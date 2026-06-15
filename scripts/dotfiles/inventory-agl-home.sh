#!/usr/bin/env bash
# Inventário de paths Cursor / Claude / Codex para sync multi-dispositivo AGL.
# Plano: config/dotfiles/manifest.yaml
#
# Uso:
#   ./scripts/dotfiles/inventory-agl-home.sh
#   ./scripts/dotfiles/inventory-agl-home.sh --json /tmp/inventory.json

set -euo pipefail

JSON_OUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON_OUT="${2:-}"; shift 2 ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--json FILE]"
      exit 0
      ;;
    *) echo "Opção desconhecida: $1" >&2; exit 1 ;;
  esac
done

HOST="$(hostname -s 2>/dev/null || hostname)"
USER_NAME="$(whoami)"
TS="$(date -Iseconds)"

paths=(
  "$HOME/.config/Cursor/User"
  "$HOME/.config/Cursor/User/globalStorage"
  "$HOME/.config/Cursor/User/workspaceStorage"
  "$HOME/.cursor"
  "$HOME/.cursor/chats"
  "$HOME/.cursor/projects"
  "$HOME/.cursor/mcp.json"
  "$HOME/.claude"
  "$HOME/.claude/history.jsonl"
  "$HOME/.claude/file-history"
  "$HOME/.claude/settings.json"
  "$HOME/.claude/.credentials.json"
  "$HOME/.codex"
  "$HOME/.codex/config.toml"
)

echo "=== AGL Home Inventory ==="
echo "host: $HOST"
echo "user: $USER_NAME"
echo "time: $TS"
echo ""

declare -A sizes
for p in "${paths[@]}"; do
  if [[ -e "$p" ]]; then
    sz="$(du -sh "$p" 2>/dev/null | awk '{print $1}')"
    link=""
    if [[ -L "$p" ]]; then
      link=" -> $(readlink "$p")"
    fi
    echo "  OK   $sz  $p$link"
    sizes["$p"]="$sz"
  else
    echo "  MISS       $p"
    sizes["$p"]="MISSING"
  fi
done

echo ""
echo "-- sync root --"
for root in \
  "${AGL_HOME_SYNC_ROOT:-/mnt/overpower/apps/dev/agl/agl-home-sync}" \
  /mnt/agl-home-sync; do
  if [[ -d "$root" ]]; then
    echo "  OK   $(du -sh "$root" 2>/dev/null | awk '{print $1}')  $root"
  else
    echo "  MISS       $root"
  fi
done

if [[ -n "$JSON_OUT" ]]; then
  mkdir -p "$(dirname "$JSON_OUT")"
  {
    echo "{"
    echo "  \"host\": \"$HOST\","
    echo "  \"user\": \"$USER_NAME\","
    echo "  \"timestamp\": \"$TS\","
    echo "  \"paths\": {"
    first=1
    for p in "${paths[@]}"; do
      [[ $first -eq 1 ]] || echo ","
      first=0
      esc="${p//\\/\\\\}"
      esc="${esc//\"/\\\"}"
      val="${sizes[$p]:-MISSING}"
      echo -n "    \"$esc\": \"$val\""
    done
    echo ""
    echo "  }"
    echo "}"
  } >"$JSON_OUT"
  echo ""
  echo "JSON: $JSON_OUT"
fi
