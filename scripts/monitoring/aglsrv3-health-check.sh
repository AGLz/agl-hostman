#!/usr/bin/env bash
# Monitorização AGLSRV3 — host, CTs, VM310, man3, Ollama, ZFS + alertas Telegram.
#
# Uso:
#   ./scripts/monitoring/aglsrv3-health-check.sh              # check + alerta se FAIL
#   ./scripts/monitoring/aglsrv3-health-check.sh --check-only   # sem Telegram
#   ./scripts/monitoring/aglsrv3-health-check.sh --json
#   ./scripts/monitoring/aglsrv3-health-check.sh --test-alert   # força notificação
#
# Cron (agldv03): scripts/monitoring/install-aglsrv3-monitor-cron.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
TARGETS="${AGLSRV3_TARGETS:-$REPO_ROOT/config/monitoring/aglsrv3-health-targets.json}"
NOTIFY_SCRIPT="$SCRIPT_DIR/agl-alert-notify.sh"
RESULTS_FILE="$(mktemp)"

CHECK_ONLY=0
JSON_OUT=0
TEST_ALERT=0
DRY_RUN="${AGLSRV3_DRY_RUN:-0}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check-only) CHECK_ONLY=1; shift ;;
    --json) JSON_OUT=1; shift ;;
    --test-alert) TEST_ALERT=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Argumento desconhecido: $1" >&2; exit 2 ;;
  esac
done

: >"$RESULTS_FILE"
trap 'rm -f "$RESULTS_FILE"' EXIT

log() { echo "[aglsrv3-health] $*"; }

record() {
  local status="$1" id="$2" detail="${3:-}"
  detail="${detail//$'\n'/ }"
  printf '%s\t%s\t%s\n' "$status" "$id" "$detail" >>"$RESULTS_FILE"
}

load_config() {
  python3 - "$TARGETS" <<'PY'
import json, sys
c = json.load(open(sys.argv[1]))
print(c["host"]["tailscale"])
print(c["host"]["ssh"])
print(c["antiFlapping"]["consecutiveFailuresBeforeAlert"])
print(c["antiFlapping"]["minMinutesBetweenRepeatAlert"])
print(c["antiFlapping"]["stateDir"])
print(c["zfs"]["pool"])
print(c["ollama"]["tailscale_api"])
print(c["dns"]["server"])
PY
}

if ! python3 -c "import json; json.load(open('$TARGETS'))" 2>/dev/null; then
  echo "ERRO: JSON inválido em $TARGETS" >&2
  exit 2
fi

mapfile -t CFG < <(load_config)
TS_HOST="${CFG[0]}"
SSH_HOST="${CFG[1]}"
FAIL_THRESHOLD="${CFG[2]}"
REPEAT_MINUTES="${CFG[3]}"
STATE_DIR="${CFG[4]}"
ZFS_POOL="${CFG[5]}"
OLLAMA_URL="${CFG[6]}"
DNS_SERVER="${CFG[7]}"

ssh_run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    return 1
  fi
  ssh -o BatchMode=yes -o ConnectTimeout=12 "$SSH_HOST" "$@" 2>/dev/null
}

state_file() { echo "${STATE_DIR}/$(echo "$1" | tr '/ ' '__').fail"; }
alert_file() { echo "${STATE_DIR}/$(echo "$1" | tr '/ ' '__').lastalert"; }

bump_failure() {
  local id="$1"
  local sf fail
  sf="$(state_file "$id")"
  mkdir -p "$STATE_DIR"
  fail=0
  [[ -f "$sf" ]] && fail=$(<"$sf") || true
  fail=$((fail + 1))
  echo "$fail" >"$sf"
  echo "$fail"
}

reset_failure() {
  local id="$1"
  rm -f "$(state_file "$id")"
}

should_alert() {
  local id="$1" fails="$2"
  local af last now min_secs
  [[ "$fails" -ge "$FAIL_THRESHOLD" ]] || return 1
  af="$(alert_file "$id")"
  last=0
  [[ -f "$af" ]] && last=$(<"$af") || true
  now=$(date +%s)
  min_secs=$((REPEAT_MINUTES * 60))
  [[ $((now - last)) -ge $min_secs ]]
}

mark_alerted() {
  local id="$1"
  date +%s >"$(alert_file "$id")"
}

ping_host() {
  local id="host-tailscale"
  if [[ "$DRY_RUN" == "1" ]]; then
    record "SKIP" "$id" "dry-run"
    return 0
  fi
  if ping -c1 -W4 "$TS_HOST" &>/dev/null; then
    record "OK" "$id" "ping $TS_HOST"
    reset_failure "$id"
    return 0
  fi
  local fails
  fails="$(bump_failure "$id")"
  record "FAIL" "$id" "sem ping $TS_HOST (falhas consecutivas=$fails)"
  return 1
}

check_ssh_reachable() {
  local id="host-ssh"
  if [[ "$DRY_RUN" == "1" ]]; then
    record "SKIP" "$id" "dry-run"
    return 0
  fi
  if ssh_run "uptime -s >/dev/null"; then
    record "OK" "$id" "SSH $SSH_HOST"
    reset_failure "$id"
    return 0
  fi
  local fails
  fails="$(bump_failure "$id")"
  record "FAIL" "$id" "SSH indisponível $SSH_HOST (falhas=$fails)"
  return 1
}

check_containers() {
  local vmid name svc id st svc_st line fails
  local -a lines=()
  mapfile -t lines < <(python3 -c "
import json
for c in json.load(open('$TARGETS')).get('containers', []):
    print(c['vmid'], c['name'], c.get('systemd',''), sep='\t')
")
  for line in "${lines[@]}"; do
    IFS=$'\t' read -r vmid name svc <<<"$line"
    [[ -z "$vmid" ]] && continue
    id="ct${vmid}"
    if [[ "$DRY_RUN" == "1" ]]; then
      record "SKIP" "$id" "dry-run"
      continue
    fi
    st="$(ssh_run "pct status $vmid" | awk '/^status:/{print $2}')"
    if [[ "$st" != "running" ]]; then
      fails="$(bump_failure "$id")"
      record "FAIL" "$id" "CT$vmid ($name) status=$st falhas=$fails"
      continue
    fi
    if [[ -n "$svc" ]]; then
      svc_st="$(ssh_run "pct exec $vmid -- systemctl is-active $svc" 2>/dev/null || echo inactive)"
      if [[ "$svc_st" != "active" ]]; then
        fails="$(bump_failure "$id")"
        record "FAIL" "$id" "CT$vmid $svc=$svc_st falhas=$fails"
        continue
      fi
    fi
    record "OK" "$id" "CT$vmid $name running${svc:+ $svc=active}"
    reset_failure "$id"
  done
}

check_vms() {
  local vmid name expect id st fails line
  local -a lines=()
  mapfile -t lines < <(python3 -c "
import json
for v in json.load(open('$TARGETS')).get('vms', []):
    print(v['vmid'], v['name'], v.get('expect','running'), sep='\t')
")
  for line in "${lines[@]}"; do
    IFS=$'\t' read -r vmid name expect <<<"$line"
    [[ -z "$vmid" ]] && continue
    id="vm${vmid}"
    if [[ "$DRY_RUN" == "1" ]]; then
      record "SKIP" "$id" "dry-run"
      continue
    fi
    st="$(ssh_run "qm status $vmid" | awk '/^status:/{print $2}')"
    if [[ "$st" == "$expect" ]]; then
      record "OK" "$id" "VM$vmid $name $st"
      reset_failure "$id"
    else
      fails="$(bump_failure "$id")"
      record "FAIL" "$id" "VM$vmid esperado=$expect actual=${st:-?} falhas=$fails"
    fi
  done
}

check_http() {
  local id url code expect
  while IFS=$'\t' read -r id url expect; do
    [[ -z "$id" ]] && continue
    if [[ "$DRY_RUN" == "1" ]]; then
      record "SKIP" "$id" "dry-run"
      continue
    fi
    code="$(curl -sk -o /dev/null -w '%{http_code}' --max-time 12 "$url" 2>/dev/null || echo 000)"
    if [[ "$code" == "$expect" ]]; then
      record "OK" "$id" "HTTP $code $url"
      reset_failure "$id"
    else
      local fails
      fails="$(bump_failure "$id")"
      record "FAIL" "$id" "HTTP $code (esperado $expect) $url falhas=$fails"
    fi
  done < <(python3 -c "
import json
for h in json.load(open('$TARGETS')).get('http', []):
    print(h['id'], h['url'], h.get('expect_code', 200), sep='\t')
")
}

check_ollama() {
  local id="ollama-vm310"
  if [[ "$DRY_RUN" == "1" ]]; then
    record "SKIP" "$id" "dry-run"
    return 0
  fi
  local body missing=()
  if ! body="$(curl -sf --max-time 12 "${OLLAMA_URL%/}/api/tags" 2>/dev/null)"; then
    local fails
    fails="$(bump_failure "$id")"
    record "FAIL" "$id" "Ollama inacessível $OLLAMA_URL falhas=$fails"
    return 0
  fi
  while IFS= read -r m; do
    [[ -z "$m" ]] && continue
    if ! echo "$body" | python3 -c "import json,sys; names=[x.get('name') for x in json.load(sys.stdin).get('models',[])]; sys.exit(0 if sys.argv[1] in names else 1)" "$m" 2>/dev/null; then
      missing+=("$m")
    fi
  done < <(python3 -c "import json; print('\n'.join(json.load(open('$TARGETS'))['ollama'].get('expected_models',[])))")
  if [[ ${#missing[@]} -eq 0 ]]; then
    record "OK" "$id" "tags OK $OLLAMA_URL"
    reset_failure "$id"
  else
    local fails
    fails="$(bump_failure "$id")"
    record "WARN" "$id" "modelos em falta: ${missing[*]} falhas=$fails"
  fi
}

check_zfs() {
  local id="zfs-${ZFS_POOL}"
  if [[ "$DRY_RUN" == "1" ]]; then
    record "SKIP" "$id" "dry-run"
    return 0
  fi
  local out state cap
  out="$(ssh_run "zpool status -x $ZFS_POOL 2>/dev/null; zpool list -H -o capacity $ZFS_POOL 2>/dev/null")" || {
    local fails
    fails="$(bump_failure "$id")"
    record "FAIL" "$id" "zpool $ZFS_POOL indisponível falhas=$fails"
    return 0
  }
  if echo "$out" | grep -qE "'$ZFS_POOL' is healthy|all pools are healthy"; then
    state="ONLINE"
  else
    state="$(ssh_run "zpool list -H -o health $ZFS_POOL 2>/dev/null" | tr -d '[:space:]')"
    [[ -z "$state" ]] && state="UNKNOWN"
  fi
  cap="$(ssh_run "zpool list -H -o capacity $ZFS_POOL 2>/dev/null" | tr -d '%[:space:]')"
  if [[ "$state" == "DEGRADED" ]]; then
    local removed
    removed="$(ssh_run "zpool status $ZFS_POOL 2>/dev/null | grep -c REMOVED" || echo 0)"
    if [[ "${removed:-0}" -gt 0 ]]; then
      record "WARN" "$id" "DEGRADED — disco(s) REMOVED; cap=${cap:-?}% (intervir no site AGLFG)"
      return 0
    fi
  fi
  if [[ "$state" != "ONLINE" ]]; then
    fails="$(bump_failure "$id")"
    record "FAIL" "$id" "pool state=$state falhas=$fails"
    return 0
  fi
  local warn_pct
  warn_pct="$(python3 -c "import json; print(json.load(open('$TARGETS'))['zfs'].get('warn_capacity_pct',85))")"
  if [[ -n "$cap" && "$cap" -ge "$warn_pct" ]]; then
    record "WARN" "$id" "capacidade ${cap}% (limiar ${warn_pct}%)"
  else
    record "OK" "$id" "ONLINE cap=${cap:-?}%"
    reset_failure "$id"
  fi
}

check_dns() {
  local id="pihole-dns"
  if [[ "$DRY_RUN" == "1" ]]; then
    record "SKIP" "$id" "dry-run"
    return 0
  fi
  local ans
  ans="$(ssh_run "pct exec 317 -- dig +short @127.0.0.1 google.com A 2>/dev/null | head -1")"
  if [[ -n "$ans" ]]; then
    record "OK" "$id" "Pi-hole resolve google.com → $ans"
    reset_failure "$id"
  else
    local fails
    fails="$(bump_failure "$id")"
    record "FAIL" "$id" "DNS CT317 sem resposta falhas=$fails"
  fi
}

check_local_lvm() {
  local id="storage-local-lvm"
  if [[ "$DRY_RUN" == "1" ]]; then
    record "SKIP" "$id" "dry-run"
    return 0
  fi
  local pct warn_pct
  pct="$(ssh_run "pvesm status 2>/dev/null | awk '/^local-lvm/{gsub(/%/,\"\",\$NF); print \$NF}'")"
  warn_pct="$(python3 -c "import json; print(json.load(open('$TARGETS'))['storage'].get('local_lvm_warn_pct',85))")"
  if [[ -n "$pct" ]]; then
    local pct_int="${pct%%.*}"
    if [[ "$pct_int" -ge "$warn_pct" ]]; then
      record "WARN" "$id" "local-lvm ${pct}% (limiar ${warn_pct}%)"
    else
      record "OK" "$id" "local-lvm ${pct}%"
      reset_failure "$id"
    fi
  else
    record "WARN" "$id" "pvesm local-lvm indisponível"
  fi
}

send_alerts() {
  [[ "$CHECK_ONLY" -eq 1 && "$TEST_ALERT" -eq 0 ]] && return 0
  [[ -x "$NOTIFY_SCRIPT" ]] || { log "WARN: falta $NOTIFY_SCRIPT"; return 0; }

  if [[ "$TEST_ALERT" -eq 1 ]]; then
    bash "$NOTIFY_SCRIPT" --severity warn --title "Teste monitor AGLSRV3" --body "Alerta de teste $(date -Is)"
    return 0
  fi

  local st id det fails body alerts=0
  while IFS=$'\t' read -r st id det; do
    [[ -z "$st" ]] && continue
    [[ "$st" == "FAIL" ]] || continue
    fails="$(cat "$(state_file "$id")" 2>/dev/null || echo 0)"
    should_alert "$id" "$fails" || continue
    body="${body}• ${id}: ${det}"$'\n'
    mark_alerted "$id"
    alerts=$((alerts + 1))
  done <"$RESULTS_FILE"

  if [[ "$alerts" -gt 0 ]]; then
    bash "$NOTIFY_SCRIPT" \
      --severity critical \
      --title "AGLSRV3 — ${alerts} check(s) FAIL" \
      --body "${body%$'\n'}"
  fi
}

print_summary() {
  local ok=0 warn=0 fail=0 skip=0
  printf "\n%-8s %-22s %s\n" "ESTADO" "CHECK" "DETALHE"
  printf "%-8s %-22s %s\n" "------" "-----" "-------"
  while IFS=$'\t' read -r st id det; do
    [[ -z "$st" ]] && continue
    printf "%-8s %-22s %s\n" "$st" "$id" "$det"
    case "$st" in
      OK) ((ok++)) || true ;;
      WARN) ((warn++)) || true ;;
      FAIL) ((fail++)) || true ;;
      SKIP) ((skip++)) || true ;;
    esac
  done <"$RESULTS_FILE"
  log "Resumo: OK=$ok WARN=$warn FAIL=$fail SKIP=$skip"
  if [[ "$JSON_OUT" -eq 1 ]]; then
    python3 <<PY
import json, datetime
rows = []
with open("$RESULTS_FILE") as f:
    for line in f:
        line=line.rstrip("\n")
        if not line: continue
        st, cid, det = (line.split("\t", 2) + ["", "", ""])[:3]
        rows.append({"status": st, "id": cid, "detail": det})
print(json.dumps({
    "timestamp": datetime.datetime.utcnow().replace(microsecond=0).isoformat() + "Z",
    "host": "aglsrv3",
    "summary": {"ok": $ok, "warn": $warn, "fail": $fail, "skip": $skip},
    "checks": rows,
}, ensure_ascii=False))
PY
  fi
  [[ "$fail" -eq 0 ]]
}

main() {
  log "Alvos: $TARGETS | check_only=$CHECK_ONLY notify=$([[ $CHECK_ONLY -eq 0 ]] && echo 1 || echo 0)"
  ping_host || true
  if ping -c1 -W2 "$TS_HOST" &>/dev/null; then
    check_ssh_reachable || true
    check_containers
    check_vms
    check_zfs
    check_local_lvm
    check_dns
  else
    record "SKIP" "guests" "host down — CT/VM/ZFS/DNS omitidos"
  fi
  check_http
  check_ollama
  send_alerts
  print_summary
}

main
