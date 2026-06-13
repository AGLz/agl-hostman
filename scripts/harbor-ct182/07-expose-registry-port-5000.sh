#!/usr/bin/env bash
# Expõe registry Harbor na porta 5000 (LAN) mapeando 5000→8443 no proxy nginx.
# Executar no CT182 como root.
set -euo pipefail

HARBOR_DIR="${HARBOR_DIR:-/opt/harbor}"
COMPOSE="${HARBOR_DIR}/docker-compose.yml"

[[ -f "${COMPOSE}" ]] || {
    echo "ERRO: ${COMPOSE} não encontrado" >&2
    exit 1
}

if grep -q '5000:8443' "${COMPOSE}"; then
    echo "Porta 5000 já mapeada em ${COMPOSE}"
else
    sed -i '/- 443:8443/a\      - 5000:8443' "${COMPOSE}"
    echo "Adicionado 5000:8443 em ${COMPOSE}"
fi

cd "${HARBOR_DIR}"
docker compose up -d --force-recreate proxy
sleep 2
curl -skI "https://127.0.0.1:5000/v2/" | head -1
ss -tlnp | grep ':5000' || true
