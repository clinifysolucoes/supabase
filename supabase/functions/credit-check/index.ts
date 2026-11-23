// Edge Function credit-check: consulta de credito (SPC/Serasa/Boa Vista) do
// paciente pelo CPF.
//
// Por que existe: a chave do birô de credito e do sistema e NUNCA entra no
// app. O app chama esta function com o JWT do usuario; aqui:
//   1. ad.credit_check_request (como o chamador) - permissao ALTERAR em
//      PATIENTS, consulta ligada na filial, autorizacao do paciente, CPF valido;
//      grava a consulta pendente e devolve o CPF
//   2. consulta o birô (adaptador do provedor em CREDIT_PROVIDER)
//   3. ad.credit_check_result (service_role) - grava o resultado resumido
//
// Sem as secrets do birô a consulta fica registrada com erro
// CREDIT_NOT_CONFIGURED (a tela mostra "consulta ainda nao contratada").
// Os adaptadores dos birôs dependem do contrato (cada um tem API, homologacao
// e layout proprios): enquanto nao forem escritos, devolvem
// CREDIT_PROVIDER_NOT_IMPLEMENTED. O ponto unico para escrever cada um e a
// funcao queryProvider abaixo, que precisa devolver o resultado normalizado.
//
// Entrada (JSON): { nr_company, nr_branch, nr_patient, id_consent }
// Saida 200:      { nr_check, it_status, it_result?, qt_score?, qt_debts?, vl_debts?, Message? }
// Erro 4xx:       { "Message": "CHAVE", "Parameters": {...} }  (mesmo formato do banco)
//
// Secrets (Edge Functions -> Secrets):
//   CREDIT_PROVIDER    serasa | spc | boavista
//   CREDIT_API_URL     endereco da API do birô (homologacao ou producao)
//   CREDIT_API_KEY     chave/token do contrato (ou client secret do OAuth)
//   CREDIT_CLIENT_ID   opcional (birôs com OAuth client credentials)
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

const PROVIDERS: Record<string, number> = { serasa: 1, spc: 2, boavista: 3 };

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
  return fail(400, "CREDIT_BACKEND_ERROR", { Detail: error.message });
}

/** Resultado normalizado de um birô. */
interface CreditResult {
  it_result: 1 | 2; // 1 nada consta | 2 com restricoes
  qt_score?: number; // 0 a 1000
  qt_debts?: number;
  vl_debts?: number;
  vc_protocol?: string;
  js_detail?: Record<string, unknown>; // resumo: credores, valores, datas
}

class ProviderError extends Error {}

/**
 * Consulta o birô. Cada adaptador recebe o CPF (so digitos), o nome e o
 * nascimento do paciente e devolve o resultado normalizado.
 */
async function queryProvider(
  provider: string,
  _doc: string,
  _name: string,
  _birth: string | null,
): Promise<CreditResult> {
  switch (provider) {
    case "serasa":
    case "spc":
    case "boavista":
      // Escrever aqui o adaptador quando o contrato com o birô existir
      // (endereco, autenticacao, layout da resposta e mapeamento para CreditResult).
      throw new ProviderError("CREDIT_PROVIDER_NOT_IMPLEMENTED");
    default:
      throw new ProviderError("CREDIT_NOT_CONFIGURED");
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return fail(405, "CREDIT_METHOD");

  const authorization = req.headers.get("Authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) return fail(401, "CREDIT_UNAUTHORIZED");

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch (_) {
    return fail(400, "CREDIT_BODY_INVALID");
  }

  const url = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const provider = (Deno.env.get("CREDIT_PROVIDER") ?? "").trim().toLowerCase();
  const configured = provider in PROVIDERS && !!Deno.env.get("CREDIT_API_URL") &&
    !!Deno.env.get("CREDIT_API_KEY");

  // 1. valida e abre a consulta COMO O CHAMADOR
  const asCaller = createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const opened = await asCaller.schema("ad").rpc("credit_check_request", {
    p_json: {
      nr_version: 1,
      nr_company: body.nr_company,
      nr_branch: body.nr_branch,
      nr_patient: body.nr_patient,
      id_consent: body.id_consent === true,
      it_provider: PROVIDERS[provider] ?? 1,
    },
  });
  if (opened.error) return passThrough(opened.error);
  const nrCheck = Number(opened.data?.nr_check);

  // 2. consulta o birô (ou registra que nao esta configurado)
  let result: CreditResult | null = null;
  let errorKey: string | null = null;
  if (!configured) {
    errorKey = "CREDIT_NOT_CONFIGURED";
  } else {
    try {
      result = await queryProvider(
        provider,
        String(opened.data.vc_document),
        String(opened.data.vc_name ?? ""),
        opened.data.dt_birth ? String(opened.data.dt_birth) : null,
      );
    } catch (e) {
      errorKey = e instanceof ProviderError ? e.message : "CREDIT_PROVIDER_ERROR";
    }
  }

  // 3. grava o resultado (service_role)
  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const saved = await admin.schema("ad").rpc("credit_check_result", {
    p_json: {
      nr_version: 1,
      nr_company: body.nr_company,
      nr_branch: body.nr_branch,
      nr_check: nrCheck,
      ...(result ? { it_status: 2, ...result } : { it_status: 9, vc_error: errorKey }),
    },
  });
  if (saved.error) return passThrough(saved.error);

  if (!result) return json(200, { nr_check: nrCheck, it_status: 9, Message: errorKey });
  return json(200, { nr_check: nrCheck, it_status: 2, ...result, js_detail: undefined });
});
