#!/usr/bin/env bash
# Diagnóstico 401 VerificationTokenTable — correr no host com LiteLLM (ex.: agldv03).
# Não imprime a chave completa; apenas comprimentos e últimos caracteres.
set -euo pipefail

echo "=== /opt/litellm/.env LITELLM_MASTER_KEY ==="
if [[ -f /opt/litellm/.env ]]; then
  line=$(grep -m1 '^LITELLM_MASTER_KEY=' /opt/litellm/.env || true)
  val="${line#*=}"
  val="${val//$'\r'/}"
  val="${val#\"}"
  val="${val%\"}"
  echo "  len=${#val} suffix=...${val: -6}"
else
  echo "  (ficheiro em falta)"
fi

echo "=== ~/.openclaw/litellm-gateway.env ==="
if [[ -f "$HOME/.openclaw/litellm-gateway.env" ]]; then
  line=$(grep -m1 '^LITELLM_MASTER_KEY=' "$HOME/.openclaw/litellm-gateway.env" || true)
  val="${line#*=}"
  val="${val//$'\r'/}"
  val="${val#\"}"
  val="${val%\"}"
  echo "  len=${#val} suffix=...${val: -6}"
else
  echo "  (em falta)"
fi

echo "=== openclaw.json — strings sk- (len + sufixo) ==="
if [[ -f "$HOME/.openclaw/openclaw.json" ]]; then
  # grep sem matches devolve 1 — evitar pipefail a abortar o script
  mapfile -t _sk < <(grep -oE '"sk-[A-Za-z0-9_-]{10,}"' "$HOME/.openclaw/openclaw.json" 2>/dev/null || true)
  if [[ ${#_sk[@]} -eq 0 ]]; then
    echo "  (nenhuma string sk- encontrada no JSON)"
  else
    for tok in "${_sk[@]}"; do
      t="${tok//\"/}"
      n=${#t}
      [[ $n -ge 6 ]] && echo "  len=$n suf=...${t: -6}"
    done | sort -u | head -15
  fi
else
  echo "  (sem openclaw.json)"
fi

echo "=== curl /v1/models com chave do .env do proxy ==="
if [[ -f /opt/litellm/.env ]]; then
  K=$(grep -m1 '^LITELLM_MASTER_KEY=' /opt/litellm/.env | cut -d= -f2- | tr -d '\r')
  K=${K//\"/}
  code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 \
    -H "Authorization: Bearer $K" http://127.0.0.1:4000/v1/models || echo "err")
  echo "  HTTP $code (200 = chave master aceite)"
else
  echo "  (sem .env)"
fi
