#!/usr/bin/env bash
# Replica config + .env LiteLLM para todos os hosts (agldv03, agldv04, agldv12, fgsrv06)
# Uso: ./scripts/litellm/replicate-all-hosts.sh
# Ref: docs/LITELLM-MULTI-HOST-DEPLOYMENT.md

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_SRC="$REPO_ROOT/config/litellm/config.yaml"
CALLBACKS_SRC="$REPO_ROOT/config/litellm/custom_callbacks"
ENV_SRC="$REPO_ROOT/config/litellm/.env"

COMPOSE_OPT="$REPO_ROOT/docker/litellm/docker-compose.opt-litellm.yml"
COMPOSE_FGS="$REPO_ROOT/docker/litellm/docker-compose-fgsrv06.yml"

_deploy_compose() {
  local ip="$1"
  local host="$2"
  ssh "root@${ip}" "mkdir -p /opt/litellm/custom_callbacks"
  if [[ "$host" == "fgsrv06" ]]; then
    scp -q "$COMPOSE_FGS" "root@${ip}:/opt/litellm/docker-compose.yml"
  else
    scp -q "$COMPOSE_OPT" "root@${ip}:/opt/litellm/docker-compose.yml"
  fi
  echo "  OK: docker-compose.yml"
}

_push_callbacks() {
  local ip="$1"
  [[ -d "$CALLBACKS_SRC" ]] || return 0
  tar -C "$CALLBACKS_SRC" -cf - . | ssh "root@${ip}" "mkdir -p /opt/litellm/custom_callbacks && tar -xf - -C /opt/litellm/custom_callbacks"
  echo "  OK: custom_callbacks"
}

declare -A HOST_IPS
HOST_IPS[agldv03]="100.94.221.87"
HOST_IPS[agldv04]="100.113.9.98"
HOST_IPS[agldv12]="100.71.217.115"
HOST_IPS[fgsrv06]="100.83.51.9"

[[ ! -f "$CONFIG_SRC" ]] && { echo "Erro: $CONFIG_SRC não encontrado"; exit 1; }
[[ ! -d "$CALLBACKS_SRC" ]] && { echo "Erro: $CALLBACKS_SRC não encontrado"; exit 1; }
[[ ! -f "$ENV_SRC" ]] && { echo "Erro: $ENV_SRC não encontrado"; exit 1; }

echo "=============================================="
echo "  LiteLLM — Replicar config + .env → Hosts"
echo "=============================================="
echo "  Config: $CONFIG_SRC"
echo "  Env:    $ENV_SRC"
echo "  Hosts:  agldv03, agldv04, agldv12, fgsrv06"
echo ""

# 1. agldv03 (base): config + .env + restart
echo "=== agldv03 (base) ==="
ssh "root@${HOST_IPS[agldv03]}" "cp -a /opt/litellm/config.yaml /opt/litellm/config.yaml.bak.\$(date +%Y%m%d%H%M) 2>/dev/null || true"
scp -q "$CONFIG_SRC" "root@${HOST_IPS[agldv03]}:/opt/litellm/config.yaml"
echo "  OK: config.yaml"
_deploy_compose "${HOST_IPS[agldv03]}" "agldv03"
_push_callbacks "${HOST_IPS[agldv03]}"

# Sync .env em agldv03 (merge via script remoto)
scp -q "$ENV_SRC" "root@${HOST_IPS[agldv03]}:/tmp/litellm-env-sync"
ssh "root@${HOST_IPS[agldv03]}" 'DEST=/opt/litellm/.env
[[ ! -f "$DEST" ]] && { echo "  ERRO: $DEST não existe"; exit 1; }
updated=0
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ "$line" =~ ^# ]] && continue; [[ -z "${line// }" ]] && continue
  if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
    key="${BASH_REMATCH[1]}"; val="${BASH_REMATCH[2]}"; val="${val%\"}"; val="${val#\"}"
    [[ -z "$val" ]] && continue
    [[ "$key" == "LITELLM_MASTER_KEY" ]] && dest_val=$(grep "^${key}=" "$DEST" 2>/dev/null | cut -d= -f2-) && [[ -n "$dest_val" && "$dest_val" != "sk-litellm-default" ]] && continue
    grep -q "^${key}=" "$DEST" 2>/dev/null && sed -i "/^${key}=/d" "$DEST"
    echo "${key}=${val}" >> "$DEST"
    ((updated++)) || true
  fi
done < /tmp/litellm-env-sync
rm -f /tmp/litellm-env-sync
echo "  OK: .env ($updated vars)"'

if ssh "root@${HOST_IPS[agldv03]}" "cd /opt/litellm && docker compose up -d --force-recreate litellm-proxy" 2>&1; then
  echo "  OK: restart"
else
  echo "  AVISO: restart agldv03 falhou — ver docker logs"
fi
echo ""

FAILED=0
# 2. agldv04, agldv12, fgsrv06: config de agldv03 + .env merge + restart
for host in agldv04 agldv12 fgsrv06; do
  ip="${HOST_IPS[$host]}"
  echo "=== $host ($ip) ==="

  # Backup + config (fgsrv06 usa variante remota)
  ssh "root@${ip}" "cp -a /opt/litellm/config.yaml /opt/litellm/config.yaml.bak.\$(date +%Y%m%d%H%M) 2>/dev/null || true"

  if [[ "$host" == "fgsrv06" ]]; then
    ssh "root@${HOST_IPS[agldv03]}" "cat /opt/litellm/config.yaml" | \
      sed -e 's|http://192.168.0.200:11434|http://100.116.57.111:11434|g' \
          -e 's|host: "192.168.0.137"|host: "litellm-redis"|' \
          -e 's|# Redis Cache Configuration (CT137 - aglsrv1)|# Redis Cache Configuration (local - litellm-redis)|' \
          -e '/password: "os.environ\/REDIS_PASSWORD"/d' | \
      ssh "root@${ip}" "cat > /opt/litellm/config.yaml"
  else
    scp -q "root@${HOST_IPS[agldv03]}:/opt/litellm/config.yaml" "root@${ip}:/opt/litellm/config.yaml"
  fi
  echo "  OK: config.yaml"
  _deploy_compose "$ip" "$host"
  _push_callbacks "$ip"

  # .env merge
  scp -q "$ENV_SRC" "root@${ip}:/tmp/litellm-env-sync"
  ssh "root@${ip}" 'DEST=/opt/litellm/.env
[[ ! -f "$DEST" ]] && { echo "  ERRO: $DEST não existe"; exit 1; }
updated=0
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ "$line" =~ ^# ]] && continue; [[ -z "${line// }" ]] && continue
  if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
    key="${BASH_REMATCH[1]}"; val="${BASH_REMATCH[2]}"; val="${val%\"}"; val="${val#\"}"
    [[ -z "$val" ]] && continue
    [[ "$key" == "LITELLM_MASTER_KEY" ]] && dest_val=$(grep "^${key}=" "$DEST" 2>/dev/null | cut -d= -f2-) && [[ -n "$dest_val" && "$dest_val" != "sk-litellm-default" ]] && continue
    grep -q "^${key}=" "$DEST" 2>/dev/null && sed -i "/^${key}=/d" "$DEST"
    echo "${key}=${val}" >> "$DEST"
    ((updated++)) || true
  fi
done < /tmp/litellm-env-sync
rm -f /tmp/litellm-env-sync
echo "  OK: .env ($updated vars)"'

  if ssh "root@${ip}" "cd /opt/litellm && docker compose up -d --force-recreate litellm-proxy" 2>&1; then
    echo "  OK: restart"
  else
    echo "  AVISO: restart $host falhou (Docker/cgroup?) — config e callbacks já copiados"
    ((FAILED++)) || true
  fi
  echo ""
done

echo "=============================================="
if [[ "$FAILED" -gt 0 ]]; then
  echo "  Replicação concluída com $FAILED host(s) sem restart Docker"
else
  echo "  Replicação concluída"
fi
echo "=============================================="
[[ "$FAILED" -eq 0 ]]
