#!/usr/bin/env bash
# Propaga pack AGL para makemoney01 (NFS local).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTMAN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MAKEMONEY01_ROOT="${MAKEMONEY01_ROOT:-/mnt/overpower/apps/dev/agl/makemoney01}"
LLM_WIKI_DIR="${LLM_WIKI_DIR:-/mnt/overpower/apps/dev/agl/llm-wiki}"

MAKEMONEY01_ROOT="$MAKEMONEY01_ROOT" LLM_WIKI_DIR="$LLM_WIKI_DIR" AGL_SOURCE="$HOSTMAN_ROOT" \
  bash "$HOSTMAN_ROOT/scripts/skills/install-agl-pack-makemoney01.sh"
MAKEMONEY01_ROOT="$MAKEMONEY01_ROOT" LLM_WIKI_DIR="$LLM_WIKI_DIR" \
  bash "$HOSTMAN_ROOT/scripts/skills/verify-makemoney01-pack.sh"
