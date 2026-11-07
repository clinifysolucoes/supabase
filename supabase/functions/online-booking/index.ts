// Edge Function online-booking: pagina publica de agendamento (sem login).
//
// Por que existe: anon nao tem nada no banco. A pagina publica do app chama
// esta function sem sessao; aqui a unica coisa feita e repassar o pedido para
// ad.online_booking_public com service_role (a RPC so aceita service_role e
// faz todas as validacoes: clinica ligada, profissional marcado, horario
// livre, dados do paciente, limite por CPF).
//
// Deploy com verify_jwt = false (a chave publica nova nao e um JWT).
//
// Entrada (JSON):
//   { action: "info",  vc_slug }
//   { action: "slots", vc_slug, nr_professional, dt_day }
//   { action: "book",  vc_slug, nr_professional, dh_start, vc_name, vc_cpf, dt_birth, vc_mobile,
//                      vc_email?, vc_notes?, website? }   (website = campo isca: preenchido = robo)
// Saida 200: o JSON da RPC. Erro 4xx: { "Message": "CHAVE", "Parameters": {...} }.

import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
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

const PICK: Record<string, string[]> = {
  info: [],
  slots: ["nr_professional", "dt_day"],
  book: ["nr_professional", "dh_start", "vc_name", "vc_cpf", "dt_birth", "vc_mobile", "vc_email", "vc_notes"],
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return fail(405, "ONLINE_BOOKING_METHOD");

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch (_) {
    return fail(400, "ONLINE_BOOKING_BODY_INVALID");
  }
  const action = String(body.action ?? "").toLowerCase();
  const fields = PICK[action];
  if (!fields) return fail(400, "ONLINE_BOOKING_ACTION_INVALID");
  const slug = String(body.vc_slug ?? "").trim().toLowerCase();
  if (!/^[a-z0-9-]{3,40}$/.test(slug)) return fail(404, "ONLINE_BOOKING_NOT_FOUND");
  if (action === "book" && String(body.website ?? "") !== "") return fail(400, "ONLINE_BOOKING_SLOT_TAKEN");

  const p_json: Record<string, unknown> = { nr_version: 1, vc_action: action.toUpperCase(), vc_slug: slug };
  for (const f of fields) {
    const v = body[f];
    if (v === undefined || v === null) continue;
    p_json[f] = typeof v === "string" ? v.slice(0, 600) : v;
  }

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const r = await admin.schema("ad").rpc("online_booking_public", { p_json });
  if (r.error) {
    try {
      const parsed = JSON.parse(r.error.message);
      if (parsed && typeof parsed.Message === "string") {
        return json(parsed.Message === "ONLINE_BOOKING_NOT_FOUND" ? 404 : 400, parsed);
      }
    } catch (_) {
      // mensagem nao e JSON
    }
    return fail(400, "ONLINE_BOOKING_BACKEND_ERROR");
  }
  return json(200, r.data);
});
