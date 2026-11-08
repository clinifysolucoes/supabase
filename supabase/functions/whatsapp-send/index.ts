// Edge Function whatsapp-send: envia a fila de alertas por WhatsApp.
//
// Chamada pelo agendador (workflow .github/workflows/whatsapp-cron.yml a cada
// 10 minutos) com o header x-cron-secret = CRON_SECRET; deploy com
// verify_jwt = false. Para cada lote:
//   1. ad.whatsapp_dispatch CLAIM (service_role): enfileira o devido e pega ate
//      50 mensagens com o numero, a chave cifrada e o idioma de cada filial
//   2. decifra a chave (WHATSAPP_ENC_KEY) e envia o modelo pela Cloud API; o
//      lembrete leva os botoes Confirmar (CONFIRM) e Remarcar (RESCHEDULE)
//   3. ad.whatsapp_dispatch RESULT com o id da Meta ou o erro
// Saida 200: { qt_sent, qt_failed, qt_enqueued }
//
// Secrets: WHATSAPP_ENC_KEY, CRON_SECRET.

import { createClient } from "npm:@supabase/supabase-js@2";

const GRAPH = "https://graph.facebook.com/v21.0";

type Msg = {
  nr_company: number;
  nr_branch: number;
  nr_message: number;
  it_kind: number;
  vc_to: string;
  vc_template: string;
  js_params: string[];
  vc_phone_number_id: string;
  vc_language: string;
  vc_token_enc: string;
};

const unb64 = (s: string) => Uint8Array.from(atob(s), (c) => c.charCodeAt(0));

async function decrypt(enc: string, key: CryptoKey): Promise<string> {
  const [v, iv, data] = enc.split(":");
  if (v !== "v1") throw new Error("version");
  const plain = await crypto.subtle.decrypt({ name: "AES-GCM", iv: unb64(iv) }, key, unb64(data));
  return new TextDecoder().decode(plain);
}

function payload(m: Msg) {
  const components: unknown[] = [{
    type: "body",
    parameters: (m.js_params ?? []).map((p) => ({ type: "text", text: String(p || "-").slice(0, 1000) })),
  }];
  if (m.it_kind === 1) {
    components.push(
      { type: "button", sub_type: "quick_reply", index: "0", parameters: [{ type: "payload", payload: "CONFIRM" }] },
      { type: "button", sub_type: "quick_reply", index: "1", parameters: [{ type: "payload", payload: "RESCHEDULE" }] },
    );
  }
  return {
    messaging_product: "whatsapp",
    to: m.vc_to,
    type: "template",
    template: { name: m.vc_template, language: { code: m.vc_language }, components },
  };
}

Deno.serve(async (req: Request) => {
  const secret = Deno.env.get("CRON_SECRET") ?? "";
  if (!secret || req.headers.get("x-cron-secret") !== secret) {
    return new Response(JSON.stringify({ Message: "WHATSAPP_UNAUTHORIZED" }), { status: 401 });
  }
  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  let key: CryptoKey;
  try {
    const raw = unb64(Deno.env.get("WHATSAPP_ENC_KEY") ?? "");
    if (raw.length !== 32) throw new Error("key");
    key = await crypto.subtle.importKey("raw", raw, "AES-GCM", false, ["decrypt"]);
  } catch (_) {
    return new Response(JSON.stringify({ Message: "WHATSAPP_ENCRYPTION_UNAVAILABLE" }), { status: 500 });
  }

  let sent = 0, failed = 0, enqueued = 0;
  const tokens = new Map<string, string>();
  for (let round = 0; round < 4; round++) {
    const claim = await admin.schema("ad").rpc("whatsapp_dispatch", {
      p_json: { nr_version: 1, vc_action: "CLAIM", qt_limit: 50 },
    });
    if (claim.error) {
      return new Response(JSON.stringify({ Message: "WHATSAPP_BACKEND_ERROR", Detail: claim.error.message }), {
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
        const cacheKey = `${m.nr_company}/${m.nr_branch}`;
        let token = tokens.get(cacheKey);
        if (!token) {
          token = await decrypt(m.vc_token_enc, key);
          tokens.set(cacheKey, token);
        }
        const r = await fetch(`${GRAPH}/${m.vc_phone_number_id}/messages`, {
          method: "POST",
          headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
          body: JSON.stringify(payload(m)),
        });
        const out = await r.json().catch(() => ({}));
        const id = out?.messages?.[0]?.id;
        if (r.ok && id) {
          results.push({ ...ref, vc_wa_id: id });
          sent++;
        } else {
          results.push({ ...ref, vc_error: out?.error?.message ?? `HTTP ${r.status}` });
          failed++;
        }
      } catch (e) {
        results.push({ ...ref, vc_error: String(e).slice(0, 400) });
        failed++;
      }
    }
    await admin.schema("ad").rpc("whatsapp_dispatch", {
      p_json: { nr_version: 1, vc_action: "RESULT", results },
    });
    if (msgs.length < 50) break;
  }
  return new Response(JSON.stringify({ qt_sent: sent, qt_failed: failed, qt_enqueued: enqueued }), {
    headers: { "Content-Type": "application/json" },
  });
});
