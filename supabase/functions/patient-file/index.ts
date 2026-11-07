// Edge Function patient-file: fotos e exames do prontuario.
//
// Por que existe: os arquivos ficam no Storage (bucket privado "patient") e o
// app nunca tem policy no Storage nem service_role. O app chama esta function
// com o JWT do usuario; aqui:
//   upload:   ad.patient_file_save 'I' (como o chamador: permissao, tipo,
//             tamanho, paciente) -> URL assinada de upload no caminho reservado
//   urls:     ad.patient_file_list (como o chamador: permissao de leitura)
//             -> URLs assinadas de visualizacao (10 minutos) dos arquivos pedidos
//   download: ad.patient_file_list -> URL assinada de download (5 minutos)
//   delete:   ad.patient_file_save 'DELETE' (como o chamador) -> apaga o
//             arquivo do Storage (service_role)
// O bucket e criado na primeira chamada se ainda nao existir.
//
// Entrada (JSON):
//   { action: "upload",   nr_company, nr_branch, nr_patient, it_type, it_category?, vc_name, vc_mime,
//                         qt_bytes, dt_file?, vc_tooth?, vc_description? }
//   { action: "urls",     nr_company, nr_branch, nr_patient, nr_files: [..] }
//   { action: "download", nr_company, nr_branch, nr_patient, nr_file }
//   { action: "delete",   nr_company, nr_branch, nr_patient, nr_file }
// Saida 200:
//   upload:   { nr_file, vc_path, signed_url, token }
//   urls:     { urls: { "<nr_file>": "<signed_url>" } }
//   download: { signed_url, vc_name, vc_mime }
//   delete:   { nr_file }
// Erro 4xx: { "Message": "CHAVE", "Parameters": {...} }  (mesmo formato do banco)
//
// Deploy: workflow .github/workflows/edge-deploy.yml. SUPABASE_URL /
// SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY sao injetadas pela Supabase.

import { createClient } from "npm:@supabase/supabase-js@2";

const BUCKET = "patient";
const MAX_BYTES = 20 * 1024 * 1024;

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
  return fail(400, "PATIENT_FILE_BACKEND_ERROR", { Detail: error.message });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return fail(405, "PATIENT_FILE_METHOD");

  const authorization = req.headers.get("Authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) return fail(401, "PATIENT_FILE_UNAUTHORIZED");

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch (_) {
    return fail(400, "PATIENT_FILE_BODY_INVALID");
  }
  const action = String(body.action ?? "");
  const nrCompany = Number(body.nr_company);
  const nrBranch = Number(body.nr_branch);
  const nrPatient = Number(body.nr_patient);
  if (!nrCompany || !nrBranch) return fail(400, "RECORD_BRANCH_REQUIRED");
  if (!nrPatient) return fail(400, "PATIENT_REQUIRED");
  const base = { nr_version: 1, nr_company: nrCompany, nr_branch: nrBranch, nr_patient: nrPatient };

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
    await admin.storage.createBucket(BUCKET, { public: false, fileSizeLimit: MAX_BYTES });
  }

  async function listFiles(nrFiles: unknown[]) {
    return await asCaller.schema("ad").rpc("patient_file_list", {
      p_json: { ...base, nr_files: nrFiles },
    });
  }

  if (action === "upload") {
    const saved = await asCaller.schema("ad").rpc("patient_file_save", {
      p_json: {
        ...base,
        vc_action: "I",
        it_type: body.it_type,
        it_category: body.it_category ?? 99,
        vc_name: body.vc_name,
        vc_mime: body.vc_mime,
        qt_bytes: body.qt_bytes,
        dt_file: body.dt_file ?? null,
        vc_tooth: body.vc_tooth ?? null,
        vc_description: body.vc_description ?? null,
      },
    });
    if (saved.error) return passThrough(saved.error);
    const path = String(saved.data.vc_path);
    await ensureBucket();
    const signed = await storage.createSignedUploadUrl(path);
    if (signed.error) {
      // sem URL o registro nao serve: desfaz
      await asCaller.schema("ad").rpc("patient_file_save", {
        p_json: { ...base, vc_action: "DELETE", nr_file: saved.data.nr_file },
      });
      return fail(400, "PATIENT_FILE_STORAGE_FAILED", { Detail: signed.error.message });
    }
    return json(200, {
      nr_file: saved.data.nr_file,
      vc_path: path,
      signed_url: signed.data.signedUrl,
      token: signed.data.token,
    });
  }

  if (action === "urls") {
    const wanted = Array.isArray(body.nr_files) ? body.nr_files.slice(0, 100) : [];
    if (wanted.length === 0) return json(200, { urls: {} });
    const listed = await listFiles(wanted);
    if (listed.error) return passThrough(listed.error);
    const files = (listed.data?.files ?? []) as Array<{ nr_file: number; vc_path: string }>;
    if (files.length === 0) return json(200, { urls: {} });
    const signed = await storage.createSignedUrls(files.map((f) => f.vc_path), 600);
    if (signed.error) return fail(400, "PATIENT_FILE_STORAGE_FAILED", { Detail: signed.error.message });
    const urls: Record<string, string> = {};
    signed.data.forEach((s, i) => {
      if (s.signedUrl) urls[String(files[i].nr_file)] = s.signedUrl;
    });
    return json(200, { urls });
  }

  if (action === "download") {
    const listed = await listFiles([body.nr_file]);
    if (listed.error) return passThrough(listed.error);
    const file = listed.data?.files?.[0];
    if (!file) return fail(404, "PATIENT_FILE_NOT_FOUND");
    const signed = await storage.createSignedUrl(String(file.vc_path), 300, { download: String(file.vc_name) });
    if (signed.error) return fail(400, "PATIENT_FILE_STORAGE_FAILED", { Detail: signed.error.message });
    return json(200, { signed_url: signed.data.signedUrl, vc_name: file.vc_name, vc_mime: file.vc_mime });
  }

  if (action === "delete") {
    const removed = await asCaller.schema("ad").rpc("patient_file_save", {
      p_json: { ...base, vc_action: "DELETE", nr_file: body.nr_file },
    });
    if (removed.error) return passThrough(removed.error);
    // o registro ja esta excluido; se o arquivo nao sair agora, fica orfao no bucket (sem acesso)
    await storage.remove([String(removed.data.vc_path)]);
    return json(200, { nr_file: removed.data.nr_file });
  }

  return fail(400, "PATIENT_FILE_ACTION_INVALID");
});
