// Edge Function fin-attachment: anexos das contas do financeiro.
//
// Por que existe: os arquivos ficam no Storage (bucket privado "finance") e o
// app nunca tem policy de escrita no Storage nem service_role. O app chama esta
// function com o JWT do usuario; aqui:
//   upload:   ad.fin_attachment_save 'I' (como o chamador: permissao, tipo,
//             tamanho, conta) -> URL assinada de upload no caminho reservado
//   download: ad.fin_attachment_list (como o chamador: permissao de leitura)
//             -> URL assinada de download (5 minutos)
//   delete:   ad.fin_attachment_save 'DELETE' (como o chamador) -> apaga o
//             arquivo do Storage (service_role)
// O bucket e criado na primeira chamada se ainda nao existir.
//
// Entrada (JSON):
//   { action: "upload",   nr_company, nr_branch, nr_entry, it_type?, vc_name, vc_mime, qt_bytes }
//   { action: "download", nr_company, nr_branch, nr_attachment }
//   { action: "delete",   nr_company, nr_branch, nr_attachment }
// Saida 200:
//   upload:   { nr_attachment, vc_path, signed_url, token }
//   download: { signed_url, vc_name, vc_mime }
//   delete:   { nr_attachment }
// Erro 4xx: { "Message": "CHAVE", "Parameters": {...} }  (mesmo formato do banco)
//
// Deploy: workflow .github/workflows/edge-deploy.yml. SUPABASE_URL /
// SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY sao injetadas pela Supabase.

import { createClient } from "npm:@supabase/supabase-js@2";

const BUCKET = "finance";

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
  return fail(400, "FIN_ATTACHMENT_BACKEND_ERROR", { Detail: error.message });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return fail(405, "FIN_ATTACHMENT_METHOD");

  const authorization = req.headers.get("Authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) return fail(401, "FIN_ATTACHMENT_UNAUTHORIZED");

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch (_) {
    return fail(400, "FIN_ATTACHMENT_BODY_INVALID");
  }
  const action = String(body.action ?? "");
  const nrCompany = Number(body.nr_company);
  const nrBranch = Number(body.nr_branch);
  if (!nrCompany || !nrBranch) return fail(400, "FINANCE_BRANCH_REQUIRED");

  const url = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // Cliente que age COMO O CHAMADOR: as RPCs validam sessao e permissao no banco.
  const asCaller = createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const storage = admin.storage.from(BUCKET);

  async function ensureBucket(): Promise<void> {
    const found = await admin.storage.getBucket(BUCKET);
    if (found.data) return;
    await admin.storage.createBucket(BUCKET, { public: false, fileSizeLimit: 10 * 1024 * 1024 });
  }

  if (action === "upload") {
    const saved = await asCaller.schema("ad").rpc("fin_attachment_save", {
      p_json: {
        nr_version: 1,
        vc_action: "I",
        nr_company: nrCompany,
        nr_branch: nrBranch,
        nr_entry: body.nr_entry,
        it_type: body.it_type ?? 1,
        vc_name: body.vc_name,
        vc_mime: body.vc_mime,
        qt_bytes: body.qt_bytes,
      },
    });
    if (saved.error) return passThrough(saved.error);
    const path = String(saved.data.vc_path);
    await ensureBucket();
    const signed = await storage.createSignedUploadUrl(path);
    if (signed.error) {
      // sem URL o registro nao serve: desfaz
      await asCaller.schema("ad").rpc("fin_attachment_save", {
        p_json: {
          nr_version: 1,
          vc_action: "DELETE",
          nr_company: nrCompany,
          nr_branch: nrBranch,
          nr_attachment: saved.data.nr_attachment,
        },
      });
      return fail(400, "FIN_ATTACHMENT_STORAGE_FAILED", { Detail: signed.error.message });
    }
    return json(200, {
      nr_attachment: saved.data.nr_attachment,
      vc_path: path,
      signed_url: signed.data.signedUrl,
      token: signed.data.token,
    });
  }

  if (action === "download") {
    const listed = await asCaller.schema("ad").rpc("fin_attachment_list", {
      p_json: {
        nr_version: 1,
        nr_company: nrCompany,
        nr_branch: nrBranch,
        nr_attachment: body.nr_attachment,
      },
    });
    if (listed.error) return passThrough(listed.error);
    const att = listed.data?.attachments?.[0];
    if (!att) return fail(404, "FIN_ATTACHMENT_NOT_FOUND");
    const signed = await storage.createSignedUrl(String(att.vc_path), 300, { download: String(att.vc_name) });
    if (signed.error) return fail(400, "FIN_ATTACHMENT_STORAGE_FAILED", { Detail: signed.error.message });
    return json(200, { signed_url: signed.data.signedUrl, vc_name: att.vc_name, vc_mime: att.vc_mime });
  }

  if (action === "delete") {
    const removed = await asCaller.schema("ad").rpc("fin_attachment_save", {
      p_json: {
        nr_version: 1,
        vc_action: "DELETE",
        nr_company: nrCompany,
        nr_branch: nrBranch,
        nr_attachment: body.nr_attachment,
      },
    });
    if (removed.error) return passThrough(removed.error);
    // o registro ja esta excluido; se o arquivo nao sair agora, fica orfao no bucket (sem acesso)
    await storage.remove([String(removed.data.vc_path)]);
    return json(200, { nr_attachment: removed.data.nr_attachment });
  }

  return fail(400, "FIN_ATTACHMENT_ACTION_INVALID");
});
