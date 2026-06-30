import * as crypto from "crypto";
import { defineSecret } from "firebase-functions/params";
import { logger } from "firebase-functions/v2";

// ────────────────────────────────────────────────────────────────────────────
//  Meta Conversions API (CAPI)
//  Envio server-side de eventos de conversão para a Meta (Pixel 1322720386475594).
//  Governança: 10Dobro. O token é um secret (META_CAPI_TOKEN).
//
//  Esta função é ADITIVA e à prova de falha: NUNCA lança. Qualquer erro é logado
//  e engolido para jamais afetar o fluxo que a chamou (ex.: webhook de pagamento).
// ────────────────────────────────────────────────────────────────────────────

/// Secret com o token da Conversions API (fornecido pela 10Dobro).
/// - Funções v2: adicione `META_CAPI_TOKEN` ao array `secrets` e passe
///   `META_CAPI_TOKEN.value()` para `sendCapiEvent`.
/// - Funções v1: use `runWith({ secrets: ["META_CAPI_TOKEN"] })` e passe
///   `process.env.META_CAPI_TOKEN ?? ""`.
export const META_CAPI_TOKEN = defineSecret("META_CAPI_TOKEN");

const PIXEL_ID = "1322720386475594";
const GRAPH_VERSION = "v21.0";

function sha256(value?: string | null): string | undefined {
  if (!value) return undefined;
  return crypto.createHash("sha256").update(value.trim().toLowerCase()).digest("hex");
}

export interface CapiEventOptions {
  email?: string | null;
  phone?: string | null;
  uid?: string | null; // vira external_id (hasheado)
  value?: number;
  currency?: string; // default BRL
  eventId?: string; // dedup com o Pixel (ex.: orderId)
  actionSource?: "website" | "app" | "system_generated";
  eventSourceUrl?: string;
  clientIp?: string;
  userAgent?: string;
  fbp?: string;
  fbc?: string;
}

/// Envia um evento para a Meta Conversions API. NUNCA lança.
export async function sendCapiEvent(
  token: string,
  eventName: string,
  opts: CapiEventOptions = {}
): Promise<void> {
  try {
    if (!token) {
      logger.warn(`[capi] ${eventName} ignorado: META_CAPI_TOKEN ausente.`);
      return;
    }

    const userData: Record<string, unknown> = {};
    const em = sha256(opts.email);
    if (em) userData.em = [em];
    const ph = sha256(opts.phone);
    if (ph) userData.ph = [ph];
    const ext = sha256(opts.uid);
    if (ext) userData.external_id = [ext];
    if (opts.clientIp) userData.client_ip_address = opts.clientIp;
    if (opts.userAgent) userData.client_user_agent = opts.userAgent;
    if (opts.fbp) userData.fbp = opts.fbp;
    if (opts.fbc) userData.fbc = opts.fbc;

    const event: Record<string, unknown> = {
      event_name: eventName,
      event_time: Math.floor(Date.now() / 1000),
      action_source: opts.actionSource ?? "website",
      user_data: userData,
    };
    if (opts.eventId) event.event_id = opts.eventId;
    if (opts.eventSourceUrl) event.event_source_url = opts.eventSourceUrl;
    if (typeof opts.value === "number") {
      event.custom_data = { currency: opts.currency ?? "BRL", value: opts.value };
    }

    const url =
      `https://graph.facebook.com/${GRAPH_VERSION}/${PIXEL_ID}/events` +
      `?access_token=${encodeURIComponent(token)}`;

    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ data: [event] }),
    });

    if (!res.ok) {
      const body = await res.text().catch(() => "");
      logger.error(`[capi] ${eventName} falhou: ${res.status} ${body}`);
    } else {
      logger.info(`[capi] ${eventName} enviado.`);
    }
  } catch (e) {
    logger.error(`[capi] erro ao enviar ${eventName}:`, e);
  }
}
