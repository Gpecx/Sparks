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
 *  - updateElo         : Processa resultado de duelo e atualiza ELO rating.
 *  - unlockBadge       : Concede badge se ainda não desbloqueada.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.unlockBadge = exports.updateElo = exports.spendSparkPoints = exports.addXp = void 0;
const admin = require("firebase-admin");
const https_1 = require("firebase-functions/v2/https");
const v2_1 = require("firebase-functions/v2");
// ── Firebase Admin init ──────────────────────────────────────────
admin.initializeApp();
const db = admin.firestore();
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
function currentWeekKey() {
    const now = new Date();
    const start = new Date(now.getFullYear(), 0, 1);
    const dayOfYear = Math.floor((now.getTime() - start.getTime()) / (1000 * 60 * 60 * 24)) + 1;
    const weekNum = Math.floor((dayOfYear - now.getDay() + 10) / 7);
    return `${now.getFullYear()}-W${String(weekNum).padStart(2, "0")}`;
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
exports.addXp = (0, https_1.onCall)({ region: "southamerica-east1" }, async (request) => {
    var _a;
    const uid = (_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid;
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "Usuário não autenticado.");
    }
    const { amount, source = "app" } = request.data;
    if (!amount || typeof amount !== "number" || amount <= 0) {
        throw new https_1.HttpsError("invalid-argument", "amount deve ser um número positivo.");
    }
    const userRef = db.collection("users").doc(uid);
    let result;
    let rankingData = null;
    // Transação focada SOMENTE no documento do usuário (sem cross-document)
    await db.runTransaction(async (tx) => {
        var _a, _b, _c, _d, _e, _f, _g;
        const snap = await tx.get(userRef);
        if (!snap.exists) {
            throw new https_1.HttpsError("not-found", "Documento do usuário não encontrado.");
        }
        const data = snap.data();
        const currentXp = (_a = data["xp"]) !== null && _a !== void 0 ? _a : 0;
        const currentWeeklyXp = (_b = data["weeklyXp"]) !== null && _b !== void 0 ? _b : 0;
        const unlockedBadgeIds = (_c = data["unlockedBadgeIds"]) !== null && _c !== void 0 ? _c : [];
        const oldLevel = calcLevel(currentXp);
        const newXp = currentXp + amount;
        const newLevel = calcLevel(newXp);
        const newTension = calcTension(newXp);
        const newWeeklyXp = currentWeeklyXp + amount;
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
        // Armazena dados para ranking (será escrito fora da transação)
        rankingData = {
            uid,
            displayName: (_d = data["displayName"]) !== null && _d !== void 0 ? _d : "Usuário",
            photoUrl: (_e = data["photoUrl"]) !== null && _e !== void 0 ? _e : null,
            weeklyXp: newWeeklyXp,
            clanId: (_f = data["clanId"]) !== null && _f !== void 0 ? _f : null,
            clanName: (_g = data["clanName"]) !== null && _g !== void 0 ? _g : null,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
    });
    // Ranking atualizado FORA da transação — sem risco de contenção
    if (rankingData) {
        const weekKey = currentWeekKey();
        const rankingRef = db
            .collection("rankings")
            .doc("weekly")
            .collection(weekKey)
            .doc(uid);
        try {
            await rankingRef.set(rankingData, { merge: true });
        }
        catch (e) {
            v2_1.logger.warn("[addXp] Erro ao atualizar ranking (não crítico):", e);
        }
    }
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
exports.spendSparkPoints = (0, https_1.onCall)({ region: "southamerica-east1" }, async (request) => {
    var _a;
    const uid = (_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid;
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "Usuário não autenticado.");
    }
    const { amount, source = "purchase" } = request.data;
    if (!amount || typeof amount !== "number" || amount <= 0) {
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
exports.updateElo = (0, https_1.onCall)({ region: "southamerica-east1" }, async (request) => {
    var _a;
    const uid = (_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid;
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "Usuário não autenticado.");
    }
    const { eloChange, won } = request.data;
    if (typeof eloChange !== "number") {
        throw new https_1.HttpsError("invalid-argument", "eloChange deve ser um número.");
    }
    const userRef = db.collection("users").doc(uid);
    let result;
    await db.runTransaction(async (tx) => {
        var _a, _b, _c;
        const snap = await tx.get(userRef);
        if (!snap.exists) {
            throw new https_1.HttpsError("not-found", "Documento do usuário não encontrado.");
        }
        const data = snap.data();
        const currentElo = (_a = data["eloRating"]) !== null && _a !== void 0 ? _a : 1200;
        const currentDuels = (_b = data["totalDuels"]) !== null && _b !== void 0 ? _b : 0;
        const unlockedBadgeIds = (_c = data["unlockedBadgeIds"]) !== null && _c !== void 0 ? _c : [];
        const updates = {
            eloRating: admin.firestore.FieldValue.increment(eloChange),
            totalDuels: admin.firestore.FieldValue.increment(1),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        if (won === true) {
            updates["wins"] = admin.firestore.FieldValue.increment(1);
        }
        else if (won === false) {
            updates["losses"] = admin.firestore.FieldValue.increment(1);
        }
        tx.update(userRef, updates);
        // Badge do primeiro duelo (totalDuels era 0 antes da atualização)
        if (currentDuels === 0) {
            if (!unlockedBadgeIds.includes("primeiro_duelo")) {
                updates.unlockedBadgeIds = admin.firestore.FieldValue.arrayUnion("primeiro_duelo");
            }
        }
        result = {
            newElo: currentElo + eloChange,
            totalDuels: currentDuels + 1,
        };
    });
    v2_1.logger.info(`[updateElo] uid=${uid} change=${eloChange} won=${won} newElo=${result.newElo}`);
    return result;
});
exports.unlockBadge = (0, https_1.onCall)({ region: "southamerica-east1" }, async (request) => {
    var _a, _b;
    const uid = (_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid;
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "Usuário não autenticado.");
    }
    const { badgeId, source = "achievement" } = request.data;
    if (!badgeId || typeof badgeId !== "string") {
        throw new https_1.HttpsError("invalid-argument", "badgeId inválido.");
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
//# sourceMappingURL=index.js.map