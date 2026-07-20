#!/usr/bin/env bash
# Health check profundo das GPUs Ollama AGL — VM110 (AGLSRV1/GTX1650) + VM310 (AGLSRV3/RX580).
#
# Verifica (por VM):
#   1) hostpci presente no qm config
#   2) GPU no host: config PCI != 0xFF (D3cold), driver vfio-pci
#   3) guest: dispositivo real (não só Virtio)
#   4) Ollama: size_vram > 0 ou PROCESSOR com % GPU
#
# Uso:
#   bash scripts/monitoring/check-agl-gpu-health.sh
#   bash scripts/monitoring/check-agl-gpu-health.sh --json
#   bash scripts/monitoring/check-agl-gpu-health.sh --notify   # Telegram se FAIL
#   CHECK_ONLY=1 bash ...   # sem notify
#
# Exit: 0=tudo OK/WARN, 1=pelo menos um FAIL crítico
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
NOTIFY_SCRIPT="${NOTIFY_SCRIPT:-$SCRIPT_DIR/agl-alert-notify.sh}"

JSON=0
NOTIFY=0
CHECK_ONLY="${CHECK_ONLY:-0}"

for arg in "$@"; do
  case "$arg" in
    --json) JSON=1 ;;
    --notify) NOTIFY=1 ;;
    --check-only) CHECK_ONLY=1 ;;
  esac
done
[[ "$CHECK_ONLY" == "1" ]] && NOTIFY=0

AGLSRV1="${AGLSRV1:-root@100.107.113.33}"
AGLSRV3="${AGLSRV3:-root@100.123.5.81}"
VM110_TS="${VM110_TS:-http://100.74.118.51:11434}"
VM310_TS="${VM310_TS:-http://100.67.253.52:11434}"

FAILS=0
WARNS=0
RESULTS=()

log_line() {
  local sev="$1" id="$2" msg="$3"
  RESULTS+=("${sev}|${id}|${msg}")
  if [[ "$JSON" -eq 0 ]]; then
    printf '[%s] %-18s %s\n' "$sev" "$id" "$msg"
  fi
  case "$sev" in
    FAIL) FAILS=$((FAILS + 1)) ;;
    WARN) WARNS=$((WARNS + 1)) ;;
  esac
}

ssh_host() {
  ssh -o BatchMode=yes -o ConnectTimeout=12 "$@"
}

# --- Host PCI: D3cold = config space all 0xFF ---
check_host_pci() {
  local id="$1" host="$2" bdf="$3" expect_driver="${4:-vfio-pci}"
  local out
  out="$(ssh_host "$host" bash -s -- "$bdf" "$expect_driver" <<'REMOTE' || true
set -euo pipefail
BDF="$1"
EXPECT="$2"
DEV="/sys/bus/pci/devices/${BDF}"
if [[ ! -e "$DEV" ]]; then
  echo "MISSING"
  exit 0
fi
# config space all FF → device dead (D3cold / Unknown header type 7f)
cfg="$(od -An -tx1 -N16 "$DEV/config" 2>/dev/null | tr -d ' \n')"
if [[ "$cfg" =~ ^[fF]{32}$ ]]; then
  echo "D3COLD"
  exit 0
fi
drv="$(basename "$(readlink -f "$DEV/driver" 2>/dev/null || echo none)")"
lspci_line="$(lspci -nn -s "${BDF#0000:}" 2>/dev/null | head -1)"
echo "OK|${drv}|${lspci_line}"
REMOTE
)"
  case "$out" in
    MISSING) log_line "FAIL" "$id" "PCI ${bdf} ausente no host (D3cold total / slot vazio)" ;;
    D3COLD)  log_line "FAIL" "$id" "PCI ${bdf} D3cold — config 0xFF (precisa reboot host + reenum)" ;;
    OK\|*)
      local drv rest
      drv="$(echo "$out" | cut -d'|' -f2)"
      rest="$(echo "$out" | cut -d'|' -f3-)"
      if [[ "$drv" == "$expect_driver" ]]; then
        log_line "OK" "$id" "host ${bdf} driver=${drv} | ${rest}"
      else
        log_line "WARN" "$id" "host ${bdf} driver=${drv} (esperado ${expect_driver}) | ${rest}"
      fi
      ;;
    *) log_line "FAIL" "$id" "check host PCI falhou: ${out:-empty}" ;;
  esac
}

check_hostpci_conf() {
  local id="$1" host="$2" vmid="$3"
  local conf
  conf="$(ssh_host "$host" "qm config $vmid 2>/dev/null | grep -E '^hostpci' || true")"
  if [[ -z "$conf" ]]; then
    log_line "FAIL" "$id" "VM${vmid} sem hostpci* no qm config — GPU não passada à guest"
  else
    log_line "OK" "$id" "VM${vmid}: $(echo "$conf" | tr '\n' '; ')"
  fi
}

check_guest_gpu() {
  local id="$1" host="$2" vmid="$3" vendor_re="$4"
  local raw
  raw="$(ssh_host "$host" "qm guest exec $vmid -- lspci -nn 2>/dev/null" 2>/dev/null || true)"
  local lspci_out
  lspci_out="$(printf '%s' "$raw" | python3 -c "
import json,sys
raw=sys.stdin.read()
try:
  j=json.loads(raw)
  print(j.get('out-data') or '')
except Exception:
  print(raw)
" 2>/dev/null || true)"
  if echo "$lspci_out" | grep -qiE "$vendor_re"; then
    log_line "OK" "$id" "guest vê GPU: $(echo "$lspci_out" | grep -iE "$vendor_re" | head -1)"
  elif echo "$lspci_out" | grep -qi virtio; then
    log_line "FAIL" "$id" "guest só Virtio — sem GPU passthrough"
  else
    log_line "WARN" "$id" "guest lspci sem match (${vendor_re})"
  fi
}

check_ollama_vram() {
  local id="$1" base="$2"
  local body
  if ! body="$(curl -sf --max-time 10 "${base%/}/api/ps" 2>/dev/null)"; then
    log_line "FAIL" "$id" "Ollama API inacessível ${base}"
    return
  fi
  local verdict
  verdict="$(printf '%s' "$body" | python3 -c "
import json,sys
d=json.load(sys.stdin)
models=d.get('models') or []
if not models:
    print('EMPTY|nenhum modelo carregado')
    raise SystemExit
m=models[0]
vram=int(m.get('size_vram') or 0)
name=m.get('name') or '?'
size=int(m.get('size') or 0)
if vram > 0:
    pct=int(100*vram/size) if size else 0
    print(f'GPU|{name} size_vram={vram} (~{pct}% weights+kv em VRAM)')
else:
    print(f'CPU|{name} size_vram=0 — inferência em CPU')
" 2>/dev/null || echo "ERR|parse")"
  case "$verdict" in
    GPU\|*) log_line "OK" "$id" "${verdict#GPU|}" ;;
    CPU\|*) log_line "FAIL" "$id" "${verdict#CPU|}" ;;
    EMPTY\|*) log_line "WARN" "$id" "${verdict#EMPTY|}" ;;
    *) log_line "WARN" "$id" "$verdict" ;;
  esac
}

# ========== checks ==========
echo "=== AGL GPU health $(date -Iseconds) ===" >&2

# VM110 — GTX 1650 @ AGLSRV1
check_hostpci_conf "vm110-hostpci" "$AGLSRV1" 110
check_host_pci "vm110-host-pci" "$AGLSRV1" "0000:05:00.0" "vfio-pci"
check_guest_gpu "vm110-guest-pci" "$AGLSRV1" 110 "NVIDIA|10de:|GTX|GeForce"
check_ollama_vram "vm110-ollama-vram" "$VM110_TS"

# VM310 — RX580 @ AGLSRV3
check_hostpci_conf "vm310-hostpci" "$AGLSRV3" 310
check_host_pci "vm310-host-pci" "$AGLSRV3" "0000:02:00.0" "vfio-pci"
check_guest_gpu "vm310-guest-pci" "$AGLSRV3" 310 "AMD|1002:|Radeon|Polaris"
check_ollama_vram "vm310-ollama-vram" "$VM310_TS"

if [[ "$JSON" -eq 1 ]]; then
  python3 - "$FAILS" "$WARNS" "${RESULTS[@]}" <<'PY'
import json, sys
fails, warns = int(sys.argv[1]), int(sys.argv[2])
rows = []
for line in sys.argv[3:]:
    parts = line.split("|", 2)
    if len(parts) == 3:
        rows.append({"severity": parts[0], "id": parts[1], "msg": parts[2]})
print(json.dumps({"fails": fails, "warns": warns, "checks": rows}, indent=2, ensure_ascii=False))
PY
fi

SUMMARY="FAIL=${FAILS} WARN=${WARNS}"
echo "=== ${SUMMARY} ===" >&2

if [[ "$NOTIFY" -eq 1 && "$FAILS" -gt 0 && -x "$NOTIFY_SCRIPT" ]]; then
  BODY="$(printf '%s\n' "${RESULTS[@]}" | grep '^FAIL|' | sed 's/^FAIL|/• /' | head -12)"
  bash "$NOTIFY_SCRIPT" --severity critical --title "GPU Ollama unhealthy" --body "${BODY}"$'\n'"${SUMMARY}" || true
fi

[[ "$FAILS" -eq 0 ]]
