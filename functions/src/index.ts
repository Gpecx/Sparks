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
import {
  onCall,
  onRequest,
  CallableRequest,
  HttpsError,
} from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { defineSecret } from "firebase-functions/params";
import {
  findOrCreateCustomer,
  updateCustomer,
  createCharge,
  getChargeStatus,
  AsaasBillingType,
} from "./services/asaasService";

// ── Secrets vinculados ao Firebase Secret Manager ────────────────
const ASAAS_API_KEY       = defineSecret("ASAAS_API_KEY");
const ASAAS_BASE_URL      = defineSecret("ASAAS_BASE_URL");
const ASAAS_WEBHOOK_TOKEN = defineSecret("ASAAS_WEBHOOK_TOKEN");

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

    const { amount, source = "app" } = request.data;

    if (!amount || typeof amount !== "number" || amount <= 0) {
      throw new HttpsError(
        "invalid-argument",
        "amount deve ser um número positivo."
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

    const { amount, source = "reward" } = request.data;

    if (!amount || typeof amount !== "number" || amount <= 0) {
      throw new HttpsError(
        "invalid-argument",
        "amount deve ser um número positivo."
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

    const { amount, source = "purchase" } = request.data;

    if (!amount || typeof amount !== "number" || amount <= 0) {
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

    const { eloChange, won } = request.data;

    if (typeof eloChange !== "number") {
      throw new HttpsError("invalid-argument", "eloChange deve ser um número.");
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

    const { badgeId, source = "achievement" } = request.data;

    if (!badgeId || typeof badgeId !== "string") {
      throw new HttpsError("invalid-argument", "badgeId inválido.");
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

    const totalPrice = items.reduce((acc, i) => acc + i.price, 0);
    const totalPoints = items.reduce((acc, i) => acc + i.sparkPointsGranted, 0);

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
      items: items.map((i) => ({
        name: i.name,
        description: i.description,
        price: i.price,
        sparkPointsGranted: i.sparkPointsGranted,
        isSubscription: i.isSubscription ?? false,
      })),
      totalPrice,
      totalPoints,
      billingType,
      status: "PENDING",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const orderId = orderRef.id;

    const description =
      items.length === 1
        ? items[0].name
        : `${items.length} itens — Loja Spark`;

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
    secrets: [ASAAS_WEBHOOK_TOKEN],
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
    logger.info(`[asaasWebhook] Body bruto: ${JSON.stringify(rawBody).substring(0, 500)}`);

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

    // 3) Verifica token com lógica corrigida
    const expectedSecret = process.env.ASAAS_WEBHOOK_TOKEN ?? "";
    logger.info(`[asaasWebhook] Token recebido='${receivedToken.substring(0, 12)}...' esperado='${expectedSecret.substring(0, 12)}...' match=${receivedToken === expectedSecret}`);

    if (expectedSecret) {
      if (receivedToken !== expectedSecret) {
        logger.warn(`[asaasWebhook] Token inválido bloqueado. Esperava o secret configurado no Firebase.`);
        res.status(401).send("Unauthorized");
        return;
      }
    } else {
      logger.warn(`[asaasWebhook] AVISO: ASAAS_WEBHOOK_TOKEN não está configurado! Processando sem validação (Apenas para testes)`);
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
