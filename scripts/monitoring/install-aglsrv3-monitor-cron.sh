#!/usr/bin/env bash
# Instala cron de monitorização AGLSRV3 no host actual (canónico: agldv03 CT179).
#
# Uso:
#   sudo bash scripts/monitoring/install-aglsrv3-monitor-cron.sh
#   sudo bash scripts/monitoring/install-aglsrv3-monitor-cron.sh --test-run
#   sudo bash scripts/monitoring/install-aglsrv3-monitor-cron.sh --uninstall
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
CHECK_SCRIPT="$REPO_ROOT/scripts/monitoring/aglsrv3-health-check.sh"
CRON_FILE="/etc/cron.d/agl-hostman-aglsrv3"
LOG_DIR="/var/log/hostman"
ENV_DIR="/etc/agl-hostman"
ENV_FILE="${ENV_DIR}/monitor.env"
SCHEDULE="${AGLSRV3_CRON_SCHEDULE:-*/5 * * * *}"

TEST_RUN=0
UNINSTALL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --test-run) TEST_RUN=1; shift ;;
    --uninstall) UNINSTALL=1; shift ;;
    -h|--help)
      sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Argumento desconhecido: $1" >&2; exit 2 ;;
  esac
done

if [[ "$UNINSTALL" -eq 1 ]]; then
  rm -f "$CRON_FILE"
  echo "OK removido $CRON_FILE"
  exit 0
fi

[[ -f "$CHECK_SCRIPT" ]] || { echo "ERRO: falta $CHECK_SCRIPT" >&2; exit 1; }
chmod +x "$CHECK_SCRIPT" "$SCRIPT_DIR/agl-alert-notify.sh" 2>/dev/null || true

mkdir -p "$LOG_DIR" "$ENV_DIR" /var/lib/agl-hostman/aglsrv3-monitor

if [[ ! -f "$ENV_FILE" ]]; then
  install -m 0600 "$REPO_ROOT/config/monitoring/aglsrv3-monitor.env.example" "$ENV_FILE"
  echo "AVISO: editar $ENV_FILE com AGL_ALERT_TELEGRAM_BOT_TOKEN"
fi

# Sincronizar token do zshrc do root se monitor.env ainda vazio
python3 - <<PY
import re
from pathlib import Path

env_path = Path("$ENV_FILE")
text = env_path.read_text()
token = ""
for line in text.splitlines():
    if line.startswith("AGL_ALERT_TELEGRAM_BOT_TOKEN="):
        token = line.split("=", 1)[1].strip()
        break
if token and len(token) > 10:
    raise SystemExit(0)
z = Path("/root/.zshrc")
if not z.exists():
    raise SystemExit(0)
for line in z.read_text().splitlines():
    m = re.match(r"^export TELEGRAM_BOT_TOKEN=(.+)$", line.strip())
    if not m:
        continue
    new_token = m.group(1).strip().strip("\"'")
    lines = []
    replaced = False
    for ln in text.splitlines():
        if ln.startswith("AGL_ALERT_TELEGRAM_BOT_TOKEN="):
            lines.append(f"AGL_ALERT_TELEGRAM_BOT_TOKEN={new_token}")
            replaced = True
        else:
            lines.append(ln)
    if not replaced:
        lines.append(f"AGL_ALERT_TELEGRAM_BOT_TOKEN={new_token}")
    env_path.write_text("\n".join(lines) + "\n")
    env_path.chmod(0o600)
    print("OK token Telegram sincronizado de /root/.zshrc")
    break
PY

cat >"$CRON_FILE" <<EOF
# AGL Hostman — monitor AGLSRV3 (host + CTs + man3 + Ollama)
# Repo: $REPO_ROOT
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
AGL_MONITOR_ENV=$ENV_FILE
$SCHEDULE root cd $REPO_ROOT && bash $CHECK_SCRIPT >> $LOG_DIR/aglsrv3-health.log 2>&1
EOF

chmod 644 "$CRON_FILE"
echo "OK cron instalado: $CRON_FILE"
echo "Schedule: $SCHEDULE"
echo "Log: $LOG_DIR/aglsrv3-health.log"
echo "Estado anti-flap: /var/lib/agl-hostman/aglsrv3-monitor/"
echo ""
echo "Configurar Telegram: nano $ENV_FILE"

if [[ "$TEST_RUN" -eq 1 ]]; then
  echo ""
  echo "=== Test run ==="
  AGL_MONITOR_ENV="$ENV_FILE" bash "$CHECK_SCRIPT" --check-only
  echo ""
  echo "=== Test alert (se token configurado) ==="
  AGL_MONITOR_ENV="$ENV_FILE" bash "$CHECK_SCRIPT" --test-alert || true
fi
