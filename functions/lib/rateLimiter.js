"use strict";
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
Object.defineProperty(exports, "__esModule", { value: true });
exports.RATE_ADMIN = exports.RATE_PAYMENT = exports.RATE_GAMIFICATION = exports.RATE_AUTH = void 0;
exports.checkRateLimit = checkRateLimit;
exports.rateLimitKey = rateLimitKey;
const firestore_1 = require("firebase-admin/firestore");
const https_1 = require("firebase-functions/v2/https");
const v2_1 = require("firebase-functions/v2");
// Lazy getter — evita chamar getFirestore() antes do initializeApp() do index.ts
let _db = null;
function getDb() {
    if (!_db)
        _db = (0, firestore_1.getFirestore)("default");
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
async function checkRateLimit(key, limit, windowMs) {
    const ref = getDb().collection("rate_limits").doc(key);
    const now = Date.now();
    const windowStart = now - windowMs;
    await getDb().runTransaction(async (tx) => {
        var _a, _b;
        const snap = await tx.get(ref);
        const hits = snap.exists
            ? ((_b = (_a = snap.data()) === null || _a === void 0 ? void 0 : _a["hits"]) !== null && _b !== void 0 ? _b : [])
            : [];
        // Remove timestamps fora da janela (self-cleaning)
        const recentHits = hits.filter((ts) => ts > windowStart);
        if (recentHits.length >= limit) {
            const oldestHit = Math.min(...recentHits);
            const resetInMs = oldestHit + windowMs - now;
            const resetInSec = Math.ceil(resetInMs / 1000);
            v2_1.logger.warn(`[rateLimiter] Limite atingido: key=${key} hits=${recentHits.length}/${limit} resetIn=${resetInSec}s`);
            throw new https_1.HttpsError("resource-exhausted", `Muitas tentativas. Aguarde ${resetInSec} segundo(s) antes de tentar novamente.`);
        }
        // Adiciona o timestamp atual
        recentHits.push(now);
        tx.set(ref, { hits: recentHits, updatedAt: firestore_1.FieldValue.serverTimestamp() });
    });
}
// ── Constantes de configuração ────────────────────────────────────
/** Rotas de autenticação: máx. 5 tentativas / 15 minutos. */
exports.RATE_AUTH = { limit: 5, windowMs: 15 * 60 * 1000 };
/** Funções de gamificação: máx. 20 chamadas / 1 minuto. */
exports.RATE_GAMIFICATION = { limit: 20, windowMs: 60 * 1000 };
/** Funções de pagamento: máx. 10 chamadas / 1 minuto. */
exports.RATE_PAYMENT = { limit: 10, windowMs: 60 * 1000 };
/** Funções administrativas: máx. 10 chamadas / 5 minutos. */
exports.RATE_ADMIN = { limit: 10, windowMs: 5 * 60 * 1000 };
/**
 * Constrói a chave de rate limiting para funções autenticadas (por uid).
 *
 * @param group    Grupo de rate limit (auth, gamification, payment, admin)
 * @param uid      UID do usuário autenticado
 * @param fnName   Nome da função Cloud
 */
function rateLimitKey(group, uid, fnName) {
    return `${group}:${uid}:${fnName}`;
}
//# sourceMappingURL=rateLimiter.js.map