#!/usr/bin/env bash
# Aplica ZAI_API_KEY no LiteLLM (/opt/litellm/.env) e no auth OpenClaw (agents/main).
# Uso no host: bash patch-zai-litellm-openclaw-remote.sh 'SEU_ZAI_API_KEY'
# Reason: alinhar proxy + perfil zai:default como no aglwk45.
set -euo pipefail

KEY="${1:?pass ZAI API key as first argument}"

ENV=/opt/litellm/.env
AUTH=/root/.openclaw/agents/main/agent/auth-profiles.json

if [[ ! -f "$ENV" ]]; then
  echo "ERRO: falta $ENV" >&2
  exit 1
fi

tmp_env="$(mktemp)"
found=0
while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ "$line" =~ ^ZAI_API_KEY= ]]; then
    printf 'ZAI_API_KEY=%s\n' "$KEY"
    found=1
  else
    printf '%s\n' "$line"
  fi
done < "$ENV" > "$tmp_env"
if [[ "$found" -eq 0 ]]; then
  printf 'ZAI_API_KEY=%s\n' "$KEY" >> "$tmp_env"
fi
mv "$tmp_env" "$ENV"

if command -v docker >/dev/null 2>&1 && docker ps -a --format '{{.Names}}' | grep -qx 'litellm-proxy'; then
  docker restart litellm-proxy
  echo "LiteLLM: litellm-proxy reiniciado."
else
  echo "AVISO: contentor litellm-proxy não encontrado; confirme o serviço LiteLLM manualmente."
fi

if [[ -f "$AUTH" ]]; then
  python3 <<PY
import json
from pathlib import Path
p = Path("$AUTH")
raw = p.read_bytes()
if raw.startswith(b"\xef\xbb\xbf"):
    raw = raw[3:]
data = json.loads(raw.decode("utf-8"))
profiles = data.setdefault("profiles", {})
entry = profiles.setdefault("zai:default", {})
entry["provider"] = "zai"
entry["type"] = "api_key"
entry["key"] = """$KEY"""
lg = data.setdefault("lastGood", {})
lg["zai"] = "zai:default"
p.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
PY
  chmod 600 "$AUTH" || true
  echo "OpenClaw: auth-profiles.json (zai:default) atualizado."
else
  echo "AVISO: falta $AUTH — auth não alterado."
fi

if systemctl is-system-running >/dev/null 2>&1; then
  systemctl --user daemon-reload 2>/dev/null || true
  if systemctl --user is-enabled openclaw-gateway >/dev/null 2>&1 || systemctl --user cat openclaw-gateway >/dev/null 2>&1; then
    systemctl --user restart openclaw-gateway
    sleep 2
    systemctl --user is-active openclaw-gateway || true
  fi
fi

echo "Concluído neste host."
