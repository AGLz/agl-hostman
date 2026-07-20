#!/usr/bin/env bash
# Instala pack AGL em todos os projetos CRM/ERP makemoney01.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTMAN="${AGL_SOURCE:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
MANIFEST="${MAKEMONEY_MANIFEST:-/mnt/overpower/apps/dev/agl/makemoney01/config/niche-projects.json}"
SKIP_GIT_CLONE="${SKIP_GIT_CLONE:-1}"

[[ -f "$MANIFEST" ]] || { echo "ERRO: $MANIFEST" >&2; exit 1; }

mapfile -t SLUGS < <(python3 -c "import json; print('\n'.join(p['slug'] for p in json.load(open('$MANIFEST'))['projects']))")

for slug in "${SLUGS[@]}"; do
  echo "=== pack $slug ==="
  NICHE_ROOT="/mnt/overpower/apps/dev/agl/${slug}" \
  SKIP_GIT_CLONE="$SKIP_GIT_CLONE" \
    bash "$HOSTMAN/scripts/skills/install-agl-pack-makemoney-niche.sh" "$slug"
done

echo "OK propagate ${#SLUGS[@]} niche packs"
