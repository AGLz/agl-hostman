#!/usr/bin/env bash
# Alinha CTs de download ao template aria2 CT165 (CPU, memória, rede, ulimit, tuning).
# CTs: qBittorrent 121, SABnzbd 141, Deluge 157, aria2 165.
#
# Uso:
#   bash scripts/media/download-clients-perf-optimize.sh              # dry-run base
#   bash scripts/media/download-clients-perf-optimize.sh --apply      # LXC + tuning base
#   bash scripts/media/download-clients-perf-optimize.sh --fine-tune  # dry-run camada 2
#   bash scripts/media/download-clients-perf-optimize.sh --apply --fine-tune
#
# Ver docs/DOWNLOAD-CLIENTS-FINE-TUNING-1GBPS.md

set -euo pipefail

AGLSRV1="${AGLSRV1:-root@100.107.113.33}"
APPLY=false
FINE_TUNE=false
for a in "$@"; do
  [[ "$a" == --apply ]] && APPLY=true
  [[ "$a" == --fine-tune ]] && FINE_TUNE=true
done

run() { ssh -o ConnectTimeout=15 -o BatchMode=yes "$AGLSRV1" "$@"; }

section() { echo ""; echo "=== $1 ==="; }

# sysctl de rede (dentro do CT) — alinhado a cargas de download
SYSCTL_SNIPPET='net.core.rmem_max = 16777216
net.core.wmem_max = 4194304
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 4194304
net.ipv4.tcp_fastopen = 3'

if [[ "$APPLY" != true ]]; then
  echo "Modo dry-run. Aplicar: bash scripts/media/download-clients-perf-optimize.sh --apply"
fi

section "Template aria2 CT165 (referência)"
run "pct config 165 | grep -E '^(cores|memory|mp0|features|swap)'" || true

section "Estado actual"
for v in 121 141 157 165; do
  echo "--- CT${v} ---"
  run "pct config $v | grep -E '^(cores|memory|mp0|features|swap|net0)'" || true
done

section "Alterações Proxmox LXC (template aria2)"
cat <<'PLAN'
| CT  | Serviço      | cores (antes→depois) | memory      | features (como CT165)     | Outros |
|-----|--------------|----------------------|-------------|---------------------------|--------|
| 121 | qBittorrent  | 8 → 8                | 8192 (mantém)| fuse,mknod,mount,nesting  | mp0–mp9 = CT123 (ct-download-mounts-apply.sh) |
| 141 | SABnzbd      | 2 → 4                | 4096        | +fuse,mount,nesting       | Usenet: 4 cores suficiente |
| 157 | Deluge       | 2 → 8                | 2048 → 4096 | +fuse,mount,nesting       | net0 sem firewall=1 |
| 165 | aria2        | 8                    | 4096        | (já OK)                   | mp1=/overpower/base → /mnt/overpower |

NOTA: mounts unificados com Radarr — mp1 `/mnt/overpower` = `/overpower/base/downs` no host.
PLAN

section "CT121 qBittorrent — app"
cat <<'PLAN'
- nofile 65535 + LimitNOFILE systemd
- Session: MaxConnections=300, PerTorrent=80, ActiveDownloads=8 (como aria2)
- Limpar Session\AdditionalTrackers (lista enorme mesmo com AddTrackersEnabled=false)
- Disk IO: SimplePreadPwrite, Preallocation=false, falloc-equivalent
PLAN

section "CT157 Deluge — app (equivalente aria2)"
cat <<'PLAN'
- max_connections_global: 200 → 300 | max_connections_per_torrent: 80
- max_active_downloading: 3 → 8 | max_active_limit: 12
- max_half_open_connections: 50 → 100 | max_upload_slots_global: 4 → 16
- cache_size: 512 → 1024 | nofile 65535 + deluged LimitNOFILE
PLAN

section "CT141 SABnzbd — app"
cat <<'PLAN'
- direct_unpack_threads: 3 → 4 (com 4 cores)
- cache_max / article_cache se presentes — alinhar a 512M–1G
- nofile 65535 + sabnzbd LimitNOFILE
PLAN

section "CT165 aria2"
cat <<'PLAN'
- Re-aplicar split=16, bt-max-peers=80, max-concurrent-downloads=8, falloc
PLAN

if [[ "$FINE_TUNE" == true ]]; then
  section "Fine-tune (camada 2) — plano"
  cat <<'FT'
Host ZFS (dataset overpower — bind /overpower/base nos CTs):
  zfs set recordsize=1M atime=off overpower
  opcional: zfs_dirty_data_max, vm.dirty_background_bytes=128M no host

CT121 qBit: AsyncIOThreads=8, disk cache 1024MiB, buffers, Prefer TCP, CoalesceReadWrite
CT157 Deluge: instalar ltConfig (manual) — ver doc
CT165 aria2: min-split-size=2M, bt-max-peers=120
CT141 SAB: article cache 1500M, articles per request, receive_threads
FT
fi

if [[ "$APPLY" != true ]]; then
  exit 0
fi

if [[ "$FINE_TUNE" == true ]] && [[ "$APPLY" == true ]]; then
  section "Fine-tune CT121 qBittorrent"
  run "bash -s" <<'REMOTE'
set -euo pipefail
pct exec 121 -- bash -s <<'IN_CT'
set -euo pipefail
QCONF=/.config/qBittorrent/qBittorrent.conf
STAMP=$(date +%Y%m%d-%H%M%S)
cp -a "$QCONF" "${QCONF}.bak.finetune.${STAMP}"
systemctl stop qbittorrent-nox
python3 - "$QCONF" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
keys = {
    "Session\\AsyncIOThreadsCount": "8",
    "Session\\CoalesceReadWrite": "true",
    "Session\\SuggestMode": "true",
    "Session\\SendBufferWatermark": "5000",
    "Session\\SendBufferLowWatermark": "500",
    "Session\\SendBufferWatermarkFactor": "150",
    "Session\\DiskCacheSize": "1024",
    "Session\\DiskCacheTTL": "600",
    "Session\\uTPMixedMode": "0",
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
systemctl start qbittorrent-nox
systemctl is-active qbittorrent-nox
grep -E 'AsyncIOThreads|DiskCache|SendBuffer|uTPMixed' "$QCONF" | head -8
IN_CT
REMOTE

  section "Fine-tune CT165 aria2"
  run "bash -s" <<'REMOTE'
set -euo pipefail
pct exec 165 -- bash -s <<'IN_CT'
set -euo pipefail
CONF=/root/aria2.daemon
STAMP=$(date +%Y%m%d-%H%M%S)
cp -a "$CONF" "${CONF}.bak.finetune.${STAMP}"
python3 - "$CONF" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
opts = {"min-split-size": "2M", "bt-max-peers": "120"}
lines, secret, seen = [], None, set()
for line in path.read_text().splitlines():
    if line.startswith("rpc-secret="):
        secret = line
        continue
    key = line.split("=", 1)[0] if "=" in line else None
    if key in opts:
        lines.append(f"{key}={opts[key]}")
        seen.add(key)
    else:
        lines.append(line)
for k, v in opts.items():
    if k not in seen:
        lines.append(f"{k}={v}")
out = "\n".join(lines).rstrip() + "\n"
if secret:
    out += secret + "\n"
path.write_text(out)
PY
systemctl restart aria2
grep -E 'min-split-size|bt-max-peers' "$CONF"
IN_CT
REMOTE

  section "Fine-tune CT141 SABnzbd"
  run "bash -s" <<'REMOTE'
set -euo pipefail
pct exec 141 -- bash -s <<'IN_CT'
set -euo pipefail
INI=/root/.sabnzbd/sabnzbd.ini
STAMP=$(date +%Y%m%d-%H%M%S)
cp -a "$INI" "${INI}.bak.finetune.${STAMP}"
systemctl stop sabnzbdplus 2>/dev/null || systemctl stop sabnzbd 2>/dev/null || true
python3 - "$INI" <<'PY'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

def set_kv(key, value):
    global text
    pat = rf"^({re.escape(key)}\s*=\s*).*$"
    if re.search(pat, text, flags=re.M):
        text = re.sub(pat, rf"\g<1>{value}", text, count=1, flags=re.M)
    elif re.search(r"^\[misc\]", text, flags=re.M):
        text = re.sub(r"^(\[misc\]\s*\n)", rf"\g<1>{key} = {value}\n", text, count=1, flags=re.M)

for key, val in [
    ("cache_max", "1500M"),
    ("direct_unpack_threads", "4"),
]:
    set_kv(key, val)
if not re.search(r"^article_cache\s*=", text, flags=re.M):
    set_kv("article_cache", "1500M")
path.write_text(text, encoding="utf-8")
PY
for unit in sabnzbdplus sabnzbd; do
  if systemctl cat "$unit" &>/dev/null; then
    systemctl start "$unit"
    systemctl is-active "$unit"
    break
  fi
done
grep -E '^(cache_max|article_cache|direct_unpack)' "$INI" 2>/dev/null | head -5
IN_CT
REMOTE

  section "Fine-tune host ZFS (pool overpower; /overpower/base é directório no dataset)"
  run "bash -s" <<'REMOTE'
set -euo pipefail
ZFS_DS=overpower
if zfs list "$ZFS_DS" &>/dev/null; then
  zfs set recordsize=1M atime=off "$ZFS_DS"
  # compression: manter lz4 se já definido (menos CPU que off em alguns workloads)
  zfs get recordsize,atime,compression "$ZFS_DS"
else
  echo "SKIP: dataset $ZFS_DS não encontrado"
fi
grep -E '^(vm\.dirty_background_bytes|vm\.dirty_bytes)' /etc/sysctl.d/*.conf 2>/dev/null || true
if ! grep -q agl-download-host-dirty /etc/sysctl.d/99-agl-download-host.conf 2>/dev/null; then
  cat >/etc/sysctl.d/99-agl-download-host.conf <<'SYS'
# agl-hostman — page cache no host (root/ext4); ZFS usa zfs_dirty_data_max
vm.dirty_background_bytes = 134217728
vm.dirty_bytes = 268435456
SYS
  sysctl --system >/dev/null 2>&1 || true
fi
REMOTE

  echo ""
  echo "Fine-tune aplicado. Ver docs/DOWNLOAD-CLIENTS-FINE-TUNING-1GBPS.md"
  exit 0
fi

section "Proxmox LXC — CT157 Deluge"
run "bash -s" <<'REMOTE'
set -euo pipefail
VMID=157
pct stop "$VMID"
pct set "$VMID" -cores 8 -memory 4096 -swap 512 \
  -features fuse=1,mknod=1,mount=nfs\;cifs,nesting=1
# Remover firewall=1 do veth (pode limitar tráfego de peers)
pct set "$VMID" -net0 name=eth0,bridge=vmbr0,gw=192.168.0.1,hwaddr=BC:24:11:00:01:57,ip=192.168.0.157/24,type=veth
pct start "$VMID"
sleep 5
pct config "$VMID" | grep -E '^(cores|memory|net0|features)'
REMOTE

section "Proxmox LXC — CT141 SABnzbd"
run "bash -s" <<'REMOTE'
set -euo pipefail
VMID=141
pct stop "$VMID"
pct set "$VMID" -cores 4 -memory 4096 \
  -features fuse=1,mknod=1,mount=nfs\;cifs,nesting=1
pct start "$VMID"
sleep 5
pct config "$VMID" | grep -E '^(cores|memory|features)'
REMOTE

section "Proxmox LXC — CT121 qBittorrent (features)"
run "bash -s" <<'REMOTE'
set -euo pipefail
VMID=121
# Só features; cores/memory já adequados
CUR=$(pct config "$VMID" | grep '^features:' || true)
if echo "$CUR" | grep -q nesting; then
  echo "CT121 features já com nesting/mount"
else
  pct stop "$VMID"
  pct set "$VMID" -features fuse=1,mknod=1,mount=nfs\;cifs,nesting=1
  pct start "$VMID"
  sleep 5
fi
pct config "$VMID" | grep -E '^(cores|memory|features|mp0)'
REMOTE

section "Aplicar CT121 qBittorrent"
run "bash -s" <<'REMOTE'
set -euo pipefail
VMID=121
apply_limits_sysctl() {
  pct exec "$VMID" -- bash -s <<'IN_CT'
set -euo pipefail
grep -q 'agl-hostman download-clients-perf' /etc/security/limits.conf 2>/dev/null || cat >>/etc/security/limits.conf <<'EOF'
# agl-hostman download-clients-perf
* soft nofile 65535
* hard nofile 65535
EOF
grep -q pam_limits.so /etc/pam.d/common-session 2>/dev/null || echo 'session required pam_limits.so' >>/etc/pam.d/common-session
cat >/etc/sysctl.d/99-agl-download.conf <<'SYS'
net.core.rmem_max = 16777216
net.core.wmem_max = 4194304
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 4194304
net.ipv4.tcp_fastopen = 3
SYS
sysctl --system >/dev/null 2>&1 || true
IN_CT
}
apply_limits_sysctl

pct exec "$VMID" -- bash -s <<'IN_CT'
set -euo pipefail
STAMP=$(date +%Y%m%d-%H%M%S)
QCONF=/.config/qBittorrent/qBittorrent.conf
cp -a "$QCONF" "${QCONF}.bak.${STAMP}"

systemctl stop qbittorrent-nox
python3 - "$QCONF" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
keys = {
    "Session\\AddTrackersEnabled": "false",
    "Session\\AdditionalTrackers": "",
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
systemctl is-active qbittorrent-nox
cat /proc/$(pgrep -xo qbittorrent-nox)/limits 2>/dev/null | grep "Max open files" || ulimit -n
IN_CT
echo "CT121 qBittorrent OK"
REMOTE

section "Aplicar CT157 Deluge"
run "bash -s" <<'REMOTE'
set -euo pipefail
VMID=157
pct exec "$VMID" -- bash -s <<'IN_CT'
set -euo pipefail
grep -q 'agl-hostman download-clients-perf' /etc/security/limits.conf 2>/dev/null || cat >>/etc/security/limits.conf <<'EOF'
# agl-hostman download-clients-perf
* soft nofile 65535
* hard nofile 65535
EOF
grep -q pam_limits.so /etc/pam.d/common-session 2>/dev/null || echo 'session required pam_limits.so' >>/etc/pam.d/common-session
cat >/etc/sysctl.d/99-agl-download.conf <<'SYS'
net.core.rmem_max = 16777216
net.core.wmem_max = 4194304
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 4194304
net.ipv4.tcp_fastopen = 3
SYS
sysctl --system >/dev/null 2>&1 || true
IN_CT

pct exec "$VMID" -- bash -s <<'IN_CT'
set -euo pipefail
CONF=/root/.config/deluge/core.conf
STAMP=$(date +%Y%m%d-%H%M%S)
cp -a "$CONF" "${CONF}.bak.${STAMP}"
systemctl stop deluged deluge-web 2>/dev/null || systemctl stop deluged

python3 - "$CONF" <<'PY'
import json, pathlib, re, sys
path = pathlib.Path(sys.argv[1])
raw = path.read_text()
header, body = "", raw
m = re.match(r"^(\{\s*\"file\"\s*:\s*1.*?\})\s*(\{.*\})\s*$", raw, re.DOTALL)
if m:
    header, body = m.group(1), m.group(2)
conf = json.loads(body)
conf.update({
    "max_connections_global": 300,
    "max_connections_per_torrent": 80,
    "max_connections_per_second": 30,
    "max_half_open_connections": 100,
    "max_active_downloading": 8,
    "max_active_limit": 12,
    "max_active_seeding": 5,
    "max_upload_slots_global": 16,
    "cache_size": 1024,
    "max_download_speed": -1.0,
    "max_upload_speed": -1.0,
})
path.write_text(header + json.dumps(conf, indent=4) + "\n")
PY

mkdir -p /etc/systemd/system/deluged.service.d
cat >/etc/systemd/system/deluged.service.d/limits.conf <<'EOF'
[Service]
LimitNOFILE=65535
EOF
systemctl daemon-reload
systemctl start deluged deluge-web 2>/dev/null || systemctl start deluged
sleep 2
systemctl is-active deluged
grep -E 'max_connections_global|max_active_downloading|cache_size' "$CONF" | head -5
IN_CT
echo "CT157 Deluge OK"
REMOTE

section "Aplicar CT141 SABnzbd"
run "bash -s" <<'REMOTE'
set -euo pipefail
VMID=141
pct exec "$VMID" -- bash -s <<'IN_CT'
set -euo pipefail
grep -q 'agl-hostman download-clients-perf' /etc/security/limits.conf 2>/dev/null || cat >>/etc/security/limits.conf <<'EOF'
# agl-hostman download-clients-perf
* soft nofile 65535
* hard nofile 65535
EOF
grep -q pam_limits.so /etc/pam.d/common-session 2>/dev/null || echo 'session required pam_limits.so' >>/etc/pam.d/common-session
cat >/etc/sysctl.d/99-agl-download.conf <<'SYS'
net.core.rmem_max = 16777216
net.core.wmem_max = 4194304
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 4194304
net.ipv4.tcp_fastopen = 3
SYS
sysctl --system >/dev/null 2>&1 || true
IN_CT

pct exec "$VMID" -- bash -s <<'IN_CT'
set -euo pipefail
INI=/root/.sabnzbd/sabnzbd.ini
STAMP=$(date +%Y%m%d-%H%M%S)
cp -a "$INI" "${INI}.bak.${STAMP}"
systemctl stop sabnzbdplus 2>/dev/null || systemctl stop sabnzbd

python3 - "$INI" <<'PY'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

def set_kv(key: str, value: str) -> None:
    global text
    pat = rf"^({re.escape(key)}\s*=\s*).*$"
    if re.search(pat, text, flags=re.M):
        text = re.sub(pat, rf"\g<1>{value}", text, count=1, flags=re.M)
    elif re.search(r"^\[misc\]", text, flags=re.M):
        text = re.sub(
            r"^(\[misc\]\s*\n)",
            rf"\g<1>{key} = {value}\n",
            text,
            count=1,
            flags=re.M,
        )
    else:
        text += f"\n[misc]\n{key} = {value}\n"

set_kv("direct_unpack_threads", "4")
if re.search(r"^cache_max\s*=", text, flags=re.M):
    set_kv("cache_max", "1G")
elif re.search(r"^article_cache\s*=", text, flags=re.M):
    set_kv("article_cache", "512M")
else:
    set_kv("cache_max", "1G")
path.write_text(text, encoding="utf-8")
PY

for unit in sabnzbdplus sabnzbd; do
  if systemctl cat "$unit" &>/dev/null; then
    mkdir -p "/etc/systemd/system/${unit}.service.d"
    cat >"/etc/systemd/system/${unit}.service.d/limits.conf" <<'EOF'
[Service]
LimitNOFILE=65535
EOF
    systemctl daemon-reload
    systemctl start "$unit"
    systemctl is-active "$unit"
    break
  fi
done
grep -E '^(direct_unpack_threads|cache_max|article_cache)' "$INI" 2>/dev/null | head -5
IN_CT
echo "CT141 SABnzbd OK"
REMOTE

section "Aplicar CT165 aria2"
run "bash -s" <<'REMOTE'
set -euo pipefail
VMID=165
pct exec "$VMID" -- bash -s <<'IN_CT'
set -euo pipefail
grep -q 'agl-hostman download-clients-perf' /etc/security/limits.conf 2>/dev/null || cat >>/etc/security/limits.conf <<'EOF'
# agl-hostman download-clients-perf
* soft nofile 65535
* hard nofile 65535
EOF
grep -q pam_limits.so /etc/pam.d/common-session 2>/dev/null || echo 'session required pam_limits.so' >>/etc/pam.d/common-session
cat >/etc/sysctl.d/99-agl-download.conf <<'SYS'
net.core.rmem_max = 16777216
net.core.wmem_max = 4194304
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 4194304
net.ipv4.tcp_fastopen = 3
SYS
sysctl --system >/dev/null 2>&1 || true

STAMP=$(date +%Y%m%d-%H%M%S)
CONF=/root/aria2.daemon
cp -a "$CONF" "${CONF}.bak.${STAMP}"

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
echo "CT165 aria2 OK"
REMOTE

echo ""
echo "Optimização aplicada. Benchmark: bash scripts/media/download-clients-perf-benchmark-qbit-deluge.sh --skip-optimize"
