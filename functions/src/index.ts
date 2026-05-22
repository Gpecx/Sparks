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
import {
  onCall,
  CallableRequest,
  HttpsError,
} from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";

// ── Firebase Admin init ──────────────────────────────────────────
admin.initializeApp();
const db = admin.firestore();

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
  { region: "southamerica-east1" },
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
// 2. spendSparkPoints — Debita Spark Points com verificação de saldo
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
  { region: "southamerica-east1" },
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
  { region: "southamerica-east1" },
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
  { region: "southamerica-east1" },
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
