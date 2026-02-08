#!/usr/bin/env bash
# ===============================================
# Mock Setup Script for statusline-command.sh Tests
# ===============================================
# Creates mock versions of external dependencies for isolated testing
# ===============================================

set -euo pipefail

# Colors for output
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Mock directory
MOCK_DIR="${1:-/tmp/statusline-mocks}"

echo -e "${BLUE}[INFO]${NC} Setting up mocks in: $MOCK_DIR"
mkdir -p "$MOCK_DIR"

# Create mock git
create_mock_git() {
  cat > "$MOCK_DIR/git" << 'EOF'
#!/bin/bash
# Mock git for testing

case "$1" in
  rev-parse)
    if [ "$2" = "--git-dir" ]; then
      # Check if we're in a test git repo
      if [ -d ".git" ] || [ -d "$PWD/../.git" ]; then
        echo ".git"
        exit 0
      fi
      exit 1
    elif [ "$2" = "--show-toplevel" ]; then
      echo "$PWD"
    fi
    ;;
  branch)
    if [ "$2" = "--show-current" ]; then
      if [ -f ".git/HEAD" ]; then
        grep -oP 'refs/heads/\K.*' .git/HEAD 2>/dev/null || echo "main"
      else
        echo "main"
      fi
    fi
    ;;
  remote)
    if [ "$2" = "get-url" ] && [ "$3" = "origin" ]; then
      if [ -f ".git/config" ]; then
        grep -A1 'remote "origin"' .git/config | grep url | cut -d'=' -f2 | tr -d ' ' || echo "https://github.com/test/repo.git"
      else
        echo "https://github.com/test/repo.git"
      fi
    fi
    ;;
  status)
    # Return test status
    echo " M test.txt"
    ;;
  config)
    # Accept all config commands
    exit 0
    ;;
  describe)
    exit 1
    ;;
  *)
    echo "mock-git: $*" >&2
    ;;
esac
EOF
  chmod +x "$MOCK_DIR/git"
  echo -e "${GREEN}[DONE]${NC} Created mock git"
}

# Create mock jq
create_mock_jq() {
  cat > "$MOCK_DIR/jq" << 'EOF'
#!/bin/bash
# Mock jq for testing

# Simple JSON value extraction using grep/sed
if [ $# -ge 1 ]; then
  local filter="$1"
  shift

  # Read JSON from stdin or file
  local json=""
  if [ $# -eq 0 ]; then
    json=$(cat)
  else
    json=$(cat "$1")
  fi

  # Extract field value using grep
  case "$filter" in
    .model.display_name)
      echo "$json" | grep -oP '"display_name"\s*:\s*"\K[^"]+' || echo "Claude"
      ;;
    .cwd)
      echo "$json" | grep -oP '"cwd"\s*:\s*"\K[^"]+' || echo "$PWD"
      ;;
    .workspace.current_dir)
      echo "$json" | grep -oP '"current_dir"\s*:\s*"\K[^"]+' || echo "$PWD"
      ;;
    .workspace.project_dir)
      echo "$json" | grep -oP '"project_dir"\s*:\s*"\K[^"]+' || echo "$PWD"
      ;;
    .output_style.name)
      echo "default"
      ;;
    .tokens)
      echo "45000"
      ;;
    .budget)
      echo "200000"
      ;;
    .percentage)
      echo "22.5"
      ;;
    .zone)
      echo "SMART"
      ;;
    .mcp_count)
      echo "5"
      ;;
    *)
      # Return raw JSON for complex queries
      echo "$json"
      ;;
  esac
fi
EOF
  chmod +x "$MOCK_DIR/jq"
  echo -e "${GREEN}[DONE]${NC} Created mock jq"
}

# Create mock gh (GitHub CLI)
create_mock_gh() {
  cat > "$MOCK_DIR/gh" << 'EOF'
#!/bin/bash
# Mock gh for testing

case "$1" in
  pr)
    case "$2" in
      list)
        echo '[]'
        ;;
    esac
    ;;
  *)
    ;;
esac
EOF
  chmod +x "$MOCK_DIR/gh"
  echo -e "${GREEN}[DONE]${NC} Created mock gh"
}

# Create mock claude
create_mock_claude() {
  cat > "$MOCK_DIR/claude" << 'EOF'
#!/bin/bash
# Mock claude for testing

case "$1" in
  --version)
    echo "Claude Code v1.0.0"
    ;;
  *)
    ;;
esac
EOF
  chmod +x "$MOCK_DIR/claude"
  echo -e "${GREEN}[DONE]${NC} Created mock claude"
}

# Create mock count-context-tokens.sh
create_mock_token_counter() {
  cat > "$MOCK_DIR/count-context-tokens.sh" << 'EOF'
#!/bin/bash
# Mock token counter for testing

case "$1" in
  json)
    cat << 'INNER_EOF'
{
  "tokens": 45200,
  "budget": 200000,
  "percentage": 22.6,
  "zone": "SMART",
  "mcp_count": 5
}
INNER_EOF
    ;;
  *)
    echo "45200"
    ;;
esac
EOF
  chmod +x "$MOCK_DIR/count-context-tokens.sh"
  echo -e "${GREEN}[DONE]${NC} Created mock count-context-tokens.sh"
}

# Create all mocks
create_mock_git
create_mock_jq
create_mock_gh
create_mock_claude
create_mock_token_counter

echo
echo -e "${GREEN}[SUCCESS]${NC} All mocks created successfully"
echo
echo "To use mocks in tests, add to your PATH:"
echo "  export PATH=\"$MOCK_DIR:\$PATH\""
echo
echo "Available mocks:"
ls -1 "$MOCK_DIR"
