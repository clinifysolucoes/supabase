# Flyway — controle de migrations (staging + main)

Pontos de atenção:

1. **Encoding UTF-8** (Supabase é UTF8): nenhuma conversão de encoding. BOM é rejeitado.
2. **Repeatables incluem RLS policies e triggers**, além das functions. Ordem alfabética:
   `fn_*` → `rls_*` → `trg_*` → `zz_*` (gerados).
3. **Dicionário vira `COMMENT ON`**: `generate-repeatables.sh` chama `tools/gen-dictionary.mjs` e grava
   `flyway/repeatable/R__zz_dictionary_comments.sql` (gitignored, como os demais gerados).

## Arquivos

| Arquivo | Uso |
|---|---|
| `conf/flyway.local.conf` | Postgres local (Docker) ou `supabase start` (porta 54322) |
| `conf/flyway.staging.conf` / `flyway.prod.conf` | projetos Supabase; conexão só por env vars |
| `callbacks/afterMigrate__lockdown_flyway_history.sql` | roda depois de todo `migrate`: revoga `anon`/`authenticated` e liga RLS na `flyway_schema_history` (o Supabase a expõe em `public`) |
| `init/00-supabase-stubs.sql` | roles + `auth.users` + `auth.uid()` para Postgres puro (local/CI). **Nunca** num Supabase real |
| `scripts/generate-repeatables.sh` | gera `flyway/repeatable/` e `flyway/staged-scripts/` |
| `scripts/validate-standards.sh` | naming, header, UTF-8, RLS em toda tabela, least privilege |
| `scripts/deploy.sh <env> [cmd]` | Flyway CLI ou `redgate/flyway:11` via Docker |
| `scripts/local-db.sh <up\|migrate\|test\|reset\|psql\|down>` | ciclo local completo |

## Conexão com o Supabase

```
FLYWAY_URL=jdbc:postgresql://<pooler-host>:5432/postgres?sslmode=require
FLYWAY_USER=postgres.<project-ref>
FLYWAY_PASSWORD=<senha>
```

Pooler em modo **session** (5432). Runner do GitHub é IPv4 e o host direto `db.<ref>.supabase.co`
é IPv6. A 6543 (transaction mode) não suporta prepared statements e o Flyway falha.

## Baseline

Projeto novo: `baselineOnMigrate=true` com `baselineVersion=0`. Na primeira execução o Flyway cria a
`flyway_schema_history` em `public` e aplica tudo (todas as versões são maiores que 0).

## Troubleshooting

- *Found non-empty schema(s) "public" but no schema history table* → esperado em Supabase; o baseline 0
  resolve. Se aparecer, confira se a `.conf` certa foi usada.
- *Detected applied migration not resolved locally* → uma repeatable foi apagada do repo. Em staging o
  push roda `repair` automaticamente; em prod rode o workflow com `command=repair` depois de revisar.
- *Validate failed: Migration checksum mismatch* numa **versionada** → alguém editou um `V*.sql` já
  aplicado. Nunca edite: crie outra versionada.
- *migrate travado para sempre* numa migration que faz `ALTER TABLE` na `flyway_schema_history` → o Flyway
  segura `AccessShareLock` nela numa segunda conexão durante o migrate. DDL nessa tabela só em callback
  `afterMigrate` (`flyway/callbacks/`).
- *permission denied for schema ad* vindo do app → `ad` não está em Exposed schemas, ou a chamada veio
  como `anon` (sem sessão).
