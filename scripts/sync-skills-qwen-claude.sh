#!/usr/bin/env bash
# ============================================================
# Sync Skills between ~/.qwen/skills/ and ~/.claude/skills/
# ============================================================
# Syncs all skills from ~/.qwen/skills/ to ~/.claude/skills/
# and vice versa. Run on each host or remotely via SSH.
#
# Usage: ./scripts/sync-skills-qwen-claude.sh [--host IP] [--direction qwen-to-claude|claude-to-qwen|both]
# ============================================================

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Defaults
REMOTE_HOST=""
DIRECTION="both"
SSH_OPTS=""

for arg in "$@"; do
  case "$arg" in
    --host) REMOTE_HOST="$2"; shift 2 ;;
    --direction) DIRECTION="$2"; shift 2 ;;
  esac
done

log() { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_info() { echo -e "${CYAN}[i]${NC} $1"; }

# Determine execution context
if [[ -n "$REMOTE_HOST" ]]; then
  # Remote execution
  if [[ "$REMOTE_HOST" == "100.83.51.9" ]]; then
    SSH_OPTS="-i ~/.ssh/fg_srv.pem"
  fi
  
  exec_cmd() {
    ssh $SSH_OPTS "root@$REMOTE_HOST" "$1"
  }
  exec_scp_to() {
    scp -rq $SSH_OPTS "$1" "root@$REMOTE_HOST:$2"
  }
  exec_scp_from() {
    scp -rq $SSH_OPTS "root@$REMOTE_HOST:$1" "$2"
  }
else
  # Local execution
  exec_cmd() { eval "$1"; }
  exec_scp_to() { cp -r "$1" "$2"; }
  exec_scp_from() { cp -r "$1" "$2"; }
fi

sync_skills() {
  local src_dir="$1"
  local dst_dir="$2"
  local label="$3"

  log_info "Syncing: $label"
  
  # Ensure source exists
  local src_exists
  src_exists=$(exec_cmd "test -d $src_dir && echo yes || echo no")
  
  if [[ "$src_exists" != "yes" ]]; then
    log_info "  Source $src_dir doesn't exist, skipping"
    return
  fi

  # Create destination
  exec_cmd "mkdir -p $dst_dir"

  # Count source skills
  local count
  count=$(exec_cmd "ls -1 $src_dir/ 2>/dev/null | wc -l" | tr -d ' ')
  
  # Sync each skill
  local skills
  skills=$(exec_cmd "ls -1 $src_dir/ 2>/dev/null")
  
  local synced=0
  while IFS= read -r skill; do
    [[ -z "$skill" ]] && continue
    
    # Check if it's a valid skill (has SKILL.md)
    local has_skill_md
    has_skill_md=$(exec_cmd "test -f $src_dir/$skill/SKILL.md && echo yes || echo no")
    
    if [[ "$has_skill_md" != "yes" ]]; then
      continue
    fi

    # Backup existing
    exec_cmd "test -d $dst_dir/$skill && cp -r $dst_dir/$skill $dst_dir/$skill.backup.$(date +%Y%m%d_%H%M%S) || true"
    
    # Copy
    if [[ -n "$REMOTE_HOST" ]]; then
      # For remote, we need to use scp
      if [[ "$src_dir" == "/root/.qwen/skills" ]]; then
        exec_scp_from "/root/.qwen/skills/$skill" "/tmp/skill-sync-$skill"
        exec_scp_to "/tmp/skill-sync-$skill" "$dst_dir/$skill"
        exec_cmd "rm -rf /tmp/skill-sync-$skill"
      else
        exec_scp_from "/root/.claude/skills/$skill" "/tmp/skill-sync-$skill"
        exec_scp_to "/tmp/skill-sync-$skill" "$src_dir/$skill"
        exec_cmd "rm -rf /tmp/skill-sync-$skill"
      fi
    else
      rm -rf "$dst_dir/$skill"
      cp -r "$src_dir/$skill" "$dst_dir/$skill"
    fi
    
    synced=$((synced + 1))
  done <<< "$skills"

  log_success "  Synced $synced skills → $dst_dir"
}

echo ""
echo -e "${BOLD}=============================================${NC}"
echo -e "${BOLD}  Skills Sync: Qwen Code ↔ Claude Code${NC}"
echo -e "${BOLD}=============================================${NC}"
echo ""

if [[ -n "$REMOTE_HOST" ]]; then
  echo -e "  Target: ${CYAN}$REMOTE_HOST${NC}"
else
  echo -e "  Target: ${CYAN}local${NC}"
fi

echo -e "  Direction: ${CYAN}$DIRECTION${NC}"
echo ""

if [[ "$DIRECTION" == "qwen-to-claude" || "$DIRECTION" == "both" ]]; then
  sync_skills "/root/.qwen/skills" "/root/.claude/skills" "Qwen → Claude"
fi

if [[ "$DIRECTION" == "claude-to-qwen" || "$DIRECTION" == "both" ]]; then
  sync_skills "/root/.claude/skills" "/root/.qwen/skills" "Claude → Qwen"
fi

# Final count
echo ""
echo -e "${BOLD}=============================================${NC}"
echo -e "${GREEN}  Sync Complete!${NC}"
echo -e "${BOLD}=============================================${NC}"

if [[ -n "$REMOTE_HOST" ]]; then
  qwen_count=$(exec_cmd "ls -1 /root/.qwen/skills/ 2>/dev/null | wc -l" | tr -d ' ')
  claude_count=$(exec_cmd "ls -1 /root/.claude/skills/ 2>/dev/null | wc -l" | tr -d ' ')
  echo -e "  ~/.qwen/skills/:  ${CYAN}$qwen_count${NC}"
  echo -e "  ~/.claude/skills: ${CYAN}$claude_count${NC}"
else
  echo -e "  ~/.qwen/skills/:  ${CYAN}$(ls -1 ~/.qwen/skills/ 2>/dev/null | wc -l | tr -d ' ')${NC}"
  echo -e "  ~/.claude/skills: ${CYAN}$(ls -1 ~/.claude/skills/ 2>/dev/null | wc -l | tr -d ' ')${NC}"
fi
echo ""
