#!/usr/bin/env bash
# Benchmark de clientes de download no AGLSRV1.
# Torrent legal ~755 MiB (Debian netinst) ou ~1 GiB (SAB: test_download_1000MB.nzb)
#
# Uso:
#   bash scripts/media/download-clients-perf-benchmark.sh
#   bash scripts/media/download-clients-perf-benchmark.sh --skip-optimize
#   bash scripts/media/download-clients-perf-benchmark.sh --skip-optimize --skip-sab
#   (--only-torrent = alias de --skip-sab; aria2/qBit/Deluge continuam)

set -euo pipefail

AGLSRV1="${AGLSRV1:-root@100.107.113.33}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TORRENT_URL="${TORRENT_URL:-https://cdimage.debian.org/debian-cd/current/amd64/bt-cd/debian-13.5.0-amd64-netinst.iso.torrent}"
TORRENT_NAME="${TORRENT_NAME:-debian-13.5.0-amd64-netinst.iso}"
SAB_TEST_NZB_URL="${SAB_TEST_NZB_URL:-https://sabnzbd.org/tests/test_download_100MB.nzb}"
SKIP_OPTIMIZE=false
SKIP_SAB=false
for a in "$@"; do
  [[ "$a" == --skip-optimize ]] && SKIP_OPTIMIZE=true
  [[ "$a" == --only-torrent || "$a" == --skip-sab ]] && SKIP_SAB=true
done

if [[ "$SKIP_OPTIMIZE" != true ]]; then
  bash "$REPO_ROOT/scripts/media/download-clients-perf-optimize.sh" --apply
fi

TMP_TORRENT="$(mktemp /tmp/agl-bench-XXXXXX.torrent)"
trap 'rm -f "$TMP_TORRENT"' EXIT
curl -fsSL "$TORRENT_URL" -o "$TMP_TORRENT"
echo "Torrent de teste: $TORRENT_NAME — $TORRENT_URL"

TORRENT_HASH="$(python3 "$REPO_ROOT/scripts/media/_torrent_info_hash.py" "$TMP_TORRENT")"
echo "Info-hash: $TORRENT_HASH"

scp -q -o BatchMode=yes "$TMP_TORRENT" "${AGLSRV1}:/tmp/bench-test.torrent"
scp -q -o BatchMode=yes "$REPO_ROOT/scripts/media/_bench_deluge_ct157.py" "${AGLSRV1}:/tmp/agl-bench-deluge.py"
scp -q -o BatchMode=yes "$REPO_ROOT/scripts/media/_bench_qbit_ct121.py" "${AGLSRV1}:/tmp/agl-bench-qbit.py"

RESULT_REMOTE="/tmp/agl-download-perf-$(date +%Y%m%d-%H%M%S).txt"
echo "Relatório remoto: $RESULT_REMOTE"

ssh -o ConnectTimeout=15 -o BatchMode=yes "$AGLSRV1" "bash -s" "$RESULT_REMOTE" "$TORRENT_NAME" "$SAB_TEST_NZB_URL" "$TORRENT_HASH" "$SKIP_SAB" <<'REMOTE'
set -euo pipefail
RESULT="$1"
TORRENT_NAME="$2"
SAB_TEST_NZB_URL="$3"
TORRENT_HASH="$4"
SKIP_SAB="${5:-false}"
TORRENT="/tmp/bench-test.torrent"
REPORT="$RESULT"

log() { echo "$*" | tee -a "$REPORT"; }

: >"$REPORT"
log "=== AGL Download Clients Benchmark ==="
log "Data: $(date -Iseconds)"
log ""

log "=== Host ==="
uptime | tee -a "$REPORT"
log ""

for VMID in 121 141 157 165; do
  log "=== CT${VMID} config ==="
  pct config "$VMID" | grep -E '^(cores|memory|net0|mp)' | tee -a "$REPORT"
  log ""
done

log "=== CT121 disco + ulimit ==="
pct exec 121 -- bash -c 'ulimit -n; df -h /mnt/overpower; dd if=/dev/zero of=/mnt/overpower/downs/.bench bs=64M count=16 conv=fdatasync 2>&1 | tail -1; rm -f /mnt/overpower/downs/.bench' | tee -a "$REPORT"
log ""

log "=== CT141 SABnzbd disco ==="
pct exec 141 -- bash -c 'df -h /mnt/overpower; dd if=/dev/zero of=/mnt/overpower/downs/.bench bs=64M count=16 conv=fdatasync 2>&1 | tail -1; rm -f /mnt/overpower/downs/.bench' | tee -a "$REPORT"
log ""

log "=== CT157 Deluge disco ==="
pct exec 157 -- bash -c 'df -h /mnt/overpower; dd if=/dev/zero of=/mnt/overpower/downs/.bench bs=64M count=16 conv=fdatasync 2>&1 | tail -1; rm -f /mnt/overpower/downs/.bench' | tee -a "$REPORT"
log ""

log "=== CT165 disco + ulimit ==="
pct exec 165 -- bash -c 'ulimit -n; df -h /mnt/overpower; dd if=/dev/zero of=/mnt/overpower/downs/.bench bs=64M count=16 conv=fdatasync 2>&1 | tail -1; rm -f /mnt/overpower/downs/.bench' | tee -a "$REPORT"
log ""

pct push 165 "$TORRENT" /tmp/bench-test.torrent
pct push 121 "$TORRENT" /tmp/bench-test.torrent
pct push 157 "$TORRENT" /tmp/bench-test.torrent
pct push 123 "$TORRENT" /tmp/bench-test.torrent

log "=== aria2 CT165 (download completo) ==="
START=$(date +%s)
pct exec 165 -- bash -s "$TORRENT_NAME" <<'IN' | tee -a "$REPORT"
set -euo pipefail
TNAME="$1"
OUTDIR="/mnt/overpower/downs/bench-aria2"
rm -rf "$OUTDIR"
mkdir -p "$OUTDIR"
aria2c -d "$OUTDIR" \
  --max-connection-per-server=16 --split=16 --min-split-size=5M \
  --seed-time=0 --seed-ratio=0 --bt-max-peers=100 \
  --summary-interval=5 --console-log-level=notice \
  --allow-overwrite=true --auto-file-renaming=false \
  --bt-remove-unselected-file=true \
  "/tmp/bench-test.torrent" 2>&1 | tee /tmp/aria2-bench.log
if [[ -f "$OUTDIR/$TNAME" ]]; then
  stat -c "RESULT COMPLETE size_bytes=%s" "$OUTDIR/$TNAME"
else
  echo "RESULT INCOMPLETE"
  ls -la "$OUTDIR" || true
  tail -20 /tmp/aria2-bench.log || true
fi
IN
log "CT165 elapsed_sec=$(($(date +%s)-START))"
log ""

log "=== qBittorrent CT121 (download fresco, API localhost) ==="
pct exec 121 -- mkdir -p /mnt/overpower/downs/bench-qbit
# credenciais do Radarr (só no CT123)
QB_USER=$(pct exec 123 -- python3 -c "import json,sqlite3;c=sqlite3.connect('/var/lib/radarr/radarr.db');print(json.loads(c.execute(\"SELECT Settings FROM DownloadClients WHERE Name='qBittorrent AGLSRV1'\").fetchone()[0])['username'])")
QB_PASS=$(pct exec 123 -- python3 -c "import json,sqlite3;c=sqlite3.connect('/var/lib/radarr/radarr.db');print(json.loads(c.execute(\"SELECT Settings FROM DownloadClients WHERE Name='qBittorrent AGLSRV1'\").fetchone()[0])['password'])")

log "Aguardar WebUI (restauro de torrents pode demorar vários minutos)..."
WEBUI_DEADLINE=$(($(date +%s) + 600))
while [[ $(date +%s) -lt $WEBUI_DEADLINE ]]; do
  if pct exec 121 -- curl -sf -o /dev/null --connect-timeout 2 http://127.0.0.1:8090/ 2>/dev/null; then
    log "WebUI pronta em $(($(date +%s) - (WEBUI_DEADLINE - 600)))s"
    break
  fi
  sleep 10
done
if ! pct exec 121 -- curl -sf -o /dev/null --connect-timeout 2 http://127.0.0.1:8090/ 2>/dev/null; then
  log "ERRO: WebUI CT121 não respondeu em 600s"
fi

pct push 121 /tmp/agl-bench-qbit.py /tmp/agl-bench-qbit.py
START=$(date +%s)
pct exec 121 -- env QB_USER="$QB_USER" QB_PASS="$QB_PASS" TORRENT_HASH="$TORRENT_HASH" \
  python3 /tmp/agl-bench-qbit.py "$TORRENT_NAME" | tee -a "$REPORT"
QB_EXIT=$?
log "CT121 qbit exit=$QB_EXIT elapsed_sec=$(($(date +%s)-START))"
log ""

log "=== Deluge CT157 (daemon RPC :58846) ==="
log "CT157 recursos:"
pct config 157 | grep -E '^(cores|memory|mp0)' | tee -a "$REPORT"
log "Deluge core.conf (limites):"
pct exec 157 -- bash -c 'for f in /root/.config/deluge/core.conf /root/.config/deluge/host.conf /etc/deluge/core.conf; do
  [ -f "$f" ] && echo "--- $f ---" && grep -E "max_connections|max_download|max_upload|rate_limit|listen_ports" "$f" 2>/dev/null | head -20
done' | tee -a "$REPORT" || true
pct push 157 /tmp/agl-bench-deluge.py /tmp/agl-bench-deluge.py
pct exec 157 -- bash -c 'rm -rf /mnt/overpower/downs/bench-deluge && mkdir -p /mnt/overpower/downs/bench-deluge'
START=$(date +%s)
set +e
DL_PASS=$(pct exec 123 -- python3 -c "import json,sqlite3;c=sqlite3.connect('/var/lib/radarr/radarr.db');print(json.loads(c.execute(\"SELECT Settings FROM DownloadClients WHERE Name='Deluge AGLSRV1'\").fetchone()[0])['password'])")
pct exec 157 -- env DL_DAEMON_PASS="$DL_PASS" python3 /tmp/agl-bench-deluge.py "$TORRENT_NAME" | tee -a "$REPORT"
DL_EXIT=${PIPESTATUS[0]}
set -e
if [[ "$DL_EXIT" -ne 0 ]]; then
  log "CT157 deluge SKIP/FAIL exit=$DL_EXIT (ver ct157-deluge-auth-sync.sh; web.default_daemon)"
else
  log "CT157 deluge exit=$DL_EXIT elapsed_sec=$(($(date +%s)-START))"
fi
log ""

if [[ "$SKIP_SAB" != true ]]; then
log "=== SABnzbd CT141 (NZB teste ~100 MiB) ==="
SAB_KEY=$(pct exec 123 -- python3 -c "import json,sqlite3;c=sqlite3.connect('/var/lib/radarr/radarr.db');print(json.loads(c.execute(\"SELECT Settings FROM DownloadClients WHERE Name='SABnzbd AGLSRV1'\").fetchone()[0])['apiKey'])")
SAB_NZB="${SAB_TEST_NZB_URL}"
log "SAB test NZB: $SAB_NZB"

log "Aguardar API SABnzbd (arranque pode demorar — postproc/history)..."
SAB_DEADLINE=$(($(date +%s) + 600))
while [[ $(date +%s) -lt $SAB_DEADLINE ]]; do
  if pct exec 141 -- curl -sf -o /dev/null --connect-timeout 2 "http://127.0.0.1:7777/api?mode=version&apikey=${SAB_KEY}" 2>/dev/null; then
    log "SAB API pronta"
    break
  fi
  sleep 15
done

START=$(date +%s)
set +e
pct exec 141 -- env SAB_KEY="$SAB_KEY" SAB_NZB="$SAB_NZB" python3 <<'PY' | tee -a "$REPORT"
import json, os, sys, time, urllib.parse, urllib.request

api = os.environ["SAB_KEY"]
nzb_url = os.environ["SAB_NZB"]
base = "http://127.0.0.1:7777/api"

def api_get(params):
    q = urllib.parse.urlencode({**params, "apikey": api, "output": "json"})
    with urllib.request.urlopen(f"{base}?{q}", timeout=120) as r:
        return json.loads(r.read())

# retomar fila se congelada (freeze downloads)
st = api_get({"mode": "queue"})
if st.get("queue", {}).get("paused"):
    api_get({"mode": "resume"})
    print("queue resumed")

def slot_label(s):
    return (s.get("nzb_name") or s.get("filename") or "").lower()

api_get({
    "mode": "addurl",
    "name": nzb_url,
    "cat": "*",
    "priority": "-2",
    "nzbname": "sab_test_100MB",
})
print(f"added nzb url={nzb_url}")

deadline = time.time() + 1800
last = ""
while time.time() < deadline:
    q = api_get({"mode": "queue"})
    slots = q.get("queue", {}).get("slots", [])
    hit = [
        s
        for s in slots
        if "sab_test" in slot_label(s) or "test_download" in slot_label(s)
    ]
    if hit:
        s = hit[0]
        if s.get("status") == "Paused" and s.get("nzo_id"):
            api_get({"mode": "queue", "name": "resume", "value": s["nzo_id"]})
            print(f"resumed slot {s.get('nzo_id')}")
        mb = s.get("mb", "?")
        pct_done = s.get("percentage", "?")
        mbleft = s.get("mbleft", "?")
        last = f"queue nzb={slot_label(s)} mb={mb} left={mbleft} pct={pct_done} status={s.get('status')}"
        print(last)
    hist = api_get({"mode": "history", "limit": 5})
    for h in hist.get("history", {}).get("slots", []):
        name = h.get("name", "")
        if "test" in name.lower() or "sab_test" in name.lower():
            status = h.get("status", "")
            if status == "Completed":
                print(f"RESULT COMPLETE name={name} size={h.get('bytes')} report={h.get('report', '')[:200]}")
                sys.exit(0)
            if status == "Failed":
                print(f"RESULT FAILED name={name} fail={h.get('fail_message', '')}")
                sys.exit(3)
    time.sleep(15)
print("RESULT TIMEOUT")
print(last)
sys.exit(2)
PY
SAB_EXIT=$?
set -e
if [[ "$SAB_EXIT" -ne 0 ]]; then
  log "CT141 sabnzbd SKIP/FAIL exit=$SAB_EXIT (API presa em 'Loading postproc queue'? reiniciar ou ver history1.db)"
else
  log "CT141 sabnzbd exit=$SAB_EXIT elapsed_sec=$(($(date +%s)-START))"
fi
fi
log ""
log "=== Resumo MiB/s (torrent Debian) ==="
grep -E 'peak_MiBs|avg_MiBs|RESULT COMPLETE' "$REPORT" | tail -20 | tee -a "$REPORT" || true
log ""
log "Relatório: $REPORT"
REMOTE

echo ""
ssh "$AGLSRV1" "cat '$RESULT_REMOTE'"
