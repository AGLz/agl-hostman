#!/usr/bin/env bash
# Optimiza CTs de download (qBittorrent CT121, aria2 CT165) no AGLSRV1.
# Baseado em: TRaSH/qBittorrent issues (Disk IO, ulimit), aria2 docs, Proxmox LXC tuning.
#
# Uso:
#   bash scripts/media/download-clients-perf-optimize.sh           # dry-run
#   bash scripts/media/download-clients-perf-optimize.sh --apply

set -euo pipefail

AGLSRV1="${AGLSRV1:-root@100.107.113.33}"
APPLY=false
for a in "$@"; do [[ "$a" == --apply ]] && APPLY=true; done

run() { ssh -o ConnectTimeout=15 -o BatchMode=yes "$AGLSRV1" "$@"; }

section() { echo ""; echo "=== $1 ==="; }

if [[ "$APPLY" != true ]]; then
  echo "Modo dry-run. Aplicar: bash scripts/media/download-clients-perf-optimize.sh --apply"
fi

section "CT121 qBittorrent — diagnóstico"
run "pct exec 121 -- bash -c 'ulimit -n; df -h /mnt/overpower | tail -1; stat -f -c %T /mnt/overpower 2>/dev/null || true'"

section "Alterações planeadas CT121"
cat <<'PLAN'
- limits.conf: nofile 65535 (actual: 1024 — bottleneck com MaxConnections=500)
- Desactivar Session\AddTrackersEnabled (centenas de trackers extra por torrent)
- MaxConcurrentHTTPAnnounces: 320 → 50
- MaxActiveDownloads: 20 → 8 | MaxActiveTorrents: 30 → 12
- MaxConnections: 500 → 300 | MaxConnectionsPerTorrent: 200 → 80
- Preallocation: true → false (menos pressão em ZFS no arranque)
- Proxmox net0: queues=8 (multiqueue veth)
- NOTA: /mnt/overpower no CT121 é ZFS local ~40G, não o pool host 11T — ver docs/DOWNLOAD-CLIENTS-PERF.md
PLAN

section "CT165 aria2 — alterações planeadas"
cat <<'PLAN2'
- limits.conf: nofile 65535
- split=16, max-connection-per-server=16, min-split-size=5M
- max-concurrent-downloads=8, bt-max-peers=80
- file-allocation=falloc (ZFS no host overpower)
- enable-dht=true, enable-peer-exchange=true
- Proxmox net0: queues=8
PLAN2

if [[ "$APPLY" != true ]]; then
  exit 0
fi

section "Aplicar CT121"
run "bash -s" <<'REMOTE'
set -euo pipefail
VMID=121
CONF_BACKUP=""

pct exec "$VMID" -- bash -s <<'IN_CT'
set -euo pipefail
STAMP=$(date +%Y%m%d-%H%M%S)
QCONF=/.config/qBittorrent/qBittorrent.conf
cp -a "$QCONF" "${QCONF}.bak.${STAMP}"

# limits
grep -q 'nofile 65535' /etc/security/limits.conf 2>/dev/null || cat >>/etc/security/limits.conf <<'EOF'
# agl-hostman download-clients-perf
* soft nofile 65535
* hard nofile 65535
EOF
grep -q pam_limits.so /etc/pam.d/common-session 2>/dev/null || echo 'session required pam_limits.so' >>/etc/pam.d/common-session

systemctl stop qbittorrent-nox
python3 - "$QCONF" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
keys = {
    "Session\\AddTrackersEnabled": "false",
    "Session\\MaxConcurrentHTTPAnnounces": "50",
    "Session\\MaxActiveDownloads": "8",
    "Session\\MaxActiveTorrents": "12",
    "Session\\MaxConnections": "300",
    "Session\\MaxConnectionsPerTorrent": "80",
    "Session\\Preallocation": "false",
    "Session\\DiskIOType": "SimplePreadPwrite",
    "Session\\DiskIOReadMode": "EnableOSCache",
    "Session\\DiskIOWriteMode": "EnableOSCache",
    "Session\\DiskQueueSize": "134217728",
}
out, seen = [], set()
for line in path.read_text().splitlines():
    replaced = False
    for k, v in keys.items():
        if line.startswith(k + "="):
            out.append(f"{k}={v}")
            seen.add(k)
            replaced = True
            break
    if not replaced:
        out.append(line)
for k, v in keys.items():
    if k not in seen:
        out.append(f"{k}={v}")
path.write_text("\n".join(out) + "\n")
PY

mkdir -p /etc/systemd/system/qbittorrent-nox.service.d
cat >/etc/systemd/system/qbittorrent-nox.service.d/limits.conf <<'EOF'
[Service]
LimitNOFILE=65535
EOF
systemctl daemon-reload
systemctl start qbittorrent-nox
echo "NOTA: WebUI pode demorar 5+ min com ~600 torrents — aguardar curl http://127.0.0.1:8090/"
systemctl is-active qbittorrent-nox
cat /proc/$(pgrep -xo qbittorrent-nox)/limits 2>/dev/null | grep "Max open files" || ulimit -n
IN_CT
echo "CT121 qBittorrent optimized (queues=8 skipped — schema PVE não suporta em veth)"
REMOTE

section "Aplicar CT165"
run "bash -s" <<'REMOTE'
set -euo pipefail
VMID=165
pct exec "$VMID" -- bash -s <<'IN_CT'
set -euo pipefail
STAMP=$(date +%Y%m%d-%H%M%S)
CONF=/root/aria2.daemon
cp -a "$CONF" "${CONF}.bak.${STAMP}"
grep -q 'nofile 65535' /etc/security/limits.conf 2>/dev/null || cat >>/etc/security/limits.conf <<'EOF'
* soft nofile 65535
* hard nofile 65535
EOF
grep -q pam_limits.so /etc/pam.d/common-session 2>/dev/null || echo 'session required pam_limits.so' >>/etc/pam.d/common-session

python3 - "$CONF" <<'PY'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
lines = []
secret = None
opts = {
    "split": "16",
    "max-connection-per-server": "16",
    "min-split-size": "5M",
    "max-concurrent-downloads": "8",
    "bt-max-peers": "80",
    "file-allocation": "falloc",
    "enable-dht": "true",
    "enable-peer-exchange": "true",
    "bt-enable-lpd": "true",
    "bt-request-peer-speed-limit": "50M",
}
seen = set()
for line in path.read_text().splitlines():
    if line.startswith("rpc-secret="):
        secret = line
        continue
    key = line.split("=", 1)[0] if "=" in line else None
    if key in opts:
        lines.append(f"{key}={opts[key]}")
        seen.add(key)
    elif key in ("save-session",) and key in seen:
        continue
    else:
        lines.append(line)
    if key == "save-session":
        seen.add("save-session")
for k, v in opts.items():
    if k not in seen:
        lines.append(f"{k}={v}")
out = "\n".join(lines).rstrip() + "\n"
if secret:
    out += secret + "\n"
path.write_text(out)
PY
mkdir -p /etc/systemd/system/aria2.service.d
cat >/etc/systemd/system/aria2.service.d/limits.conf <<'EOF'
[Service]
LimitNOFILE=65535
EOF
systemctl daemon-reload
systemctl restart aria2
systemctl is-active aria2
IN_CT
echo "CT165 aria2 optimized"
REMOTE

echo ""
echo "Optimização aplicada. Seguinte: bash scripts/media/download-clients-perf-benchmark.sh"
