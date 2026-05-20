#!/usr/bin/env bash
# Desactiva Telegram no CT191 para evitar 409 getUpdates com CT187 (mesmo token).
# Produção Telegram: apenas CT187. CT191 = Jarvis O / GStack (Control UI, A2A, sem poll Telegram).
#
# Uso (AGLSRV1 ou SSH):
#   bash scripts/proxmox/pct191-disable-telegram-duplicate.sh
#   bash scripts/proxmox/pct191-disable-telegram-duplicate.sh --restart

set -euo pipefail

VMID=191
CONFIG_PATH="/opt/agl-openclaw/config/openclaw.json"
RESTART=false

for arg in "$@"; do
  case "$arg" in
    --restart) RESTART=true ;;
    -h | --help)
      echo "Uso: $0 [--restart]" >&2
      exit 0
      ;;
    *)
      echo "Argumento desconhecido: $arg" >&2
      exit 1
      ;;
  esac
done

command -v pct >/dev/null || {
  echo "ERRO: executar no Proxmox (pct)." >&2
  exit 1
}

if ! pct status "${VMID}" 2>/dev/null | grep -q running; then
  echo "ERRO: CT${VMID} não está running." >&2
  exit 1
fi

pct exec "${VMID}" -- test -f "${CONFIG_PATH}" || {
  echo "ERRO: ${CONFIG_PATH} não existe no CT${VMID}." >&2
  exit 1
}

BACKUP_SUFFIX="$(date -u +%Y%m%dT%H%M%SZ)"
pct exec "${VMID}" -- cp "${CONFIG_PATH}" "${CONFIG_PATH}.bak.telegram-off.${BACKUP_SUFFIX}"

pct exec "${VMID}" -- python3 - <<'PY'
import json
from pathlib import Path

path = Path("/opt/agl-openclaw/config/openclaw.json")
data = json.loads(path.read_text(encoding="utf-8"))
channels = data.setdefault("channels", {})
tg = channels.setdefault("telegram", {})
tg["enabled"] = False
# Evitar token no JSON; CT191 não deve fazer poll
if "botToken" in tg:
    del tg["botToken"]
path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print("OK: channels.telegram.enabled=false em", path)
PY

if [[ "${RESTART}" == true ]]; then
  pct exec "${VMID}" -- bash -c 'cd /opt/agl-openclaw && docker compose restart openclaw-gateway'
  sleep 5
  pct exec "${VMID}" -- curl -sf http://127.0.0.1:28789/healthz && echo ""
fi

echo "Feito. Confirmar logs CT191 sem 409; Telegram activo só no CT187."
