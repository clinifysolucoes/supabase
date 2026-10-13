# Supabase — login multi-empresa / multi-filial

Núcleo de autenticação e acesso (empresas, filiais, usuários multi-empresa, perfis por filial, log de
sessão) em **Supabase**, no schema `ad`. Base do futuro sistema de odontologia. App: Flutter (web + Android + iOS). Leia o [CLAUDE.md](CLAUDE.md) para as convenções
completas e as regras de segurança.

## Conteúdo

| Pasta | O que é |
|---|---|
| `Scripts/2026/10/` | DDL versionado (schema `ad`, tabelas com RLS, grants) |
| `Procedures/BAD/` | functions RPC, helpers internos, policies e triggers (repeatables Flyway) |
| `Procedures/BPRIVATE/` | helpers de RLS no schema `private`, que não é exposto na API |
| `docs/dictionary/` | dicionário de dados: `schema.json` (fonte) + `index.html` (viewer com ERD e busca) |
| `docs/DATA_DICTIONARY.md` | dicionário em Markdown com ERD Mermaid (renderiza no GitHub) |
| `tests/` | testes SQL de RLS e das functions (rodam em transação com rollback) |
| `flyway/` | configs por ambiente, stubs do Supabase para teste local, scripts |
| `.github/workflows/` | validação em PR e deploy em staging/produção via Flyway |

## Rodar local (Docker + Node)

```bash
./flyway/scripts/validate-standards.sh        # padrões do projeto
node tools/gen-dictionary.mjs                 # regenera DATA_DICTIONARY.md e schema.js
./flyway/scripts/local-db.sh reset            # sobe postgres:16, aplica stubs, flyway migrate, roda tests/*.sql
./flyway/scripts/local-db.sh psql             # psql no banco local
```

Para ver o dicionário, abra `docs/dictionary/index.html` no navegador.

## Deploy num projeto Supabase

1. Crie o projeto (região São Paulo) e, em **Project Settings → API → Exposed schemas**, adicione `ad`.
2. Pegue no botão **Connect** o host do pooler (modo *Session*, porta 5432) e o usuário `postgres.<ref>`.
3. Local:

```bash
export FLYWAY_URL="jdbc:postgresql://<pooler-host>:5432/postgres?sslmode=require"
export FLYWAY_USER="postgres.<project-ref>"
export FLYWAY_PASSWORD="<senha>"
./flyway/scripts/deploy.sh staging info
./flyway/scripts/deploy.sh staging migrate
```

4. CI/CD: os GitHub environments `staging` e `production` guardam a conexão de cada projeto
   (`SUPABASE_DB_HOST`, `SUPABASE_DB_PORT=5432`, `SUPABASE_DB_USER` e o secret `SUPABASE_DB_PASSWORD`).
   Merge em `staging` publica em homologação; merge em `main` publica em produção. Os dois são
   automáticos, sem aprovação manual.

## Fluxo de publicação

```
<dev>_feature_<desc>  --PR-->  staging  --PR (só a partir de staging)-->  main
                                  |                                         |
                         deploy homologação                          deploy produção
```

- `staging` e `main` são protegidas: PR com 1 aprovação, revisão de code owner, conversas resolvidas,
  sem force push e sem deleção. Nada de push direto. A branch default é `staging`.
- PR para `main` só passa se a branch de origem for `staging` e o autor estiver na variável
  `MAIN_PR_ALLOWED_AUTHORS` (workflow `main-author-allowlist.yml`). Hotfix entra em `staging` primeiro.
- Deploy manual (`workflow_dispatch`) só roda a partir da própria branch do environment.

## Functions expostas ao app (`supabase.schema('ad').rpc(...)`)

| Function | Para quê |
|---|---|
| `session_context` | login no app: usuário, empresas → filiais → perfis, bloqueios com motivo, grava log |
| `company_create` | onboarding: empresa + matriz + perfis + vínculo do criador como admin |
| `company_update`, `branch_create`, `branch_update` | cadastro (admin da empresa) |
| `access_profile_save` | perfis de acesso (admin) |
| `company_user_save` | vincular / bloquear / remover usuários e definir filiais x perfis (admin) |
| `user_update` | próprio cadastro (nome, CPF, telefones, avatar) |

Todas recebem `{'p_json': {...}}` com `nr_version` e devolvem `jsonb`. Erros chegam como
`{"Message": "CHAVE", "Parameters": {...}}` — a lista de chaves está no viewer do dicionário.
