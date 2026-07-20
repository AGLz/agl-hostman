#!/usr/bin/env bash
# Atualiza todos os CTs running no AGLSRV1 via apt (proxy cacheng CT173).
# Uso: bash scripts/proxmox/aglsrv1-apt-update-all-cts.sh
set -euo pipefail

PROXY='192.168.0.173:3142'
CACheng_VMID=173
TIMEOUT_SEC=600
LOG="/tmp/aglsrv1-apt-update-$(date +%Y%m%d-%H%M%S).log"
REPORT="/tmp/aglsrv1-apt-update-report.tsv"

exec > >(tee -a "$LOG") 2>&1

ensure_lan_route() {
  local vmid=$1
  # ponytail: RouteAll do Tailscale desvia 192.168.0.0/24 — precisa rule pref 100
  pct exec "$vmid" -- bash -lc '
    command -v tailscale >/dev/null 2>&1 || exit 0
    tailscale debug prefs 2>/dev/null | grep -q "\"RouteAll\": true" || exit 0
    ip rule replace to 192.168.0.0/24 pref 100 lookup main 2>/dev/null || \
      ip rule add to 192.168.0.0/24 pref 100 lookup main 2>/dev/null || true
    cat > /etc/network/if-up.d/99-local-lan-bypass-ts <<'"'"'EOF'"'"'
#!/bin/sh
ip rule replace to 192.168.0.0/24 pref 100 lookup main 2>/dev/null || \
  ip rule add to 192.168.0.0/24 pref 100 lookup main 2>/dev/null || true
EOF
    chmod +x /etc/network/if-up.d/99-local-lan-bypass-ts
  ' 2>/dev/null || true
}

ensure_proxy() {
  local vmid=$1
  pct exec "$vmid" -- bash -lc "
    command -v apt-get >/dev/null 2>&1 || exit 0
    mkdir -p /etc/apt/apt.conf.d
    grep -q '${PROXY}' /etc/apt/apt.conf.d/01proxy 2>/dev/null || cat > /etc/apt/apt.conf.d/01proxy <<'EOF'
// APT cache proxy via CT173 (cacheng / apt-cacher-ng)
Acquire::http::Proxy \"http://${PROXY}\";
Acquire::https::Proxy \"http://${PROXY}\";
EOF
  " 2>/dev/null || true
}

fix_common_apt() {
  local vmid=$1
  pct exec "$vmid" -- bash -lc '
    set +e
    fixes=""
    # Helm repo quebrado (baltocdn NOSPLIT)
    if [ -f /etc/apt/sources.list.d/helm-stable-debian.list ] || ls /etc/apt/sources.list.d/*helm* 2>/dev/null; then
      rm -f /etc/apt/sources.list.d/helm-stable-debian.list /etc/apt/sources.list.d/helm*.list 2>/dev/null
      fixes="${fixes}helm-repo-removed;"
    fi
    # Warp GPG expirada
    if grep -rq warp.dev /etc/apt/sources.list.d/ 2>/dev/null; then
      curl -fsSL https://releases.warp.dev/linux/keys/warp-archive-keyring.gpg -o /usr/share/keyrings/warp-archive-keyring.gpg 2>/dev/null \
        && fixes="${fixes}warp-key-updated;" \
        || rm -f /etc/apt/sources.list.d/warp*.list 2>/dev/null && fixes="${fixes}warp-repo-removed;"
    fi
    # Locks / dpkg interrompido
    if fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; then
      fixes="${fixes}dpkg-locked;"
    else
      DEBIAN_FRONTEND=noninteractive dpkg --configure -a >/dev/null 2>&1 && fixes="${fixes}dpkg-configured;"
      DEBIAN_FRONTEND=noninteractive apt-get --fix-broken install -y -qq >/dev/null 2>&1 && fixes="${fixes}fix-broken;"
    fi
    echo "$fixes"
  ' 2>/dev/null || echo "fix-failed"
}

update_ct() {
  local vmid=$1 name=$2
  echo ""
  echo "========== CT${vmid} (${name}) =========="

  if ! pct exec "$vmid" -- bash -lc 'command -v apt-get >/dev/null 2>&1' 2>/dev/null; then
    echo "SKIP: sem apt-get"
    printf '%s\t%s\tSKIP\t0\tno-apt\n' "$vmid" "$name" >> "$REPORT"
    return 0
  fi

  local fixes=""
  if [ "$vmid" != "$CACheng_VMID" ]; then
    ensure_proxy "$vmid"
    ensure_lan_route "$vmid"
    fixes=$(fix_common_apt "$vmid")
  else
    # cacheng: sem proxy circular
    pct exec "$vmid" -- bash -lc 'mv -f /etc/apt/apt.conf.d/01proxy /tmp/01proxy.bak 2>/dev/null; true' 2>/dev/null || true
    fixes="cacheng-direct"
  fi

  local before after rc=0
  before=$(pct exec "$vmid" -- bash -lc 'dpkg -l | grep -c "^ii"' 2>/dev/null || echo 0)

  if ! timeout "$TIMEOUT_SEC" pct exec "$vmid" -- bash -lc \
    'export DEBIAN_FRONTEND=noninteractive; apt-get update -qq 2>&1 && apt-get dist-upgrade -y -qq 2>&1'; then
    rc=1
    echo "WARN: update falhou, tentando fix-broken..."
    pct exec "$vmid" -- bash -lc 'DEBIAN_FRONTEND=noninteractive apt-get --fix-broken install -y -qq' 2>/dev/null || true
    pct exec "$vmid" -- bash -lc 'DEBIAN_FRONTEND=noninteractive dpkg --configure -a --force-confold 2>/dev/null' || true
    timeout "$TIMEOUT_SEC" pct exec "$vmid" -- bash -lc \
      'export DEBIAN_FRONTEND=noninteractive; apt-get update -qq && apt-get dist-upgrade -y -qq' 2>/dev/null || rc=2
  fi

  if [ "$vmid" = "$CACheng_VMID" ]; then
    pct exec "$vmid" -- bash -lc 'mv -f /tmp/01proxy.bak /etc/apt/apt.conf.d/01proxy 2>/dev/null; true' 2>/dev/null || true
  fi

  after=$(pct exec "$vmid" -- bash -lc 'dpkg -l | grep -c "^ii"' 2>/dev/null || echo 0)
  local upgraded=$((after - before))
  [ "$upgraded" -lt 0 ] && upgraded=0

  local reboot=""
  if pct exec "$vmid" -- test -f /var/run/reboot-required 2>/dev/null; then
    reboot="REBOOT"
  fi

  local status=OK
  [ "$rc" -ne 0 ] && status=FAIL

  printf '%s\t%s\t%s\t%d\t%s\t%s\n' "$vmid" "$name" "$status" "$upgraded" "$fixes" "$reboot" >> "$REPORT"
  echo "Result: $status packages~$upgraded fixes=[$fixes] $reboot"
}

# Prioridade: dev primeiro
PRIORITY=(179 181 185 174 183 184 186 187 188 189 190 191 192 193 194 202 134 180 182)
DONE=()

echo "vmid\tname\tstatus\tpackages\tfixes\treboot" > "$REPORT"

for vmid in "${PRIORITY[@]}"; do
  status=$(pct list | awk -v v="$vmid" '$1==v{print $2}')
  [ "$status" = "running" ] || continue
  name=$(pct list | awk -v v="$vmid" '$1==v{print $NF}')
  update_ct "$vmid" "$name"
  DONE+=("$vmid")
done

for vmid in $(pct list | awk '$2=="running"{print $1}' | sort -n); do
  skip=0
  for d in "${DONE[@]}"; do [ "$d" = "$vmid" ] && skip=1; done
  [ "$skip" -eq 1 ] && continue
  name=$(pct list | awk -v v="$vmid" '$1==v{print $NF}')
  update_ct "$vmid" "$name"
done

echo ""
echo "========== RELATÓRIO FINAL =========="
column -t -s $'\t' "$REPORT" 2>/dev/null || cat "$REPORT"
echo ""
echo "Log: $LOG"
echo "Report: $REPORT"
