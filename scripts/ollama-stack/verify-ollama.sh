#!/usr/bin/env bash
# Verifica API Ollama (version + modelos instalados).
# Uso (CT200 / aglsrv1-ollama-gpu):
#   OLLAMA_HOST=100.116.57.111:11434 ./scripts/ollama-stack/verify-ollama.sh   # Tailscale
#   ./scripts/ollama-stack/verify-ollama.sh http://192.168.0.200:11434         # LAN
#   ./scripts/ollama-stack/verify-ollama.sh http://10.6.0.17:11434             # WireGuard

set -euo pipefail

BASE="${1:-}"
if [[ -z "$BASE" ]]; then
  BASE="http://${OLLAMA_HOST:-127.0.0.1:11434}"
fi
BASE="${BASE%/}"

echo "=== Ollama: ${BASE} ==="
if ! curl -sS -m 5 -f "${BASE}/api/version" >/dev/null 2>&1; then
  echo "ERRO: não responde em ${BASE} (serviço parado ou rede/firewall)." >&2
  echo "Dica: em CT200 ver docs/CT200-OLLAMA-QUICKSTART.md — curl ${BASE}/api/tags" >&2
  exit 1
fi

echo "--- /api/version ---"
curl -sS -m 5 "${BASE}/api/version" | head -c 400 || true
echo ""
echo "--- /api/tags (modelos) ---"
curl -sS -m 15 "${BASE}/api/tags" | head -c 8000 || true
echo ""
echo "OK: Ollama acessível."
exit 0
