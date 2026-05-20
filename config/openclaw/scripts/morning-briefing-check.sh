#!/bin/sh
# Morning briefing digest for OpenClaw cron (CT187).
# Em OK: imprime MORNING_BRIEFING (não HEARTBEAT_OK) para entrega Telegram via mode announce.
set -eu

TZ="${TZ:-America/Sao_Paulo}"
export TZ
TS=$(date '+%Y-%m-%d %H:%M %Z')
fail=0
issues=""

oc=$(curl -s -o /dev/null -w '%{http_code}' -m 5 http://127.0.0.1:18789/healthz 2>/dev/null || echo curl_failed)
llm=$(curl -s -o /dev/null -w '%{http_code}' -m 10 http://100.125.249.8:4000/health/liveliness 2>/dev/null || echo curl_failed)

ssh_ok=""
for h in aglsrv1 ct186 ct187 agldv03; do
  if ssh -o BatchMode=yes -o ConnectTimeout=10 "$h" 'hostname >/dev/null && uptime >/dev/null' >/dev/null 2>&1; then
    ssh_ok="${ssh_ok}${ssh_ok:+ }${h}"
  else
    fail=1
    issues="${issues}
- SSH ${h}: falhou"
  fi
done

litellm_docker="?"
if ssh -o BatchMode=yes -o ConnectTimeout=10 ct186 'docker ps --format "{{.Names}}" | grep -q litellm-proxy' >/dev/null 2>&1; then
  litellm_docker=ok
else
  fail=1
  litellm_docker=fail
  issues="${issues}
- CT186: litellm-proxy em falta"
fi

oc_docker="?"
if ssh -o BatchMode=yes -o ConnectTimeout=10 ct187 'docker ps --format "{{.Names}}" | grep -q openclaw-gateway' >/dev/null 2>&1; then
  oc_docker=ok
else
  fail=1
  oc_docker=fail
  issues="${issues}
- CT187: openclaw-gateway em falta"
fi

[ "$oc" = 200 ] || { fail=1; issues="${issues}
- OpenClaw healthz: HTTP ${oc}"; }
[ "$llm" = 200 ] || { fail=1; issues="${issues}
- LiteLLM liveliness: HTTP ${llm}"; }

if [ "$fail" -ne 0 ]; then
  printf '%s\n' "MORNING_BRIEFING_ISSUES (${TS}):${issues}"
  exit 1
fi

printf '%s\n' "MORNING_BRIEFING (${TS})
Parque AGL — resumo (12h)

OpenClaw gateway: HTTP ${oc}
LiteLLM CT186: HTTP ${llm}
SSH OK: ${ssh_ok:-nenhum}
Docker: litellm-proxy=${litellm_docker}, openclaw-gateway=${oc_docker}

Estado: operacional."
