#!/usr/bin/env bash
# validate-standards.sh
#
# Valida os padroes do projeto (falha o PR se violar):
#
# Procedures/**/*.pgs (repeatables: functions, triggers, RLS policies)
#   1. Naming: snake_case minusculo  ^[a-z][a-z0-9_]*\.pgs$
#   2. Header corporativo com "Project" nas primeiras 15 linhas
#   3. UTF-8 valido, sem BOM
#   4. Contem CREATE OR REPLACE FUNCTION/TRIGGER ou CREATE POLICY (idempotente)
#   5. Toda function SECURITY DEFINER tem SET search_path = '' (lint Supabase)
#   6. Arquivo com function tem REVOKE ALL ON FUNCTION (least privilege explicito)
#   7. Nenhum GRANT para anon ou public (anon nunca recebe nada)
#
# Scripts/YYYY/MM/V<YYYYMMDD>_<HHMM>__<desc>.sql (versionadas)
#   1. Caminho e nome no padrao; YYYY/MM do path = YYYY/MM do filename
#   2. UTF-8 sem BOM
#   3. Toda CREATE TABLE acompanhada de ENABLE ROW LEVEL SECURITY no mesmo arquivo
#   4. Nenhum GRANT para anon ou public
#
# Uso: ./flyway/scripts/validate-standards.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

ERRORS=0
err() { echo "  ERRO  $1"; ERRORS=$((ERRORS + 1)); }

has_bom() { [ "$(head -c 3 "$1" | od -An -tx1 | tr -d ' \n')" = "efbbbf" ]; }
valid_utf8() { iconv -f UTF-8 -t UTF-8 "$1" >/dev/null 2>&1; }
# Remove comentarios /* ... */ e -- ... para que as checagens olhem so o codigo.
strip_comments() { perl -0777 -pe 's{/\*.*?\*/}{}gs; s{--[^\n]*}{}g' "$1"; }
count_ci() { strip_comments "$1" | grep -ciE "$2" || true; }
has_ci() { strip_comments "$1" | grep -qiE "$2"; }

echo "------ Procedures ------"
while IFS= read -r FILE; do
  NAME="$(basename "$FILE")"

  if ! [[ "$NAME" =~ ^[a-z][a-z0-9_]*\.pgs$ ]]; then
    err "$FILE - nome deve ser snake_case minusculo (ex.: company_create.pgs)"
  fi
  if ! head -15 "$FILE" | grep -q "Project"; then
    err "$FILE - falta o header corporativo (linha 'Project :' nas primeiras 15 linhas)"
  fi
  if has_bom "$FILE"; then
    err "$FILE - tem BOM UTF-8 (salvar como UTF-8 sem BOM)"
  fi
  if ! valid_utf8 "$FILE"; then
    err "$FILE - nao e UTF-8 valido"
  fi
  if ! has_ci "$FILE" "create\s+(or\s+replace\s+)?(function|trigger)|create\s+policy"; then
    err "$FILE - nao tem CREATE OR REPLACE FUNCTION/TRIGGER nem CREATE POLICY"
  fi

  DEFINERS=$(count_ci "$FILE" "security\s+definer")
  SEARCHPATH=$(count_ci "$FILE" "set\s+search_path\s*=\s*''")
  if [ "$DEFINERS" -gt "$SEARCHPATH" ]; then
    err "$FILE - $DEFINERS SECURITY DEFINER mas so $SEARCHPATH SET search_path = '' (obrigatorio em cada uma)"
  fi

  if has_ci "$FILE" "create\s+or\s+replace\s+function" && ! has_ci "$FILE" "revoke\s+all\s+on\s+function"; then
    err "$FILE - function sem 'revoke all on function ... from public, anon' (least privilege explicito)"
  fi

  if has_ci "$FILE" "grant\s+.*\s+to\s+(anon|public)\b"; then
    err "$FILE - GRANT para anon/public e proibido"
  fi
done < <(find Procedures -type f -name '*.pgs' 2>/dev/null | sort)
echo "  procedures verificadas"

echo ""
echo "------ Scripts (versioned) ------"
while IFS= read -r FILE; do
  err "$FILE - versionada nao pode estar na raiz de Scripts/. Mova para Scripts/YYYY/MM/"
done < <(find Scripts -maxdepth 1 -type f -name '*.sql' 2>/dev/null)

while IFS= read -r FILE; do
  err "$FILE - versionada precisa estar em Scripts/YYYY/MM/, nao em Scripts/YYYY/"
done < <(find Scripts -maxdepth 2 -mindepth 2 -type f -name '*.sql' 2>/dev/null)

while IFS= read -r FILE; do
  REL="${FILE#Scripts/}"
  if ! echo "$REL" | grep -qE '^[0-9]{4}/[0-9]{2}/V[0-9]{8}_[0-9]{4}__[a-z0-9_]+\.sql$'; then
    err "$FILE - nao bate Scripts/YYYY/MM/V<YYYYMMDD>_<HHMM>__<desc_snake_case>.sql"
    continue
  fi
  PATH_YYYY="$(echo "$REL" | cut -d/ -f1)"
  PATH_MM="$(echo "$REL" | cut -d/ -f2)"
  FNAME="$(basename "$REL")"
  if [ "$PATH_YYYY" != "${FNAME:1:4}" ] || [ "$PATH_MM" != "${FNAME:5:2}" ]; then
    err "$FILE - YYYY/MM do path ($PATH_YYYY/$PATH_MM) nao bate com o filename (${FNAME:1:4}/${FNAME:5:2})"
  fi
  if has_bom "$FILE"; then
    err "$FILE - tem BOM UTF-8"
  fi
  if ! valid_utf8 "$FILE"; then
    err "$FILE - nao e UTF-8 valido"
  fi
  TABLES=$(count_ci "$FILE" "^\s*create\s+table")
  RLS=$(count_ci "$FILE" "enable\s+row\s+level\s+security")
  if [ "$TABLES" -gt "$RLS" ]; then
    err "$FILE - $TABLES CREATE TABLE mas so $RLS ENABLE ROW LEVEL SECURITY (toda tabela nasce com RLS)"
  fi
  if has_ci "$FILE" "grant\s+.*\s+to\s+(anon|public)\b"; then
    err "$FILE - GRANT para anon/public e proibido"
  fi
done < <(find Scripts -mindepth 3 -type f -name '*.sql' 2>/dev/null | sort)
echo "  scripts verificados"

echo ""
if [ "$ERRORS" -gt 0 ]; then
  echo "FALHOU: $ERRORS erro(s). Nao mergear sem corrigir."
  exit 1
fi
echo "OK: 0 erros."
exit 0
