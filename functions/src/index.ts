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
import { logger } from "firebase-functions/v2";
import { defineSecret } from "firebase-functions/params";
import * as nodemailer from "nodemailer";
import {
  findOrCreateCustomer,
  updateCustomer,
  createCharge,
  getChargeStatus,
  getChargeDetails,
  AsaasBillingType,
} from "./services/asaasService";
import {
  checkRateLimit,
  rateLimitKey,
  RATE_AUTH,
  RATE_PAYMENT,
  RATE_GAMIFICATION,
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

function currentWeekKey(): string {
  const now = new Date();
  const start = new Date(now.getFullYear(), 0, 1);
  const dayOfYear =
    Math.floor((now.getTime() - start.getTime()) / (1000 * 60 * 60 * 24)) + 1;
  const weekNum = Math.floor((dayOfYear - now.getDay() + 10) / 7);
  return `${now.getFullYear()}-W${String(weekNum).padStart(2, "0")}`;
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
const MAX_ELO_DELTA = 50;

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
    let rankingData: Record<string, any> | null = null;

    // Transação focada SOMENTE no documento do usuário (sem cross-document)
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(userRef);
      if (!snap.exists) {
        throw new HttpsError("not-found", "Documento do usuário não encontrado.");
      }

      const data = snap.data()!;
      const currentXp = (data["xp"] as number) ?? 0;
      const currentWeeklyXp = (data["weeklyXp"] as number) ?? 0;
      const unlockedBadgeIds: string[] = data["unlockedBadgeIds"] ?? [];
      const oldLevel = calcLevel(currentXp);

      const newXp = currentXp + amount;
      const newLevel = calcLevel(newXp);
      const newTension = calcTension(newXp);
      const newWeeklyXp = currentWeeklyXp + amount;
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

      // Armazena dados para ranking (será escrito fora da transação)
      rankingData = {
        uid,
        displayName: data["displayName"] ?? "Usuário",
        photoUrl: data["photoUrl"] ?? null,
        weeklyXp: newWeeklyXp,
        clanId: data["clanId"] ?? null,
        clanName: data["clanName"] ?? null,
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
      } catch (e) {
        logger.warn("[addXp] Erro ao atualizar ranking (não crítico):", e);
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
// 3. updateElo — Processa resultado de duelo e atualiza ELO rating
// ────────────────────────────────────────────────────────────────

interface UpdateEloData {
  eloChange: number;
  won: boolean | null; // true=vitória, false=derrota, null=empate
}

interface UpdateEloResult {
  newElo: number;
  totalDuels: number;
}

export const updateElo = onCall(
  {
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
  },
  async (request: CallableRequest<UpdateEloData>): Promise<UpdateEloResult> => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Usuário não autenticado.");
    }

    await checkRateLimit(
      rateLimitKey("gamification", uid, "updateElo"),
      RATE_GAMIFICATION.limit,
      RATE_GAMIFICATION.windowMs
    );

    const { eloChange, won } = request.data;

    if (typeof eloChange !== "number" || !Number.isFinite(eloChange)) {
      throw new HttpsError("invalid-argument", "eloChange deve ser um número.");
    }
    if (Math.abs(eloChange) > MAX_ELO_DELTA) {
      throw new HttpsError(
        "invalid-argument",
        `eloChange fora do intervalo permitido (±${MAX_ELO_DELTA}).`
      );
    }

    const userRef = db.collection("users").doc(uid);
    let result!: UpdateEloResult;

    await db.runTransaction(async (tx) => {
      const snap = await tx.get(userRef);
      if (!snap.exists) {
        throw new HttpsError("not-found", "Documento do usuário não encontrado.");
      }

      const data = snap.data()!;
      const currentElo = (data["eloRating"] as number) ?? 1200;
      const currentDuels = (data["totalDuels"] as number) ?? 0;
      const unlockedBadgeIds: string[] = data["unlockedBadgeIds"] ?? [];

      const updates: Record<string, unknown> = {
        eloRating: admin.firestore.FieldValue.increment(eloChange),
        totalDuels: admin.firestore.FieldValue.increment(1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (won === true) {
        updates["wins"] = admin.firestore.FieldValue.increment(1);
      } else if (won === false) {
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

    logger.info(
      `[updateElo] uid=${uid} change=${eloChange} won=${won} newElo=${result.newElo}`
    );
    return result;
  }
);

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
    secrets: [ASAAS_WEBHOOK_TOKEN, ASAAS_API_KEY, ASAAS_BASE_URL],
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
      logger.warn("[asaasWebhook] Pagamento sem externalReference.", payment);
      res.status(200).send("No externalReference");
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
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
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

    logger.info(`[startTrial] uid=${uid} plan=${planId} endsAt=${trialEndsAt.toISOString()}`);
    return { success: true, trialEndsAt: trialEndsAt.toISOString() };
  }
);

// ────────────────────────────────────────────────────────────────
// 10. cancelTrial — Cancela trial antes do vencimento
// ────────────────────────────────────────────────────────────────

export const cancelTrial = onCall(
  {
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

    await userRef.update({
      isOnTrial: false,
      isPremium: false,
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

    const expiredSnap = await db
      .collection("users")
      .where("isOnTrial", "==", true)
      .where("trialEndsAt", "<=", now)
      .get();

    if (expiredSnap.empty) {
      logger.info("[processTrialExpiry] Nenhum trial vencido.");
      return;
    }

    // Firestore limita um batch a 500 operações. Fatiamos em lotes para
    // não estourar o limite quando muitos trials vencerem no mesmo dia.
    const BATCH_LIMIT = 500;
    const docs = expiredSnap.docs;
    for (let i = 0; i < docs.length; i += BATCH_LIMIT) {
      const batch = db.batch();
      for (const doc of docs.slice(i, i + BATCH_LIMIT)) {
        batch.update(doc.ref, {
          isOnTrial: false,
          isPremium: false,
          trialEndsAt: null,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }

    logger.info(`[processTrialExpiry] ${expiredSnap.size} trial(s) expirado(s) e revogado(s).`);
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

// ────────────────────────────────────────────────────────────────
// syncPublicProfile — Espelha campos PÚBLICOS de users/{uid} em
// public_profiles/{uid} (LGPD: /users é privado; o espelho público
// não carrega e-mail, dados de pagamento nem tokens).
// As Security Rules deixam public_profiles como write:false (só o
// servidor escreve), e este trigger é o ÚNICO escritor. Sem ele a
// coleção fica vazia e o ranking all-time / telas de perfil quebram.
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
    const newPublic = pickPublicFields(afterData);

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
// cleanupOldRankings — Agendada semanalmente. Remove subcoleções de
// semanas antigas em rankings/weekly para o storage não crescer
// indefinidamente (o addXp cria uma subcoleção nova a cada semana e
// nada as apagava). Mantém as últimas RANKING_WEEKS_TO_KEEP semanas.
// O weekKey tem formato "YYYY-Www" (zero-padded), então a ordenação
// lexicográfica decrescente equivale à cronológica.
// ────────────────────────────────────────────────────────────────

const RANKING_WEEKS_TO_KEEP = 8;

export const cleanupOldRankings = onSchedule(
  {
    schedule: "every monday 04:00",
    timeZone: "America/Sao_Paulo",
    region: "southamerica-east1",
    serviceAccount: "spark-v1-e0eb5@appspot.gserviceaccount.com",
  },
  async () => {
    const weeklyDoc = db.collection("rankings").doc("weekly");
    const weekCols = await weeklyDoc.listCollections();

    if (weekCols.length <= RANKING_WEEKS_TO_KEEP) {
      logger.info(
        `[cleanupOldRankings] ${weekCols.length} semana(s); nada a limpar.`
      );
      return;
    }

    // Ordena por ID (weekKey) decrescente e mantém só as mais recentes.
    const sorted = weekCols.sort((a, b) => (a.id < b.id ? 1 : -1));
    const toDelete = sorted.slice(RANKING_WEEKS_TO_KEEP);

    for (const col of toDelete) {
      try {
        await db.recursiveDelete(col);
        logger.info(`[cleanupOldRankings] semana ${col.id} removida.`);
      } catch (e) {
        logger.warn(`[cleanupOldRankings] falha ao remover ${col.id}:`, e);
      }
    }

    logger.info(
      `[cleanupOldRankings] ${toDelete.length} semana(s) antiga(s) removida(s).`
    );
  }
);
