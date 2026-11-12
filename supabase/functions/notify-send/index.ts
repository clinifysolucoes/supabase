// Edge Function notify-send: envia a fila de alertas por e-mail (Resend) e
// SMS (Zenvia).
//
// Chamada por um agendador (Supabase Integrations > Cron, HTTP request a cada
// 10-15 minutos) com o header x-cron-secret = CRON_SECRET; deploy com
// verify_jwt = false. Para cada lote:
//   1. ad.notify_dispatch CLAIM (service_role): enfileira o devido e pega ate
//      50 mensagens com o remetente de cada filial
//   2. troca {{link}} pelo link de confirmacao do lembrete
//      (APP_PUBLIC_URL/confirmar/<token>; sem APP_PUBLIC_URL o trecho sai)
//   3. envia pelo Resend (e-mail) ou pela Zenvia (SMS)
//   4. ad.notify_dispatch RESULT com o id do provedor ou o erro
// Canal sem a chave configurada vira erro na mensagem ("nao configurado").
// Saida 200: { qt_sent, qt_failed, qt_enqueued }
//
// Secrets: CRON_SECRET (o mesmo do WhatsApp), RESEND_API_KEY, RESEND_FROM
// (endereco do dominio verificado no Resend, ex.: alertas@clinify.com.br),
// ZENVIA_API_TOKEN, ZENVIA_FROM (remetente/palavra-chave da conta Zenvia),
// APP_PUBLIC_URL (opcional, ex.: https://app.clinify.com.br).

import { createClient } from "npm:@supabase/supabase-js@2";

type Msg = {
  nr_company: number;
  nr_branch: number;
  nr_message: number;
  it_channel: number;
  it_kind: number;
  vc_to: string;
  vc_subject: string | null;
  tx_body: string;
  uu_token: string | null;
  vc_from_name: string;
  vc_reply_to: string | null;
};

type Sent = { id?: string; error?: string };

const env = (k: string) => (Deno.env.get(k) ?? "").trim();

/** Troca {{link}}; sem URL publica, tira o "Confirme: {{link}}". */
export function withLink(text: string, token: string | null, base: string): string {
  if (token && base) return text.replaceAll("{{link}}", `${base.replace(/\/+$/, "")}/confirmar/${token}`);
  return text
    .replace(/\s*Confirm\w*\s*:?\s*\{\{link\}\}\.?/gi, "")
    .replaceAll("{{link}}", "")
    .replace(/[ \t]{2,}/g, " ")
    .trim();
}

const esc = (s: string) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

/** Texto simples -> HTML com quebras de linha e links clicaveis. */
export function toHtml(text: string): string {
  const body = esc(text)
    .replace(/(https?:\/\/[^\s<]+)/g, '<a href="$1">$1</a>')
    .replace(/\n/g, "<br>");
  return `<div style="font-family:Arial,sans-serif;font-size:15px;line-height:1.5;color:#0F2A33">${body}</div>`;
}

async function sendEmail(m: Msg, text: string): Promise<Sent> {
  const key = env("RESEND_API_KEY");
  const from = env("RESEND_FROM");
  if (!key || !from) return { error: "E-mail não configurado (RESEND_API_KEY/RESEND_FROM)" };
  const name = (m.vc_from_name || "Clínica").replace(/[<>"]/g, "").slice(0, 80);
  const r = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      from: `${name} <${from}>`,
      to: [m.vc_to],
      subject: m.vc_subject || name,
      text,
      html: toHtml(text),
      ...(m.vc_reply_to ? { reply_to: m.vc_reply_to } : {}),
    }),
  });
  const out = await r.json().catch(() => ({}));
  return r.ok && out?.id ? { id: String(out.id) } : { error: out?.message ?? `Resend HTTP ${r.status}` };
}

async function sendSms(m: Msg, text: string): Promise<Sent> {
  const token = env("ZENVIA_API_TOKEN");
  const from = env("ZENVIA_FROM");
  if (!token || !from) return { error: "SMS não configurado (ZENVIA_API_TOKEN/ZENVIA_FROM)" };
  const r = await fetch("https://api.zenvia.com/v2/channels/sms/messages", {
    method: "POST",
    headers: { "X-API-TOKEN": token, "Content-Type": "application/json" },
    body: JSON.stringify({ from, to: m.vc_to, contents: [{ type: "text", text: text.slice(0, 1000) }] }),
  });
  const out = await r.json().catch(() => ({}));
  return r.ok && out?.id ? { id: String(out.id) } : { error: out?.message ?? `Zenvia HTTP ${r.status}` };
}

Deno.serve(async (req: Request) => {
  const secret = env("CRON_SECRET");
  if (!secret || req.headers.get("x-cron-secret") !== secret) {
    return new Response(JSON.stringify({ Message: "NOTIFY_UNAUTHORIZED" }), { status: 401 });
  }
  const admin = createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"), {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const base = env("APP_PUBLIC_URL");

  let sent = 0, failed = 0, enqueued = 0;
  for (let round = 0; round < 4; round++) {
    const claim = await admin.schema("ad").rpc("notify_dispatch", {
      p_json: { nr_version: 1, vc_action: "CLAIM", qt_limit: 50 },
    });
    if (claim.error) {
      return new Response(JSON.stringify({ Message: "NOTIFY_BACKEND_ERROR", Detail: claim.error.message }), {
        status: 500,
      });
    }
    enqueued += Number(claim.data?.qt_enqueued ?? 0);
    const msgs = (claim.data?.messages ?? []) as Msg[];
    if (msgs.length === 0) break;
    const results: Record<string, unknown>[] = [];
    for (const m of msgs) {
      const ref = { nr_company: m.nr_company, nr_branch: m.nr_branch, nr_message: m.nr_message };
      try {
        const text = withLink(m.tx_body, m.uu_token, base);
        const r = m.it_channel === 1 ? await sendEmail(m, text) : await sendSms(m, text);
        if (r.id) {
          results.push({ ...ref, vc_provider_id: r.id });
          sent++;
        } else {
          results.push({ ...ref, vc_error: String(r.error).slice(0, 400) });
          failed++;
        }
      } catch (e) {
        results.push({ ...ref, vc_error: String(e).slice(0, 400) });
        failed++;
      }
    }
    await admin.schema("ad").rpc("notify_dispatch", {
      p_json: { nr_version: 1, vc_action: "RESULT", results },
    });
    if (msgs.length < 50) break;
  }
  return new Response(JSON.stringify({ qt_sent: sent, qt_failed: failed, qt_enqueued: enqueued }), {
    headers: { "Content-Type": "application/json" },
  });
});
