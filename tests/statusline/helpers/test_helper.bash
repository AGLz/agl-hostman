#!/usr/bin/env bash
# ===============================================
# Test Helper Functions for statusline-command.sh
# ===============================================
# Common helper functions used across test files
# ===============================================

# Project root detection
get_project_root() {
  local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  echo "${script_dir}/../.."
}

# Path to statusline script
get_statusline_script() {
  local project_root="${1:-$(get_project_root)}"
  echo "${project_root}/.claude/statusline-command.sh"
}

# Create temporary git repository for testing
create_test_git_repo() {
  local test_dir="$1"
  local branch="${2:-main}"

  mkdir -p "$test_dir"
  cd "$test_dir"

  git init -q
  git config user.email "test@test.com"
  git config user.name "Test User"
  git checkout -b "$branch" 2>/dev/null || git branch -M "$branch"

  echo "$test_dir"
}

# Create test git repository with remote
create_test_git_repo_with_remote() {
  local test_dir="$1"
  local remote_url="${2:-https://github.com/test/repo.git}"
  local branch="${3:-main}"

  create_test_git_repo "$test_dir" "$branch"
  git remote add origin "$remote_url"

  echo "$test_dir"
}

# Create test git repository with changes
create_test_git_repo_with_changes() {
  local test_dir="$1"
  local branch="${2:-main}"

  create_test_git_repo "$test_dir" "$branch"

  # Create some commits
  touch initial.txt
  git add initial.txt
  git commit -m "Initial commit" 2>/dev/null

  # Create modified file
  echo "modified" > initial.txt

  # Create new file (staged)
  touch new.txt
  git add new.txt

  # Create untracked file
  touch untracked.txt

  echo "$test_dir"
}

# Create mock token counter script
create_mock_token_counter() {
  local output_dir="$1"
  local tokens="${2:-45000}"
  local budget="${3:-200000}"
  local zone="${4:-SMART}"
  local mcp_count="${5:-5}"

  local script_path="${output_dir}/count-context-tokens.sh"

  cat > "$script_path" << EOF
#!/bin/bash
# Mock token counter for testing
if [ "\$1" = "json" ]; then
  cat << INNER_EOF
{
  "tokens": $tokens,
  "budget": $budget,
  "percentage": $(awk "BEGIN {printf \"%.1f\", $tokens * 100.0 / $budget}"),
  "zone": "$zone",
  "mcp_count": $mcp_count
}
INNER_EOF
else
  echo "$tokens"
fi
EOF

  chmod +x "$script_path"
  echo "$script_path"
}

# Create mock V3 statusline helper
create_mock_v3_helper() {
  local output_dir="$1"
  local ddd_done="${2:-3}"
  local ddd_total="${3:-5}"
  local swarm_agents="${4:-2}"
  local intelligence="${5:-65}"
  local sec_status="${6:-IN_PROGRESS}"

  local helper_path="${output_dir}/.claude/helpers/statusline.cjs"
  mkdir -p "$(dirname "$helper_path")"

  cat > "$helper_path" << EOF
#!/usr/bin/env node
console.log(JSON.stringify({
  v3Progress: {
    domainsCompleted: $ddd_done,
    totalDomains: $ddd_total
  },
  swarm: {
    activeAgents: $swarm_agents
  },
  system: {
    intelligencePct: $intelligence
  },
  security: {
    status: "$sec_status"
  }
}));
EOF

  chmod +x "$helper_path"
  echo "$helper_path"
}

# Create test JSON input
create_test_json_input() {
  local model="${1:-Claude}"
  local cwd="${2:-/test}"
  local project_dir="${3:-/test}"

  cat << EOF
{
  "session_id": "test-123",
  "model": {
    "id": "claude-sonnet-4-5-20250929",
    "display_name": "$model"
  },
  "workspace": {
    "current_dir": "$cwd",
    "project_dir": "$project_dir"
  },
  "cwd": "$cwd",
  "output_style": {
    "name": "default"
  }
}
EOF
}

# Run statusline script and capture output
run_statusline() {
  local statusline_script="$1"
  local json_input="$2"
  local extra_args="${3:-}"

  echo "$json_input" | bash $extra_args "$statusline_script"
}

# Extract token count from statusline output
extract_tokens() {
  local output="$1"
  echo "$output" | grep -oP '\d+\.?\d*K/\d+' | head -1
}

# Extract branch name from statusline output
extract_branch() {
  local output="$1"
  echo "$output" | grep -oP '⎇ \K[\w-]+' | head -1
}

# Extract project name from statusline output
extract_project() {
  local output="$1"
  echo "$output" | grep -oP 'in \x1b\[36m\K[^\x1b]+' | head -1
}

# Check if output contains ANSI color codes
has_ansi_colors() {
  local output="$1"
  [[ "$output" =~ $'\033[' ]]
}

# Check if output contains specific icon
has_icon() {
  local output="$1"
  local icon="$2"
  [[ "$output" =~ "$icon" ]]
}

# Get current time block based on hour
get_time_block() {
  local hour="${1:-$(date +%H | sed 's/^0//')}"

  if [ "$hour" -ge 1 ] && [ "$hour" -lt 6 ]; then
    echo "1-6"
  elif [ "$hour" -ge 6 ] && [ "$hour" -lt 11 ]; then
    echo "6-11"
  elif [ "$hour" -ge 11 ] && [ "$hour" -lt 16 ]; then
    echo "11-4"
  elif [ "$hour" -ge 16 ] && [ "$hour" -lt 21 ]; then
    echo "4-9"
  else
    echo "9-1"
  fi
}

# Calculate time until reset
calculate_time_until_reset() {
  local hour="${1:-$(date +%H | sed 's/^0//')}"
  local minute="${2:-$(date +%M | sed 's/^0//')}"

  local current_time_min=$((hour * 60 + minute))
  local time_until_min
  local block_end

  if [ "$hour" -ge 1 ] && [ "$hour" -lt 6 ]; then
    block_end=6
  elif [ "$hour" -ge 6 ] && [ "$hour" -lt 11 ]; then
    block_end=11
  elif [ "$hour" -ge 11 ] && [ "$hour" -lt 16 ]; then
    block_end=16
  elif [ "$hour" -ge 16 ] && [ "$hour" -lt 21 ]; then
    block_end=21
  else
    # Block 5 (21-1)
    if [ "$hour" -ge 21 ]; then
      local minutes_until_midnight=$((24 * 60 - current_time_min))
      time_until_min=$((minutes_until_midnight + 60))
    else
      time_until_min=$((60 - current_time_min))
    fi
    echo "$((time_until_min / 60))h $((time_until_min % 60))m"
    return
  fi

  local block_end_min=$((block_end * 60))
  time_until_min=$((block_end_min - current_time_min))

  echo "$((time_until_min / 60))h $((time_until_min % 60))m"
}

# Strip ANSI codes from output
strip_ansi_codes() {
  local output="$1"
  echo "$output" | sed 's/\x1b\[[0-9;]*m//g'
}

# Get output length without ANSI codes
get_output_length() {
  local output="$1"
  local stripped=$(strip_ansi_codes "$output")
  echo "${#stripped}"
}

# Check if progress bar is present
has_progress_bar() {
  local output="$1"
  [[ "$output" =~ "[" ]] && [[ "$output" =~ "]" ]] && \
    ([[ "$output" =~ "█" ]] || [[ "$output" =~ "░" ]])
}

# Get progress bar fill percentage
get_progress_bar_fill() {
  local output="$1"
  local bar=$(echo "$output" | grep -oP '\[█░]+\]' | head -1)
  local filled=$(echo "$bar" | grep -o "█" | wc -l)
  echo "$filled"
}

# Validate statusline output structure
validate_statusline_structure() {
  local output="$1"
  local errors=0

  # Check for model name
  if ! [[ "$output" =~ "Claude" ]] && ! [[ "$output" =~ "Sonnet" ]]; then
    echo "ERROR: Model name not found" >&2
    ((errors++))
  fi

  # Check for directory or project info
  if ! [[ "$output" =~ "/" ]] && ! [[ "$output" =~ "~" ]]; then
    echo "ERROR: Directory info not found" >&2
    ((errors++))
  fi

  # Check for time/reset info
  if ! [[ "$output" =~ "h " ]] && ! [[ "$output" =~ "m" ]]; then
    echo "WARNING: Time info not found" >&2
  fi

  return $errors
}

# Performance measurement helper
measure_execution_time() {
  local command="$1"
  local iterations="${2:-1}"

  local start=$(date +%s%N)
  for ((i=0; i<iterations; i++)); do
    eval "$command" > /dev/null
  done
  local end=$(date +%s%N)

  echo $(( (end - start) / 1000000 / iterations ))
}

# Export functions for use in test files
export -f get_project_root
export -f get_statusline_script
export -f create_test_git_repo
export -f create_test_git_repo_with_remote
export -f create_test_git_repo_with_changes
export -f create_mock_token_counter
export -f create_mock_v3_helper
export -f create_test_json_input
export -f run_statusline
export -f extract_tokens
export -f extract_branch
export -f extract_project
export -f has_ansi_colors
export -f has_icon
export -f get_time_block
export -f calculate_time_until_reset
export -f strip_ansi_codes
export -f get_output_length
export -f has_progress_bar
export -f get_progress_bar_fill
export -f validate_statusline_structure
export -f measure_execution_time
