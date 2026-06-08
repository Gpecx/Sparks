"use strict";
/**
 * SPARK — Asaas Payment Service
 *
 * Abstrai toda a comunicação com a API REST do Asaas.
 * Suporta PIX, Cartão de Crédito e Boleto.
 *
 * Variáveis de ambiente requeridas (configurar via firebase functions:config:set
 * ou Secret Manager em produção):
 *   ASAAS_API_KEY   — chave de produção ou sandbox do Asaas
 *   ASAAS_BASE_URL  — https://sandbox.asaas.com/api/v3 (teste)
 *                     https://api.asaas.com/v3          (produção)
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.getAsaasConfig = getAsaasConfig;
exports.findOrCreateCustomer = findOrCreateCustomer;
exports.updateCustomer = updateCustomer;
exports.createCharge = createCharge;
exports.verifyWebhookToken = verifyWebhookToken;
exports.getChargeStatus = getChargeStatus;
const logger = require("firebase-functions/logger");
const https = require("https");
const http = require("http");
const url_1 = require("url");
// ── Configuração (será preenchida via Secret Manager / env) ──────
function getAsaasConfig() {
    var _a, _b;
    const apiKey = (_a = process.env.ASAAS_API_KEY) !== null && _a !== void 0 ? _a : "";
    const baseUrl = (_b = process.env.ASAAS_BASE_URL) !== null && _b !== void 0 ? _b : "https://sandbox.asaas.com/api/v3";
    return { apiKey, baseUrl };
}
// ── HTTP Helper ──────────────────────────────────────────────────
function httpRequest(url, options, body) {
    return new Promise((resolve, reject) => {
        const parsedUrl = new url_1.URL(url);
        const isHttps = parsedUrl.protocol === "https:";
        const lib = isHttps ? https : http;
        const reqOptions = {
            hostname: parsedUrl.hostname,
            port: parsedUrl.port || (isHttps ? 443 : 80),
            path: parsedUrl.pathname + parsedUrl.search,
            method: options.method || "GET",
            headers: options.headers,
        };
        const req = lib.request(reqOptions, (res) => {
            let rawData = "";
            res.on("data", (chunk) => (rawData += chunk));
            res.on("end", () => {
                var _a, _b;
                try {
                    resolve({
                        status: (_a = res.statusCode) !== null && _a !== void 0 ? _a : 0,
                        data: rawData ? JSON.parse(rawData) : null,
                    });
                }
                catch (_c) {
                    resolve({ status: (_b = res.statusCode) !== null && _b !== void 0 ? _b : 0, data: rawData });
                }
            });
        });
        req.on("error", reject);
        if (body)
            req.write(body);
        req.end();
    });
}
function buildHeaders(apiKey) {
    return {
        accept: "application/json",
        "content-type": "application/json",
        access_token: apiKey,
        "User-Agent": "Spark-App/1.0",
    };
}
// ── Customer ─────────────────────────────────────────────────────
/**
 * Busca clientes pelo CPF/email ou cria um novo.
 * Retorna sempre o asaasCustomerId.
 */
async function findOrCreateCustomer(name, email, cpfCnpj) {
    const { apiKey, baseUrl } = getAsaasConfig();
    const headers = buildHeaders(apiKey);
    // Tenta localizar por email
    const searchUrl = `${baseUrl}/customers?email=${encodeURIComponent(email)}&limit=1`;
    const searchRes = await httpRequest(searchUrl, { method: "GET", headers });
    if (searchRes.status === 200) {
        const body = searchRes.data;
        if (body.data && body.data.length > 0) {
            const existing = body.data[0];
            logger.info(`[Asaas] Cliente existente encontrado: ${existing.id}`);
            // Se informamos o CPF agora, e o cliente Asaas ainda não o tem, atualizamos o cadastro dele.
            if (cpfCnpj && !existing.cpfCnpj) {
                logger.info(`[Asaas] Atualizando cliente ${existing.id} com novo CPF/CNPJ: ${cpfCnpj}`);
                await updateCustomer(existing.id, cpfCnpj);
            }
            return existing.id;
        }
    }
    // Cria novo cliente
    const payload = { name, email };
    if (cpfCnpj)
        payload["cpfCnpj"] = cpfCnpj;
    const createRes = await httpRequest(`${baseUrl}/customers`, { method: "POST", headers }, JSON.stringify(payload));
    if (createRes.status >= 400) {
        logger.error("[Asaas] Erro ao criar cliente:", createRes.data);
        throw new Error(`Asaas createCustomer error ${createRes.status}: ${JSON.stringify(createRes.data)}`);
    }
    const created = createRes.data;
    logger.info(`[Asaas] Cliente criado: ${created.id}`);
    return created.id;
}
async function updateCustomer(customerId, cpfCnpj) {
    const { apiKey, baseUrl } = getAsaasConfig();
    const headers = buildHeaders(apiKey);
    const res = await httpRequest(`${baseUrl}/customers/${customerId}`, { method: "PUT", headers }, JSON.stringify({ cpfCnpj }));
    if (res.status >= 400) {
        logger.error(`[Asaas] Erro ao atualizar cliente ${customerId}:`, res.data);
        throw new Error(`Asaas updateCustomer error ${res.status}: ${JSON.stringify(res.data)}`);
    }
}
// ── Charge ───────────────────────────────────────────────────────
/**
 * Cria uma cobrança no Asaas e retorna os dados necessários para o app.
 */
async function createCharge(opts) {
    var _a, _b, _c;
    const { apiKey, baseUrl } = getAsaasConfig();
    const headers = buildHeaders(apiKey);
    // Data de vencimento: hoje + 1 dia (mínimo exigido pelo Asaas)
    const dueDate = (_a = opts.dueDate) !== null && _a !== void 0 ? _a : (() => {
        const d = new Date();
        d.setDate(d.getDate() + 1);
        return d.toISOString().split("T")[0];
    })();
    const payload = {
        customer: opts.customerId,
        billingType: opts.billingType,
        value: opts.value,
        dueDate,
        description: opts.description,
        externalReference: opts.orderId,
    };
    const res = await httpRequest(`${baseUrl}/payments`, { method: "POST", headers }, JSON.stringify(payload));
    if (res.status >= 400) {
        logger.error("[Asaas] Erro ao criar cobrança:", res.data);
        throw new Error(`Asaas createCharge error ${res.status}: ${JSON.stringify(res.data)}`);
    }
    const charge = res.data;
    // O Asaas Sandbox retorna billingType="UNDEFINED" para cartão de crédito
    // até o pagamento ser finalizado — normalizamos para CREDIT_CARD
    if (charge.billingType === "UNDEFINED" && opts.billingType === "CREDIT_CARD") {
        charge.billingType = "CREDIT_CARD";
    }
    logger.info(`[Asaas] Cobrança criada: ${charge.id} status=${charge.status} billingType=${charge.billingType}`);
    let pixPayload = null;
    let pixQrCodeBase64 = null;
    let pixExpirationDate = null;
    // Para PIX, busca o QR Code
    if (opts.billingType === "PIX") {
        const pixRes = await httpRequest(`${baseUrl}/payments/${charge.id}/pixQrCode`, { method: "GET", headers });
        if (pixRes.status === 200) {
            const pix = pixRes.data;
            pixPayload = pix.payload;
            pixQrCodeBase64 = pix.encodedImage;
            pixExpirationDate = pix.expirationDate;
        }
        else {
            logger.warn("[Asaas] Não foi possível obter QR Code PIX:", pixRes.data);
        }
    }
    return {
        chargeId: charge.id,
        status: charge.status,
        billingType: charge.billingType,
        invoiceUrl: (_b = charge.invoiceUrl) !== null && _b !== void 0 ? _b : null,
        pixPayload,
        pixQrCodeBase64,
        pixExpirationDate,
        bankSlipUrl: (_c = charge.bankSlipUrl) !== null && _c !== void 0 ? _c : null,
    };
}
// ── Webhook Signature ────────────────────────────────────────────
/**
 * Verifica o token de autenticidade do webhook do Asaas.
 * O Asaas envia o header "asaas-access-token" com o valor configurado
 * no painel → Configurações → Webhook.
 */
function verifyWebhookToken(token) {
    var _a;
    const secret = (_a = process.env.ASAAS_WEBHOOK_TOKEN) !== null && _a !== void 0 ? _a : "";
    if (!secret) {
        // Falha FECHADA: sem secret configurado, nada é aceito.
        logger.error("[Asaas] ASAAS_WEBHOOK_TOKEN não configurado — rejeitando webhook.");
        return false;
    }
    return token === secret;
}
// ── Get Charge Status ────────────────────────────────────────────
/**
 * Consulta o status atual de uma cobrança no Asaas.
 * Usado pelo checkPaymentStatus para polling ativo (fallback ao webhook).
 */
async function getChargeStatus(chargeId) {
    var _a;
    const { apiKey, baseUrl } = getAsaasConfig();
    const headers = buildHeaders(apiKey);
    const res = await httpRequest(`${baseUrl}/payments/${chargeId}`, { method: "GET", headers });
    if (res.status >= 400) {
        logger.error(`[Asaas] Erro ao consultar cobrança ${chargeId}:`, res.data);
        return "UNKNOWN";
    }
    const charge = res.data;
    return (_a = charge.status) !== null && _a !== void 0 ? _a : "UNKNOWN";
}
//# sourceMappingURL=asaasService.js.map