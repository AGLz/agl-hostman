#!/usr/bin/env bash
# Corre no agldv03 após sync-systemd-openclaw-env.sh (validação rápida).
set -euo pipefail
K="$(sed -n 's/^LITELLM_MASTER_KEY=//p' /root/.openclaw/litellm-gateway.env | head -1 | tr -d '"')"
echo -n "LiteLLM /v1/models HTTP "
curl -sS -o /dev/null -w "%{http_code}" -H "Authorization: Bearer ${K}" http://127.0.0.1:4000/v1/models || true
echo
if grep -qF '${' /root/.config/environment.d/openclaw.conf 2>/dev/null; then
  echo "ERRO: openclaw.conf ainda contem sintaxe \${ (systemd nao expande)."
  exit 1
fi
echo "openclaw.conf: OK (sem \${)"
head -8 /root/.config/environment.d/openclaw.conf | while IFS= read -r line; do
  printf '%s=(definido)\n' "${line%%=*}"
done
