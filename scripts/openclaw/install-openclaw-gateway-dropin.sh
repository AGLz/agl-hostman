#!/usr/bin/env bash
# Instala drop-in do systemd user com UnsetEnvironment (evita herança LiteLLM).
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DROP=~/.config/systemd/user/openclaw-gateway.service.d
mkdir -p "$DROP"
/bin/cp -f "$REPO/config/openclaw/openclaw-gateway.service.d-env.conf" "$DROP/env.conf"
systemctl --user daemon-reload
echo "OK: $DROP/env.conf — correr: systemctl --user restart openclaw-gateway.service"
