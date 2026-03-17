#!/usr/bin/env bash
# =============================================================================
# Corrigir instalação do plugin code-intelligence no Turbo Flow
# O plugin depende de @claude-flow/ruvector-upstream que não existe mais no npm.
# Solução: usar override para @sparkleideas/ruvector-upstream
#
# Executar no CT com Turbo Flow (ex: agldv12)
# Uso: ./scripts/proxmox/fix-turbo-flow-code-intelligence.sh [host]
# =============================================================================
set -euo pipefail

HOST="${1:-root@192.168.0.185}"
PLUGINS_DIR="${TURBO_FLOW_PLUGINS:-/opt/turbo-flow/.claude-flow/plugins}"

echo "=== Fix plugin code-intelligence no Turbo Flow ==="
echo "Host: $HOST"
echo ""

ssh -o StrictHostKeyChecking=no "$HOST" "PLUGINS_DIR=$PLUGINS_DIR bash -s" << 'REMOTE'
cd "$PLUGINS_DIR"
# Adicionar plugin e override
jq '.dependencies["@claude-flow/plugin-code-intelligence"] = "^3.0.0-alpha.1" | .overrides["@claude-flow/ruvector-upstream"] = "npm:@sparkleideas/ruvector-upstream@3.0.0-alpha.1-patch.38"' package.json > pkg.tmp && mv pkg.tmp package.json
npm install
# Registrar em installed.json
NOW=$(date -Iseconds)
jq --arg path "$PLUGINS_DIR/node_modules/@claude-flow/plugin-code-intelligence" \
  '.plugins["@claude-flow/plugin-code-intelligence"] = {
    name: "@claude-flow/plugin-code-intelligence",
    version: "3.0.0-alpha.1",
    installedAt: "'"$NOW"'",
    enabled: true,
    source: "npm",
    path: $path,
    commands: [],
    hooks: []
  }' installed.json > inst.tmp && mv inst.tmp installed.json
REMOTE

echo ""
echo "=== Code Intelligence instalado com sucesso ==="
ssh -o StrictHostKeyChecking=no "$HOST" "ls $PLUGINS_DIR/node_modules/@claude-flow/plugin-code-intelligence 2>/dev/null && echo 'OK'"
