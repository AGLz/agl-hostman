#!/usr/bin/env bash
# Remoto: npm install openclaw@latest + gateway install --force + restart user systemd
# Uso local: scp … && ssh … bash remote-openclaw-upgrade-gateway.sh
# Uso via:   bash scripts/openclaw/invoke-remote-openclaw-upgrade.sh
set -euo pipefail
npm install -g openclaw@latest
openclaw --version
openclaw gateway install --force
systemctl --user daemon-reload
systemctl --user restart openclaw-gateway
sleep 3
systemctl --user is-active openclaw-gateway
echo OK
