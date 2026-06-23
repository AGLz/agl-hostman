#!/usr/bin/env bash
# Sync incremental Cursor → llm-wiki (raw/cursor/live + ingest-queue).
# Uso:
#   bash scripts/cursor/sync-cursor-to-wiki.sh
#   bash scripts/cursor/sync-cursor-to-wiki.sh --full --snapshot
#   LLM_WIKI_GIT_COMMIT=1 bash scripts/cursor/sync-cursor-to-wiki.sh
set -euo pipefail

REPO="${AGL_HOSTMAN_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
WIKI="${LLM_WIKI_DIR:-/mnt/overpower/apps/dev/agl/llm-wiki}"
FILTER="${CURSOR_EXPORT_FILTER:-agl}"
PY="${PYTHON:-python3}"
export CURSOR_EXPORT_HOST="${CURSOR_EXPORT_HOST:-$(hostname -s 2>/dev/null || hostname)}"
export CURSOR_EXPORT_ALL_HOSTS="${CURSOR_EXPORT_ALL_HOSTS:-1}"
FULL=0
SNAPSHOT=0
SESSION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --full) FULL=1 ;;
    --snapshot) SNAPSHOT=1 ;;
    --all) FILTER=all ;;
    --session)
      shift
      SESSION="${1:-}"
      ;;
    *) echo "Uso: $0 [--full] [--snapshot] [--all] [--session PATH]" >&2; exit 2 ;;
  esac
  shift
done

ARGS=(--wiki "$WIKI" --filter "$FILTER")
[[ "$FULL" -eq 1 ]] && ARGS+=(--full)
[[ "$SNAPSHOT" -eq 1 ]] && ARGS+=(--snapshot)
[[ -n "$SESSION" ]] && ARGS+=(--session "$SESSION")

echo "[cursor-wiki] export → $WIKI"
OUT="$("$PY" "$REPO/scripts/cursor/export-cursor-sessions.py" "${ARGS[@]}")"
echo "$OUT"

if [[ "${LLM_WIKI_GIT_COMMIT:-0}" == "1" ]] && [[ -d "$WIKI/.git" ]]; then
  if git -C "$WIKI" status --porcelain raw/cursor/ | grep -q .; then
    git -C "$WIKI" add raw/cursor/live raw/cursor/.export-state*.json raw/cursor/ingest-queue.jsonl
  fi
  if git -C "$WIKI" diff --cached --quiet; then
    echo "[cursor-wiki] sem alterações para commit"
  else
    MSG="chore(cursor): sync conversas Cursor → raw/cursor/live ($(date -u +%Y-%m-%dT%H:%MZ))"
    git -C "$WIKI" commit -m "$MSG"
    if [[ "${LLM_WIKI_GIT_PUSH:-0}" == "1" ]]; then
      git -C "$WIKI" push origin "$(git -C "$WIKI" branch --show-current)"
    fi
    echo "[cursor-wiki] commit OK"
  fi
fi

echo "[cursor-wiki] OK"
