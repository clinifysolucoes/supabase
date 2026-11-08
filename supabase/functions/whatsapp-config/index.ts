// Edge Function whatsapp-config: configuracao do WhatsApp da clinica.
//
// Por que existe: a chave de acesso da Meta (token) nao pode ficar legivel no
// banco. O app chama esta function com o JWT do usuario; aqui:
//   save: valida a permissao chamando ad.whatsapp_settings_save como o
//         chamador; se veio vc_token, cifra (AES-GCM, chave WHATSAPP_ENC_KEY
//         nos secrets) e grava pelo service_role (ad.whatsapp_dispatch SECRET);
//         depois grava os demais campos como o chamador
//   test: valida a permissao e envia o modelo padrao "hello_world" da Meta
//         para o numero informado, com o numero e a chave salvos da filial
//
// Entrada (JSON):
//   { action: "save", nr_company, nr_branch, vc_token?, ...campos de ad.whatsapp_settings_save }
//   { action: "test", nr_company, nr_branch, vc_to }
// Saida 200: save { ok: true } | test { vc_wa_id }
// Erro 4xx: { "Message": "CHAVE", "Parameters": {...} }
//
// Secrets: WHATSAPP_ENC_KEY (32 bytes em base64; o mesmo da whatsapp-send).

import { createClient } from "npm:@supabase/supabase-js@2";

const GRAPH = "https://graph.facebook.com/v21.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function fail(status: number, key: string, parameters: Record<string, unknown> = {}): Response {
  return json(status, { Message: key, Parameters: parameters });
}

function passThrough(error: { message: string }): Response {
  try {
    const parsed = JSON.parse(error.message);
    if (parsed && typeof parsed.Message === "string") return json(400, parsed);
  } catch (_) {
    // mensagem nao e JSON
  }
  return fail(400, "WHATSAPP_BACKEND_ERROR", { Detail: error.message });
}

const b64 = (u: Uint8Array) => btoa(String.fromCharCode(...u));
const unb64 = (s: string) => Uint8Array.from(atob(s), (c) => c.charCodeAt(0));

async function key(): Promise<CryptoKey> {
  const raw = unb64(Deno.env.get("WHATSAPP_ENC_KEY") ?? "");
  if (raw.length !== 32) throw new Error("WHATSAPP_ENC_KEY");
  return crypto.subtle.importKey("raw", raw, "AES-GCM", false, ["encrypt", "decrypt"]);
}

async function encrypt(text: string): Promise<string> {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const data = await crypto.subtle.encrypt({ name: "AES-GCM", iv }, await key(), new TextEncoder().encode(text));
  return `v1:${b64(iv)}:${b64(new Uint8Array(data))}`;
}

async function decrypt(enc: string): Promise<string> {
  const [v, iv, data] = enc.split(":");
  if (v !== "v1") throw new Error("version");
  const plain = await crypto.subtle.decrypt({ name: "AES-GCM", iv: unb64(iv) }, await key(), unb64(data));
  return new TextDecoder().decode(plain);
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return fail(405, "WHATSAPP_METHOD");
  const authorization = req.headers.get("Authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) return fail(401, "WHATSAPP_UNAUTHORIZED");

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch (_) {
    return fail(400, "WHATSAPP_VALUE_INVALID");
  }
  const action = String(body.action ?? "");
  const nrCompany = Number(body.nr_company);
  const nrBranch = Number(body.nr_branch);
  if (!nrCompany || !nrBranch) return fail(400, "WHATSAPP_BRANCH_REQUIRED");
  const base = { nr_version: 1, nr_company: nrCompany, nr_branch: nrBranch };

  const url = Deno.env.get("SUPABASE_URL")!;
  const asCaller = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // valida a permissao (ALTERAR em SETTINGS) antes de qualquer coisa
  const check = await asCaller.schema("ad").rpc("whatsapp_settings_save", {
    p_json: { ...base, id_check_only: true },
  });
  if (check.error) return passThrough(check.error);

  if (action === "save") {
    const token = typeof body.vc_token === "string" ? body.vc_token.trim() : "";
    if (token) {
      if (!/^[A-Za-z0-9_\-.|]{20,1000}$/.test(token)) return fail(400, "WHATSAPP_TOKEN_INVALID");
      let enc: string;
      try {
        enc = await encrypt(token);
      } catch (_) {
        return fail(500, "WHATSAPP_ENCRYPTION_UNAVAILABLE");
      }
      const s = await admin.schema("ad").rpc("whatsapp_dispatch", {
        p_json: { ...base, vc_action: "SECRET", vc_token_enc: enc },
      });
      if (s.error) return passThrough(s.error);
    }
    const fields: Record<string, unknown> = { ...base };
    for (const [k, v] of Object.entries(body)) {
      if (/^(id|vc|qt)_/.test(k) && k !== "vc_token" && k !== "id_check_only") fields[k] = v;
    }
    const saved = await asCaller.schema("ad").rpc("whatsapp_settings_save", { p_json: fields });
    if (saved.error) return passThrough(saved.error);
    return json(200, { ok: true });
  }

  if (action === "test") {
    const to = String(body.vc_to ?? "").replace(/\D/g, "");
    const phone = /^55\d{10,11}$/.test(to) ? to : /^\d{10,11}$/.test(to) ? `55${to}` : "";
    if (!phone) return fail(400, "WHATSAPP_PHONE_INVALID");
    const cfg = await admin.schema("ad").rpc("whatsapp_dispatch", { p_json: { ...base, vc_action: "CONFIG" } });
    if (cfg.error) return passThrough(cfg.error);
    let token: string;
    try {
      token = await decrypt(String(cfg.data.vc_token_enc));
    } catch (_) {
      return fail(500, "WHATSAPP_ENCRYPTION_UNAVAILABLE");
    }
    const r = await fetch(`${GRAPH}/${cfg.data.vc_phone_number_id}/messages`, {
      method: "POST",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        messaging_product: "whatsapp",
        to: phone,
        type: "template",
        template: { name: "hello_world", language: { code: "en_US" } },
      }),
    });
    const out = await r.json().catch(() => ({}));
    if (!r.ok) {
      return fail(400, "WHATSAPP_SEND_FAILED", { Detail: out?.error?.message ?? `HTTP ${r.status}` });
    }
    return json(200, { vc_wa_id: out?.messages?.[0]?.id ?? null });
  }

  return fail(400, "WHATSAPP_ACTION_INVALID");
});
