#!/bin/bash

# ===============================================
# Claude Code Global Statusline (FGSRV6 Version)
# ===============================================
# Shows useful info across ALL directories:
# - Current directory (shortened path)
# - Git info (branch, status, repo name)
# - Claude Flow metrics (if present)
# - System info (hostname, user)
# ===============================================

# ===============================================
# ERROR HANDLING & VALIDATION
# ===============================================

# Helper function for error logging (won't break statusline)
log_error() {
  echo "[statusline ERROR] $*" >&2
}

# Helper function for debug logging (only if DEBUG=1)
log_debug() {
  if [ "$DEBUG" = "1" ]; then
    echo "[statusline DEBUG] $*" >&2
  fi
}

# Check required dependencies
check_dependencies() {
  local missing_deps=""
  local dep

  for dep in jq git awk sed grep basename cut head find wc date hostname bc; do
    if ! command -v "$dep" >/dev/null 2>&1; then
      if [ -z "$missing_deps" ]; then
        missing_deps="$dep"
      else
        missing_deps="$missing_deps $dep"
      fi
    fi
  done

  if [ -n "$missing_deps" ]; then
    log_error "Missing dependencies: $missing_deps"
    log_error "Statusline will have reduced functionality"
  fi
}

check_dependencies

# Read and validate JSON input from stdin
INPUT=$(cat)

# Validate JSON is not empty
if [ -z "$INPUT" ]; then
  log_error "No input received (stdin is empty)"
  # Provide minimal fallback output
  printf "\033[1mClaude\033[0m [INPUT ERROR] \033[31m✗\033[0m\n"
  exit 0
fi

# Validate JSON structure
if ! echo "$INPUT" | jq empty >/dev/null 2>&1; then
  log_error "Invalid JSON input received"
  # Provide minimal fallback output
  printf "\033[1mClaude\033[0m [JSON ERROR] \033[31m✗\033[0m\n"
  exit 0
fi

# Extract JSON fields with safe defaults
MODEL=$(echo "$INPUT" | jq -r '.model.display_name // "Claude"' 2>/dev/null || echo "Claude")
CWD=$(echo "$INPUT" | jq -r '.workspace.current_dir // .cwd // "."' 2>/dev/null || echo ".")
PROJECT_DIR=$(echo "$INPUT" | jq -r '.workspace.project_dir // .cwd // "."' 2>/dev/null || echo ".")

# Validate critical paths
if [ ! -d "$CWD" ]; then
  log_error "CWD path does not exist: $CWD"
  CWD="."
fi

if [ ! -d "$PROJECT_DIR" ]; then
  log_debug "PROJECT_DIR does not exist: $PROJECT_DIR"
  PROJECT_DIR="$CWD"
fi

DIR=$(basename "$CWD" 2>/dev/null || echo "unknown")

# Replace claude-code-flow with branded name
if [ "$DIR" = "claude-code-flow" ]; then
  DIR="🌊 Claude Flow"
fi

# Get git branch with error handling
BRANCH=""
if command -v git >/dev/null 2>&1; then
  BRANCH=$(cd "$CWD" 2>/dev/null && git branch --show-current 2>/dev/null || echo "")
fi

# Start building statusline
printf "\033[1m$MODEL\033[0m in \033[36m$DIR\033[0m"
[ -n "$BRANCH" ] && printf " on \033[33m⎇ $BRANCH\033[0m"

# ===============================================
# Claude-Flow Integration (with graceful fallback)
# ===============================================
FLOW_DIR="$CWD/.claude-flow"

if [ -d "$FLOW_DIR" ]; then
  printf " │"

  # 1. Swarm Configuration & Topology
  if [ -f "$FLOW_DIR/swarm-config.json" ]; then
    # Validate JSON before parsing
    if jq empty "$FLOW_DIR/swarm-config.json" >/dev/null 2>&1; then
      STRATEGY=$(jq -r '.defaultStrategy // empty' "$FLOW_DIR/swarm-config.json" 2>/dev/null || echo "")
      if [ -n "$STRATEGY" ]; then
        # Map strategy to topology icon
        case "$STRATEGY" in
          "balanced") TOPO_ICON="⚡mesh" ;;
          "conservative") TOPO_ICON="⚡hier" ;;
          "aggressive") TOPO_ICON="⚡ring" ;;
          *) TOPO_ICON="⚡$STRATEGY" ;;
        esac
        printf " \033[35m$TOPO_ICON\033[0m"

        # Count agent profiles as "configured agents"
        AGENT_COUNT=$(jq -r '.agentProfiles | length' "$FLOW_DIR/swarm-config.json" 2>/dev/null || echo "0")
        if [ -n "$AGENT_COUNT" ] && [ "$AGENT_COUNT" != "null" ] && [ "$AGENT_COUNT" -gt 0 ] 2>/dev/null; then
          printf "  \033[35m🤖 $AGENT_COUNT\033[0m"
        fi
      fi
    else
      log_debug "Invalid JSON in swarm-config.json"
    fi
  fi

  # 2. Real-time System Metrics
  if [ -f "$FLOW_DIR/metrics/system-metrics.json" ]; then
    # Validate JSON before parsing
    if jq empty "$FLOW_DIR/metrics/system-metrics.json" >/dev/null 2>&1; then
      # Get latest metrics (last entry in array)
      LATEST=$(jq -r '.[-1]' "$FLOW_DIR/metrics/system-metrics.json" 2>/dev/null || echo "null")

      if [ -n "$LATEST" ] && [ "$LATEST" != "null" ]; then
        # Memory usage
        MEM_PERCENT=$(echo "$LATEST" | jq -r '.memoryUsagePercent // 0' 2>/dev/null | awk '{printf "%.0f", $1}' || echo "0")
        if [ -n "$MEM_PERCENT" ] && [ "$MEM_PERCENT" != "null" ]; then
          # Color-coded memory (green <60%, yellow 60-80%, red >80%)
          if [ "$MEM_PERCENT" -lt 60 ] 2>/dev/null; then
            MEM_COLOR="\033[32m"  # Green
          elif [ "$MEM_PERCENT" -lt 80 ] 2>/dev/null; then
            MEM_COLOR="\033[33m"  # Yellow
          else
            MEM_COLOR="\033[31m"  # Red
          fi
          printf "  ${MEM_COLOR}💾 ${MEM_PERCENT}%\033[0m"
        fi

        # CPU load
        CPU_LOAD=$(echo "$LATEST" | jq -r '.cpuLoad // 0' 2>/dev/null | awk '{printf "%.0f", $1 * 100}' || echo "0")
        if [ -n "$CPU_LOAD" ] && [ "$CPU_LOAD" != "null" ]; then
          # Color-coded CPU (green <50%, yellow 50-75%, red >75%)
          if [ "$CPU_LOAD" -lt 50 ] 2>/dev/null; then
            CPU_COLOR="\033[32m"  # Green
          elif [ "$CPU_LOAD" -lt 75 ] 2>/dev/null; then
            CPU_COLOR="\033[33m"  # Yellow
          else
            CPU_COLOR="\033[31m"  # Red
          fi
          printf "  ${CPU_COLOR}⚙ ${CPU_LOAD}%\033[0m"
        fi
      fi
    else
      log_debug "Invalid JSON in system-metrics.json"
    fi
  fi

  # 3. Session State
  if [ -f "$FLOW_DIR/session-state.json" ]; then
    # Validate JSON before parsing
    if jq empty "$FLOW_DIR/session-state.json" >/dev/null 2>&1; then
      SESSION_ID=$(jq -r '.sessionId // empty' "$FLOW_DIR/session-state.json" 2>/dev/null || echo "")
      ACTIVE=$(jq -r '.active // false' "$FLOW_DIR/session-state.json" 2>/dev/null || echo "false")

      if [ "$ACTIVE" = "true" ] && [ -n "$SESSION_ID" ]; then
        # Show abbreviated session ID
        SHORT_ID=$(echo "$SESSION_ID" | cut -d'-' -f1 2>/dev/null || echo "$SESSION_ID")
        printf "  \033[34m🔄 $SHORT_ID\033[0m"
      fi
    else
      log_debug "Invalid JSON in session-state.json"
    fi
  fi

  # 4. Performance Metrics from task-metrics.json
  if [ -f "$FLOW_DIR/metrics/task-metrics.json" ]; then
    # Validate JSON before parsing
    if jq empty "$FLOW_DIR/metrics/task-metrics.json" >/dev/null 2>&1; then
      # Parse task metrics for success rate, avg time, and streak
      METRICS=$(jq -r '
        # Calculate metrics
        (map(select(.success == true)) | length) as $successful |
        (length) as $total |
        (if $total > 0 then ($successful / $total * 100) else 0 end) as $success_rate |
        (map(.duration // 0) | add / length) as $avg_duration |
        # Calculate streak (consecutive successes from end)
        (reverse |
          reduce .[] as $task (0;
            if $task.success == true then . + 1 else 0 end
          )
        ) as $streak |
        {
          success_rate: $success_rate,
          avg_duration: $avg_duration,
          streak: $streak,
          total: $total
        } | @json
      ' "$FLOW_DIR/metrics/task-metrics.json" 2>/dev/null || echo '{"success_rate":0,"avg_duration":0,"streak":0,"total":0}')

      if [ -n "$METRICS" ] && [ "$METRICS" != "null" ]; then
        # Success Rate
        SUCCESS_RATE=$(echo "$METRICS" | jq -r '.success_rate // 0' 2>/dev/null | awk '{printf "%.0f", $1}' || echo "0")
        TOTAL_TASKS=$(echo "$METRICS" | jq -r '.total // 0' 2>/dev/null || echo "0")

        if [ -n "$SUCCESS_RATE" ] && [ "$TOTAL_TASKS" -gt 0 ] 2>/dev/null; then
          # Color-code: Green (>80%), Yellow (60-80%), Red (<60%)
          if [ "$SUCCESS_RATE" -gt 80 ] 2>/dev/null; then
            SUCCESS_COLOR="\033[32m"  # Green
          elif [ "$SUCCESS_RATE" -ge 60 ] 2>/dev/null; then
            SUCCESS_COLOR="\033[33m"  # Yellow
          else
            SUCCESS_COLOR="\033[31m"  # Red
          fi
          printf "  ${SUCCESS_COLOR}🎯 ${SUCCESS_RATE}%\033[0m"
        fi

        # Average Time
        AVG_TIME=$(echo "$METRICS" | jq -r '.avg_duration // 0' 2>/dev/null || echo "0")
        if [ -n "$AVG_TIME" ] && [ "$TOTAL_TASKS" -gt 0 ] 2>/dev/null; then
          # Format smartly: seconds, minutes, or hours (safe bc operations)
          if command -v bc >/dev/null 2>&1; then
            if [ $(echo "$AVG_TIME < 60" | bc -l 2>/dev/null || echo 0) -eq 1 ]; then
              TIME_STR=$(echo "$AVG_TIME" | awk '{printf "%.1fs", $1}')
            elif [ $(echo "$AVG_TIME < 3600" | bc -l 2>/dev/null || echo 0) -eq 1 ]; then
              TIME_STR=$(echo "$AVG_TIME" | awk '{printf "%.1fm", $1/60}')
            else
              TIME_STR=$(echo "$AVG_TIME" | awk '{printf "%.1fh", $1/3600}')
            fi
          else
            # Fallback if bc is not available
            TIME_STR=$(echo "$AVG_TIME" | awk '{printf "%.1fs", $1}')
          fi
          printf "  \033[36m⏱️  $TIME_STR\033[0m"
        fi

        # Streak (only show if > 0)
        STREAK=$(echo "$METRICS" | jq -r '.streak // 0' 2>/dev/null || echo "0")
        if [ -n "$STREAK" ] && [ "$STREAK" -gt 0 ] 2>/dev/null; then
          printf "  \033[91m🔥 $STREAK\033[0m"
        fi
      fi
    else
      log_debug "Invalid JSON in task-metrics.json"
    fi
  fi

  # 5. Active Tasks (check for task files)
  if [ -d "$FLOW_DIR/tasks" ]; then
    TASK_COUNT=$(find "$FLOW_DIR/tasks" -name "*.json" -type f 2>/dev/null | wc -l || echo "0")
    if [ "$TASK_COUNT" -gt 0 ] 2>/dev/null; then
      printf "  \033[36m📋 $TASK_COUNT\033[0m"
    fi
  fi

  # 6. Check for hooks activity
  if [ -f "$FLOW_DIR/hooks-state.json" ]; then
    # Validate JSON before parsing
    if jq empty "$FLOW_DIR/hooks-state.json" >/dev/null 2>&1; then
      HOOKS_ACTIVE=$(jq -r '.enabled // false' "$FLOW_DIR/hooks-state.json" 2>/dev/null || echo "false")
      if [ "$HOOKS_ACTIVE" = "true" ]; then
        printf " \033[35m🔗\033[0m"
      fi
    else
      log_debug "Invalid JSON in hooks-state.json"
    fi
  fi
else
  log_debug "Claude-Flow directory not found: $FLOW_DIR"
fi

echo
