#!/usr/bin/env node
/*
 * gen-dictionary.mjs - gera, a partir de docs/dictionary/schema.json (source of truth):
 *
 *   docs/DATA_DICTIONARY.md        Markdown com ERD Mermaid (renderiza no GitHub) + tabelas
 *   docs/dictionary/schema.js      window.DICTIONARY = {...} para o viewer docs/dictionary/index.html
 *   <arquivo>                      (--sql <arquivo>) COMMENT ON table/column/function -> repeatable Flyway
 *
 * Flags:
 *   --check   nao grava; falha (exit 1) se .md/.js em disco estiverem desatualizados
 *   --sql F   grava tambem o SQL de comentarios em F
 *   --quiet   sem log
 *
 * Sem dependencias. Node 18+.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const SRC = path.join(root, 'docs', 'dictionary', 'schema.json');
const MD = path.join(root, 'docs', 'DATA_DICTIONARY.md');
const JS = path.join(root, 'docs', 'dictionary', 'schema.js');

const args = process.argv.slice(2);
const CHECK = args.includes('--check');
const QUIET = args.includes('--quiet');
const sqlIdx = args.indexOf('--sql');
const SQL_OUT = sqlIdx >= 0 ? args[sqlIdx + 1] : null;

const log = (...m) => { if (!QUIET) console.log(...m); };

const raw = JSON.parse(fs.readFileSync(SRC, 'utf8'));

/* ---------- expande colunas de auditoria ---------- */
const dict = {
  ...raw,
  tables: raw.tables.map((t) => ({
    ...t,
    columns: t.audit === false ? t.columns : [...t.columns, ...raw.audit_columns],
  })),
};

/* ---------- helpers ---------- */
const sqlStr = (s) => `'${String(s).replace(/'/g, "''")}'`;
const mdCell = (s) => (s == null || s === '' ? '' : String(s).replace(/\|/g, '\\|').replace(/\n/g, ' '));
const baseType = (t) => String(t).replace(/\(.*\)/, '').replace(/\s+/g, '_');
/* schema da tabela: "schema" no JSON (od, ...) ou o schema padrao (ad) */
const schemaOf = (t) => t.schema || dict.schema;
const qualified = (t) => `${schemaOf(t)}.${t.name}`;
const anchor = (t) => `${schemaOf(t)}${t.name.replace(/_/g, '')}`;

function keyLabel(c) {
  const k = [];
  if (c.pk) k.push(`PK${c.pk}`);
  if (c.uk) k.push('UK');
  if (c.fk) k.push('FK');
  return k.join(', ');
}
function colDescription(c) {
  let d = c.description || '';
  if (c.values) {
    d += ' Valores: ' + Object.entries(c.values).map(([k, v]) => `${k} = ${v}`).join('; ') + '.';
  }
  return d;
}

/* ---------- Mermaid ERD ---------- */
function mermaidErd() {
  const lines = ['erDiagram'];
  for (const r of dict.relations) lines.push(`  ${r.from} ${r.card} ${r.to} : "${r.label}"`);
  for (const e of dict.external_entities || []) {
    lines.push(`  ${e.name} {`);
    lines.push(`    uuid id PK`);
    lines.push(`    text email`);
    lines.push('  }');
  }
  for (const t of dict.tables) {
    lines.push(`  ${t.name} {`);
    for (const c of t.columns) {
      if (['nr_operator', 'dh_created', 'dh_updated'].includes(c.name)) continue;
      const keys = [];
      if (c.pk) keys.push('PK');
      if (c.fk) keys.push('FK');
      if (c.uk && !c.pk) keys.push('UK');
      lines.push(`    ${baseType(c.type)} ${c.name}${keys.length ? ' ' + keys.join(', ') : ''}`);
    }
    lines.push('  }');
  }
  return lines.join('\n');
}

/* ---------- Markdown ---------- */
function markdown() {
  const L = [];
  L.push(`# Dicionário de dados — ${dict.project}`);
  L.push('');
  const schemas = dict.schemas
    ? Object.entries(dict.schemas).map(([k, v]) => `**\`${k}\`** (${v})`).join(', ')
    : `**\`${dict.schema}\`** (${dict.schema_title})`;
  L.push(`> ${dict.subtitle}. Schemas: ${schemas}. Atualizado em ${dict.updated}.`);
  L.push('>');
  L.push('> **Gerado** por `node tools/gen-dictionary.mjs` a partir de [`docs/dictionary/schema.json`](dictionary/schema.json). Não edite este arquivo à mão.');
  L.push('> Viewer interativo: abra [`docs/dictionary/index.html`](dictionary/index.html) no navegador.');
  L.push('> O mesmo JSON vira `COMMENT ON` no banco (repeatable `R__zz_dictionary_comments.sql`): o dicionário aparece no Supabase Studio e em qualquer cliente SQL.');
  L.push('');
  L.push('## Convenção de colunas');
  L.push('');
  L.push('Formato `<prefixo>_<nome>` em inglês, sem o prefixo da tabela. Mesma coluna tem o mesmo nome em todas as tabelas (`nr_company` em company, branch, company_user...), o que permite `join ... using (nr_company)`.');
  L.push('');
  L.push('| Prefixo | Significado |');
  L.push('|---|---|');
  for (const [p, d] of Object.entries(dict.prefixes)) L.push(`| \`${p}\` | ${mdCell(d)} |`);
  L.push('');
  L.push('Colunas de auditoria em **toda** tabela (preenchidas pelo trigger `ad.trg_audit`):');
  L.push('');
  L.push('| Coluna | Tipo | Descrição |');
  L.push('|---|---|---|');
  for (const c of raw.audit_columns) L.push(`| \`${c.name}\` | \`${c.type}\` | ${mdCell(c.description)} |`);
  L.push('');
  L.push('## Visão geral das tabelas');
  L.push('');
  L.push('| Tabela | Título | Descrição |');
  L.push('|---|---|---|');
  for (const t of dict.tables) L.push(`| [\`${qualified(t)}\`](#${anchor(t)}) | ${mdCell(t.title)} | ${mdCell(t.description)} |`);
  L.push('');
  L.push('## Diagrama (ERD)');
  L.push('');
  L.push('```mermaid');
  L.push(mermaidErd());
  L.push('```');
  L.push('');
  L.push('## Tabelas');
  for (const t of dict.tables) {
    L.push('');
    L.push(`### ${qualified(t)}`);
    L.push('');
    L.push(`**${t.title}**`);
    L.push('');
    L.push(t.description);
    L.push('');
    if (t.rls) {
      L.push(`**RLS:** ${t.rls}`);
      L.push('');
    }
    L.push('| Coluna | Tipo | Chave | Nulo | Default | Descrição |');
    L.push('|---|---|---|---|---|---|');
    for (const c of t.columns) {
      const fk = c.fk ? ` → \`${c.fk}\`` : '';
      L.push(`| \`${c.name}\` | \`${c.type}\` | ${keyLabel(c)}${fk} | ${c.nullable === false ? 'NOT NULL' : 'NULL'} | ${c.default ? `\`${mdCell(c.default)}\`` : ''} | ${mdCell(colDescription(c))} |`);
    }
  }
  L.push('');
  L.push('## Functions');
  L.push('');
  L.push('Contrato das RPC: `p_json jsonb` de entrada (sempre com `nr_version`), `jsonb` de saída, erros via `RAISE EXCEPTION` com `ad.fn_message` (`{"Message": "CHAVE", "Parameters": {...}}`). Chamada no Flutter: `supabase.schema(\'<schema>\').rpc(\'<nome>\', params: {\'p_json\': {...}})` (`ad` ou `od`, conforme a assinatura).');
  for (const kind of [['rpc', 'RPC (expostas ao app)'], ['helper', 'Helpers (regras compartilhadas / RLS)'], ['trigger', 'Triggers']]) {
    const fns = dict.functions.filter((f) => f.kind === kind[0]);
    if (!fns.length) continue;
    L.push('');
    L.push(`### ${kind[1]}`);
    L.push('');
    L.push('| Function | Grant | Descrição |');
    L.push('|---|---|---|');
    for (const f of fns) L.push(`| \`${f.signature}\` | ${mdCell(f.grant)} | ${mdCell(f.description)} |`);
  }
  L.push('');
  L.push('## Chaves de mensagem (i18n do app)');
  L.push('');
  L.push('Toda chave abaixo pode chegar em `PostgrestException.message` como JSON. O app traduz a chave e interpola `Parameters`.');
  L.push('');
  L.push('| Chave | Function | Parâmetros |');
  L.push('|---|---|---|');
  const params = {
    VERSION_MISMATCH: 'Function, Database, Application', SESSION_USER_BLOCKED: 'Reason',
    COMPANY_CREATE_CNPJ_INVALID: 'Cnpj', COMPANY_CREATE_CNPJ_IN_USE: 'Cnpj', COMPANY_CREATE_EMAIL_INVALID: 'Email', COMPANY_CREATE_TIMEZONE_INVALID: 'Timezone',
    COMPANY_UPDATE_CNPJ_INVALID: 'Cnpj', COMPANY_UPDATE_CNPJ_IN_USE: 'Cnpj', COMPANY_UPDATE_EMAIL_INVALID: 'Email',
    BRANCH_CREATE_CNPJ_INVALID: 'Cnpj', BRANCH_CREATE_CNPJ_IN_USE: 'Cnpj', BRANCH_CREATE_EMAIL_INVALID: 'Email', BRANCH_CREATE_TIMEZONE_INVALID: 'Timezone',
    BRANCH_UPDATE_CNPJ_INVALID: 'Cnpj', BRANCH_UPDATE_CNPJ_IN_USE: 'Cnpj', BRANCH_UPDATE_EMAIL_INVALID: 'Email', BRANCH_UPDATE_TIMEZONE_INVALID: 'Timezone',
    ACCESS_PROFILE_NAME_IN_USE: 'Name', COMPANY_USER_EMAIL_NOT_FOUND: 'Email', COMPANY_USER_BRANCH_INVALID: 'Branch', COMPANY_USER_PROFILE_INVALID: 'Profile',
    USER_UPDATE_CPF_INVALID: 'Cpf', USER_UPDATE_CPF_IN_USE: 'Cpf',
    PRICING_PARAM_INVALID: 'Field', PRICING_EXPENSE_TYPE_INVALID: 'Expense', PRICING_EXPENSE_AMOUNT_INVALID: 'Expense',
    PRICING_FEE_RATE_INVALID: 'Fee', PRICING_PERCENT_TOO_HIGH: 'Total', MATERIAL_NAME_IN_USE: 'Name',
    PROCEDURE_NAME_IN_USE: 'Name', PROCEDURE_CODE_IN_USE: 'Code', PROCEDURE_VALUE_INVALID: 'Field',
    PROCEDURE_PERCENT_INVALID: 'Field', PROCEDURE_MATERIAL_INVALID: 'Material', PROCEDURE_QUANTITY_INVALID: 'Material',
  };
  const seen = new Map();
  for (const f of dict.functions) for (const e of f.errors || []) {
    if (!seen.has(e)) seen.set(e, []);
    seen.get(e).push(f.name);
  }
  for (const [k, fns] of [...seen.entries()].sort((a, b) => a[0].localeCompare(b[0]))) {
    L.push(`| \`${k}\` | ${fns.map((n) => `\`${n}\``).join(', ')} | ${params[k] || ''} |`);
  }
  L.push('');
  return L.join('\n') + '\n';
}

/* ---------- JS para o viewer ---------- */
function viewerJs() {
  return `/* GERADO por tools/gen-dictionary.mjs a partir de schema.json - nao editar */\nwindow.DICTIONARY = ${JSON.stringify({ ...dict, mermaid: mermaidErd() }, null, 2)};\n`;
}

/* ---------- SQL de comentarios ---------- */
function commentsSql() {
  const L = [];
  L.push('-- GERADO por tools/gen-dictionary.mjs a partir de docs/dictionary/schema.json.');
  L.push('-- Nao editar: altere o JSON e rode flyway/scripts/generate-repeatables.sh.');
  L.push('-- Repeatable Flyway: reaplicado sempre que o dicionario muda (checksum).');
  L.push('');
  for (const t of dict.tables) {
    L.push(`comment on table ${qualified(t)} is ${sqlStr(`${t.title}. ${t.description}`)};`);
    for (const c of t.columns) {
      L.push(`comment on column ${qualified(t)}.${c.name} is ${sqlStr(colDescription(c))};`);
    }
    L.push('');
  }
  for (const f of dict.functions) {
    L.push(`comment on function ${f.signature} is ${sqlStr(f.description)};`);
  }
  L.push('');
  return L.join('\n');
}

/* ---------- main ---------- */
const outputs = [
  { file: MD, content: markdown(), label: 'docs/DATA_DICTIONARY.md' },
  { file: JS, content: viewerJs(), label: 'docs/dictionary/schema.js' },
];
if (SQL_OUT) outputs.push({ file: path.resolve(SQL_OUT), content: commentsSql(), label: SQL_OUT, alwaysWrite: true });

const norm = (s) => s.replace(/\r\n/g, '\n');
let stale = 0;
for (const o of outputs) {
  if (CHECK && !o.alwaysWrite) {
    const cur = fs.existsSync(o.file) ? norm(fs.readFileSync(o.file, 'utf8')) : null;
    if (cur !== norm(o.content)) {
      console.error(`DESATUALIZADO: ${o.label} (rode: node tools/gen-dictionary.mjs)`);
      stale++;
    } else {
      log(`ok: ${o.label}`);
    }
    continue;
  }
  if (CHECK && o.alwaysWrite) continue;
  fs.mkdirSync(path.dirname(o.file), { recursive: true });
  fs.writeFileSync(o.file, o.content, 'utf8');
  log(`gerado: ${o.label}`);
}
if (stale) process.exit(1);
