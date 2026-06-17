#!/usr/bin/env bash
# Verificação unificada da infra AGL — rede, LiteLLM CT186, Ollama VM110/VM310 (GPU), satélites.
#
# Uso:
#   ./scripts/infra/verify-agl-health.sh              # todas as fases
#   ./scripts/infra/verify-agl-health.sh --quick      # sem smoke chat LiteLLM
#   ./scripts/infra/verify-agl-health.sh --json       # resumo JSON em stdout
#   ./scripts/infra/verify-agl-health.sh --phase litellm
#   PHASE=network,ollama ./scripts/infra/verify-agl-health.sh
#   VERIFY_AGL_DRY_RUN=1 ./scripts/infra/verify-agl-health.sh
#
# Exit: 0 = sem FAIL; 1 = há FAIL ou WARN (com --strict); 2 = erro de config/args
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
TARGETS="${VERIFY_AGL_TARGETS:-$REPO_ROOT/config/monitoring/agl-health-targets.json}"
RESULTS_FILE="${VERIFY_AGL_RESULTS_FILE:-$(mktemp)}"
ENV_FILE="${LITELLM_ENV_FILE:-$REPO_ROOT/config/litellm/.env}"

QUICK=0
JSON_OUT=0
STRICT=0
DRY_RUN="${VERIFY_AGL_DRY_RUN:-0}"
PHASES="${PHASE:-all}"

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --quick) QUICK=1; shift ;;
    --json) JSON_OUT=1; shift ;;
    --strict) STRICT=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --phase) PHASES="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Argumento desconhecido: $1" >&2; usage ;;
  esac
done

: >"$RESULTS_FILE"

log() { echo "[verify-agl] $*"; }

record() {
  local status="$1" id="$2" detail="${3:-}"
  detail="${detail//$'\n'/ }"
  printf '%s\t%s\t%s\n' "$status" "$id" "$detail" >>"$RESULTS_FILE"
}

phase_enabled() {
  local p="$1"
  [[ "$PHASES" == "all" ]] && return 0
  [[ ",$PHASES," == *",$p,"* ]]
}

ping_host() {
  local id="$1" ip="$2"
  if [[ "$DRY_RUN" == "1" ]]; then
    record "SKIP" "$id" "dry-run ping $ip"
    return 0
  fi
  if ping -c1 -W3 "$ip" &>/dev/null; then
    record "OK" "$id" "ping $ip"
  else
    record "FAIL" "$id" "sem resposta ping $ip"
  fi
}

curl_check() {
  local on_fail="$1" id="$2" url="$3" timeout="${4:-8}"
  if [[ "$DRY_RUN" == "1" ]]; then
    record "SKIP" "$id" "dry-run GET $url"
    return 0
  fi
  local code
  code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time "$timeout" "$url" 2>/dev/null || echo 000)"
  if [[ "$code" == "200" ]]; then
    record "OK" "$id" "HTTP $code $url"
  else
    record "$on_fail" "$id" "HTTP $code $url"
  fi
}

ssh_qm_status() {
  local severity="$1" id="$2" ssh_host="$3" vmid="$4" expect="${5:-running}"
  if [[ "$DRY_RUN" == "1" ]]; then
    record "SKIP" "$id" "dry-run qm status $vmid @ $ssh_host"
    return 0
  fi
  local out st
  if ! out="$(ssh -o BatchMode=yes -o ConnectTimeout=10 "$ssh_host" "qm status $vmid" 2>/dev/null)"; then
    record "FAIL" "$id" "SSH ou qm indisponível ($ssh_host VM$vmid)"
    return 0
  fi
  st="$(echo "$out" | awk '/^status:/{print $2}')"
  if [[ "$st" == "$expect" ]]; then
    record "OK" "$id" "VM$vmid $st"
  else
    record "$severity" "$id" "VM$vmid esperado=$expect actual=$st"
  fi
}

ollama_tags_check() {
  local severity="$1" id="$2" base="$3" shift_models=("${@:4}")
  if [[ "$DRY_RUN" == "1" ]]; then
    record "SKIP" "$id" "dry-run Ollama $base"
    return 0
  fi
  local body
  if ! body="$(curl -sf --max-time 12 "${base%/}/api/tags" 2>/dev/null)"; then
    record "FAIL" "$id" "Ollama inacessível $base"
    return 0
  fi
  local missing=()
  local m
  for m in "${shift_models[@]}"; do
    if ! echo "$body" | python3 -c "import json,sys; names=[x.get('name') for x in json.load(sys.stdin).get('models',[])]; sys.exit(0 if sys.argv[1] in names else 1)" "$m" 2>/dev/null; then
      missing+=("$m")
    fi
  done
  if [[ ${#missing[@]} -eq 0 ]]; then
    record "OK" "$id" "tags OK em $base (${shift_models[*]})"
  else
    record "$severity" "$id" "modelos em falta em $base: ${missing[*]}"
  fi
}

vm110_gpu_check() {
  local id="vm110-gpu"
  local ssh_host
  ssh_host="$(python3 -c "import json; c=json.load(open('$TARGETS')); print(c['hosts']['aglsrv1']['ssh'])" 2>/dev/null || echo 'root@100.107.113.33')"
  local vmid
  vmid="$(python3 -c "import json; c=json.load(open('$TARGETS')); print(c['ollama']['vm110']['vmid'])" 2>/dev/null || echo 110)"
  if [[ "$DRY_RUN" == "1" ]]; then
    record "SKIP" "$id" "dry-run nvidia-smi guest VM$vmid"
    return 0
  fi
  local raw
  if ! raw="$(ssh -o BatchMode=yes -o ConnectTimeout=12 "$ssh_host" \
    "qm guest exec $vmid -- nvidia-smi --query-gpu=name,driver_version,memory.used --format=csv,noheader 2>/dev/null" 2>/dev/null)"; then
    record "WARN" "$id" "guest exec nvidia-smi indisponível (VM parada ou sem agent?)"
    return 0
  fi
  local parsed
  parsed="$(printf '%s' "$raw" | python3 -c "
import json, sys
raw = sys.stdin.read()
try:
    j = json.loads(raw)
except json.JSONDecodeError:
    line = raw.replace(chr(10), ' ')[:200]
    print('PLAIN\t' + line)
    raise SystemExit(0)
exitcode = j.get('exitcode', j.get('exit-code', 1))
out = (j.get('out-data') or j.get('out-truncated') or '').strip()
err = (j.get('err-data') or '').strip()
if exitcode == 0 and out:
    print('OK\t' + out.replace(chr(10), ' | ')[:200])
elif err:
    print('ERR\t' + err.replace(chr(10), ' ')[:200])
else:
    print('ERR\texit=' + str(exitcode) + ' out=' + out[:120])
" 2>/dev/null || echo "ERR	parse falhou")"
  local kind detail
  kind="${parsed%%$'\t'*}"
  detail="${parsed#*$'\t'}"
  if [[ "$kind" == "OK" ]] && echo "$detail" | grep -qiE 'GTX|NVIDIA|GeForce|RTX|Quadro|Tesla'; then
    record "OK" "$id" "$detail"
  elif [[ "$kind" == "PLAIN" ]] && echo "$detail" | grep -qiE 'GTX|NVIDIA|GeForce|RTX'; then
    record "OK" "$id" "$detail"
  else
    record "WARN" "$id" "${detail:-nvidia-smi sem GPU NVIDIA visível}"
  fi
}

vm310_gpu1_check() {
  local id="vm310-gpu1"
  if [[ "$DRY_RUN" == "1" ]]; then
    record "SKIP" "$id" "dry-run verify-vm310-gpu1-ready"
    return 0
  fi
  if bash "$REPO_ROOT/scripts/aglsrv3/verify-vm310-gpu1-ready.sh" &>/dev/null; then
    record "OK" "$id" "amdgpu GPU1 + :11435"
  else
    record "WARN" "$id" "GPU1 amdgpu ou :11435 inactivo (GPU0 pode bastar)"
  fi
}

litellm_smoke() {
  local model="$1"
  local id="litellm-smoke-$model"
  if [[ "$DRY_RUN" == "1" ]]; then
    record "SKIP" "$id" "dry-run smoke $model"
    return 0
  fi
  if LITELLM_ENV_FILE="$ENV_FILE" LITELLM_URL="${LITELLM_URL:-http://100.125.249.8:4000}" \
    bash "$REPO_ROOT/scripts/litellm/test-ollama-litellm-content.sh" "$model" &>/dev/null; then
    record "OK" "$id" "content OK via proxy"
  else
    record "FAIL" "$id" "smoke falhou ($model)"
  fi
}

meshagent_leak_check() {
  local id="aglsrv1-meshagent-leak"
  local ssh_host
  ssh_host="$(python3 -c "import json; c=json.load(open('$TARGETS')); print(c['hosts']['aglsrv1']['ssh'])" 2>/dev/null || echo 'root@100.107.113.33')"
  if [[ "$DRY_RUN" == "1" ]]; then
    record "SKIP" "$id" "dry-run meshagent RSS"
    return 0
  fi
  local leaks
  leaks="$(ssh -o BatchMode=yes -o ConnectTimeout=10 "$ssh_host" \
    "ps aux | grep meshagent | grep -v grep | awk '{if (\$6 > 1000000) print \$2, int(\$6/1024)\"MB\"}'" 2>/dev/null || true)"
  if [[ -z "$leaks" ]]; then
    record "OK" "$id" "sem leaks >1GB"
  else
    record "WARN" "$id" "meshagent leak: $(echo "$leaks" | tr '\n' ' ' | head -c 100)"
  fi
}

load_targets() {
  if [[ ! -f "$TARGETS" ]]; then
    echo "ERRO: falta $TARGETS" >&2
    exit 2
  fi
  python3 -c "import json; json.load(open('$TARGETS'))" || {
    echo "ERRO: JSON inválido em $TARGETS" >&2
    exit 2
  }
}

run_network() {
  log "=== Rede (Tailscale ping) ==="
  ping_host "host-aglsrv1" "$(python3 -c "import json; print(json.load(open('$TARGETS'))['hosts']['aglsrv1']['tailscale'])")"
  ping_host "host-aglsrv3" "$(python3 -c "import json; print(json.load(open('$TARGETS'))['hosts']['aglsrv3']['tailscale'])")"
  ping_host "host-agldv03" "$(python3 -c "import json; print(json.load(open('$TARGETS'))['hosts']['agldv03']['tailscale'])")"
  ping_host "host-litellm-ct186" "$(python3 -c "import json; u=json.load(open('$TARGETS'))['litellm']['readiness_primary']; print(u.split('//')[1].split(':')[0])")"
  ping_host "host-vm310" "$(python3 -c "import json; u=json.load(open('$TARGETS'))['ollama']['vm310']['tailscale_gpu0']; print(u.split('//')[1].split(':')[0])")"
  ping_host "host-vm110" "$(python3 -c "import json; u=json.load(open('$TARGETS'))['ollama']['vm110']['tailscale_api']; print(u.split('//')[1].split(':')[0])")"
}

run_litellm() {
  log "=== LiteLLM CT186 ==="
  local readiness liveliness
  readiness="$(python3 -c "import json; print(json.load(open('$TARGETS'))['litellm']['readiness_primary'])")"
  liveliness="$(python3 -c "import json; print(json.load(open('$TARGETS'))['litellm']['liveliness'])")"
  curl_check "OK" "litellm-readiness" "$readiness" 10
  curl_check "OK" "litellm-liveliness" "$liveliness" 10
  if [[ "$QUICK" -eq 0 ]]; then
    while IFS= read -r model; do
      [[ -n "$model" ]] && litellm_smoke "$model"
    done < <(python3 -c "import json; print('\n'.join(json.load(open('$TARGETS'))['litellm']['ollama_smoke_models']))")
  fi
}

run_ollama() {
  log "=== Ollama VM110 / VM310 ==="
  local v110_base v310_g0 v310_g1
  v110_base="$(python3 -c "import json; print(json.load(open('$TARGETS'))['ollama']['vm110']['tailscale_api'])")"
  v310_g0="$(python3 -c "import json; print(json.load(open('$TARGETS'))['ollama']['vm310']['tailscale_gpu0'])")"
  v310_g1="$(python3 -c "import json; print(json.load(open('$TARGETS'))['ollama']['vm310']['tailscale_gpu1'])")"
  read -ra m110 <<< "$(python3 -c "import json; print(' '.join(json.load(open('$TARGETS'))['ollama']['vm110']['expected_models']))")"
  read -ra m310g0 <<< "$(python3 -c "import json; print(' '.join(json.load(open('$TARGETS'))['ollama']['vm310']['expected_models_gpu0']))")"
  read -ra m310g1 <<< "$(python3 -c "import json; print(' '.join(json.load(open('$TARGETS'))['ollama']['vm310']['expected_models_gpu1']))")"

  ollama_tags_check "OK" "vm110-ollama" "$v110_base" "${m110[@]}"
  vm110_gpu_check
  ollama_tags_check "WARN" "vm310-ollama-gpu0" "$v310_g0" "${m310g0[@]}"
  ollama_tags_check "WARN" "vm310-ollama-gpu1" "$v310_g1" "${m310g1[@]}"
  vm310_gpu1_check
}

run_proxmox() {
  log "=== Proxmox VMs ==="
  local ssh1 ssh3 vm110 vm310 expect
  ssh1="$(python3 -c "import json; print(json.load(open('$TARGETS'))['hosts']['aglsrv1']['ssh'])")"
  ssh3="$(python3 -c "import json; print(json.load(open('$TARGETS'))['hosts']['aglsrv3']['ssh'])")"
  vm110="$(python3 -c "import json; print(json.load(open('$TARGETS'))['ollama']['vm110']['vmid'])")"
  vm310="$(python3 -c "import json; print(json.load(open('$TARGETS'))['ollama']['vm310']['vmid'])")"
  ssh_qm_status "WARN" "vm110-proxmox" "$ssh1" "$vm110" "running"
  ssh_qm_status "WARN" "vm310-proxmox" "$ssh3" "$vm310" "running"
}

run_services() {
  log "=== Serviços satélite ==="
  while IFS=$'\t' read -r sev sid url; do
    [[ -z "$sid" ]] && continue
    if [[ "$sev" == "fail" ]]; then
      curl_check "FAIL" "$sid" "$url" 8
    else
      curl_check "WARN" "$sid" "$url" 8
    fi
  done < <(python3 -c "
import json
for s in json.load(open('$TARGETS')).get('services', []):
    print(s.get('severity', 'warn'), s['id'], s['url'], sep='\t')
")
}

run_hosts() {
  log "=== Host AGLSRV1 (meshagent) ==="
  meshagent_leak_check
}

print_human_summary() {
  local ok=0 warn=0 fail=0 skip=0
  printf "\n%-10s %-28s %s\n" "ESTADO" "CHECK" "DETALHE"
  printf "%-10s %-28s %s\n" "------" "-----" "-------"
  while IFS=$'\t' read -r st id det; do
    [[ -z "$st" ]] && continue
    printf "%-10s %-28s %s\n" "$st" "$id" "$det"
    case "$st" in
      OK) ((ok++)) || true ;;
      WARN) ((warn++)) || true ;;
      FAIL) ((fail++)) || true ;;
      SKIP) ((skip++)) || true ;;
    esac
  done <"$RESULTS_FILE"
  echo ""
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
summary = {"ok": $ok, "warn": $warn, "fail": $fail, "skip": $skip}
print(json.dumps({
    "timestamp": datetime.datetime.utcnow().replace(microsecond=0).isoformat() + "Z",
    "targets": "$TARGETS",
    "summary": summary,
    "checks": rows,
}, ensure_ascii=False))
PY
  fi
  if [[ "$fail" -gt 0 ]]; then
    return 1
  fi
  if [[ "$STRICT" -eq 1 && "$warn" -gt 0 ]]; then
    return 1
  fi
  return 0
}

main() {
  load_targets
  trap 'rm -f "$RESULTS_FILE"' EXIT
  log "Alvos: $TARGETS | quick=$QUICK dry_run=$DRY_RUN phases=$PHASES"
  phase_enabled network && run_network
  phase_enabled litellm && run_litellm
  phase_enabled ollama && run_ollama
  phase_enabled proxmox && run_proxmox
  phase_enabled services && run_services
  phase_enabled hosts && run_hosts
  print_human_summary
}

main
