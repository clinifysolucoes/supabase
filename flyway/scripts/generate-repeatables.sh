#!/usr/bin/env bash
# generate-repeatables.sh
#
# Gera as duas pastas que o Flyway consome (ambas gitignored - source of truth
# fica em Procedures/ e Scripts/, commitados):
#
#   1. flyway/repeatable/R__<nome>.sql
#      Repeatables a partir de Procedures/**/*.pgs (functions, triggers, RLS
#      policies). O prefixo R__ e exigencia do Flyway. Repeatables sao aplicadas
#      em ORDEM ALFABETICA do nome: fn_* antes de rls_* antes de trg_*.
#      + R__zz_dictionary_comments.sql gerado do dicionario de dados
#        (docs/dictionary/schema.json) -> COMMENT ON table/column/function.
#        O "zz" garante que roda por ultimo.
#
#   2. flyway/staged-scripts/YYYY/MM/V*.sql
#      Copia 1-pra-1 de Scripts/, mesma estrutura YYYY/MM.
#
# Encoding: Supabase e UTF-8. Os arquivos sao copiados byte a byte; BOM e
# rejeitado (o Flyway leria o BOM como parte do primeiro statement).
#
# Uso: ./flyway/scripts/generate-repeatables.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT_DIR="$REPO_ROOT/flyway/repeatable"
STAGED_DIR="$REPO_ROOT/flyway/staged-scripts"

if ! command -v node >/dev/null 2>&1; then
  echo "ERRO: node nao encontrado no PATH (necessario para gerar os comentarios do dicionario)." >&2
  exit 1
fi

rm -rf "$OUT_DIR" "$STAGED_DIR"
mkdir -p "$OUT_DIR" "$STAGED_DIR"

has_bom() {
  [ "$(head -c 3 "$1" | od -An -tx1 | tr -d ' \n')" = "efbbbf" ]
}

# === 1. Repeatables (Procedures/**/*.pgs) ===
COUNT=0
declare -A SEEN=()
while IFS= read -r PGS; do
  NAME="$(basename "$PGS" .pgs)"
  if [ -n "${SEEN[$NAME]:-}" ]; then
    echo "ERRO: nome duplicado de repeatable: $NAME ($PGS e ${SEEN[$NAME]})" >&2
    exit 1
  fi
  SEEN[$NAME]="$PGS"
  if has_bom "$PGS"; then
    echo "ERRO: $PGS tem BOM UTF-8. Salve como UTF-8 sem BOM." >&2
    exit 1
  fi
  cp "$PGS" "$OUT_DIR/R__${NAME}.sql"
  COUNT=$((COUNT + 1))
done < <(find "$REPO_ROOT/Procedures" -type f -name '*.pgs' | sort)
echo "  repeatables: $COUNT arquivo(s) R__*.sql em flyway/repeatable/"

# === 1b. Comentarios do dicionario de dados ===
node "$REPO_ROOT/tools/gen-dictionary.mjs" --sql "$OUT_DIR/R__zz_dictionary_comments.sql" --quiet
echo "  dicionario : R__zz_dictionary_comments.sql gerado de docs/dictionary/schema.json"

# === 2. Versionadas (Scripts/YYYY/MM/V*.sql) ===
SCOUNT=0
if [ -d "$REPO_ROOT/Scripts" ]; then
  while IFS= read -r SQL; do
    if has_bom "$SQL"; then
      echo "ERRO: $SQL tem BOM UTF-8. Salve como UTF-8 sem BOM." >&2
      exit 1
    fi
    REL="${SQL#"$REPO_ROOT/Scripts/"}"
    mkdir -p "$STAGED_DIR/$(dirname "$REL")"
    cp "$SQL" "$STAGED_DIR/$REL"
    SCOUNT=$((SCOUNT + 1))
  done < <(find "$REPO_ROOT/Scripts" -type f -name 'V*.sql' | sort)
fi
echo "  versionadas: $SCOUNT arquivo(s) V*.sql em flyway/staged-scripts/"
