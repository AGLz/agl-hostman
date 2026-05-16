#!/usr/bin/env bash
# Troca o bot Telegram do OpenClaw no CT187 (novo token @BotFather → novo bot → evita 409 getUpdates).
# O token não aparece na linha de comandos do CT: pct push a partir de um ficheiro no AGLSRV1.
#
# No AGLSRV1:
#   printf '%s' 'TOKEN_DO_NEWBOT' > /root/ct187-telegram.token.new && chmod 600 /root/ct187-telegram.token.new
#   bash /caminho/agl-hostman/scripts/proxmox/pct187-rotate-telegram-bot-token.sh /root/ct187-telegram.token.new
#   shred -u /root/ct187-telegram.token.new 2>/dev/null || rm -f /root/ct187-telegram.token.new

set -euo pipefail

TOKEN_FILE="${1:-/root/ct187-telegram.token.new}"
CT=187
REMOTE_TMP="/tmp/ct187-new-telegram.token"

if [[ ! -f "$TOKEN_FILE" ]]; then
  echo "ERRO: ficheiro inexistente: $TOKEN_FILE" >&2
  exit 1
fi

command -v pct >/dev/null || {
  echo "ERRO: pct não encontrado — executar no Proxmox AGLSRV1." >&2
  exit 1
}

pct push "$CT" "$TOKEN_FILE" "$REMOTE_TMP"

pct exec "$CT" -- python3 <<'PY'
from datetime import datetime
from pathlib import Path

tmp = Path("/tmp/ct187-new-telegram.token")
token = tmp.read_text().strip()
tmp.unlink(missing_ok=True)
if not token:
    raise SystemExit("ERRO: token vazio")

env_path = Path("/opt/agl-openclaw/.env")
if not env_path.is_file():
    raise SystemExit("ERRO: falta /opt/agl-openclaw/.env")

text = env_path.read_text()
lines = text.splitlines()
prefix = "TELEGRAM_BOT_TOKEN="
out = []
found = False
for line in lines:
    if line.startswith(prefix):
        out.append(prefix + token)
        found = True
    else:
        out.append(line)
if not found:
    out.append(prefix + token)

bak = env_path.parent / f".env.bak.telegram.{datetime.now():%Y%m%d%H%M%S}"
bak.write_text(text)
env_path.write_text("\n".join(out) + "\n")
PY

pct exec "$CT" -- bash -c "cd /opt/agl-openclaw && docker compose -f docker-compose.yml up -d && docker compose -f docker-compose.yml restart"

echo "OK: TELEGRAM_BOT_TOKEN actualizado no CT${CT} e stack reiniciada."
echo "Logs: pct exec ${CT} -- docker logs agl-openclaw-openclaw-gateway-1 --tail 35"
