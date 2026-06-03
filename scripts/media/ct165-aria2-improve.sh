#!/usr/bin/env bash
# CT165 (aria2) — auditoria e melhorias seguras no AGLSRV1.
# Uso:
#   bash scripts/media/ct165-aria2-improve.sh           # só relatório
#   bash scripts/media/ct165-aria2-improve.sh --apply  # aplica mudanças seguras
#   bash scripts/media/ct165-aria2-improve.sh --apply --rightsize  # + 8→2 cores (requer restart CT)

set -euo pipefail

AGLSRV1="${AGLSRV1:-root@100.107.113.33}"
VMID=165
APPLY=false
RIGHTSIZE=false

for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=true ;;
    --rightsize) RIGHTSIZE=true ;;
    -h|--help)
      sed -n '2,8p' "$0"
      exit 0
      ;;
  esac
done

run_remote() {
  ssh -o ConnectTimeout=15 -o BatchMode=yes "$AGLSRV1" "$@"
}

section() { echo ""; echo "=== $1 ==="; }

section "CT165 status"
run_remote "pct status $VMID"
run_remote "pct config $VMID | grep -E '^(cores|memory|hostname|net0|mp0|onboot)'"

section "Disco overpower (crítico para reactivar downloads)"
run_remote "pct exec $VMID -- df -h /mnt/overpower 2>/dev/null || true"

section "Serviços"
run_remote "pct exec $VMID -- systemctl is-active aria2 nginx 2>/dev/null || true"
run_remote "pct exec $VMID -- ss -tlnp 2>/dev/null | grep -E ':6800|:6880' || true"

section "Config aria2 (sem segredos)"
run_remote "pct exec $VMID -- bash -c 'grep -vE \"^rpc-secret=\" /root/aria2.daemon 2>/dev/null || true'"
run_remote "pct exec $VMID -- test -f /root/config/.aria2/ariahook.sh && echo hook:present || echo hook:MISSING"

section "*arr — cliente Aria2"
run_remote 'bash -s' <<'REMOTE'
set -euo pipefail
read_key() { pct exec "$1" -- grep -oP '(?<=<ApiKey>)[^<]+' "/var/lib/$2/config.xml" 2>/dev/null | head -1; }
check_aria2() {
  local label=$1 ct=$2 port=$3 svc=$4
  local key
  key=$(read_key "$ct" "$svc") || { echo "${label}: key skip"; return 0; }
  pct exec "$ct" -- curl -sf -H "X-Api-Key: ${key}" "http://127.0.0.1:${port}/api/v3/downloadclient" \
    | python3 -c "import sys,json; cs=json.load(sys.stdin); a=[c for c in cs if 'Aria2' in c['name']]; print('${label}:', a[0]['name'] if a else 'n/a', 'enable=', a[0]['enable'] if a else 'n/a')" \
    || echo "${label}: API skip"
}
check_aria2 Radarr 123 7878 radarr
check_aria2 Sonarr 124 8989 sonarr
REMOTE

if [[ "$APPLY" != true ]]; then
  echo ""
  echo "Modo auditoria. Para aplicar: bash scripts/media/ct165-aria2-improve.sh --apply"
  exit 0
fi

section "Aplicar melhorias (--apply)"
run_remote "pct exec $VMID -- bash -s" <<'IN_CT'
set -euo pipefail
CONF=/root/aria2.daemon
HOOK_DIR=/root/config/.aria2
HOOK="${HOOK_DIR}/ariahook.sh"
STAMP=$(date +%Y%m%d-%H%M%S)
cp -a "$CONF" "${CONF}.bak.${STAMP}"

mkdir -p "$HOOK_DIR" /mnt/overpower/downs/torFiles
cat > "$HOOK" <<'HOOK_EOF'
#!/usr/bin/env bash
# Move conclusões aria2 para torFiles (alinhado com qBittorrent CT121).
DEST="/mnt/overpower/downs/torFiles"
[[ -d "$DEST" ]] || mkdir -p "$DEST"
# aria2: GID, file count, path...
path="${3:-}"
if [[ -n "$path" && -e "$path" ]]; then
  base=$(basename "$path")
  if [[ ! -e "${DEST}/${base}" ]]; then
    mv -f "$path" "$DEST/" 2>/dev/null || cp -a "$path" "$DEST/" && rm -rf "$path"
  fi
fi
HOOK_EOF
chmod +x "$HOOK"

python3 - "$CONF" <<'PY'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text()
secret_m = re.search(r"^rpc-secret=.*$", text, re.M)
secret = secret_m.group(0) if secret_m else None
lines = []
seen_save = False
for line in text.splitlines():
    if line.startswith("save-session"):
        if seen_save:
            continue
        seen_save = True
        lines.append('save-session=/var/tmp/aria2c.session')
        continue
    if line.startswith('save-session="'):
        if seen_save:
            continue
        seen_save = True
        lines.append('save-session=/var/tmp/aria2c.session')
        continue
    if line.startswith("on-download-complete") or line.startswith("on-bt-download-complete"):
        lines.append(line.split("=")[0] + '="' + "/root/config/.aria2/ariahook.sh" + '"')
        continue
    if line.startswith("rpc-allow-origin-all"):
        lines.append("rpc-allow-origin-all=false")
        continue
    lines.append(line)
out = "\n".join(lines).rstrip() + "\n"
if secret and "rpc-secret=" not in out:
    out = out.rstrip() + "\n" + secret + "\n"
path.write_text(out)
PY

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get -y -qq upgrade

systemctl restart aria2
systemctl is-active aria2
echo "aria2 restarted OK"
IN_CT

if [[ "$RIGHTSIZE" == true ]]; then
  section "Rightsize Proxmox (2 cores — aria2 idle)"
  run_remote "pct stop $VMID && pct set $VMID -cores 2 && pct start $VMID"
  run_remote "pct config $VMID | grep '^cores:'"
fi

echo ""
echo "Melhorias aplicadas. Verificar: bash scripts/media/arr-freeze-downloads.sh --verify-only"
echo "Reactivar Aria2 nos *arr só após espaço em /mnt/overpower (arr-unfreeze-downloads.sh)."
