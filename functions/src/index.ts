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

import * as admin from "firebase-admin";
import { getFirestore } from "firebase-admin/firestore";
import * as crypto from "crypto";
import {
  onCall,
  onRequest,
  CallableRequest,
  HttpsError,
} from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { logger, setGlobalOptions } from "firebase-functions/v2";
import { defineSecret } from "firebase-functions/params";
import * as functionsV1 from "firebase-functions/v1";
import { sendCapiEvent, META_CAPI_TOKEN } from "./capi";
import * as nodemailer from "nodemailer";
import {
  findOrCreateCustomer,
  updateCustomer,
  createCharge,
  getChargeStatus,
  getChargeDetails,
  getChargeDetailsFull,
  getCustomer,
  AsaasBillingType,
} from "./services/asaasService";
import {
  checkRateLimit,
  rateLimitKey,
  RATE_AUTH,
  RATE_PAYMENT,
  RATE_GAMIFICATION,
  RATE_ADMIN,
} from "./rateLimiter";

// ── Secrets vinculados ao Firebase Secret Manager ────────────────
const ASAAS_API_KEY       = defineSecret("ASAAS_API_KEY");
const ASAAS_BASE_URL      = defineSecret("ASAAS_BASE_URL");
const ASAAS_WEBHOOK_TOKEN = defineSecret("ASAAS_WEBHOOK_TOKEN");
const SMTP_USER           = defineSecret("SMTP_USER");
const SMTP_PASS           = defineSecret("SMTP_PASS");

// ── Firebase Admin init ──────────────────────────────────────────
admin.initializeApp({
  projectId: "spark-v1-e0eb5",
});
const db = getFirestore("default");
db.settings({ ignoreUndefinedProperties: true });

// Campos padrão de um novo usuário (bônus de boas-vindas). Centralizado para
// reuso entre o trigger de criação (onUserCreated) e o resgate (redeemAccessCode).
function defaultUserFields(
  uid: string,
  email: string | null | undefined,
  displayName: string | null | undefined,
  photoUrl: string | null | undefined
): Record<string, unknown> {
  return {
    uid,
    displayName: displayName ?? "",
    email: email ?? "",
    photoUrl: photoUrl ?? null,
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
export const onUserCreated = functionsV1
  .region("southamerica-east1")
  .runWith({ secrets: ["META_CAPI_TOKEN"] })
  .auth.user()
  .onCreate(async (user) => {
    // Meta CAPI — novo usuário = Lead. Aditivo e à prova de falha (nunca lança).
    await sendCapiEvent(process.env.META_CAPI_TOKEN ?? "", "Lead", {
      email: user.email,
      uid: user.uid,
    });

    const userRef = db.collection("users").doc(user.uid);
    const snap = await userRef.get();
    if (!snap.exists) {
      await userRef.set(
        defaultUserFields(user.uid, user.email, user.displayName, user.photoURL),
        { merge: true }
      );
      logger.info(`[onUserCreated] doc de usuário criado para uid=${user.uid}`);
    }

    // Reivindica assinatura paga na LP antes da conta existir (se houver).
    // Roda DEPOIS de garantir o doc com os defaults, para não sobrescrever
    // isPremium. À prova de falha — nunca quebra a criação da conta.
    try {
      await claimPendingActivation(user.uid, user.email);
    } catch (e) {
      logger.warn("[onUserCreated] claimPendingActivation falhou (ignorado):", e);
    }
  });

// ── Hardening de segurança ───────────────────────────────────────
// Teto de instâncias por função: protege contra picos/DoS que virariam
// custo de billing (Cloud Functions escala sem limite por padrão). Vale
// para TODAS as funções; cada uma pode sobrescrever localmente se precisar.
setGlobalOptions({ maxInstances: 10 });

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

function calcLevel(totalXp: number): number {
  return Math.floor(totalXp / 500) + 1;
}

function calcTension(totalXp: number): string {
  if (totalXp < 5000) return "BT";
  if (totalXp < 15000) return "MT";
  if (totalXp < 30000) return "AT";
  return "EAT";
}

function xpBadgesEarned(totalXp: number): string[] {
  const badges: string[] = [];
  if (totalXp >= 1000) badges.push("xp_1000");
  if (totalXp >= 5000) badges.push("xp_5000");
  if (totalXp >= 10000) badges.push("xp_10000");
  return badges;
}

// Rótulo de semana "YYYY-Www" — usado apenas para arquivar o histórico do
// torneio e rotular a notificação de vitória.
function weekKeyFor(d: Date): string {
  const start = new Date(d.getFullYear(), 0, 1);
  const dayOfYear =
    Math.floor((d.getTime() - start.getTime()) / (1000 * 60 * 60 * 24)) + 1;
  const weekNum = Math.floor((dayOfYear - d.getDay() + 10) / 7);
  return `${d.getFullYear()}-W${String(weekNum).padStart(2, "0")}`;
}

// Semana que acabou de encerrar (closeTournament roda na virada de segunda).
function lastWeekKey(): string {
  const d = new Date();
  d.setDate(d.getDate() - 7);
  return weekKeyFor(d);
}

async function writeAuditLog(
  uid: string,
  action: string,
  amount: number,
  source: string,
  meta?: Record<string, unknown>
): Promise<void> {
  const entry: Record<string, unknown> = {
    action,
    amount,
    source,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (meta) entry["meta"] = meta;
  await db.collection("users").doc(uid).collection("audit_log").add(entry);
}

// Removido _unlockBadgeInTx para evitar multiplos updates na mesma transacao

/** Comparação de strings em tempo constante (evita timing attacks no token). */
function safeEqual(a: string, b: string): boolean {
  const ab = Buffer.from(a);
  const bb = Buffer.from(b);
  if (ab.length !== bb.length) return false;
  return crypto.timingSafeEqual(ab, bb);
}

/**
 * Gera um código de acesso legível no formato PROF-XXXX-XXXX usando bytes
 * criptograficamente seguros. Alfabeto sem caracteres ambíguos (0/O, 1/I/L).
 */
const CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"; // sem 0 O 1 I L
function genCode(): string {
  const bytes = crypto.randomBytes(8);
  let body = "";
  for (let i = 0; i < 8; i++) {
    body += CODE_ALPHABET[bytes[i] % CODE_ALPHABET.length];
    if (i === 3) body += "-";
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
async function removeUserFromClan(clanId: string, uid: string): Promise<void> {
  const clanRef = db.collection("clans").doc(clanId);
  const clanSnap = await clanRef.get();
  if (!clanSnap.exists) return;

  const wasCreator = clanSnap.data()?.["createdBy"] === uid;

  // Apaga o documento de membro do usuário
  await clanRef.collection("members").doc(uid).delete().catch(() => {});

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
    .catch(() => {});

  // Se o criador saiu, promove outro membro a líder/admin
  if (wasCreator) {
    const next = remaining.docs.find((d) => d.id !== uid) ?? remaining.docs[0];
    await clanRef.update({ createdBy: next.id }).catch(() => {});
    await next.ref.update({ role: "admin" }).catch(() => {});
  }
}

// ────────────────────────────────────────────────────────────────
// CATÁLOGO DE PREÇOS / LIMITES — FONTE DE VERDADE NO SERVIDOR
// ────────────────────────────────────────────────────────────────
// Preço e pontos NUNCA vêm do cliente. O servidor resolve tudo pelo
// planId. O preço enviado pelo app é usado apenas para escolher entre
// mensal/anual — e é rejeitado se não casar com o catálogo.

interface CatalogPlan {
  monthlyPrice: number;
  annualPrice: number | null;
  /** Spark Points concedidos por esta assinatura (assinaturas atuais: 0). */
  points: number;
}

const PLAN_CATALOG: Record<string, CatalogPlan> = {
  student:  { monthlyPrice: 19.90, annualPrice: 199, points: 0 },
  pro:      { monthlyPrice: 39.90, annualPrice: 399, points: 0 },
  premium:  { monthlyPrice: 79.90, annualPrice: 799, points: 0 },
  business: { monthlyPrice: 29,    annualPrice: null, points: 0 },
};

/** Tolerância para casar preço float enviado pelo cliente (centavos). */
const PRICE_EPSILON = 0.01;

/** Tetos por chamada — mitigam farming até a migração para recompensas
 *  100% autoritativas no servidor (ver memória spark-security-pending). */
const MAX_XP_PER_CALL = 1000;
const MAX_SP_PER_CALL = 500;

/** Badges que o servidor concede automaticamente — NÃO podem ser
 *  reivindicadas manualmente via unlockBadge. */
const SERVER_ONLY_BADGES = new Set<string>([
  "xp_1000", "xp_5000", "xp_10000", "primeiro_duelo",
]);

/** Badges que o cliente pode reivindicar (conquistas ainda não
 *  verificáveis no servidor). Qualquer ID fora deste conjunto é rejeitado. */
const CLIENT_CLAIMABLE_BADGES = new Set<string>([
  "queimador", "sniper", "noturno", "top3", "teorico", "veloz",
  "cla_unido", "streak_3_days", "streak_7", "streak_30",
  "first_lesson", "lesson_10", "lesson_50",
]);

/**
 * Resolve um item do carrinho contra o catálogo do servidor.
 * Lança HttpsError se o plano for desconhecido ou o preço não casar
 * com nenhum período do plano.
 */
function resolveCatalogItem(item: {
  name?: string;
  price?: number;
  planId?: string;
}): {
  name: string;
  planId: string;
  price: number;
  points: number;
  isSubscription: boolean;
  period: "monthly" | "annual";
} {
  const planId = item.planId;
  if (!planId || !PLAN_CATALOG[planId]) {
    throw new HttpsError(
      "invalid-argument",
      `Plano inválido ou indisponível: ${planId ?? "(vazio)"}.`
    );
  }
  const plan = PLAN_CATALOG[planId];
  const submitted = typeof item.price === "number" ? item.price : NaN;

  let period: "monthly" | "annual";
  let price: number;
  if (Math.abs(submitted - plan.monthlyPrice) <= PRICE_EPSILON) {
    period = "monthly";
    price = plan.monthlyPrice;
  } else if (
    plan.annualPrice != null &&
    Math.abs(submitted - plan.annualPrice) <= PRICE_EPSILON
  ) {
    period = "annual";
    price = plan.annualPrice;
  } else {
    throw new HttpsError(
      "invalid-argument",
      `Preço inválido para o plano ${planId}.`
    );
  }

  return {
    name: (item.name ?? planId).slice(0, 120),
    planId,
    price,
    points: plan.points,
    isSubscription: true,
    period,
  };
}

/**
 * Reverte um VALOR de cobrança para o plano do catálogo (mensal ou anual).
 * Usado na ativação por link de pagamento da LP, onde não há pedido e só
 * temos o valor pago. Os preços do catálogo são todos distintos, então o
 * mapeamento é inequívoco. Retorna null para valores fora do catálogo
 * (cobrança avulsa/custom) — nesse caso nada é concedido.
 */
function resolvePlanByValue(
  value: number
): { planId: string; period: "monthly" | "annual" } | null {
  for (const [planId, plan] of Object.entries(PLAN_CATALOG)) {
    if (Math.abs(value - plan.monthlyPrice) <= PRICE_EPSILON) {
      return { planId, period: "monthly" };
    }
    if (plan.annualPrice != null && Math.abs(value - plan.annualPrice) <= PRICE_EPSILON) {
      return { planId, period: "annual" };
    }
  }
  return null;
}

/** Normaliza um e-mail para usar como id de documento (mesmo padrão dos OTPs). */
function emailKey(email: string): string {
  return email.trim().toLowerCase().replace(/[^a-z0-9]/g, "_");
}

/**
 * Concede uma assinatura vinda de link de pagamento da LP ao usuário.
 * Espelha o grant in-app (isPremium + subscriptionPlanId), grava uma
 * transação idempotente (id determinístico) e dispara o Purchase no CAPI.
 */
async function grantLinkSubscription(opts: {
  uid: string;
  planId: string;
  period: "monthly" | "annual";
  paymentId: string;
  value: number;
  email: string | null;
}): Promise<void> {
  const { uid, planId, period, paymentId, value, email } = opts;
  await db.collection("users").doc(uid).set(
    {
      isPremium: true,
      subscriptionPlanId: planId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  await db.collection("transactions").doc(`link_${paymentId}`).set(
    {
      uid,
      asaasPaymentId: paymentId,
      planId,
      period,
      totalPrice: value,
      totalPoints: 0,
      status: "PAID",
      origin: "payment_link",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  try {
    await sendCapiEvent(META_CAPI_TOKEN.value(), "Purchase", {
      email: email ?? undefined,
      uid,
      value,
      currency: "BRL",
      eventId: paymentId,
      actionSource: "website",
    });
  } catch (e) {
    logger.warn("[linkActivation] CAPI Purchase falhou (ignorado):", e);
  }
}

/**
 * Reivindica uma pendência de ativação por link (pagou na LP antes de ter
 * conta, ou Student que estava segurado). Chamada no onUserCreated e ao
 * aprovar a verificação de estudante. Mantém a pendência se ela exigir
 * verificação de estudante e o usuário ainda não foi verificado.
 */
async function claimPendingActivation(
  uid: string,
  email: string | null | undefined,
  opts?: { studentJustVerified?: boolean }
): Promise<void> {
  if (!email) return;
  const ref = db.collection("pending_link_activations").doc(emailKey(email));
  const snap = await ref.get();
  if (!snap.exists) return;
  const p = snap.data()!;
  const requiresStudent = p["requiresStudentVerification"] === true;
  if (requiresStudent && !opts?.studentJustVerified) {
    // Ainda não verificado — segura a pendência, mas amarra o uid.
    if (p["uid"] !== uid) await ref.set({ uid }, { merge: true });
    return;
  }
  await grantLinkSubscription({
    uid,
    planId: (p["planId"] as string) ?? "pro",
    period: (p["period"] as "monthly" | "annual") ?? "monthly",
    paymentId: (p["paymentId"] as string) ?? `pending_${uid}`,
    value: (p["value"] as number) ?? 0,
    email,
  });
  await ref.delete();
  logger.info(`[claimPending] concedido ${p["planId"]} a uid=${uid} (pendência da LP).`);
}

/**
 * Reivindica pendências amarradas a um uid (caso Student segurado: o uid já
 * foi gravado na pendência quando o pagamento entrou). Chamada ao aprovar a
 * verificação de estudante. À prova de falha — nunca lança.
 */
async function claimPendingActivationsByUid(uid: string): Promise<void> {
  try {
    const q = await db
      .collection("pending_link_activations")
      .where("uid", "==", uid)
      .limit(5)
      .get();
    for (const doc of q.docs) {
      const p = doc.data();
      await grantLinkSubscription({
        uid,
        planId: (p["planId"] as string) ?? "student",
        period: (p["period"] as "monthly" | "annual") ?? "monthly",
        paymentId: (p["paymentId"] as string) ?? `pending_${uid}`,
        value: (p["value"] as number) ?? 0,
        email: (p["email"] as string) ?? null,
      });
      await doc.ref.delete();
      logger.info(`[claimPendingByUid] concedido ${p["planId"]} a uid=${uid}.`);
    }
  } catch (e) {
    logger.warn("[claimPendingByUid] falhou (ignorado):", e);
  }
}

// ────────────────────────────────────────────────────────────────
// 1. addXp — Adiciona XP ao usuário
// ────────────────────────────────────────────────────────────────

interface AddXpData {
  amount: number;
  source?: string;
}

interface AddXpResult {
  newXp: number;
  newLevel: number;
  newTension: string;
  leveledUp: boolean;
  badgesUnlocked: string[];
}

export const addXp = onCall(
  {
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
  },
  async (request: CallableRequest<AddXpData>): Promise<AddXpResult> => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Usuário não autenticado.");
    }

    await checkRateLimit(
      rateLimitKey("gamification", uid, "addXp"),
      RATE_GAMIFICATION.limit,
      RATE_GAMIFICATION.windowMs
    );

    const { amount, source = "app" } = request.data;

    if (!amount || typeof amount !== "number" || !Number.isFinite(amount) || amount <= 0) {
      throw new HttpsError(
        "invalid-argument",
        "amount deve ser um número positivo."
      );
    }
    if (amount > MAX_XP_PER_CALL) {
      throw new HttpsError(
        "invalid-argument",
        `amount excede o máximo permitido por chamada (${MAX_XP_PER_CALL}).`
      );
    }

    const userRef = db.collection("users").doc(uid);
    let result!: AddXpResult;

    // Transação focada SOMENTE no documento do usuário (sem cross-document)
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(userRef);
      if (!snap.exists) {
        throw new HttpsError("not-found", "Documento do usuário não encontrado.");
      }

      const data = snap.data()!;
      const currentXp = (data["xp"] as number) ?? 0;
      const unlockedBadgeIds: string[] = data["unlockedBadgeIds"] ?? [];
      const oldLevel = calcLevel(currentXp);

      const newXp = currentXp + amount;
      const newLevel = calcLevel(newXp);
      const newTension = calcTension(newXp);
      const leveledUp = newLevel > oldLevel;

      const userUpdates: Record<string, any> = {
        xp: admin.firestore.FieldValue.increment(amount),
        weeklyXp: admin.firestore.FieldValue.increment(amount),
        monthlyXp: admin.firestore.FieldValue.increment(amount),
        level: newLevel,
        tensionLevel: newTension,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      const badgesToCheck = xpBadgesEarned(newXp);
      const badgesUnlocked: string[] = [];
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
    } catch (e) {
      logger.warn("[addXp] Erro no audit log (não crítico):", e);
    }

    logger.info(
      `[addXp] uid=${uid} amount=${amount} newXp=${result.newXp} level=${result.newLevel}`
    );
    return result;
  }
);

// ────────────────────────────────────────────────────────────────
// 2. addSparkPoints — Adiciona Spark Points ao usuário (recompensas)
// ────────────────────────────────────────────────────────────────

interface AddSpData {
  amount: number;
  source?: string;
}

interface AddSpResult {
  newBalance: number;
}

export const addSparkPoints = onCall(
  {
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
  },
  async (request: CallableRequest<AddSpData>): Promise<AddSpResult> => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Usuário não autenticado.");
    }

    await checkRateLimit(
      rateLimitKey("gamification", uid, "addSparkPoints"),
      RATE_GAMIFICATION.limit,
      RATE_GAMIFICATION.windowMs
    );

    const { amount, source = "reward" } = request.data;

    if (!amount || typeof amount !== "number" || !Number.isFinite(amount) || amount <= 0) {
      throw new HttpsError(
        "invalid-argument",
        "amount deve ser um número positivo."
      );
    }
    if (amount > MAX_SP_PER_CALL) {
      throw new HttpsError(
        "invalid-argument",
        `amount excede o máximo permitido por chamada (${MAX_SP_PER_CALL}).`
      );
    }

    const userRef = db.collection("users").doc(uid);
    let newBalance = 0;

    await db.runTransaction(async (tx) => {
      const snap = await tx.get(userRef);
      if (!snap.exists) {
        throw new HttpsError("not-found", "Documento do usuário não encontrado.");
      }

      const currentSp = (snap.data()!["sparkPoints"] as number) ?? 0;
      newBalance = currentSp + amount;

      tx.update(userRef, {
        sparkPoints: admin.firestore.FieldValue.increment(amount),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    try {
      await writeAuditLog(uid, "sp_gained", amount, source, { newBalance });
    } catch (e) {
      logger.warn("[addSparkPoints] Audit log error:", e);
    }

    logger.info(`[addSparkPoints] uid=${uid} amount=${amount} newBalance=${newBalance}`);
    return { newBalance };
  }
);

// ────────────────────────────────────────────────────────────────
// 3. spendSparkPoints — Debita Spark Points com verificação de saldo
// ────────────────────────────────────────────────────────────────

interface SpendSpData {
  amount: number;
  source?: string;
}

interface SpendSpResult {
  success: boolean;
  newBalance: number;
  message?: string;
}

export const spendSparkPoints = onCall(
  {
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
  },
  async (request: CallableRequest<SpendSpData>): Promise<SpendSpResult> => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Usuário não autenticado.");
    }

    await checkRateLimit(
      rateLimitKey("gamification", uid, "spendSparkPoints"),
      RATE_GAMIFICATION.limit,
      RATE_GAMIFICATION.windowMs
    );

    const { amount, source = "purchase" } = request.data;

    if (!amount || typeof amount !== "number" || !Number.isFinite(amount) || amount <= 0) {
      throw new HttpsError(
        "invalid-argument",
        "amount deve ser um número positivo."
      );
    }

    const userRef = db.collection("users").doc(uid);
    let result!: SpendSpResult;

    await db.runTransaction(async (tx) => {
      const snap = await tx.get(userRef);
      if (!snap.exists) {
        throw new HttpsError("not-found", "Documento do usuário não encontrado.");
      }

      const currentSp = (snap.data()!["sparkPoints"] as number) ?? 0;

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
      } catch (e) {
        logger.warn("[spendSparkPoints] Audit log error:", e);
      }
    }

    return result;
  }
);

// ────────────────────────────────────────────────────────────────
// 3. (removido) updateElo — o ELO de duelo agora é apurado e gravado
//    EXCLUSIVAMENTE por `finalizeDuel`, a partir do resultado real da
//    partida. Não há mais função de ELO que aceite delta arbitrário do
//    cliente (que permitiria forjar ranking).
// ────────────────────────────────────────────────────────────────

// ────────────────────────────────────────────────────────────────
// 4. unlockBadge — Concede badge ao usuário de forma validada
// ────────────────────────────────────────────────────────────────

interface UnlockBadgeData {
  badgeId: string;
  source?: string;
}

interface UnlockBadgeResult {
  unlocked: boolean;
  badgeId: string;
}

export const unlockBadge = onCall(
  {
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
  },
  async (
    request: CallableRequest<UnlockBadgeData>
  ): Promise<UnlockBadgeResult> => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Usuário não autenticado.");
    }

    await checkRateLimit(
      rateLimitKey("gamification", uid, "unlockBadge"),
      RATE_GAMIFICATION.limit,
      RATE_GAMIFICATION.windowMs
    );

    const { badgeId, source = "achievement" } = request.data;

    if (!badgeId || typeof badgeId !== "string") {
      throw new HttpsError("invalid-argument", "badgeId inválido.");
    }
    // Badges concedidas pelo servidor (XP/duelo) não podem ser reivindicadas.
    if (SERVER_ONLY_BADGES.has(badgeId)) {
      throw new HttpsError(
        "permission-denied",
        "Esta conquista é concedida automaticamente pelo servidor."
      );
    }
    // Só badges conhecidas e reivindicáveis pelo cliente são aceitas.
    if (!CLIENT_CLAIMABLE_BADGES.has(badgeId)) {
      throw new HttpsError("invalid-argument", `badgeId desconhecido: ${badgeId}.`);
    }

    const userRef = db.collection("users").doc(uid);
    let unlocked = false;

    const snap = await userRef.get();
    if (!snap.exists) {
      throw new HttpsError("not-found", "Documento do usuário não encontrado.");
    }

    const unlockedBadgeIds: string[] = snap.data()!["unlockedBadgeIds"] ?? [];

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
      } catch (e) {
        logger.warn("[unlockBadge] Audit log error:", e);
      }
      logger.info(`[unlockBadge] uid=${uid} badge=${badgeId}`);
    }

    return { unlocked, badgeId };
  }
);

// ────────────────────────────────────────────────────────────────
// 5. createAsaasCheckout — Cria cobrança no Asaas (PIX/Cartão/Boleto)
// ────────────────────────────────────────────────────────────────

interface CheckoutItem {
  name: string;
  description: string;
  price: number;
  sparkPointsGranted: number;
  isSubscription?: boolean;
  planId?: string;
}

interface CreateCheckoutData {
  items: CheckoutItem[];
  billingType: AsaasBillingType;
  customerName?: string;
  customerEmail?: string;
  customerCpfCnpj?: string;
}

interface CreateCheckoutResult {
  orderId: string;
  chargeId: string;
  billingType: AsaasBillingType;
  totalPrice: number;
  invoiceUrl: string | null;
  pixPayload: string | null;
  pixQrCodeBase64: string | null;
  pixExpirationDate: string | null;
  bankSlipUrl: string | null;
}

export const createAsaasCheckout = onCall(
  {
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    secrets: [ASAAS_API_KEY, ASAAS_BASE_URL],
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
  },
  async (
    request: CallableRequest<CreateCheckoutData>
  ): Promise<CreateCheckoutResult> => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Usuário não autenticado.");
    }

    // Rate limit: evita criação em massa de pedidos / abuso da API Asaas.
    await checkRateLimit(
      rateLimitKey("payment", uid, "createAsaasCheckout"),
      RATE_PAYMENT.limit,
      RATE_PAYMENT.windowMs
    );

    const { items, billingType, customerName, customerEmail, customerCpfCnpj } =
      request.data;

    if (!items || items.length === 0) {
      throw new HttpsError("invalid-argument", "Carrinho vazio.");
    }
    if (!billingType) {
      throw new HttpsError("invalid-argument", "billingType é obrigatório.");
    }

    // Verifica se a chave do Asaas está configurada
    const apiKey = process.env.ASAAS_API_KEY ?? "";
    if (!apiKey) {
      logger.warn("[createAsaasCheckout] ASAAS_API_KEY não configurada — pagamento indisponível.");
      throw new HttpsError(
        "unavailable",
        "O sistema de pagamentos está em manutenção. Tente novamente em breve."
      );
    }

    // SEGURANÇA: resolve cada item pelo catálogo do servidor. Preço e
    // pontos são definidos pelo servidor — o que o cliente enviar é
    // ignorado (exceto para escolher mensal/anual, já validado).
    const resolvedItems = items.map((i) => resolveCatalogItem(i));
    const totalPrice = resolvedItems.reduce((acc, i) => acc + i.price, 0);
    const totalPoints = resolvedItems.reduce((acc, i) => acc + i.points, 0);

    // ENFORCEMENT do plano Student: o preço de estudante só é liberado
    // para quem teve a matrícula verificada e APROVADA (por admin/Cloud
    // Function). Sem isto, qualquer um compraria Student a R$19,90.
    if (resolvedItems.some((i) => i.planId === "student")) {
      const svSnap = await db
        .collection("student_verifications")
        .doc(uid)
        .get();
      if (!svSnap.exists || svSnap.data()?.["status"] !== "approved") {
        throw new HttpsError(
          "failed-precondition",
          "Verificação de estudante necessária. Envie seu comprovante de matrícula e aguarde a aprovação antes de assinar o plano Student."
        );
      }
    }

    // Busca dados do usuário no Firestore para preencher o cliente Asaas
    const userSnap = await db.collection("users").doc(uid).get();
    if (!userSnap.exists) {
      throw new HttpsError("not-found", "Usuário não encontrado.");
    }
    const userData = userSnap.data()!;
    const name =
      customerName ?? (userData["displayName"] as string) ?? "Usuário Spark";
    const email =
      customerEmail ?? (userData["email"] as string) ?? `${uid}@spark.app`;

    // Obtém ou cria o cliente no Asaas
    let asaasCustomerId: string | undefined = userData["asaasCustomerId"] as
      | string
      | undefined;

    if (!asaasCustomerId) {
      asaasCustomerId = await findOrCreateCustomer(
        name,
        email,
        customerCpfCnpj
      );
      // Persiste o id para reutilização futura
      await db
        .collection("users")
        .doc(uid)
        .update({ asaasCustomerId });
    } else if (customerCpfCnpj) {
      // Se já existia o id, mas recebemos o CPF agora (ex: pagamento PIX), garantimos o update
      await updateCustomer(asaasCustomerId, customerCpfCnpj);
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

    const description =
      resolvedItems.length === 1
        ? resolvedItems[0].name
        : `${resolvedItems.length} itens — Loja Spark`;

    // Cria a cobrança no Asaas
    const chargeResult = await createCharge({
      customerId: asaasCustomerId,
      value: Number(totalPrice.toFixed(2)),
      description,
      billingType,
      orderId,
    });

    // Salva o chargeId no pedido para reconciliação via webhook
    await orderRef.update({ chargeId: chargeResult.chargeId });

    logger.info(
      `[createAsaasCheckout] uid=${uid} orderId=${orderId} chargeId=${chargeResult.chargeId} total=${totalPrice}`
    );

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
  }
);

// ────────────────────────────────────────────────────────────────
// 6. checkPaymentStatus — Consulta status da cobrança diretamente no Asaas
//    Usado como fallback quando o webhook não é recebido (sandbox/firewall).
// ────────────────────────────────────────────────────────────────

interface CheckPaymentStatusData {
  orderId: string;
}

interface CheckPaymentStatusResult {
  status: string;
  processed: boolean;
  sparkPointsGranted: number;
}

export const checkPaymentStatus = onCall(
  {
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    secrets: [ASAAS_API_KEY, ASAAS_BASE_URL],
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
  },
  async (
    request: CallableRequest<CheckPaymentStatusData>
  ): Promise<CheckPaymentStatusResult> => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Usuário não autenticado.");
    }

    await checkRateLimit(
      rateLimitKey("payment", uid, "checkPaymentStatus"),
      RATE_PAYMENT.limit,
      RATE_PAYMENT.windowMs
    );

    const { orderId } = request.data;
    if (!orderId) {
      throw new HttpsError("invalid-argument", "orderId é obrigatório.");
    }

    // Busca o pedido no Firestore
    const orderRef = db.collection("orders").doc(orderId);
    const orderSnap = await orderRef.get();

    if (!orderSnap.exists) {
      throw new HttpsError("not-found", `Pedido ${orderId} não encontrado.`);
    }

    const order = orderSnap.data()!;

    // Valida que o pedido pertence ao usuário autenticado
    if (order["uid"] !== uid) {
      throw new HttpsError("permission-denied", "Acesso negado ao pedido.");
    }

    // Se já foi processado, retorna direto
    if (order["status"] === "PAID") {
      return {
        status: "PAID",
        processed: false, // já estava pago antes
        sparkPointsGranted: (order["totalPoints"] as number) ?? 0,
      };
    }

    const chargeId = order["chargeId"] as string | undefined;
    if (!chargeId) {
      return { status: order["status"] ?? "PENDING", processed: false, sparkPointsGranted: 0 };
    }

    // Consulta o Asaas diretamente usando getChargeStatus
    const asaasChargeStatus = await getChargeStatus(chargeId);

    logger.info(
      `[checkPaymentStatus] orderId=${orderId} chargeId=${chargeId} asaasStatus=${asaasChargeStatus}`
    );

    const isConfirmed =
      asaasChargeStatus === "RECEIVED" ||
      asaasChargeStatus === "CONFIRMED" ||
      asaasChargeStatus === "RECEIVED_IN_CASH";

    if (!isConfirmed) {
      return { status: asaasChargeStatus, processed: false, sparkPointsGranted: 0 };
    }

    // Pagamento confirmado no Asaas — processa igual ao webhook
    const totalPoints = (order["totalPoints"] as number) ?? 0;
    const totalPrice = (order["totalPrice"] as number) ?? 0;
    const items = (order["items"] as any[]) ?? [];
    const hasSubscription = items.some((i: any) => i.isSubscription === true);

    const batch = db.batch();

    batch.update(orderRef, {
      status: "PAID",
      paidAt: admin.firestore.FieldValue.serverTimestamp(),
      asaasPaymentId: chargeId,
      confirmedVia: "polling",
    });

    const userRef = db.collection("users").doc(uid);
    let userUpdated = false;
    const userUpdates: any = { updatedAt: admin.firestore.FieldValue.serverTimestamp() };

    if (totalPoints > 0) {
      userUpdates.sparkPoints = admin.firestore.FieldValue.increment(totalPoints);
      userUpdated = true;
    }

    if (hasSubscription) {
      userUpdates.isPremium = true;
      const subItem = items.find((i: any) => i.isSubscription === true);
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
    } catch (e) {
      logger.warn("[checkPaymentStatus] Audit log error:", e);
    }

    logger.info(
      `[checkPaymentStatus] Pedido ${orderId} processado via polling. +${totalPoints} pts para uid=${uid}`
    );

    return { status: "PAID", processed: true, sparkPointsGranted: totalPoints };
  }
);

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
export const asaasWebhook = onRequest(
  {
    region: "southamerica-east1",
    secrets: [ASAAS_WEBHOOK_TOKEN, ASAAS_API_KEY, ASAAS_BASE_URL, META_CAPI_TOKEN],
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
  },
  async (req, res) => {
    // 1) Só aceita POST
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    // 2) Parseia o body — o Asaas envia em formato envelope:
    //    { data: "JSON string com event+payment", accessToken: "..." }
    //    Também aceita formato direto: { event, payment } (para testes manuais)
    let event: string | undefined;
    let payment: { id: string; externalReference?: string; status?: string } | undefined;

    const rawBody = req.body;
    // Não logamos o corpo bruto (pode conter PII do cliente).

    // Lê o token primariamente do header oficial do Asaas
    let receivedToken = (req.headers["asaas-access-token"] as string | undefined) ?? "";

    if (rawBody?.data && typeof rawBody.data === "string") {
      // Formato envelope (pode vir de ferramentas de teste ou proxy)
      try {
        const parsed = JSON.parse(rawBody.data);
        event = parsed.event;
        payment = parsed.payment;
        // Fallback para o envelope caso o header não venha
        if (!receivedToken) {
          receivedToken = rawBody.accessToken ?? "";
        }
        logger.info(`[asaasWebhook] Formato envelope detectado. Event=${event}, paymentId=${payment?.id}`);
      } catch (e) {
        logger.error(`[asaasWebhook] Erro ao parsear data: ${e}`);
        res.status(400).send("Invalid data format");
        return;
      }
    } else {
      // Formato direto (Asaas real / chamadas diretas)
      event = rawBody?.event;
      payment = rawBody?.payment;
      logger.info(`[asaasWebhook] Formato direto detectado. Event=${event}, paymentId=${payment?.id}`);
    }

    // 3) Verifica token — FAIL-CLOSED: sem secret configurado, rejeita tudo.
    //    (Nunca logamos o valor/prefixo do secret.)
    const expectedSecret = process.env.ASAAS_WEBHOOK_TOKEN ?? "";
    if (!expectedSecret) {
      logger.error("[asaasWebhook] ASAAS_WEBHOOK_TOKEN não configurado — rejeitando webhook.");
      res.status(401).send("Unauthorized");
      return;
    }
    if (!safeEqual(receivedToken, expectedSecret)) {
      logger.warn("[asaasWebhook] Token inválido bloqueado.");
      res.status(401).send("Unauthorized");
      return;
    }

    logger.info(`[asaasWebhook] Evento: ${event}`, { payment });

    // 4) Processa apenas eventos de pagamento confirmado
    const isConfirmed =
      event === "PAYMENT_RECEIVED" || 
      event === "PAYMENT_CONFIRMED" ||
      event === "PAYMENT_RECEIVED_IN_CASH";

    if (!isConfirmed || !payment) {
      logger.info(`[asaasWebhook] Evento '${event}' ignorado.`);
      res.status(200).send("Event ignored");
      return;
    }

    const orderId = payment.externalReference;
    if (!orderId) {
      // ── Pagamento via LINK da LP (sem pedido in-app) ──
      // Descobre o pagador pelo cliente Asaas, reverte o valor p/ plano e
      // concede (ou segura, se a conta não existir / Student não verificado).
      const paymentId = payment.id;

      const charge = await getChargeDetailsFull(paymentId);
      if (!charge) {
        res.status(200).send("Charge re-verification failed");
        return;
      }
      const linkConfirmed =
        charge.status === "RECEIVED" ||
        charge.status === "CONFIRMED" ||
        charge.status === "RECEIVED_IN_CASH";
      if (!linkConfirmed) {
        logger.info(`[linkActivation] cobrança ${paymentId} não confirmada (status=${charge.status}).`);
        res.status(200).send("Charge not confirmed at Asaas");
        return;
      }

      const plan = resolvePlanByValue(charge.value);
      if (!plan) {
        logger.warn(`[linkActivation] valor ${charge.value} fora do catálogo (pid=${paymentId}).`);
        res.status(200).send("No matching plan");
        return;
      }
      if (!charge.customer) {
        logger.warn(`[linkActivation] cobrança sem customer (pid=${paymentId}).`);
        res.status(200).send("No customer");
        return;
      }

      // Idempotência: claim atômico por paymentId (cada mês = paymentId novo).
      const claimRef = db.collection("link_activations").doc(paymentId);
      try {
        await claimRef.create({
          paymentId,
          planId: plan.planId,
          period: plan.period,
          value: charge.value,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (_e) {
        logger.info(`[linkActivation] pagamento ${paymentId} já processado.`);
        res.status(200).send("Already processed");
        return;
      }

      const cust = await getCustomer(charge.customer);
      const payerEmail = cust?.email ?? null;
      if (!payerEmail) {
        // Sem e-mail não dá p/ casar — libera o claim para re-tentar depois.
        await claimRef.delete().catch(() => {});
        logger.warn(`[linkActivation] cliente ${charge.customer} sem e-mail (pid=${paymentId}).`);
        res.status(200).send("No customer email");
        return;
      }

      // Acha o usuário pelo e-mail (fonte autoritativa: Firebase Auth).
      let linkUid: string | null = null;
      try {
        linkUid = (await admin.auth().getUserByEmail(payerEmail)).uid;
      } catch (_e) {
        linkUid = null;
      }

      const isStudentPlan = plan.planId === "student";

      if (linkUid) {
        // Student não verificado → SEGURA (rede de segurança; a LP também filtra).
        if (isStudentPlan) {
          const uSnap = await db.collection("users").doc(linkUid).get();
          if (uSnap.data()?.["studentVerified"] !== true) {
            await db.collection("pending_link_activations").doc(emailKey(payerEmail)).set(
              {
                email: payerEmail.toLowerCase(),
                uid: linkUid,
                planId: plan.planId,
                period: plan.period,
                value: charge.value,
                paymentId,
                customerId: charge.customer,
                requiresStudentVerification: true,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
              },
              { merge: true }
            );
            logger.info(`[linkActivation] Student segurado (uid=${linkUid}) aguardando verificação.`);
            res.status(200).send("Held: student verification required");
            return;
          }
        }
        await grantLinkSubscription({
          uid: linkUid,
          planId: plan.planId,
          period: plan.period,
          paymentId,
          value: charge.value,
          email: payerEmail,
        });
        logger.info(`[linkActivation] ${plan.planId} concedido a uid=${linkUid} via link da LP.`);
        res.status(200).send("OK");
        return;
      }

      // Usuário ainda não existe → pendência por e-mail (claim no onUserCreated).
      await db.collection("pending_link_activations").doc(emailKey(payerEmail)).set(
        {
          email: payerEmail.toLowerCase(),
          planId: plan.planId,
          period: plan.period,
          value: charge.value,
          paymentId,
          customerId: charge.customer,
          requiresStudentVerification: isStudentPlan,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      logger.info(`[linkActivation] pendência criada p/ ${payerEmail} (sem conta ainda).`);
      res.status(200).send("Pending: awaiting signup");
      return;
    }

    // 4) Busca o pedido no Firestore
    const orderRef = db.collection("orders").doc(orderId);
    const orderSnap = await orderRef.get();

    if (!orderSnap.exists) {
      logger.error(`[asaasWebhook] Pedido ${orderId} não encontrado.`);
      res.status(200).send("Order not found");
      return;
    }

    const order = orderSnap.data()!;

    // Idempotência — ignora se já foi processado
    if (order["status"] === "PAID") {
      logger.info(`[asaasWebhook] Pedido ${orderId} já processado. Ignorando.`);
      res.status(200).send("Already processed");
      return;
    }

    const uid = order["uid"] as string;
    const totalPoints = (order["totalPoints"] as number) ?? 0;
    const totalPrice = (order["totalPrice"] as number) ?? 0;
    const items = (order["items"] as any[]) ?? [];
    const hasSubscription = items.some((i: any) => i.isSubscription === true);

    // DEFESA EM PROFUNDIDADE: nunca confia só no corpo do webhook.
    // Reconsulta a cobrança no Asaas e confirma que ela está paga E pelo
    // valor esperado do pedido antes de conceder qualquer benefício.
    const orderChargeId = (order["chargeId"] as string | undefined) ?? payment.id;
    const charge = await getChargeDetails(orderChargeId);
    if (!charge) {
      logger.error(`[asaasWebhook] Não foi possível reconsultar a cobrança ${orderChargeId}. Abortando concessão.`);
      res.status(200).send("Charge re-verification failed");
      return;
    }
    const asaasConfirmed =
      charge.status === "RECEIVED" ||
      charge.status === "CONFIRMED" ||
      charge.status === "RECEIVED_IN_CASH";
    if (!asaasConfirmed) {
      logger.warn(`[asaasWebhook] Cobrança ${orderChargeId} não confirmada no Asaas (status=${charge.status}). Ignorando.`);
      res.status(200).send("Charge not confirmed at Asaas");
      return;
    }
    if (Math.abs(charge.value - totalPrice) > PRICE_EPSILON) {
      logger.error(`[asaasWebhook] Valor divergente: Asaas=${charge.value} pedido=${totalPrice}. Abortando concessão.`);
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
    const userUpdates: any = { updatedAt: admin.firestore.FieldValue.serverTimestamp() };

    if (totalPoints > 0) {
      userUpdates.sparkPoints = admin.firestore.FieldValue.increment(totalPoints);
      userUpdated = true;
    }

    if (hasSubscription) {
      userUpdates.isPremium = true;
      const subItem = items.find((i: any) => i.isSubscription === true);
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
    } catch (e) {
      logger.warn("[asaasWebhook] Audit log error:", e);
    }

    logger.info(
      `[asaasWebhook] Pedido ${orderId} confirmado. +${totalPoints} pts para uid=${uid}`
    );

    // Meta CAPI — Purchase confirmado no servidor (fonte de verdade da receita).
    // Aditivo e à prova de falha: erros aqui NUNCA afetam a resposta do webhook.
    try {
      const fbUser = await admin.auth().getUser(uid).catch(() => null);
      await sendCapiEvent(META_CAPI_TOKEN.value(), "Purchase", {
        email: fbUser?.email,
        uid,
        value: totalPrice,
        currency: "BRL",
        eventId: orderId, // dedup com o Pixel
        actionSource: "website",
      });
    } catch (e) {
      logger.warn("[asaasWebhook] CAPI Purchase falhou (ignorado):", e);
    }

    res.status(200).send("OK");
  }
);

// ────────────────────────────────────────────────────────────────
// 9. startTrial — Ativa 7 dias gratuitos do Spark Pro
//    Chamada pelo TrialCheckoutScreen após tokenizar o cartão.
// ────────────────────────────────────────────────────────────────

interface StartTrialData {
  planId: string;
  cardTokenId?: string;
}

interface StartTrialResult {
  success: boolean;
  trialEndsAt: string;
}

export const startTrial = onCall(
  {
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
    secrets: [META_CAPI_TOKEN],
  },
  async (request: CallableRequest<StartTrialData>): Promise<StartTrialResult> => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Usuário não autenticado.");

    await checkRateLimit(
      rateLimitKey("payment", uid, "startTrial"),
      RATE_PAYMENT.limit,
      RATE_PAYMENT.windowMs
    );

    const { planId, cardTokenId } = request.data;
    if (!planId) throw new HttpsError("invalid-argument", "planId é obrigatório.");
    if (!PLAN_CATALOG[planId]) {
      throw new HttpsError("invalid-argument", `Plano inválido: ${planId}.`);
    }

    const userRef = db.collection("users").doc(uid);
    const snap = await userRef.get();
    if (!snap.exists) throw new HttpsError("not-found", "Usuário não encontrado.");

    const data = snap.data()!;

    if (data["isOnTrial"] === true) {
      throw new HttpsError("already-exists", "Usuário já possui um trial ativo.");
    }
    if (data["hadTrial"] === true) {
      throw new HttpsError("already-exists", "Usuário já utilizou o período de trial.");
    }

    const trialEndsAt = new Date();
    trialEndsAt.setDate(trialEndsAt.getDate() + 7);

    await userRef.update({
      isOnTrial: true,
      hadTrial: true,
      trialEndsAt: admin.firestore.Timestamp.fromDate(trialEndsAt),
      subscriptionPlanId: planId,
      isPremium: true,
      trialCardTokenId: cardTokenId ?? null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    try {
      await writeAuditLog(uid, "trial_started", 7, "startTrial", {
        planId,
        trialEndsAt: trialEndsAt.toISOString(),
      });
    } catch (e) {
      logger.warn("[startTrial] Audit log error:", e);
    }

    // Meta CAPI — trial iniciado (aditivo, nunca lança).
    await sendCapiEvent(META_CAPI_TOKEN.value(), "StartTrial", {
      email: request.auth?.token?.email as string | undefined,
      uid,
    });

    logger.info(`[startTrial] uid=${uid} plan=${planId} endsAt=${trialEndsAt.toISOString()}`);
    return { success: true, trialEndsAt: trialEndsAt.toISOString() };
  }
);

// ────────────────────────────────────────────────────────────────
// 10. cancelTrial — Cancela trial antes do vencimento
// ────────────────────────────────────────────────────────────────

export const cancelTrial = onCall(
  {
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
  },
  async (request: CallableRequest<Record<string, never>>): Promise<{ success: boolean }> => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Usuário não autenticado.");

    const userRef = db.collection("users").doc(uid);
    const snap = await userRef.get();
    if (!snap.exists) throw new HttpsError("not-found", "Usuário não encontrado.");

    const data = snap.data()!;
    if (!data["isOnTrial"]) {
      throw new HttpsError("failed-precondition", "Usuário não possui trial ativo.");
    }

    // Preserva premium se houver acesso-cortesia (código) ainda ativo — cancelar
    // o trial não deve derrubar uma cortesia válida.
    const compTs = data["compAccessExpiresAt"] as admin.firestore.Timestamp | undefined;
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
    } catch (e) {
      logger.warn("[cancelTrial] Audit log error:", e);
    }

    logger.info(`[cancelTrial] uid=${uid} trial cancelado.`);
    return { success: true };
  }
);

// ════════════════════════════════════════════════════════════════
// CÓDIGOS DE ACESSO (cortesia) — libera acesso total por N dias.
//   access_codes/{CODE}: server-only. Concede isPremium=true +
//   compAccessExpiresAt (ortogonal a trial/assinatura). A expiração é
//   tratada pelo processTrialExpiry (bloco de cortesia, abaixo).
// ════════════════════════════════════════════════════════════════

/** Lê o doc do chamador e exige role=='admin' (mesmo critério das rules). */
async function assertAdmin(uid: string): Promise<void> {
  const snap = await db.collection("users").doc(uid).get();
  if (snap.data()?.["role"] !== "admin") {
    throw new HttpsError("permission-denied", "Apenas administradores.");
  }
}

/**
 * Resolve uids -> { uid, name, email } mesclando o doc /users (displayName/email)
 * com o registro do Firebase Auth (preenche email/nome faltantes). Usado para
 * mostrar POR QUEM cada código foi resgatado e a listagem de usuários do admin.
 */
async function resolveUserInfos(
  uids: string[]
): Promise<Map<string, { uid: string; name: string; email: string | null }>> {
  const out = new Map<string, { uid: string; name: string; email: string | null }>();
  const unique = [...new Set(uids.filter(Boolean))];
  if (unique.length === 0) return out;

  // /users (displayName + email quando houver)
  const docs = await db.getAll(...unique.map((u) => db.collection("users").doc(u)));
  const fromDoc = new Map<string, { name?: string; email?: string }>();
  docs.forEach((d) => {
    const data = d.data() || {};
    fromDoc.set(d.id, { name: data["displayName"], email: data["email"] });
  });

  // Auth (fonte confiável de email/nome) — em lotes de 100
  const fromAuth = new Map<string, { name?: string; email?: string }>();
  for (let i = 0; i < unique.length; i += 100) {
    const chunk = unique.slice(i, i + 100).map((u) => ({ uid: u }));
    try {
      const res = await admin.auth().getUsers(chunk);
      res.users.forEach((u) =>
        fromAuth.set(u.uid, { name: u.displayName, email: u.email })
      );
    } catch (e) {
      logger.warn("[resolveUserInfos] getUsers erro:", e);
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
export const redeemAccessCode = onCall(
  {
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
  },
  async (request: CallableRequest<{ code?: string }>): Promise<{ success: boolean; expiresAt: string }> => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Usuário não autenticado.");

    // Rate limit (anti-brute-force de códigos): família de entitlement.
    await checkRateLimit(
      rateLimitKey("payment", uid, "redeemAccessCode"),
      RATE_PAYMENT.limit,
      RATE_PAYMENT.windowMs
    );

    const code = (request.data?.code ?? "").toString().trim().toUpperCase();
    if (!code) throw new HttpsError("invalid-argument", "Código é obrigatório.");

    const codeRef = db.collection("access_codes").doc(code);
    const userRef = db.collection("users").doc(uid);

    const expiresAtIso = await db.runTransaction(async (tx) => {
      const codeSnap = await tx.get(codeRef);
      if (!codeSnap.exists) throw new HttpsError("not-found", "Código inválido.");
      const c = codeSnap.data()!;

      if (c["active"] !== true) {
        throw new HttpsError("failed-precondition", "Código desativado.");
      }
      const codeExp = c["expiresAt"] as admin.firestore.Timestamp | null | undefined;
      if (codeExp && codeExp.toMillis() <= Date.now()) {
        throw new HttpsError("failed-precondition", "Código expirado.");
      }
      const redeemedBy: string[] = c["redeemedBy"] ?? [];
      if (redeemedBy.includes(uid)) {
        throw new HttpsError("already-exists", "Você já resgatou este código.");
      }
      if ((c["usedCount"] ?? 0) >= (c["maxUses"] ?? 1)) {
        throw new HttpsError("resource-exhausted", "Código esgotado.");
      }

      const userSnap = await tx.get(userRef);
      const u = userSnap.exists ? userSnap.data()! : null;

      // Não sobrescreve uma assinatura paga ativa.
      if (u && u["subscriptionPlanId"] != null && u["isPremium"] === true) {
        throw new HttpsError("failed-precondition", "Você já possui uma assinatura ativa.");
      }

      const durationDays = (c["durationDays"] as number) ?? 30;
      // Estende a partir do maior entre (agora) e (cortesia atual) — não perde dias.
      const currentComp = u?.["compAccessExpiresAt"] as admin.firestore.Timestamp | undefined;
      const baseMs =
        currentComp && currentComp.toMillis() > Date.now()
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
      } else {
        // O doc do usuário ainda não existe (ex.: a criação client-side falhou —
        // problema conhecido de timing de auth no web; normalmente o trigger
        // onUserCreated já o cria). Cria aqui com os padrões + o acesso liberado.
        const token = request.auth?.token as { email?: string; name?: string } | undefined;
        tx.set(userRef, {
          ...defaultUserFields(uid, token?.email, token?.name, null),
          ...compFields,
        });
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
    } catch (e) {
      logger.warn("[redeemAccessCode] Audit log error:", e);
    }

    logger.info(`[redeemAccessCode] uid=${uid} resgatou ${code} até ${expiresAtIso}.`);
    return { success: true, expiresAt: expiresAtIso };
  }
);

// createAccessCodes — admin gera um lote de códigos de uso único.
export const createAccessCodes = onCall(
  {
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
  },
  async (
    request: CallableRequest<{ count?: number; durationDays?: number; label?: string }>
  ): Promise<{ codes: string[] }> => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Usuário não autenticado.");
    await assertAdmin(uid);
    await checkRateLimit(
      rateLimitKey("admin", uid, "createAccessCodes"),
      RATE_ADMIN.limit,
      RATE_ADMIN.windowMs
    );

    const count = Math.min(Math.max(Number(request.data?.count) || 1, 1), 100);
    const durationDays = Math.max(Number(request.data?.durationDays) || 30, 1);
    const label = request.data?.label ? String(request.data.label).slice(0, 120) : null;

    const codes: string[] = [];
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

    logger.info(`[createAccessCodes] uid=${uid} gerou ${count} código(s) (${durationDays}d).`);
    return { codes };
  }
);

// listAccessCodes — admin lista os códigos e seus status.
export const listAccessCodes = onCall(
  {
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
  },
  async (request: CallableRequest<Record<string, never>>): Promise<{ codes: Record<string, unknown>[] }> => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Usuário não autenticado.");
    await assertAdmin(uid);
    await checkRateLimit(
      rateLimitKey("admin", uid, "listAccessCodes"),
      RATE_ADMIN.limit,
      RATE_ADMIN.windowMs
    );

    const snap = await db
      .collection("access_codes")
      .orderBy("createdAt", "desc")
      .limit(500)
      .get();

    // Resolve, de uma vez, todos os uids que resgataram qualquer código.
    const allUids = new Set<string>();
    snap.docs.forEach((d) =>
      ((d.data()["redeemedBy"] as string[]) ?? []).forEach((u) => allUids.add(u))
    );
    const infos = await resolveUserInfos([...allUids]);

    const codes = snap.docs.map((d) => {
      const c = d.data();
      const createdAt = c["createdAt"] as admin.firestore.Timestamp | undefined;
      const lastRedeemedAt = c["lastRedeemedAt"] as admin.firestore.Timestamp | undefined;
      const redeemedBy: string[] = c["redeemedBy"] ?? [];
      return {
        code: d.id,
        durationDays: c["durationDays"] ?? 30,
        active: c["active"] ?? false,
        usedCount: c["usedCount"] ?? 0,
        maxUses: c["maxUses"] ?? 1,
        redeemedBy,
        // Quem resgatou (nome + email) — para o admin ver por quem cada chave foi usada.
        redeemers: redeemedBy.map(
          (u) => infos.get(u) ?? { uid: u, name: "", email: null }
        ),
        label: c["label"] ?? null,
        // Anotação livre do admin (ex.: "enviado para Fulano / escola X").
        note: c["note"] ?? null,
        createdAt: createdAt ? createdAt.toDate().toISOString() : null,
        lastRedeemedAt: lastRedeemedAt ? lastRedeemedAt.toDate().toISOString() : null,
      };
    });
    return { codes };
  }
);

// revokeAccessCode — admin desativa um código (não revoga acessos já concedidos).
export const revokeAccessCode = onCall(
  {
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
  },
  async (request: CallableRequest<{ code?: string }>): Promise<{ success: boolean }> => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Usuário não autenticado.");
    await assertAdmin(uid);
    await checkRateLimit(
      rateLimitKey("admin", uid, "revokeAccessCode"),
      RATE_ADMIN.limit,
      RATE_ADMIN.windowMs
    );

    const code = (request.data?.code ?? "").toString().trim().toUpperCase();
    if (!code) throw new HttpsError("invalid-argument", "Código é obrigatório.");
    const ref = db.collection("access_codes").doc(code);
    const snap = await ref.get();
    if (!snap.exists) throw new HttpsError("not-found", "Código não encontrado.");
    await ref.update({ active: false, updatedAt: admin.firestore.FieldValue.serverTimestamp() });

    logger.info(`[revokeAccessCode] uid=${uid} revogou ${code}.`);
    return { success: true };
  }
);

// setAccessCodeNote — admin anota livremente em um código (ex.: "enviado para
// Fulano / escola X"). Substitui a planilha/txt de controle manual.
export const setAccessCodeNote = onCall(
  {
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
  },
  async (
    request: CallableRequest<{ code?: string; note?: string }>
  ): Promise<{ success: boolean }> => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Usuário não autenticado.");
    await assertAdmin(uid);
    await checkRateLimit(
      rateLimitKey("admin", uid, "setAccessCodeNote"),
      RATE_ADMIN.limit,
      RATE_ADMIN.windowMs
    );

    const code = (request.data?.code ?? "").toString().trim().toUpperCase();
    if (!code) throw new HttpsError("invalid-argument", "Código é obrigatório.");
    const note = (request.data?.note ?? "").toString().slice(0, 280);

    const ref = db.collection("access_codes").doc(code);
    const snap = await ref.get();
    if (!snap.exists) throw new HttpsError("not-found", "Código não encontrado.");
    await ref.update({
      note: note.length > 0 ? note : admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info(`[setAccessCodeNote] uid=${uid} anotou ${code}.`);
    return { success: true };
  }
);

// ───────────────────────────────────────────────────────────────────
//  VERIFICAÇÃO DE ESTUDANTE — aprovação (PDF §8)
//
//  O cliente envia o comprovante e grava student_verifications/{uid}
//  com status 'pending' (as Security Rules só deixam o dono escrever
//  'pending'). A APROVAÇÃO/REJEIÇÃO é exclusiva do admin via as duas
//  funções abaixo — que também gravam users/{uid}.studentVerified, o
//  flag autoritativo lido pelo enforcement do createAsaasCheckout.
// ───────────────────────────────────────────────────────────────────

// listStudentVerifications — admin lista as solicitações de verificação.
export const listStudentVerifications = onCall(
  {
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
  },
  async (
    request: CallableRequest<{ status?: string }>
  ): Promise<{ verifications: Record<string, unknown>[] }> => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Usuário não autenticado.");
    await assertAdmin(uid);
    await checkRateLimit(
      rateLimitKey("admin", uid, "listStudentVerifications"),
      RATE_ADMIN.limit,
      RATE_ADMIN.windowMs
    );

    const snap = await db
      .collection("student_verifications")
      .orderBy("createdAt", "desc")
      .limit(300)
      .get();

    const infos = await resolveUserInfos(snap.docs.map((d) => d.id));

    const verifications = snap.docs.map((d) => {
      const v = d.data();
      const info = infos.get(d.id);
      const createdAt = v["createdAt"] as admin.firestore.Timestamp | undefined;
      const reviewedAt = v["reviewedAt"] as admin.firestore.Timestamp | undefined;
      return {
        uid: d.id,
        name: info?.name ?? "",
        accountEmail: info?.email ?? null,
        institution: v["institution"] ?? "",
        institutionalEmail: v["email"] ?? "",
        method: v["method"] ?? "email",
        proofUrl: v["proofUrl"] ?? null,
        status: v["status"] ?? "pending",
        autoEligible: v["autoEligible"] === true,
        createdAt: createdAt ? createdAt.toDate().toISOString() : null,
        reviewedAt: reviewedAt ? reviewedAt.toDate().toISOString() : null,
      };
    });
    return { verifications };
  }
);

// reviewStudentVerification — admin aprova ou rejeita uma solicitação.
// Aprovar concede users/{uid}.studentVerified=true (lido pelo checkout).
export const reviewStudentVerification = onCall(
  {
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
  },
  async (
    request: CallableRequest<{ uid?: string; decision?: string }>
  ): Promise<{ status: string }> => {
    const adminUid = request.auth?.uid;
    if (!adminUid) throw new HttpsError("unauthenticated", "Usuário não autenticado.");
    await assertAdmin(adminUid);
    await checkRateLimit(
      rateLimitKey("admin", adminUid, "reviewStudentVerification"),
      RATE_ADMIN.limit,
      RATE_ADMIN.windowMs
    );

    const targetUid = (request.data?.uid ?? "").toString().trim();
    const decision = (request.data?.decision ?? "").toString().trim();
    if (!targetUid) {
      throw new HttpsError("invalid-argument", "uid é obrigatório.");
    }
    if (decision !== "approve" && decision !== "reject") {
      throw new HttpsError("invalid-argument", "decision deve ser 'approve' ou 'reject'.");
    }

    const ref = db.collection("student_verifications").doc(targetUid);
    const snap = await ref.get();
    if (!snap.exists) {
      throw new HttpsError("not-found", "Solicitação de verificação não encontrada.");
    }

    const approved = decision === "approve";
    const batch = db.batch();
    batch.update(ref, {
      status: approved ? "approved" : "rejected",
      reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
      reviewedBy: adminUid,
    });
    batch.set(
      db.collection("users").doc(targetUid),
      {
        studentVerified: approved,
        studentVerifiedAt: approved
          ? admin.firestore.FieldValue.serverTimestamp()
          : admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    await batch.commit();

    // Estudante aprovado → libera qualquer assinatura Student paga na LP que
    // estava segurada aguardando verificação.
    if (approved) {
      await claimPendingActivationsByUid(targetUid);
    }

    logger.info(
      `[reviewStudentVerification] admin=${adminUid} uid=${targetUid} -> ${decision}`
    );
    return { status: approved ? "approved" : "rejected" };
  }
);

// listUsers — admin lista todos os usuários com o plano/origem de acesso.
// Resolve nome+email via /users + Firebase Auth e classifica o plano em:
//   subscription (assinatura paga) · voucher (cortesia por código) · premium · free
export const listUsers = onCall(
  {
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
  },
  async (
    request: CallableRequest<Record<string, never>>
  ): Promise<{ users: Record<string, unknown>[] }> => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Usuário não autenticado.");
    await assertAdmin(uid);
    await checkRateLimit(
      rateLimitKey("admin", uid, "listUsers"),
      RATE_ADMIN.limit,
      RATE_ADMIN.windowMs
    );

    // Sem orderBy — docs sem createdAt não podem ser excluídos da listagem.
    const snap = await db.collection("users").limit(1000).get();
    const infos = await resolveUserInfos(snap.docs.map((d) => d.id));
    const now = Date.now();

    const users = snap.docs.map((d) => {
      const u = d.data();
      const info = infos.get(d.id);
      const compExp = u["compAccessExpiresAt"] as admin.firestore.Timestamp | undefined;
      const compActive = compExp ? compExp.toMillis() > now : false;
      const isPremium = u["isPremium"] === true;

      let plan: string;
      if (u["subscriptionPlanId"] != null && isPremium) plan = "subscription";
      else if (u["compAccessSource"] === "access_code" && compActive) plan = "voucher";
      else if (isPremium) plan = "premium";
      else plan = "free";

      const createdAt = u["createdAt"] as admin.firestore.Timestamp | undefined;
      return {
        uid: d.id,
        name: info?.name || "",
        email: info?.email || u["email"] || null,
        role: u["role"] ?? "técnico",
        plan,
        isPremium,
        subscriptionPlanId: u["subscriptionPlanId"] ?? null,
        compAccessSource: u["compAccessSource"] ?? null,
        compAccessCode: u["compAccessCode"] ?? null,
        compAccessExpiresAt: compExp ? compExp.toDate().toISOString() : null,
        weeklyXp: u["weeklyXp"] ?? 0,
        xp: u["xp"] ?? 0,
        createdAt: createdAt ? createdAt.toDate().toISOString() : null,
      };
    });

    logger.info(`[listUsers] uid=${uid} listou ${users.length} usuário(s).`);
    return { users };
  }
);

// ────────────────────────────────────────────────────────────────
// 11. processTrialExpiry — Agendada diariamente (Cloud Scheduler)
//     Revoga isPremium de todos os trials vencidos.
// ────────────────────────────────────────────────────────────────

export const processTrialExpiry = onSchedule(
  {
    schedule: "every day 03:00",
    timeZone: "America/Sao_Paulo",
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
  },
  async () => {
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
          const comp = doc.data()["compAccessExpiresAt"] as admin.firestore.Timestamp | undefined;
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
      logger.info(`[processTrialExpiry] ${expiredSnap.size} trial(s) expirado(s).`);
    } else {
      logger.info("[processTrialExpiry] Nenhum trial vencido.");
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
          batch.update(doc.ref, {
            compAccessExpiresAt: null,
            compAccessSource: null,
            compAccessCode: null,
            ...(stillPremium ? {} : { isPremium: false }),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }
      logger.info(`[processTrialExpiry] ${compSnap.size} acesso(s)-cortesia expirado(s).`);
    }
  }
);

// ────────────────────────────────────────────────────────────────
// grantAdminPremium — todo usuário com role=='admin' recebe assinatura
// premium automaticamente. Dispara em qualquer escrita no doc do usuário;
// ao detectar role=='admin' sem premium, concede isPremium + plano premium.
// Server-controlled: roda com Admin SDK, ignora as Firestore Rules.
// ────────────────────────────────────────────────────────────────
export const grantAdminPremium = onDocumentWritten(
  { document: "users/{uid}", region: "southamerica-east1", database: "default" },
  async (event) => {
    const after = event.data?.after;
    if (!after?.exists) return; // doc deletado

    const d = after.data() as Record<string, unknown>;
    if (d["role"] !== "admin") return; // só admins

    const updates: Record<string, unknown> = {};
    if (d["isPremium"] !== true) updates["isPremium"] = true;
    if (d["subscriptionPlanId"] == null) updates["subscriptionPlanId"] = "premium";

    // Nada a alterar ⇒ não escreve (evita loop de re-disparo do trigger).
    if (Object.keys(updates).length === 0) return;

    updates["updatedAt"] = admin.firestore.FieldValue.serverTimestamp();
    await after.ref.update(updates);
    logger.info(`[grantAdminPremium] Premium concedido ao admin ${event.params.uid}.`);
  }
);

// ────────────────────────────────────────────────────────────────
// 12. checkDeviceTrust — Verifica se o dispositivo é confiável (Admin SDK) [v2 — 2026-06-10]
// ────────────────────────────────────────────────────────────────

interface CheckDeviceTrustData {
  deviceId: string;
}

export const checkDeviceTrust = onCall(
  {
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
  },
  async (request: CallableRequest<CheckDeviceTrustData>): Promise<{ trusted: boolean }> => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Usuário não autenticado.");
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

      const data = snap.data()!;

      // Checa expiração
      if (data["expiresAt"]) {
        const expiresAt = (data["expiresAt"] as admin.firestore.Timestamp).toMillis();
        if (Date.now() > expiresAt) {
          // Expirado — remove em background
          deviceRef.delete().catch(() => {});
          return { trusted: false };
        }
      }

      // Atualiza lastSeenAt sem bloquear a resposta
      deviceRef.update({ lastSeenAt: admin.firestore.FieldValue.serverTimestamp() }).catch(() => {});

      logger.info(`[checkDeviceTrust] uid=${uid} deviceId=${deviceId} trusted=true`);
      return { trusted: true };
    } catch (e) {
      logger.error(`[checkDeviceTrust] Erro ao verificar dispositivo: ${e}`);
      return { trusted: false };
    }
  }
);

// ────────────────────────────────────────────────────────────────
// 13. sendEmailVerificationCode — Gera OTP e envia por e-mail
// ────────────────────────────────────────────────────────────────

interface SendVerifCodeData {
  email: string;
}

export const sendEmailVerificationCode = onCall(
  {
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    secrets: [SMTP_USER, SMTP_PASS],
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
  },
  async (request: CallableRequest<SendVerifCodeData>): Promise<{ sent: boolean }> => {
    // Aceita chamadas autenticadas (login) e também não-autenticadas
    // (registro antes do primeiro login) — o e-mail é validado abaixo.
    const { email } = request.data;

    if (!email || typeof email !== "string" || !email.includes("@")) {
      throw new HttpsError("invalid-argument", "E-mail inválido.");
    }

    // Rate-limit por IP (impede bombardeio de muitos e-mails distintos a
    // partir do mesmo cliente / abuso do SMTP). 5 envios / 15 min por IP.
    const ip = request.rawRequest?.ip ?? "unknown";
    await checkRateLimit(`auth:ip_${ip}:sendOtp`, RATE_AUTH.limit, RATE_AUTH.windowMs);

    // Rate-limit simples: máx. 5 envios por hora por e-mail
    const rateLimitRef = db
      .collection("_otp_rate_limits")
      .doc(email.toLowerCase().replace(/[^a-z0-9]/g, "_"));
    const rlSnap = await rateLimitRef.get();
    if (rlSnap.exists) {
      const rlData = rlSnap.data()!;
      const windowStart = (rlData["windowStart"] as admin.firestore.Timestamp)?.toMillis() ?? 0;
      const count = (rlData["count"] as number) ?? 0;
      const now = Date.now();
      if (now - windowStart < 60 * 60 * 1000 && count >= 5) {
        throw new HttpsError(
          "resource-exhausted",
          "Muitas tentativas. Aguarde 1 hora antes de solicitar um novo código."
        );
      }
      if (now - windowStart >= 60 * 60 * 1000) {
        // Nova janela
        await rateLimitRef.set({ windowStart: admin.firestore.Timestamp.now(), count: 1 });
      } else {
        await rateLimitRef.update({ count: admin.firestore.FieldValue.increment(1) });
      }
    } else {
      await rateLimitRef.set({ windowStart: admin.firestore.Timestamp.now(), count: 1 });
    }

    // Gera código OTP de 6 dígitos com gerador criptograficamente seguro
    const otp = String(crypto.randomInt(100000, 1000000));
    const expiresAt = admin.firestore.Timestamp.fromMillis(Date.now() + 10 * 60 * 1000); // 10 min

    // Salva o OTP no Firestore (a coleção usa o e-mail normalizado como doc ID)
    const uid = request.auth?.uid ?? null;
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
    const smtpUser = process.env.SMTP_USER ?? "";
    const smtpPass = process.env.SMTP_PASS ?? "";

    if (!smtpUser || !smtpPass) {
      logger.error("[sendEmailVerificationCode] SMTP_USER ou SMTP_PASS não configurados.");
      throw new HttpsError(
        "internal",
        "Serviço de e-mail não configurado. Entre em contato com o suporte."
      );
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

    logger.info(`[sendEmailVerificationCode] OTP enviado para ${email} (uid=${uid}).`);
    return { sent: true };
  }
);

// ────────────────────────────────────────────────────────────────
// 13. verifyEmailCode — Valida OTP e registra dispositivo confiável
// ────────────────────────────────────────────────────────────────

interface VerifyEmailCodeData {
  code: string;
  deviceId: string;
  deviceName?: string;
  rememberDevice?: boolean;
}

interface VerifyEmailCodeResult {
  verified: boolean;
  error?: string;
}

export const verifyEmailCode = onCall(
  {
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
  },
  async (
    request: CallableRequest<VerifyEmailCodeData>
  ): Promise<VerifyEmailCodeResult> => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Usuário não autenticado.");
    }

    // Rate limit por uid: impede brute-force do OTP (complementa o cap de
    // 5 tentativas por código já existente).
    await checkRateLimit(
      rateLimitKey("auth", uid, "verifyEmailCode"),
      RATE_AUTH.limit,
      RATE_AUTH.windowMs
    );

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
    const expiresAt = (otp["expiresAt"] as admin.firestore.Timestamp).toMillis();
    if (Date.now() > expiresAt) {
      await otpDoc.ref.delete();
      return { verified: false, error: "Código expirado. Solicite um novo." };
    }

    // Verifica tentativas (máx. 5)
    const attempts = (otp["attempts"] as number) ?? 0;
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
    const deviceExpiresAt = admin.firestore.Timestamp.fromMillis(
      Date.now() + daysToTrust * 24 * 60 * 60 * 1000
    );

    batch.set(deviceRef, {
      deviceId,
      deviceName: deviceName ?? "Dispositivo desconhecido",
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: deviceExpiresAt,
      rememberDevice,
    });

    batch.delete(otpDoc.ref);

    await batch.commit();

    logger.info(`[verifyEmailCode] uid=${uid} dispositivo ${deviceId} verificado com sucesso.`);
    return { verified: true };
  }
);

// ────────────────────────────────────────────────────────────────
//  VERIFICAÇÃO DE ESTUDANTE POR OTP — aprovação automática (PDF §8)
//
//  Em vez de validar o RA (não há API nacional p/ isso), validamos que
//  a pessoa CONTROLA um e-mail institucional reconhecido: enviamos um
//  código e, se ela confirmar, aprovamos na hora — sem revisão humana.
//  Quem não tem e-mail institucional cai no fluxo manual (comprovante).
// ────────────────────────────────────────────────────────────────

/** Domínios reconhecidos p/ verificação automática de estudante.
 *  Espelha a lista do app; qualquer `.edu.br` também é aceito. */
const APPROVED_STUDENT_DOMAINS = new Set<string>([
  "usp.br", "unicamp.br", "ufmg.edu.br", "ufrj.br", "ufpe.br",
  "ufsc.br", "ufrgs.br", "unesp.br", "ufba.br", "unb.br",
]);

function isApprovedStudentEmail(email: string): boolean {
  const e = email.trim().toLowerCase();
  const at = e.indexOf("@");
  if (at < 0) return false;
  const domain = e.substring(at + 1);
  if (domain.endsWith(".edu.br")) return true;
  return [...APPROVED_STUDENT_DOMAINS].some(
    (d) => domain === d || domain.endsWith("." + d)
  );
}

// sendStudentVerificationCode — envia OTP ao e-mail institucional.
export const sendStudentVerificationCode = onCall(
  {
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    secrets: [SMTP_USER, SMTP_PASS],
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
  },
  async (
    request: CallableRequest<{ institutionalEmail?: string; institution?: string }>
  ): Promise<{ sent: boolean }> => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Usuário não autenticado.");

    const email = (request.data?.institutionalEmail ?? "").toString().trim();
    const institution = (request.data?.institution ?? "").toString().trim().slice(0, 160);
    if (!email || !email.includes("@")) {
      throw new HttpsError("invalid-argument", "E-mail institucional inválido.");
    }
    if (!isApprovedStudentEmail(email)) {
      throw new HttpsError(
        "failed-precondition",
        "Esse e-mail não é de uma instituição reconhecida para verificação automática. Envie um comprovante de matrícula para análise."
      );
    }

    // Rate-limit por IP e por usuário (anti-abuso do SMTP / brute de e-mails).
    const ip = request.rawRequest?.ip ?? "unknown";
    await checkRateLimit(`auth:ip_${ip}:sendStudentOtp`, RATE_AUTH.limit, RATE_AUTH.windowMs);
    await checkRateLimit(
      rateLimitKey("auth", uid, "sendStudentOtp"),
      RATE_AUTH.limit,
      RATE_AUTH.windowMs
    );

    const otp = String(crypto.randomInt(100000, 1000000));
    const expiresAt = admin.firestore.Timestamp.fromMillis(Date.now() + 10 * 60 * 1000);

    await db.collection("_student_otps").doc(uid).set({
      uid,
      email: email.toLowerCase(),
      institution,
      code: otp,
      expiresAt,
      attempts: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const smtpUser = process.env.SMTP_USER ?? "";
    const smtpPass = process.env.SMTP_PASS ?? "";
    if (!smtpUser || !smtpPass) {
      logger.error("[sendStudentVerificationCode] SMTP não configurado.");
      throw new HttpsError("internal", "Serviço de e-mail indisponível. Tente mais tarde.");
    }

    const transporter = nodemailer.createTransport({
      service: "gmail",
      auth: { user: smtpUser, pass: smtpPass },
    });

    await transporter.sendMail({
      from: `"SPARK" <${smtpUser}>`,
      to: email,
      subject: "Verificação de estudante SPARK",
      html: `
        <div style="font-family:sans-serif;max-width:480px;margin:0 auto;background:#0d1117;color:#fff;padding:32px;border-radius:16px;">
          <h1 style="color:#00ff88;margin:0 0 8px;">⚡ SPARK</h1>
          <p style="color:#aaa;margin:0 0 24px;">Verificação de Estudante</p>
          <p style="margin:0 0 16px;">Use o código abaixo para confirmar sua matrícula e liberar o plano Student:</p>
          <div style="background:#1a2332;border:2px solid #00ff88;border-radius:12px;padding:24px;text-align:center;margin:0 0 24px;">
            <span style="font-size:40px;font-weight:900;letter-spacing:12px;color:#00ff88;">${otp}</span>
          </div>
          <p style="color:#aaa;font-size:13px;">Este código expira em <strong style='color:#fff;'>10 minutos</strong>.</p>
          <p style="color:#555;font-size:12px;">Se você não solicitou, ignore este e-mail.</p>
        </div>
      `,
    });

    logger.info(`[sendStudentVerificationCode] OTP enviado para ${email} (uid=${uid}).`);
    return { sent: true };
  }
);

// verifyStudentVerificationCode — valida o OTP e APROVA o estudante.
export const verifyStudentVerificationCode = onCall(
  {
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
  },
  async (
    request: CallableRequest<{ code?: string }>
  ): Promise<{ verified: boolean; error?: string }> => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Usuário não autenticado.");

    await checkRateLimit(
      rateLimitKey("auth", uid, "verifyStudentOtp"),
      RATE_AUTH.limit,
      RATE_AUTH.windowMs
    );

    const code = (request.data?.code ?? "").toString().trim();
    if (code.length !== 6) return { verified: false, error: "Código inválido." };

    const ref = db.collection("_student_otps").doc(uid);
    const snap = await ref.get();
    if (!snap.exists) {
      return { verified: false, error: "Nenhum código encontrado. Solicite um novo." };
    }
    const otp = snap.data()!;

    const expiresAt = (otp["expiresAt"] as admin.firestore.Timestamp).toMillis();
    if (Date.now() > expiresAt) {
      await ref.delete();
      return { verified: false, error: "Código expirado. Solicite um novo." };
    }

    const attempts = (otp["attempts"] as number) ?? 0;
    if (attempts >= 5) {
      await ref.delete();
      return { verified: false, error: "Muitas tentativas. Solicite um novo código." };
    }

    if (otp["code"] !== code) {
      await ref.update({ attempts: admin.firestore.FieldValue.increment(1) });
      const remaining = 4 - attempts;
      return {
        verified: false,
        error: `Código incorreto. ${remaining > 0 ? `${remaining} tentativa(s) restante(s).` : "Solicite um novo código."}`,
      };
    }

    // Código correto → aprova o estudante automaticamente.
    const email = (otp["email"] as string) ?? "";
    const institution = (otp["institution"] as string) ?? "";
    const batch = db.batch();
    batch.set(
      db.collection("student_verifications").doc(uid),
      {
        uid,
        institution,
        email,
        method: "email_otp",
        status: "approved",
        autoEligible: true,
        approvedVia: "otp",
        reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    batch.set(
      db.collection("users").doc(uid),
      {
        studentVerified: true,
        studentVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    batch.delete(ref);
    await batch.commit();

    // Libera qualquer assinatura Student paga na LP que estava segurada.
    await claimPendingActivationsByUid(uid);

    logger.info(`[verifyStudentVerificationCode] uid=${uid} aprovado via OTP (${email}).`);
    return { verified: true };
  }
);

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

export const deleteAccount = onCall(
  {
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
  },
  async (request: CallableRequest<unknown>): Promise<{ ok: boolean }> => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Usuário não autenticado.");
    }

    await checkRateLimit(
      rateLimitKey("auth", uid, "deleteAccount"),
      RATE_AUTH.limit,
      RATE_AUTH.windowMs
    );

    const userRef = db.collection("users").doc(uid);
    const userSnap = await userRef.get();
    const clanId = userSnap.exists
      ? (userSnap.data()?.["clanId"] as string | undefined)
      : undefined;

    // 1. Sai do clã
    if (clanId) {
      try {
        await removeUserFromClan(clanId, uid);
      } catch (e) {
        logger.warn(`[deleteAccount] falha ao sair do clã ${clanId}:`, e);
      }
    }

    // 2. Remove o usuário do ranking em TODAS as semanas
    try {
      const weeklyDoc = db.collection("rankings").doc("weekly");
      const weekCols = await weeklyDoc.listCollections();
      await Promise.all(
        weekCols.map((col) => col.doc(uid).delete().catch(() => {}))
      );
    } catch (e) {
      logger.warn("[deleteAccount] falha ao limpar rankings:", e);
    }

    // 3. Apaga o perfil público
    try {
      await db.recursiveDelete(db.collection("public_profiles").doc(uid));
    } catch (e) {
      logger.warn("[deleteAccount] falha ao apagar public_profile:", e);
    }

    // 4. Apaga o documento do usuário e todas as subcoleções
    try {
      await db.recursiveDelete(userRef);
    } catch (e) {
      logger.warn("[deleteAccount] falha ao apagar user doc:", e);
    }

    // 5. Apaga o usuário do Firebase Auth (por último)
    try {
      await admin.auth().deleteUser(uid);
    } catch (e) {
      logger.warn("[deleteAccount] falha ao apagar auth user:", e);
    }

    logger.info(`[deleteAccount] conta ${uid} excluída permanentemente.`);
    return { ok: true };
  }
);

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
const DUEL_QUESTION_TIME_MS = 15_000; // tempo por questão (igual ao app)
const DUEL_QUEUE_TTL_MS = 15_000; // entrada da fila expira sem heartbeat
const DUEL_RATE = { limit: 60, windowMs: 60 * 1000 } as const;

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
const DUEL_FORCE_GRACE_MS = 15_000;

interface DuelQuestionFull {
  id: string;
  statement: string;
  options: string[];
  correctIndex: number;
}

// Cache em memória do banco de questões (warm instances) — evita varrer
// o collectionGroup a cada matchmaking.
let _questionCache: DuelQuestionFull[] | null = null;
let _questionCacheAt = 0;
const QUESTION_CACHE_TTL_MS = 5 * 60 * 1000;

async function loadDuelQuestionPool(): Promise<DuelQuestionFull[]> {
  const now = Date.now();
  if (_questionCache && now - _questionCacheAt < QUESTION_CACHE_TTL_MS) {
    return _questionCache;
  }

  // Sem where() → não exige índice de collection-group. Filtramos em memória.
  const snap = await db
    .collectionGroup("questions")
    .select("type", "statement", "options", "correctIndex", "isActive")
    .get();

  const pool: DuelQuestionFull[] = [];
  snap.forEach((doc) => {
    const d = doc.data();
    if (d["isActive"] === false) return;
    if (d["type"] !== "multipleChoice") return; // duelo usa só múltipla escolha
    const options = d["options"];
    const correctIndex = d["correctIndex"];
    const statement = d["statement"];
    if (!Array.isArray(options) || options.length < 2) return;
    if (
      typeof correctIndex !== "number" ||
      correctIndex < 0 ||
      correctIndex >= options.length
    ) {
      return;
    }
    if (typeof statement !== "string" || statement.trim() === "") return;
    pool.push({
      id: doc.id,
      statement: statement.trim(),
      options: options.map((o: unknown) => String(o)),
      correctIndex,
    });
  });

  _questionCache = pool;
  _questionCacheAt = now;
  logger.info(`[duel] pool de questões recarregado: ${pool.length} válidas`);
  return pool;
}

function pickRandomDuelQuestions(
  pool: DuelQuestionFull[],
  count: number
): DuelQuestionFull[] {
  const arr = [...pool];
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr.slice(0, Math.min(count, arr.length));
}

/** Pontuação de uma rodada — espelha o cálculo do app. */
function duelRoundScore(isCorrect: boolean, timeMs: number): number {
  if (!isCorrect) return 0;
  const clamped = Math.max(0, Math.min(DUEL_QUESTION_TIME_MS, timeMs));
  return Math.max(0, Math.min(100, 100 - clamped / 100));
}

function sumDuelScores(answers: Array<Record<string, unknown>>): number {
  return answers.reduce((acc, a) => acc + ((a["score"] as number) ?? 0), 0);
}

async function fetchPlayerCard(
  uid: string
): Promise<{ name: string; photo: string | null; elo: number }> {
  try {
    const snap = await db.collection("users").doc(uid).get();
    const d = snap.data() ?? {};
    return {
      name: (d["displayName"] as string) || (d["name"] as string) || "Jogador",
      photo: (d["photoUrl"] as string) ?? null,
      elo: (d["eloRating"] as number) ?? 0,
    };
  } catch {
    return { name: "Jogador", photo: null, elo: 0 };
  }
}

// ── 1. joinDuelQueue ────────────────────────────────────────────────

interface JoinQueueResult {
  status: "matched" | "waiting";
  matchId?: string;
}

class OpponentTakenError extends Error {}

/** Lançada quando, dentro da transação de pareamento, descobrimos que o
 *  PRÓPRIO iniciador já foi pareado por outro jogador. Evita criar uma
 *  segunda partida (duplo-pareamento) numa corrida de heartbeat. */
class AlreadyMatchedError extends Error {
  constructor(public readonly matchId: string) {
    super("already matched");
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
async function sendPushToUser(
  uid: string,
  payload: { title: string; body: string; data?: Record<string, string> }
): Promise<void> {
  try {
    const snap = await db.collection("users").doc(uid).get();
    const token = snap.get("fcmToken") as string | undefined;
    if (!token) return;

    await admin.messaging().send({
      token,
      notification: { title: payload.title, body: payload.body },
      data: payload.data ?? {},
      android: { priority: "high", notification: { sound: "default" } },
      apns: {
        headers: { "apns-priority": "10" },
        payload: { aps: { sound: "default" } },
      },
    });
  } catch (e: unknown) {
    const code = (e as { code?: string })?.code ?? "";
    // Token inválido/expirado → remove para não tentar de novo.
    if (
      code === "messaging/registration-token-not-registered" ||
      code === "messaging/invalid-registration-token" ||
      code === "messaging/invalid-argument"
    ) {
      await db
        .collection("users")
        .doc(uid)
        .update({ fcmToken: admin.firestore.FieldValue.delete() })
        .catch(() => undefined);
    }
    logger.warn(`[sendPushToUser] uid=${uid} push falhou:`, e);
  }
}

export const joinDuelQueue = onCall(
  {
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
  },
  async (request: CallableRequest): Promise<JoinQueueResult> => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Usuário não autenticado.");

    await checkRateLimit(
      rateLimitKey("gamification", uid, "joinDuelQueue"),
      DUEL_RATE.limit,
      DUEL_RATE.windowMs
    );

    // Cooldown por abandono: jogador "de castigo" não entra no matchmaking.
    const meSnap = await db.collection("users").doc(uid).get();
    const cooldownUntil = meSnap.get("duelCooldownUntil") as
      | FirebaseFirestore.Timestamp
      | undefined;
    if (cooldownUntil && cooldownUntil.toMillis() > Date.now()) {
      const remainingMs = cooldownUntil.toMillis() - Date.now();
      throw new HttpsError(
        "resource-exhausted",
        "Você abandonou partidas demais. Aguarde o cooldown para jogar de novo.",
        { cooldownUntil: cooldownUntil.toMillis(), remainingMs }
      );
    }

    const myQueueRef = db.collection("matchmaking_queue").doc(uid);
    const now = Date.now();

    // (a) Já fui pareado por outro jogador enquanto esperava?
    const mySnap = await myQueueRef.get();
    let staleCleared = false;
    const existingMatchId = mySnap.data()?.["matchId"] as string | undefined;
    if (existingMatchId) {
      // Só recoloca na partida se ela AINDA existe e está ativa. Caso contrário
      // (partida encerrada/abandonada), a entrada está velha: limpa e segue para
      // um novo pareamento — senão o jogador cairia numa "partida fantasma".
      const existingSnap = await db.collection("matches").doc(existingMatchId).get();
      if (existingSnap.exists && existingSnap.data()?.["status"] === "active") {
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

    let opponentRef: FirebaseFirestore.DocumentReference | null = null;
    for (const doc of candidates.docs) {
      if (doc.id === uid) continue;
      const d = doc.data();
      if (d["matchId"]) continue; // já pareado
      const lastSeen = (d["lastSeen"] as FirebaseFirestore.Timestamp | undefined)?.toMillis() ?? 0;
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
          throw new HttpsError(
            "failed-precondition",
            "Não há perguntas suficientes cadastradas para um duelo."
          );
        }
        const picked = pickRandomDuelQuestions(pool, DUEL_QUESTION_COUNT);

        const [meCard, oppCard] = await Promise.all([
          fetchPlayerCard(uid),
          fetchPlayerCard(opponentRef.id),
        ]);

        const matchRef = db.collection("matches").doc();
        const oppUid = opponentRef.id;

        await db.runTransaction(async (tx) => {
          const [oppDoc, myDoc] = await Promise.all([
            tx.get(opponentRef!),
            tx.get(myQueueRef),
          ]);
          // Corrida de heartbeat: outro jogador me pareou enquanto eu procurava
          // um oponente. NÃO crio uma segunda partida — devolvo a que já existe.
          const myMatchId = myDoc.data()?.["matchId"] as string | undefined;
          if (myMatchId) throw new AlreadyMatchedError(myMatchId);
          if (!oppDoc.exists) throw new OpponentTakenError();
          const od = oppDoc.data()!;
          if (od["matchId"]) throw new OpponentTakenError();
          const lastSeen = (od["lastSeen"] as FirebaseFirestore.Timestamp | undefined)?.toMillis() ?? 0;
          if (now - lastSeen > DUEL_QUEUE_TTL_MS) throw new OpponentTakenError();

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
          tx.set(
            opponentRef!,
            { matchId: matchRef.id, status: "matched" },
            { merge: true }
          );

          // Eu (iniciador) saio da fila.
          tx.delete(myQueueRef);
        });

        logger.info(`[joinDuelQueue] match ${matchRef.id}: ${oppUid} vs ${uid}`);

        // Avisa por push o jogador que ESTAVA esperando (oppUid): o iniciador
        // já está com o app aberto, mas o oponente pode tê-lo em background.
        await sendPushToUser(oppUid, {
          title: "⚔️ Você foi pareado para um duelo!",
          body: `${meCard.name} entrou na arena. Abra o Spark e dispute!`,
          data: { type: "duel_matched", matchId: matchRef.id },
        });

        return { status: "matched", matchId: matchRef.id };
      } catch (e) {
        // Já fui pareado por outro durante a transação → devolvo essa partida.
        if (e instanceof AlreadyMatchedError) {
          return { status: "matched", matchId: e.matchId };
        }
        if (!(e instanceof OpponentTakenError)) throw e;
        // Oponente foi pego por outro — cai para enfileirar.
      }
    }

    // (d) Sem oponente → entra/atualiza a fila (heartbeat).
    await myQueueRef.set(
      {
        uid,
        status: "waiting",
        matchId: null,
        joinedAt: mySnap.exists && !staleCleared
          ? mySnap.data()?.["joinedAt"] ?? admin.firestore.FieldValue.serverTimestamp()
          : admin.firestore.FieldValue.serverTimestamp(),
        lastSeen: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    return { status: "waiting" };
  }
);

// ── 2. leaveDuelQueue ───────────────────────────────────────────────

export const leaveDuelQueue = onCall(
  {
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
  },
  async (request: CallableRequest): Promise<{ ok: boolean }> => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Usuário não autenticado.");
    await db.collection("matchmaking_queue").doc(uid).delete().catch(() => undefined);
    return { ok: true };
  }
);

// ── 3. submitDuelAnswer ─────────────────────────────────────────────

interface SubmitAnswerData {
  matchId: string;
  questionIndex: number;
  selectedOption: number;
  elapsedMs: number;
}

interface SubmitAnswerResult {
  isCorrect: boolean;
  correctIndex: number;
  score: number;
}

export const submitDuelAnswer = onCall(
  {
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
  },
  async (
    request: CallableRequest<SubmitAnswerData>
  ): Promise<SubmitAnswerResult> => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Usuário não autenticado.");

    await checkRateLimit(
      rateLimitKey("gamification", uid, "submitDuelAnswer"),
      DUEL_RATE.limit,
      DUEL_RATE.windowMs
    );

    const { matchId, questionIndex, selectedOption, elapsedMs } = request.data;
    if (typeof matchId !== "string" || !matchId) {
      throw new HttpsError("invalid-argument", "matchId inválido.");
    }
    if (typeof questionIndex !== "number" || questionIndex < 0) {
      throw new HttpsError("invalid-argument", "questionIndex inválido.");
    }

    const matchRef = db.collection("matches").doc(matchId);
    const keyRef = matchRef.collection("secret").doc("key");

    let result!: SubmitAnswerResult;

    await db.runTransaction(async (tx) => {
      const [matchSnap, keySnap] = await Promise.all([
        tx.get(matchRef),
        tx.get(keyRef),
      ]);
      if (!matchSnap.exists) throw new HttpsError("not-found", "Duelo não encontrado.");

      const m = matchSnap.data()!;
      const isP1 = m["player1Uid"] === uid;
      const isP2 = m["player2Uid"] === uid;
      if (!isP1 && !isP2) {
        throw new HttpsError("permission-denied", "Você não participa deste duelo.");
      }
      if (m["status"] !== "active") {
        throw new HttpsError("failed-precondition", "Duelo já encerrado.");
      }

      const questions = (m["questions"] as Array<unknown>) ?? [];
      if (questionIndex >= questions.length) {
        throw new HttpsError("invalid-argument", "Índice de questão fora do intervalo.");
      }

      const scoresField = isP1 ? "player1Scores" : "player2Scores";
      const doneField = isP1 ? "player1Done" : "player2Done";
      const answers = (m[scoresField] as Array<Record<string, unknown>>) ?? [];

      // Anti-replay: só aceita a próxima questão esperada, em ordem.
      if (questionIndex !== answers.length) {
        throw new HttpsError("failed-precondition", "Resposta fora de ordem ou duplicada.");
      }

      const answerKey = (keySnap.data()?.["answers"] as number[]) ?? [];
      const correctIndex = answerKey[questionIndex] ?? -1;
      const isCorrect = selectedOption === correctIndex;
      const timeMs = Math.max(0, Math.min(DUEL_QUESTION_TIME_MS, elapsedMs ?? DUEL_QUESTION_TIME_MS));
      const score = duelRoundScore(isCorrect, timeMs);

      const round = {
        q: questionIndex,
        selectedOption: typeof selectedOption === "number" ? selectedOption : -1,
        isCorrect,
        timeMs,
        score,
      };

      const updates: Record<string, unknown> = {
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
  }
);

// ── 4. finalizeDuel ─────────────────────────────────────────────────

interface FinalizeData {
  matchId: string;
  force?: boolean;
}

interface FinalizeResult {
  status: "finished" | "waiting";
  winnerId?: string | null;
  player1Total?: number;
  player2Total?: number;
  eloChange?: number;
  newElo?: number;
}

export const finalizeDuel = onCall(
  {
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
  },
  async (request: CallableRequest<FinalizeData>): Promise<FinalizeResult> => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Usuário não autenticado.");

    await checkRateLimit(
      rateLimitKey("gamification", uid, "finalizeDuel"),
      DUEL_RATE.limit,
      DUEL_RATE.windowMs
    );

    const { matchId, force } = request.data;
    if (typeof matchId !== "string" || !matchId) {
      throw new HttpsError("invalid-argument", "matchId inválido.");
    }

    const matchRef = db.collection("matches").doc(matchId);
    let result!: FinalizeResult;

    await db.runTransaction(async (tx) => {
      const matchSnap = await tx.get(matchRef);
      if (!matchSnap.exists) throw new HttpsError("not-found", "Duelo não encontrado.");
      const m = matchSnap.data()!;

      const p1 = m["player1Uid"] as string;
      const p2 = m["player2Uid"] as string;
      if (uid !== p1 && uid !== p2) {
        throw new HttpsError("permission-denied", "Você não participa deste duelo.");
      }

      const p1Answers = (m["player1Scores"] as Array<Record<string, unknown>>) ?? [];
      const p2Answers = (m["player2Scores"] as Array<Record<string, unknown>>) ?? [];
      const total = (m["questions"] as Array<unknown>)?.length ?? DUEL_QUESTION_COUNT;
      const p1Total = sumDuelScores(p1Answers);
      const p2Total = sumDuelScores(p2Answers);

      // Já finalizado → idempotente.
      if (m["status"] === "finished") {
        const isP1 = uid === p1;
        const myChange = (m[isP1 ? "player1EloChange" : "player2EloChange"] as number) ?? 0;
        result = {
          status: "finished",
          winnerId: (m["winnerId"] as string) ?? null,
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
          throw new HttpsError(
            "failed-precondition",
            "Conclua suas perguntas antes de encerrar o duelo."
          );
        }
        // (b) o oponente precisa ter tido um período de carência para terminar
        //     APÓS o primeiro a concluir. Sem o marco `firstDoneAt` (docs
        //     legados), exige a duração máxima honesta desde a criação.
        const firstDoneMs =
          (m["firstDoneAt"] as FirebaseFirestore.Timestamp | undefined)?.toMillis();
        const createdMs =
          (m["createdAt"] as FirebaseFirestore.Timestamp | undefined)?.toMillis();
        const since = firstDoneMs ?? createdMs ?? 0;
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
      let winnerId: string | null = null;
      if (p1Total > p2Total) winnerId = p1;
      else if (p2Total > p1Total) winnerId = p2;

      const p1Ref = db.collection("users").doc(p1);
      const p2Ref = db.collection("users").doc(p2);
      const [p1Snap, p2Snap] = await Promise.all([tx.get(p1Ref), tx.get(p2Ref)]);

      const p1Elo = (p1Snap.data()?.["eloRating"] as number) ?? 0;
      const p2Elo = (p2Snap.data()?.["eloRating"] as number) ?? 0;

      // ELO real: ganha-se MAIS batendo quem é mais forte e perde-se MENOS
      // perdendo para quem é mais forte (e vice-versa).
      const expected1 = 1 / (1 + Math.pow(10, (p2Elo - p1Elo) / 400));
      const expected2 = 1 - expected1;
      const s1 = winnerId === null ? 0.5 : winnerId === p1 ? 1 : 0;
      const s2 = 1 - s1;

      const clampChange = (raw: number, currentElo: number): number => {
        const capped = Math.max(-DUEL_ELO_MAX, Math.min(DUEL_ELO_MAX, Math.round(raw)));
        return Math.max(capped, -currentElo); // ELO nunca fica negativo
      };
      const p1Change = clampChange(DUEL_ELO_K * (s1 - expected1), p1Elo);
      const p2Change = clampChange(DUEL_ELO_K * (s2 - expected2), p2Elo);

      const applyElo = (
        ref: FirebaseFirestore.DocumentReference,
        snap: FirebaseFirestore.DocumentSnapshot,
        change: number,
        won: boolean | null
      ) => {
        if (!snap.exists) return;
        const data = snap.data()!;
        const updates: Record<string, unknown> = {
          eloRating: admin.firestore.FieldValue.increment(change),
          totalDuels: admin.firestore.FieldValue.increment(1),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        if (won === true) updates["wins"] = admin.firestore.FieldValue.increment(1);
        else if (won === false) updates["losses"] = admin.firestore.FieldValue.increment(1);
        const unlocked: string[] = data["unlockedBadgeIds"] ?? [];
        if (((data["totalDuels"] as number) ?? 0) === 0 && !unlocked.includes("primeiro_duelo")) {
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

    logger.info(`[finalizeDuel] match=${matchId} status=${result.status} winner=${result.winnerId ?? "-"}`);
    return result;
  }
);

// ── 4b. leaveDuel ───────────────────────────────────────────────────
//  Abandono explícito: o jogador SAIU da partida no meio (fechou a tela
//  ou o app). O oponente que continuou VENCE por W.O. e leva o ELO da
//  vitória. O doc do match é marcado com `abandonedBy` para o cliente do
//  oponente exibir a mensagem "seu oponente saiu". Idempotente: se a
//  partida já foi encerrada (ou é treino), não faz nada.

interface LeaveDuelData {
  matchId: string;
}

export const leaveDuel = onCall(
  {
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
  },
  async (
    request: CallableRequest<LeaveDuelData>
  ): Promise<{ ok: boolean; finished: boolean }> => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Usuário não autenticado.");

    await checkRateLimit(
      rateLimitKey("gamification", uid, "leaveDuel"),
      DUEL_RATE.limit,
      DUEL_RATE.windowMs
    );

    const { matchId } = request.data ?? ({} as LeaveDuelData);
    if (typeof matchId !== "string" || !matchId) {
      throw new HttpsError("invalid-argument", "matchId inválido.");
    }

    const matchRef = db.collection("matches").doc(matchId);
    let finished = false;

    await db.runTransaction(async (tx) => {
      const matchSnap = await tx.get(matchRef);
      if (!matchSnap.exists) return; // nada a fazer
      const m = matchSnap.data()!;

      const p1 = m["player1Uid"] as string;
      const p2 = m["player2Uid"] as string;
      if (uid !== p1 && uid !== p2) {
        throw new HttpsError("permission-denied", "Você não participa deste duelo.");
      }
      // Já encerrado (quem chegou primeiro decide) ou treino → ignora.
      if (m["status"] !== "active" || m["isBot"] === true) return;

      // Quem SAI perde; o oponente que CONTINUOU vence.
      const winnerId = uid === p1 ? p2 : p1;

      const p1Ref = db.collection("users").doc(p1);
      const p2Ref = db.collection("users").doc(p2);
      const [p1Snap, p2Snap] = await Promise.all([tx.get(p1Ref), tx.get(p2Ref)]);

      const p1Elo = (p1Snap.data()?.["eloRating"] as number) ?? 0;
      const p2Elo = (p2Snap.data()?.["eloRating"] as number) ?? 0;

      const expected1 = 1 / (1 + Math.pow(10, (p2Elo - p1Elo) / 400));
      const expected2 = 1 - expected1;
      const s1 = winnerId === p1 ? 1 : 0;
      const s2 = 1 - s1;

      const clampChange = (raw: number, currentElo: number): number => {
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
      const priorAbandons =
        (abandonerSnap.data()?.["duelAbandons"] as number) ?? 0;
      const newAbandons = priorAbandons + 1;
      const abandonUpdates: Record<string, unknown> =
        newAbandons >= DUEL_ABANDON_LIMIT
          ? {
              duelAbandons: 0,
              duelCooldownUntil: admin.firestore.Timestamp.fromMillis(
                Date.now() + DUEL_COOLDOWN_MS
              ),
            }
          : { duelAbandons: newAbandons };

      const applyElo = (
        ref: FirebaseFirestore.DocumentReference,
        snap: FirebaseFirestore.DocumentSnapshot,
        change: number,
        won: boolean,
        extra?: Record<string, unknown>
      ) => {
        if (!snap.exists) return;
        const data = snap.data()!;
        const updates: Record<string, unknown> = {
          eloRating: admin.firestore.FieldValue.increment(change),
          totalDuels: admin.firestore.FieldValue.increment(1),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          ...(extra ?? {}),
        };
        if (won) updates["wins"] = admin.firestore.FieldValue.increment(1);
        else updates["losses"] = admin.firestore.FieldValue.increment(1);
        const unlocked: string[] = data["unlockedBadgeIds"] ?? [];
        if (((data["totalDuels"] as number) ?? 0) === 0 && !unlocked.includes("primeiro_duelo")) {
          updates["unlockedBadgeIds"] = admin.firestore.FieldValue.arrayUnion("primeiro_duelo");
        }
        tx.update(ref, updates);
      };

      applyElo(p1Ref, p1Snap, p1Change, winnerId === p1,
        abandonerIsP1 ? abandonUpdates : undefined);
      applyElo(p2Ref, p2Snap, p2Change, winnerId === p2,
        abandonerIsP1 ? undefined : abandonUpdates);

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

    logger.info(`[leaveDuel] match=${matchId} abandonedBy=${uid} finished=${finished}`);
    return { ok: true, finished };
  }
);

// ── 5. getBotDuelQuestions ──────────────────────────────────────────
//  Perguntas COM gabarito para partida de treino (vs bot). Treino não
//  afeta o ranking, então entregar o gabarito ao cliente é aceitável.

interface BotQuestionsData {
  count?: number;
}

export const getBotDuelQuestions = onCall(
  {
    enforceAppCheck: ENFORCE_APP_CHECK,
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
  },
  async (
    request: CallableRequest<BotQuestionsData>
  ): Promise<{ questions: DuelQuestionFull[] }> => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Usuário não autenticado.");

    await checkRateLimit(
      rateLimitKey("gamification", uid, "getBotDuelQuestions"),
      DUEL_RATE.limit,
      DUEL_RATE.windowMs
    );

    const count = Math.max(3, Math.min(15, request.data?.count ?? DUEL_QUESTION_COUNT));
    const pool = await loadDuelQuestionPool();
    if (pool.length === 0) {
      throw new HttpsError(
        "failed-precondition",
        "Não há perguntas cadastradas para o duelo."
      );
    }
    return { questions: pickRandomDuelQuestions(pool, count) };
  }
);

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
] as const;

/** Extrai apenas os campos públicos de um doc de usuário. */
function pickPublicFields(
  data: Record<string, unknown>
): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const key of PUBLIC_PROFILE_FIELDS) {
    if (data[key] !== undefined) out[key] = data[key];
  }
  return out;
}

export const syncPublicProfile = onDocumentWritten(
  {
    document: "users/{uid}",
    // Este projeto usa um banco Firestore NOMEADO ("default"), não o
    // "(default)". Sem declarar isto o deploy do trigger falha com 404
    // ("database '(default)' does not exist") e o gatilho nunca dispara.
    database: "default",
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
  },
  async (event) => {
    const uid = event.params.uid;
    const publicRef = db.collection("public_profiles").doc(uid);

    const after = event.data?.after;
    // Documento de usuário foi apagado → remove o espelho público.
    // (deleteAccount já remove explicitamente, mas isto cobre exclusões diretas.)
    if (!after || !after.exists) {
      await publicRef.delete().catch(() => {});
      logger.info(`[syncPublicProfile] uid=${uid} removido (user apagado).`);
      return;
    }

    const afterData = after.data() ?? {};

    // Contas de admin/teste NÃO aparecem em nenhum ranking (Global, Torneio
    // ou clã, que leem public_profiles). Remove o espelho e sai.
    if (afterData["role"] === "admin" || afterData["excludeFromRanking"] === true) {
      await publicRef.delete().catch(() => {});
      logger.info(`[syncPublicProfile] uid=${uid} excluído do ranking (admin/teste).`);
      return;
    }

    const newPublic = pickPublicFields(afterData);
    // Garante que os campos de ordenação dos rankings sempre existam — sem
    // eles o documento some do orderBy('xp')/orderBy('weeklyXp').
    if (newPublic["xp"] === undefined) newPublic["xp"] = 0;
    if (newPublic["weeklyXp"] === undefined) newPublic["weeklyXp"] = 0;

    // Evita escritas desnecessárias (e loops de custo): só grava se algum
    // campo público realmente mudou em relação ao estado anterior.
    const beforeData = event.data?.before?.data() ?? {};
    const oldPublic = pickPublicFields(beforeData);
    const changed = PUBLIC_PROFILE_FIELDS.some(
      (k) => JSON.stringify(oldPublic[k]) !== JSON.stringify(newPublic[k])
    );
    if (event.data?.before?.exists && !changed) {
      return;
    }

    newPublic["uid"] = uid;
    newPublic["updatedAt"] = admin.firestore.FieldValue.serverTimestamp();

    await publicRef.set(newPublic, { merge: true });
    logger.info(`[syncPublicProfile] uid=${uid} espelho público atualizado.`);
  }
);

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

export const closeTournament = onSchedule(
  {
    // 00:05 de segunda (BRT) — logo após a virada da semana.
    schedule: "every monday 00:05",
    timeZone: "America/Sao_Paulo",
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
  },
  async () => {
    const weekKey = lastWeekKey();

    // 1) Top 3 por weeklyXp (apenas quem realmente pontuou).
    const topSnap = await db
      .collection("public_profiles")
      .orderBy("weeklyXp", "desc")
      .limit(3)
      .get();
    const winners = topSnap.docs.filter(
      (d) => ((d.get("weeklyXp") as number) ?? 0) > 0
    );

    const historyCol = db
      .collection("rankings")
      .doc("tournament_history")
      .collection(weekKey);

    for (let i = 0; i < winners.length; i++) {
      const doc = winners[i];
      const uid = doc.id;
      const place = i + 1;
      const prize = TOURNAMENT_PRIZES[i] ?? 0;
      const finalWeeklyXp = (doc.get("weeklyXp") as number) ?? 0;

      try {
        // Premia o XP total (cascateia para public_profiles via trigger).
        await db.collection("users").doc(uid).set(
          {
            xp: admin.firestore.FieldValue.increment(prize),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

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
          displayName: doc.get("displayName") ?? "Usuário",
          photoUrl: doc.get("photoUrl") ?? null,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (e) {
        logger.warn(`[closeTournament] falha ao premiar uid=${uid}:`, e);
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
      if (snap.empty) break;

      const batch = db.batch();
      for (const d of snap.docs) {
        batch.update(d.ref, { weeklyXp: 0 });
      }
      await batch.commit();
      resetCount += snap.size;
      if (snap.size < 400) break;
    }

    logger.info(
      `[closeTournament] semana=${weekKey} premiados=${winners.length} ` +
        `weeklyXp_resetado=${resetCount}`
    );
  }
);

// ────────────────────────────────────────────────────────────────
// streakReminder — Agendada (20:00 BRT). Avisa quem tem streak ativo
// (currentStreak > 0) mas AINDA não estudou hoje que a ofensiva expira
// à meia-noite. Cria uma notificação in-app (type "streakAtRisk", lida
// pelo NotificationService) e dispara o push.
//
// Não confiamos só no flag `studiedToday` (que é resetado pelo cliente e
// pode estar velho): comparamos `lastStudyDate` com o dia atual em BRT.
// ────────────────────────────────────────────────────────────────

export const streakReminder = onSchedule(
  {
    schedule: "every day 20:00",
    timeZone: "America/Sao_Paulo",
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
  },
  async () => {
    // Chave do "hoje" em BRT (UTC-3), independente de fuso do runtime.
    const dayKey = (ms: number): string => {
      const d = new Date(ms - 3 * 60 * 60 * 1000);
      return `${d.getUTCFullYear()}-${d.getUTCMonth()}-${d.getUTCDate()}`;
    };
    const todayKey = dayKey(Date.now());

    let sent = 0;
    let last: FirebaseFirestore.QueryDocumentSnapshot | undefined;
    while (true) {
      let q = db
        .collection("users")
        .where("currentStreak", ">", 0)
        .orderBy("currentStreak")
        .limit(300);
      if (last) q = q.startAfter(last);
      const snap = await q.get();
      if (snap.empty) break;

      for (const doc of snap.docs) {
        const data = doc.data();
        const streak = (data["currentStreak"] as number) ?? 0;
        if (streak <= 0) continue;

        // Já estudou hoje → streak garantido, não incomoda.
        const ls = data["lastStudyDate"] as
          | FirebaseFirestore.Timestamp
          | undefined;
        if (ls && dayKey(ls.toMillis()) === todayKey) continue;

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
      if (snap.size < 300) break;
    }

    logger.info(`[streakReminder] lembretes enviados=${sent}`);
  }
);

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

export const cleanupStaleDuels = onSchedule(
  {
    schedule: "every 15 minutes",
    timeZone: "America/Sao_Paulo",
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
  },
  async () => {
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
      if (m["isBot"] === true) continue; // treino não vive no servidor
      const createdAt = (m["createdAt"] as FirebaseFirestore.Timestamp | undefined)?.toMillis();
      // Sem createdAt (doc legado) também é tratado como velho.
      if (createdAt && now - createdAt < DUEL_STALE_TTL_MS) continue;

      const p1 = m["player1Uid"] as string | undefined;
      const p2 = m["player2Uid"] as string | undefined;
      const p1Total = sumDuelScores((m["player1Scores"] as Array<Record<string, unknown>>) ?? []);
      const p2Total = sumDuelScores((m["player2Scores"] as Array<Record<string, unknown>>) ?? []);
      let winnerId: string | null = null;
      if (p1 && p2) {
        if (p1Total > p2Total) winnerId = p1;
        else if (p2Total > p1Total) winnerId = p2;
      }

      try {
        const batch = db.batch();
        batch.update(doc.ref, {
          status: "finished",
          winnerId,
          closedBy: "cleanup",
          finishedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        if (p1) batch.delete(db.collection("matchmaking_queue").doc(p1));
        if (p2) batch.delete(db.collection("matchmaking_queue").doc(p2));
        await batch.commit();
        closed++;
      } catch (e) {
        logger.warn(`[cleanupStaleDuels] falha ao encerrar ${doc.id}:`, e);
      }
    }

    logger.info(
      `[cleanupStaleDuels] ${closed}/${snap.size} duelo(s) travado(s) encerrado(s).`
    );
  }
);

// ────────────────────────────────────────────────────────────────
// rankingAdminTask — ENDPOINT TEMPORÁRIO (mínimo). Protegido por token.
//   ?token=...&action=findname&q=souza
// REMOVER após o uso (firebase functions:delete rankingAdminTask).
// ────────────────────────────────────────────────────────────────
const RANKING_ADMIN_TOKEN = "rk_7Q2x9Mzv4Lp1Ad8Ws6Tc3Nb5Hf0Ej";

export const rankingAdminTask = onRequest(
  {
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
  },
  async (req, res) => {
    if (req.query.token !== RANKING_ADMIN_TOKEN) {
      res.status(403).json({ error: "forbidden" });
      return;
    }
    const action = String(req.query.action ?? "");
    try {
      if (action === "findname") {
        const q = String(req.query.q ?? "").toLowerCase();
        const [pubSnap, usersSnap] = await Promise.all([
          db.collection("public_profiles").get(),
          db.collection("users").get(),
        ]);
        const userById = new Map(usersSnap.docs.map((d) => [d.id, d]));
        const inPub = pubSnap.docs
          .filter((d) =>
            String(d.get("displayName") ?? "").toLowerCase().includes(q)
          )
          .map((d) => d.id);
        const inUsers = usersSnap.docs
          .filter((d) =>
            String(d.get("displayName") ?? "").toLowerCase().includes(q)
          )
          .map((d) => d.id);
        const uids = Array.from(new Set([...inPub, ...inUsers]));
        const matches = [];
        for (const uid of uids) {
          let email: string | null = null;
          try {
            email = (await admin.auth().getUser(uid)).email ?? null;
          } catch (_) {
            email = null;
          }
          const ud = userById.get(uid);
          const pd = pubSnap.docs.find((d) => d.id === uid);
          matches.push({
            uid,
            email,
            displayName: ud?.get("displayName") ?? pd?.get("displayName") ?? null,
            xp: ud?.get("xp") ?? pd?.get("xp") ?? 0,
            role: ud?.get("role") ?? null,
            inRanking: !!pd,
          });
        }
        res.json({ count: matches.length, matches });
        return;
      }
      res.status(400).json({ error: "unknown action" });
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      logger.error("[rankingAdminTask]", msg);
      res.status(500).json({ error: msg });
    }
  }
);
