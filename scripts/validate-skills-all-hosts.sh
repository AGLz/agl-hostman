#!/usr/bin/env bash
# ============================================================
# Validate Agent Skills Installation on AGL Infrastructure
# ============================================================
# Usage: ./scripts/validate-skills-all-hosts.sh
# ============================================================

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

declare -A HOST_IPS
HOST_IPS[agldv03]="100.94.221.87"
HOST_IPS[agldv04]="100.113.9.98"
HOST_IPS[agldv05]="100.82.71.49"
HOST_IPS[agldv06]="100.71.229.12"
HOST_IPS[agldv07]="100.64.175.89"
HOST_IPS[agldv12]="100.71.217.115"
HOST_IPS[fgsrv06]="100.83.51.9"

declare -A HOST_KEYS
HOST_KEYS[fgsrv06]="-i ~/.ssh/fg_srv.pem"

REQUIRED_SKILLS=(
  "proxmox-agl"
  "tailscale-agl"
  "qemu-agl"
  "wireguard-agl"
  "ruflo-agl"
  "cursor-cli-agl"
  "qwen-code-agl"
  "proxmox"
  "tailscale"
)

log() { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }

echo ""
echo -e "${BOLD}=============================================${NC}"
echo -e "${BOLD}  AGL Agent Skills Validation${NC}"
echo -e "${BOLD}=============================================${NC}"
echo ""

TOTAL_HOSTS=0
REACHABLE_HOSTS=0
FULLY_INSTALLED=0
PARTIAL_INSTALLED=0

for host_name in "${!HOST_IPS[@]}"; do
  host_ip="${HOST_IPS[$host_name]}"
  ssh_opts="${HOST_KEYS[$host_name]:-}"
  TOTAL_HOSTS=$((TOTAL_HOSTS + 1))

  echo -e "${BOLD}=== $host_name ($host_ip) ===${NC}"

  # Test connectivity
  if ! ssh $ssh_opts -o ConnectTimeout=5 -o BatchMode=yes "root@$host_ip" "echo OK" > /dev/null 2>&1; then
    log_error "  UNREACHABLE"
    echo ""
    continue
  fi

  REACHABLE_HOSTS=$((REACHABLE_HOSTS + 1))

  # Check ~/.qwen/skills/
  qwen_count=$(ssh $ssh_opts "root@$host_ip" "ls -1 /root/.qwen/skills/ 2>/dev/null | grep -v backup | wc -l" | tr -d ' ')
  
  # Check ~/.claude/skills/
  claude_count=$(ssh $ssh_opts "root@$host_ip" "ls -1 /root/.claude/skills/ 2>/dev/null | grep -v backup | wc -l" | tr -d ' ')

  # Check project skills
  project_count=$(ssh $ssh_opts "root@$host_ip" "ls -1 /mnt/overpower/apps/dev/agl/agl-hostman/.qwen/skills/ 2>/dev/null | wc -l" | tr -d ' ')

  echo -e "  ~/.qwen/skills/:  ${CYAN}$qwen_count${NC}"
  echo -e "  ~/.claude/skills: ${CYAN}$claude_count${NC}"
  echo -e "  project/.qwen:    ${CYAN}$project_count${NC}"

  # Check required skills
  missing=0
  for skill in "${REQUIRED_SKILLS[@]}"; do
    has_skill=$(ssh $ssh_opts "root@$host_ip" "test -f /root/.qwen/skills/$skill/SKILL.md && echo yes || echo no" | tr -d ' ')
    if [[ "$has_skill" != "yes" ]]; then
      log_warn "  Missing: $skill"
      missing=$((missing + 1))
    fi
  done

  if [[ $missing -eq 0 ]]; then
    log_success "  All ${#REQUIRED_SKILLS[@]} required skills present"
    FULLY_INSTALLED=$((FULLY_INSTALLED + 1))
  else
    log_warn "  $missing skills missing"
    PARTIAL_INSTALLED=$((PARTIAL_INSTALLED + 1))
  fi

  # Check Claude Code availability
  has_claude=$(ssh $ssh_opts "root@$host_ip" "which claude 2>/dev/null && echo yes || echo no" | tr -d ' ')
  if [[ "$has_claude" == *"yes"* ]]; then
    log_success "  Claude Code: installed"
  else
    log_warn "  Claude Code: not found"
  fi

  echo ""
done

echo -e "${BOLD}=============================================${NC}"
echo -e "${BOLD}  Summary${NC}"
echo -e "${BOLD}=============================================${NC}"
echo ""
echo -e "  Total hosts:       ${CYAN}$TOTAL_HOSTS${NC}"
echo -e "  Reachable:         ${GREEN}$REACHABLE_HOSTS${NC}"
echo -e "  Unreachable:       ${RED}$((TOTAL_HOSTS - REACHABLE_HOSTS))${NC}"
echo -e "  Fully installed:   ${GREEN}$FULLY_INSTALLED${NC}"
echo -e "  Partial installed: ${YELLOW}$PARTIAL_INSTALLED${NC}"
echo ""

if [[ $FULLY_INSTALLED -eq $REACHABLE_HOSTS ]]; then
  echo -e "${GREEN}  ✓ All reachable hosts have all required skills!${NC}"
else
  echo -e "${YELLOW}  ! Some hosts need attention${NC}"
fi
echo ""
