#!/usr/bin/env bash
# Fase A — medir linha e validar SAB (sem mudar stack de clientes).
#
# Uso:
#   bash scripts/media/download-clients-phase-a.sh              # plano
#   bash scripts/media/download-clients-phase-a.sh --apply      # corre no AGLSRV1
#   bash scripts/media/download-clients-phase-a.sh --apply --sab-test
#
# Variáveis:
#   AGLSRV1          SSH (default root@100.107.113.33)
#   IPERF_TARGET      Destino opcional gateway/LAN (default 192.168.0.1)
#   SAB_TEST_NZB_URL  NZB teste (default 100MB oficial SAB)

set -euo pipefail

AGLSRV1="${AGLSRV1:-root@100.107.113.33}"
IPERF_TARGET="${IPERF_TARGET:-192.168.0.1}"
SAB_TEST_NZB_URL="${SAB_TEST_NZB_URL:-https://sabnzbd.org/tests/test_download_100MB.nzb}"
APPLY=false
SAB_TEST=false
for a in "$@"; do
  [[ "$a" == --apply ]] && APPLY=true
  [[ "$a" == --sab-test ]] && SAB_TEST=true
done

run() { ssh -o ConnectTimeout=15 -o BatchMode=yes "$AGLSRV1" "$@"; }

section() { echo ""; echo "=== $1 ==="; }

section "Fase A — plano"
cat <<PLAN
A.1 iperf3: servidor no host (192.168.0.245), cliente em CT121 → mede veth/LAN
A.2 iperf3 opcional: host → IPERF_TARGET=${IPERF_TARGET} (5s; falha se sem iperf -s no destino)
A.3 SABnzbd CT141: limpar slots de teste, resume fila, tuning bandwidth_max
A.4 SAB teste NZB 100MB (--sab-test): só com --apply
PLAN

if [[ "$APPLY" != true ]]; then
  echo ""
  echo "Executar: bash scripts/media/download-clients-phase-a.sh --apply --sab-test"
  exit 0
fi

RESULT="/tmp/agl-download-phase-a-$(date +%Y%m%d-%H%M%S).txt"
echo "Relatório remoto: $RESULT"

run "bash -s" "$RESULT" "$IPERF_TARGET" "$SAB_TEST_NZB_URL" "$SAB_TEST" <<'REMOTE'
set -euo pipefail
RESULT="$1"
IPERF_TARGET="$2"
SAB_NZB="$3"
DO_SAB_TEST="${4:-false}"

log() { echo "$*" | tee -a "$RESULT"; }

: >"$RESULT"
log "=== AGL Download Phase A ==="
log "Data: $(date -Iseconds)"
log ""

HOST_IP=$(hostname -I | awk '{print $1}')
log "=== A.1 iperf3 (host ${HOST_IP}:5202 ← CT121) ==="
if command -v iperf3 >/dev/null; then
  pkill -f 'iperf3 -s -p 5202' 2>/dev/null || true
  sleep 1
  iperf3 -s -p 5202 -1 >/tmp/iperf-host-server.log 2>&1 &
  sleep 2
  if pct status 121 | grep -q running; then
    pct exec 121 -- iperf3 -c "$HOST_IP" -p 5202 -t 10 -P 4 2>&1 | tee -a "$RESULT" || log "iperf3 CT121→host FALHOU"
  else
    log "CT121 não running — skip iperf CT"
  fi
  log ""
  log "=== A.2 iperf3 (host → ${IPERF_TARGET}, 5s) ==="
  if iperf3 -c "$IPERF_TARGET" -t 5 2>&1 | tee -a "$RESULT"; then
    log "gateway/LAN OK"
  else
    log "SKIP: sem iperf3 -s em ${IPERF_TARGET} (normal). Definir IPERF_TARGET=outro host com iperf3 -s"
  fi
else
  log "iperf3 não instalado no host"
fi
log ""

log "=== A.3 SABnzbd CT141 — preparação ==="
SAB_KEY=$(pct exec 123 -- python3 -c "
import json, sqlite3
c = sqlite3.connect('/var/lib/radarr/radarr.db')
row = c.execute(\"SELECT Settings FROM DownloadClients WHERE Name='SABnzbd AGLSRV1'\").fetchone()
print(json.loads(row[0])['apiKey'])
" 2>/dev/null) || SAB_KEY=""

if [[ -z "$SAB_KEY" ]]; then
  log "ERRO: não foi possível obter API key SAB do Radarr CT123"
else
  pct exec 141 -- env SAB_KEY="$SAB_KEY" bash -s <<'IN_CT' | tee -a "$RESULT"
set -euo pipefail
KEY="$SAB_KEY"
python3 - <<'PY'
import json, urllib.parse, urllib.request, os

api = "http://127.0.0.1:7777/api"
key = os.environ["SAB_KEY"]

def api_get(params):
    q = urllib.parse.urlencode({**params, "apikey": key, "output": "json"})
    with urllib.request.urlopen(f"{api}?{q}", timeout=60) as r:
        return json.loads(r.read())

api_get({"mode": "resume"})
q = api_get({"mode": "queue"})
for s in q.get("queue", {}).get("slots", []):
    name = (s.get("filename") or s.get("nzb_name") or "").lower()
    if "sab_test" in name or "test_download" in name or "phasea" in name:
        nzo = s["nzo_id"]
        api_get({"mode": "queue", "name": "delete", "value": nzo})
        print(f"deleted queue {nzo} {name}")
print("queue resumed/cleaned")
PY

# Tuning mínimo high-speed (ini)
INI=/root/.sabnzbd/sabnzbd.ini
STAMP=$(date +%Y%m%d-%H%M%S)
cp -a "$INI" "${INI}.bak.phasea.${STAMP}"
python3 - "$INI" <<'PY'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
updates = {
    "bandwidth_max": "125000",  # ~100 MiB/s em KB/s (wiki high speed)
    "receive_threads": "4",
    "num_simd_decoders": "4",
}
for key, val in updates.items():
    pat = rf"^({re.escape(key)}\s*=\s*).*$"
    if re.search(pat, text, flags=re.M):
        text = re.sub(pat, rf"\g<1>{val}", text, count=1, flags=re.M)
    else:
        text += f"\n{key} = {val}\n"
path.write_text(text, encoding="utf-8")
PY
systemctl restart sabnzbd 2>/dev/null || systemctl restart sabnzbdplus 2>/dev/null || true
sleep 5
grep -E '^(bandwidth_max|receive_threads|cache_max|direct_unpack)' "$INI" | head -6
df -h /mnt/overpower | tail -1
IN_CT
fi
log ""

if [[ "$DO_SAB_TEST" == "true" && -n "$SAB_KEY" ]]; then
  log "=== A.4 SABnzbd teste NZB ==="
  log "NZB: $SAB_NZB"
  pct exec 141 -- env SAB_KEY="$SAB_KEY" SAB_NZB="$SAB_NZB" python3 <<'PY' | tee -a "$RESULT"
import json, os, sys, time, urllib.parse, urllib.request

api_key = os.environ["SAB_KEY"]
nzb_url = os.environ["SAB_NZB"]
base = "http://127.0.0.1:7777/api"

def api_get(params):
    q = urllib.parse.urlencode({**params, "apikey": api_key, "output": "json"})
    with urllib.request.urlopen(f"{base}?{q}", timeout=120) as r:
        return json.loads(r.read())

for _ in range(40):
    try:
        api_get({"mode": "version"})
        break
    except Exception:
        time.sleep(3)
else:
    print("SAB API timeout")
    sys.exit(4)

api_get({"mode": "resume"})
api_get({
    "mode": "addurl",
    "name": nzb_url,
    "cat": "*",
    "priority": "-2",
    "nzbname": "phasea_test_100mb",
})
print(f"added {nzb_url}")

t0 = time.time()
peak_kbps = 0
deadline = time.time() + 900
while time.time() < deadline:
    q = api_get({"mode": "queue"})
    qinfo = q.get("queue", {})
    try:
        kbps = int(float(str(qinfo.get("kbpersec", "0")).replace(",", "") or 0) * 1024)
    except ValueError:
        kbps = 0
    if kbps > peak_kbps:
        peak_kbps = kbps
    slots = qinfo.get("slots", [])
    hit = [s for s in slots if "phasea" in (s.get("filename") or "").lower()]
    if hit:
        s = hit[0]
        if s.get("status") == "Paused" and s.get("nzo_id"):
            api_get({"mode": "queue", "name": "resume", "value": s["nzo_id"]})
        print(f"queue status={s.get('status')} pct={s.get('percentage')} kbps={kbps}")
    hist = api_get({"mode": "history", "limit": 5})
    for h in hist.get("history", {}).get("slots", []):
        if "phasea" in (h.get("name") or "").lower():
            if h.get("status") == "Completed":
                elapsed = time.time() - t0
                mib = peak_kbps / 1024 if peak_kbps else 0
                print(f"RESULT COMPLETE elapsed_sec={elapsed:.0f} peak_MiBs_approx={mib:.2f}")
                sys.exit(0)
            if h.get("status") == "Failed":
                print(f"RESULT FAILED fail={h.get('fail_message', '')}")
                sys.exit(3)
    time.sleep(10)
print(f"RESULT TIMEOUT peak_kbps={peak_kbps}")
sys.exit(2)
PY
  SAB_EXIT=$? || true
  log "SAB test exit=$SAB_EXIT"
fi

log ""
log "=== Status SAB (warnings) ==="
if [[ -n "$SAB_KEY" ]]; then
  pct exec 141 -- curl -sf "http://127.0.0.1:7777/api?mode=status&apikey=${SAB_KEY}&output=json" 2>/dev/null \
    | python3 -c "import sys,json;d=json.load(sys.stdin);print('warnings:',len(d.get('status',{}).get('warnings',[])));[print('-',w[:120]) for w in d.get('status',{}).get('warnings',[])[:5]]" \
    | tee -a "$RESULT" || true
fi

log ""
log "Relatório: $RESULT"
REMOTE

echo ""
run "cat '$RESULT'" || true
exit 0
