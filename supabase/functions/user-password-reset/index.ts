// Edge Function user-password-reset: o administrador da empresa define uma
// senha nova para um usuario dela.
//
// Por que existe: trocar a senha de outra conta no Supabase Auth exige
// service_role, que NUNCA entra no app. O app chama esta function com o JWT do
// administrador; aqui:
//   1. ad.user_password_reset_check (como o chamador) - e admin? usuario da
//      empresa? conta nao compartilhada com outra empresa? (grava o log)
//   2. auth.admin.updateUserById (service_role) - grava a senha nova
//
// Entrada (JSON): { nr_company, nr_branch?, nr_user, vc_password }
// Saida 200:      { nr_user }
// Erro 4xx:       { "Message": "CHAVE", "Parameters": {...} }  (mesmo formato do banco)
//
// Deploy: workflow .github/workflows/edge-deploy.yml. SUPABASE_URL /
// SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY sao injetadas pela Supabase.

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

/** Repassa o erro do banco ({"Message": ...}) como veio; outros viram chave generica. */
function passThrough(error: { message: string }): Response {
  try {
    const parsed = JSON.parse(error.message);
    if (parsed && typeof parsed.Message === "string") return json(400, parsed);
  } catch (_) {
    // mensagem nao e JSON
  }
  return fail(400, "USER_PASSWORD_BACKEND_ERROR", { Detail: error.message });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return fail(405, "USER_PASSWORD_METHOD");

  const authorization = req.headers.get("Authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) return fail(401, "USER_PASSWORD_UNAUTHORIZED");

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch (_) {
    return fail(400, "USER_PASSWORD_BODY_INVALID");
  }
  const password = String(body.vc_password ?? "");
  if (password.length < 8) return fail(400, "USER_CREATE_PASSWORD_WEAK");

  const url = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // Cliente que age COMO O CHAMADOR: a RPC valida sessao e permissao no banco.
  const asCaller = createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const check = await asCaller.schema("ad").rpc("user_password_reset_check", {
    p_json: {
      nr_version: 1,
      nr_company: body.nr_company,
      nr_branch: body.nr_branch ?? null,
      nr_user: body.nr_user,
    },
  });
  if (check.error) return passThrough(check.error);
  const uuAuth = String(check.data?.uu_auth ?? "");
  if (!uuAuth) return fail(400, "COMPANY_USER_NOT_FOUND");

  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const updated = await admin.auth.admin.updateUserById(uuAuth, { password });
  if (updated.error) {
    return fail(400, "USER_PASSWORD_AUTH_FAILED", { Detail: updated.error.message });
  }
  return json(200, { nr_user: check.data.nr_user });
});
