
#!/bin/bash

# ===============================================
# Claude Code Global Statusline
# ===============================================
# Shows useful info across ALL directories:
# - Current directory (shortened path)
# - Git info (branch, status, repo name)
# - Todo list status (if available)
# - Claude Flow metrics (if present)
# - System info (hostname, user)
# ===============================================

# Read JSON input from stdin
INPUT=$(cat)
MODEL=$(echo "$INPUT" | jq -r '.model.display_name // "Claude"')
CWD=$(echo "$INPUT" | jq -r '.workspace.current_dir // .cwd')
PROJECT_DIR=$(echo "$INPUT" | jq -r '.workspace.project_dir // .cwd')
OUTPUT_STYLE=$(echo "$INPUT" | jq -r '.output_style.name // "default"')
CC_VERSION=$(claude --version 2>/dev/null | sed 's/ (Claude Code)//' | sed 's/^/CC v/')

# =========================
# Git Project Information
# =========================
cd "$CWD" 2>/dev/null
PROJECT_NAME=""
BRANCH=""

if git rev-parse --git-dir > /dev/null 2>&1; then
  # Get project name from remote URL or directory
  REMOTE_URL=$(git remote get-url origin 2>/dev/null | head -n1)

  if [ -n "$REMOTE_URL" ]; then
    # Extract project name from git URL
    PROJECT_NAME=$(basename "$REMOTE_URL" .git)
  fi

  # Fallback to directory name if no remote or parsing failed
  if [ -z "$PROJECT_NAME" ] || [ "$PROJECT_NAME" = "$REMOTE_URL" ]; then
    GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
    PROJECT_NAME=$(basename "$GIT_ROOT")
  fi

  # Special branded names
  case "$PROJECT_NAME" in
    "claude-code-flow") PROJECT_NAME="🌊 Claude Flow" ;;
    "agl-hostman") PROJECT_NAME="AGL HostMan" ;;
    "gemini-flow") PROJECT_NAME="💎 Gemini Flow" ;;
  esac

  # Get branch name
  BRANCH=$(git branch --show-current 2>/dev/null)
  [ -z "$BRANCH" ] && BRANCH=$(git describe --tags --exact-match 2>/dev/null || echo "detached")
fi

# Detect environment
ENV_TYPE=""
if grep -q microsoft /proc/version 2>/dev/null; then
  ENV_TYPE="WSL2"
elif [ -f /.dockerenv ]; then
  CONTAINER_NAME=$(hostname)
  ENV_TYPE="🐳 $CONTAINER_NAME"
fi

# Start building statusline
printf "\033[1m$MODEL\033[0m"

# Show environment if detected
[ -n "$ENV_TYPE" ] && printf " [\033[35m$ENV_TYPE\033[0m]"

# Show project and branch if in git repo
if [ -n "$PROJECT_NAME" ] && [ -n "$BRANCH" ]; then
  printf " in \033[36m${PROJECT_NAME}\033[0m"
  printf " on \033[33m⎇ ${BRANCH}\033[0m │"
else
  # Fallback to directory display
  DIR_FULL=$(echo "$CWD" | sed "s|^$HOME|~|")
  DIR_NAME=$(basename "$CWD")
  DEPTH=$(echo "$CWD" | tr '/' '\n' | wc -l)

  if [ $DEPTH -le 3 ]; then
    DIR_DISPLAY="$DIR_FULL"
  else
    PARENT=$(basename "$(dirname "$CWD")")
    DIR_DISPLAY=".../$PARENT/$DIR_NAME"
  fi

  printf " in \033[36m${DIR_DISPLAY}\033[0m"
fi

# Git status info (compact)
cd "$CWD" 2>/dev/null
if git rev-parse --git-dir > /dev/null 2>&1; then
  # Get git status (skip optional locks for speed)
  git config --local core.commitGraph false 2>/dev/null
  STATUS=$(git status --porcelain --untracked-files=normal 2>/dev/null)

  if [ -n "$STATUS" ]; then
    # Count changes
    MODIFIED=$(echo "$STATUS" | grep -c "^ M" || true)
    ADDED=$(echo "$STATUS" | grep -c "^A" || true)
    DELETED=$(echo "$STATUS" | grep -c "^ D" || true)
    UNTRACKED=$(echo "$STATUS" | grep -c "^??" || true)

    # Show compact status (only if changes exist)
    STATUS_STR=""
    [ $MODIFIED -gt 0 ] && STATUS_STR="${STATUS_STR}\033[33m~${MODIFIED}\033[0m"
    [ $ADDED -gt 0 ] && STATUS_STR="${STATUS_STR}\033[32m+${ADDED}\033[0m"
    [ $DELETED -gt 0 ] && STATUS_STR="${STATUS_STR}\033[31m-${DELETED}\033[0m"
    [ $UNTRACKED -gt 0 ] && STATUS_STR="${STATUS_STR}\033[90m?${UNTRACKED}\033[0m"

    [ -n "$STATUS_STR" ] && printf " [${STATUS_STR}]"
  fi

  # Check if repo has remote
  REMOTE=$(git remote 2>/dev/null | head -n1)
  if [ -n "$REMOTE" ]; then
    # Check ahead/behind
    AHEAD=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0)
    BEHIND=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo 0)

    [ $AHEAD -gt 0 ] && printf " \033[32m↑$AHEAD\033[0m"
    [ $BEHIND -gt 0 ] && printf " \033[31m↓$BEHIND\033[0m"
  fi
fi

# ===============================================
# Current Session Usage (5-hour windows)
# ===============================================
# 5-hour blocks:
# 1-6    (01:00 to 06:00)
# 6-11   (06:00 to 11:00)
# 11-4   (11:00 to 16:00)
# 4-9    (16:00 to 21:00)
# 9-1    (21:00 to 01:00) - 4 hour block to accommodate 24h

# Get current hour and minute
CURRENT_HOUR=$(date +%H | sed 's/^0//')
CURRENT_MIN=$(date +%M | sed 's/^0//')

# Define 5-hour blocks
# Block 1: 01:00-06:00
# Block 2: 06:00-11:00
# Block 3: 11:00-16:00
# Block 4: 16:00-21:00
# Block 5: 21:00-01:00 (next day)

BLOCK_START=""
BLOCK_END=""
BLOCK_NAME=""

if [ $CURRENT_HOUR -ge 1 ] && [ $CURRENT_HOUR -lt 6 ]; then
  # Block 1: 1-6
  BLOCK_START=1
  BLOCK_END=6
  BLOCK_NAME="1-6"
elif [ $CURRENT_HOUR -ge 6 ] && [ $CURRENT_HOUR -lt 11 ]; then
  # Block 2: 6-11
  BLOCK_START=6
  BLOCK_END=11
  BLOCK_NAME="6-11"
elif [ $CURRENT_HOUR -ge 11 ] && [ $CURRENT_HOUR -lt 16 ]; then
  # Block 3: 11-4
  BLOCK_START=11
  BLOCK_END=16
  BLOCK_NAME="11-4"
elif [ $CURRENT_HOUR -ge 16 ] && [ $CURRENT_HOUR -lt 21 ]; then
  # Block 4: 4-9
  BLOCK_START=16
  BLOCK_END=21
  BLOCK_NAME="4-9"
else
  # Block 5: 9-1 (or 21-1)
  BLOCK_START=21
  BLOCK_END=1
  BLOCK_NAME="9-1"
fi

# Calculate time until reset
CURRENT_TIME_MIN=$((CURRENT_HOUR * 60 + CURRENT_MIN))

if [ "$BLOCK_END" = "1" ]; then
  # Special case: block 5 (21:00 to 01:00 next day)
  if [ $CURRENT_HOUR -ge 21 ]; then
    # Before midnight: count until 00:00 + 1 hour
    MINUTES_UNTIL_MIDNIGHT=$((24 * 60 - CURRENT_TIME_MIN))
    TIME_UNTIL_RESET_MIN=$((MINUTES_UNTIL_MIDNIGHT + 60))  # +1 hour to 01:00
  else
    # After midnight (hour 0): count until 01:00
    TIME_UNTIL_RESET_MIN=$((60 - CURRENT_TIME_MIN))
  fi
else
  # All other blocks
  BLOCK_END_MIN=$((BLOCK_END * 60))
  TIME_UNTIL_RESET_MIN=$((BLOCK_END_MIN - CURRENT_TIME_MIN))
fi

HOURS_UNTIL_RESET=$((TIME_UNTIL_RESET_MIN / 60))
MINS_UNTIL_RESET=$((TIME_UNTIL_RESET_MIN % 60))

TIME_UNTIL_RESET="${HOURS_UNTIL_RESET}h ${MINS_UNTIL_RESET}m"

# Format reset time
if [ "$BLOCK_END" = "1" ]; then
  RESET_TIME="01:00"
else
  RESET_TIME="$(printf '%02d' $BLOCK_END):00"
fi

# Count tokens in current session (use latest session file with actual tokens)
TOKENS_USED=$(/root/.claude/scripts/count-tokens.sh 2>/dev/null || echo "0")

# Ensure TOKENS_USED is a valid number (handle empty or non-numeric results)
TOKENS_USED=${TOKENS_USED:-0}
case "$TOKENS_USED" in
  ''|*[!0-9]*) TOKENS_USED=0 ;;
esac

# Token limit per 5-hour window (Claude Pro: ~44K, Max5: ~88K)
# Using Pro limit as default (can be adjusted for Max5)
# glm-* models have 3x limit (132K tokens)
TOKENS_LIMIT_BASE=44000
case "$MODEL" in
  glm-*)
    TOKENS_LIMIT=$((TOKENS_LIMIT_BASE * 3))
    ;;
  *)
    TOKENS_LIMIT=$TOKENS_LIMIT_BASE
    ;;
esac

# Calculate usage percentage (cap at 100% for progress bar)
USAGE_PCT=$((TOKENS_USED * 100 / TOKENS_LIMIT))
if [ $USAGE_PCT -gt 100 ]; then
  USAGE_PCT=100
fi

# Create visual progress bar [░░░░░░░░░░] (10 blocks)
FILLED=$((USAGE_PCT / 10))
EMPTY=$((10 - FILLED))

PROGRESS_BAR="["
for i in $(seq 1 $FILLED); do
  PROGRESS_BAR="${PROGRESS_BAR}█"
done
for i in $(seq 1 $EMPTY); do
  PROGRESS_BAR="${PROGRESS_BAR}░"
done
PROGRESS_BAR="${PROGRESS_BAR}]"

# Color based on usage
if [ $USAGE_PCT -lt 50 ]; then
  BAR_COLOR="\033[32m"  # Green
elif [ $USAGE_PCT -lt 80 ]; then
  BAR_COLOR="\033[33m"  # Yellow
else
  BAR_COLOR="\033[31m"  # Red
fi

# Format output: | 40.8K/44K tokens [██████░░░░] | reset 21:00(2h 31m)[4-9]
# Format tokens with K suffix for better readability
TOKENS_USED_K=$(awk "BEGIN {printf \"%.1fK\", $TOKENS_USED/1000}")
TOKENS_LIMIT_K=$(awk "BEGIN {printf \"%.0fK\", $TOKENS_LIMIT/1000}")
printf " | ${BAR_COLOR}${TOKENS_USED_K}/${TOKENS_LIMIT_K} ${PROGRESS_BAR}\033[0m"
printf " | \033[90m${RESET_TIME}(${TIME_UNTIL_RESET})[${BLOCK_NAME}]\033[0m"

# CC version and hostname
printf " \033[90m│\033[0m"
printf " \033[36m${CC_VERSION}\033[0m"
printf " \033[90m│\033[0m"
printf "\033[33m $(hostname)\033[0m"

echo
