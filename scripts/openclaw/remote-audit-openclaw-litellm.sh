#!/usr/bin/env bash
# Corre no host remoto (agldv03 / fgsrv06): gateway OpenClaw, LiteLLM, chaves.
# Instalação: scp scripts/openclaw/remote-audit-openclaw-litellm.sh root@HOST:/tmp/audit-oc.sh && ssh root@HOST bash /tmp/audit-oc.sh
set -euo pipefail

echo "======== $(hostname) ($(date -Iseconds)) ========"
echo "=== openclaw-gateway (systemd --user) ==="
systemctl --user is-active openclaw-gateway 2>/dev/null && systemctl --user show openclaw-gateway -p ActiveState --no-pager || echo "(sem unidade ou erro)"

echo ""
echo "=== openclaw --version ==="
openclaw --version 2>/dev/null | head -1 || echo "(openclaw não no PATH)"

echo ""
echo "=== /opt/litellm/.env (só comprimentos / prefixos) ==="
if [[ -r /opt/litellm/.env ]]; then
  echo -n "LITELLM_MASTER_KEY: "
  grep -m1 '^LITELLM_MASTER_KEY=' /opt/litellm/.env | head -c 45
  echo "..."
  for v in OPENAI_API_KEY GEMINI_API_KEY ANTHROPIC_API_KEY DEEPSEEK_API_KEY MOONSHOT_API_KEY ZAI_API_KEY; do
    line="$(grep -m1 "^${v}=" /opt/litellm/.env 2>/dev/null || true)"
    val="${line#*=}"
    echo "$v len(host .env): ${#val}"
  done
else
  echo "(ficheiro inexistente ou sem leitura)"
fi

echo ""
echo "=== Docker litellm-proxy ==="
if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qx litellm-proxy; then
  echo "state: $(docker inspect -f '{{.State.Status}}' litellm-proxy 2>/dev/null)"
  for v in OPENAI_API_KEY GEMINI_API_KEY ANTHROPIC_API_KEY; do
    n="$(docker exec litellm-proxy printenv "$v" 2>/dev/null | wc -c || echo 0)"
    echo "container $v bytes: $n"
  done
else
  echo "(sem contentor litellm-proxy)"
fi

echo ""
echo "=== OpenClaw agent main / models.json (openai apiKey prefix) ==="
MP=/root/.openclaw/agents/main/agent/models.json
if [[ -f "$MP" ]]; then
  jq -r '.providers.openai.apiKey // "null"' "$MP" 2>/dev/null | head -c 28
  echo "..."
  jq -r '.providers.openai.baseUrl // empty' "$MP" 2>/dev/null | sed 's/^/openai baseUrl: /'
else
  echo "(sem $MP)"
fi

echo ""
echo "=== openclaw.conf tem LITELLM_MASTER_KEY? ==="
if [[ -r /root/.config/environment.d/openclaw.conf ]] && grep -q '^LITELLM_MASTER_KEY=' /root/.config/environment.d/openclaw.conf; then
  echo "sim"
else
  echo "NÃO (gateway pode não ver a master key)"
fi

echo ""
echo "=== LiteLLM GET /v1/models (Bearer master) ==="
if [[ -r /opt/litellm/.env ]]; then
  K="$(grep -m1 '^LITELLM_MASTER_KEY=' /opt/litellm/.env | cut -d= -f2- | tr -d '\r')"
  K="${K//\"/}"
  if [[ -n "$K" ]]; then
    code="$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $K" http://127.0.0.1:4000/v1/models 2>/dev/null || echo 0)"
    echo "HTTP $code"
  fi
fi

echo "======== fim $(hostname) ========"
echo ""
