#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${containerWorkspaceFolder:-/workspaces/agl-hostman}"
POST_SETUP="${WORKSPACE}/devpods/post-setup.sh"

if [[ -x "${POST_SETUP}" ]]; then
  echo "[devcontainer] post-attach: ${POST_SETUP}"
  "${POST_SETUP}"
fi
