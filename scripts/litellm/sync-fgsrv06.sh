#!/usr/bin/env bash
# Sync LiteLLM config: repo → fgsrv06 (/opt/litellm)
# Uso: ./scripts/litellm/sync-fgsrv06.sh
# Ref: docs/LITELLM-MULTI-HOST-DEPLOYMENT.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_litellm-sync-common.sh
source "${SCRIPT_DIR}/_litellm-sync-common.sh"

litellm_require_repo_config

HOST="fgsrv06"
ip="${LITELLM_HOST_IPS[$HOST]}"
remote_dir="$(litellm_remote_dir "$HOST")"

echo "=== Sync LiteLLM config: repo → fgsrv06 ==="
echo "  Source: ${LITELLM_CONFIG_REMOTE_SRC:-${LITELLM_CONFIG_SRC} (variante remota)}"
echo "  Target: root@${ip}:${remote_dir}/config.yaml"
echo ""

litellm_push_config_to_host "$HOST" "$ip"
echo "  OK: config.yaml"

echo ""
echo "  Reiniciando litellm-proxy..."
ssh "root@${ip}" "cd ${remote_dir} && docker compose restart litellm-proxy"

echo ""
echo "=== Concluído ==="
echo "  Verificar: ssh root@${ip} 'docker logs litellm-proxy --tail 20'"
