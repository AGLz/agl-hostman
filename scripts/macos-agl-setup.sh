#!/bin/bash
# macOS AGL Infrastructure - Quick Access Setup
# Adds functions and aliases to your shell for improved AI engineer experience
#
# Installation:
#   1. Run this script: bash scripts/macos-agl-setup.sh
#   2. Or add to ~/.zshrc: source /Users/admin/apps/dev/agl/agl-hostman/scripts/macos-agl-setup.sh

# ============================================================================
# COLOR DEFINITIONS
# ============================================================================
export AGL_COLOR_RESET='\033[0m'
export AGL_COLOR_BOLD='\033[1m'
export AGL_COLOR_RED='\033[0;31m'
export AGL_COLOR_GREEN='\033[0;32m'
export AGL_COLOR_YELLOW='\033[0;33m'
export AGL_COLOR_BLUE='\033[0;34m'
export AGL_COLOR_MAGENTA='\033[0;35m'
export AGL_COLOR_CYAN='\033[0;36m'

# ============================================================================
# INFRASTRUCTURE QUICK ACCESS
# ============================================================================

# Quick SSH functions with automatic Tailscale fallback
agl-ct179() {
    echo -e "${AGL_COLOR_CYAN}Connecting to CT179 (agldv03) - Primary Development Container${AGL_COLOR_RESET}"
    ssh root@100.94.221.87 "$@"
}

agl-ct183() {
    echo -e "${AGL_COLOR_CYAN}Connecting to CT183 (Archon AI Command Center)${AGL_COLOR_RESET}"
    ssh root@100.80.30.59 "$@"
}

agl-ct180() {
    echo -e "${AGL_COLOR_CYAN}Connecting to CT180 (Dokploy) - https://dok.aglz.io${AGL_COLOR_RESET}"
    ssh root@100.116.218.100 "$@"
}

agl-ct108() {
    echo -e "${AGL_COLOR_CYAN}Connecting to CT108 (agldv06) - AGLSRV6 Development${AGL_COLOR_RESET}"
    ssh root@100.71.229.12 "$@"
}

agl-srv1() {
    echo -e "${AGL_COLOR_CYAN}Connecting to AGLSRV1 - Main Proxmox Host${AGL_COLOR_RESET}"
    ssh root@100.107.113.33 "$@"
}

agl-srv6() {
    echo -e "${AGL_COLOR_CYAN}Connecting to AGLSRV6 - Secondary Proxmox Host${AGL_COLOR_RESET}"
    ssh root@100.119.25.106 "$@"
}

# ============================================================================
# ARCHON MCP INTEGRATION
# ============================================================================

archon-health() {
    echo -e "${AGL_COLOR_YELLOW}Checking Archon MCP Server Health...${AGL_COLOR_RESET}"
    curl -s http://100.80.30.59:8051/health | jq '.' || echo "Archon not reachable via Tailscale"
}

archon-restart() {
    echo -e "${AGL_COLOR_YELLOW}Restarting Archon MCP Server...${AGL_COLOR_RESET}"
    ssh root@100.80.30.59 "cd /root/archon && docker-compose restart archon-mcp && docker-compose ps"
}

archon-logs() {
    echo -e "${AGL_COLOR_YELLOW}Showing Archon MCP logs (last 50 lines)...${AGL_COLOR_RESET}"
    ssh root@100.80.30.59 "docker logs archon-mcp --tail 50 -f"
}

# ============================================================================
# INFRASTRUCTURE STATUS
# ============================================================================

agl-status() {
    echo -e "${AGL_COLOR_BOLD}${AGL_COLOR_CYAN}=== AGL Infrastructure Status ===${AGL_COLOR_RESET}\n"

    # Network connectivity
    echo -e "${AGL_COLOR_YELLOW}Network Connectivity:${AGL_COLOR_RESET}"
    if command -v tailscale &> /dev/null; then
        echo "  Tailscale: $(tailscale status --self | awk '{print $1}')"
    else
        echo "  Tailscale: Not installed or not in PATH"
    fi

    # Key hosts status (with timeout)
    echo -e "\n${AGL_COLOR_YELLOW}Host Status (ping test):${AGL_COLOR_RESET}"
    for host in "100.94.221.87:CT179" "100.80.30.59:CT183-Archon" "100.107.113.33:AGLSRV1"; do
        ip=$(echo $host | cut -d: -f1)
        name=$(echo $host | cut -d: -f2)
        if ping -c 1 -W 1 $ip &> /dev/null; then
            echo -e "  ${AGL_COLOR_GREEN}✓${AGL_COLOR_RESET} $name ($ip)"
        else
            echo -e "  ${AGL_COLOR_RED}✗${AGL_COLOR_RESET} $name ($ip)"
        fi
    done

    # Claude MCP status
    echo -e "\n${AGL_COLOR_YELLOW}Claude MCP Servers:${AGL_COLOR_RESET}"
    if command -v claude &> /dev/null; then
        claude mcp list | grep -E "Connected|Disconnected" | head -10
    else
        echo "  Claude CLI not installed"
    fi

    # Docker status (local)
    echo -e "\n${AGL_COLOR_YELLOW}Local Docker:${AGL_COLOR_RESET}"
    if docker info &> /dev/null; then
        echo -e "  ${AGL_COLOR_GREEN}✓${AGL_COLOR_RESET} Docker running ($(docker ps -q | wc -l | xargs) containers)"
    else
        echo -e "  ${AGL_COLOR_RED}✗${AGL_COLOR_RESET} Docker not running"
    fi
}

# ============================================================================
# DOCUMENTATION QUICK ACCESS
# ============================================================================

agl-docs() {
    local doc=$1
    local base="/Users/admin/apps/dev/agl/agl-hostman/docs"

    if [ -z "$doc" ]; then
        echo -e "${AGL_COLOR_CYAN}Available Documentation:${AGL_COLOR_RESET}"
        echo "  agl-docs infra      - Infrastructure map and network topology"
        echo "  agl-docs archon     - Archon MCP integration guide"
        echo "  agl-docs workflows  - SPARC methodology and Agent OS"
        echo "  agl-docs rules      - Coding standards and best practices"
        echo "  agl-docs quick      - Quick reference and troubleshooting"
        echo "  agl-docs dokploy    - Deployment platform guide"
        return 0
    fi

    case "$doc" in
        infra|INFRA)
            cat "$base/INFRA.md" | less -R
            ;;
        archon|ARCHON)
            cat "$base/ARCHON.md" | less -R
            ;;
        workflows|WORKFLOWS)
            cat "$base/WORKFLOWS.md" | less -R
            ;;
        rules|RULES)
            cat "$base/RULES.md" | less -R
            ;;
        quick|QUICK)
            cat "$base/QUICK-START.md" | less -R
            ;;
        dokploy|DOKPLOY)
            cat "$base/DOKPLOY.md" | less -R
            ;;
        *)
            echo -e "${AGL_COLOR_RED}Unknown documentation: $doc${AGL_COLOR_RESET}"
            agl-docs
            ;;
    esac
}

# Quick doc search
agl-find() {
    local query=$1
    if [ -z "$query" ]; then
        echo "Usage: agl-find <search-term>"
        return 1
    fi

    echo -e "${AGL_COLOR_CYAN}Searching AGL documentation for: ${AGL_COLOR_YELLOW}$query${AGL_COLOR_RESET}\n"
    grep -r -n -i --color=always "$query" /Users/admin/apps/dev/agl/agl-hostman/docs/ | head -20
}

# ============================================================================
# DEVELOPMENT HELPERS
# ============================================================================

# Quick context loading for Claude
agl-context() {
    echo -e "${AGL_COLOR_CYAN}Loading AGL context for Claude Code...${AGL_COLOR_RESET}"
    cat << 'EOF'
@docs/INFRA.md - Infrastructure map, hosts, containers, network topology
@docs/ARCHON.md - Archon MCP tools, task management, knowledge base
@docs/WORKFLOWS.md - Agent OS, SPARC methodology, available agents
@docs/RULES.md - Coding standards, execution patterns, best practices
@docs/QUICK-START.md - Quick reference, commands, troubleshooting
@docs/DOKPLOY.md - Deployment platform and CI/CD workflows

Use: Load these in Claude Code with @docs/filename.md syntax
EOF
}

# Environment detection
agl-env() {
    echo -e "${AGL_COLOR_CYAN}Current Environment:${AGL_COLOR_RESET}"
    echo "  Platform: macOS $(sw_vers -productVersion)"
    echo "  Shell: $SHELL"
    echo "  Working Dir: $(pwd)"
    echo "  User: $USER"

    if command -v docker &> /dev/null; then
        echo "  Docker: $(docker --version | head -1)"
    fi

    if command -v tailscale &> /dev/null; then
        echo "  Tailscale: $(tailscale version | head -1)"
    fi

    if command -v claude &> /dev/null; then
        echo "  Claude CLI: $(claude --version 2>&1 | head -1)"
    fi
}

# ============================================================================
# PROJECT NAVIGATION
# ============================================================================

alias agl='cd /Users/admin/apps/dev/agl/agl-hostman'
alias agl-hostman='cd /Users/admin/apps/dev/agl/agl-hostman'
alias agl-scripts='cd /Users/admin/apps/dev/agl/agl-hostman/scripts'

# ============================================================================
# GIT HELPERS
# ============================================================================

agl-sync() {
    echo -e "${AGL_COLOR_CYAN}Syncing agl-hostman repository...${AGL_COLOR_RESET}"
    cd /Users/admin/apps/dev/agl/agl-hostman
    git fetch origin
    git status
    echo -e "\n${AGL_COLOR_YELLOW}To pull changes: git pull origin $(git branch --show-current)${AGL_COLOR_RESET}"
}

# ============================================================================
# DOCKER HELPERS
# ============================================================================

agl-docker() {
    echo -e "${AGL_COLOR_CYAN}Docker Quick Actions:${AGL_COLOR_RESET}"
    echo "  agl-docker-clean   - Remove stopped containers and dangling images"
    echo "  agl-docker-stats   - Show container resource usage"
}

agl-docker-clean() {
    echo -e "${AGL_COLOR_YELLOW}Cleaning Docker...${AGL_COLOR_RESET}"
    docker container prune -f
    docker image prune -f
    echo -e "${AGL_COLOR_GREEN}✓ Cleanup complete${AGL_COLOR_RESET}"
}

agl-docker-stats() {
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
}

# ============================================================================
# CLAUDE CODE OPTIMIZATION
# ============================================================================

agl-claude-setup() {
    echo -e "${AGL_COLOR_CYAN}Setting up Claude Code MCP servers...${AGL_COLOR_RESET}\n"

    echo -e "${AGL_COLOR_YELLOW}Adding Archon MCP Server (Tailscale)...${AGL_COLOR_RESET}"
    claude mcp add --transport http archon-tailscale http://100.80.30.59:8051/mcp

    echo -e "\n${AGL_COLOR_YELLOW}Verifying MCP connections...${AGL_COLOR_RESET}"
    claude mcp list

    echo -e "\n${AGL_COLOR_GREEN}✓ Setup complete!${AGL_COLOR_RESET}"
    echo -e "Test Archon: ${AGL_COLOR_CYAN}archon-health${AGL_COLOR_RESET}"
}

# ============================================================================
# HELP
# ============================================================================

agl-help() {
    cat << EOF
${AGL_COLOR_BOLD}${AGL_COLOR_CYAN}AGL Infrastructure - macOS Quick Access Commands${AGL_COLOR_RESET}

${AGL_COLOR_YELLOW}SSH Quick Access:${AGL_COLOR_RESET}
  agl-ct179          - Connect to CT179 (Primary Development)
  agl-ct183          - Connect to CT183 (Archon AI)
  agl-ct180          - Connect to CT180 (Dokploy)
  agl-ct108          - Connect to CT108 (AGLSRV6 Dev)
  agl-srv1           - Connect to AGLSRV1 (Main Proxmox)
  agl-srv6           - Connect to AGLSRV6 (Secondary Proxmox)

${AGL_COLOR_YELLOW}Archon Integration:${AGL_COLOR_RESET}
  archon-health      - Check Archon MCP server health
  archon-restart     - Restart Archon MCP container
  archon-logs        - View Archon MCP logs (live tail)

${AGL_COLOR_YELLOW}Infrastructure Status:${AGL_COLOR_RESET}
  agl-status         - Show complete infrastructure status
  agl-env            - Display current environment info

${AGL_COLOR_YELLOW}Documentation:${AGL_COLOR_RESET}
  agl-docs           - List available documentation
  agl-docs infra     - View infrastructure documentation
  agl-docs archon    - View Archon integration guide
  agl-docs workflows - View SPARC and Agent OS workflows
  agl-find <term>    - Search documentation

${AGL_COLOR_YELLOW}Development:${AGL_COLOR_RESET}
  agl-context        - Show Claude Code context loading syntax
  agl-sync           - Sync Git repository
  agl                - Jump to agl-hostman directory

${AGL_COLOR_YELLOW}Claude Code:${AGL_COLOR_RESET}
  agl-claude-setup   - Configure Claude MCP servers

${AGL_COLOR_YELLOW}Docker:${AGL_COLOR_RESET}
  agl-docker-clean   - Clean stopped containers and images
  agl-docker-stats   - Show container resource usage

${AGL_COLOR_CYAN}Run 'agl-help' anytime to see this menu${AGL_COLOR_RESET}
EOF
}

# ============================================================================
# INITIALIZATION MESSAGE
# ============================================================================

echo -e "${AGL_COLOR_GREEN}✓ AGL Infrastructure tools loaded!${AGL_COLOR_RESET}"
echo -e "  Run ${AGL_COLOR_CYAN}agl-help${AGL_COLOR_RESET} to see available commands"
echo -e "  Run ${AGL_COLOR_CYAN}agl-status${AGL_COLOR_RESET} to check infrastructure"
