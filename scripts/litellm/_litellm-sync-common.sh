#!/usr/bin/env bash
# Funções partilhadas: sync/deploy LiteLLM (fonte = repo; canónico = CT186).
# Uso: source "$(dirname "$0")/_litellm-sync-common.sh"

_litellm_common_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LITELLM_REPO_ROOT="$(cd "${_litellm_common_dir}/../.." && pwd)"
LITELLM_CONFIG_SRC="${LITELLM_REPO_ROOT}/config/litellm/config.yaml"
LITELLM_CONFIG_REMOTE_SRC="${LITELLM_REPO_ROOT}/config/litellm/config-remote.yaml"
LITELLM_CALLBACKS_SRC="${LITELLM_REPO_ROOT}/config/litellm/custom_callbacks"
LITELLM_ENV_SRC="${LITELLM_REPO_ROOT}/config/litellm/.env"
LITELLM_COMPOSE_OPT="${LITELLM_REPO_ROOT}/docker/litellm/docker-compose.opt-litellm.yml"
LITELLM_COMPOSE_FGS="${LITELLM_REPO_ROOT}/docker/litellm/docker-compose-fgsrv06.yml"
LITELLM_COMPOSE_CT186="${LITELLM_REPO_ROOT}/docker/litellm/docker-compose.ct186.yml"

declare -A LITELLM_HOST_IPS
LITELLM_HOST_IPS[ct186]="100.125.249.8"
LITELLM_HOST_IPS[agldv04]="100.113.9.98"
LITELLM_HOST_IPS[agldv12]="100.71.217.115"
LITELLM_HOST_IPS[fgsrv06]="100.83.51.9"

# agldv03 descontinuado 2026-06-05 — mantido só para mensagens de erro
LITELLM_DEPRECATED_HOSTS="agldv03"

litellm_require_repo_config() {
  if [[ ! -f "$LITELLM_CONFIG_SRC" ]]; then
    echo "Erro: $LITELLM_CONFIG_SRC não encontrado" >&2
    exit 1
  fi
}

litellm_remote_dir() {
  local host="$1"
  if [[ "$host" == "ct186" ]]; then
    echo "/opt/agl-litellm"
  else
    echo "/opt/litellm"
  fi
}

litellm_config_stream_for_host() {
  local host="$1"
  if [[ "$host" == "fgsrv06" ]]; then
    if [[ -f "$LITELLM_CONFIG_REMOTE_SRC" ]]; then
      cat "$LITELLM_CONFIG_REMOTE_SRC"
    else
      sed -e 's|http://192.168.0.200:11434|http://100.116.57.111:11434|g' \
          -e 's|host: "192.168.0.137"|host: "litellm-redis"|' \
          -e 's|# Redis Cache Configuration (CT137 - aglsrv1)|# Redis Cache Configuration (local - litellm-redis)|' \
          -e '/password: "os.environ\/REDIS_PASSWORD"/d' \
          "$LITELLM_CONFIG_SRC"
    fi
  else
    cat "$LITELLM_CONFIG_SRC"
  fi
}

litellm_push_config_to_host() {
  local host="$1"
  local ip="$2"
  local remote_dir
  remote_dir="$(litellm_remote_dir "$host")"

  ssh "root@${ip}" "mkdir -p ${remote_dir} && cp -a ${remote_dir}/config.yaml ${remote_dir}/config.yaml.bak.\$(date +%Y%m%d%H%M) 2>/dev/null || true"
  litellm_config_stream_for_host "$host" | ssh "root@${ip}" "cat > ${remote_dir}/config.yaml"
}

litellm_push_compose_to_host() {
  local host="$1"
  local ip="$2"
  local remote_dir compose_src

  remote_dir="$(litellm_remote_dir "$host")"
  ssh "root@${ip}" "mkdir -p ${remote_dir}"

  case "$host" in
    ct186) compose_src="$LITELLM_COMPOSE_CT186" ;;
    fgsrv06) compose_src="$LITELLM_COMPOSE_FGS" ;;
    *) compose_src="$LITELLM_COMPOSE_OPT" ;;
  esac

  if [[ ! -f "$compose_src" ]]; then
    echo "Erro: compose não encontrado: $compose_src" >&2
    return 1
  fi

  scp -q "$compose_src" "root@${ip}:${remote_dir}/docker-compose.yml"
}

litellm_push_callbacks_to_host() {
  local ip="$1"
  local host="$2"
  local remote_dir
  remote_dir="$(litellm_remote_dir "$host")"

  [[ -d "$LITELLM_CALLBACKS_SRC" ]] || return 0
  ssh "root@${ip}" "mkdir -p ${remote_dir}/custom_callbacks"
  tar -C "$LITELLM_CALLBACKS_SRC" -cf - . | ssh "root@${ip}" "tar -xf - -C ${remote_dir}/custom_callbacks"
}

litellm_merge_env_on_host() {
  local ip="$1"
  local dest_path="$2"

  if [[ ! -f "$LITELLM_ENV_SRC" ]]; then
    echo "  AVISO: $LITELLM_ENV_SRC não encontrado — skip merge .env"
    return 0
  fi

  scp -q "$LITELLM_ENV_SRC" "root@${ip}:/tmp/litellm-env-sync"
  ssh "root@${ip}" "DEST=${dest_path}
[[ ! -f \"\$DEST\" ]] && { echo \"  ERRO: \$DEST não existe\"; exit 1; }
updated=0
while IFS= read -r line || [[ -n \"\$line\" ]]; do
  [[ \"\$line\" =~ ^# ]] && continue; [[ -z \"\${line// }\" ]] && continue
  if [[ \"\$line\" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
    key=\"\${BASH_REMATCH[1]}\"; val=\"\${BASH_REMATCH[2]}\"; val=\"\${val%\\\"}\"; val=\"\${val#\\\"}\"
    [[ -z \"\$val\" ]] && continue
    [[ \"\$key\" == \"LITELLM_MASTER_KEY\" ]] && dest_val=\$(grep \"^\${key}=\" \"\$DEST\" 2>/dev/null | cut -d= -f2-) && [[ -n \"\$dest_val\" && \"\$dest_val\" != \"sk-litellm-default\" ]] && continue
    grep -q \"^\${key}=\" \"\$DEST\" 2>/dev/null && sed -i \"/^\${key}=/d\" \"\$DEST\"
    echo \"\${key}=\${val}\" >> \"\$DEST\"
    ((updated++)) || true
  fi
done < /tmp/litellm-env-sync
rm -f /tmp/litellm-env-sync
echo \"  OK: .env (\$updated vars)\""
}

litellm_restart_proxy_on_host() {
  local host="$1"
  local ip="$2"
  local remote_dir
  remote_dir="$(litellm_remote_dir "$host")"

  if ssh "root@${ip}" "cd ${remote_dir} && docker compose up -d --force-recreate litellm-proxy" 2>&1; then
    echo "  OK: restart"
    return 0
  fi

  echo "  AVISO: restart ${host} falhou — ver docker logs"
  return 1
}

litellm_reject_deprecated_host() {
  local host="$1"
  if [[ "$host" == "agldv03" ]]; then
    echo "Erro: LiteLLM em agldv03 (CT179) foi descontinuado (2026-06-05)." >&2
    echo "  Canónico: CT186 — bash scripts/proxmox/bootstrap-ct186-litellm.sh" >&2
    echo "  Sync config: bash scripts/litellm/deploy-litellm-callbacks-ct186.sh" >&2
    exit 1
  fi
}
