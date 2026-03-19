#!/usr/bin/env bash
# Configura OpenClaw para usar LiteLLM local (localhost:4000)
# Uso: ./scripts/openclaw/use-litellm-local.sh
# Requer: jq, LiteLLM rodando em localhost:4000 (Docker ou agldv03/fgsrv06)

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PATCH="$REPO_ROOT/config/openclaw/openclaw-patch.json"
JQ_PATCH="$REPO_ROOT/config/openclaw/openclaw-litellm-local.jq"
LOCAL_ENV="$REPO_ROOT/config/openclaw/litellm-gateway-local.env"
OPENCLAW_DIR="${OPENCLAW_CONFIG_DIR:-$HOME/.openclaw}"
OPENCLAW_JSON="$OPENCLAW_DIR/openclaw.json"

mkdir -p "$OPENCLAW_DIR"

echo "=== OpenClaw → LiteLLM local (localhost:4000) ==="
echo "  Config: $OPENCLAW_JSON"
echo ""

# Merge base patch + aplicar jq
current=$(cat "$OPENCLAW_JSON" 2>/dev/null || echo '{}')
merged=$(echo "$current" "$PATCH" | jq -s '.[0] * .[1]' 2>/dev/null)
if [[ -z "$merged" ]]; then
  merged=$(cat "$PATCH")
fi
patched=$(echo "$merged" | jq -f "$JQ_PATCH" 2>/dev/null)
if [[ -n "$patched" ]]; then
  echo "$patched" > "$OPENCLAW_JSON"
  echo "  OK: openclaw.json atualizado"
else
  echo "  Erro: falha ao aplicar patch (jq instalado?)"
  exit 1
fi

# Copiar litellm-gateway.env para local
cp "$LOCAL_ENV" "$OPENCLAW_DIR/litellm-gateway.env" 2>/dev/null && echo "  OK: litellm-gateway.env" || true

echo ""
echo "=== Concluído ==="
echo "  Reinicie o gateway: openclaw gateway restart"
echo "  Verifique: openclaw models list"
