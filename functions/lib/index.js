"use strict";
/**
 * SPARK Cloud Functions — Lógica de Gamificação no Servidor
 *
 * Funções Callable (HTTPS) que substituem as escritas diretas do cliente
 * no Firestore para campos sensíveis (xp, sparkPoints, eloRating, etc.).
 *
 * Todas as funções:
 *  1. Validam se o chamador está autenticado.
 *  2. Executam a lógica em uma Transação Firestore, garantindo atomicidade.
 *  3. Retornam um resultado tipado para o cliente Flutter.
 *
 * Funções exportadas:
 *  - addXp             : Adiciona XP, recalcula nível/tensionLevel e badges.
 *  - spendSparkPoints  : Debita Spark Points com verificação de saldo.
 *  - unlockBadge       : Concede badge se ainda não desbloqueada.
 *  - finalizeDuel      : Apura resultado do duelo e atualiza o ELO dos dois
 *                        jogadores (única via de escrita de ELO de duelo).
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.rankingAdminTask = exports.cleanupStaleDuels = exports.streakReminder = exports.closeTournament = exports.syncPublicProfile = exports.getBotDuelQuestions = exports.leaveDuel = exports.finalizeDuel = exports.submitDuelAnswer = exports.leaveDuelQueue = exports.joinDuelQueue = exports.deleteAccount = exports.verifyEmailCode = exports.sendEmailVerificationCode = exports.checkDeviceTrust = exports.grantAdminPremium = exports.processTrialExpiry = exports.listUsers = exports.setAccessCodeNote = exports.revokeAccessCode = exports.listAccessCodes = exports.createAccessCodes = exports.redeemAccessCode = exports.cancelTrial = exports.startTrial = exports.asaasWebhook = exports.checkPaymentStatus = exports.createAsaasCheckout = exports.unlockBadge = exports.spendSparkPoints = exports.addSparkPoints = exports.addXp = exports.onUserCreated = void 0;
const admin = require("firebase-admin");
const firestore_1 = require("firebase-admin/firestore");
const crypto = require("crypto");
const https_1 = require("firebase-functions/v2/https");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const firestore_2 = require("firebase-functions/v2/firestore");
const v2_1 = require("firebase-functions/v2");
const params_1 = require("firebase-functions/params");
const functionsV1 = require("firebase-functions/v1");
const nodemailer = require("nodemailer");
const asaasService_1 = require("./services/asaasService");
const rateLimiter_1 = require("./rateLimiter");
// ── Secrets vinculados ao Firebase Secret Manager ────────────────
const ASAAS_API_KEY = (0, params_1.defineSecret)("ASAAS_API_KEY");
const ASAAS_BASE_URL = (0, params_1.defineSecret)("ASAAS_BASE_URL");
const ASAAS_WEBHOOK_TOKEN = (0, params_1.defineSecret)("ASAAS_WEBHOOK_TOKEN");
const SMTP_USER = (0, params_1.defineSecret)("SMTP_USER");
const SMTP_PASS = (0, params_1.defineSecret)("SMTP_PASS");
// ── Firebase Admin init ──────────────────────────────────────────
admin.initializeApp({
    projectId: "spark-v1-e0eb5",
});
const db = (0, firestore_1.getFirestore)("default");
db.settings({ ignoreUndefinedProperties: true });
// Campos padrão de um novo usuário (bônus de boas-vindas). Centralizado para
// reuso entre o trigger de criação (onUserCreated) e o resgate (redeemAccessCode).
function defaultUserFields(uid, email, displayName, photoUrl) {
    return {
        uid,
        displayName: displayName !== null && displayName !== void 0 ? displayName : "",
        email: email !== null && email !== void 0 ? email : "",
        photoUrl: photoUrl !== null && photoUrl !== void 0 ? photoUrl : null,
        role: "técnico",
        sparkPoints: 100,
        xp: 0,
        level: 1,
        tensionLevel: "BT",
        currentStreak: 0,
        longestStreak: 0,
        activeDays: 0,
        studiedToday: false,
        lastStudyDate: null,
        weeklyXp: 0,
        monthlyXp: 0,
        unlockedBadgeIds: [],
        clanId: null,
        clanName: null,
        totalLessonsCompleted: 0,
        totalCorrectAnswers: 0,
        totalAnswers: 0,
        eloRating: 0,
        wins: 0,
        losses: 0,
        totalDuels: 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
}
// Bootstrap do doc do usuário no servidor: dispara quando QUALQUER conta é criada
// no Firebase Auth e cria users/{uid} com os padrões de boas-vindas. Resolve a
// falha de criação client-side no web (permission-denied por timing de auth) e
// garante o doc em todas as plataformas. Admin SDK ignora as Security Rules.
exports.onUserCreated = functionsV1
    .region("southamerica-east1")
    .auth.user()
    .onCreate(async (user) => {
    const userRef = db.collection("users").doc(user.uid);
    const snap = await userRef.get();
    if (snap.exists)
        return; // já criado (client ou redeem) — não sobrescreve
    await userRef.set(defaultUserFields(user.uid, user.email, user.displayName, user.photoURL), { merge: true });
    v2_1.logger.info(`[onUserCreated] doc de usuário criado para uid=${user.uid}`);
});
// ── Hardening de segurança ───────────────────────────────────────
// Teto de instâncias por função: protege contra picos/DoS que virariam
// custo de billing (Cloud Functions escala sem limite por padrão). Vale
// para TODAS as funções; cada uma pode sobrescrever localmente se precisar.
(0, v2_1.setGlobalOptions)({ maxInstances: 10 });
// App Check — atesta que a chamada veio do app legítimo (não de curl/script
// com um token de auth roubado/forjado). Aplicado APENAS aos callables.
//
// ⚠️ MANTER false até o cliente Flutter enviar tokens de App Check. Ligar
// antes disso REJEITA todas as chamadas do app em produção (login, XP,
// pagamento). Rollout: (1) firebase_app_check no Flutter + initialize;
// (2) registrar providers no console (Play Integrity/DeviceCheck/reCAPTCHA);
// (3) publicar o app e confirmar tokens chegando; (4) flip para true + deploy.
const ENFORCE_APP_CHECK = false;
// ────────────────────────────────────────────────────────────────
// HELPERS
// ────────────────────────────────────────────────────────────────
function calcLevel(totalXp) {
    return Math.floor(totalXp / 500) + 1;
}
function calcTension(totalXp) {
    if (totalXp < 5000)
        return "BT";
    if (totalXp < 15000)
        return "MT";
    if (totalXp < 30000)
        return "AT";
    return "EAT";
}
function xpBadgesEarned(totalXp) {
    const badges = [];
    if (totalXp >= 1000)
        badges.push("xp_1000");
    if (totalXp >= 5000)
        badges.push("xp_5000");
    if (totalXp >= 10000)
        badges.push("xp_10000");
    return badges;
}
// Rótulo de semana "YYYY-Www" — usado apenas para arquivar o histórico do
// torneio e rotular a notificação de vitória.
function weekKeyFor(d) {
    const start = new Date(d.getFullYear(), 0, 1);
    const dayOfYear = Math.floor((d.getTime() - start.getTime()) / (1000 * 60 * 60 * 24)) + 1;
    const weekNum = Math.floor((dayOfYear - d.getDay() + 10) / 7);
    return `${d.getFullYear()}-W${String(weekNum).padStart(2, "0")}`;
}
// Semana que acabou de encerrar (closeTournament roda na virada de segunda).
function lastWeekKey() {
    const d = new Date();
    d.setDate(d.getDate() - 7);
    return weekKeyFor(d);
}
async function writeAuditLog(uid, action, amount, source, meta) {
    const entry = {
        action,
        amount,
        source,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (meta)
        entry["meta"] = meta;
    await db.collection("users").doc(uid).collection("audit_log").add(entry);
}
// Removido _unlockBadgeInTx para evitar multiplos updates na mesma transacao
/** Comparação de strings em tempo constante (evita timing attacks no token). */
function safeEqual(a, b) {
    const ab = Buffer.from(a);
    const bb = Buffer.from(b);
    if (ab.length !== bb.length)
        return false;
    return crypto.timingSafeEqual(ab, bb);
}
/**
 * Gera um código de acesso legível no formato PROF-XXXX-XXXX usando bytes
 * criptograficamente seguros. Alfabeto sem caracteres ambíguos (0/O, 1/I/L).
 */
const CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"; // sem 0 O 1 I L
function genCode() {
    const bytes = crypto.randomBytes(8);
    let body = "";
    for (let i = 0; i < 8; i++) {
        body += CODE_ALPHABET[bytes[i] % CODE_ALPHABET.length];
        if (i === 3)
            body += "-";
    }
    return `PROF-${body}`; // ex.: PROF-X7K2-9QM4
}
/**
 * Remove um usuário do seu clã de forma consistente:
 *  - apaga o documento de membro;
 *  - se ele era o último membro, apaga o clã inteiro (some do ranking de clãs);
 *  - se era o criador mas há outros membros, transfere a liderança;
 *  - decrementa memberCount.
 * Usa Admin SDK (ignora as Security Rules).
 */
async function removeUserFromClan(clanId, uid) {
    var _a, _b;
    const clanRef = db.collection("clans").doc(clanId);
    const clanSnap = await clanRef.get();
    if (!clanSnap.exists)
        return;
    const wasCreator = ((_a = clanSnap.data()) === null || _a === void 0 ? void 0 : _a["createdBy"]) === uid;
    // Apaga o documento de membro do usuário
    await clanRef.collection("members").doc(uid).delete().catch(() => { });
    // Verifica se sobrou alguém
    const remaining = await clanRef.collection("members").limit(2).get();
    if (remaining.empty) {
        // Era o último membro → apaga o clã e todas as subcoleções.
        // Como o ranking de clãs lê direto de /clans, o clã some do ranking.
        await db.recursiveDelete(clanRef);
        return;
    }
    // Ainda há membros → ajusta a contagem
    await clanRef
        .update({ memberCount: admin.firestore.FieldValue.increment(-1) })
        .catch(() => { });
    // Se o criador saiu, promove outro membro a líder/admin
    if (wasCreator) {
        const next = (_b = remaining.docs.find((d) => d.id !== uid)) !== null && _b !== void 0 ? _b : remaining.docs[0];
        await clanRef.update({ createdBy: next.id }).catch(() => { });
        await next.ref.update({ role: "admin" }).catch(() => { });
    }
}
const PLAN_CATALOG = {
    student: { monthlyPrice: 19.90, annualPrice: 199, points: 0 },
    pro: { monthlyPrice: 39.90, annualPrice: 399, points: 0 },
    premium: { monthlyPrice: 79.90, annualPrice: 799, points: 0 },
    business: { monthlyPrice: 29, annualPrice: null, points: 0 },
};
/** Tolerância para casar preço float enviado pelo cliente (centavos). */
const PRICE_EPSILON = 0.01;
/** Tetos por chamada — mitigam farming até a migração para recompensas
 *  100% autoritativas no servidor (ver memória spark-security-pending). */
const MAX_XP_PER_CALL = 1000;
const MAX_SP_PER_CALL = 500;
/** Badges que o servidor concede automaticamente — NÃO podem ser
 *  reivindicadas manualmente via unlockBadge. */
const SERVER_ONLY_BADGES = new Set([
    "xp_1000", "xp_5000", "xp_10000", "primeiro_duelo",
]);
/** Badges que o cliente pode reivindicar (conquistas ainda não
 *  verificáveis no servidor). Qualquer ID fora deste conjunto é rejeitado. */
const CLIENT_CLAIMABLE_BADGES = new Set([
    "queimador", "sniper", "noturno", "top3", "teorico", "veloz",
    "cla_unido", "streak_3_days", "streak_7", "streak_30",
    "first_lesson", "lesson_10", "lesson_50",
]);
/**
 * Resolve um item do carrinho contra o catálogo do servidor.
 * Lança HttpsError se o plano for desconhecido ou o preço não casar
 * com nenhum período do plano.
 */
function resolveCatalogItem(item) {
    var _a;
    const planId = item.planId;
    if (!planId || !PLAN_CATALOG[planId]) {
        throw new https_1.HttpsError("invalid-argument", `Plano inválido ou indisponível: ${planId !== null && planId !== void 0 ? planId : "(vazio)"}.`);
    }
    const plan = PLAN_CATALOG[planId];
    const submitted = typeof item.price === "number" ? item.price : NaN;
    let period;
    let price;
    if (Math.abs(submitted - plan.monthlyPrice) <= PRICE_EPSILON) {
        period = "monthly";
        price = plan.monthlyPrice;
    }
    else if (plan.annualPrice != null &&
        Math.abs(submitted - plan.annualPrice) <= PRICE_EPSILON) {
        period = "annual";
        price = plan.annualPrice;
    }
    else {
        throw new https_1.HttpsError("invalid-argument", `Preço inválido para o plano ${planId}.`);
    }
    return {
        name: ((_a = item.name) !== null && _a !== void 0 ? _a : planId).slice(0, 120),
        planId,
        price,
        points: plan.points,
        isSubscription: true,
        period,
    };
}
exports.addXp = (0, https_1.onCall)({
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
}, async (request) => {
    var _a;
    const uid = (_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid;
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "Usuário não autenticado.");
    }
    await (0, rateLimiter_1.checkRateLimit)((0, rateLimiter_1.rateLimitKey)("gamification", uid, "addXp"), rateLimiter_1.RATE_GAMIFICATION.limit, rateLimiter_1.RATE_GAMIFICATION.windowMs);
    const { amount, source = "app" } = request.data;
    if (!amount || typeof amount !== "number" || !Number.isFinite(amount) || amount <= 0) {
        throw new https_1.HttpsError("invalid-argument", "amount deve ser um número positivo.");
    }
    if (amount > MAX_XP_PER_CALL) {
        throw new https_1.HttpsError("invalid-argument", `amount excede o máximo permitido por chamada (${MAX_XP_PER_CALL}).`);
    }
    const userRef = db.collection("users").doc(uid);
    let result;
    // Transação focada SOMENTE no documento do usuário (sem cross-document)
    await db.runTransaction(async (tx) => {
        var _a, _b;
        const snap = await tx.get(userRef);
        if (!snap.exists) {
            throw new https_1.HttpsError("not-found", "Documento do usuário não encontrado.");
        }
        const data = snap.data();
        const currentXp = (_a = data["xp"]) !== null && _a !== void 0 ? _a : 0;
        const unlockedBadgeIds = (_b = data["unlockedBadgeIds"]) !== null && _b !== void 0 ? _b : [];
        const oldLevel = calcLevel(currentXp);
        const newXp = currentXp + amount;
        const newLevel = calcLevel(newXp);
        const newTension = calcTension(newXp);
        const leveledUp = newLevel > oldLevel;
        const userUpdates = {
            xp: admin.firestore.FieldValue.increment(amount),
            weeklyXp: admin.firestore.FieldValue.increment(amount),
            monthlyXp: admin.firestore.FieldValue.increment(amount),
            level: newLevel,
            tensionLevel: newTension,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        const badgesToCheck = xpBadgesEarned(newXp);
        const badgesUnlocked = [];
        const newBadges = badgesToCheck.filter(b => !unlockedBadgeIds.includes(b));
        if (newBadges.length > 0) {
            userUpdates.unlockedBadgeIds = admin.firestore.FieldValue.arrayUnion(...newBadges);
            badgesUnlocked.push(...newBadges);
        }
        tx.update(userRef, userUpdates);
        result = { newXp, newLevel, newTension, leveledUp, badgesUnlocked };
        // O ranking (Global por xp e Torneio por weeklyXp) é lido direto de
        // public_profiles, mantido pelo trigger syncPublicProfile. Não há mais
        // escrita em rankings/weekly aqui.
    });
    // Audit log fora da transação (não-crítico)
    try {
        await writeAuditLog(uid, "xp_gained", amount, source, {
            newXp: result.newXp,
            newLevel: result.newLevel,
        });
        if (result.leveledUp) {
            await writeAuditLog(uid, "level_up", result.newLevel, source, {
                newLevel: result.newLevel,
            });
        }
    }
    catch (e) {
        v2_1.logger.warn("[addXp] Erro no audit log (não crítico):", e);
    }
    v2_1.logger.info(`[addXp] uid=${uid} amount=${amount} newXp=${result.newXp} level=${result.newLevel}`);
    return result;
});
exports.addSparkPoints = (0, https_1.onCall)({
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
}, async (request) => {
    var _a;
    const uid = (_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid;
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "Usuário não autenticado.");
    }
    await (0, rateLimiter_1.checkRateLimit)((0, rateLimiter_1.rateLimitKey)("gamification", uid, "addSparkPoints"), rateLimiter_1.RATE_GAMIFICATION.limit, rateLimiter_1.RATE_GAMIFICATION.windowMs);
    const { amount, source = "reward" } = request.data;
    if (!amount || typeof amount !== "number" || !Number.isFinite(amount) || amount <= 0) {
        throw new https_1.HttpsError("invalid-argument", "amount deve ser um número positivo.");
    }
    if (amount > MAX_SP_PER_CALL) {
        throw new https_1.HttpsError("invalid-argument", `amount excede o máximo permitido por chamada (${MAX_SP_PER_CALL}).`);
    }
    const userRef = db.collection("users").doc(uid);
    let newBalance = 0;
    await db.runTransaction(async (tx) => {
        var _a;
        const snap = await tx.get(userRef);
        if (!snap.exists) {
            throw new https_1.HttpsError("not-found", "Documento do usuário não encontrado.");
        }
        const currentSp = (_a = snap.data()["sparkPoints"]) !== null && _a !== void 0 ? _a : 0;
        newBalance = currentSp + amount;
        tx.update(userRef, {
            sparkPoints: admin.firestore.FieldValue.increment(amount),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    });
    try {
        await writeAuditLog(uid, "sp_gained", amount, source, { newBalance });
    }
    catch (e) {
        v2_1.logger.warn("[addSparkPoints] Audit log error:", e);
    }
    v2_1.logger.info(`[addSparkPoints] uid=${uid} amount=${amount} newBalance=${newBalance}`);
    return { newBalance };
});
exports.spendSparkPoints = (0, https_1.onCall)({
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
}, async (request) => {
    var _a;
    const uid = (_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid;
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "Usuário não autenticado.");
    }
    await (0, rateLimiter_1.checkRateLimit)((0, rateLimiter_1.rateLimitKey)("gamification", uid, "spendSparkPoints"), rateLimiter_1.RATE_GAMIFICATION.limit, rateLimiter_1.RATE_GAMIFICATION.windowMs);
    const { amount, source = "purchase" } = request.data;
    if (!amount || typeof amount !== "number" || !Number.isFinite(amount) || amount <= 0) {
        throw new https_1.HttpsError("invalid-argument", "amount deve ser um número positivo.");
    }
    const userRef = db.collection("users").doc(uid);
    let result;
    await db.runTransaction(async (tx) => {
        var _a;
        const snap = await tx.get(userRef);
        if (!snap.exists) {
            throw new https_1.HttpsError("not-found", "Documento do usuário não encontrado.");
        }
        const currentSp = (_a = snap.data()["sparkPoints"]) !== null && _a !== void 0 ? _a : 0;
        if (currentSp < amount) {
            result = {
                success: false,
                newBalance: currentSp,
                message: "Saldo insuficiente de Spark Points.",
            };
            return; // não faz rollback, só não executa
        }
        tx.update(userRef, {
            sparkPoints: admin.firestore.FieldValue.increment(-amount),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        result = { success: true, newBalance: currentSp - amount };
    });
    if (result.success) {
        try {
            await writeAuditLog(uid, "sp_spent", amount, source);
        }
        catch (e) {
            v2_1.logger.warn("[spendSparkPoints] Audit log error:", e);
        }
    }
    return result;
});
exports.unlockBadge = (0, https_1.onCall)({
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
}, async (request) => {
    var _a, _b;
    const uid = (_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid;
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "Usuário não autenticado.");
    }
    await (0, rateLimiter_1.checkRateLimit)((0, rateLimiter_1.rateLimitKey)("gamification", uid, "unlockBadge"), rateLimiter_1.RATE_GAMIFICATION.limit, rateLimiter_1.RATE_GAMIFICATION.windowMs);
    const { badgeId, source = "achievement" } = request.data;
    if (!badgeId || typeof badgeId !== "string") {
        throw new https_1.HttpsError("invalid-argument", "badgeId inválido.");
    }
    // Badges concedidas pelo servidor (XP/duelo) não podem ser reivindicadas.
    if (SERVER_ONLY_BADGES.has(badgeId)) {
        throw new https_1.HttpsError("permission-denied", "Esta conquista é concedida automaticamente pelo servidor.");
    }
    // Só badges conhecidas e reivindicáveis pelo cliente são aceitas.
    if (!CLIENT_CLAIMABLE_BADGES.has(badgeId)) {
        throw new https_1.HttpsError("invalid-argument", `badgeId desconhecido: ${badgeId}.`);
    }
    const userRef = db.collection("users").doc(uid);
    let unlocked = false;
    const snap = await userRef.get();
    if (!snap.exists) {
        throw new https_1.HttpsError("not-found", "Documento do usuário não encontrado.");
    }
    const unlockedBadgeIds = (_b = snap.data()["unlockedBadgeIds"]) !== null && _b !== void 0 ? _b : [];
    if (!unlockedBadgeIds.includes(badgeId)) {
        await userRef.update({
            unlockedBadgeIds: admin.firestore.FieldValue.arrayUnion(badgeId),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        unlocked = true;
    }
    if (unlocked) {
        try {
            await writeAuditLog(uid, "badge_unlocked", 1, source, { badgeId });
        }
        catch (e) {
            v2_1.logger.warn("[unlockBadge] Audit log error:", e);
        }
        v2_1.logger.info(`[unlockBadge] uid=${uid} badge=${badgeId}`);
    }
    return { unlocked, badgeId };
});
exports.createAsaasCheckout = (0, https_1.onCall)({
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    secrets: [ASAAS_API_KEY, ASAAS_BASE_URL],
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
}, async (request) => {
    var _a, _b, _c, _d;
    const uid = (_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid;
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "Usuário não autenticado.");
    }
    // Rate limit: evita criação em massa de pedidos / abuso da API Asaas.
    await (0, rateLimiter_1.checkRateLimit)((0, rateLimiter_1.rateLimitKey)("payment", uid, "createAsaasCheckout"), rateLimiter_1.RATE_PAYMENT.limit, rateLimiter_1.RATE_PAYMENT.windowMs);
    const { items, billingType, customerName, customerEmail, customerCpfCnpj } = request.data;
    if (!items || items.length === 0) {
        throw new https_1.HttpsError("invalid-argument", "Carrinho vazio.");
    }
    if (!billingType) {
        throw new https_1.HttpsError("invalid-argument", "billingType é obrigatório.");
    }
    // Verifica se a chave do Asaas está configurada
    const apiKey = (_b = process.env.ASAAS_API_KEY) !== null && _b !== void 0 ? _b : "";
    if (!apiKey) {
        v2_1.logger.warn("[createAsaasCheckout] ASAAS_API_KEY não configurada — pagamento indisponível.");
        throw new https_1.HttpsError("unavailable", "O sistema de pagamentos está em manutenção. Tente novamente em breve.");
    }
    // SEGURANÇA: resolve cada item pelo catálogo do servidor. Preço e
    // pontos são definidos pelo servidor — o que o cliente enviar é
    // ignorado (exceto para escolher mensal/anual, já validado).
    const resolvedItems = items.map((i) => resolveCatalogItem(i));
    const totalPrice = resolvedItems.reduce((acc, i) => acc + i.price, 0);
    const totalPoints = resolvedItems.reduce((acc, i) => acc + i.points, 0);
    // Busca dados do usuário no Firestore para preencher o cliente Asaas
    const userSnap = await db.collection("users").doc(uid).get();
    if (!userSnap.exists) {
        throw new https_1.HttpsError("not-found", "Usuário não encontrado.");
    }
    const userData = userSnap.data();
    const name = (_c = customerName !== null && customerName !== void 0 ? customerName : userData["displayName"]) !== null && _c !== void 0 ? _c : "Usuário Spark";
    const email = (_d = customerEmail !== null && customerEmail !== void 0 ? customerEmail : userData["email"]) !== null && _d !== void 0 ? _d : `${uid}@spark.app`;
    // Obtém ou cria o cliente no Asaas
    let asaasCustomerId = userData["asaasCustomerId"];
    if (!asaasCustomerId) {
        asaasCustomerId = await (0, asaasService_1.findOrCreateCustomer)(name, email, customerCpfCnpj);
        // Persiste o id para reutilização futura
        await db
            .collection("users")
            .doc(uid)
            .update({ asaasCustomerId });
    }
    else if (customerCpfCnpj) {
        // Se já existia o id, mas recebemos o CPF agora (ex: pagamento PIX), garantimos o update
        await (0, asaasService_1.updateCustomer)(asaasCustomerId, customerCpfCnpj);
    }
    // Cria o pedido pendente no Firestore ANTES de chamar o Asaas
    const orderRef = db.collection("orders").doc();
    await orderRef.set({
        uid,
        items: resolvedItems.map((i) => ({
            name: i.name,
            price: i.price,
            sparkPointsGranted: i.points,
            isSubscription: i.isSubscription,
            planId: i.planId,
            period: i.period,
        })),
        totalPrice,
        totalPoints,
        billingType,
        status: "PENDING",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    const orderId = orderRef.id;
    const description = resolvedItems.length === 1
        ? resolvedItems[0].name
        : `${resolvedItems.length} itens — Loja Spark`;
    // Cria a cobrança no Asaas
    const chargeResult = await (0, asaasService_1.createCharge)({
        customerId: asaasCustomerId,
        value: Number(totalPrice.toFixed(2)),
        description,
        billingType,
        orderId,
    });
    // Salva o chargeId no pedido para reconciliação via webhook
    await orderRef.update({ chargeId: chargeResult.chargeId });
    v2_1.logger.info(`[createAsaasCheckout] uid=${uid} orderId=${orderId} chargeId=${chargeResult.chargeId} total=${totalPrice}`);
    return {
        orderId,
        chargeId: chargeResult.chargeId,
        billingType: chargeResult.billingType,
        totalPrice,
        invoiceUrl: chargeResult.invoiceUrl,
        pixPayload: chargeResult.pixPayload,
        pixQrCodeBase64: chargeResult.pixQrCodeBase64,
        pixExpirationDate: chargeResult.pixExpirationDate,
        bankSlipUrl: chargeResult.bankSlipUrl,
    };
});
exports.checkPaymentStatus = (0, https_1.onCall)({
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    secrets: [ASAAS_API_KEY, ASAAS_BASE_URL],
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
}, async (request) => {
    var _a, _b, _c, _d, _e, _f;
    const uid = (_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid;
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "Usuário não autenticado.");
    }
    await (0, rateLimiter_1.checkRateLimit)((0, rateLimiter_1.rateLimitKey)("payment", uid, "checkPaymentStatus"), rateLimiter_1.RATE_PAYMENT.limit, rateLimiter_1.RATE_PAYMENT.windowMs);
    const { orderId } = request.data;
    if (!orderId) {
        throw new https_1.HttpsError("invalid-argument", "orderId é obrigatório.");
    }
    // Busca o pedido no Firestore
    const orderRef = db.collection("orders").doc(orderId);
    const orderSnap = await orderRef.get();
    if (!orderSnap.exists) {
        throw new https_1.HttpsError("not-found", `Pedido ${orderId} não encontrado.`);
    }
    const order = orderSnap.data();
    // Valida que o pedido pertence ao usuário autenticado
    if (order["uid"] !== uid) {
        throw new https_1.HttpsError("permission-denied", "Acesso negado ao pedido.");
    }
    // Se já foi processado, retorna direto
    if (order["status"] === "PAID") {
        return {
            status: "PAID",
            processed: false, // já estava pago antes
            sparkPointsGranted: (_b = order["totalPoints"]) !== null && _b !== void 0 ? _b : 0,
        };
    }
    const chargeId = order["chargeId"];
    if (!chargeId) {
        return { status: (_c = order["status"]) !== null && _c !== void 0 ? _c : "PENDING", processed: false, sparkPointsGranted: 0 };
    }
    // Consulta o Asaas diretamente usando getChargeStatus
    const asaasChargeStatus = await (0, asaasService_1.getChargeStatus)(chargeId);
    v2_1.logger.info(`[checkPaymentStatus] orderId=${orderId} chargeId=${chargeId} asaasStatus=${asaasChargeStatus}`);
    const isConfirmed = asaasChargeStatus === "RECEIVED" ||
        asaasChargeStatus === "CONFIRMED" ||
        asaasChargeStatus === "RECEIVED_IN_CASH";
    if (!isConfirmed) {
        return { status: asaasChargeStatus, processed: false, sparkPointsGranted: 0 };
    }
    // Pagamento confirmado no Asaas — processa igual ao webhook
    const totalPoints = (_d = order["totalPoints"]) !== null && _d !== void 0 ? _d : 0;
    const totalPrice = (_e = order["totalPrice"]) !== null && _e !== void 0 ? _e : 0;
    const items = (_f = order["items"]) !== null && _f !== void 0 ? _f : [];
    const hasSubscription = items.some((i) => i.isSubscription === true);
    const batch = db.batch();
    batch.update(orderRef, {
        status: "PAID",
        paidAt: admin.firestore.FieldValue.serverTimestamp(),
        asaasPaymentId: chargeId,
        confirmedVia: "polling",
    });
    const userRef = db.collection("users").doc(uid);
    let userUpdated = false;
    const userUpdates = { updatedAt: admin.firestore.FieldValue.serverTimestamp() };
    if (totalPoints > 0) {
        userUpdates.sparkPoints = admin.firestore.FieldValue.increment(totalPoints);
        userUpdated = true;
    }
    if (hasSubscription) {
        userUpdates.isPremium = true;
        const subItem = items.find((i) => i.isSubscription === true);
        if (subItem && subItem.planId) {
            userUpdates.subscriptionPlanId = subItem.planId;
        }
        userUpdated = true;
    }
    if (userUpdated) {
        batch.update(userRef, userUpdates);
    }
    const txRef = db.collection("transactions").doc();
    batch.set(txRef, {
        uid,
        orderId,
        asaasPaymentId: chargeId,
        totalPrice,
        totalPoints,
        status: "PAID",
        confirmedVia: "polling",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await batch.commit();
    try {
        await writeAuditLog(uid, "sp_purchased", totalPoints, "asaas_polling", {
            orderId,
            asaasPaymentId: chargeId,
            totalPrice,
        });
    }
    catch (e) {
        v2_1.logger.warn("[checkPaymentStatus] Audit log error:", e);
    }
    v2_1.logger.info(`[checkPaymentStatus] Pedido ${orderId} processado via polling. +${totalPoints} pts para uid=${uid}`);
    return { status: "PAID", processed: true, sparkPointsGranted: totalPoints };
});
// ────────────────────────────────────────────────────────────────
// 6. asaasWebhook — Processa eventos de pagamento do Asaas
// ────────────────────────────────────────────────────────────────
/**
 * Endpoint HTTP que o Asaas chama quando um pagamento é confirmado.
 * Configura este URL no painel Asaas → Configurações → Webhook.
 *
 * URL: https://southamerica-east1-spark-v1-e0eb5.cloudfunctions.net/asaasWebhook
 *
 * Eventos suportados:
 *  - PAYMENT_RECEIVED   : PIX / Cartão confirmado
 *  - PAYMENT_CONFIRMED  : Boleto compensado
 */
// deploy-force: 2026-05-29T13:59 — atualiza secret ASAAS_WEBHOOK_TOKEN para versão 8
exports.asaasWebhook = (0, https_1.onRequest)({
    region: "southamerica-east1",
    secrets: [ASAAS_WEBHOOK_TOKEN, ASAAS_API_KEY, ASAAS_BASE_URL],
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
}, async (req, res) => {
    var _a, _b, _c, _d, _e, _f, _g;
    // 1) Só aceita POST
    if (req.method !== "POST") {
        res.status(405).send("Method Not Allowed");
        return;
    }
    // 2) Parseia o body — o Asaas envia em formato envelope:
    //    { data: "JSON string com event+payment", accessToken: "..." }
    //    Também aceita formato direto: { event, payment } (para testes manuais)
    let event;
    let payment;
    const rawBody = req.body;
    // Não logamos o corpo bruto (pode conter PII do cliente).
    // Lê o token primariamente do header oficial do Asaas
    let receivedToken = (_a = req.headers["asaas-access-token"]) !== null && _a !== void 0 ? _a : "";
    if ((rawBody === null || rawBody === void 0 ? void 0 : rawBody.data) && typeof rawBody.data === "string") {
        // Formato envelope (pode vir de ferramentas de teste ou proxy)
        try {
            const parsed = JSON.parse(rawBody.data);
            event = parsed.event;
            payment = parsed.payment;
            // Fallback para o envelope caso o header não venha
            if (!receivedToken) {
                receivedToken = (_b = rawBody.accessToken) !== null && _b !== void 0 ? _b : "";
            }
            v2_1.logger.info(`[asaasWebhook] Formato envelope detectado. Event=${event}, paymentId=${payment === null || payment === void 0 ? void 0 : payment.id}`);
        }
        catch (e) {
            v2_1.logger.error(`[asaasWebhook] Erro ao parsear data: ${e}`);
            res.status(400).send("Invalid data format");
            return;
        }
    }
    else {
        // Formato direto (Asaas real / chamadas diretas)
        event = rawBody === null || rawBody === void 0 ? void 0 : rawBody.event;
        payment = rawBody === null || rawBody === void 0 ? void 0 : rawBody.payment;
        v2_1.logger.info(`[asaasWebhook] Formato direto detectado. Event=${event}, paymentId=${payment === null || payment === void 0 ? void 0 : payment.id}`);
    }
    // 3) Verifica token — FAIL-CLOSED: sem secret configurado, rejeita tudo.
    //    (Nunca logamos o valor/prefixo do secret.)
    const expectedSecret = (_c = process.env.ASAAS_WEBHOOK_TOKEN) !== null && _c !== void 0 ? _c : "";
    if (!expectedSecret) {
        v2_1.logger.error("[asaasWebhook] ASAAS_WEBHOOK_TOKEN não configurado — rejeitando webhook.");
        res.status(401).send("Unauthorized");
        return;
    }
    if (!safeEqual(receivedToken, expectedSecret)) {
        v2_1.logger.warn("[asaasWebhook] Token inválido bloqueado.");
        res.status(401).send("Unauthorized");
        return;
    }
    v2_1.logger.info(`[asaasWebhook] Evento: ${event}`, { payment });
    // 4) Processa apenas eventos de pagamento confirmado
    const isConfirmed = event === "PAYMENT_RECEIVED" ||
        event === "PAYMENT_CONFIRMED" ||
        event === "PAYMENT_RECEIVED_IN_CASH";
    if (!isConfirmed || !payment) {
        v2_1.logger.info(`[asaasWebhook] Evento '${event}' ignorado.`);
        res.status(200).send("Event ignored");
        return;
    }
    const orderId = payment.externalReference;
    if (!orderId) {
        v2_1.logger.warn("[asaasWebhook] Pagamento sem externalReference.", payment);
        res.status(200).send("No externalReference");
        return;
    }
    // 4) Busca o pedido no Firestore
    const orderRef = db.collection("orders").doc(orderId);
    const orderSnap = await orderRef.get();
    if (!orderSnap.exists) {
        v2_1.logger.error(`[asaasWebhook] Pedido ${orderId} não encontrado.`);
        res.status(200).send("Order not found");
        return;
    }
    const order = orderSnap.data();
    // Idempotência — ignora se já foi processado
    if (order["status"] === "PAID") {
        v2_1.logger.info(`[asaasWebhook] Pedido ${orderId} já processado. Ignorando.`);
        res.status(200).send("Already processed");
        return;
    }
    const uid = order["uid"];
    const totalPoints = (_d = order["totalPoints"]) !== null && _d !== void 0 ? _d : 0;
    const totalPrice = (_e = order["totalPrice"]) !== null && _e !== void 0 ? _e : 0;
    const items = (_f = order["items"]) !== null && _f !== void 0 ? _f : [];
    const hasSubscription = items.some((i) => i.isSubscription === true);
    // DEFESA EM PROFUNDIDADE: nunca confia só no corpo do webhook.
    // Reconsulta a cobrança no Asaas e confirma que ela está paga E pelo
    // valor esperado do pedido antes de conceder qualquer benefício.
    const orderChargeId = (_g = order["chargeId"]) !== null && _g !== void 0 ? _g : payment.id;
    const charge = await (0, asaasService_1.getChargeDetails)(orderChargeId);
    if (!charge) {
        v2_1.logger.error(`[asaasWebhook] Não foi possível reconsultar a cobrança ${orderChargeId}. Abortando concessão.`);
        res.status(200).send("Charge re-verification failed");
        return;
    }
    const asaasConfirmed = charge.status === "RECEIVED" ||
        charge.status === "CONFIRMED" ||
        charge.status === "RECEIVED_IN_CASH";
    if (!asaasConfirmed) {
        v2_1.logger.warn(`[asaasWebhook] Cobrança ${orderChargeId} não confirmada no Asaas (status=${charge.status}). Ignorando.`);
        res.status(200).send("Charge not confirmed at Asaas");
        return;
    }
    if (Math.abs(charge.value - totalPrice) > PRICE_EPSILON) {
        v2_1.logger.error(`[asaasWebhook] Valor divergente: Asaas=${charge.value} pedido=${totalPrice}. Abortando concessão.`);
        res.status(200).send("Amount mismatch");
        return;
    }
    // 5) Batch: marca pedido como pago + incrementa pontos/premium + grava transação
    const batch = db.batch();
    // Atualiza status do pedido
    batch.update(orderRef, {
        status: "PAID",
        paidAt: admin.firestore.FieldValue.serverTimestamp(),
        asaasPaymentId: payment.id,
    });
    const userRef = db.collection("users").doc(uid);
    let userUpdated = false;
    const userUpdates = { updatedAt: admin.firestore.FieldValue.serverTimestamp() };
    if (totalPoints > 0) {
        userUpdates.sparkPoints = admin.firestore.FieldValue.increment(totalPoints);
        userUpdated = true;
    }
    if (hasSubscription) {
        userUpdates.isPremium = true;
        const subItem = items.find((i) => i.isSubscription === true);
        if (subItem && subItem.planId) {
            userUpdates.subscriptionPlanId = subItem.planId;
        }
        userUpdated = true;
    }
    if (userUpdated) {
        batch.update(userRef, userUpdates);
    }
    // Registra transação para histórico financeiro
    const txRef = db.collection("transactions").doc();
    batch.set(txRef, {
        uid,
        orderId,
        asaasPaymentId: payment.id,
        totalPrice,
        totalPoints,
        status: "PAID",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await batch.commit();
    // Audit log (não-crítico)
    try {
        await writeAuditLog(uid, "sp_purchased", totalPoints, "asaas_payment", {
            orderId,
            asaasPaymentId: payment.id,
            totalPrice,
        });
    }
    catch (e) {
        v2_1.logger.warn("[asaasWebhook] Audit log error:", e);
    }
    v2_1.logger.info(`[asaasWebhook] Pedido ${orderId} confirmado. +${totalPoints} pts para uid=${uid}`);
    res.status(200).send("OK");
});
exports.startTrial = (0, https_1.onCall)({
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
}, async (request) => {
    var _a;
    const uid = (_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid;
    if (!uid)
        throw new https_1.HttpsError("unauthenticated", "Usuário não autenticado.");
    await (0, rateLimiter_1.checkRateLimit)((0, rateLimiter_1.rateLimitKey)("payment", uid, "startTrial"), rateLimiter_1.RATE_PAYMENT.limit, rateLimiter_1.RATE_PAYMENT.windowMs);
    const { planId, cardTokenId } = request.data;
    if (!planId)
        throw new https_1.HttpsError("invalid-argument", "planId é obrigatório.");
    if (!PLAN_CATALOG[planId]) {
        throw new https_1.HttpsError("invalid-argument", `Plano inválido: ${planId}.`);
    }
    const userRef = db.collection("users").doc(uid);
    const snap = await userRef.get();
    if (!snap.exists)
        throw new https_1.HttpsError("not-found", "Usuário não encontrado.");
    const data = snap.data();
    if (data["isOnTrial"] === true) {
        throw new https_1.HttpsError("already-exists", "Usuário já possui um trial ativo.");
    }
    if (data["hadTrial"] === true) {
        throw new https_1.HttpsError("already-exists", "Usuário já utilizou o período de trial.");
    }
    const trialEndsAt = new Date();
    trialEndsAt.setDate(trialEndsAt.getDate() + 7);
    await userRef.update({
        isOnTrial: true,
        hadTrial: true,
        trialEndsAt: admin.firestore.Timestamp.fromDate(trialEndsAt),
        subscriptionPlanId: planId,
        isPremium: true,
        trialCardTokenId: cardTokenId !== null && cardTokenId !== void 0 ? cardTokenId : null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    try {
        await writeAuditLog(uid, "trial_started", 7, "startTrial", {
            planId,
            trialEndsAt: trialEndsAt.toISOString(),
        });
    }
    catch (e) {
        v2_1.logger.warn("[startTrial] Audit log error:", e);
    }
    v2_1.logger.info(`[startTrial] uid=${uid} plan=${planId} endsAt=${trialEndsAt.toISOString()}`);
    return { success: true, trialEndsAt: trialEndsAt.toISOString() };
});
// ────────────────────────────────────────────────────────────────
// 10. cancelTrial — Cancela trial antes do vencimento
// ────────────────────────────────────────────────────────────────
exports.cancelTrial = (0, https_1.onCall)({
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
}, async (request) => {
    var _a;
    const uid = (_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid;
    if (!uid)
        throw new https_1.HttpsError("unauthenticated", "Usuário não autenticado.");
    const userRef = db.collection("users").doc(uid);
    const snap = await userRef.get();
    if (!snap.exists)
        throw new https_1.HttpsError("not-found", "Usuário não encontrado.");
    const data = snap.data();
    if (!data["isOnTrial"]) {
        throw new https_1.HttpsError("failed-precondition", "Usuário não possui trial ativo.");
    }
    // Preserva premium se houver acesso-cortesia (código) ainda ativo — cancelar
    // o trial não deve derrubar uma cortesia válida.
    const compTs = data["compAccessExpiresAt"];
    const compActive = !!compTs && compTs.toMillis() > Date.now();
    await userRef.update({
        isOnTrial: false,
        isPremium: compActive,
        trialEndsAt: null,
        subscriptionPlanId: null,
        trialCardTokenId: null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    try {
        await writeAuditLog(uid, "trial_cancelled", 0, "cancelTrial", {});
    }
    catch (e) {
        v2_1.logger.warn("[cancelTrial] Audit log error:", e);
    }
    v2_1.logger.info(`[cancelTrial] uid=${uid} trial cancelado.`);
    return { success: true };
});
// ════════════════════════════════════════════════════════════════
// CÓDIGOS DE ACESSO (cortesia) — libera acesso total por N dias.
//   access_codes/{CODE}: server-only. Concede isPremium=true +
//   compAccessExpiresAt (ortogonal a trial/assinatura). A expiração é
//   tratada pelo processTrialExpiry (bloco de cortesia, abaixo).
// ════════════════════════════════════════════════════════════════
/** Lê o doc do chamador e exige role=='admin' (mesmo critério das rules). */
async function assertAdmin(uid) {
    var _a;
    const snap = await db.collection("users").doc(uid).get();
    if (((_a = snap.data()) === null || _a === void 0 ? void 0 : _a["role"]) !== "admin") {
        throw new https_1.HttpsError("permission-denied", "Apenas administradores.");
    }
}
/**
 * Resolve uids -> { uid, name, email } mesclando o doc /users (displayName/email)
 * com o registro do Firebase Auth (preenche email/nome faltantes). Usado para
 * mostrar POR QUEM cada código foi resgatado e a listagem de usuários do admin.
 */
async function resolveUserInfos(uids) {
    const out = new Map();
    const unique = [...new Set(uids.filter(Boolean))];
    if (unique.length === 0)
        return out;
    // /users (displayName + email quando houver)
    const docs = await db.getAll(...unique.map((u) => db.collection("users").doc(u)));
    const fromDoc = new Map();
    docs.forEach((d) => {
        const data = d.data() || {};
        fromDoc.set(d.id, { name: data["displayName"], email: data["email"] });
    });
    // Auth (fonte confiável de email/nome) — em lotes de 100
    const fromAuth = new Map();
    for (let i = 0; i < unique.length; i += 100) {
        const chunk = unique.slice(i, i + 100).map((u) => ({ uid: u }));
        try {
            const res = await admin.auth().getUsers(chunk);
            res.users.forEach((u) => fromAuth.set(u.uid, { name: u.displayName, email: u.email }));
        }
        catch (e) {
            v2_1.logger.warn("[resolveUserInfos] getUsers erro:", e);
        }
    }
    for (const uid of unique) {
        const d = fromDoc.get(uid) || {};
        const a = fromAuth.get(uid) || {};
        const name = (d.name && d.name.trim()) || (a.name && a.name.trim()) || "";
        const email = d.email || a.email || null;
        out.set(uid, { uid, name, email });
    }
    return out;
}
// redeemAccessCode — professor resgata o código e ganha acesso por durationDays.
exports.redeemAccessCode = (0, https_1.onCall)({
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
}, async (request) => {
    var _a, _b, _c;
    const uid = (_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid;
    if (!uid)
        throw new https_1.HttpsError("unauthenticated", "Usuário não autenticado.");
    // Rate limit (anti-brute-force de códigos): família de entitlement.
    await (0, rateLimiter_1.checkRateLimit)((0, rateLimiter_1.rateLimitKey)("payment", uid, "redeemAccessCode"), rateLimiter_1.RATE_PAYMENT.limit, rateLimiter_1.RATE_PAYMENT.windowMs);
    const code = ((_c = (_b = request.data) === null || _b === void 0 ? void 0 : _b.code) !== null && _c !== void 0 ? _c : "").toString().trim().toUpperCase();
    if (!code)
        throw new https_1.HttpsError("invalid-argument", "Código é obrigatório.");
    const codeRef = db.collection("access_codes").doc(code);
    const userRef = db.collection("users").doc(uid);
    const expiresAtIso = await db.runTransaction(async (tx) => {
        var _a, _b, _c, _d, _e;
        const codeSnap = await tx.get(codeRef);
        if (!codeSnap.exists)
            throw new https_1.HttpsError("not-found", "Código inválido.");
        const c = codeSnap.data();
        if (c["active"] !== true) {
            throw new https_1.HttpsError("failed-precondition", "Código desativado.");
        }
        const codeExp = c["expiresAt"];
        if (codeExp && codeExp.toMillis() <= Date.now()) {
            throw new https_1.HttpsError("failed-precondition", "Código expirado.");
        }
        const redeemedBy = (_a = c["redeemedBy"]) !== null && _a !== void 0 ? _a : [];
        if (redeemedBy.includes(uid)) {
            throw new https_1.HttpsError("already-exists", "Você já resgatou este código.");
        }
        if (((_b = c["usedCount"]) !== null && _b !== void 0 ? _b : 0) >= ((_c = c["maxUses"]) !== null && _c !== void 0 ? _c : 1)) {
            throw new https_1.HttpsError("resource-exhausted", "Código esgotado.");
        }
        const userSnap = await tx.get(userRef);
        const u = userSnap.exists ? userSnap.data() : null;
        // Não sobrescreve uma assinatura paga ativa.
        if (u && u["subscriptionPlanId"] != null && u["isPremium"] === true) {
            throw new https_1.HttpsError("failed-precondition", "Você já possui uma assinatura ativa.");
        }
        const durationDays = (_d = c["durationDays"]) !== null && _d !== void 0 ? _d : 30;
        // Estende a partir do maior entre (agora) e (cortesia atual) — não perde dias.
        const currentComp = u === null || u === void 0 ? void 0 : u["compAccessExpiresAt"];
        const baseMs = currentComp && currentComp.toMillis() > Date.now()
            ? currentComp.toMillis()
            : Date.now();
        const expiresAt = new Date(baseMs + durationDays * 24 * 60 * 60 * 1000);
        const expiresTs = admin.firestore.Timestamp.fromDate(expiresAt);
        const compFields = {
            isPremium: true,
            compAccessExpiresAt: expiresTs,
            compAccessSource: "access_code",
            compAccessCode: code,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        if (userSnap.exists) {
            tx.update(userRef, compFields);
        }
        else {
            // O doc do usuário ainda não existe (ex.: a criação client-side falhou —
            // problema conhecido de timing de auth no web; normalmente o trigger
            // onUserCreated já o cria). Cria aqui com os padrões + o acesso liberado.
            const token = (_e = request.auth) === null || _e === void 0 ? void 0 : _e.token;
            tx.set(userRef, Object.assign(Object.assign({}, defaultUserFields(uid, token === null || token === void 0 ? void 0 : token.email, token === null || token === void 0 ? void 0 : token.name, null)), compFields));
        }
        tx.update(codeRef, {
            usedCount: admin.firestore.FieldValue.increment(1),
            redeemedBy: admin.firestore.FieldValue.arrayUnion(uid),
            lastRedeemedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        // Auditoria (coleção server-only).
        tx.set(db.collection("voucher_redemptions").doc(), {
            uid,
            code,
            durationDays,
            grantedUntil: expiresTs,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return expiresAt.toISOString();
    });
    try {
        await writeAuditLog(uid, "access_code_redeemed", 0, "redeemAccessCode", {
            code,
            grantedUntil: expiresAtIso,
        });
    }
    catch (e) {
        v2_1.logger.warn("[redeemAccessCode] Audit log error:", e);
    }
    v2_1.logger.info(`[redeemAccessCode] uid=${uid} resgatou ${code} até ${expiresAtIso}.`);
    return { success: true, expiresAt: expiresAtIso };
});
// createAccessCodes — admin gera um lote de códigos de uso único.
exports.createAccessCodes = (0, https_1.onCall)({
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
}, async (request) => {
    var _a, _b, _c, _d;
    const uid = (_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid;
    if (!uid)
        throw new https_1.HttpsError("unauthenticated", "Usuário não autenticado.");
    await assertAdmin(uid);
    await (0, rateLimiter_1.checkRateLimit)((0, rateLimiter_1.rateLimitKey)("admin", uid, "createAccessCodes"), rateLimiter_1.RATE_ADMIN.limit, rateLimiter_1.RATE_ADMIN.windowMs);
    const count = Math.min(Math.max(Number((_b = request.data) === null || _b === void 0 ? void 0 : _b.count) || 1, 1), 100);
    const durationDays = Math.max(Number((_c = request.data) === null || _c === void 0 ? void 0 : _c.durationDays) || 30, 1);
    const label = ((_d = request.data) === null || _d === void 0 ? void 0 : _d.label) ? String(request.data.label).slice(0, 120) : null;
    const codes = [];
    const batch = db.batch();
    for (let i = 0; i < count; i++) {
        const code = genCode();
        codes.push(code);
        batch.set(db.collection("access_codes").doc(code), {
            code,
            durationDays,
            active: true,
            maxUses: 1,
            usedCount: 0,
            createdBy: uid,
            label,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            expiresAt: null,
            redeemedBy: [],
        });
    }
    await batch.commit();
    v2_1.logger.info(`[createAccessCodes] uid=${uid} gerou ${count} código(s) (${durationDays}d).`);
    return { codes };
});
// listAccessCodes — admin lista os códigos e seus status.
exports.listAccessCodes = (0, https_1.onCall)({
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
}, async (request) => {
    var _a;
    const uid = (_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid;
    if (!uid)
        throw new https_1.HttpsError("unauthenticated", "Usuário não autenticado.");
    await assertAdmin(uid);
    await (0, rateLimiter_1.checkRateLimit)((0, rateLimiter_1.rateLimitKey)("admin", uid, "listAccessCodes"), rateLimiter_1.RATE_ADMIN.limit, rateLimiter_1.RATE_ADMIN.windowMs);
    const snap = await db
        .collection("access_codes")
        .orderBy("createdAt", "desc")
        .limit(500)
        .get();
    // Resolve, de uma vez, todos os uids que resgataram qualquer código.
    const allUids = new Set();
    snap.docs.forEach((d) => { var _a; return ((_a = d.data()["redeemedBy"]) !== null && _a !== void 0 ? _a : []).forEach((u) => allUids.add(u)); });
    const infos = await resolveUserInfos([...allUids]);
    const codes = snap.docs.map((d) => {
        var _a, _b, _c, _d, _e, _f, _g;
        const c = d.data();
        const createdAt = c["createdAt"];
        const lastRedeemedAt = c["lastRedeemedAt"];
        const redeemedBy = (_a = c["redeemedBy"]) !== null && _a !== void 0 ? _a : [];
        return {
            code: d.id,
            durationDays: (_b = c["durationDays"]) !== null && _b !== void 0 ? _b : 30,
            active: (_c = c["active"]) !== null && _c !== void 0 ? _c : false,
            usedCount: (_d = c["usedCount"]) !== null && _d !== void 0 ? _d : 0,
            maxUses: (_e = c["maxUses"]) !== null && _e !== void 0 ? _e : 1,
            redeemedBy,
            // Quem resgatou (nome + email) — para o admin ver por quem cada chave foi usada.
            redeemers: redeemedBy.map((u) => { var _a; return (_a = infos.get(u)) !== null && _a !== void 0 ? _a : { uid: u, name: "", email: null }; }),
            label: (_f = c["label"]) !== null && _f !== void 0 ? _f : null,
            // Anotação livre do admin (ex.: "enviado para Fulano / escola X").
            note: (_g = c["note"]) !== null && _g !== void 0 ? _g : null,
            createdAt: createdAt ? createdAt.toDate().toISOString() : null,
            lastRedeemedAt: lastRedeemedAt ? lastRedeemedAt.toDate().toISOString() : null,
        };
    });
    return { codes };
});
// revokeAccessCode — admin desativa um código (não revoga acessos já concedidos).
exports.revokeAccessCode = (0, https_1.onCall)({
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
}, async (request) => {
    var _a, _b, _c;
    const uid = (_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid;
    if (!uid)
        throw new https_1.HttpsError("unauthenticated", "Usuário não autenticado.");
    await assertAdmin(uid);
    await (0, rateLimiter_1.checkRateLimit)((0, rateLimiter_1.rateLimitKey)("admin", uid, "revokeAccessCode"), rateLimiter_1.RATE_ADMIN.limit, rateLimiter_1.RATE_ADMIN.windowMs);
    const code = ((_c = (_b = request.data) === null || _b === void 0 ? void 0 : _b.code) !== null && _c !== void 0 ? _c : "").toString().trim().toUpperCase();
    if (!code)
        throw new https_1.HttpsError("invalid-argument", "Código é obrigatório.");
    const ref = db.collection("access_codes").doc(code);
    const snap = await ref.get();
    if (!snap.exists)
        throw new https_1.HttpsError("not-found", "Código não encontrado.");
    await ref.update({ active: false, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
    v2_1.logger.info(`[revokeAccessCode] uid=${uid} revogou ${code}.`);
    return { success: true };
});
// setAccessCodeNote — admin anota livremente em um código (ex.: "enviado para
// Fulano / escola X"). Substitui a planilha/txt de controle manual.
exports.setAccessCodeNote = (0, https_1.onCall)({
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
}, async (request) => {
    var _a, _b, _c, _d, _e;
    const uid = (_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid;
    if (!uid)
        throw new https_1.HttpsError("unauthenticated", "Usuário não autenticado.");
    await assertAdmin(uid);
    await (0, rateLimiter_1.checkRateLimit)((0, rateLimiter_1.rateLimitKey)("admin", uid, "setAccessCodeNote"), rateLimiter_1.RATE_ADMIN.limit, rateLimiter_1.RATE_ADMIN.windowMs);
    const code = ((_c = (_b = request.data) === null || _b === void 0 ? void 0 : _b.code) !== null && _c !== void 0 ? _c : "").toString().trim().toUpperCase();
    if (!code)
        throw new https_1.HttpsError("invalid-argument", "Código é obrigatório.");
    const note = ((_e = (_d = request.data) === null || _d === void 0 ? void 0 : _d.note) !== null && _e !== void 0 ? _e : "").toString().slice(0, 280);
    const ref = db.collection("access_codes").doc(code);
    const snap = await ref.get();
    if (!snap.exists)
        throw new https_1.HttpsError("not-found", "Código não encontrado.");
    await ref.update({
        note: note.length > 0 ? note : admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    v2_1.logger.info(`[setAccessCodeNote] uid=${uid} anotou ${code}.`);
    return { success: true };
});
// listUsers — admin lista todos os usuários com o plano/origem de acesso.
// Resolve nome+email via /users + Firebase Auth e classifica o plano em:
//   subscription (assinatura paga) · voucher (cortesia por código) · premium · free
exports.listUsers = (0, https_1.onCall)({
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
}, async (request) => {
    var _a;
    const uid = (_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid;
    if (!uid)
        throw new https_1.HttpsError("unauthenticated", "Usuário não autenticado.");
    await assertAdmin(uid);
    await (0, rateLimiter_1.checkRateLimit)((0, rateLimiter_1.rateLimitKey)("admin", uid, "listUsers"), rateLimiter_1.RATE_ADMIN.limit, rateLimiter_1.RATE_ADMIN.windowMs);
    // Sem orderBy — docs sem createdAt não podem ser excluídos da listagem.
    const snap = await db.collection("users").limit(1000).get();
    const infos = await resolveUserInfos(snap.docs.map((d) => d.id));
    const now = Date.now();
    const users = snap.docs.map((d) => {
        var _a, _b, _c, _d, _e, _f;
        const u = d.data();
        const info = infos.get(d.id);
        const compExp = u["compAccessExpiresAt"];
        const compActive = compExp ? compExp.toMillis() > now : false;
        const isPremium = u["isPremium"] === true;
        let plan;
        if (u["subscriptionPlanId"] != null && isPremium)
            plan = "subscription";
        else if (u["compAccessSource"] === "access_code" && compActive)
            plan = "voucher";
        else if (isPremium)
            plan = "premium";
        else
            plan = "free";
        const createdAt = u["createdAt"];
        return {
            uid: d.id,
            name: (info === null || info === void 0 ? void 0 : info.name) || "",
            email: (info === null || info === void 0 ? void 0 : info.email) || u["email"] || null,
            role: (_a = u["role"]) !== null && _a !== void 0 ? _a : "técnico",
            plan,
            isPremium,
            subscriptionPlanId: (_b = u["subscriptionPlanId"]) !== null && _b !== void 0 ? _b : null,
            compAccessSource: (_c = u["compAccessSource"]) !== null && _c !== void 0 ? _c : null,
            compAccessCode: (_d = u["compAccessCode"]) !== null && _d !== void 0 ? _d : null,
            compAccessExpiresAt: compExp ? compExp.toDate().toISOString() : null,
            weeklyXp: (_e = u["weeklyXp"]) !== null && _e !== void 0 ? _e : 0,
            xp: (_f = u["xp"]) !== null && _f !== void 0 ? _f : 0,
            createdAt: createdAt ? createdAt.toDate().toISOString() : null,
        };
    });
    v2_1.logger.info(`[listUsers] uid=${uid} listou ${users.length} usuário(s).`);
    return { users };
});
// ────────────────────────────────────────────────────────────────
// 11. processTrialExpiry — Agendada diariamente (Cloud Scheduler)
//     Revoga isPremium de todos os trials vencidos.
// ────────────────────────────────────────────────────────────────
exports.processTrialExpiry = (0, scheduler_1.onSchedule)({
    schedule: "every day 03:00",
    timeZone: "America/Sao_Paulo",
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
}, async () => {
    const now = admin.firestore.Timestamp.now();
    const nowMs = now.toMillis();
    const BATCH_LIMIT = 500; // Firestore limita um batch a 500 operações.
    // ── 1) Trials vencidos ──────────────────────────────────────
    const expiredSnap = await db
        .collection("users")
        .where("isOnTrial", "==", true)
        .where("trialEndsAt", "<=", now)
        .get();
    if (!expiredSnap.empty) {
        const docs = expiredSnap.docs;
        for (let i = 0; i < docs.length; i += BATCH_LIMIT) {
            const batch = db.batch();
            for (const doc of docs.slice(i, i + BATCH_LIMIT)) {
                // Preserva premium se houver acesso-cortesia ainda ativo.
                const comp = doc.data()["compAccessExpiresAt"];
                const compActive = !!comp && comp.toMillis() > nowMs;
                batch.update(doc.ref, {
                    isOnTrial: false,
                    isPremium: compActive,
                    trialEndsAt: null,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
            }
            await batch.commit();
        }
        v2_1.logger.info(`[processTrialExpiry] ${expiredSnap.size} trial(s) expirado(s).`);
    }
    else {
        v2_1.logger.info("[processTrialExpiry] Nenhum trial vencido.");
    }
    // ── 2) Acessos-cortesia (códigos) vencidos ──────────────────
    const compSnap = await db
        .collection("users")
        .where("compAccessExpiresAt", "<=", now)
        .get();
    if (!compSnap.empty) {
        const docs = compSnap.docs;
        for (let i = 0; i < docs.length; i += BATCH_LIMIT) {
            const batch = db.batch();
            for (const doc of docs.slice(i, i + BATCH_LIMIT)) {
                const d = doc.data();
                // Só revoga isPremium se não houver OUTRA fonte de premium
                // (assinatura paga ou trial ativo). Sempre limpa os campos comp*.
                const stillPremium = d["subscriptionPlanId"] != null || d["isOnTrial"] === true;
                batch.update(doc.ref, Object.assign(Object.assign({ compAccessExpiresAt: null, compAccessSource: null, compAccessCode: null }, (stillPremium ? {} : { isPremium: false })), { updatedAt: admin.firestore.FieldValue.serverTimestamp() }));
            }
            await batch.commit();
        }
        v2_1.logger.info(`[processTrialExpiry] ${compSnap.size} acesso(s)-cortesia expirado(s).`);
    }
});
// ────────────────────────────────────────────────────────────────
// grantAdminPremium — todo usuário com role=='admin' recebe assinatura
// premium automaticamente. Dispara em qualquer escrita no doc do usuário;
// ao detectar role=='admin' sem premium, concede isPremium + plano premium.
// Server-controlled: roda com Admin SDK, ignora as Firestore Rules.
// ────────────────────────────────────────────────────────────────
exports.grantAdminPremium = (0, firestore_2.onDocumentWritten)({ document: "users/{uid}", region: "southamerica-east1", database: "default" }, async (event) => {
    var _a;
    const after = (_a = event.data) === null || _a === void 0 ? void 0 : _a.after;
    if (!(after === null || after === void 0 ? void 0 : after.exists))
        return; // doc deletado
    const d = after.data();
    if (d["role"] !== "admin")
        return; // só admins
    const updates = {};
    if (d["isPremium"] !== true)
        updates["isPremium"] = true;
    if (d["subscriptionPlanId"] == null)
        updates["subscriptionPlanId"] = "premium";
    // Nada a alterar ⇒ não escreve (evita loop de re-disparo do trigger).
    if (Object.keys(updates).length === 0)
        return;
    updates["updatedAt"] = admin.firestore.FieldValue.serverTimestamp();
    await after.ref.update(updates);
    v2_1.logger.info(`[grantAdminPremium] Premium concedido ao admin ${event.params.uid}.`);
});
exports.checkDeviceTrust = (0, https_1.onCall)({
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
}, async (request) => {
    var _a;
    const uid = (_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid;
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "Usuário não autenticado.");
    }
    const { deviceId } = request.data;
    if (!deviceId) {
        return { trusted: false };
    }
    try {
        const deviceRef = db
            .collection("users")
            .doc(uid)
            .collection("trusted_devices")
            .doc(deviceId);
        const snap = await deviceRef.get();
        if (!snap.exists) {
            return { trusted: false };
        }
        const data = snap.data();
        // Checa expiração
        if (data["expiresAt"]) {
            const expiresAt = data["expiresAt"].toMillis();
            if (Date.now() > expiresAt) {
                // Expirado — remove em background
                deviceRef.delete().catch(() => { });
                return { trusted: false };
            }
        }
        // Atualiza lastSeenAt sem bloquear a resposta
        deviceRef.update({ lastSeenAt: admin.firestore.FieldValue.serverTimestamp() }).catch(() => { });
        v2_1.logger.info(`[checkDeviceTrust] uid=${uid} deviceId=${deviceId} trusted=true`);
        return { trusted: true };
    }
    catch (e) {
        v2_1.logger.error(`[checkDeviceTrust] Erro ao verificar dispositivo: ${e}`);
        return { trusted: false };
    }
});
exports.sendEmailVerificationCode = (0, https_1.onCall)({
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    secrets: [SMTP_USER, SMTP_PASS],
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
}, async (request) => {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j;
    // Aceita chamadas autenticadas (login) e também não-autenticadas
    // (registro antes do primeiro login) — o e-mail é validado abaixo.
    const { email } = request.data;
    if (!email || typeof email !== "string" || !email.includes("@")) {
        throw new https_1.HttpsError("invalid-argument", "E-mail inválido.");
    }
    // Rate-limit por IP (impede bombardeio de muitos e-mails distintos a
    // partir do mesmo cliente / abuso do SMTP). 5 envios / 15 min por IP.
    const ip = (_b = (_a = request.rawRequest) === null || _a === void 0 ? void 0 : _a.ip) !== null && _b !== void 0 ? _b : "unknown";
    await (0, rateLimiter_1.checkRateLimit)(`auth:ip_${ip}:sendOtp`, rateLimiter_1.RATE_AUTH.limit, rateLimiter_1.RATE_AUTH.windowMs);
    // Rate-limit simples: máx. 5 envios por hora por e-mail
    const rateLimitRef = db
        .collection("_otp_rate_limits")
        .doc(email.toLowerCase().replace(/[^a-z0-9]/g, "_"));
    const rlSnap = await rateLimitRef.get();
    if (rlSnap.exists) {
        const rlData = rlSnap.data();
        const windowStart = (_d = (_c = rlData["windowStart"]) === null || _c === void 0 ? void 0 : _c.toMillis()) !== null && _d !== void 0 ? _d : 0;
        const count = (_e = rlData["count"]) !== null && _e !== void 0 ? _e : 0;
        const now = Date.now();
        if (now - windowStart < 60 * 60 * 1000 && count >= 5) {
            throw new https_1.HttpsError("resource-exhausted", "Muitas tentativas. Aguarde 1 hora antes de solicitar um novo código.");
        }
        if (now - windowStart >= 60 * 60 * 1000) {
            // Nova janela
            await rateLimitRef.set({ windowStart: admin.firestore.Timestamp.now(), count: 1 });
        }
        else {
            await rateLimitRef.update({ count: admin.firestore.FieldValue.increment(1) });
        }
    }
    else {
        await rateLimitRef.set({ windowStart: admin.firestore.Timestamp.now(), count: 1 });
    }
    // Gera código OTP de 6 dígitos com gerador criptograficamente seguro
    const otp = String(crypto.randomInt(100000, 1000000));
    const expiresAt = admin.firestore.Timestamp.fromMillis(Date.now() + 10 * 60 * 1000); // 10 min
    // Salva o OTP no Firestore (a coleção usa o e-mail normalizado como doc ID)
    const uid = (_g = (_f = request.auth) === null || _f === void 0 ? void 0 : _f.uid) !== null && _g !== void 0 ? _g : null;
    const otpDocId = email.toLowerCase().replace(/[^a-z0-9]/g, "_");
    await db.collection("_email_otps").doc(otpDocId).set({
        email,
        code: otp,
        uid,
        expiresAt,
        attempts: 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    // Envia o e-mail via SMTP
    const smtpUser = (_h = process.env.SMTP_USER) !== null && _h !== void 0 ? _h : "";
    const smtpPass = (_j = process.env.SMTP_PASS) !== null && _j !== void 0 ? _j : "";
    if (!smtpUser || !smtpPass) {
        v2_1.logger.error("[sendEmailVerificationCode] SMTP_USER ou SMTP_PASS não configurados.");
        throw new https_1.HttpsError("internal", "Serviço de e-mail não configurado. Entre em contato com o suporte.");
    }
    const transporter = nodemailer.createTransport({
        service: "gmail",
        auth: { user: smtpUser, pass: smtpPass },
    });
    await transporter.sendMail({
        from: `"SPARK" <${smtpUser}>`,
        to: email,
        subject: "Seu código de verificação SPARK",
        html: `
        <div style="font-family:sans-serif;max-width:480px;margin:0 auto;background:#0d1117;color:#fff;padding:32px;border-radius:16px;">
          <h1 style="color:#00ff88;margin:0 0 8px;">⚡ SPARK</h1>
          <p style="color:#aaa;margin:0 0 24px;">Verificação de Identidade</p>
          <p style="margin:0 0 16px;">Use o código abaixo para confirmar seu login:</p>
          <div style="background:#1a2332;border:2px solid #00ff88;border-radius:12px;padding:24px;text-align:center;margin:0 0 24px;">
            <span style="font-size:40px;font-weight:900;letter-spacing:12px;color:#00ff88;">${otp}</span>
          </div>
          <p style="color:#aaa;font-size:13px;">Este código expira em <strong style='color:#fff;'>10 minutos</strong>.</p>
          <p style="color:#555;font-size:12px;">Se você não solicitou este código, ignore este e-mail.</p>
        </div>
      `,
    });
    v2_1.logger.info(`[sendEmailVerificationCode] OTP enviado para ${email} (uid=${uid}).`);
    return { sent: true };
});
exports.verifyEmailCode = (0, https_1.onCall)({
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
}, async (request) => {
    var _a, _b;
    const uid = (_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid;
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "Usuário não autenticado.");
    }
    // Rate limit por uid: impede brute-force do OTP (complementa o cap de
    // 5 tentativas por código já existente).
    await (0, rateLimiter_1.checkRateLimit)((0, rateLimiter_1.rateLimitKey)("auth", uid, "verifyEmailCode"), rateLimiter_1.RATE_AUTH.limit, rateLimiter_1.RATE_AUTH.windowMs);
    const { code, deviceId, deviceName } = request.data;
    if (!code || code.length !== 6) {
        return { verified: false, error: "Código inválido." };
    }
    if (!deviceId) {
        return { verified: false, error: "Identificador de dispositivo ausente." };
    }
    // Busca o OTP pelo uid do usuário autenticado
    const otpQuery = await db
        .collection("_email_otps")
        .where("uid", "==", uid)
        .orderBy("createdAt", "desc")
        .limit(1)
        .get();
    if (otpQuery.empty) {
        return { verified: false, error: "Nenhum código encontrado. Solicite um novo." };
    }
    const otpDoc = otpQuery.docs[0];
    const otp = otpDoc.data();
    // Verifica expiração
    const expiresAt = otp["expiresAt"].toMillis();
    if (Date.now() > expiresAt) {
        await otpDoc.ref.delete();
        return { verified: false, error: "Código expirado. Solicite um novo." };
    }
    // Verifica tentativas (máx. 5)
    const attempts = (_b = otp["attempts"]) !== null && _b !== void 0 ? _b : 0;
    if (attempts >= 5) {
        await otpDoc.ref.delete();
        return { verified: false, error: "Muitas tentativas. Solicite um novo código." };
    }
    // Compara o código
    if (otp["code"] !== code) {
        await otpDoc.ref.update({
            attempts: admin.firestore.FieldValue.increment(1),
        });
        const remaining = 4 - attempts;
        return {
            verified: false,
            error: `Código incorreto. ${remaining > 0 ? `${remaining} tentativa(s) restante(s).` : "Solicite um novo código."}`
        };
    }
    // Código correto — registra dispositivo confiável e remove o OTP
    const batch = db.batch();
    const deviceRef = db
        .collection("users")
        .doc(uid)
        .collection("trusted_devices")
        .doc(deviceId);
    // rememberDevice=true → 30 dias; false/omitido → 1 dia
    const rememberDevice = request.data.rememberDevice === true;
    const daysToTrust = rememberDevice ? 30 : 1;
    const deviceExpiresAt = admin.firestore.Timestamp.fromMillis(Date.now() + daysToTrust * 24 * 60 * 60 * 1000);
    batch.set(deviceRef, {
        deviceId,
        deviceName: deviceName !== null && deviceName !== void 0 ? deviceName : "Dispositivo desconhecido",
        verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: deviceExpiresAt,
        rememberDevice,
    });
    batch.delete(otpDoc.ref);
    await batch.commit();
    v2_1.logger.info(`[verifyEmailCode] uid=${uid} dispositivo ${deviceId} verificado com sucesso.`);
    return { verified: true };
});
// ────────────────────────────────────────────────────────────────
// deleteAccount — Exclui PERMANENTEMENTE a conta e todos os dados
// ────────────────────────────────────────────────────────────────
// Remove tudo que se refere ao usuário, inclusive o nome dele no
// ranking (em TODAS as semanas). Roda com Admin SDK, então ignora as
// Security Rules que bloqueiam escrita em /rankings. Ordem:
//   1. Sai do clã (transfere liderança ou apaga o clã se ficar vazio)
//   2. Apaga as entradas de ranking de todas as semanas
//   3. Apaga public_profiles/{uid}
//   4. Apaga users/{uid} + todas as subcoleções
//   5. Apaga o usuário do Firebase Auth
// ────────────────────────────────────────────────────────────────
exports.deleteAccount = (0, https_1.onCall)({
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
}, async (request) => {
    var _a, _b;
    const uid = (_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid;
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "Usuário não autenticado.");
    }
    await (0, rateLimiter_1.checkRateLimit)((0, rateLimiter_1.rateLimitKey)("auth", uid, "deleteAccount"), rateLimiter_1.RATE_AUTH.limit, rateLimiter_1.RATE_AUTH.windowMs);
    const userRef = db.collection("users").doc(uid);
    const userSnap = await userRef.get();
    const clanId = userSnap.exists
        ? (_b = userSnap.data()) === null || _b === void 0 ? void 0 : _b["clanId"]
        : undefined;
    // 1. Sai do clã
    if (clanId) {
        try {
            await removeUserFromClan(clanId, uid);
        }
        catch (e) {
            v2_1.logger.warn(`[deleteAccount] falha ao sair do clã ${clanId}:`, e);
        }
    }
    // 2. Remove o usuário do ranking em TODAS as semanas
    try {
        const weeklyDoc = db.collection("rankings").doc("weekly");
        const weekCols = await weeklyDoc.listCollections();
        await Promise.all(weekCols.map((col) => col.doc(uid).delete().catch(() => { })));
    }
    catch (e) {
        v2_1.logger.warn("[deleteAccount] falha ao limpar rankings:", e);
    }
    // 3. Apaga o perfil público
    try {
        await db.recursiveDelete(db.collection("public_profiles").doc(uid));
    }
    catch (e) {
        v2_1.logger.warn("[deleteAccount] falha ao apagar public_profile:", e);
    }
    // 4. Apaga o documento do usuário e todas as subcoleções
    try {
        await db.recursiveDelete(userRef);
    }
    catch (e) {
        v2_1.logger.warn("[deleteAccount] falha ao apagar user doc:", e);
    }
    // 5. Apaga o usuário do Firebase Auth (por último)
    try {
        await admin.auth().deleteUser(uid);
    }
    catch (e) {
        v2_1.logger.warn("[deleteAccount] falha ao apagar auth user:", e);
    }
    v2_1.logger.info(`[deleteAccount] conta ${uid} excluída permanentemente.`);
    return { ok: true };
});
// ════════════════════════════════════════════════════════════════════
//  DUELO DE FAÍSCAS (PvP) — Matchmaking + partida server-authoritative
//
//  Fluxo:
//   1. joinDuelQueue   → pareia 2 jogadores OU coloca na fila (heartbeat).
//   2. submitDuelAnswer→ valida cada resposta no servidor (anti-trapaça).
//   3. finalizeDuel    → apura vencedor e aplica ELO aos dois jogadores.
//   4. getBotDuelQuestions → perguntas (com gabarito) p/ partida de treino.
//
//  As perguntas vêm das trilhas reais (collectionGroup "questions") e são
//  sorteadas aleatoriamente. O gabarito do duelo fica numa subcoleção
//  secreta (matches/{id}/secret/key) que o cliente NÃO consegue ler.
// ════════════════════════════════════════════════════════════════════
const DUEL_QUESTION_COUNT = 8; // 7–10 perguntas por duelo
const DUEL_QUESTION_TIME_MS = 15000; // tempo por questão (igual ao app)
const DUEL_QUEUE_TTL_MS = 15000; // entrada da fila expira sem heartbeat
const DUEL_RATE = { limit: 60, windowMs: 60 * 1000 };
// ELO real (fórmula clássica de Elo). O fator K define o "peso" de cada
// partida; o teto limita variações extremas por segurança.
const DUEL_ELO_K = 32;
const DUEL_ELO_MAX = 40;
// Punição por abandono: a cada DUEL_ABANDON_LIMIT abandonos explícitos
// (leaveDuel numa partida PvP ativa), o jogador fica DUEL_COOLDOWN_MS sem
// poder entrar no matchmaking. O contador zera após aplicar o castigo.
const DUEL_ABANDON_LIMIT = 3;
const DUEL_COOLDOWN_MS = 10 * 60 * 1000; // 10 min
// Carência (ms) que o oponente tem para terminar APÓS o primeiro jogador
// concluir todas as suas perguntas, antes que o `force` de apuração seja
// aceito. Fecha a brecha de um cliente forjado encerrar o duelo no meio
// (liderando) e negar as rodadas restantes ao oponente. Fica abaixo do
// timeout de 20s do cliente para dar margem de latência.
const DUEL_FORCE_GRACE_MS = 15000;
// Cache em memória do banco de questões (warm instances) — evita varrer
// o collectionGroup a cada matchmaking.
let _questionCache = null;
let _questionCacheAt = 0;
const QUESTION_CACHE_TTL_MS = 5 * 60 * 1000;
async function loadDuelQuestionPool() {
    const now = Date.now();
    if (_questionCache && now - _questionCacheAt < QUESTION_CACHE_TTL_MS) {
        return _questionCache;
    }
    // Sem where() → não exige índice de collection-group. Filtramos em memória.
    const snap = await db
        .collectionGroup("questions")
        .select("type", "statement", "options", "correctIndex", "isActive")
        .get();
    const pool = [];
    snap.forEach((doc) => {
        const d = doc.data();
        if (d["isActive"] === false)
            return;
        if (d["type"] !== "multipleChoice")
            return; // duelo usa só múltipla escolha
        const options = d["options"];
        const correctIndex = d["correctIndex"];
        const statement = d["statement"];
        if (!Array.isArray(options) || options.length < 2)
            return;
        if (typeof correctIndex !== "number" ||
            correctIndex < 0 ||
            correctIndex >= options.length) {
            return;
        }
        if (typeof statement !== "string" || statement.trim() === "")
            return;
        pool.push({
            id: doc.id,
            statement: statement.trim(),
            options: options.map((o) => String(o)),
            correctIndex,
        });
    });
    _questionCache = pool;
    _questionCacheAt = now;
    v2_1.logger.info(`[duel] pool de questões recarregado: ${pool.length} válidas`);
    return pool;
}
function pickRandomDuelQuestions(pool, count) {
    const arr = [...pool];
    for (let i = arr.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [arr[i], arr[j]] = [arr[j], arr[i]];
    }
    return arr.slice(0, Math.min(count, arr.length));
}
/** Pontuação de uma rodada — espelha o cálculo do app. */
function duelRoundScore(isCorrect, timeMs) {
    if (!isCorrect)
        return 0;
    const clamped = Math.max(0, Math.min(DUEL_QUESTION_TIME_MS, timeMs));
    return Math.max(0, Math.min(100, 100 - clamped / 100));
}
function sumDuelScores(answers) {
    return answers.reduce((acc, a) => { var _a; return acc + ((_a = a["score"]) !== null && _a !== void 0 ? _a : 0); }, 0);
}
async function fetchPlayerCard(uid) {
    var _a, _b, _c;
    try {
        const snap = await db.collection("users").doc(uid).get();
        const d = (_a = snap.data()) !== null && _a !== void 0 ? _a : {};
        return {
            name: d["displayName"] || d["name"] || "Jogador",
            photo: (_b = d["photoUrl"]) !== null && _b !== void 0 ? _b : null,
            elo: (_c = d["eloRating"]) !== null && _c !== void 0 ? _c : 0,
        };
    }
    catch (_d) {
        return { name: "Jogador", photo: null, elo: 0 };
    }
}
class OpponentTakenError extends Error {
}
/** Lançada quando, dentro da transação de pareamento, descobrimos que o
 *  PRÓPRIO iniciador já foi pareado por outro jogador. Evita criar uma
 *  segunda partida (duplo-pareamento) numa corrida de heartbeat. */
class AlreadyMatchedError extends Error {
    constructor(matchId) {
        super("already matched");
        this.matchId = matchId;
    }
}
// ────────────────────────────────────────────────────────────────
// sendPushToUser — Dispara um push FCM (best-effort) para o usuário.
// Lê o token salvo em users/{uid}.fcmToken (gravado pelo FcmService no
// app). É COMPLEMENTAR à notificação in-app: falha de push nunca pode
// derrubar o fluxo principal (premiação, pareamento etc.), por isso
// engole o erro. Se o token estiver morto (app desinstalado/expirado),
// limpa o campo para não insistir em envios fadados a falhar.
// ────────────────────────────────────────────────────────────────
async function sendPushToUser(uid, payload) {
    var _a, _b;
    try {
        const snap = await db.collection("users").doc(uid).get();
        const token = snap.get("fcmToken");
        if (!token)
            return;
        await admin.messaging().send({
            token,
            notification: { title: payload.title, body: payload.body },
            data: (_a = payload.data) !== null && _a !== void 0 ? _a : {},
            android: { priority: "high", notification: { sound: "default" } },
            apns: {
                headers: { "apns-priority": "10" },
                payload: { aps: { sound: "default" } },
            },
        });
    }
    catch (e) {
        const code = (_b = e === null || e === void 0 ? void 0 : e.code) !== null && _b !== void 0 ? _b : "";
        // Token inválido/expirado → remove para não tentar de novo.
        if (code === "messaging/registration-token-not-registered" ||
            code === "messaging/invalid-registration-token" ||
            code === "messaging/invalid-argument") {
            await db
                .collection("users")
                .doc(uid)
                .update({ fcmToken: admin.firestore.FieldValue.delete() })
                .catch(() => undefined);
        }
        v2_1.logger.warn(`[sendPushToUser] uid=${uid} push falhou:`, e);
    }
}
exports.joinDuelQueue = (0, https_1.onCall)({
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
}, async (request) => {
    var _a, _b, _c, _d, _e, _f, _g;
    const uid = (_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid;
    if (!uid)
        throw new https_1.HttpsError("unauthenticated", "Usuário não autenticado.");
    await (0, rateLimiter_1.checkRateLimit)((0, rateLimiter_1.rateLimitKey)("gamification", uid, "joinDuelQueue"), DUEL_RATE.limit, DUEL_RATE.windowMs);
    // Cooldown por abandono: jogador "de castigo" não entra no matchmaking.
    const meSnap = await db.collection("users").doc(uid).get();
    const cooldownUntil = meSnap.get("duelCooldownUntil");
    if (cooldownUntil && cooldownUntil.toMillis() > Date.now()) {
        const remainingMs = cooldownUntil.toMillis() - Date.now();
        throw new https_1.HttpsError("resource-exhausted", "Você abandonou partidas demais. Aguarde o cooldown para jogar de novo.", { cooldownUntil: cooldownUntil.toMillis(), remainingMs });
    }
    const myQueueRef = db.collection("matchmaking_queue").doc(uid);
    const now = Date.now();
    // (a) Já fui pareado por outro jogador enquanto esperava?
    const mySnap = await myQueueRef.get();
    let staleCleared = false;
    const existingMatchId = (_b = mySnap.data()) === null || _b === void 0 ? void 0 : _b["matchId"];
    if (existingMatchId) {
        // Só recoloca na partida se ela AINDA existe e está ativa. Caso contrário
        // (partida encerrada/abandonada), a entrada está velha: limpa e segue para
        // um novo pareamento — senão o jogador cairia numa "partida fantasma".
        const existingSnap = await db.collection("matches").doc(existingMatchId).get();
        if (existingSnap.exists && ((_c = existingSnap.data()) === null || _c === void 0 ? void 0 : _c["status"]) === "active") {
            return { status: "matched", matchId: existingMatchId };
        }
        await myQueueRef.delete().catch(() => undefined);
        staleCleared = true;
    }
    // (b) Procura um oponente esperando (mais antigo primeiro).
    const candidates = await db
        .collection("matchmaking_queue")
        .orderBy("joinedAt", "asc")
        .limit(10)
        .get();
    let opponentRef = null;
    for (const doc of candidates.docs) {
        if (doc.id === uid)
            continue;
        const d = doc.data();
        if (d["matchId"])
            continue; // já pareado
        const lastSeen = (_e = (_d = d["lastSeen"]) === null || _d === void 0 ? void 0 : _d.toMillis()) !== null && _e !== void 0 ? _e : 0;
        if (now - lastSeen > DUEL_QUEUE_TTL_MS) {
            // Entrada morta — limpa de forma best-effort.
            doc.ref.delete().catch(() => undefined);
            continue;
        }
        opponentRef = doc.ref;
        break;
    }
    // (c) Encontrou oponente → tenta parear atomicamente.
    if (opponentRef) {
        try {
            const pool = await loadDuelQuestionPool();
            if (pool.length < DUEL_QUESTION_COUNT) {
                throw new https_1.HttpsError("failed-precondition", "Não há perguntas suficientes cadastradas para um duelo.");
            }
            const picked = pickRandomDuelQuestions(pool, DUEL_QUESTION_COUNT);
            const [meCard, oppCard] = await Promise.all([
                fetchPlayerCard(uid),
                fetchPlayerCard(opponentRef.id),
            ]);
            const matchRef = db.collection("matches").doc();
            const oppUid = opponentRef.id;
            await db.runTransaction(async (tx) => {
                var _a, _b, _c;
                const [oppDoc, myDoc] = await Promise.all([
                    tx.get(opponentRef),
                    tx.get(myQueueRef),
                ]);
                // Corrida de heartbeat: outro jogador me pareou enquanto eu procurava
                // um oponente. NÃO crio uma segunda partida — devolvo a que já existe.
                const myMatchId = (_a = myDoc.data()) === null || _a === void 0 ? void 0 : _a["matchId"];
                if (myMatchId)
                    throw new AlreadyMatchedError(myMatchId);
                if (!oppDoc.exists)
                    throw new OpponentTakenError();
                const od = oppDoc.data();
                if (od["matchId"])
                    throw new OpponentTakenError();
                const lastSeen = (_c = (_b = od["lastSeen"]) === null || _b === void 0 ? void 0 : _b.toMillis()) !== null && _c !== void 0 ? _c : 0;
                if (now - lastSeen > DUEL_QUEUE_TTL_MS)
                    throw new OpponentTakenError();
                // Doc do match — questões SEM gabarito.
                tx.set(matchRef, {
                    player1Uid: oppUid, // quem esperava entra como player1
                    player2Uid: uid,
                    player1Name: oppCard.name,
                    player2Name: meCard.name,
                    player1Photo: oppCard.photo,
                    player2Photo: meCard.photo,
                    player1Elo: oppCard.elo,
                    player2Elo: meCard.elo,
                    status: "active",
                    isBot: false,
                    questions: picked.map((q) => ({
                        id: q.id,
                        statement: q.statement,
                        options: q.options,
                    })),
                    player1Scores: [],
                    player2Scores: [],
                    player1Done: false,
                    player2Done: false,
                    winnerId: null,
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                    finishedAt: null,
                });
                // Gabarito secreto (regras bloqueiam leitura do cliente).
                tx.set(matchRef.collection("secret").doc("key"), {
                    answers: picked.map((q) => q.correctIndex),
                });
                // Avisa o jogador que esperava (listener da fila dele).
                tx.set(opponentRef, { matchId: matchRef.id, status: "matched" }, { merge: true });
                // Eu (iniciador) saio da fila.
                tx.delete(myQueueRef);
            });
            v2_1.logger.info(`[joinDuelQueue] match ${matchRef.id}: ${oppUid} vs ${uid}`);
            // Avisa por push o jogador que ESTAVA esperando (oppUid): o iniciador
            // já está com o app aberto, mas o oponente pode tê-lo em background.
            await sendPushToUser(oppUid, {
                title: "⚔️ Você foi pareado para um duelo!",
                body: `${meCard.name} entrou na arena. Abra o Spark e dispute!`,
                data: { type: "duel_matched", matchId: matchRef.id },
            });
            return { status: "matched", matchId: matchRef.id };
        }
        catch (e) {
            // Já fui pareado por outro durante a transação → devolvo essa partida.
            if (e instanceof AlreadyMatchedError) {
                return { status: "matched", matchId: e.matchId };
            }
            if (!(e instanceof OpponentTakenError))
                throw e;
            // Oponente foi pego por outro — cai para enfileirar.
        }
    }
    // (d) Sem oponente → entra/atualiza a fila (heartbeat).
    await myQueueRef.set({
        uid,
        status: "waiting",
        matchId: null,
        joinedAt: mySnap.exists && !staleCleared
            ? (_g = (_f = mySnap.data()) === null || _f === void 0 ? void 0 : _f["joinedAt"]) !== null && _g !== void 0 ? _g : admin.firestore.FieldValue.serverTimestamp()
            : admin.firestore.FieldValue.serverTimestamp(),
        lastSeen: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return { status: "waiting" };
});
// ── 2. leaveDuelQueue ───────────────────────────────────────────────
exports.leaveDuelQueue = (0, https_1.onCall)({
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
}, async (request) => {
    var _a;
    const uid = (_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid;
    if (!uid)
        throw new https_1.HttpsError("unauthenticated", "Usuário não autenticado.");
    await db.collection("matchmaking_queue").doc(uid).delete().catch(() => undefined);
    return { ok: true };
});
exports.submitDuelAnswer = (0, https_1.onCall)({
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
}, async (request) => {
    var _a;
    const uid = (_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid;
    if (!uid)
        throw new https_1.HttpsError("unauthenticated", "Usuário não autenticado.");
    await (0, rateLimiter_1.checkRateLimit)((0, rateLimiter_1.rateLimitKey)("gamification", uid, "submitDuelAnswer"), DUEL_RATE.limit, DUEL_RATE.windowMs);
    const { matchId, questionIndex, selectedOption, elapsedMs } = request.data;
    if (typeof matchId !== "string" || !matchId) {
        throw new https_1.HttpsError("invalid-argument", "matchId inválido.");
    }
    if (typeof questionIndex !== "number" || questionIndex < 0) {
        throw new https_1.HttpsError("invalid-argument", "questionIndex inválido.");
    }
    const matchRef = db.collection("matches").doc(matchId);
    const keyRef = matchRef.collection("secret").doc("key");
    let result;
    await db.runTransaction(async (tx) => {
        var _a, _b, _c, _d, _e;
        const [matchSnap, keySnap] = await Promise.all([
            tx.get(matchRef),
            tx.get(keyRef),
        ]);
        if (!matchSnap.exists)
            throw new https_1.HttpsError("not-found", "Duelo não encontrado.");
        const m = matchSnap.data();
        const isP1 = m["player1Uid"] === uid;
        const isP2 = m["player2Uid"] === uid;
        if (!isP1 && !isP2) {
            throw new https_1.HttpsError("permission-denied", "Você não participa deste duelo.");
        }
        if (m["status"] !== "active") {
            throw new https_1.HttpsError("failed-precondition", "Duelo já encerrado.");
        }
        const questions = (_a = m["questions"]) !== null && _a !== void 0 ? _a : [];
        if (questionIndex >= questions.length) {
            throw new https_1.HttpsError("invalid-argument", "Índice de questão fora do intervalo.");
        }
        const scoresField = isP1 ? "player1Scores" : "player2Scores";
        const doneField = isP1 ? "player1Done" : "player2Done";
        const answers = (_b = m[scoresField]) !== null && _b !== void 0 ? _b : [];
        // Anti-replay: só aceita a próxima questão esperada, em ordem.
        if (questionIndex !== answers.length) {
            throw new https_1.HttpsError("failed-precondition", "Resposta fora de ordem ou duplicada.");
        }
        const answerKey = (_d = (_c = keySnap.data()) === null || _c === void 0 ? void 0 : _c["answers"]) !== null && _d !== void 0 ? _d : [];
        const correctIndex = (_e = answerKey[questionIndex]) !== null && _e !== void 0 ? _e : -1;
        const isCorrect = selectedOption === correctIndex;
        const timeMs = Math.max(0, Math.min(DUEL_QUESTION_TIME_MS, elapsedMs !== null && elapsedMs !== void 0 ? elapsedMs : DUEL_QUESTION_TIME_MS));
        const score = duelRoundScore(isCorrect, timeMs);
        const round = {
            q: questionIndex,
            selectedOption: typeof selectedOption === "number" ? selectedOption : -1,
            isCorrect,
            timeMs,
            score,
        };
        const updates = {
            [scoresField]: admin.firestore.FieldValue.arrayUnion(round),
        };
        if (questionIndex === questions.length - 1) {
            updates[doneField] = true;
            // Marca quando o PRIMEIRO jogador terminou todas as perguntas — é o
            // marco a partir do qual o `force` de apuração ganha carência.
            if (!m["firstDoneAt"]) {
                updates["firstDoneAt"] = admin.firestore.FieldValue.serverTimestamp();
            }
        }
        tx.update(matchRef, updates);
        result = { isCorrect, correctIndex, score };
    });
    return result;
});
exports.finalizeDuel = (0, https_1.onCall)({
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
}, async (request) => {
    var _a, _b;
    const uid = (_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid;
    if (!uid)
        throw new https_1.HttpsError("unauthenticated", "Usuário não autenticado.");
    await (0, rateLimiter_1.checkRateLimit)((0, rateLimiter_1.rateLimitKey)("gamification", uid, "finalizeDuel"), DUEL_RATE.limit, DUEL_RATE.windowMs);
    const { matchId, force } = request.data;
    if (typeof matchId !== "string" || !matchId) {
        throw new https_1.HttpsError("invalid-argument", "matchId inválido.");
    }
    const matchRef = db.collection("matches").doc(matchId);
    let result;
    await db.runTransaction(async (tx) => {
        var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k, _l, _m, _o;
        const matchSnap = await tx.get(matchRef);
        if (!matchSnap.exists)
            throw new https_1.HttpsError("not-found", "Duelo não encontrado.");
        const m = matchSnap.data();
        const p1 = m["player1Uid"];
        const p2 = m["player2Uid"];
        if (uid !== p1 && uid !== p2) {
            throw new https_1.HttpsError("permission-denied", "Você não participa deste duelo.");
        }
        const p1Answers = (_a = m["player1Scores"]) !== null && _a !== void 0 ? _a : [];
        const p2Answers = (_b = m["player2Scores"]) !== null && _b !== void 0 ? _b : [];
        const total = (_d = (_c = m["questions"]) === null || _c === void 0 ? void 0 : _c.length) !== null && _d !== void 0 ? _d : DUEL_QUESTION_COUNT;
        const p1Total = sumDuelScores(p1Answers);
        const p2Total = sumDuelScores(p2Answers);
        // Já finalizado → idempotente.
        if (m["status"] === "finished") {
            const isP1 = uid === p1;
            const myChange = (_e = m[isP1 ? "player1EloChange" : "player2EloChange"]) !== null && _e !== void 0 ? _e : 0;
            result = {
                status: "finished",
                winnerId: (_f = m["winnerId"]) !== null && _f !== void 0 ? _f : null,
                player1Total: p1Total,
                player2Total: p2Total,
                eloChange: myChange,
            };
            return;
        }
        const bothDone = p1Answers.length >= total && p2Answers.length >= total;
        if (!bothDone) {
            if (!force) {
                // Ainda esperando o oponente terminar.
                result = { status: "waiting" };
                return;
            }
            // ── Validação do `force` (anti-trapaça) ───────────────────────
            // (a) quem força PRECISA ter concluído as próprias perguntas: impede
            //     um cliente forjado liderando encerrar no meio e negar rodadas.
            const callerAnswers = uid === p1 ? p1Answers : p2Answers;
            if (callerAnswers.length < total) {
                throw new https_1.HttpsError("failed-precondition", "Conclua suas perguntas antes de encerrar o duelo.");
            }
            // (b) o oponente precisa ter tido um período de carência para terminar
            //     APÓS o primeiro a concluir. Sem o marco `firstDoneAt` (docs
            //     legados), exige a duração máxima honesta desde a criação.
            const firstDoneMs = (_g = m["firstDoneAt"]) === null || _g === void 0 ? void 0 : _g.toMillis();
            const createdMs = (_h = m["createdAt"]) === null || _h === void 0 ? void 0 : _h.toMillis();
            const since = (_j = firstDoneMs !== null && firstDoneMs !== void 0 ? firstDoneMs : createdMs) !== null && _j !== void 0 ? _j : 0;
            const graceMs = firstDoneMs
                ? DUEL_FORCE_GRACE_MS
                : total * DUEL_QUESTION_TIME_MS;
            if (since === 0 || Date.now() - since < graceMs) {
                // Ainda cedo para forçar — segue aguardando (cliente tenta de novo).
                result = { status: "waiting" };
                return;
            }
        }
        // Apura vencedor.
        let winnerId = null;
        if (p1Total > p2Total)
            winnerId = p1;
        else if (p2Total > p1Total)
            winnerId = p2;
        const p1Ref = db.collection("users").doc(p1);
        const p2Ref = db.collection("users").doc(p2);
        const [p1Snap, p2Snap] = await Promise.all([tx.get(p1Ref), tx.get(p2Ref)]);
        const p1Elo = (_l = (_k = p1Snap.data()) === null || _k === void 0 ? void 0 : _k["eloRating"]) !== null && _l !== void 0 ? _l : 0;
        const p2Elo = (_o = (_m = p2Snap.data()) === null || _m === void 0 ? void 0 : _m["eloRating"]) !== null && _o !== void 0 ? _o : 0;
        // ELO real: ganha-se MAIS batendo quem é mais forte e perde-se MENOS
        // perdendo para quem é mais forte (e vice-versa).
        const expected1 = 1 / (1 + Math.pow(10, (p2Elo - p1Elo) / 400));
        const expected2 = 1 - expected1;
        const s1 = winnerId === null ? 0.5 : winnerId === p1 ? 1 : 0;
        const s2 = 1 - s1;
        const clampChange = (raw, currentElo) => {
            const capped = Math.max(-DUEL_ELO_MAX, Math.min(DUEL_ELO_MAX, Math.round(raw)));
            return Math.max(capped, -currentElo); // ELO nunca fica negativo
        };
        const p1Change = clampChange(DUEL_ELO_K * (s1 - expected1), p1Elo);
        const p2Change = clampChange(DUEL_ELO_K * (s2 - expected2), p2Elo);
        const applyElo = (ref, snap, change, won) => {
            var _a, _b;
            if (!snap.exists)
                return;
            const data = snap.data();
            const updates = {
                eloRating: admin.firestore.FieldValue.increment(change),
                totalDuels: admin.firestore.FieldValue.increment(1),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            };
            if (won === true)
                updates["wins"] = admin.firestore.FieldValue.increment(1);
            else if (won === false)
                updates["losses"] = admin.firestore.FieldValue.increment(1);
            const unlocked = (_a = data["unlockedBadgeIds"]) !== null && _a !== void 0 ? _a : [];
            if (((_b = data["totalDuels"]) !== null && _b !== void 0 ? _b : 0) === 0 && !unlocked.includes("primeiro_duelo")) {
                updates["unlockedBadgeIds"] = admin.firestore.FieldValue.arrayUnion("primeiro_duelo");
            }
            tx.update(ref, updates);
        };
        applyElo(p1Ref, p1Snap, p1Change, winnerId === null ? null : winnerId === p1);
        applyElo(p2Ref, p2Snap, p2Change, winnerId === null ? null : winnerId === p2);
        tx.update(matchRef, {
            status: "finished",
            winnerId,
            player1EloChange: p1Change,
            player2EloChange: p2Change,
            finishedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        // Limpa as entradas de fila dos dois jogadores: ao parear, o doc de fila
        // de quem esperava (player1) fica com o `matchId` gravado. Sem apagá-lo
        // aqui, reabrir o PvP recolocaria o jogador na partida JÁ encerrada.
        tx.delete(db.collection("matchmaking_queue").doc(p1));
        tx.delete(db.collection("matchmaking_queue").doc(p2));
        const isP1 = uid === p1;
        result = {
            status: "finished",
            winnerId,
            player1Total: p1Total,
            player2Total: p2Total,
            eloChange: isP1 ? p1Change : p2Change,
        };
    });
    v2_1.logger.info(`[finalizeDuel] match=${matchId} status=${result.status} winner=${(_b = result.winnerId) !== null && _b !== void 0 ? _b : "-"}`);
    return result;
});
exports.leaveDuel = (0, https_1.onCall)({
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
}, async (request) => {
    var _a, _b;
    const uid = (_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid;
    if (!uid)
        throw new https_1.HttpsError("unauthenticated", "Usuário não autenticado.");
    await (0, rateLimiter_1.checkRateLimit)((0, rateLimiter_1.rateLimitKey)("gamification", uid, "leaveDuel"), DUEL_RATE.limit, DUEL_RATE.windowMs);
    const { matchId } = (_b = request.data) !== null && _b !== void 0 ? _b : {};
    if (typeof matchId !== "string" || !matchId) {
        throw new https_1.HttpsError("invalid-argument", "matchId inválido.");
    }
    const matchRef = db.collection("matches").doc(matchId);
    let finished = false;
    await db.runTransaction(async (tx) => {
        var _a, _b, _c, _d, _e, _f;
        const matchSnap = await tx.get(matchRef);
        if (!matchSnap.exists)
            return; // nada a fazer
        const m = matchSnap.data();
        const p1 = m["player1Uid"];
        const p2 = m["player2Uid"];
        if (uid !== p1 && uid !== p2) {
            throw new https_1.HttpsError("permission-denied", "Você não participa deste duelo.");
        }
        // Já encerrado (quem chegou primeiro decide) ou treino → ignora.
        if (m["status"] !== "active" || m["isBot"] === true)
            return;
        // Quem SAI perde; o oponente que CONTINUOU vence.
        const winnerId = uid === p1 ? p2 : p1;
        const p1Ref = db.collection("users").doc(p1);
        const p2Ref = db.collection("users").doc(p2);
        const [p1Snap, p2Snap] = await Promise.all([tx.get(p1Ref), tx.get(p2Ref)]);
        const p1Elo = (_b = (_a = p1Snap.data()) === null || _a === void 0 ? void 0 : _a["eloRating"]) !== null && _b !== void 0 ? _b : 0;
        const p2Elo = (_d = (_c = p2Snap.data()) === null || _c === void 0 ? void 0 : _c["eloRating"]) !== null && _d !== void 0 ? _d : 0;
        const expected1 = 1 / (1 + Math.pow(10, (p2Elo - p1Elo) / 400));
        const expected2 = 1 - expected1;
        const s1 = winnerId === p1 ? 1 : 0;
        const s2 = 1 - s1;
        const clampChange = (raw, currentElo) => {
            const capped = Math.max(-DUEL_ELO_MAX, Math.min(DUEL_ELO_MAX, Math.round(raw)));
            return Math.max(capped, -currentElo); // ELO nunca fica negativo
        };
        const p1Change = clampChange(DUEL_ELO_K * (s1 - expected1), p1Elo);
        const p2Change = clampChange(DUEL_ELO_K * (s2 - expected2), p2Elo);
        // ── Castigo por abandono ao jogador que SAIU (uid) ──────────────
        // Conta o abandono; ao atingir o limite, aplica o cooldown e zera o
        // contador (dá novas "vidas" depois de cumprir o castigo).
        const abandonerIsP1 = uid === p1;
        const abandonerSnap = abandonerIsP1 ? p1Snap : p2Snap;
        const priorAbandons = (_f = (_e = abandonerSnap.data()) === null || _e === void 0 ? void 0 : _e["duelAbandons"]) !== null && _f !== void 0 ? _f : 0;
        const newAbandons = priorAbandons + 1;
        const abandonUpdates = newAbandons >= DUEL_ABANDON_LIMIT
            ? {
                duelAbandons: 0,
                duelCooldownUntil: admin.firestore.Timestamp.fromMillis(Date.now() + DUEL_COOLDOWN_MS),
            }
            : { duelAbandons: newAbandons };
        const applyElo = (ref, snap, change, won, extra) => {
            var _a, _b;
            if (!snap.exists)
                return;
            const data = snap.data();
            const updates = Object.assign({ eloRating: admin.firestore.FieldValue.increment(change), totalDuels: admin.firestore.FieldValue.increment(1), updatedAt: admin.firestore.FieldValue.serverTimestamp() }, (extra !== null && extra !== void 0 ? extra : {}));
            if (won)
                updates["wins"] = admin.firestore.FieldValue.increment(1);
            else
                updates["losses"] = admin.firestore.FieldValue.increment(1);
            const unlocked = (_a = data["unlockedBadgeIds"]) !== null && _a !== void 0 ? _a : [];
            if (((_b = data["totalDuels"]) !== null && _b !== void 0 ? _b : 0) === 0 && !unlocked.includes("primeiro_duelo")) {
                updates["unlockedBadgeIds"] = admin.firestore.FieldValue.arrayUnion("primeiro_duelo");
            }
            tx.update(ref, updates);
        };
        applyElo(p1Ref, p1Snap, p1Change, winnerId === p1, abandonerIsP1 ? abandonUpdates : undefined);
        applyElo(p2Ref, p2Snap, p2Change, winnerId === p2, abandonerIsP1 ? undefined : abandonUpdates);
        tx.update(matchRef, {
            status: "finished",
            winnerId,
            abandonedBy: uid,
            player1EloChange: p1Change,
            player2EloChange: p2Change,
            finishedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        // Limpa as filas dos dois (mesmo motivo do finalizeDuel).
        tx.delete(db.collection("matchmaking_queue").doc(p1));
        tx.delete(db.collection("matchmaking_queue").doc(p2));
        finished = true;
    });
    v2_1.logger.info(`[leaveDuel] match=${matchId} abandonedBy=${uid} finished=${finished}`);
    return { ok: true, finished };
});
exports.getBotDuelQuestions = (0, https_1.onCall)({
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
}, async (request) => {
    var _a, _b, _c;
    const uid = (_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid;
    if (!uid)
        throw new https_1.HttpsError("unauthenticated", "Usuário não autenticado.");
    await (0, rateLimiter_1.checkRateLimit)((0, rateLimiter_1.rateLimitKey)("gamification", uid, "getBotDuelQuestions"), DUEL_RATE.limit, DUEL_RATE.windowMs);
    const count = Math.max(3, Math.min(15, (_c = (_b = request.data) === null || _b === void 0 ? void 0 : _b.count) !== null && _c !== void 0 ? _c : DUEL_QUESTION_COUNT));
    const pool = await loadDuelQuestionPool();
    if (pool.length === 0) {
        throw new https_1.HttpsError("failed-precondition", "Não há perguntas cadastradas para o duelo.");
    }
    return { questions: pickRandomDuelQuestions(pool, count) };
});
// ────────────────────────────────────────────────────────────────
// syncPublicProfile — Espelha campos PÚBLICOS de users/{uid} em
// public_profiles/{uid} (LGPD: /users é privado; o espelho público
// não carrega e-mail, dados de pagamento nem tokens).
// As Security Rules deixam public_profiles como write:false (só o
// servidor escreve), e este trigger é o ÚNICO escritor. Sem ele a
// coleção fica vazia e o ranking all-time / telas de perfil quebram.
// (Recuperado: foi removido por engano no merge da PR #19/spark-admin.)
// ────────────────────────────────────────────────────────────────
/** Campos espelhados em public_profiles. Qualquer outro fica fora (PII). */
const PUBLIC_PROFILE_FIELDS = [
    "displayName",
    "photoUrl",
    "profession",
    "xp",
    "level",
    "tensionLevel",
    "weeklyXp",
    "monthlyXp",
    "eloRating",
    "clanId",
    "clanName",
    "unlockedBadgeIds",
    // Streak exibido no perfil público (patente/ofensiva). Sem espelhar,
    // a tela de perfil público mostraria sempre 0.
    "currentStreak",
    "longestStreak",
    // Módulo que o usuário está estudando agora. Necessário para a "presença
    // do clã" (learning_path_screen consulta public_profiles por clanId +
    // currentModuleId). Sem espelhar este campo, a query sempre vinha vazia.
    "currentModuleId",
];
/** Extrai apenas os campos públicos de um doc de usuário. */
function pickPublicFields(data) {
    const out = {};
    for (const key of PUBLIC_PROFILE_FIELDS) {
        if (data[key] !== undefined)
            out[key] = data[key];
    }
    return out;
}
exports.syncPublicProfile = (0, firestore_2.onDocumentWritten)({
    document: "users/{uid}",
    // Este projeto usa um banco Firestore NOMEADO ("default"), não o
    // "(default)". Sem declarar isto o deploy do trigger falha com 404
    // ("database '(default)' does not exist") e o gatilho nunca dispara.
    database: "default",
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
}, async (event) => {
    var _a, _b, _c, _d, _e, _f, _g;
    const uid = event.params.uid;
    const publicRef = db.collection("public_profiles").doc(uid);
    const after = (_a = event.data) === null || _a === void 0 ? void 0 : _a.after;
    // Documento de usuário foi apagado → remove o espelho público.
    // (deleteAccount já remove explicitamente, mas isto cobre exclusões diretas.)
    if (!after || !after.exists) {
        await publicRef.delete().catch(() => { });
        v2_1.logger.info(`[syncPublicProfile] uid=${uid} removido (user apagado).`);
        return;
    }
    const afterData = (_b = after.data()) !== null && _b !== void 0 ? _b : {};
    // Contas de admin/teste NÃO aparecem em nenhum ranking (Global, Torneio
    // ou clã, que leem public_profiles). Remove o espelho e sai.
    if (afterData["role"] === "admin" || afterData["excludeFromRanking"] === true) {
        await publicRef.delete().catch(() => { });
        v2_1.logger.info(`[syncPublicProfile] uid=${uid} excluído do ranking (admin/teste).`);
        return;
    }
    const newPublic = pickPublicFields(afterData);
    // Garante que os campos de ordenação dos rankings sempre existam — sem
    // eles o documento some do orderBy('xp')/orderBy('weeklyXp').
    if (newPublic["xp"] === undefined)
        newPublic["xp"] = 0;
    if (newPublic["weeklyXp"] === undefined)
        newPublic["weeklyXp"] = 0;
    // Evita escritas desnecessárias (e loops de custo): só grava se algum
    // campo público realmente mudou em relação ao estado anterior.
    const beforeData = (_e = (_d = (_c = event.data) === null || _c === void 0 ? void 0 : _c.before) === null || _d === void 0 ? void 0 : _d.data()) !== null && _e !== void 0 ? _e : {};
    const oldPublic = pickPublicFields(beforeData);
    const changed = PUBLIC_PROFILE_FIELDS.some((k) => JSON.stringify(oldPublic[k]) !== JSON.stringify(newPublic[k]));
    if (((_g = (_f = event.data) === null || _f === void 0 ? void 0 : _f.before) === null || _g === void 0 ? void 0 : _g.exists) && !changed) {
        return;
    }
    newPublic["uid"] = uid;
    newPublic["updatedAt"] = admin.firestore.FieldValue.serverTimestamp();
    await publicRef.set(newPublic, { merge: true });
    v2_1.logger.info(`[syncPublicProfile] uid=${uid} espelho público atualizado.`);
});
// ────────────────────────────────────────────────────────────────
// closeTournament — Agendada na virada de segunda. Encerra o torneio
// SEMANAL: premia o top 3 por weeklyXp, notifica os vencedores (popup
// no app), arquiva o pódio final e ZERA weeklyXp de todos para começar
// a nova semana.
//
// O Ranking GLOBAL (por xp total) e o Torneio (por weeklyXp) são lidos
// direto de public_profiles — os nomes/posições nunca são apagados,
// apenas o weeklyXp é resetado aqui para reiniciar a competição.
// ────────────────────────────────────────────────────────────────
// Premiação do torneio: 1º, 2º, 3º lugar (XP somado ao total).
const TOURNAMENT_PRIZES = [500, 250, 100];
exports.closeTournament = (0, scheduler_1.onSchedule)({
    // 00:05 de segunda (BRT) — logo após a virada da semana.
    schedule: "every monday 00:05",
    timeZone: "America/Sao_Paulo",
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
}, async () => {
    var _a, _b, _c, _d;
    const weekKey = lastWeekKey();
    // 1) Top 3 por weeklyXp (apenas quem realmente pontuou).
    const topSnap = await db
        .collection("public_profiles")
        .orderBy("weeklyXp", "desc")
        .limit(3)
        .get();
    const winners = topSnap.docs.filter((d) => { var _a; return ((_a = d.get("weeklyXp")) !== null && _a !== void 0 ? _a : 0) > 0; });
    const historyCol = db
        .collection("rankings")
        .doc("tournament_history")
        .collection(weekKey);
    for (let i = 0; i < winners.length; i++) {
        const doc = winners[i];
        const uid = doc.id;
        const place = i + 1;
        const prize = (_a = TOURNAMENT_PRIZES[i]) !== null && _a !== void 0 ? _a : 0;
        const finalWeeklyXp = (_b = doc.get("weeklyXp")) !== null && _b !== void 0 ? _b : 0;
        try {
            // Premia o XP total (cascateia para public_profiles via trigger).
            await db.collection("users").doc(uid).set({
                xp: admin.firestore.FieldValue.increment(prize),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
            // Notificação que dispara o popup animado de vitória no app.
            await db
                .collection("users")
                .doc(uid)
                .collection("notifications")
                .add({
                type: "tournament_win",
                place,
                prize,
                weekKey,
                weeklyXp: finalWeeklyXp,
                read: false,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            // Push do resultado do torneio (o popup animado continua sendo
            // disparado in-app pela notificação acima; aqui é só o aviso externo).
            await sendPushToUser(uid, {
                title: place === 1
                    ? "🥇 Você venceu o torneio semanal!"
                    : `🏆 ${place}º lugar no torneio semanal!`,
                body: `Parabéns! Você ganhou ${prize} XP. Veja o pódio no Spark.`,
                data: {
                    type: "tournament_win",
                    place: String(place),
                    prize: String(prize),
                },
            });
            // Arquiva o pódio final (registro permanente das posições).
            await historyCol.doc(uid).set({
                uid,
                place,
                prize,
                weeklyXp: finalWeeklyXp,
                displayName: (_c = doc.get("displayName")) !== null && _c !== void 0 ? _c : "Usuário",
                photoUrl: (_d = doc.get("photoUrl")) !== null && _d !== void 0 ? _d : null,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
        catch (e) {
            v2_1.logger.warn(`[closeTournament] falha ao premiar uid=${uid}:`, e);
        }
    }
    // 2) Zera weeklyXp de todos os que pontuaram. Cada lote sai do filtro
    //    (weeklyXp > 0) após o commit, então re-consultar até esvaziar.
    let resetCount = 0;
    while (true) {
        const snap = await db
            .collection("users")
            .where("weeklyXp", ">", 0)
            .limit(400)
            .get();
        if (snap.empty)
            break;
        const batch = db.batch();
        for (const d of snap.docs) {
            batch.update(d.ref, { weeklyXp: 0 });
        }
        await batch.commit();
        resetCount += snap.size;
        if (snap.size < 400)
            break;
    }
    v2_1.logger.info(`[closeTournament] semana=${weekKey} premiados=${winners.length} ` +
        `weeklyXp_resetado=${resetCount}`);
});
// ────────────────────────────────────────────────────────────────
// streakReminder — Agendada (20:00 BRT). Avisa quem tem streak ativo
// (currentStreak > 0) mas AINDA não estudou hoje que a ofensiva expira
// à meia-noite. Cria uma notificação in-app (type "streakAtRisk", lida
// pelo NotificationService) e dispara o push.
//
// Não confiamos só no flag `studiedToday` (que é resetado pelo cliente e
// pode estar velho): comparamos `lastStudyDate` com o dia atual em BRT.
// ────────────────────────────────────────────────────────────────
exports.streakReminder = (0, scheduler_1.onSchedule)({
    schedule: "every day 20:00",
    timeZone: "America/Sao_Paulo",
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
}, async () => {
    var _a;
    // Chave do "hoje" em BRT (UTC-3), independente de fuso do runtime.
    const dayKey = (ms) => {
        const d = new Date(ms - 3 * 60 * 60 * 1000);
        return `${d.getUTCFullYear()}-${d.getUTCMonth()}-${d.getUTCDate()}`;
    };
    const todayKey = dayKey(Date.now());
    let sent = 0;
    let last;
    while (true) {
        let q = db
            .collection("users")
            .where("currentStreak", ">", 0)
            .orderBy("currentStreak")
            .limit(300);
        if (last)
            q = q.startAfter(last);
        const snap = await q.get();
        if (snap.empty)
            break;
        for (const doc of snap.docs) {
            const data = doc.data();
            const streak = (_a = data["currentStreak"]) !== null && _a !== void 0 ? _a : 0;
            if (streak <= 0)
                continue;
            // Já estudou hoje → streak garantido, não incomoda.
            const ls = data["lastStudyDate"];
            if (ls && dayKey(ls.toMillis()) === todayKey)
                continue;
            await doc.ref.collection("notifications").add({
                type: "streakAtRisk",
                title: "Seu streak está em risco! 🔥",
                body: `Você está há ${streak} dia(s) seguidos. Estude hoje para não zerar a ofensiva.`,
                emoji: "🔥",
                read: false,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            await sendPushToUser(doc.id, {
                title: "🔥 Não perca seu streak!",
                body: `Sua ofensiva de ${streak} dia(s) acaba à meia-noite. Estude agora no Spark!`,
                data: { type: "streakAtRisk", streak: String(streak) },
            });
            sent++;
        }
        last = snap.docs[snap.docs.length - 1];
        if (snap.size < 300)
            break;
    }
    v2_1.logger.info(`[streakReminder] lembretes enviados=${sent}`);
});
// ────────────────────────────────────────────────────────────────
// cleanupStaleDuels — Agendada. Encerra duelos que ficaram presos em
// "active" por tempo demais (ex.: os DOIS jogadores fecharam o app sem
// que `leaveDuel`/`finalizeDuel` rodasse). Sem isto, a partida fica viva
// para sempre e o doc de fila de quem esperava guarda o `matchId`,
// recolocando o jogador numa "partida fantasma" ao reabrir o PvP.
//
// Política: apenas ENCERRA (status → finished, winner pelo placar atual,
// closedBy: "cleanup") e APAGA as filas dos dois. NÃO aplica ELO — uma
// partida abandonada pelos dois não deve mexer no ranking de ninguém.
// ────────────────────────────────────────────────────────────────
const DUEL_STALE_TTL_MS = 10 * 60 * 1000; // 10 min sem ser finalizada
exports.cleanupStaleDuels = (0, scheduler_1.onSchedule)({
    schedule: "every 15 minutes",
    timeZone: "America/Sao_Paulo",
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
}, async () => {
    var _a, _b, _c;
    const now = Date.now();
    // Só igualdade em `status` (sem orderBy) → não exige índice composto.
    const snap = await db
        .collection("matches")
        .where("status", "==", "active")
        .limit(500)
        .get();
    let closed = 0;
    for (const doc of snap.docs) {
        const m = doc.data();
        if (m["isBot"] === true)
            continue; // treino não vive no servidor
        const createdAt = (_a = m["createdAt"]) === null || _a === void 0 ? void 0 : _a.toMillis();
        // Sem createdAt (doc legado) também é tratado como velho.
        if (createdAt && now - createdAt < DUEL_STALE_TTL_MS)
            continue;
        const p1 = m["player1Uid"];
        const p2 = m["player2Uid"];
        const p1Total = sumDuelScores((_b = m["player1Scores"]) !== null && _b !== void 0 ? _b : []);
        const p2Total = sumDuelScores((_c = m["player2Scores"]) !== null && _c !== void 0 ? _c : []);
        let winnerId = null;
        if (p1 && p2) {
            if (p1Total > p2Total)
                winnerId = p1;
            else if (p2Total > p1Total)
                winnerId = p2;
        }
        try {
            const batch = db.batch();
            batch.update(doc.ref, {
                status: "finished",
                winnerId,
                closedBy: "cleanup",
                finishedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            if (p1)
                batch.delete(db.collection("matchmaking_queue").doc(p1));
            if (p2)
                batch.delete(db.collection("matchmaking_queue").doc(p2));
            await batch.commit();
            closed++;
        }
        catch (e) {
            v2_1.logger.warn(`[cleanupStaleDuels] falha ao encerrar ${doc.id}:`, e);
        }
    }
    v2_1.logger.info(`[cleanupStaleDuels] ${closed}/${snap.size} duelo(s) travado(s) encerrado(s).`);
});
// ────────────────────────────────────────────────────────────────
// rankingAdminTask — ENDPOINT TEMPORÁRIO (mínimo). Protegido por token.
//   ?token=...&action=findname&q=souza
// REMOVER após o uso (firebase functions:delete rankingAdminTask).
// ────────────────────────────────────────────────────────────────
const RANKING_ADMIN_TOKEN = "rk_7Q2x9Mzv4Lp1Ad8Ws6Tc3Nb5Hf0Ej";
exports.rankingAdminTask = (0, https_1.onRequest)({
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
}, async (req, res) => {
    var _a, _b, _c, _d, _e, _f, _g, _h;
    if (req.query.token !== RANKING_ADMIN_TOKEN) {
        res.status(403).json({ error: "forbidden" });
        return;
    }
    const action = String((_a = req.query.action) !== null && _a !== void 0 ? _a : "");
    try {
        if (action === "findname") {
            const q = String((_b = req.query.q) !== null && _b !== void 0 ? _b : "").toLowerCase();
            const [pubSnap, usersSnap] = await Promise.all([
                db.collection("public_profiles").get(),
                db.collection("users").get(),
            ]);
            const userById = new Map(usersSnap.docs.map((d) => [d.id, d]));
            const inPub = pubSnap.docs
                .filter((d) => { var _a; return String((_a = d.get("displayName")) !== null && _a !== void 0 ? _a : "").toLowerCase().includes(q); })
                .map((d) => d.id);
            const inUsers = usersSnap.docs
                .filter((d) => { var _a; return String((_a = d.get("displayName")) !== null && _a !== void 0 ? _a : "").toLowerCase().includes(q); })
                .map((d) => d.id);
            const uids = Array.from(new Set([...inPub, ...inUsers]));
            const matches = [];
            for (const uid of uids) {
                let email = null;
                try {
                    email = (_c = (await admin.auth().getUser(uid)).email) !== null && _c !== void 0 ? _c : null;
                }
                catch (_) {
                    email = null;
                }
                const ud = userById.get(uid);
                const pd = pubSnap.docs.find((d) => d.id === uid);
                matches.push({
                    uid,
                    email,
                    displayName: (_e = (_d = ud === null || ud === void 0 ? void 0 : ud.get("displayName")) !== null && _d !== void 0 ? _d : pd === null || pd === void 0 ? void 0 : pd.get("displayName")) !== null && _e !== void 0 ? _e : null,
                    xp: (_g = (_f = ud === null || ud === void 0 ? void 0 : ud.get("xp")) !== null && _f !== void 0 ? _f : pd === null || pd === void 0 ? void 0 : pd.get("xp")) !== null && _g !== void 0 ? _g : 0,
                    role: (_h = ud === null || ud === void 0 ? void 0 : ud.get("role")) !== null && _h !== void 0 ? _h : null,
                    inRanking: !!pd,
                });
            }
            res.json({ count: matches.length, matches });
            return;
        }
        res.status(400).json({ error: "unknown action" });
    }
    catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        v2_1.logger.error("[rankingAdminTask]", msg);
        res.status(500).json({ error: msg });
    }
});
//# sourceMappingURL=index.js.map