#!/usr/bin/env bash
# Manutenção CT102 (pihole) no AGLSRV1 — executar no host Proxmox: bash pihole-ct102-maintenance.sh
set -eu

VMID=102

pct exec "${VMID}" -- bash <<'EOF'
set -eu
TOML=/etc/pihole/pihole.toml

python3 <<'PY'
import re
from pathlib import Path

p = Path("/etc/pihole/pihole.toml")
t = p.read_text()

def fix_upstreams(m: re.Match) -> str:
    lines = m.group(0).splitlines()
    out = []
    for ln in lines:
        if re.search(r'"[^"]*:[^"]*"', ln):
            continue
        out.append(ln)
    return "\n".join(out)

t = re.sub(r"upstreams = \[.*?\]", fix_upstreams, t, count=1, flags=re.S)
t = t.replace("maxDBdays = 91", "maxDBdays = 14")
t = t.replace("resolveIPv6 = true", "resolveIPv6 = false")
p.write_text(t)
print("pihole.toml updated")
PY

echo "=== upstreams (IPv4 only) ==="
sed -n '/upstreams = \[/,/^\]/p' "${TOML}" | head -15
grep maxDBdays "${TOML}"

echo "=== stopping FTL for DB maintenance ==="
systemctl stop pihole-FTL
sleep 2

# Prune queries older than 14 days (epoch)
CUTOFF=$(($(date +%s) - 14 * 86400))
if [ -f /etc/pihole/pihole-FTL.db ]; then
  sqlite3 /etc/pihole/pihole-FTL.db "DELETE FROM query_storage WHERE timestamp < ${CUTOFF};" 2>/dev/null || true
  sqlite3 /etc/pihole/pihole-FTL.db "VACUUM;" 2>/dev/null || true
  ls -lh /etc/pihole/pihole-FTL.db
fi

echo "=== log cleanup ==="
rm -f /var/log/pihole/pihole.log.[2-9]* /var/log/pihole/pihole.log.[0-9][0-9]* 2>/dev/null || true
rm -f /var/log/pihole/FTL.log.[2-9]* /var/log/pihole/FTL.log.[0-9][0-9]* 2>/dev/null || true
: > /var/log/pihole/pihole.log 2>/dev/null || true
: > /var/log/pihole/pihole.log.1 2>/dev/null || true

echo "=== starting FTL ==="
systemctl start pihole-FTL
sleep 3
systemctl is-active pihole-FTL
df -h /
EOF

echo "=== DNS test ==="
dig @192.168.0.102 google.com +short +time=3 | head -2
dig @100.114.66.80 google.com +short +time=3 | head -2
