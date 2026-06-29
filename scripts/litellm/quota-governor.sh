#!/usr/bin/env bash
# Quota governor AGL — probe tiers LiteLLM, spend API, fallback Hermes free-tier, alerta Werner.
#
# Uso:
#   bash scripts/litellm/quota-governor.sh --dry-run
#   bash scripts/litellm/quota-governor.sh --json
#   bash scripts/litellm/quota-governor.sh --apply-hermes --notify
#
# Env: LITELLM_ENV_FILE, LITELLM_GATEWAY_URL, GOVERNOR_* (ver config/monitoring/quota-governor.env.example)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="${LITELLM_ENV_FILE:-/opt/litellm/.env}"
GATEWAY="${LITELLM_GATEWAY_URL:-http://100.125.249.8:4000}"
STATE_FILE="${GOVERNOR_STATE_FILE:-/var/log/hostman/quota-governor-state.json}"
GOVERNOR_ENV="${GOVERNOR_ENV:-$REPO_ROOT/config/monitoring/quota-governor.env}"

PROBE_T3="${GOVERNOR_PROBE_T3:-zai-glm-5,gpt-5.4-mini,claude-haiku}"
PROBE_T4="${GOVERNOR_PROBE_T4:-agl-primary,agl-primary-vm110}"
PROBE_T5="${GOVERNOR_PROBE_T5:-glm-4.7-flash,groq-llama-31-8b}"
SPEND_WARN_USD="${GOVERNOR_SPEND_WARN_USD:-80}"
HERMES_SSH_HOST="${HERMES_SSH_HOST:-root@100.81.225.22}"

DRY_RUN=1
JSON_OUT=0
APPLY_HERMES=0
NOTIFY=0
SKIP_PROBE=0

usage() {
  sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

log() { echo "[quota-governor] $*" >&2; }

load_env() {
  local gov_file="$GOVERNOR_ENV"
  if [[ ! -f "$gov_file" && -f "${REPO_ROOT}/config/monitoring/quota-governor.env.example" ]]; then
    gov_file="${REPO_ROOT}/config/monitoring/quota-governor.env.example"
  fi
  if [[ -f "$gov_file" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "$gov_file"
    set +a
  fi
  if [[ -f "$ENV_FILE" && -z "${LITELLM_MASTER_KEY:-}" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "$ENV_FILE"
    set +a
  fi
  if [[ -z "${LITELLM_MASTER_KEY:-}" ]]; then
    LITELLM_MASTER_KEY="$("$SCRIPT_DIR/_litellm-master-key.sh" || true)"
  fi
}

master_auth_header() {
  if [[ -n "${LITELLM_MASTER_KEY:-}" ]]; then
    printf 'Bearer %s' "$LITELLM_MASTER_KEY"
  else
    printf '%s' ""
  fi
}

probe_model() {
  local model="$1"
  local auth url code body snippet
  auth="$(master_auth_header)"
  url="${GATEWAY%/}/v1/chat/completions"
  body="$(jq -cn --arg m "$model" '{model:$m,messages:[{role:"user",content:"pong"}],max_tokens:4}')"
  code="$(curl -sS -o /tmp/gov-probe-$$.json -w '%{http_code}' --max-time 45 \
    ${auth:+-H "Authorization: ${auth}"} \
    -H "Content-Type: application/json" \
    -d "$body" "$url" 2>/dev/null || echo 000)"
  snippet="$(python3 - /tmp/gov-probe-$$.json <<'PY' 2>/dev/null || echo ERR
import json, sys
p = sys.argv[1]
try:
    d = json.load(open(p))
except Exception:
    print("ERR")
    raise SystemExit
if "error" in d:
    e = d["error"]
    msg = e.get("message", str(e)) if isinstance(e, dict) else str(e)
    print(("QUOTA" if any(x in msg.lower() for x in ("quota","429","rate","limit","1310")) else "ERR") + ":" + msg[:60])
elif d.get("choices"):
    c = d["choices"][0].get("message", {}).get("content", "")
    print("OK:" + (c or "empty")[:20])
else:
    print("ERR:unknown")
PY
)"
  rm -f /tmp/gov-probe-$$.json
  if [[ "$code" == "200" && "$snippet" == OK:* ]]; then
    printf 'OK'
  elif [[ "$code" == "429" || "$snippet" == QUOTA:* ]]; then
    printf 'QUOTA'
  elif [[ "$code" == "401" || "$code" == "403" ]]; then
    printf 'AUTH'
  else
    printf 'FAIL:%s' "$code"
  fi
}

probe_tier() {
  local tier="$1" csv="$2"
  local -a models result=()
  IFS=',' read -r -a models <<< "$csv"
  local ok=0 quota=0 fail=0 m st
  for m in "${models[@]}"; do
    m="${m// /}"
    [[ -n "$m" ]] || continue
    st="$(probe_model "$m")"
    result+=("${m}:${st}")
    case "$st" in
      OK) ok=$((ok + 1)) ;;
      QUOTA) quota=$((quota + 1)) ;;
      *) fail=$((fail + 1)) ;;
    esac
  done
  TIER_RESULTS["$tier"]="$(IFS=,; echo "${result[*]}")"
  TIER_OK["$tier"]="$ok"
  TIER_QUOTA["$tier"]="$quota"
  TIER_FAIL["$tier"]="$fail"
}

fetch_spend() {
  local auth resp
  auth="$(master_auth_header)"
  [[ -n "$auth" ]] || { GLOBAL_SPEND="null"; return; }
  resp="$(curl -sS --max-time 20 -H "Authorization: ${auth}" "${GATEWAY%/}/global/spend" 2>/dev/null || echo '{}')"
  GLOBAL_SPEND="$(printf '%s' "$resp" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print("null")
    raise SystemExit
if isinstance(d, dict):
    for k in ("spend", "total_spend", "global_spend"):
        if k in d:
            print(d[k])
            raise SystemExit
    print(json.dumps(d))
else:
    print(d)
' 2>/dev/null || echo "null")"
}

decide_action() {
  if [[ "$SKIP_PROBE" -eq 1 ]]; then
    ACTION="skipped"
    REASON="Probe omitido (--skip-probe)"
    return
  fi

  local t3_ok="${TIER_OK[T3]:-0}"
  local t5_ok="${TIER_OK[T5]:-0}"
  local t3_quota="${TIER_QUOTA[T3]:-0}"

  if [[ "${GATEWAY_OK:-0}" -eq 0 ]]; then
    ACTION="critical"
    REASON="LiteLLM gateway inacessível"
    return
  fi

  if [[ "$t3_ok" -eq 0 && "$t3_quota" -ge 1 && "$t5_ok" -ge 1 ]]; then
    ACTION="free-tier"
    REASON="T3 paid em quota; T5 free disponível"
    return
  fi

  if [[ "$t3_ok" -eq 0 && "$t5_ok" -eq 0 ]]; then
    ACTION="degraded"
    REASON="T3 e T5 indisponíveis"
    return
  fi

  if [[ -n "${GLOBAL_SPEND:-}" && "${GLOBAL_SPEND}" != "null" ]]; then
    local spend_num
    spend_num="$(python3 -c "import sys; v=sys.argv[1]; print(float(v) if v.replace('.','',1).isdigit() else -1)" "${GLOBAL_SPEND}" 2>/dev/null || echo -1)"
    if [[ "$spend_num" != "-1" ]] && python3 -c "import sys; sys.exit(0 if float(sys.argv[1]) >= float(sys.argv[2]) else 1)" "$spend_num" "$SPEND_WARN_USD" 2>/dev/null; then
      ACTION="warn-spend"
      REASON="Spend global ${GLOBAL_SPEND} >= warn ${SPEND_WARN_USD}"
      return
    fi
  fi

  ACTION="ok"
  REASON="Tiers dentro da política"
}

apply_hermes_free_tier() {
  # Budget baixo → free NO-LOGGING (data_collection=deny, custo $0) + fallback local.
  # Seguro p/ dados AGL (não usa owl-alpha/nemotron que logam). Não cai para paid.
  local fix_script="${REPO_ROOT}/scripts/proxmox/hermes-openrouter-free-ct188.sh"
  [[ -f "$fix_script" ]] || { log "ERRO: fix script em falta"; return 1; }
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[dry-run] Hermes free no-logging via ${HERMES_SSH_HOST}"
    return 0
  fi
  if [[ -d /opt/agl-hermes ]]; then
    log "Aplicar Hermes free no-logging local (CT188)"
    bash "$fix_script"
    return
  fi
  log "Aplicar Hermes free no-logging remoto ${HERMES_SSH_HOST}"
  scp -q "$fix_script" "${HERMES_SSH_HOST}:/tmp/hermes-openrouter-free-ct188.sh"
  ssh -o BatchMode=yes -o ConnectTimeout=20 "${HERMES_SSH_HOST}" "bash /tmp/hermes-openrouter-free-ct188.sh"
}

send_notify() {
  local severity title body
  case "$ACTION" in
    critical) severity="critical" ;;
    free-tier|degraded) severity="warn" ;;
    warn-spend) severity="warn" ;;
    *) return 0 ;;
  esac
  title="Quota Governor: ${ACTION}"
  body="Gateway: ${GATEWAY}
Reason: ${REASON}
T3: ${TIER_RESULTS[T3]:-}
T5: ${TIER_RESULTS[T5]:-}
Spend: ${GLOBAL_SPEND:-n/a}"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[dry-run] notify ${severity}: ${title}"
    return 0
  fi
  bash "${REPO_ROOT}/scripts/monitoring/agl-alert-notify.sh" \
    --severity "$severity" --title "$title" --body "$body" || true
}

write_state() {
  local ts dir tmp
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  dir="$(dirname "$STATE_FILE")"
  mkdir -p "$dir" 2>/dev/null || STATE_FILE="/tmp/quota-governor-state.json"
  tmp="$(mktemp)"
  cat >"$tmp" <<EOF
timestamp=${ts}
gateway=${GATEWAY}
gateway_ok=${GATEWAY_OK}
action=${ACTION}
reason=${REASON}
global_spend=${GLOBAL_SPEND:-}
hermes_applied=${HERMES_APPLIED}
state_file=${STATE_FILE}
t3_ok=${TIER_OK[T3]:-0}
t3_quota=${TIER_QUOTA[T3]:-0}
t3_fail=${TIER_FAIL[T3]:-0}
t3_detail=${TIER_RESULTS[T3]:-}
t4_ok=${TIER_OK[T4]:-0}
t4_quota=${TIER_QUOTA[T4]:-0}
t4_fail=${TIER_FAIL[T4]:-0}
t4_detail=${TIER_RESULTS[T4]:-}
t5_ok=${TIER_OK[T5]:-0}
t5_quota=${TIER_QUOTA[T5]:-0}
t5_fail=${TIER_FAIL[T5]:-0}
t5_detail=${TIER_RESULTS[T5]:-}
EOF
  python3 - "$tmp" "$STATE_FILE" <<'PY'
import json, sys
cfg = {}
for line in open(sys.argv[1]):
    line = line.strip()
    if not line or "=" not in line:
        continue
    k, v = line.split("=", 1)
    cfg[k] = v
state = {
    "timestamp": cfg.get("timestamp"),
    "gateway": cfg.get("gateway"),
    "gateway_ok": cfg.get("gateway_ok") == "1",
    "action": cfg.get("action"),
    "reason": cfg.get("reason"),
    "global_spend": cfg.get("global_spend"),
    "hermes_applied": cfg.get("hermes_applied") == "1",
    "tiers": {
        "T3": {"ok": int(cfg.get("t3_ok", 0)), "quota": int(cfg.get("t3_quota", 0)), "fail": int(cfg.get("t3_fail", 0)), "detail": cfg.get("t3_detail", "")},
        "T4": {"ok": int(cfg.get("t4_ok", 0)), "quota": int(cfg.get("t4_quota", 0)), "fail": int(cfg.get("t4_fail", 0)), "detail": cfg.get("t4_detail", "")},
        "T5": {"ok": int(cfg.get("t5_ok", 0)), "quota": int(cfg.get("t5_quota", 0)), "fail": int(cfg.get("t5_fail", 0)), "detail": cfg.get("t5_detail", "")},
    },
}
with open(sys.argv[2], "w") as f:
    json.dump(state, f, indent=2)
print(json.dumps(state))
PY
  rm -f "$tmp"
}

declare -A TIER_RESULTS TIER_OK TIER_QUOTA TIER_FAIL
GLOBAL_SPEND=""
ACTION="unknown"
REASON=""
GATEWAY_OK=0
HERMES_APPLIED=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --apply-hermes) APPLY_HERMES=1; shift ;;
    --notify) NOTIFY=1; shift ;;
    --json) JSON_OUT=1; shift ;;
    --skip-probe) SKIP_PROBE=1; shift ;;
    -h|--help) usage ;;
    *) log "Opção desconhecida: $1"; usage ;;
  esac
done

load_env

if curl -sf --max-time 8 "${GATEWAY%/}/health/liveliness" >/dev/null 2>&1; then
  GATEWAY_OK=1
else
  log "WARN: gateway health FAIL ${GATEWAY}"
fi

if [[ "$SKIP_PROBE" -eq 0 && "$GATEWAY_OK" -eq 1 ]]; then
  probe_tier T3 "$PROBE_T3"
  probe_tier T4 "$PROBE_T4"
  probe_tier T5 "$PROBE_T5"
  fetch_spend
else
  log "Probe omitido (skip=$SKIP_PROBE gateway_ok=$GATEWAY_OK)"
fi

decide_action

if [[ "$ACTION" == "free-tier" && "$APPLY_HERMES" -eq 1 ]]; then
  apply_hermes_free_tier && HERMES_APPLIED=1
fi

[[ "$NOTIFY" -eq 1 ]] && send_notify

if [[ "$JSON_OUT" -eq 1 ]]; then
  write_state | tail -1
else
  write_state >/dev/null
  cat <<REPORT
ACTION: ${ACTION}
REASON: ${REASON}
GATEWAY: ${GATEWAY} (ok=${GATEWAY_OK})
T3: ${TIER_RESULTS[T3]:-skipped}
T4: ${TIER_RESULTS[T4]:-skipped}
T5: ${TIER_RESULTS[T5]:-skipped}
SPEND: ${GLOBAL_SPEND:-n/a}
STATE: ${STATE_FILE}
HERMES_APPLIED: ${HERMES_APPLIED}
REPORT
fi

case "$ACTION" in
  critical) exit 2 ;;
  degraded|free-tier)
    [[ "$DRY_RUN" -eq 1 || "$SKIP_PROBE" -eq 1 ]] && exit 0
    exit 1
    ;;
  *) exit 0 ;;
esac
