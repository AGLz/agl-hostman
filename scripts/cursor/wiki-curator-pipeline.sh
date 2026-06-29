#!/usr/bin/env bash
# Pipeline completo: export Cursor → optimize wiki (Curator) → commit opcional.
set -euo pipefail

REPO="${AGL_HOSTMAN_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
WIKI="${LLM_WIKI_DIR:-/mnt/overpower/apps/dev/agl/llm-wiki}"
PY="${PYTHON:-python3}"

echo "[curator-pipeline] 1/3 sync cursor raw"
bash "$REPO/scripts/cursor/sync-cursor-to-wiki.sh" "$@"

echo "[curator-pipeline] 2/3 optimize wiki (dedupe, ingest stubs, lint, hubs)"
"$PY" "$REPO/scripts/cursor/wiki-curator-optimize.py" --wiki "$WIKI"

echo "[curator-pipeline] 2b/3 synthesize all sessions → wiki/"
"$PY" "$REPO/scripts/cursor/wiki-curator-synthesize-all.py" --wiki "$WIKI" --force

if [[ "${LLM_WIKI_GIT_COMMIT:-0}" == "1" ]] && [[ -d "$WIKI/.git" ]]; then
  echo "[curator-pipeline] 3/3 git commit vault"
  git -C "$WIKI" add raw/wiki-ingest raw/logs/wiki-lint raw/cursor wiki/
  if ! git -C "$WIKI" diff --cached --quiet; then
    git -C "$WIKI" commit -m "chore(wiki): curator optimize cursor ingest $(date -u +%Y-%m-%dT%H:%MZ)"
    [[ "${LLM_WIKI_GIT_PUSH:-0}" == "1" ]] && git -C "$WIKI" push origin "$(git -C "$WIKI" branch --show-current)"
  fi
else
  echo "[curator-pipeline] 3/3 skip git (LLM_WIKI_GIT_COMMIT=0)"
fi

echo "[curator-pipeline] OK"
