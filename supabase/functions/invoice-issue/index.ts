// Edge Function invoice-issue: emissao e cancelamento de NFS-e num emissor
// (Focus NFe, NFE.io, eNotas, PlugNotas).
//
// Por que existe: a chave do emissor e do sistema e NUNCA entra no app. O app
// chama esta function com o JWT do usuario; aqui:
//   1. ad.invoice_issue_check (como o chamador) - permissao em FINANCE, NFS-e
//      ligada e configurada na filial, situacao da nota; devolve prestador,
//      tomador e servico (e, na emissao, passa a nota para "processando")
//   2. envia ao emissor (adaptador do provedor em INVOICE_PROVIDER)
//   3. ad.invoice_result (service_role) - grava numero, PDF/XML ou o erro
//
// Sem as secrets do emissor a nota fica com erro INVOICE_NOT_CONFIGURED e pode
// ser reenviada depois. Os adaptadores dependem do contrato com o emissor (cada
// um tem API, autenticacao e layout proprios): enquanto nao forem escritos,
// devolvem INVOICE_PROVIDER_NOT_IMPLEMENTED. O ponto unico para escrever cada
// um sao as funcoes issueOnProvider / cancelOnProvider abaixo.
//
// Entrada (JSON): { nr_company, nr_branch, nr_invoice, vc_action: "ISSUE" | "CANCEL", vc_cancel_reason? }
// Saida 200:      { nr_invoice, it_status, Message? }
// Erro 4xx:       { "Message": "CHAVE", "Parameters": {...} }  (mesmo formato do banco)
//
// Secrets (Edge Functions -> Secrets):
//   INVOICE_PROVIDER   focus | nfeio | enotas | plugnotas
//   INVOICE_API_URL    endereco da API do emissor (homologacao ou producao)
//   INVOICE_API_KEY    token da conta no emissor
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

const PROVIDERS = ["focus", "nfeio", "enotas", "plugnotas"];

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
  return fail(400, "INVOICE_BACKEND_ERROR", { Detail: error.message });
}

/** Resposta normalizada da emissao. */
interface IssueResult {
  vc_number: string;
  vc_verification?: string;
  vc_pdf_url?: string;
  vc_xml_url?: string;
  vc_provider_ref?: string;
}

class ProviderError extends Error {}

/** Dados que ad.invoice_issue_check devolve (prestador, tomador, servico). */
// deno-lint-ignore no-explicit-any
type InvoicePayload = Record<string, any>;

/**
 * Envia a NFS-e ao emissor e devolve numero, codigo de verificacao e links.
 * Muitos emissores processam de forma assincrona: o adaptador pode consultar
 * ate a nota ficar pronta (polling curto) ou devolver erro para reenviar.
 */
async function issueOnProvider(provider: string, _payload: InvoicePayload): Promise<IssueResult> {
  switch (provider) {
    case "focus":
    case "nfeio":
    case "enotas":
    case "plugnotas":
      // Escrever aqui o adaptador quando o contrato com o emissor existir
      // (endereco, autenticacao, layout do envio e da resposta).
      throw new ProviderError("INVOICE_PROVIDER_NOT_IMPLEMENTED");
    default:
      throw new ProviderError("INVOICE_NOT_CONFIGURED");
  }
}

/** Cancela no emissor a NFS-e ja emitida. */
async function cancelOnProvider(provider: string, _payload: InvoicePayload): Promise<void> {
  switch (provider) {
    case "focus":
    case "nfeio":
    case "enotas":
    case "plugnotas":
      throw new ProviderError("INVOICE_PROVIDER_NOT_IMPLEMENTED");
    default:
      throw new ProviderError("INVOICE_NOT_CONFIGURED");
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return fail(405, "INVOICE_METHOD");

  const authorization = req.headers.get("Authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) return fail(401, "INVOICE_UNAUTHORIZED");

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch (_) {
    return fail(400, "INVOICE_BODY_INVALID");
  }
  const action = String(body.vc_action ?? "").toUpperCase();

  const url = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const provider = (Deno.env.get("INVOICE_PROVIDER") ?? "").trim().toLowerCase();
  const configured = PROVIDERS.includes(provider) && !!Deno.env.get("INVOICE_API_URL") &&
    !!Deno.env.get("INVOICE_API_KEY");

  // 1. valida e prepara COMO O CHAMADOR
  const asCaller = createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const checked = await asCaller.schema("ad").rpc("invoice_issue_check", {
    p_json: {
      nr_version: 1,
      nr_company: body.nr_company,
      nr_branch: body.nr_branch,
      nr_invoice: body.nr_invoice,
      vc_action: action,
      vc_cancel_reason: body.vc_cancel_reason ?? null,
    },
  });
  if (checked.error) return passThrough(checked.error);
  const payload = checked.data as InvoicePayload;

  // 2. envia ao emissor (ou registra que nao esta configurado)
  let issued: IssueResult | null = null;
  let ok = false;
  let errorKey: string | null = null;
  if (!configured) {
    errorKey = "INVOICE_NOT_CONFIGURED";
  } else {
    try {
      if (action === "ISSUE") {
        issued = await issueOnProvider(provider, payload);
      } else {
        await cancelOnProvider(provider, payload);
      }
      ok = true;
    } catch (e) {
      errorKey = e instanceof ProviderError ? e.message : "INVOICE_PROVIDER_ERROR";
    }
  }

  // 3. grava o resultado (service_role)
  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const saved = await admin.schema("ad").rpc("invoice_result", {
    p_json: {
      nr_version: 1,
      nr_company: body.nr_company,
      nr_branch: body.nr_branch,
      nr_invoice: payload.nr_invoice,
      vc_action: action,
      id_ok: ok,
      vc_error: errorKey,
      vc_cancel_reason: payload.vc_cancel_reason ?? null,
      ...(issued ?? {}),
    },
  });
  if (saved.error) return passThrough(saved.error);

  return json(200, {
    nr_invoice: payload.nr_invoice,
    it_status: saved.data?.it_status,
    ...(errorKey ? { Message: errorKey } : {}),
  });
});
