#!/usr/bin/env bash
# Replica config + .env LiteLLM para CT186 (canónico) + agldv04, agldv12, fgsrv06
# Fonte: config/litellm/* no repo agl-hostman
# Uso: ./scripts/litellm/replicate-all-hosts.sh
# Ref: docs/LITELLM-MULTI-HOST-DEPLOYMENT.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_litellm-sync-common.sh
source "${SCRIPT_DIR}/_litellm-sync-common.sh"

litellm_require_repo_config
[[ -d "$LITELLM_CALLBACKS_SRC" ]] || { echo "Erro: $LITELLM_CALLBACKS_SRC não encontrado"; exit 1; }
[[ -f "$LITELLM_ENV_SRC" ]] || { echo "Erro: $LITELLM_ENV_SRC não encontrado"; exit 1; }

REPLICATE_HOSTS=(ct186 agldv04 agldv12 fgsrv06)

echo "=============================================="
echo "  LiteLLM — Replicar config + .env → Hosts"
echo "=============================================="
echo "  Config: ${LITELLM_CONFIG_SRC}"
echo "  Env:    ${LITELLM_ENV_SRC}"
echo "  Hosts:  ${REPLICATE_HOSTS[*]}"
echo ""

FAILED=0

for host in "${REPLICATE_HOSTS[@]}"; do
  ip="${LITELLM_HOST_IPS[$host]}"
  remote_dir="$(litellm_remote_dir "$host")"
  echo "=== $host ($ip) ==="

  if [[ "$host" == "ct186" ]]; then
    bash "${SCRIPT_DIR}/deploy-litellm-callbacks-ct186.sh" || ((FAILED++)) || true
    litellm_merge_env_on_host "$ip" "${remote_dir}/.env" || ((FAILED++)) || true
    echo ""
    continue
  fi

  litellm_push_config_to_host "$host" "$ip"
  echo "  OK: config.yaml"
  litellm_push_compose_to_host "$host" "$ip"
  echo "  OK: docker-compose.yml"
  litellm_push_callbacks_to_host "$ip" "$host"
  echo "  OK: custom_callbacks"
  litellm_merge_env_on_host "$ip" "${remote_dir}/.env" || ((FAILED++)) || true

  if ! litellm_restart_proxy_on_host "$host" "$ip"; then
    ((FAILED++)) || true
  fi
  echo ""
done

echo "=============================================="
if [[ "$FAILED" -gt 0 ]]; then
  echo "  Replicação concluída com $FAILED falha(s)"
else
  echo "  Replicação concluída"
fi
echo "=============================================="
[[ "$FAILED" -eq 0 ]]
