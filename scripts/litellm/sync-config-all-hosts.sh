#!/usr/bin/env bash
# Sync LiteLLM config: repo → CT186 (canónico) + agldv04, agldv12, fgsrv06
# Uso: ./scripts/litellm/sync-config-all-hosts.sh
# Fonte: config/litellm/config.yaml no repo agl-hostman
# Ref: docs/LITELLM-MULTI-HOST-DEPLOYMENT.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_litellm-sync-common.sh
source "${SCRIPT_DIR}/_litellm-sync-common.sh"

litellm_require_repo_config

SYNC_HOSTS=(ct186 agldv04 agldv12 fgsrv06)

echo "=== Sync LiteLLM config: repo → hosts ==="
echo "  Source: ${LITELLM_CONFIG_SRC}"
echo ""

FAILED=0

for host in "${SYNC_HOSTS[@]}"; do
  ip="${LITELLM_HOST_IPS[$host]}"
  remote_dir="$(litellm_remote_dir "$host")"
  echo "=== $host ($ip) → ${remote_dir} ==="

  if [[ "$host" == "ct186" ]]; then
    if ! bash "${SCRIPT_DIR}/deploy-litellm-callbacks-ct186.sh"; then
      ((FAILED++)) || true
    fi
    echo ""
    continue
  fi

  litellm_push_config_to_host "$host" "$ip"
  echo "  OK: config.yaml"
  litellm_push_compose_to_host "$host" "$ip" || true
  litellm_push_callbacks_to_host "$ip" "$host"
  echo "  OK: custom_callbacks"
  ssh "root@${ip}" "cd ${remote_dir} && docker compose restart litellm-proxy 2>/dev/null" || {
    echo "  AVISO: restart ${host} falhou"
    ((FAILED++)) || true
  }
  echo ""
done

echo "=== Concluído ==="
[[ "$FAILED" -eq 0 ]]
