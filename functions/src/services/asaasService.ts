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

import * as logger from "firebase-functions/logger";
import * as https from "https";
import * as http from "http";
import { URL } from "url";

// ── Configuração (será preenchida via Secret Manager / env) ──────
export function getAsaasConfig(): { apiKey: string; baseUrl: string } {
  const apiKey = process.env.ASAAS_API_KEY ?? "";
  const baseUrl =
    process.env.ASAAS_BASE_URL ?? "https://sandbox.asaas.com/api/v3";
  return { apiKey, baseUrl };
}

// ── Tipos da API Asaas ───────────────────────────────────────────

export type AsaasBillingType = "PIX" | "CREDIT_CARD" | "BOLETO" | "UNDEFINED";
export type AsaasChargeStatus =
  | "PENDING"
  | "RECEIVED"
  | "CONFIRMED"
  | "OVERDUE"
  | "REFUNDED"
  | "RECEIVED_IN_CASH"
  | "REFUND_REQUESTED"
  | "CHARGEBACK_REQUESTED"
  | "CHARGEBACK_DISPUTE"
  | "AWAITING_CHARGEBACK_REVERSAL"
  | "DUNNING_REQUESTED"
  | "DUNNING_RECEIVED"
  | "AWAITING_RISK_ANALYSIS";

export interface AsaasCustomer {
  id: string;
  name: string;
  cpfCnpj?: string;
  email?: string;
  phone?: string;
}

export interface AsaasCharge {
  id: string;
  customer: string;
  value: number;
  netValue: number;
  billingType: AsaasBillingType;
  status: AsaasChargeStatus;
  dueDate: string;
  description?: string;
  invoiceUrl?: string;
  bankSlipUrl?: string;
  pixQrCodeId?: string;
  externalReference?: string;
}

export interface AsaasPixQrCode {
  encodedImage: string; // base64 do QR Code
  payload: string; // código "copia e cola"
  expirationDate: string;
}

export interface CreateChargeOptions {
  customerId: string;
  value: number;
  description: string;
  billingType: AsaasBillingType;
  /** ID interno do pedido no Firestore — salvo em externalReference */
  orderId: string;
  dueDate?: string; // YYYY-MM-DD, padrão: hoje + 1 dia
}

export interface ChargeResult {
  chargeId: string;
  status: AsaasChargeStatus;
  billingType: AsaasBillingType;
  invoiceUrl: string | null;
  pixPayload: string | null;       // "copia e cola"
  pixQrCodeBase64: string | null;  // imagem base64
  pixExpirationDate: string | null;
  bankSlipUrl: string | null;
}

// ── HTTP Helper ──────────────────────────────────────────────────

function httpRequest(
  url: string,
  options: http.RequestOptions,
  body?: string
): Promise<{ status: number; data: unknown }> {
  return new Promise((resolve, reject) => {
    const parsedUrl = new URL(url);
    const isHttps = parsedUrl.protocol === "https:";
    const lib = isHttps ? https : http;

    const reqOptions: https.RequestOptions = {
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
        try {
          resolve({
            status: res.statusCode ?? 0,
            data: rawData ? JSON.parse(rawData) : null,
          });
        } catch {
          resolve({ status: res.statusCode ?? 0, data: rawData });
        }
      });
    });

    req.on("error", reject);
    if (body) req.write(body);
    req.end();
  });
}

function buildHeaders(apiKey: string): Record<string, string> {
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
export async function findOrCreateCustomer(
  name: string,
  email: string,
  cpfCnpj?: string
): Promise<string> {
  const { apiKey, baseUrl } = getAsaasConfig();
  const headers = buildHeaders(apiKey);

  // Tenta localizar por email
  const searchUrl = `${baseUrl}/customers?email=${encodeURIComponent(email)}&limit=1`;
  const searchRes = await httpRequest(searchUrl, { method: "GET", headers });

  if (searchRes.status === 200) {
    const body = searchRes.data as { data?: AsaasCustomer[] };
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
  const payload: Record<string, string> = { name, email };
  if (cpfCnpj) payload["cpfCnpj"] = cpfCnpj;

  const createRes = await httpRequest(
    `${baseUrl}/customers`,
    { method: "POST", headers },
    JSON.stringify(payload)
  );

  if (createRes.status >= 400) {
    logger.error("[Asaas] Erro ao criar cliente:", createRes.data);
    throw new Error(
      `Asaas createCustomer error ${createRes.status}: ${JSON.stringify(createRes.data)}`
    );
  }

  const created = createRes.data as AsaasCustomer;
  logger.info(`[Asaas] Cliente criado: ${created.id}`);
  return created.id;
}

export async function updateCustomer(
  customerId: string,
  cpfCnpj: string
): Promise<void> {
  const { apiKey, baseUrl } = getAsaasConfig();
  const headers = buildHeaders(apiKey);

  const res = await httpRequest(
    `${baseUrl}/customers/${customerId}`,
    { method: "PUT", headers },
    JSON.stringify({ cpfCnpj })
  );

  if (res.status >= 400) {
    logger.error(`[Asaas] Erro ao atualizar cliente ${customerId}:`, res.data);
    throw new Error(
      `Asaas updateCustomer error ${res.status}: ${JSON.stringify(res.data)}`
    );
  }
}

// ── Charge ───────────────────────────────────────────────────────

/**
 * Cria uma cobrança no Asaas e retorna os dados necessários para o app.
 */
export async function createCharge(
  opts: CreateChargeOptions
): Promise<ChargeResult> {
  const { apiKey, baseUrl } = getAsaasConfig();
  const headers = buildHeaders(apiKey);

  // Data de vencimento: hoje + 1 dia (mínimo exigido pelo Asaas)
  const dueDate =
    opts.dueDate ??
    (() => {
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

  const res = await httpRequest(
    `${baseUrl}/payments`,
    { method: "POST", headers },
    JSON.stringify(payload)
  );

  if (res.status >= 400) {
    logger.error("[Asaas] Erro ao criar cobrança:", res.data);
    throw new Error(
      `Asaas createCharge error ${res.status}: ${JSON.stringify(res.data)}`
    );
  }

  const charge = res.data as AsaasCharge;
  // O Asaas Sandbox retorna billingType="UNDEFINED" para cartão de crédito
  // até o pagamento ser finalizado — normalizamos para CREDIT_CARD
  if (charge.billingType === "UNDEFINED" && opts.billingType === "CREDIT_CARD") {
    charge.billingType = "CREDIT_CARD";
  }
  logger.info(`[Asaas] Cobrança criada: ${charge.id} status=${charge.status} billingType=${charge.billingType}`);

  let pixPayload: string | null = null;
  let pixQrCodeBase64: string | null = null;
  let pixExpirationDate: string | null = null;

  // Para PIX, busca o QR Code
  if (opts.billingType === "PIX") {
    const pixRes = await httpRequest(
      `${baseUrl}/payments/${charge.id}/pixQrCode`,
      { method: "GET", headers }
    );
    if (pixRes.status === 200) {
      const pix = pixRes.data as AsaasPixQrCode;
      pixPayload = pix.payload;
      pixQrCodeBase64 = pix.encodedImage;
      pixExpirationDate = pix.expirationDate;
    } else {
      logger.warn("[Asaas] Não foi possível obter QR Code PIX:", pixRes.data);
    }
  }

  return {
    chargeId: charge.id,
    status: charge.status,
    billingType: charge.billingType,
    invoiceUrl: charge.invoiceUrl ?? null,
    pixPayload,
    pixQrCodeBase64,
    pixExpirationDate,
    bankSlipUrl: charge.bankSlipUrl ?? null,
  };
}

// ── Webhook Signature ────────────────────────────────────────────

/**
 * Verifica o token de autenticidade do webhook do Asaas.
 * O Asaas envia o header "asaas-access-token" com o valor configurado
 * no painel → Configurações → Webhook.
 */
export function verifyWebhookToken(token: string): boolean {
  const secret = process.env.ASAAS_WEBHOOK_TOKEN ?? "";
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
export async function getChargeStatus(chargeId: string): Promise<string> {
  const { apiKey, baseUrl } = getAsaasConfig();
  const headers = buildHeaders(apiKey);

  const res = await httpRequest(
    `${baseUrl}/payments/${chargeId}`,
    { method: "GET", headers }
  );

  if (res.status >= 400) {
    logger.error(`[Asaas] Erro ao consultar cobrança ${chargeId}:`, res.data);
    return "UNKNOWN";
  }

  const charge = res.data as { status?: string };
  return charge.status ?? "UNKNOWN";
}
