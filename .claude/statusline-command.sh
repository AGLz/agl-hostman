#!/bin/bash

# ===============================================
# Claude Code Global Statusline - ULTRA v5
# ===============================================
# Target: <50ms execution time
# Absolute minimum external calls
# ===============================================

# =========================
# PARSE INPUT (native bash, no jq)
# =========================
INPUT=$(cat)
CWD=$(echo "$INPUT" | grep -oP '"current_dir":\s*"[^"]*"' | cut -d'"' -f4)
[ -z "$CWD" ] && CWD=$(echo "$INPUT" | grep -oP '"cwd":\s*"[^"]*"' | cut -d'"' -f4)
[ -z "$CWD" ] && CWD="$(pwd)"

# =========================
# DETECT MODEL from ~/.claude.json
# =========================
MODEL="Claude"
CLAUDE_CONFIG="$HOME/.claude.json"
if [ -f "$CLAUDE_CONFIG" ] && command -v jq >/dev/null 2>&1; then
  MODEL_ID=$(jq -r '.projects["'"$CWD"'"].lastModelUsage | keys[0] // empty' "$CLAUDE_CONFIG" 2>/dev/null)

  if [ -n "$MODEL_ID" ]; then
    case "$MODEL_ID" in
      *opus*) MODEL="Opus" ;;
      *sonnet*) MODEL="Sonnet" ;;
      *haiku*) MODEL="Haiku" ;;
      *glm-4.5-air*) MODEL="GLM-4.5-Air" ;;
      *glm-4.5-flash*) MODEL="GLM-4.5-Flash" ;;
      *glm*)
        # Extract version from other glm- models
        MODEL=$(echo "$MODEL_ID" | sed 's/glm-/GLM-/g' | tr '[:lower:]' '[:upper:]')
        ;;
      *gpt*)
        MODEL=$(echo "$MODEL_ID" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1')
        ;;
      *)
        # Fallback: use model ID as-is, capitalized
        MODEL=$(echo "$MODEL_ID" | tr '[:lower:]' '[:upper:]' | sed 's/-/ /g')
        ;;
    esac
  fi
fi

# =========================
# CACHED VALUES
# =========================
HASH=$(echo -n "$CWD" | md5sum | cut -d' ' -f1)
GIT_CACHE="/tmp/sg-${HASH}"
TOKEN_CACHE="/tmp/st-${HASH}"
MCP_CACHE="/tmp/sm"

# Load git info from cache (5s cache)
if [ -f "$GIT_CACHE" ] && [ $(( $(date +%s) - $(stat -c %Y "$GIT_CACHE" 2>/dev/null || echo 0) )) -lt 5 ]; then
  source "$GIT_CACHE"
else
  PROJECT_NAME="" BRANCH="" STATUS=""
  if git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1; then
    PROJECT_NAME=$(basename "$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null)")
    BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null)
    [ -z "$BRANCH" ] && BRANCH="detached"
    STATUS=$(git -C "$CWD" status --porcelain=v1 2>/dev/null | head -c 1)
    [ -n "$STATUS" ] && STATUS=" ~"
  fi
  cat > "$GIT_CACHE" <<EOF
PROJECT_NAME="$PROJECT_NAME"
BRANCH="$BRANCH"
STATUS="$STATUS"
EOF
fi

# Branding
case "$PROJECT_NAME" in
  "claude-code-flow") PROJECT_NAME="🌊 Claude Flow" ;;
  "agl-hostman") PROJECT_NAME="AGL HostMan" ;;
esac

# =========================
# TIME (instant)
# =========================
H=$(date +%H); H=${H#0}; H=${H:-0}
M=$(date +%M); M=${M#0}

# Math-based block
B=$(( (H + 4) / 5 ))
case $B in
  0) BLOCK="9-1"; R="01:00" ;;
  1) BLOCK="1-6"; R="06:00" ;;
  2) BLOCK="6-11"; R="11:00" ;;
  3) BLOCK="11-4"; R="16:00" ;;
  4) BLOCK="4-9"; R="21:00" ;;
esac

T=$((H * 60 + M))
[ "$R" = "01:00" ] && { [ $H -ge 21 ] && T=$((24*60 - T + 60)) || T=$((60 - T)); } || { RH=${R:0:2}; RH=${RH#0}; T=$((RH * 60 - H * 60 - M)); }
TM="${T}m"

# =========================
# TOKENS (cached 60s)
# =========================
if [ -f "$TOKEN_CACHE" ] && [ $(( $(date +%s) - $(stat -c %Y "$TOKEN_CACHE" 2>/dev/null || echo 0) )) -lt 60 ]; then
  TOKENS=$(cat "$TOKEN_CACHE")
else
  # Ultra-fast estimate
  TOKENS=$(ls -1q "$CWD" 2>/dev/null | wc -l)
  TOKENS=$((TOKENS * 100))
  [ $TOKENS -gt 200000 ] && TOKENS=200000
  echo $TOKENS > "$TOKEN_CACHE"
fi

P=$((TOKENS * 100 / 200000))
[ $P -lt 50 ] && { I="✓"; C="32"; Z="SMART"; }
[ $P -ge 50 ] && [ $P -lt 80 ] && { I="⚠"; C="33"; Z="DUMB"; }
[ $P -ge 80 ] && { I="⚠⚠"; C="31"; Z="WRAP_UP"; }

# Progress bar (lookup, no loop)
case $((P/10)) in
  0) PB="[░░░░░░░░░░]" ;; 1) PB="[█░░░░░░░░░]" ;; 2) PB="[██░░░░░░░░]" ;;
  3) PB="[███░░░░░░░]" ;; 4) PB="[████░░░░░░]" ;; 5) PB="[█████░░░░░]" ;;
  6) PB="[██████░░░░]" ;; 7) PB="[███████░░░]" ;; 8) PB="[████████░░]" ;;
  9) PB="[█████████░]" ;; 10) PB="[██████████]" ;;
esac

# =========================
# MCP (cached 5 min)
# =========================
if [ -f "$MCP_CACHE" ] && [ $(( $(date +%s) - $(stat -c %Y "$MCP_CACHE" 2>/dev/null || echo 0) )) -lt 300 ]; then
  MCP=$(cat "$MCP_CACHE")
else
  MCP=0
  [ -f ~/.claude/settings.json ] && MCP=$(grep -o 'mcpServers' ~/.claude/settings.json 2>/dev/null | wc -l)
  echo $MCP > "$MCP_CACHE"
fi

# =========================
# OUTPUT (single printf)
# =========================
TK=$((TOKENS / 1000))
printf "\033[1m%s\033[0m in \033[36m%s\033[0m on \033[33m⎇ %s\033[0m\033[33m%s\033[0m | \033[%sm%s %dK/200K\033[0m \033[90m%s\033[0m \033[%sm%s\033[0m | \033[90m%s(%s)[%s]\033[0m \033[35m🔌%d\033[0m \033[90m│\033[0m \033[36mCC v2.1.20\033[0m \033[90m│\033[0m \033[33m%s\033[0m\n" \
  "$MODEL" "$PROJECT_NAME" "$BRANCH" "$STATUS" "$C" "$I" "$TK" "$PB" "$C" "$Z" "$R" "$TM" "$BLOCK" "$MCP" "$(hostname)"
