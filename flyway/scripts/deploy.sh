#!/usr/bin/env bash
# deploy.sh <local|staging|prod> [info|migrate|validate|repair]
#
# Roda o Flyway com a config do ambiente. Usa o Flyway CLI se instalado;
# senao, a imagem Docker oficial redgate/flyway:11 (nada a instalar).
#
# Conexao por variaveis de ambiente (obrigatorias):
#   FLYWAY_URL       jdbc:postgresql://<host>:<porta>/postgres?sslmode=require
#   FLYWAY_USER      postgres.<project-ref>   (Supabase pooler, modo session 5432)
#   FLYWAY_PASSWORD  senha do banco
#
# Exemplos:
#   export FLYWAY_URL=... FLYWAY_USER=... FLYWAY_PASSWORD=...
#   ./flyway/scripts/deploy.sh staging info
#   ./flyway/scripts/deploy.sh staging           # migrate
#   ./flyway/scripts/deploy.sh prod validate
#
# Para o banco local em Docker use ./flyway/scripts/local-db.sh (ja exporta as variaveis).

set -euo pipefail

ENV="${1:-}"
CMD="${2:-migrate}"
case "$ENV" in
  local|staging|prod) ;;
  *) echo "Uso: $0 <local|staging|prod> [info|migrate|validate|repair]"; exit 1 ;;
esac
case "$CMD" in
  info|migrate|validate|repair) ;;
  *) echo "Comando invalido: $CMD (use info|migrate|validate|repair)"; exit 1 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONF="flyway/conf/flyway.${ENV}.conf"

: "${FLYWAY_URL:?defina FLYWAY_URL}"
: "${FLYWAY_USER:?defina FLYWAY_USER}"
: "${FLYWAY_PASSWORD:?defina FLYWAY_PASSWORD}"

cd "$REPO_ROOT"

echo "==> 1/2 Gerando flyway/repeatable e flyway/staged-scripts"
"$SCRIPT_DIR/generate-repeatables.sh"
echo ""

echo "==> 2/2 flyway $CMD ($ENV)"
if command -v flyway >/dev/null 2>&1; then
  flyway -configFiles="$CONF" "$CMD"
else
  # Git Bash (Windows) converte caminhos POSIX em argumentos; desligamos para o -v.
  HOST_REPO="$REPO_ROOT"
  if command -v cygpath >/dev/null 2>&1; then
    HOST_REPO="$(cygpath -w "$REPO_ROOT" | sed 's#\\#/#g')"
  fi
  MSYS_NO_PATHCONV=1 docker run --rm \
    --add-host=host.docker.internal:host-gateway \
    -v "$HOST_REPO:/workspace" -w /workspace \
    -e FLYWAY_URL -e FLYWAY_USER -e FLYWAY_PASSWORD \
    redgate/flyway:11 \
    -configFiles="$CONF" "$CMD"
fi
