// Edge Function notify-confirm: confirmacao da consulta pelo link do lembrete
// por e-mail/SMS (sem login).
//
// A pagina publica do app (/confirmar/<token>) chama esta function sem
// sessao; aqui so se repassa o token para ad.notify_dispatch CONFIRM com
// service_role (a RPC so aceita service_role, acha a mensagem pelo token e
// confirma a consulta Agendado). Deploy com verify_jwt = false.
//
// Entrada (JSON): { token }
// Saida 200: { it_result, vc_clinic, vc_patient, vc_date, vc_time, vc_professional }
//   it_result 1 confirmada agora | 2 ja estava confirmada | 3 nao da mais | 0 link invalido

import { createClient } from "npm:@supabase/supabase-js@2";

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

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json(405, { Message: "NOTIFY_METHOD" });
  let token = "";
  try {
    token = String((await req.json())?.token ?? "").trim();
  } catch (_) {
    return json(400, { Message: "NOTIFY_BODY_INVALID" });
  }
  if (!UUID.test(token)) return json(200, { it_result: 0 });

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const r = await admin.schema("ad").rpc("notify_dispatch", {
    p_json: { nr_version: 1, vc_action: "CONFIRM", uu_token: token },
  });
  if (r.error) return json(500, { Message: "NOTIFY_BACKEND_ERROR" });
  const d = r.data ?? {};
  return json(200, {
    it_result: d.it_result ?? 0,
    vc_clinic: d.vc_clinic ?? null,
    vc_patient: d.vc_patient ?? null,
    vc_date: d.vc_date ?? null,
    vc_time: d.vc_time ?? null,
    vc_professional: d.vc_professional ?? null,
  });
});
