#!/usr/bin/env bash
# Spike Cursor chat no auth2api (CT186) — matriz de cloaking / hosts.
# NÃO altera Hermes. Restaura config no fim (salvo --keep-working).
set -euo pipefail

CT186_SSH="${AUTH2API_SSH:-root@100.125.249.8}"
REMOTE_AUTH="${AUTH2API_REMOTE_DIR:-/opt/agl-auth2api}"
MODEL="${CURSOR_SMOKE_MODEL:-cursor-default}"
KEEP=0
for a in "$@"; do
  case "$a" in
    --keep-working) KEEP=1 ;;
    *) echo "Arg desconhecido: $a" >&2; exit 1 ;;
  esac
done

echo "Spike Cursor chat @ $CT186_SSH model=$MODEL keep=$KEEP"

ssh -o StrictHostKeyChecking=accept-new -o BatchMode=yes "$CT186_SSH" \
  REMOTE_AUTH="$REMOTE_AUTH" MODEL="$MODEL" KEEP="$KEEP" bash -s <<'REMOTE'
set -euo pipefail
cd "$REMOTE_AUTH"
cp -a config.yaml config.yaml.bak.cursor-spike.ORIG
set -a; source .env; set +a
KEY="${AUTH2API_API_KEY:?}"

smoke() {
  local label="$1" model="${2:-$MODEL}"
  local out
  out="$(curl -sS -m 50 "http://127.0.0.1:8317/v1/chat/completions" \
    -H "Authorization: Bearer ${KEY}" -H "Content-Type: application/json" \
    -d "{\"model\":\"${model}\",\"messages\":[{\"role\":\"user\",\"content\":\"Say OK\"}],\"max_tokens\":16}" || true)"
  python3 -c '
import json,sys
label, raw = sys.argv[1], sys.argv[2]
try:
  d=json.loads(raw)
except Exception as e:
  print("[%s] FAIL parse %s" % (label, e)); sys.exit(0)
err=d.get("error") or {}
msg=err.get("message") if isinstance(err,dict) else None
content=(d.get("choices") or [{}])[0].get("message",{}).get("content")
if content:
  print("[%s] OK %r" % (label, content))
elif msg:
  short = msg.replace("\n", " ")[:180]
  print("[%s] FAIL %s" % (label, short))
else:
  print("[%s] FAIL %s" % (label, d))
' "$label" "$out"
}

apply() {
  local name="$1"
  shift
  echo "=== $name ==="
  python3 - "$name" "$@" <<'PY'
import sys, yaml
from pathlib import Path
name = sys.argv[1]
# args: key=value pairs for cursor cloaking + debug=
cursor = {}
debug = "verbose"
for a in sys.argv[2:]:
    k, _, v = a.partition("=")
    if k == "debug":
        debug = v
    else:
        cursor[k] = v
p = Path("config.yaml")
cfg = yaml.safe_load(p.read_text())
cur = cfg.setdefault("cloaking", {}).setdefault("cursor", {})
# reset known keys then apply
for k in list(cur.keys()):
    pass
cur.update(cursor)
cfg["debug"] = debug
p.write_text(yaml.dump(cfg, default_flow_style=False, allow_unicode=True))
print("cloaking.cursor=", cur)
PY
  docker compose -f docker-compose.ct186.yml up -d --force-recreate auth2api >/dev/null
  for i in $(seq 1 12); do
    curl -fsS -m 2 http://127.0.0.1:8317/health >/dev/null 2>&1 && break
    sleep 1
  done
  smoke "$name"
}

smoke "baseline"

apply "cli-version-string" \
  client-version=cli-2026.01.09-231024f client-type=ide ghost-mode=false \
  agent-base-url=https://api2.cursor.sh api-base-url=https://api2.cursor.sh

apply "client-type-cli" \
  client-version=cli-2026.01.09-231024f client-type=cli ghost-mode=false \
  agent-base-url=https://api2.cursor.sh api-base-url=https://api2.cursor.sh

apply "desktop-3.12.17-ghost-false" \
  client-version=3.12.17 client-type=ide ghost-mode=false \
  agent-base-url=https://api2.cursor.sh api-base-url=https://api2.cursor.sh

apply "agentn-api5" \
  client-version=3.12.17 client-type=ide ghost-mode=false \
  agent-base-url=https://agentn.api5.cursor.sh api-base-url=https://agentn.api5.cursor.sh

apply "api5-cli" \
  client-version=cli-2026.01.09-231024f client-type=cli ghost-mode=false \
  agent-base-url=https://agentn.api5.cursor.sh api-base-url=https://agentn.api5.cursor.sh

smoke "last+gpt56" "cursor-gpt-5.6-sol-medium"

# Recent verbose errors (last 40 lines mentioning version/cursor)
echo "=== recent logs ==="
docker logs agl-auth2api 2>&1 | grep -iE 'version|unsupported|cursor|api5|StreamUnified' | tail -25 || true

if [[ "$KEEP" != "1" ]]; then
  echo "=== restore ORIG ==="
  cp -a config.yaml.bak.cursor-spike.ORIG config.yaml
  docker compose -f docker-compose.ct186.yml up -d --force-recreate auth2api >/dev/null
  sleep 3
  curl -fsS http://127.0.0.1:8317/health >/dev/null
  smoke "restored"
else
  echo "KEEP: última variante activa; ORIG em config.yaml.bak.cursor-spike.ORIG"
fi
REMOTE

echo
echo "Nota: sem state.vscdb neste host. Num desktop Cursor 3.12.x:"
echo "  bash scripts/auth2api/login.sh --provider=cursor --cursor-import-local"
echo "  bash scripts/auth2api/deploy-ct186.sh --skip-build"
echo "  bash scripts/auth2api/spike-cursor-chat.sh"
