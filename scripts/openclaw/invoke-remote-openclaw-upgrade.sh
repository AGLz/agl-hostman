#!/usr/bin/env bash
# Copia e executa remote-openclaw-upgrade-gateway.sh em agldv03 + fgsrv06
# Uso: bash scripts/openclaw/invoke-remote-openclaw-upgrade.sh
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$REPO/scripts/openclaw/remote-openclaw-upgrade-gateway.sh"
HOSTS=(root@100.94.221.87 root@100.83.51.9)
[[ -f "$SCRIPT" ]] || exit 1
for h in "${HOSTS[@]}"; do
  echo "========== $h =========="
  scp -q "$SCRIPT" "$h:/tmp/remote-openclaw-upgrade-gateway.sh"
  ssh -o BatchMode=yes -o ConnectTimeout=30 "$h" "chmod +x /tmp/remote-openclaw-upgrade-gateway.sh && bash /tmp/remote-openclaw-upgrade-gateway.sh"
done
echo "Concluído."
