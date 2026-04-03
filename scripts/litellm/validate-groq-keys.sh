#!/usr/bin/env bash
# Valida GROQ_API_KEY e GROQ_API_KEY2 contra a API Groq (GET /openai/v1/models).
# Não imprime o valor das chaves.
#
# Uso:
#   export GROQ_API_KEY="gsk_..."
#   export GROQ_API_KEY2="gsk_..."   # opcional (segunda conta / rotação)
#   ./scripts/litellm/validate-groq-keys.sh
#
# Carregar do ~/.zshrc (só linhas export GROQ_*= literais, sem '${'):
#   ./scripts/litellm/validate-groq-keys.sh --from-zshrc
#
# Reason: validação sem custo de tokens; 401/403 = chave inválida ou revogada.

set -euo pipefail

GROQ_BASE_URL="${GROQ_BASE_URL:-https://api.groq.com/openai/v1}"
ZSHRC="${HOME}/.zshrc"

load_groq_from_zshrc() {
  if [[ ! -f "$ZSHRC" ]]; then
    echo "ERRO: $ZSHRC não encontrado." >&2
    return 1
  fi
  local _tmp
  _tmp="$(mktemp)"
  # Alinhar com sync-systemd-openclaw-env.sh: ignorar valores com '${' (systemd não expande).
  grep -E '^export (GROQ_API_KEY|GROQ_API_KEY2)=' "$ZSHRC" 2>/dev/null | grep -vF '${' > "$_tmp" || true
  if [[ ! -s "$_tmp" ]]; then
    rm -f "$_tmp"
    echo "AVISO: nenhuma linha export GROQ_API_KEY(2)= encontrada em $ZSHRC (ou só com \${...})." >&2
    return 0
  fi
  # shellcheck source=/dev/null
  set -a
  source "$_tmp" || true
  set +a
  rm -f "$_tmp"
}

check_one() {
  local label="$1"
  local key="${2:-}"
  if [[ -z "$key" ]]; then
    echo "  [$label] — não definida (skip)"
    return 0
  fi
  local tmp http_code
  tmp="$(mktemp)"
  http_code="$(curl -sS -o "$tmp" -w "%{http_code}" \
    -H "Authorization: Bearer ${key}" \
    -H "Content-Type: application/json" \
    "${GROQ_BASE_URL}/models" 2>/dev/null || echo "000")"

  if [[ "$http_code" == "200" ]]; then
    local n=0
    if command -v jq >/dev/null 2>&1; then
      n="$(jq -r '.data | length' "$tmp" 2>/dev/null || echo 0)"
    fi
    echo "  [$label] OK (HTTP $http_code; modelos listados: ${n:-?})"
    rm -f "$tmp"
    return 0
  fi

  echo "  [$label] FALHA (HTTP $http_code)" >&2
  if [[ -s "$tmp" ]] && command -v jq >/dev/null 2>&1; then
    jq -r '.error.message // .message // .' "$tmp" 2>/dev/null | head -c 200 >&2 || head -c 200 "$tmp" >&2
    echo >&2
  elif [[ -s "$tmp" ]]; then
    head -c 200 "$tmp" >&2
    echo >&2
  fi
  rm -f "$tmp"
  return 1
}

fail=0

case "${1:-}" in
  -h|--help)
    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  --from-zshrc)
    load_groq_from_zshrc
    ;;
esac

echo "=== Validação Groq (${GROQ_BASE_URL}/models) ==="

if ! command -v curl >/dev/null 2>&1; then
  echo "ERRO: curl não encontrado." >&2
  exit 1
fi

if [[ -z "${GROQ_API_KEY:-}" && -z "${GROQ_API_KEY2:-}" ]]; then
  echo "Nenhuma de GROQ_API_KEY / GROQ_API_KEY2 está definida no ambiente."
  echo "Defina-as ou use: $0 --from-zshrc"
  exit 2
fi

check_one "GROQ_API_KEY" "${GROQ_API_KEY:-}" || fail=1
check_one "GROQ_API_KEY2" "${GROQ_API_KEY2:-}" || fail=1

if [[ "$fail" -ne 0 ]]; then
  echo "" >&2
  echo "Uma ou mais chaves definidas falharam. Corrija no .zshrc ou no env." >&2
  exit 1
fi

echo ""
echo "Concluído: todas as chaves definidas responderam OK."
exit 0
