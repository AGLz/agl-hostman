#!/usr/bin/env bash
# Instala wrapper SkillSpector (Docker) — Python 3.12+ no host opcional.
#
# Uso:
#   ./scripts/skills/install-skillspector.sh
#   ./scripts/skills/install-skillspector.sh --check
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTMAN_ROOT="${HOSTMAN_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
WRAPPER="${HOSTMAN_ROOT}/scripts/skills/scan-skill-security.sh"
IMAGE="${SKILLSPECTOR_IMAGE:-python:3.12-slim}"

log() { echo "[skillspector-install] $*"; }

if [[ "${1:-}" == "--check" ]]; then
  if command -v skillspector >/dev/null 2>&1; then
    skillspector --version 2>/dev/null || skillspector --help | head -1
    exit 0
  fi
  if [[ -x "$WRAPPER" ]]; then
  bash "$WRAPPER" --help 2>/dev/null || log "wrapper presente: $WRAPPER"
    exit 0
  fi
  echo "SkillSpector não instalado" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "[ERROR] Docker necessário para install-skillspector (host sem Python 3.12)" >&2
  exit 1
fi

log "pull $IMAGE"
docker pull "$IMAGE" >/dev/null

log "warm pip cache (skillspector)"
docker run --rm "$IMAGE" bash -lc 'apt-get update -qq && apt-get install -y -qq git >/dev/null && pip install -q "git+https://github.com/NVIDIA/skillspector.git" && skillspector --help | head -3'

if [[ -x "$WRAPPER" ]]; then
  log "wrapper já existe: $WRAPPER"
else
  log "usar scan-skill-security.sh (delega para Docker)"
fi

log "OK — correr: bash $HOSTMAN_ROOT/scripts/skills/scan-skill-security.sh <path>"
