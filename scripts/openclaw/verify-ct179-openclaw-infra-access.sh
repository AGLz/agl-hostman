#!/usr/bin/env bash
# Pré-requisitos de rede e serviços no CT179 (agldv03) para OpenClaw cron / administração de infra.
# Executar dentro do CT179: bash scripts/openclaw/verify-ct179-openclaw-infra-access.sh
# Referência: ops/runbooks/jarvis-operations.md — secção «CT179 (agldv03): acessos…»

set -u

CRITICAL=0

pass() {
  printf 'OK    %s\n' "$*"
}

fail() {
  printf 'FAIL  %s\n' "$*" >&2
  CRITICAL=$((CRITICAL + 1))
}

warn() {
  printf 'WARN  %s\n' "$*" >&2
}

section() {
  printf '\n=== %s ===\n' "$*"
}

section "Tailscale"
if command -v tailscale >/dev/null 2>&1; then
  if tailscale status >/dev/null 2>&1; then
    pass "tailscale status"
  else
    fail "tailscale status (comando falhou)"
  fi
  if ping -c2 -W3 100.107.113.33 >/dev/null 2>&1; then
    pass "ping 100.107.113.33 (AGLSRV1 Tailscale)"
  else
    fail "ping 100.107.113.33"
  fi
else
  warn "tailscale não encontrado no PATH — saltar checks Tailscale"
fi

section "WireGuard wg0"
if command -v wg >/dev/null 2>&1; then
  if wg show wg0 >/dev/null 2>&1; then
    pass "wg show wg0"
  else
    fail "wg show wg0 (interface ausente ou erro)"
  fi
else
  warn "comando wg ausente"
fi
if ping -c2 -W3 10.6.0.5 >/dev/null 2>&1; then
  pass "ping 10.6.0.5 (hub WireGuard)"
else
  fail "ping 10.6.0.5"
fi
if ping -c2 -W3 10.6.0.10 >/dev/null 2>&1; then
  pass "ping 10.6.0.10 (AGLSRV1 WireGuard)"
else
  fail "ping 10.6.0.10"
fi

section "LAN e SSH Proxmox (AGLSRV1)"
if ping -c2 -W3 192.168.0.245 >/dev/null 2>&1; then
  pass "ping 192.168.0.245"
else
  fail "ping 192.168.0.245"
fi
if command -v ssh >/dev/null 2>&1; then
  if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new root@192.168.0.245 true >/dev/null 2>&1; then
    pass "ssh BatchMode root@192.168.0.245"
  else
    fail "ssh BatchMode root@192.168.0.245 (chave/credencial ou firewall)"
  fi
  if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new root@10.6.0.10 true >/dev/null 2>&1; then
    pass "ssh BatchMode root@10.6.0.10"
  else
    warn "ssh BatchMode root@10.6.0.10 falhou (opcional conforme jobs.json)"
  fi
else
  fail "ssh não encontrado no PATH"
fi

section "LiteLLM local"
if command -v curl >/dev/null 2>&1; then
  if curl -sfS --max-time 5 http://127.0.0.1:4000/health/readiness >/dev/null; then
    pass "curl http://127.0.0.1:4000/health/readiness"
  else
    fail "curl LiteLLM readiness (serviço parado ou porta errada)"
  fi
else
  fail "curl não encontrado no PATH"
fi

section "OpenClaw / gateway"
if pgrep -af openclaw >/dev/null 2>&1; then
  pass "processo openclaw (pgrep)"
elif command -v systemctl >/dev/null 2>&1 && systemctl --user is-active openclaw-gateway >/dev/null 2>&1; then
  pass "systemctl --user openclaw-gateway ativo"
else
  warn "sem pgrep openclaw nem openclaw-gateway user active — confirmar o teu setup"
fi

section "Resumo"
if [[ "$CRITICAL" -eq 0 ]]; then
  printf 'Todos os checks críticos passaram.\n'
  exit 0
fi

printf '%d falha(s) crítica(s). Corrigir rede, SSH ou LiteLLM antes dos jobs cron.\n' "$CRITICAL" >&2
exit 1
