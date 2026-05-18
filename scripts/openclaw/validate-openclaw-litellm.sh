#!/usr/bin/env bash
# Validação em cadeia: LiteLLM /v1/chat/completions + WebSocket gateway OpenClaw + pedido agent (opcional).
#
# Uso (host com OpenClaw + LiteLLM, ex. agldv03):
#   bash scripts/openclaw/validate-openclaw-litellm.sh
#   SKIP_AGENT=1 bash ...   # só LiteLLM + gateway health RPC
#
# Requer: jq, curl, openclaw no PATH; chave em /opt/litellm/.env ou LITELLM_MASTER_KEY.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LITELLM_URL="${LITELLM_URL:-http://127.0.0.1:4000}"
OPT_ENV="${LITELLM_OPT_ENV:-/opt/litellm/.env}"
OC_JSON="${OPENCLAW_JSON:-$HOME/.openclaw/openclaw.json}"
OC_CONF="${OPENCLAW_SYSTEMD_ENV:-$HOME/.config/environment.d/openclaw.conf}"
MODEL="${VALIDATE_LITELLM_MODEL:-openrouter/openrouter/free}"

fail() { echo "ERRO: $*" >&2; exit 1; }

if [[ -f "$OPT_ENV" ]]; then
  K="$(grep -m1 '^LITELLM_MASTER_KEY=' "$OPT_ENV" | cut -d= -f2-)"
  K="${K%$'\r'}"
  K="${K#\"}"
  K="${K%\"}"
else
  K="${LITELLM_MASTER_KEY:-}"
fi
[[ -n "$K" ]] || fail "defina LITELLM_MASTER_KEY ou $OPT_ENV"

if [[ "$K" == "sk-your-secure-master-key" ]]; then
  echo "AVISO: LITELLM_MASTER_KEY é o placeholder de exemplo — em produção use uma chave real no LiteLLM." >&2
fi

echo "=== 1) LiteLLM POST /v1/chat/completions model=$MODEL ==="
body="$(jq -nc --arg m "$MODEL" '{model:$m,messages:[{role:"user",content:"Responde só: OK"}],max_tokens:256}')"
# shellcheck disable=SC2086
resp="$(curl -sS --max-time 120 -H "Authorization: Bearer $K" -H "Content-Type: application/json" \
  "$LITELLM_URL/v1/chat/completions" -d "$body")"
if echo "$resp" | jq -e '.error' >/dev/null 2>&1; then
  echo "$resp" | jq .
  fail "LiteLLM devolveu erro"
fi
_txt="$(echo "$resp" | jq -r '(.choices[0].message.content // .choices[0].message.reasoning_content // empty)')"
if [[ -z "${_txt// }" ]]; then
  echo "$resp" | jq .
  fail "LiteLLM: resposta vazia (content e reasoning_content)"
fi
echo "OK LiteLLM: ${_txt:0:120}"

if [[ "${SKIP_GATEWAY:-}" == "1" ]]; then
  echo "SKIP_GATEWAY=1 — fim (só LiteLLM)."
  exit 0
fi

[[ -f "$OC_CONF" ]] || fail "falta $OC_CONF — correr: bash $REPO_ROOT/scripts/openclaw/sync-systemd-openclaw-env.sh"
if ! grep -q '^OPENCLAW_GATEWAY_TOKEN=' "$OC_CONF" 2>/dev/null; then
  echo "AVISO: OPENCLAW_GATEWAY_TOKEN ausente em $OC_CONF — correr sync-systemd-openclaw-env.sh" >&2
fi

echo "=== 2) openclaw gateway call health (WS + token no ambiente) ==="
if ! command -v openclaw >/dev/null 2>&1; then
  echo "AVISO: openclaw não no PATH — saltar gateway/agent." >&2
  exit 0
fi

set -a
# shellcheck source=/dev/null
source "$OC_CONF"
set +a

gw_ok=0
if [[ -n "${OPENCLAW_GATEWAY_TOKEN:-}" ]]; then
  h_out="$(openclaw gateway call health --timeout 120000 --json 2>&1)" || true
  if ! echo "$h_out" | grep -q 'gateway connect failed'; then
    gw_ok=1
    echo "OK gateway RPC: health"
  else
    echo "$h_out" | tail -12
    echo "AVISO: WebSocket CLI→gateway falhou (1000). O serviço systemd pode estar bem; Telegram usa outro caminho." >&2
    echo "  Tentar: systemctl --user restart openclaw-gateway; openclaw doctor; bash $REPO_ROOT/scripts/openclaw/diag-agldv03-openclaw.sh" >&2
  fi
else
  echo "AVISO: OPENCLAW_GATEWAY_TOKEN vazio — exportar após sync-systemd ou adicionar ao openclaw.conf." >&2
fi

if [[ "${SKIP_AGENT:-}" == "1" || "$gw_ok" != "1" ]]; then
  echo "SKIP_AGENT (gateway WS não OK ou SKIP_AGENT=1) — fim."
  exit 0
fi

echo "=== 3) openclaw agent --agent main (via gateway) ==="
a_out="$(openclaw agent --agent main --message "Responde exatamente a palavra OK." --json --timeout 120 2>&1)" || true
if echo "$a_out" | grep -q 'gateway connect failed'; then
  echo "$a_out" | tail -15
  echo "AVISO: agent caiu para embedded — payloads podem vir vazios se faltar env." >&2
  exit 0
fi
_pl="$(echo "$a_out" | jq '(.payloads // []) | length' 2>/dev/null || echo 0)"
if [[ "$_pl" == "0" ]]; then
  echo "$a_out" | head -c 2000
  echo "AVISO: payloads vazio — ver ~/.openclaw/agents/main/sessions/ e modelos no LiteLLM." >&2
  exit 0
fi
echo "OK agent: payloads count=$_pl"
echo "$a_out" | jq '{durationMs: .meta.durationMs, firstPayload: .payloads[0]}' 2>/dev/null || true

echo ""
echo "OK: LiteLLM + gateway WS + agent."
