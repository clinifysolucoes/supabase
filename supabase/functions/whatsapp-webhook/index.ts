// Edge Function whatsapp-webhook: retorno da Meta (WhatsApp Cloud API).
//
// Configurar no app da Meta (WhatsApp > Configuracao > Webhook):
//   URL de retorno: https://<projeto>.supabase.co/functions/v1/whatsapp-webhook
//   Token de verificacao: o valor do secret WHATSAPP_VERIFY_TOKEN
//   Campo assinado: messages
// Deploy com verify_jwt = false (a Meta nao manda JWT).
//
//   GET  verificacao do endereco (hub.challenge)
//   POST confere a assinatura X-Hub-Signature-256 (HMAC do corpo com
//        WHATSAPP_APP_SECRET) e repassa para ad.whatsapp_dispatch WEBHOOK:
//        situacoes (enviada, entregue, lida, falhou) e respostas dos botoes
//        Confirmar / Remarcar do lembrete
//
// Secrets: WHATSAPP_VERIFY_TOKEN, WHATSAPP_APP_SECRET.

import { createClient } from "npm:@supabase/supabase-js@2";

function hex(buf: ArrayBuffer): string {
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let r = 0;
  for (let i = 0; i < a.length; i++) r |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return r === 0;
}

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  if (req.method === "GET") {
    const ok = url.searchParams.get("hub.mode") === "subscribe" &&
      url.searchParams.get("hub.verify_token") === (Deno.env.get("WHATSAPP_VERIFY_TOKEN") ?? "\u0000");
    return ok ? new Response(url.searchParams.get("hub.challenge") ?? "") : new Response("forbidden", { status: 403 });
  }
  if (req.method !== "POST") return new Response("method", { status: 405 });

  const raw = await req.text();
  const appSecret = Deno.env.get("WHATSAPP_APP_SECRET") ?? "";
  const signature = req.headers.get("x-hub-signature-256") ?? "";
  if (!appSecret) return new Response("not configured", { status: 500 });
  const k = await crypto.subtle.importKey("raw", new TextEncoder().encode(appSecret), { name: "HMAC", hash: "SHA-256" },
    false, ["sign"]);
  const expected = "sha256=" + hex(await crypto.subtle.sign("HMAC", k, new TextEncoder().encode(raw)));
  if (!safeEqual(signature, expected)) return new Response("signature", { status: 401 });

  let body: any;
  try {
    body = JSON.parse(raw);
  } catch (_) {
    return new Response("ok");
  }
  const statuses: unknown[] = [];
  const replies: unknown[] = [];
  for (const entry of body?.entry ?? []) {
    for (const change of entry?.changes ?? []) {
      const v = change?.value ?? {};
      for (const s of v.statuses ?? []) {
        statuses.push({
          vc_wa_id: String(s.id ?? ""),
          vc_status: String(s.status ?? ""),
          vc_error: s.errors?.[0]?.title ?? s.errors?.[0]?.message ?? null,
        });
      }
      for (const m of v.messages ?? []) {
        const context = m?.context?.id;
        const payload = m?.type === "button"
          ? m?.button?.payload
          : m?.type === "interactive"
          ? m?.interactive?.button_reply?.id
          : null;
        if (context && (payload === "CONFIRM" || payload === "RESCHEDULE")) {
          replies.push({ vc_wa_id: String(context), vc_payload: payload });
        }
      }
    }
  }
  if (statuses.length || replies.length) {
    const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    await admin.schema("ad").rpc("whatsapp_dispatch", {
      p_json: { nr_version: 1, vc_action: "WEBHOOK", statuses, replies },
    });
  }
  // a Meta reenvia se nao receber 200
  return new Response("ok");
});
