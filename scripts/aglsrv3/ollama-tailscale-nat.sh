#!/usr/bin/env bash
# NAT Tailscale → VM310 Ollama (192.168.15.210:11434) no AGLSRV3.
# Executar como root no aglsrv3 após reboot se o proxy TS deixar de funcionar.
set -euo pipefail

OLLAMA_IP="${OLLAMA_IP:-192.168.15.210}"
OLLAMA_PORT="${OLLAMA_PORT:-11434}"

iptables -t nat -C PREROUTING -i tailscale0 -p tcp --dport "${OLLAMA_PORT}" -j DNAT \
  --to-destination "${OLLAMA_IP}:${OLLAMA_PORT}" 2>/dev/null || \
iptables -t nat -A PREROUTING -i tailscale0 -p tcp --dport "${OLLAMA_PORT}" -j DNAT \
  --to-destination "${OLLAMA_IP}:${OLLAMA_PORT}"

iptables -C FORWARD -p tcp -d "${OLLAMA_IP}" --dport "${OLLAMA_PORT}" -j ACCEPT 2>/dev/null || \
iptables -A FORWARD -p tcp -d "${OLLAMA_IP}" --dport "${OLLAMA_PORT}" -j ACCEPT

echo "OK: tailscale0:${OLLAMA_PORT} → ${OLLAMA_IP}:${OLLAMA_PORT}"
