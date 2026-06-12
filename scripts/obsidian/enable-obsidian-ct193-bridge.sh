#!/usr/bin/env bash
# Activa bridge Git + Obsidian CLI no CT193 (gh auth, pull, systemd, smoke).
# Uso (agldv03): bash scripts/obsidian/enable-obsidian-ct193-bridge.sh
set -euo pipefail

REPO="${AGL_HOSTMAN_DIR:-/mnt/overpower/apps/dev/agl/agl-hostman}"
CTID="${CTID:-193}"
PROXMOX_HOST="${PROXMOX_HOST:-100.107.113.33}"

log() { echo "[enable-ct193] $*"; }

log "propagar gh auth (se necessário)..."
bash "${REPO}/scripts/obsidian/propagate-gh-auth-to-ct193.sh" || true

log "restaurar workspace.json sujo (NFS)..."
git -C /mnt/overpower/apps/dev/agl/llm-wiki restore .obsidian/workspace.json 2>/dev/null || true

log "configurar CT${CTID}..."
ssh -o ConnectTimeout=20 "root@${PROXMOX_HOST}" "pct exec ${CTID} -- bash -s" <<EOF
set -euo pipefail
REPO=${REPO}
export PATH="/usr/local/bin:/usr/bin:/bin"

git config --global --add safe.directory /mnt/overpower/apps/dev/agl/llm-wiki 2>/dev/null || true
bash "\${REPO}/scripts/obsidian/install-obsidian-cli-wrapper.sh"
VERIFY_GH_REPO=0 bash "\${REPO}/scripts/obsidian/setup-github-gh.sh"

systemctl enable obsidian-hub agl-llm-wiki-bridge agl-llm-wiki-bridge.timer
# Reason: CLI lê obsidian.json só no arranque do processo principal.
systemctl stop obsidian-hub 2>/dev/null || true
sleep 3
systemctl start obsidian-hub
sleep 25

bash "\${REPO}/scripts/obsidian/bridge-llm-wiki-git.sh" pull
systemctl start agl-llm-wiki-bridge agl-llm-wiki-bridge.timer

echo "--- smoke ---"
/usr/local/bin/obsidian version 2>&1 | head -3
/usr/local/bin/obsidian vaults 2>&1 | head -5
/usr/local/bin/obsidian search query="Obsidian CT" vault=llm-wiki format=text 2>&1 | head -5
systemctl is-active obsidian-hub agl-llm-wiki-bridge agl-llm-wiki-bridge.timer
EOF

log "verify remoto..."
ssh "root@${PROXMOX_HOST}" "pct exec ${CTID} -- bash ${REPO}/scripts/obsidian/verify-obsidian-ct.sh"

log "OK enable-obsidian-ct193-bridge"
