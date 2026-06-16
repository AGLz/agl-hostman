---
name: ruflo-agl
description: >
  Manage Ruflo and Claude-Flow v3 orchestration on AGL infrastructure. Use when working with
  Claude-Flow v3 multi-agent swarms, Ruflo platform configuration, agent coordination,
  spec-driven development, or deploying orchestration tasks across AGL hosts (agldv03/04/05/12/fgsrv06).
  Covers config sync, IS_SANDBOX deployment, ZSHRC patching, and swarm topology management.
---

# Ruflo & Claude-Flow v3 — AGL Infrastructure

## Overview

Ruflo is the open-source orchestration platform for Claude Code running on AGL infrastructure.
Claude-Flow v3 provides hierarchical multi-agent swarm orchestration.

## Hosts Running Ruflo/Claude-Flow

| Host    | Tailscale IP   | Role                     |
| ------- | -------------- | ------------------------ |
| agldv03 | 100.94.221.87  | Main orchestration host  |
| agldv04 | 100.113.9.98   | Secondary orchestration  |
| agldv05 | 100.82.71.49   | Remote orchestration     |
| agldv12 | 100.71.217.115 | Turbo Flow orchestration |
| fgsrv06 | 100.83.51.9    | VPS orchestration        |

## Configuration Files

```bash
# Claude-Flow v3 config (on each host)
/root/claude-flow-v3-config.zsh

# Claude settings
/root/.claude/settings.json       # Main settings
/root/.claude/plugins.json        # Plugin config
/root/.claude/helpers/            # Helper scripts
/root/.claude/statusline-command.sh  # Status line display

# Ruflo config
/opt/agl-hostman/config/ruflo/    # Ruflo configuration
```

## Sync Operations

### Sync config to all hosts

```bash
# From macOS or agldv03
./scripts/ruflo/sync-config-all-hosts.sh

# Sync to specific hosts
./scripts/ruflo/sync-config-all-hosts.sh agldv04 fgsrv06
```

### Sync .zshrc from agldv03

```bash
# Run ON agldv03 (CT179)
./scripts/sync-zshrc-from-agldv03.sh

# Or run from macOS via SSH
ssh root@100.94.221.87 "/mnt/overpower/apps/dev/agl/agl-hostman/scripts/sync-zshrc-from-agldv03.sh"
```

### Deploy IS_SANDBOX flag

```bash
./scripts/ruflo/deploy-is-sandbox-all-hosts.sh
```

### Patch ZSHRC on all hosts

```bash
./scripts/ruflo/patch-zshrc-all-hosts.sh
```

## Claude-Flow v3 Swarm Topology

```
                    ┌─────────────────┐
                    │   V3 Queen      │
                    │  (Coordinator)  │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
        ┌─────┴─────┐  ┌────┴────┐  ┌─────┴─────┐
        │ Researcher│  │ Coder   │  │ Reviewer  │
        └───────────┘  └─────────┘  └───────────┘
```

### Agent Roles

| Role       | Responsibility                 |
| ---------- | ------------------------------ |
| Queen      | Hierarchical mesh coordination |
| Researcher | Scope, requirements, context   |
| Architect  | Design, boundaries, patterns   |
| Coder      | Implementation                 |
| Tester     | Tests, regressions, validation |
| Reviewer   | Quality, risk, security        |

## Common Operations

### Check Ruflo status on all hosts

```bash
for host in 100.94.221.87 100.113.9.98 100.82.71.49 100.71.217.115 100.83.51.9; do
  echo "=== $host ==="
  ssh root@$host "cf --version 2>/dev/null || echo 'not installed'"
done
```

### Check Claude-Flow version

```bash
ssh root@100.94.221.87 "grep CLAUDE_FLOW_VERSION= /root/claude-flow-v3-config.zsh"
```

### Restart Ruflo services

```bash
# On each host
ssh root@<ip> "systemctl --user daemon-reload && systemctl --user restart ruflo 2>/dev/null || echo 'no systemd service'"
```

### Check LiteLLM connectivity (Ruflo dependency)

```bash
# agldv03, agldv04, agldv12 have local LiteLLM
ssh root@100.94.221.87 "curl -s http://localhost:4000/health"

# agldv05, agldv06 use remote LiteLLM on agldv03
ssh root@100.82.71.49 "curl -s http://100.94.221.87:4000/health"
```

## Environment Variables

```bash
# Set in claude-flow-v3-config.zsh
CLAUDE_FLOW_VERSION="v3"
ANTHROPIC_BASE_URL="http://localhost:4000"  # LiteLLM proxy
# Or for remote hosts:
ANTHROPIC_BASE_URL="http://100.94.221.87:4000"  # agldv03 gateway
```

## Troubleshooting

### Ruflo not responding

```bash
# 1. Check LiteLLM connectivity
curl -s http://localhost:4000/health

# 2. Check Claude-Flow config
cat /root/claude-flow-v3-config.zsh

# 3. Check Claude settings
cat /root/.claude/settings.json | jq '.apiKeyHelper, .apiBaseUrl'
```

### Config out of sync

```bash
# Re-sync from source
./scripts/ruflo/sync-config-all-hosts.sh

# Verify on each host
ssh root@<ip> "cat /root/claude-flow-v3-config.zsh | head -5"
```

### IS_SANDBOX issues

```bash
# Check sandbox flag
ssh root@<ip> "grep IS_SANDBOX /root/.openclaw/zshrc-openclaw.env"

# Re-deploy
./scripts/ruflo/deploy-is-sandbox-all-hosts.sh
```

## References

- `docs/CLAUDE-FLOW-CONFIG.md` — Configuration details
- `scripts/ruflo/` — All Ruflo deployment and sync scripts
- `config/ruflo/` — Ruflo configuration files
- https://github.com/ruvnet/claude-flow — Claude Flow repository
