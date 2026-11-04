# Supabase — Login multi-empresa / multi-filial (base do futuro sistema de odontologia)

## O que é este projeto

Este repositório contém o **núcleo de autenticação e acesso** (empresas, filiais, usuários multi-empresa,
perfis de acesso por filial, telas/permissões e logs) e o **primeiro módulo de negócio: precificação de
procedimentos** — rodando em **Supabase** (PostgreSQL + Auth + PostgREST). Três schemas:

| Schema | Papel | Exposto na API |
|---|---|---|
| `ad` (Administrative) | empresas, filiais, usuários, perfis, telas, logs | sim |
| `od` (Odontologia) | tabelas e helpers do negócio; hoje: precificação (materiais, procedimentos, parâmetros) e pacientes (ficha + notas) | **não** (o app só chega por RPC em `ad`) |
| `private` | helpers de RLS | **nunca** |

**No futuro** o schema `od` recebe agenda, pacientes, prontuário, orçamentos e financeiro, sempre **em cima**
desta base: toda tabela de negócio tem `(nr_company, nr_branch)`, policy RLS baseada em
`private.fn_my_branches()` e escrita só por RPC que checa a permissão por tela (`ad.fn_screen_permission`).
**Toda RPC exposta ao app fica em `ad`** (único schema na API): assim nenhum módulo novo exige mexer em
"Exposed schemas" no dashboard. O schema de negócio guarda tabelas, policies e helpers `fn_*`.

O app será um único código **Flutter** (web + Android + iOS) usando `supabase_flutter`.
As telas ainda não existem neste repo — aqui é só banco.

Objetos principais:

| Objeto | Papel |
|---|---|
| `ad.company` | empresa (tenant) |
| `ad.branch` | filial; PK composta `(nr_company, nr_branch)`, sequencial por empresa |
| `ad.access_profile` | perfil de acesso; `it_level` 100 = administrador da empresa |
| `ad.company_user` | usuário x empresa (multi-empresa) |
| `ad.branch_user_profile` | usuário x filial x perfil (multi-filial); é o que dá acesso |
| `ad.app_user` | usuário; senha/token/2FA são do Supabase Auth (`auth.users`) |
| `ad.access_log` | log de sessão, gravado por `session_context` |
| `ad.screen` | catálogo global de telas: uuid fixo (chave da permissão), código (`vc_code`) e nome bonito |
| `ad.access_profile_screen` | permissão do perfil por tela: linha = ler; `id_create`, `id_update` |
| `ad.event_log` / `ad.fn_event_log` | log de atividades (o que aconteceu, em qual tela); gravado pelas RPCs |
| `ad.screen_list` / `ad.event_log_list` | catálogo de telas; pesquisa do log de atividades |
| `ad.user_create_check` + Edge Function `user-create` | cadastro de usuário pela empresa (cria no Auth com service_role e vincula) |
| `ad.session_context(jsonb)` | login no app: usuário, empresas → filiais → perfis → **permissions** (telas × ler/criar/alterar), bloqueios |
| `ad.company_create` / `ad.company_update` | empresa (onboarding e cadastro) |
| `ad.company_user_save` / `ad.user_update` | usuários da empresa / próprio cadastro |
| `ad.fn_check_version` | versão do contrato (`nr_version` dentro do `p_json`) |
| `ad.fn_message` | erro i18n `{"Message": "CHAVE", "Parameters": {...}}` |
| `ad.fn_screen_permission` | `{id_read, id_create, id_update}` do usuário numa tela × filial; toda RPC de negócio usa |
| `private.fn_*` | helpers de RLS (`fn_current_user_nr`, `fn_my_branches`, `fn_my_companies`, `fn_is_company_admin`, `fn_is_admin_of_user`), fora da API |
| `od.pricing_param` / `od.clinic_expense` / `od.pricing_fee` | parâmetros de precificação da filial, despesas (custo mensal → estrutura/hora) e taxas adicionais |
| `od.material` / `od.procedure` / `od.procedure_material` | catálogo de materiais (custo por unidade de uso), procedimentos e materiais × quantidade |
| `ad.pricing_param_get` / `ad.pricing_param_save` | aba Parâmetros da tela Precificação |
| `ad.material_list` / `ad.material_save` / `ad.procedure_list` / `ad.procedure_save` | CRUD da tela; `procedure_list` devolve o preço calculado |
| `od.fn_pricing_calc` / `od.fn_pricing_context` | fórmula do preço (única fonte) e resumo da filial |
| `od.patient` / `od.patient_note` | ficha do paciente (cadastro, contato/endereço, complementares, alerta de retorno) e notas gerais |
| `ad.patient_list` / `ad.patient_get` / `ad.patient_save` / `ad.patient_note_save` | tela Pacientes: busca paginada, ficha completa, cadastro/alteração parcial, notas |
| Edge Function `material-price-lookup` | pesquisa de preço de mercado de um material (Claude + web search; secret `ANTHROPIC_API_KEY`) |

---

## 🌿 Branch obrigatória — pré-flight antes de qualquer edição

**Regra absoluta**: antes de qualquer `Write`, `Edit` ou `Bash` que altere estado (incl. `git commit`,
`mv`, `rm`, deploy), a Claude DEVE fazer **dois** checks na branch atual:

1. **Nome** bate com `^[a-z0-9.-]+_(feature|bugfix|hotfix)_.+$` (`git rev-parse --abbrev-ref HEAD`).
2. **Origem** é `staging` (não `main`):

```bash
git fetch origin --quiet
BASE_STAGING=$(git merge-base HEAD origin/staging)
BASE_MAIN=$(git merge-base HEAD origin/main)
if git merge-base --is-ancestor "$BASE_MAIN" "$BASE_STAGING"; then echo "OK"; else echo "BLOQUEADO: forkada de main"; fi
```

Se qualquer um falhar: **PARA**, mostra a branch e o motivo, pergunta tipo/nome/descrição e sugere
`git fetch origin && git checkout -b <dev>_feature_<desc> origin/staging`. Só edita depois que o dev
rodar (ou autorizar rodar). Enquanto o repo ainda não tiver `origin/staging` (bootstrap inicial), a
Claude avisa isso explicitamente e pede ao dev para criar `staging` a partir de `main` antes de continuar.

| Branch | Papel | Forkar dela? |
|---|---|---|
| `main` | Produção (projeto Supabase prod) | ❌ |
| `staging` | Homologação (projeto Supabase staging) | ✅ sempre |

Proibido: trabalhar em `main`/`staging`; branches criadas pela Claude sem confirmação; **worktrees**
(nunca `git worktree` / `.claude/worktrees`: dev e Claude trabalham lado a lado na mesma pasta).
Permitido em branch inválida: leitura, `git status/log/diff`, planejamento.

### 🚀 Publicação — só por PR, e `main` só recebe `staging`

As duas branches principais são protegidas no GitHub: PR obrigatório com 1 aprovação, revisão de
code owner (`.github/CODEOWNERS`), conversas resolvidas, sem force push e sem deleção. Ninguém faz
push direto nelas, nem a Claude. A branch default do repositório é `staging`.

| Para | Vem de | Checks no PR | No merge |
|---|---|---|---|
| `staging` | `<dev>_(feature|bugfix|hotfix)_<desc>` | `sql-validate.yml` (padrões + Flyway em Postgres efêmero + testes) | `sql-deploy-staging.yml` publica no projeto Supabase de **homologação** (environment `staging`) |
| `main` | **somente `staging`** | `main-author-allowlist.yml`: autor na variável `MAIN_PR_ALLOWED_AUTHORS` **e** origem = `staging` (os dois são required status checks) | `sql-deploy-production.yml` publica no projeto Supabase de **produção** automaticamente (environment `production`, só a partir de `main`, sem aprovação manual) |

- Hotfix nunca vai direto para `main`: entra em `staging` por PR e depois `staging` é promovida.
- Fluxo da Claude: branch a partir de `origin/staging` → commits → `git push -u origin <branch>` →
  `gh pr create --base staging`. A Claude **nunca** abre PR para `main`; a promoção
  `staging → main` é decisão do dev.
- Cada environment do GitHub guarda a conexão do seu projeto Supabase: vars `SUPABASE_DB_HOST`,
  `SUPABASE_DB_PORT` (5432), `SUPABASE_DB_USER` (`postgres.<ref>`) e o secret `SUPABASE_DB_PASSWORD`.
  Deploy manual (`workflow_dispatch`) só roda a partir da própria branch do environment.

---

## 📝 Encoding — UTF-8 sem BOM

O Supabase é `UTF8`. **Todos** os arquivos (`.pgs`, `.sql`, `.md`, `.json`) são UTF-8 **sem BOM**.
Não existe conversão para Latin1 em lugar nenhum. O `generate-repeatables.sh` rejeita BOM e o
`validate-standards.sh` rejeita UTF-8 inválido. Acentos em descrições/dados são bem-vindos; em
identificadores (tabela, coluna, function) só `[a-z0-9_]`.

---

## 📚 Dicionário de dados obrigatório — mesma mudança, nunca depois

**Regra absoluta**: toda alteração estrutural (tabela, coluna, índice, function, policy, trigger,
valor novo de `it_*`) atualiza `docs/dictionary/schema.json` **na mesma mudança** e roda
`node tools/gen-dictionary.mjs`. A Claude não entrega DDL ou `.pgs` sem a entrada correspondente
no JSON, com descrição em português.

- **Tabela nova**: bloco em `tables[]` com `title`, `description`, `rls` e todas as colunas
  (as de auditoria são adicionadas automaticamente). Relação nova em `relations[]` para o ERD.
  Tabela fora de `ad` leva `"schema": "od"` no bloco (o gerador assume `ad` quando ausente).
- **Coluna nova**: entrada em `columns[]` com `type`, `nullable`, `default`, `description`
  e `values` quando for `it_*`.
- **Function nova ou contrato alterado**: `functions[]` com `signature`, `kind` (`rpc`/`helper`/`trigger`),
  `grant`, `description` e `errors[]` (todas as chaves de `ad.fn_message`).
- **Coluna/function removida ou renomeada**: remover/renomear no JSON na mesma mudança.
- Nunca editar `docs/DATA_DICTIONARY.md` nem `docs/dictionary/schema.js` à mão: são gerados.

Garantias mecânicas: a CI falha se `DATA_DICTIONARY.md`/`schema.js` estiverem desatualizados
(`node tools/gen-dictionary.mjs --check`) e `tests/02_dictionary.sql` falha se existir tabela, coluna
ou function no schema `ad` sem comentário, ou seja, sem entrada no JSON.

---

## Estrutura do repositório

```
Supabase/
├── Procedures/BAD/<nome>.pgs      # REPEATABLES do schema ad: functions, triggers e RLS policies (Flyway reaplica se o checksum mudar)
├── Procedures/BOD/<nome>.pgs      # REPEATABLES do schema od (negócio): fn_pricing_*, rls_od_policies, trg_od_audit (RPCs ficam em BAD)
├── Procedures/BPRIVATE/fn_*.pgs   # helpers de RLS no schema private (fora da API)
├── Scripts/YYYY/MM/V<YYYYMMDD>_<HHMM>__<desc>.sql   # VERSIONADAS: DDL (uma vez, em ordem)
├── docs/
│   ├── dictionary/schema.json     # DICIONÁRIO DE DADOS - source of truth (edite aqui)
│   ├── dictionary/index.html      # viewer interativo (ERD + busca) - abre direto no navegador
│   ├── dictionary/schema.js       # gerado
│   └── DATA_DICTIONARY.md         # gerado (Mermaid ERD renderiza no GitHub)
├── tools/gen-dictionary.mjs       # gera .md/.js e o R__zz_dictionary_comments.sql (COMMENT ON)
├── tests/*.sql                    # testes de RLS/functions (psql, uma transação, rollback)
├── flyway/
│   ├── conf/flyway.{local,staging,prod}.conf
│   ├── callbacks/afterMigrate__*.sql  # SQL idempotente que roda depois de todo migrate (ex.: trancar flyway_schema_history)
│   ├── init/00-supabase-stubs.sql # roles + schema auth para Postgres puro (local/CI). NUNCA no Supabase real
│   └── scripts/{generate-repeatables,validate-standards,deploy,local-db}.sh
└── .github/workflows/{sql-validate,sql-deploy-staging,sql-deploy-production}.yml
```

### Repeatables (`Procedures/BAD/*.pgs`, `Procedures/BOD/*.pgs`, `Procedures/BPRIVATE/*.pgs`)

- Nome do arquivo = nome do objeto, `snake_case` minúsculo, **único entre todas as pastas** (o Flyway vê
  só `R__<nome>`). Um objeto por arquivo (policies de todas as tabelas de um schema ficam juntas:
  `rls_policies.pgs` para `ad`, `rls_od_policies.pgs` para `od`; triggers de auditoria em `trg_audit.pgs`
  e `trg_od_audit.pgs`, que reusa `ad.trg_audit()`).
- **Ordem alfabética importa**: o Flyway aplica repeatables pela descrição. Convenção de prefixos que já
  garante a ordem certa na primeira carga: `<entidade>_<ação>` (RPC) → `fn_*` (helpers) → `rls_*` →
  `session_context` → `trg_*` → `zz_*` (gerados). Policies referenciam `fn_*` em tempo de criação, por
  isso `fn_` < `rls_`. Helpers que chamam outros helpers em `language sql` precisam vir depois deles no
  alfabeto; na dúvida use `plpgsql` (resolve em runtime).
- Todo `.pgs` tem o header corporativo (`Project`, `Schema`, `Object`, `UsedBy`, `Programmer`, `Date`,
  `Change`) e a seção `Description` com Input/Output/Errors.
- Prefixos: `fn_` = helper interno (em `ad`/`od`, sem grant) ou de RLS (em `private`, `EXECUTE` para
  `authenticated`), nunca chamado pelo app; sem prefixo = RPC exposta ao app;
  `trg_` = trigger function; `rls_` = policies.

### Versionadas (`Scripts/YYYY/MM/V<YYYYMMDD>_<HHMM>__<desc>.sql`)

Regra estrita: subpasta `YYYY/MM` obrigatória e igual ao timestamp do nome;
descrição `[a-z0-9_]+`. Só DDL de tabelas/índices/grants/seeds. **Toda `CREATE TABLE` vem com
`ENABLE ROW LEVEL SECURITY` no mesmo arquivo** (o validador exige) e ganha um trigger `<tabela>_audit`
em `trg_audit.pgs` e uma entrada em `schema.json`.
Objeto fora do schema `ad` (caso único: `public.flyway_schema_history`, trancada pelo callback
`flyway/callbacks/afterMigrate__lockdown_flyway_history.sql`) fica fora do dicionário e é documentado no
header do próprio arquivo. **DDL na `flyway_schema_history` nunca vai em migration**: o Flyway segura um
lock nela numa segunda conexão durante o migrate e o `ALTER TABLE` trava; use callback `afterMigrate`.

### Dicionário de dados (sem Excel)

`docs/dictionary/schema.json` é a única fonte. Depois de editar:

```bash
node tools/gen-dictionary.mjs
```

Isso regenera `DATA_DICTIONARY.md` e `schema.js` (ambos commitados; a CI falha se estiverem
desatualizados). No deploy, o mesmo JSON vira `COMMENT ON table/column/function`, então o dicionário
aparece no Supabase Studio. O teste `tests/02_dictionary.sql` falha se existir tabela, coluna ou function
sem comentário — ou seja, **sem entrada no JSON**. Colunas de auditoria são adicionadas automaticamente.

---

## Convenções de nomenclatura

### Tabelas

Inglês, singular, `snake_case`, no schema `ad` (administrativo) ou `od` (odontologia). Chave de negócio
composta: filial é `(nr_company, nr_branch)`, perfil é `(nr_company, nr_profile)`,
numerados sequencialmente **por empresa** (a function trava a empresa com `FOR UPDATE` antes do `max+1`).

### Colunas `<prefixo>_<nome>` — sem prefixo de tabela

| Prefixo | Tipo | Exemplo |
|---|---|---|
| `nr_` | numérico / id (`bigint`, `smallint`) | `nr_company`, `nr_branch` |
| `vc_` | texto | `vc_name`, `vc_cnpj` |
| `it_` | indicador/tipo codificado (`smallint` + lista de valores) | `it_status`, `it_size` |
| `id_` | boolean | `id_blocked`, `id_main` |
| `dt_` | `date` | |
| `dh_` | `timestamptz` | `dh_created`, `dh_last_login` |
| `qt_` / `vl_` / `pc_` | quantidade / valor / percentual | |
| `uu_` | uuid (novo) | `uu_auth` |

A mesma coluna tem o mesmo nome em todas as tabelas (`nr_company` em todas), o que permite
`join using (nr_company)`. Auditoria em **toda** tabela: `nr_operator`, `dh_created`, `dh_updated`,
preenchidas pelo trigger `ad.trg_audit` (não precisa setar nas functions).

### Status (`it_status`) e níveis

| Coluna | Valores |
|---|---|
| `company.it_status`, `branch.it_status`, `access_profile.it_status` | 1 ativo · 90 inativo |
| `app_user.it_status`, `company_user.it_status` | 1 ativo · 80 bloqueado · 90 inativo |
| `*.id_blocked` | bloqueio pela plataforma (motivo em `vc_block_reason`) |
| `access_profile.it_level` | 0..100; **100 = administrador da empresa** |
| `app_user.it_level` | 0 normal · 100 administrador da plataforma (só service_role altera) |

---

## 🔒 Segurança — regras invioláveis

1. **RLS ligado em toda tabela**, sempre, inclusive nas futuras. Tabela sem policy = ninguém lê.
2. **`anon` não tem nada**: sem `USAGE` no schema `ad`, sem policy, sem `EXECUTE`. Nunca `grant ... to anon`
   nem `to public` (o validador bloqueia).
3. **Nenhuma policy de INSERT/UPDATE/DELETE** para `authenticated`. Toda escrita passa por function
   `SECURITY DEFINER` que valida tudo. Leitura é via RLS `FOR SELECT`.
4. **Toda function `SECURITY DEFINER` tem `SET search_path = ''`** e nomes totalmente qualificados
   (`ad.`, `auth.`, `pg_catalog.`). Lint do Supabase e proteção contra sequestro de search_path.
5. **Least privilege explícito** em cada `.pgs`: `revoke all on function ... from public, anon` e então
   `grant execute ... to authenticated` só nas RPC. Helpers internos ficam sem grant.
6. **`service_role` nunca entra no app Flutter**. Só em Edge Functions e CI. A chave `anon` é pública por
   natureza: toda a segurança é a RLS + as functions.
7. **Regra de acesso central = `private.fn_my_branches()`**. Toda tabela de negócio futura usa
   `using ((nr_company, nr_branch) in (select nr_company, nr_branch from private.fn_my_branches()))`.
   Nunca reimplemente a regra em outra policy. Os helpers de RLS ficam no schema `private`
   (`Procedures/BPRIVATE/`): as policies rodam como o usuário, então `authenticated` precisa de `EXECUTE`
   neles, e em `ad` eles apareceriam em `/rest/v1/rpc/` (lint 0029 da Supabase). `private` nunca entra em
   Exposed schemas. Hoje: `Procedures/BOD/rls_od_policies.pgs` (uma policy por tabela de `od`).
8. **Permissão por tela**: `ad.screen` é o catálogo (uuid fixo por tela, seed na versionada);
   `ad.access_profile_screen` diz o que cada perfil pode (ler / criar / alterar). Perfil nível 100
   ignora a tabela. `session_context` entrega as permissões efetivas por filial e o app esconde o que
   o usuário não pode. **Tela nova = linha nova em `ad.screen`** (versionada) com uuid fixo.
   Toda RPC que altera dados grava `ad.fn_event_log(...)` com o código da tela. RPC de negócio (em `ad`,
   sobre tabelas de `od`) checa `ad.fn_screen_permission(nr_company, nr_branch, 'TELA')`: `id_read` para listar, `id_create`
   para `vc_action = 'I'`, `id_update` para `'U'` (nunca `fn_is_company_admin`: admin já tem tudo).
8b. **Anti-lockout**: operações que mexem em perfis/vínculos terminam com `ad.fn_company_has_admin` e
   desfazem a transação se a empresa ficaria sem administrador ativo.
9. **Situação e bloqueio** (`it_status`, `id_blocked`) de empresa/filial/usuário são operações de
   plataforma (service_role). Admin de empresa não altera isso pelo app.
10. Mensagens de erro nunca vazam dados de outra empresa: as RPC checam `fn_is_company_admin` antes de
    dizer se algo existe.

---

## Padrão das functions RPC

```sql
create or replace function ad.<entidade>_<acao>(p_json jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  _nr_user bigint;
begin
  perform ad.fn_check_version((p_json ->> 'nr_version')::integer, 1, '<entidade>_<acao>');
  _nr_user := private.fn_current_user_nr();                      -- NULL = sem sessão ou usuário inativo
  if _nr_user is null or not private.fn_is_company_admin((p_json ->> 'nr_company')::bigint) then
    raise exception '%', ad.fn_message('<ENTIDADE>_<ACAO>_FORBIDDEN');
  end if;
  -- consistências: raise exception '%', ad.fn_message('<CHAVE>', jsonb_build_object('Campo', valor));
  -- update parcial: campo = case when p_json ? 'x' then <novo> else t.x end
  return jsonb_build_object(...);
end;
$$;

revoke all on function ad.<entidade>_<acao>(jsonb) from public, anon;
grant execute on function ad.<entidade>_<acao>(jsonb) to authenticated;
```

- Entrada: sempre `p_json jsonb` com `nr_version`. Saída: `jsonb`.
- Erros: `RAISE EXCEPTION '%', ad.fn_message('CHAVE', params)`. O Flutter faz `jsonDecode` de
  `PostgrestException.message`. Chaves: `<FUNCTION>_<MOTIVO>`, documentadas no `.pgs` e em `schema.json`
  (`functions[].errors`) — o viewer lista todas para o arquivo de i18n.
- Contrato mudou de forma incompatível → incrementa o número em `fn_check_version` e no app.
- Update parcial: chave presente no JSON atualiza (null limpa), chave ausente não mexe.
- Registre a function em `docs/dictionary/schema.json` (`functions[]`), senão o teste do dicionário falha.

---

## Pacientes (schema `od`) — ficha

Tela `PATIENTS` (uuid `0d6a1f3e-1b2c-4d5e-8f90-000000000006`). `od.patient` é a ficha completa, inspirada nas
fichas clássicas de clínica: dados cadastrais, contato/endereço, complementares (prontuário, plano, filiação,
representante legal) e alerta de retorno; `od.patient_note` são as notas gerais (exclusão lógica).
Regras que valem para todo cadastro de pessoa daqui em diante:

- Documentos, telefones e CEP são gravados **só com dígitos** (a máscara é do app); e-mail minúsculo; UF maiúscula.
- `patient_save` normaliza antes de validar e faz update parcial (chave presente altera, `null` limpa, ausente mantém),
  mesclando o JSON na linha atual com `jsonb_populate_record`. CPF validado por `ad.fn_cpf_is_valid` e único na filial.
- A busca (`patient_list`) é por nome/apelido/e-mail (ILIKE, `%` como curinga) e, se o texto tiver dígitos, por CPF,
  telefone e número do prontuário. Sempre paginada.
- O `event_log` de pacientes não guarda dados pessoais: só nome, situação e quais campos mudaram.

## Precificação (schema `od`) — modelo e fórmula

Consolidado das planilhas da clínica (custos → estrutura por hora → preço por procedimento), corrigindo
o que estava errado nelas (comissão/cartão/lucro/IR somados "por fora" do custo, colunas vazias, `#REF!`).

- **Custo mensal** = despesas fixas + variáveis + eventuais anuais ÷ 12 + publicidade (`od.clinic_expense`).
- **Estrutura por hora** = custo mensal ÷ (salas × horas/semana × semanas/mês × ocupação) (`od.pricing_param`),
  ou o valor manual `vl_structure_hour_manual` quando preenchido.
- **Custo direto** = materiais (`qt_used` × custo unitário; unitário = preço da embalagem ÷ (rendimento × (1 − perda)))
  + outros materiais + laboratório + minutos/60 × estrutura/hora + minutos/60 × hora clínica do profissional.
- **Percentuais sobre o preço**: cartão, comissão (padrão da filial ou do procedimento), taxas adicionais ativas
  (`od.pricing_fee`: ISS, inadimplência, antecipação...), lucro desejado (padrão ou do procedimento) e IR:
  - **PJ** (`it_tax_regime = 2`, IR sobre o faturamento): `preço = custo ÷ (1 − cartão − comissão − taxas − IR − lucro)`
  - **PF** (`it_tax_regime = 1`, IR sobre o lucro): `preço = (1 − IR) × custo ÷ ((1 − IR) × (1 − cartão − comissão − taxas) − lucro)`
  - **Preço mínimo** = mesma fórmula com lucro zero. Soma ≥ 100% → `PRICING_PERCENT_TOO_HIGH`.
- A fórmula vive em `od.fn_pricing_calc` (e numa cópia testada no app, `PricingCalculator`, para a simulação ao
  vivo). `procedure_list` sempre recalcula: o preço nunca é gravado. Percentuais em pontos (4 = 4%).
- Preço de mercado dos materiais: Edge Function `material-price-lookup` (o usuário escolhe a oferta;
  `material_save` grava `it_price_source = 2` e a loja/URL).
- RPCs em `ad` (`ad.pricing_param_get/save`, `ad.material_list/save`, `ad.procedure_list/save`); tabelas,
  policies e helpers em `od`. `od` **não** entra em Exposed schemas.

## Flyway — fluxo de mudança

| Caso | O que fazer |
|---|---|
| Nova function / policy / trigger | cria `Procedures/BAD/<nome>.pgs` + entrada em `schema.json` |
| Alterou function | edita o `.pgs`; Flyway reaplica (checksum) |
| Nova tabela / coluna | `Scripts/YYYY/MM/V<ts>__<desc>.sql` com RLS + trigger em `trg_audit.pgs` (`ad`) ou `trg_od_audit.pgs` (`od`) + policy em `rls_policies.pgs` / `rls_od_policies.pgs` + `schema.json` |
| Alterou descrição | só `schema.json` + `node tools/gen-dictionary.mjs` (o COMMENT ON é repeatable) |

Antes de abrir PR, rode o ciclo completo local (precisa de Docker e Node):

```bash
./flyway/scripts/validate-standards.sh
node tools/gen-dictionary.mjs
./flyway/scripts/local-db.sh reset      # postgres:16 + stubs + flyway migrate + tests/*.sql
```

A CI (`sql-validate.yml`) faz exatamente isso e ainda roda um segundo `migrate` que precisa dizer
*No migration necessary*. Deploy: push em `staging` → `sql-deploy-staging.yml` (info + repair + migrate);
push em `main` → `sql-deploy-production.yml` (info + migrate, automático; sem repair).

### Conexão do Flyway com o Supabase

Sempre pelo **pooler em modo session, porta 5432**, usuário `postgres.<project-ref>`, `sslmode=require`.
Nunca a 6543 (transaction mode, sem prepared statements) nem o host direto (IPv6). GitHub environments
`staging` e `production`: vars `SUPABASE_DB_HOST`, `SUPABASE_DB_PORT`, `SUPABASE_DB_USER` e secret
`SUPABASE_DB_PASSWORD`. `flyway clean` está desabilitado em todos os ambientes.

### 🔌 MCP da Supabase (`.mcp.json`, escopo do projeto)

O repo versiona `.mcp.json` com o servidor `supabase` (HTTP, `project_ref` do projeto de
**desenvolvimento**). Cada dev autentica uma vez com `/mcp` num terminal `claude` aberto nesta pasta
(OAuth no navegador). Regras de uso pela Claude:

- **Schema só pelo Flyway.** Nunca `apply_migration` nem `execute_sql` com DDL (create/alter/drop,
  policy, function, grant) em nenhum ambiente: isso cria objetos fora da `flyway_schema_history` e o
  próximo `migrate` diverge. Mudança de estrutura = arquivo em `Scripts/` ou `Procedures/` + PR.
- **MCP é para ler e diagnosticar**: `list_tables`, `execute_sql` de consulta, logs, advisors de
  segurança/performance, docs, Edge Functions. `execute_sql` de escrita só para dados de teste no
  projeto de desenvolvimento, nunca em produção.
- **Produção**: se um dia for conectado, usar `read_only=true` na URL e um `project_ref` separado.
- Ao abrir o projeto no Supabase pela primeira vez, conferir com o MCP os advisors (nenhum aviso de
  RLS desligada ou `search_path mutable`) e se `ad` está em Exposed schemas (`od` e `private` ficam fora).

### Edge Functions (`supabase/functions/<nome>/index.ts`)

Código versionado aqui; deploy pelo workflow `edge-deploy.yml` (push em `staging`/`main`, precisa do
secret `SUPABASE_ACCESS_TOKEN` e da var `SUPABASE_PROJECT_REF` no environment). Enquanto o token não
existir, o deploy em **homologação** pode ser feito pelo MCP (`deploy_edge_function`) com o mesmo
conteúdo do arquivo; nunca em produção. Edge Function é o único lugar onde `service_role` é usado, e
sempre depois de validar o chamador por uma RPC (ex.: `user_create_check`).

| Function | Faz | Secrets (Edge Functions → Secrets) |
|---|---|---|
| `user-create` | cria a conta no Auth (service_role) e vincula à empresa | nenhum extra |
| `material-price-lookup` | pesquisa preço de mercado de um material (Claude + web search); valida acesso com `ad.pricing_param_get`; não grava nada | `ANTHROPIC_API_KEY` (obrigatório), `PRICE_LOOKUP_MODEL` (opcional) |

### Setup do projeto Supabase (uma vez por ambiente)

1. Dashboard → **Project Settings → API → Exposed schemas**: adicionar `ad` (senão o PostgREST não enxerga).
   Nunca `private` nem `od`: o app só chega aos dados de negócio por RPC em `ad`.
2. **Authentication → URL Configuration**: Site URL e Redirect URLs do app.
3. Rodar o workflow de deploy (ou `./flyway/scripts/deploy.sh staging` com as env vars).
4. Conferir **Database → Advisors**: não pode haver aviso de RLS desligada nem `search_path mutable`.

---

## Flutter — como o app usa

```dart
await Supabase.initialize(url: SUPABASE_URL, anonKey: SUPABASE_ANON_KEY);
final sb = Supabase.instance.client;

// cadastro: o nome vai em user_metadata e o trigger cria ad.app_user
await sb.auth.signUp(email: email, password: senha, data: {'name': nome});

// login no app = session_context (empresas/filiais/perfis + log)
final ctx = await sb.schema('ad').rpc('session_context', params: {
  'p_json': {'nr_version': 1, 'it_app': 2, 'vc_app_version': '1.0.0'},
});
// ctx['companies'] vazio e ctx['blocked'] vazio -> tela "criar empresa"
final r = await sb.schema('ad').rpc('company_create', params: {
  'p_json': {'nr_version': 1, 'vc_name': 'Clínica Sorriso', 'vc_cnpj': '11.222.333/0001-81'},
});

// leitura direta: RLS filtra sozinha
final filiais = await sb.schema('ad').from('branch').select('nr_company, nr_branch, vc_name');

// erro: PostgrestException.message e um JSON {"Message": "CHAVE", "Parameters": {...}}
```

---

## O que NÃO está neste projeto (próximos passos conhecidos)

- Telas Flutter (login, criar empresa, escolher filial).
- Transações/telas e permissão por tela: hoje o acesso é só por nível do perfil.
- Convite por e-mail (`auth.admin.inviteUserByEmail`): hoje a Edge Function `user-create` cria a conta
  com senha inicial definida pelo administrador.
- Operações de plataforma (bloquear empresa, inativar usuário): fazer por service_role ou futura RPC
  restrita a `app_user.it_level = 100`.
- Empresa ativa no JWT (Auth Hook de custom claims) para policies sem subquery — só se a performance pedir.
- Próximos módulos do schema `od`: agenda, prontuário/anamnese/odontograma (em cima de `od.patient`), orçamentos (usando a precificação), financeiro.
- Storage para avatar/logo.
- Deploy da Edge Function `material-price-lookup` em produção (depende do secret `SUPABASE_ACCESS_TOKEN`
  do workflow e do `ANTHROPIC_API_KEY` no projeto).
