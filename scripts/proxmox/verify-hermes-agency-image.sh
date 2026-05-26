#!/usr/bin/env bash
# Verifica ferramentas de infra na imagem agl-hermes-agency (correr no CT188).
# Uso: bash verify-hermes-agency-image.sh [nome-contentor]

set -euo pipefail

CONTAINER="${1:-agl-hermes-werner}"

check() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "OK  ${label}"
  else
    echo "FAIL ${label}" >&2
    return 1
  fi
}

fail=0
if ! docker inspect -f '{{.State.Running}}' "${CONTAINER}" 2>/dev/null | grep -qx true; then
  echo "FAIL container ${CONTAINER} not running" >&2
  fail=1
else
  echo "OK  container ${CONTAINER} running"
fi

run() { docker exec "${CONTAINER}" "$@"; }

check "jq" run jq --version || fail=1
check "yq" run yq --version || fail=1
check "curl" run curl --version || fail=1
check "ssh" run ssh -V || fail=1
check "ping" run ping -V || fail=1
check "dig" run dig +short google.com || fail=1
check "wg" run wg --version || fail=1
check "showmount" run showmount --version || fail=1
check "python-yaml" run python3 -c "import yaml" || fail=1
check "telegram" run /opt/hermes/.venv/bin/python -c "import telegram" || fail=1
check "honcho" run /opt/hermes/.venv/bin/python -c "import honcho" || fail=1
check "linear" run linear --version || fail=1
check "docker-socket" run docker ps || fail=1
check "agl-hostman mount" run test -d /opt/agl-hostman/scripts/proxmox || fail=1
check "agl-dev mount rw" run bash -lc 'test -d /mnt/overpower/apps/dev/agl && touch /mnt/overpower/apps/dev/.hermes-rw-check && rm -f /mnt/overpower/apps/dev/.hermes-rw-check' || fail=1

if [[ "${fail}" -eq 0 ]]; then
  echo "=== Imagem agency OK (${CONTAINER}) ==="
else
  echo "=== Falhas na imagem agency ===" >&2
  exit 1
fi
