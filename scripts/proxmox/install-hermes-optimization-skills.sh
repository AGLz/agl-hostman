#!/usr/bin/env bash
# Instala skills do OnlyTerp/hermes-optimization-guide nos profiles Hermes (CT188).
# Uso: bash install-hermes-optimization-skills.sh [HERMES_ROOT]

set -euo pipefail

HERMES_ROOT="${1:-/opt/agl-hermes}"
VENDOR_DIR="${HERMES_ROOT}/vendor/hermes-optimization-guide"
REPO="https://github.com/OnlyTerp/hermes-optimization-guide.git"

install -d -m 0755 "${HERMES_ROOT}/vendor"

if [[ ! -d "${VENDOR_DIR}/.git" ]]; then
  echo "=== Clone ${REPO} ==="
  git clone --depth 1 "${REPO}" "${VENDOR_DIR}"
else
  echo "=== Update ${VENDOR_DIR} ==="
  git -C "${VENDOR_DIR}" pull --ff-only
fi

# Skills úteis para agência privada (Telegram allowlist) + segurança + ops
SKILLS=(
  ops/cost-report
  ops/hermes-weekly
  ops/nightly-backup
  security/audit-mcp
  security/spam-trap
  security/rotate-secrets
)

profile_dir() {
  case "$1" in
    jarvis) echo "${HERMES_ROOT}/data" ;;
    *) echo "${HERMES_ROOT}/profiles/$1" ;;
  esac
}

for agent in jarvis elon satya werner; do
  pdir="$(profile_dir "${agent}")"
  install -d -m 0700 "${pdir}/skills"
  for skill in "${SKILLS[@]}"; do
    src="${VENDOR_DIR}/skills/${skill}"
    dst="${pdir}/skills/${skill}"
    if [[ ! -d "${src}" ]]; then
      echo "WARN skill em falta: ${src}" >&2
      continue
    fi
    install -d -m 0700 "$(dirname "${dst}")"
    ln -sfn "${src}" "${dst}"
    echo "OK ${agent} ← ${skill}"
  done
  chown -R 10000:10000 "${pdir}/skills" 2>/dev/null || true
done

echo "=== Skills optimization guide instaladas ==="
