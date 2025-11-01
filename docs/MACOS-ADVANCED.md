# macOS Advanced Configuration - AI Engineer Poweruser Guide

> **For**: Advanced users who want maximum productivity
> **Last Updated**: 2025-10-29
> **Version**: 1.0.0

## 🎯 Overview

This guide covers advanced macOS configurations for power users managing AGL infrastructure:
- 🚀 Advanced terminal integration (iTerm2, Warp, etc.)
- ⚡ Keyboard shortcuts and automation (Raycast, Alfred)
- 🤖 Advanced Claude Code workflows
- 🔧 Custom tooling and scripts
- 📊 Monitoring and dashboards

## 🖥️ Terminal Enhancement

### iTerm2 Integration

**Install Profiles** for quick access:

```bash
# Create iTerm2 profile for each host
cat > ~/Library/Application\ Support/iTerm2/DynamicProfiles/agl-infrastructure.json << 'EOF'
{
  "Profiles": [
    {
      "Name": "CT179 - Development",
      "Guid": "ct179-profile",
      "Custom Command": "Yes",
      "Command": "ssh ct179",
      "Badge Text": "CT179\\nDevelopment"
    },
    {
      "Name": "CT183 - Archon",
      "Guid": "ct183-profile",
      "Custom Command": "Yes",
      "Command": "ssh ct183",
      "Badge Text": "CT183\\nArchon AI"
    },
    {
      "Name": "CT180 - Dokploy",
      "Guid": "ct180-profile",
      "Custom Command": "Yes",
      "Command": "ssh ct180",
      "Badge Text": "CT180\\nDokploy"
    }
  ]
}
EOF
```

**Features**:
- One-click host connection
- Visual badges for environment identification
- Persistent profiles
- Quick switching (⌘+Shift+O)

### Warp Terminal

**Create Workflows** (`.warp/workflows/`):

```yaml
# ~/.warp/workflows/agl-connect.yaml
name: AGL Infrastructure Connect
command: |
  echo "Select host:"
  select host in CT179 CT183 CT180 AGLSRV1 AGLSRV6; do
    case $host in
      CT179) ssh ct179; break;;
      CT183) ssh ct183; break;;
      CT180) ssh ct180; break;;
      AGLSRV1) ssh aglsrv1-ts; break;;
      AGLSRV6) ssh aglsrv6-ts; break;;
    esac
  done
tags: [agl, ssh, infrastructure]
```

### tmux Integration

**Session Management** for multi-host monitoring:

```bash
# ~/.tmux/agl-monitor.conf
new-session -s agl-monitor -n main
split-window -h
split-window -v
select-pane -t 0
send-keys "ssh ct179 'htop'" C-m
select-pane -t 1
send-keys "ssh ct183 'docker stats'" C-m
select-pane -t 2
send-keys "watch -n 5 'ssh aglsrv1-ts pct list'" C-m
```

**Launch**:
```bash
tmux source-file ~/.tmux/agl-monitor.conf
```

## ⌨️ Keyboard Shortcuts

### Raycast Integration

**Custom Scripts** (`~/Library/Application Support/Raycast/Scripts/`):

**1. Quick SSH Connect**:
```bash
#!/bin/bash
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Connect to AGL Host
# @raycast.mode compact
# @raycast.packageName AGL Infrastructure
# @raycast.icon 🖥️
# @raycast.argument1 { "type": "dropdown", "placeholder": "Host", "data": [{"title": "CT179", "value": "ct179"}, {"title": "CT183 Archon", "value": "ct183"}, {"title": "CT180 Dokploy", "value": "ct180"}] }

open "iterm2://run?command=ssh%20$1"
```

**2. Archon Health Check**:
```bash
#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Check Archon Health
# @raycast.mode inline
# @raycast.packageName AGL Infrastructure
# @raycast.icon 🤖

curl -s http://100.80.30.59:8051/health | jq -r '.status'
```

**3. Infrastructure Status**:
```bash
#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title AGL Infrastructure Status
# @raycast.mode fullOutput
# @raycast.packageName AGL Infrastructure
# @raycast.icon 📊

source /Users/admin/apps/dev/agl/agl-hostman/scripts/macos-agl-setup.sh
agl-status
```

### Alfred Workflows

**Custom Workflow** for AGL operations:

```xml
<!-- Save as: ~/Library/Application Support/Alfred/Alfred.alfredpreferences/workflows/agl-infrastructure -->
<workflow>
  <keyword>agl</keyword>
  <script>
    source /Users/admin/apps/dev/agl/agl-hostman/scripts/macos-agl-setup.sh
    case "{query}" in
      status) agl-status ;;
      ct179) open -a iTerm "ssh://ct179" ;;
      archon) archon-health ;;
      docs) agl-docs ;;
    esac
  </script>
</workflow>
```

**Usage**:
- `⌘+Space` → `agl status`
- `⌘+Space` → `agl ct179`
- `⌘+Space` → `agl archon`

### Keyboard Maestro Macros

**Quick Actions**:

```applescript
-- Macro: Check Infrastructure (⌃⌘I)
do shell script "source ~/.zshrc && agl-status"

-- Macro: Connect CT179 (⌃⌘1)
tell application "iTerm2"
  create window with default profile
  tell current session of current window
    write text "ssh ct179"
  end tell
end tell

-- Macro: Open Archon UI (⌃⌘A)
do shell script "open http://localhost:8052"
```

## 🤖 Advanced Claude Code Workflows

### Custom MCP Tool Chains

**Sequential Operations**:
```bash
# Search knowledge base → Create project → Create tasks
claude code << 'EOF'
1. Search Archon knowledge base for "Docker optimization"
2. Create project "Container Performance Tuning"
3. Create 5 tasks based on search results
4. Generate implementation plan
EOF
```

### Automated Documentation Updates

**Script**: `scripts/macos-claude-doc-update.sh`
```bash
#!/bin/bash
# Automatically update documentation using Claude Code

cd /Users/admin/apps/dev/agl/agl-hostman

# Run infrastructure check
INFRA_STATUS=$(agl-status)

# Launch Claude to update docs
claude code << EOF
@docs/INFRA.md

Update infrastructure status section with current data:
$INFRA_STATUS

Ensure all IP addresses and host statuses are accurate.
Commit changes with message: "docs: update infrastructure status $(date +%Y-%m-%d)"
EOF
```

### Context-Aware Tasks

**Smart context loading**:
```bash
# Automatically load relevant docs based on task
agl-claude-context() {
  local task="$1"

  case "$task" in
    *docker*|*container*)
      echo "@docs/INFRA.md @docs/DOKPLOY.md"
      ;;
    *archon*|*mcp*)
      echo "@docs/ARCHON.md @docs/WORKFLOWS.md"
      ;;
    *network*|*wireguard*)
      echo "@docs/INFRA.md @docs/QUICK-START.md"
      ;;
    *)
      echo "@docs/INFRA.md"
      ;;
  esac
}

# Usage
claude code "$(agl-claude-context docker) - Optimize Docker performance on CT179"
```

## 🔧 Custom Tooling

### Infrastructure Dashboard

**Script**: `scripts/macos-dashboard.sh`
```bash
#!/bin/bash
# Real-time infrastructure dashboard

watch -n 5 -c '
source /Users/admin/apps/dev/agl/agl-hostman/scripts/macos-agl-setup.sh

clear
echo "╔════════════════════════════════════════════════════════════╗"
echo "║         AGL Infrastructure Dashboard                       ║"
echo "║         $(date +"%Y-%m-%d %H:%M:%S")                              ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Host status
echo "Hosts:"
for host in "100.94.221.87:CT179" "100.80.30.59:CT183" "100.107.113.33:AGLSRV1"; do
  ip=$(echo $host | cut -d: -f1)
  name=$(echo $host | cut -d: -f2)
  if ping -c 1 -W 1 $ip &> /dev/null; then
    echo "  ✓ $name ($ip)"
  else
    echo "  ✗ $name ($ip)"
  fi
done

echo ""
echo "Docker (Local):"
if docker info &> /dev/null; then
  echo "  Containers: $(docker ps -q | wc -l)"
  echo "  Images: $(docker images -q | wc -l)"
fi

echo ""
echo "Archon MCP:"
curl -s http://100.80.30.59:8051/health | jq -r ".status" || echo "  Unreachable"
'
```

**Launch**: `./scripts/macos-dashboard.sh`

### Automated Backup Script

**Script**: `scripts/macos-auto-backup.sh`
```bash
#!/bin/bash
# Automated backup of critical configurations

BACKUP_DIR="$HOME/Backups/agl-config"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR/$TIMESTAMP"

# Backup SSH config
cp ~/.ssh/config "$BACKUP_DIR/$TIMESTAMP/ssh-config"

# Backup shell config
cp ~/.zshrc "$BACKUP_DIR/$TIMESTAMP/zshrc"

# Backup project scripts
cp -r /Users/admin/apps/dev/agl/agl-hostman/scripts "$BACKUP_DIR/$TIMESTAMP/"

# Backup Claude MCP config
if [ -f ~/.config/claude/mcp.json ]; then
  cp ~/.config/claude/mcp.json "$BACKUP_DIR/$TIMESTAMP/claude-mcp.json"
fi

# Keep only last 10 backups
ls -t "$BACKUP_DIR" | tail -n +11 | xargs -I {} rm -rf "$BACKUP_DIR/{}"

echo "✓ Backup complete: $BACKUP_DIR/$TIMESTAMP"
```

**Automate** with launchd:
```xml
<!-- ~/Library/LaunchAgents/com.agl.backup.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.agl.backup</string>
  <key>ProgramArguments</key>
  <array>
    <string>/Users/admin/apps/dev/agl/agl-hostman/scripts/macos-auto-backup.sh</string>
  </array>
  <key>StartInterval</key>
  <integer>86400</integer><!-- Daily -->
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
```

**Enable**:
```bash
launchctl load ~/Library/LaunchAgents/com.agl.backup.plist
```

### Network Monitoring

**Script**: `scripts/macos-network-monitor.sh`
```bash
#!/bin/bash
# Monitor network connectivity to all infrastructure

LOG_FILE="/tmp/agl-network-monitor.log"

while true; do
  TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

  for host in "100.94.221.87:CT179" "100.80.30.59:CT183" "100.107.113.33:AGLSRV1"; do
    ip=$(echo $host | cut -d: -f1)
    name=$(echo $host | cut -d: -f2)

    if ping -c 1 -W 2 $ip &> /dev/null; then
      echo "[$TIMESTAMP] ✓ $name ($ip) UP" >> "$LOG_FILE"
    else
      echo "[$TIMESTAMP] ✗ $name ($ip) DOWN" >> "$LOG_FILE"
      # Send notification
      osascript -e "display notification \"$name is unreachable\" with title \"AGL Infrastructure Alert\""
    fi
  done

  sleep 60
done
```

**Run in background**:
```bash
nohup ./scripts/macos-network-monitor.sh &
```

## 📊 Monitoring & Dashboards

### Grafana Setup (Optional)

**Docker Compose** for local Grafana:
```yaml
# ~/agl-monitoring/docker-compose.yml
version: '3.8'
services:
  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana-storage:/var/lib/grafana
volumes:
  grafana-storage:
```

**Data Source**: SSH metrics via Prometheus exporter

### Menu Bar Integration

**SwiftBar Script** (`~/.config/swiftbar/agl-status.1m.sh`):
```bash
#!/bin/bash
# <bitbar.title>AGL Infrastructure</bitbar.title>
# <bitbar.version>v1.0</bitbar.version>
# <bitbar.author>AGL Team</bitbar.author>
# <bitbar.desc>AGL infrastructure status in menu bar</bitbar.desc>

source /Users/admin/apps/dev/agl/agl-hostman/scripts/macos-agl-setup.sh

# Menu bar icon
echo "🖥️"
echo "---"

# Status for each host
for host in "100.94.221.87:CT179" "100.80.30.59:CT183" "100.107.113.33:AGLSRV1"; do
  ip=$(echo $host | cut -d: -f1)
  name=$(echo $host | cut -d: -f2)

  if ping -c 1 -W 1 $ip &> /dev/null; then
    echo "✓ $name | color=green bash='ssh $name' terminal=true"
  else
    echo "✗ $name | color=red"
  fi
done

echo "---"
echo "Refresh | refresh=true"
echo "Open Dashboard | bash='/Users/admin/apps/dev/agl/agl-hostman/scripts/macos-dashboard.sh' terminal=true"
```

**Install SwiftBar**: `brew install swiftbar`

## 🔐 Advanced Security

### SSH Certificate Authority

**Set up** for passwordless, key-based auth:
```bash
# Generate CA key (one-time)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/agl-ca -C "AGL Infrastructure CA"

# Sign user key
ssh-keygen -s ~/.ssh/agl-ca -I "$(whoami)-agl" -n root ~/.ssh/id_rsa.pub

# Configure servers to trust CA
# (Run on each host)
echo "TrustedUserCAKeys /etc/ssh/agl-ca.pub" | sudo tee -a /etc/ssh/sshd_config
sudo systemctl reload sshd
```

### Secrets Management

**Use 1Password CLI**:
```bash
# Install
brew install 1password-cli

# Authenticate
eval $(op signin)

# Retrieve secrets
export ARCHON_ADMIN_PASS=$(op read "op://Private/Archon Admin/password")

# Use in scripts
archon-login() {
  local pass=$(op read "op://Private/Archon Admin/password")
  curl -u admin:$pass https://archon.aglz.io/api/auth
}
```

## 🚀 Performance Optimization

### Persistent SSH Connections

**Enhanced control** in `~/.ssh/config`:
```ssh-config
Host ct* aglsrv* agldv*
  ControlMaster auto
  ControlPath ~/.ssh/controlmasters/%r@%h:%p
  ControlPersist 1h  # Keep alive for 1 hour
  ServerAliveInterval 60
  ServerAliveCountMax 10
  Compression yes
  TCPKeepAlive yes
```

### SSH Multiplexing Stats

**Monitor usage**:
```bash
agl-ssh-stats() {
  echo "Active SSH Control Masters:"
  for socket in ~/.ssh/controlmasters/*; do
    if [ -S "$socket" ]; then
      echo "  $(basename "$socket")"
      ssh -O check -S "$socket" localhost 2>&1 | grep -o "running.*"
    fi
  done
}
```

## 📚 Integration with Other Tools

### VS Code Remote-SSH

**Workspace config** (`.vscode/settings.json`):
```json
{
  "remote.SSH.configFile": "~/.ssh/config",
  "remote.SSH.defaultExtensions": [
    "ms-python.python",
    "ms-azuretools.vscode-docker"
  ],
  "remote.SSH.remotePlatform": {
    "ct179": "linux",
    "ct183": "linux",
    "ct180": "linux"
  }
}
```

**Quick connect**:
- `⌘+Shift+P` → "Remote-SSH: Connect to Host"
- Select `ct179`, `ct183`, etc.

### JetBrains Gateway

**Remote development** on infrastructure:
```bash
# Install Gateway
brew install --cask jetbrains-gateway

# Connect to CT179
# Gateway > SSH > New Connection > ct179
```

## 🎯 Productivity Workflows

### Morning Routine Script

```bash
#!/bin/bash
# ~/agl-morning.sh

echo "🌅 Good morning! Checking AGL infrastructure..."

# 1. Update repository
cd /Users/admin/apps/dev/agl/agl-hostman
git pull

# 2. Check infrastructure
agl-status

# 3. Check Archon health
archon-health

# 4. Open relevant docs
agl-docs quick

# 5. Launch monitoring dashboard
./scripts/macos-dashboard.sh &

# 6. Open tools
open -a "Google Chrome" "https://dok.aglz.io"
open -a "iTerm" "ssh://ct179"

echo "✅ Ready for development!"
```

**Add to login items** or run manually

### End of Day Cleanup

```bash
#!/bin/bash
# ~/agl-cleanup.sh

echo "🌙 End of day cleanup..."

# 1. Commit any changes
cd /Users/admin/apps/dev/agl/agl-hostman
if [[ -n $(git status -s) ]]; then
  echo "Uncommitted changes detected!"
  git status -s
fi

# 2. Backup configurations
./scripts/macos-auto-backup.sh

# 3. Kill SSH control masters
for socket in ~/.ssh/controlmasters/*; do
  if [ -S "$socket" ]; then
    ssh -O exit -S "$socket" localhost 2>/dev/null
  fi
done

# 4. Stop monitoring scripts
pkill -f "agl-network-monitor"
pkill -f "macos-dashboard"

echo "✅ Cleanup complete!"
```

## 🎓 Learning Resources

### Keyboard Shortcuts Reference

**Create quick reference**:
```bash
cat > ~/Desktop/agl-shortcuts.md << 'EOF'
# AGL Shortcuts Reference

## Terminal
- `agl-help` - Show all commands
- `agl-status` - Infrastructure status
- `agl-ct179` - Connect to CT179
- `agl-docs <name>` - View documentation

## Raycast
- `agl status` - Quick status check
- `agl ct179` - Quick connect

## iTerm2
- `⌘+Shift+O` - Open profiles
- Select "CT179 - Development"

## Keyboard Maestro
- `⌃⌘I` - Infrastructure status
- `⌃⌘1` - Connect CT179
- `⌃⌘A` - Open Archon UI
EOF
```

### Command Reference Card

**Print or save as PDF**:
```bash
agl-cheatsheet() {
  cat << 'EOF'
╔══════════════════════════════════════════════════════════╗
║           AGL Infrastructure Command Reference           ║
╠══════════════════════════════════════════════════════════╣
║ SSH                                                      ║
║   agl-ct179        Connect to CT179                     ║
║   agl-ct183        Connect to Archon                    ║
║   agl-srv1         Connect to AGLSRV1                   ║
╠══════════════════════════════════════════════════════════╣
║ Status                                                   ║
║   agl-status       Infrastructure overview              ║
║   archon-health    Archon MCP status                    ║
║   agl-env          Environment info                     ║
╠══════════════════════════════════════════════════════════╣
║ Documentation                                            ║
║   agl-docs         List all docs                        ║
║   agl-docs infra   Infrastructure guide                 ║
║   agl-find <term>  Search docs                          ║
╠══════════════════════════════════════════════════════════╣
║ Tools                                                    ║
║   agl-sync         Git sync                             ║
║   archon-ui        Open Archon web UI                   ║
║   dokploy-ui       Open Dokploy                         ║
╚══════════════════════════════════════════════════════════╝
EOF
}

# Print to terminal
agl-cheatsheet

# Save to desktop
agl-cheatsheet > ~/Desktop/agl-cheatsheet.txt
```

## 🎯 Next Level

**You're now a power user!** Continue exploring:
- Customize scripts in `scripts/macos-*.sh`
- Create your own Raycast/Alfred workflows
- Build custom monitoring dashboards
- Share improvements with the team

---

**Master Your Infrastructure! 🚀**

*The terminal is your command center.*
