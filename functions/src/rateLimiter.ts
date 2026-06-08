/**
 * rateLimiter.ts — Rate Limiting via Firestore (Sliding Window)
 *
 * Armazena timestamps de cada requisição em documentos Firestore.
 * Ao verificar, remove automaticamente os timestamps fora da janela
 * e rejeita a chamada se o limite for excedido.
 *
 * Coleção: rate_limits
 * Documento ID: {group}:{uid}:{functionName}
 * Estrutura:  { hits: number[] }  — array de timestamps em ms (epoch)
 */

import { getFirestore, Firestore, FieldValue } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";

// Lazy getter — evita chamar getFirestore() antes do initializeApp() do index.ts
let _db: Firestore | null = null;
function getDb(): Firestore {
  if (!_db) _db = getFirestore("default");
  return _db;
}

/**
 * Verifica e registra uma tentativa de rate limiting.
 *
 * @param key        Chave única: ex. "auth:uid123:sendEmailVerificationCode"
 * @param limit      Número máximo de chamadas permitidas na janela
 * @param windowMs   Duração da janela em milissegundos (ex.: 15 * 60 * 1000)
 *
 * @throws HttpsError("resource-exhausted") se o limite for atingido.
 */
export async function checkRateLimit(
  key: string,
  limit: number,
  windowMs: number
): Promise<void> {
  const ref = getDb().collection("rate_limits").doc(key);
  const now = Date.now();
  const windowStart = now - windowMs;

  await getDb().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const hits: number[] = snap.exists
      ? ((snap.data()?.["hits"] as number[]) ?? [])
      : [];

    // Remove timestamps fora da janela (self-cleaning)
    const recentHits = hits.filter((ts) => ts > windowStart);

    if (recentHits.length >= limit) {
      const oldestHit = Math.min(...recentHits);
      const resetInMs = oldestHit + windowMs - now;
      const resetInSec = Math.ceil(resetInMs / 1000);

      logger.warn(
        `[rateLimiter] Limite atingido: key=${key} hits=${recentHits.length}/${limit} resetIn=${resetInSec}s`
      );

      throw new HttpsError(
        "resource-exhausted",
        `Muitas tentativas. Aguarde ${resetInSec} segundo(s) antes de tentar novamente.`
      );
    }

    // Adiciona o timestamp atual
    recentHits.push(now);

    tx.set(ref, { hits: recentHits, updatedAt: FieldValue.serverTimestamp() });
  });
}

// ── Constantes de configuração ────────────────────────────────────

/** Rotas de autenticação: máx. 5 tentativas / 15 minutos. */
export const RATE_AUTH = { limit: 5, windowMs: 15 * 60 * 1000 } as const;

/** Funções de gamificação: máx. 20 chamadas / 1 minuto. */
export const RATE_GAMIFICATION = { limit: 20, windowMs: 60 * 1000 } as const;

/** Funções de pagamento: máx. 10 chamadas / 1 minuto. */
export const RATE_PAYMENT = { limit: 10, windowMs: 60 * 1000 } as const;

/** Funções administrativas: máx. 10 chamadas / 5 minutos. */
export const RATE_ADMIN = { limit: 10, windowMs: 5 * 60 * 1000 } as const;

/**
 * Constrói a chave de rate limiting para funções autenticadas (por uid).
 *
 * @param group    Grupo de rate limit (auth, gamification, payment, admin)
 * @param uid      UID do usuário autenticado
 * @param fnName   Nome da função Cloud
 */
export function rateLimitKey(
  group: "auth" | "gamification" | "payment" | "admin",
  uid: string,
  fnName: string
): string {
  return `${group}:${uid}:${fnName}`;
}
