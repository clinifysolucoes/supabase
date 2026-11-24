// Edge Function integrations-status: diz ao app quais integracoes externas ja
// tem as secrets configuradas no projeto, para as telas mostrarem o aviso
// "aguardando configuracao" so enquanto faltar algo.
//
// Devolve so SIM/NAO e o NOME das secrets que faltam, nunca o valor. Qualquer
// usuario logado pode chamar (verify_jwt = true): saber se o sistema ja tem
// conta no Resend ou no birô nao expoe dado de nenhuma clinica.
//
// "implemented" diz se o adaptador do provedor ja foi escrito na Edge Function
// da integracao (credit-check / invoice-issue). Quando escrever um adaptador,
// mude aqui para true; ate la a integracao fica "em preparacao" mesmo com as
// secrets cadastradas.
//
// Entrada: nada (POST {}).
// Saida 200: { items: { <codigo>: { configured, implemented, ready, missing: [nome] } } }
//
// Deploy: workflow .github/workflows/edge-deploy.yml (ou MCP em homologacao).

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

/** Secrets de cada integracao e se o adaptador ja existe. */
const INTEGRATIONS: Record<string, { secrets: string[]; implemented: boolean }> = {
  email: { secrets: ["RESEND_API_KEY", "RESEND_FROM", "CRON_SECRET", "APP_PUBLIC_URL"], implemented: true },
  sms: { secrets: ["ZENVIA_API_TOKEN", "ZENVIA_FROM", "CRON_SECRET", "APP_PUBLIC_URL"], implemented: true },
  whatsapp: {
    secrets: ["WHATSAPP_ENC_KEY", "WHATSAPP_VERIFY_TOKEN", "WHATSAPP_APP_SECRET", "CRON_SECRET"],
    implemented: true,
  },
  credit: { secrets: ["CREDIT_PROVIDER", "CREDIT_API_URL", "CREDIT_API_KEY"], implemented: false },
  invoice: { secrets: ["INVOICE_PROVIDER", "INVOICE_API_URL", "INVOICE_API_KEY"], implemented: false },
  price_lookup: { secrets: ["ANTHROPIC_API_KEY"], implemented: true },
};

Deno.serve((req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  const items: Record<string, unknown> = {};
  for (const [code, def] of Object.entries(INTEGRATIONS)) {
    const missing = def.secrets.filter((k) => !(Deno.env.get(k) ?? "").trim());
    const configured = missing.length === 0;
    items[code] = { configured, implemented: def.implemented, ready: configured && def.implemented, missing };
  }
  return new Response(JSON.stringify({ items }), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
