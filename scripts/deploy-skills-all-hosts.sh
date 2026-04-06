#!/usr/bin/env bash
# ============================================================
# Deploy ALL Agent Skills to AGL Infrastructure
# ============================================================
# Deploys custom AGL skills + community skills to all hosts:
#   agldv03, agldv04, agldv05, agldv06, agldv07, agldv12, fgsrv06
#
# Also dep to macOS local (~/.qwen/skills/)
#
# Usage: ./scripts/deploy-skills-all-hosts.sh [--local-only|--remote-only|--dry-run]
# ============================================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Parse args
MODE="all"
for arg in "$@"; do
  case "$arg" in
    --local-only) MODE="local" ;;
    --remote-only) MODE="remote" ;;
    --dry-run) MODE="dry-run" ;;
    --help|-h)
      echo "Usage: $0 [--local-only|--remote-only|--dry-run]"
      echo ""
      echo "  --local-only   Deploy only to macOS local"
      echo "  --remote-only  Deploy only to remote hosts"
      echo "  --dry-run      Show what would be deployed without making changes"
      exit 0
      ;;
  esac
done

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$REPO_ROOT/skills"

log() { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_info() { echo -e "${CYAN}[i]${NC} $1"; }

# ============================================================
# Skills to deploy
# ============================================================
AGL_SKILLS=(
  "proxmox-agl"
  "tailscale-agl"
  "qemu-agl"
  "wireguard-agl"
  "ruflo-agl"
  "cursor-cli-agl"
  "qwen-code-agl"
)

# Community skills (from openclaw/skills repo - raw URLs)
# These will be fetched from GitHub and deployed
declare -A COMMUNITY_SKILLS
COMMUNITY_SKILLS[proxmox]="https://raw.githubusercontent.com/openclaw/skills/main/skills/weird-aftertaste/proxmox/SKILL.md"
COMMUNITY_SKILLS[tailscale]="https://raw.githubusercontent.com/sundial-org/awesome-openclaw-skills/main/skills/tailscale/SKILL.md"

# ============================================================
# Remote hosts
# ============================================================
declare -A HOST_IPS
HOST_IPS[agldv03]="100.94.221.87"
HOST_IPS[agldv04]="100.113.9.98"
HOST_IPS[agldv05]="100.119.41.63"
HOST_IPS[agldv06]="100.71.229.12"
HOST_IPS[agldv07]="100.80.30.59"
HOST_IPS[agldv12]="100.71.217.115"
HOST_IPS[fgsrv06]="100.83.51.9"

# SSH key for fgsrv06
declare -A HOST_KEYS
HOST_KEYS[fgsrv06]="-i ~/.ssh/fg_srv.pem"

# ============================================================
# Functions
# ============================================================

deploy_local() {
  echo ""
  echo -e "${BOLD}=============================================${NC}"
  echo -e "${BOLD}  Deploying Skills → macOS Local${NC}"
  echo -e "${BOLD}=============================================${NC}"

  local target_dir="$HOME/.qwen/skills"
  mkdir -p "$target_dir"

  local deployed=0
  local failed=0

  for skill in "${AGL_SKILLS[@]}"; do
    local src="$SKILLS_DIR/$skill"
    local dst="$target_dir/$skill"

    if [[ ! -d "$src" ]]; then
      log_warn "Skill not found: $src"
      failed=$((failed + 1))
      continue
    fi

    if [[ "$MODE" == "dry-run" ]]; then
      log_info "[DRY-RUN] Would deploy: $skill → $dst"
      deployed=$((deployed + 1))
      continue
    fi

    # Backup existing
    if [[ -d "$dst" ]]; then
      cp -r "$dst" "${dst}.backup.$TIMESTAMP"
      log_info "Backed up: $skill"
    fi

    # Deploy
    rm -rf "$dst"
    cp -r "$src" "$dst"
    log_success "Deployed: $skill → $dst"
    deployed=$((deployed + 1))
  done

  # Deploy community skills
  for skill_name in "${!COMMUNITY_SKILLS[@]}"; do
    local url="${COMMUNITY_SKILLS[$skill_name]}"
    local dst="$target_dir/$skill_name"

    if [[ "$MODE" == "dry-run" ]]; then
      log_info "[DRY-RUN] Would fetch and deploy: $skill_name from $url"
      deployed=$((deployed + 1))
      continue
    fi

    mkdir -p "$dst"
    if curl -sL -o "$dst/SKILL.md" "$url"; then
      log_success "Deployed community skill: $skill_name"
      deployed=$((deployed + 1))
    else
      log_error "Failed to fetch: $skill_name from $url"
      failed=$((failed + 1))
    fi
  done

  echo ""
  log_success "Local deploy complete: $deployed deployed, $failed failed"
  echo -e "${BLUE}  Total skills in ~/.qwen/skills/:$(ls -1 "$target_dir" | wc -l | tr -d ' ')${NC}"
}

deploy_to_host() {
  local host_name="$1"
  local host_ip="${HOST_IPS[$host_name]}"
  local ssh_opts="${HOST_KEYS[$host_name]:-}"

  echo ""
  echo -e "${BOLD}=== $host_name ($host_ip) ===${NC}"

  # Test connectivity
  if [[ "$MODE" != "dry-run" ]]; then
    if ! ssh $ssh_opts -o ConnectTimeout=5 -o BatchMode=yes "root@$host_ip" "echo 'OK'" > /dev/null 2>&1; then
      log_error "Cannot connect to $host_name ($host_ip) - skipping"
      return 0  # Return 0 so script continues with next host
    fi
  fi

  local remote_skills_dir="/root/.qwen/skills"
  local remote_repo_dir="/root/.qwen/skills/agl-hostman"

  # Create directories
  if [[ "$MODE" != "dry-run" ]]; then
    ssh $ssh_opts "root@$host_ip" "mkdir -p $remote_skills_dir $remote_repo_dir"
  else
    log_info "[DRY-RUN] Would create: $remote_skills_dir $remote_repo_dir"
  fi

  local deployed=0
  local failed=0

  # Deploy AGL skills
  for skill in "${AGL_SKILLS[@]}"; do
    local src="$SKILLS_DIR/$skill"

    if [[ ! -d "$src" ]]; then
      log_warn "Skill not found: $src"
      failed=$((failed + 1))
      continue
    fi

    if [[ "$MODE" == "dry-run" ]]; then
      log_info "[DRY-RUN] Would deploy: $skill → $remote_skills_dir/$skill"
      deployed=$((deployed + 1))
      continue
    fi

    # Backup existing
    ssh $ssh_opts "root@$host_ip" "[[ -d $remote_skills_dir/$skill ]] && cp -r $remote_skills_dir/$skill $remote_skills_dir/$skill.backup.$TIMESTAMP || true"

    # Copy skill directory
    scp -rq $ssh_opts "$src" "root@$host_ip:$remote_skills_dir/"
    if [[ $? -eq 0 ]]; then
      log_success "  Deployed: $skill"
      deployed=$((deployed + 1))
    else
      log_error "  Failed: $skill"
      failed=$((failed + 1))
    fi
  done

  # Deploy community skills
  for skill_name in "${!COMMUNITY_SKILLS[@]}"; do
    local url="${COMMUNITY_SKILLS[$skill_name]}"

    if [[ "$MODE" == "dry-run" ]]; then
      log_info "[DRY-RUN] Would fetch and deploy: $skill_name → $remote_skills_dir/$skill_name"
      deployed=$((deployed + 1))
      continue
    fi

    ssh $ssh_opts "root@$host_ip" "mkdir -p $remote_skills_dir/$skill_name && curl -sL -o $remote_skills_dir/$skill_name/SKILL.md $url"
    if [[ $? -eq 0 ]]; then
      log_success "  Deployed community: $skill_name"
      deployed=$((deployed + 1))
    else
      log_error "  Failed community: $skill_name"
      failed=$((failed + 1))
    fi
  done

  # Also copy to project skills dir on remote host
  if [[ "$MODE" != "dry-run" ]]; then
    ssh $ssh_opts "root@$host_ip" "
      if [[ -d /mnt/overpower/apps/dev/agl/agl-hostman ]]; then
        cp -r $remote_skills_dir/* /mnt/overpower/apps/dev/agl/agl-hostman/skills/ 2>/dev/null || true
        echo '  OK: Also copied to project skills dir'
      fi
    "
  fi

  echo ""
  log_success "$host_name: $deployed deployed, $failed failed"
}

verify_host() {
  local host_name="$1"
  local host_ip="${HOST_IPS[$host_name]}"
  local ssh_opts="${HOST_KEYS[$host_name]:-}"

  echo -n "  Verifying $host_name... "

  if [[ "$MODE" == "dry-run" ]]; then
    echo "[DRY-RUN - skipped]"
    return
  fi

  local count
  count=$(ssh $ssh_opts "root@$host_ip" "ls -1 /root/.qwen/skills/ 2>/dev/null | wc -l" 2>/dev/null || echo "0")

  if [[ "$count" -gt 0 ]]; then
    log_success "$count skills installed"
  else
    log_error "No skills found on $host_name"
  fi
}

# ============================================================
# Main
# ============================================================

echo ""
echo -e "${BOLD}=============================================${NC}"
echo -e "${BOLD}  AGL Agent Skills Deployment${NC}"
echo -e "${BOLD}=============================================${NC}"
echo ""
echo -e "  Mode: ${CYAN}$MODE${NC}"
echo -e "  Source: ${CYAN}$SKILLS_DIR${NC}"
echo -e "  AGL Skills: ${CYAN}${#AGL_SKILLS[@]}${NC}"
echo -e "  Community Skills: ${CYAN}${#COMMUNITY_SKILLS[@]}${NC}"
echo -e "  Remote Hosts: ${CYAN}${#HOST_IPS[@]}${NC}"
echo ""

# List skills to deploy
echo -e "${BOLD}AGL Skills to deploy:${NC}"
for skill in "${AGL_SKILLS[@]}"; do
  echo -e "  ${GREEN}●${NC} $skill"
done

echo ""
echo -e "${BOLD}Community Skills to deploy:${NC}"
for skill_name in "${!COMMUNITY_SKILLS[@]}"; do
  echo -e "  ${GREEN}●${NC} $skill_name (from GitHub)"
done

echo ""
echo -e "${BOLD}Target hosts:${NC}"
for host_name in "${!HOST_IPS[@]}"; do
  echo -e "  ${GREEN}●${NC} $host_name → ${HOST_IPS[$host_name]}"
done

if [[ "$MODE" == "dry-run" ]]; then
  echo ""
  echo -e "${YELLOW}[DRY-RUN MODE - no changes will be made]${NC}"
fi

# ============================================================
# Deploy
# ============================================================

if [[ "$MODE" == "local" || "$MODE" == "all" ]]; then
  deploy_local
fi

if [[ "$MODE" == "remote" || "$MODE" == "all" ]]; then
  for host_name in "${!HOST_IPS[@]}"; do
    deploy_to_host "$host_name"
  done
fi

# ============================================================
# Verify
# ============================================================

echo ""
echo -e "${BOLD}=============================================${NC}"
echo -e "${BOLD}  Verification${NC}"
echo -e "${BOLD}=============================================${NC}"

if [[ "$MODE" == "local" || "$MODE" == "all" ]]; then
  echo ""
  echo -e "${BOLD}macOS Local:${NC}"
  local_count=$(ls -1 "$HOME/.qwen/skills/" 2>/dev/null | wc -l | tr -d ' ')
  echo -e "  ${GREEN}Total skills: $local_count${NC}"
fi

if [[ "$MODE" == "remote" || "$MODE" == "all" ]]; then
  for host_name in "${!HOST_IPS[@]}"; do
    verify_host "$host_name"
  done
fi

echo ""
echo -e "${BOLD}=============================================${NC}"
echo -e "${GREEN}  Deployment Complete!${NC}"
echo -e "${BOLD}=============================================${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo -e "  1. On each host, restart Qwen Code / Claude Code / Cursor"
echo -e "  2. Ask: ${CYAN}'What Skills are available?'${NC}"
echo -e "  3. Test triggers: ${CYAN}'manage proxmox'${NC}, ${CYAN}'check tailscale'${NC}, etc."
echo ""
echo -e "${BLUE}Rollback:${NC}"
if [[ "$MODE" != "dry-run" ]]; then
  echo -e "  Local: ${CYAN}ls ~/.qwen/skills/*.backup.$TIMESTAMP${NC}"
  for host_name in "${!HOST_IPS[@]}"; do
    host_ip="${HOST_IPS[$host_name]}"
    ssh_opts="${HOST_KEYS[$host_name]:-}"
    echo -e "  $host_name: ${CYAN}ssh root@$host_ip \"ls /root/.qwen/skills/*.backup.$TIMESTAMP\"${NC}"
  done
fi
echo ""
