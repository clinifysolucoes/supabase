// Edge Function material-price-lookup: pesquisa de preco de mercado de um material.
//
// Por que existe: a tela de precificacao oferece "preenchimento automatico" do
// preco da embalagem de um material, buscando valores praticados em lojas
// brasileiras de produtos odontologicos. A pesquisa na web precisa de uma chave
// de API (nunca no app). O app chama esta function com o JWT do usuario; aqui:
//   1. ad.pricing_param_get (como o chamador) - tem acesso a filial e a tela PRICING?
//   2. provedor de pesquisa (Claude + web search) - devolve ofertas em JSON
// A function NAO grava nada: o usuario escolhe a oferta e salva com
// (ad.material_save, it_price_source = 2, vc_price_source = loja/URL).
//
// Entrada (JSON): { nr_company, nr_branch, vc_query }   (nome do material + embalagem)
// Saida 200:      { vc_query, vc_provider, vl_suggested, offers: [{ vc_store, vc_title,
//                   vl_price, vc_package, vc_url }], dh_lookup }
// Erro 4xx/5xx:   { "Message": "CHAVE", "Parameters": {...} }  (mesmo formato do banco)
//
// Secrets (Supabase > Edge Functions > Secrets):
//   ANTHROPIC_API_KEY    obrigatoria (sem ela: 503 MATERIAL_LOOKUP_UNAVAILABLE)
//   PRICE_LOOKUP_MODEL   opcional (default claude-sonnet-5-5)
// SUPABASE_URL / SUPABASE_ANON_KEY sao injetadas pela Supabase no runtime.
//
// Deploy: workflow .github/workflows/edge-deploy.yml (supabase functions deploy).

import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const ANTHROPIC_URL = "https://api.anthropic.com/v1/messages";
const DEFAULT_MODEL = "claude-sonnet-5-5";
const MAX_OFFERS = 6;

interface Offer {
  vc_store: string;
  vc_title: string;
  vl_price: number;
  vc_package: string | null;
  vc_url: string | null;
}

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
    if (parsed && typeof parsed.Message === "string") {
      const status = parsed.Message === "PRICING_FORBIDDEN" ? 403 : 400;
      return json(status, parsed);
    }
  } catch (_) {
    // mensagem nao e JSON
  }
  return fail(400, "MATERIAL_LOOKUP_BACKEND_ERROR", { Detail: error.message });
}

class LookupUnavailable extends Error {}
class LookupFailed extends Error {}

function text(value: unknown, max: number): string | null {
  if (typeof value !== "string") return null;
  const t = value.trim();
  return t.length === 0 ? null : t.slice(0, max);
}

function money(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value) && value > 0) {
    return Math.round(value * 100) / 100;
  }
  if (typeof value === "string") {
    const normalized = value.replace(/[^\d,.-]/g, "").replace(/\.(?=\d{3}(\D|$))/g, "").replace(",", ".");
    const n = Number(normalized);
    if (Number.isFinite(n) && n > 0) return Math.round(n * 100) / 100;
  }
  return null;
}

/** Extrai o primeiro objeto JSON de um texto (o modelo pode cercar com ``` ou frases). */
function extractJson(raw: string): unknown {
  const cleaned = raw.replace(/```(?:json)?/gi, "");
  const start = cleaned.indexOf("{");
  const end = cleaned.lastIndexOf("}");
  if (start < 0 || end <= start) return null;
  try {
    return JSON.parse(cleaned.slice(start, end + 1));
  } catch (_) {
    return null;
  }
}

function sanitizeOffers(payload: unknown): Offer[] {
  const list = (payload as { offers?: unknown })?.offers;
  if (!Array.isArray(list)) return [];
  const offers: Offer[] = [];
  for (const item of list) {
    if (!item || typeof item !== "object") continue;
    const o = item as Record<string, unknown>;
    const price = money(o.vl_price ?? o.price);
    const store = text(o.vc_store ?? o.store, 60);
    if (price === null || store === null) continue;
    const url = text(o.vc_url ?? o.url, 200);
    offers.push({
      vc_store: store,
      vc_title: text(o.vc_title ?? o.title, 120) ?? store,
      vl_price: price,
      vc_package: text(o.vc_package ?? o.package, 40),
      vc_url: url && /^https?:\/\//i.test(url) ? url : null,
    });
    if (offers.length >= MAX_OFFERS) break;
  }
  return offers.sort((a, b) => a.vl_price - b.vl_price);
}

function median(values: number[]): number | null {
  if (values.length === 0) return null;
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  const m = sorted.length % 2 === 1 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
  return Math.round(m * 100) / 100;
}

/** Claude com a ferramenta de pesquisa na web, pedindo JSON estruturado. */
async function lookupWithClaude(query: string): Promise<Offer[]> {
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) throw new LookupUnavailable("ANTHROPIC_API_KEY ausente");
  const model = Deno.env.get("PRICE_LOOKUP_MODEL") ?? DEFAULT_MODEL;

  const prompt =
    `Pesquise na web o preço atual, em reais (R$), do produto odontológico abaixo em lojas online ` +
    `brasileiras (Dental Cremer, Dental Speed, Surya Dental, Dental Vision, Dental Jet, Mercado Livre, ` +
    `Amazon Brasil ou similares).\n\nProduto: "${query}"\n\n` +
    `Responda SOMENTE com um JSON neste formato, sem nenhum texto fora dele:\n` +
    `{"offers": [{"vc_store": "nome da loja", "vc_title": "título do anúncio", "vl_price": 123.45, ` +
    `"vc_package": "embalagem/quantidade", "vc_url": "https://..."}]}\n` +
    `Regras: até ${MAX_OFFERS} ofertas, apenas produtos equivalentes ao pedido, vl_price é o preço da ` +
    `embalagem anunciada como número com ponto decimal, vc_url é a página do produto. ` +
    `Se não encontrar nada confiável, responda {"offers": []}.`;

  const response = await fetch(ANTHROPIC_URL, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model,
      max_tokens: 1500,
      system:
        "Você é o assistente de compras de uma clínica odontológica no Brasil. Você só responde JSON válido.",
      tools: [
        {
          type: "web_search_20250305",
          name: "web_search",
          max_uses: 4,
          user_location: { type: "approximate", country: "BR" },
        },
      ],
      messages: [{ role: "user", content: prompt }],
    }),
  });

  if (!response.ok) {
    const detail = (await response.text()).slice(0, 300);
    throw new LookupFailed(`${response.status} ${detail}`);
  }
  const data = await response.json() as { content?: Array<{ type: string; text?: string }> };
  const answer = (data.content ?? [])
    .filter((block) => block.type === "text" && typeof block.text === "string")
    .map((block) => block.text as string)
    .join("\n");
  return sanitizeOffers(extractJson(answer));
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return fail(405, "MATERIAL_LOOKUP_METHOD");

  const authorization = req.headers.get("Authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) return fail(401, "MATERIAL_LOOKUP_UNAUTHORIZED");

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch (_) {
    return fail(400, "MATERIAL_LOOKUP_BODY_INVALID");
  }
  const nrCompany = Number(body.nr_company);
  const nrBranch = Number(body.nr_branch);
  const query = text(body.vc_query, 120);
  if (!Number.isInteger(nrCompany) || !Number.isInteger(nrBranch)) {
    return fail(400, "PRICING_BRANCH_REQUIRED");
  }
  if (!query || query.length < 3) return fail(400, "MATERIAL_LOOKUP_QUERY_INVALID");

  // 1. Acesso: a RPC valida sessao, filial e permissao de leitura na tela PRICING.
  const asCaller = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authorization } }, auth: { persistSession: false } },
  );
  const access = await asCaller.schema("ad").rpc("pricing_param_get", {
    p_json: { nr_version: 1, nr_company: nrCompany, nr_branch: nrBranch },
  });
  if (access.error) return passThrough(access.error);

  // 2. Pesquisa de mercado.
  try {
    const offers = await lookupWithClaude(query);
    return json(200, {
      vc_query: query,
      vc_provider: "claude-web-search",
      vl_suggested: median(offers.map((o) => o.vl_price)),
      offers,
      dh_lookup: new Date().toISOString(),
    });
  } catch (e) {
    if (e instanceof LookupUnavailable) return fail(503, "MATERIAL_LOOKUP_UNAVAILABLE");
    const detail = e instanceof Error ? e.message : String(e);
    return fail(502, "MATERIAL_LOOKUP_FAILED", { Detail: detail.slice(0, 200) });
  }
});
