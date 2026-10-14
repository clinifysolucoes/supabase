// Edge Function user-create: cadastro de usuario pela empresa.
//
// Por que existe: criar uma conta no Supabase Auth exige service_role, que
// NUNCA entra no app. O app chama esta function (com o JWT do administrador);
// aqui:
//   1. ad.user_create_check  (como o chamador) - e admin? e-mail ok? ja vinculado?
//   2. auth.admin.createUser (service_role)    - so se a conta nao existir
//   3. ad.company_user_save 'I' (como o chamador) - vincula com filiais x perfis
// Se o vinculo falhar depois de criar a conta, a conta e apagada (rollback).
//
// Entrada (JSON): { nr_company, nr_branch?, vc_name, vc_email, vc_password,
//                   vc_cpf?, vc_phone?, vc_mobile?, branches: [{nr_branch, nr_profile}] }
// Saida 200:      { nr_company, nr_user, nr_company_user, id_created }
// Erro 4xx:       { "Message": "CHAVE", "Parameters": {...} }  (mesmo formato do banco)
//
// Deploy: workflow .github/workflows/edge-deploy.yml (supabase functions deploy).
// As variaveis SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY sao
// injetadas pela Supabase no runtime das Edge Functions.

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

function fail(
  status: number,
  key: string,
  parameters: Record<string, unknown> = {},
): Response {
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
  return fail(400, "USER_CREATE_BACKEND_ERROR", { Detail: error.message });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return fail(405, "USER_CREATE_METHOD");

  const authorization = req.headers.get("Authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) return fail(401, "USER_CREATE_UNAUTHORIZED");

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch (_) {
    return fail(400, "USER_CREATE_BODY_INVALID");
  }

  const nrCompany = Number(body.nr_company);
  const nrBranch = body.nr_branch == null ? null : Number(body.nr_branch);
  const email = String(body.vc_email ?? "").trim().toLowerCase();
  const branches = Array.isArray(body.branches) ? body.branches : [];

  if (!nrCompany) return fail(400, "COMPANY_USER_COMPANY_REQUIRED");
  if (!email) return fail(400, "COMPANY_USER_EMAIL_REQUIRED");
  if (branches.length === 0) return fail(400, "COMPANY_USER_BRANCHES_REQUIRED");

  const url = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // Cliente que age COMO O CHAMADOR: as RPCs validam sessao e permissao no banco.
  const asCaller = createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // 1) pre-checagem no banco (admin? e-mail valido? ja vinculado? conta existe?)
  const check = await asCaller.schema("ad").rpc("user_create_check", {
    p_json: { nr_version: 1, nr_company: nrCompany, vc_email: email },
  });
  if (check.error) return passThrough(check.error);
  const authExists = check.data?.id_auth_exists === true;

  // 2) cria a conta no Auth so se ainda nao existir
  let createdId: string | null = null;
  if (!authExists) {
    const name = String(body.vc_name ?? "").trim();
    const password = String(body.vc_password ?? "");
    if (!name) return fail(400, "USER_CREATE_NAME_REQUIRED");
    if (password.length < 8) return fail(400, "USER_CREATE_PASSWORD_WEAK");

    const admin = createClient(url, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const created = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        name,
        cpf: body.vc_cpf ?? null,
        phone: body.vc_phone ?? null,
        mobile: body.vc_mobile ?? null,
      },
    });
    if (created.error) {
      return fail(400, "USER_CREATE_AUTH_FAILED", { Detail: created.error.message });
    }
    createdId = created.data.user?.id ?? null;
  }

  // 3) vincula a empresa (como o chamador: a RPC exige administrador)
  const link = await asCaller.schema("ad").rpc("company_user_save", {
    p_json: {
      nr_version: 1,
      vc_action: "I",
      nr_company: nrCompany,
      nr_branch: nrBranch,
      vc_email: email,
      branches,
    },
  });
  if (link.error) {
    if (createdId) {
      const admin = createClient(url, serviceKey, {
        auth: { persistSession: false, autoRefreshToken: false },
      });
      await admin.auth.admin.deleteUser(createdId);
    }
    return passThrough(link.error);
  }

  return json(200, { ...(link.data ?? {}), id_created: !authExists });
});
