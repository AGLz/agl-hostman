# OpenClaw Migration Plan - Clawdbot → OpenClaw

> **Created**: 2026-01-30
> **Status**: In Progress
> **Reference**: Complete migration from legacy Clawdbot to OpenClaw/Moltbot

---

## Background

**Clawdbot was renamed to OpenClaw/Moltbot** in early 2026. It's the same project with a new name and improved architecture.

**Official Resources**:
- GitHub: https://github.com/clawdbot/clawdbot
- Docs: https://docs.molt.bot
- Install Script: `curl -fsSL https://openclaw.bot/install.sh | bash`

---

## Current Status

### Hosts Inventory

| Host | Type | OS | OpenClaw | Clawdbot Legacy | Status |
|------|------|-----|----------|-----------------|--------|
| **agldv03** (CT179) | LXC Container | Debian 12 | 2026.1.29 | v2026.1.24-3 (dead) | Needs cleanup |
| **fgsrv6** | Proxmox Host | Debian | Not installed | None | Needs install |
| **aglwk45** (VM104) | VM | Windows 11 | Unknown | Unknown | Needs check |

---

## Detailed Analysis

### 1. CT179 (agldv03) - 10.6.0.19 / 100.94.221.87

**Status**: ✅ OpenClaw 2026.1.29 installed and functional

**OpenClaw Status**:
```
Dashboard: http://127.0.0.1:18789/
Gateway: local · ws://127.0.0.1:18789 (reachable 23ms)
Gateway service: systemd installed · enabled · running
Agents: 1 · sessions 1 · glm-4.7 (205k ctx)
Telegram: ON (@Jarvis3b3Bot)
```

**Completed Actions**:
- [x] Ran `openclaw doctor --fix` to apply migrations
- [x] Removed legacy clawdbot-gateway.service
- [x] Verified gateway service running correctly

**Remaining**:
- [ ] Optional: Update auth profiles to use setup-token
- [ ] Optional: Configure trusted proxies for reverse proxy

### 2. FGSRV6 - 10.6.0.5 / 100.83.51.9

**Status**: ✅ OpenClaw 2026.1.29 installed and functional

**OpenClaw Status**:
```
Dashboard: http://127.0.0.1:18789/
Gateway: local · ws://127.0.0.1:18789 (reachable 34ms)
Gateway service: systemd not installed (manual mode)
Agents: 1 · sessions 1 · auto (200k ctx)
Telegram: ON (@JarvisSrv6Bot)
Tailscale: fgsrv06.degu-chromatic.ts.net
```

**Completed Actions**:
- [x] Installed OpenClaw via official script (curl install.sh)
- [x] Migrated legacy clawdbot config automatically
- [x] Telegram channel configured

**Remaining**:
- [ ] Optional: Install gateway service (openclaw gateway --daemon-install)
- [ ] Optional: Configure security settings (sandbox mode for small models)

### 3. aglwk45 (VM104) - 192.168.0.33 / 100.117.146.21

**Status**: Windows 11 VM - SSH not accessible (use RDP)

**System Info**:
- OS: Windows 11
- RAM: 16GB
- Disk: 720GB
- Tailscale: Installed (100.117.146.21)
- Guest Agent: Working

**Required Actions**:
- [ ] Manual check via RDP for Clawdbot/OpenClaw
- [ ] Install OpenClaw if not present
- [ ] Configure as Windows workstation node

---

## Migration Procedure

### Phase 1: CT179 Cleanup (agldv03)

**Steps**:
```bash
# 1. Run OpenClaw doctor with fixes
ssh root@100.94.221.87
openclaw doctor --fix

# 2. Remove legacy clawdbot service
systemctl --user disable --now clawdbot-gateway.service
rm ~/.config/systemd/user/clawdbot-gateway.service

# 3. Verify status
openclaw status
openclaw doctor

# 4. Update auth profiles (if needed)
openclaw models auth setup-token
```

### Phase 2: FGSRV6 Installation

**Steps**:
```bash
# 1. SSH to FGSRV6
ssh root@100.83.51.9

# 2. Install OpenClaw via official script
curl -fsSL https://openclaw.bot/install.sh | bash

# 3. Or install via npm
npm install -g openclaw@latest

# 4. Run setup
openclaw onboard

# 5. Configure gateway
openclaw gateway --port 18790 --daemon-install
```

### Phase 3: aglwk45 Check (Windows)

**Steps**:
```powershell
# Via RDP (192.168.0.33 or 100.117.146.21)

# 1. Check for existing installation
winget list clawdbot
winget list openclaw

# 2. Install if not present
winget install openclaw

# 3. Or use npm
npm install -g openclaw@latest

# 4. Run setup
openclaw onboard
```

---

## Post-Migration Verification

For each host, verify:

1. **OpenClaw Status**:
   ```bash
   openclaw status
   ```

2. **Gateway Service**:
   ```bash
   systemctl status openclaw-gateway.service  # Linux
   ```

3. **Channels**:
   ```bash
   openclaw status --deep
   ```

4. **Doctor Check**:
   ```bash
   openclaw doctor
   ```

---

## Architecture Notes

### Multi-Gateway Setup

OpenClaw supports multiple gateways on the same host (isolated ports + config).

For mesh setup:
- **CT179**: Primary gateway (port 18789)
- **FGSRV6**: Secondary gateway (port 18790)
- **aglwk45**: Workstation gateway (port 18791)

### Channel Configuration

Common channels:
- Telegram (recommended, already configured on CT179)
- WhatsApp (requires phone)
- Discord (requires bot token)
- Slack (requires workspace)

---

## Troubleshooting

### Common Issues

**Issue**: Gateway service PATH not set
```bash
# Fix: Reinstall service
openclaw gateway --daemon-install --force
```

**Issue**: Auth profiles deprecated
```bash
# Fix: Use setup-token
openclaw models auth setup-token
```

**Issue**: Legacy service conflicts
```bash
# Fix: Remove legacy services
systemctl --user disable --now clawdbot-gateway.service
rm ~/.config/systemd/user/clawdbot-gateway.service
```

### Useful Commands

```bash
# Check logs
openclaw logs --follow

# Security audit
openclaw security audit --deep

# Update
openclaw update

# Health check
openclaw health
```

---

## Progress Tracking

| Phase | Status | Date | Notes |
|-------|--------|------|-------|
| Phase 1: CT179 cleanup | ✅ Complete | 2026-01-30 | Legacy clawdbot service removed |
| Phase 2: FGSRV6 install | ✅ Complete | 2026-01-30 | OpenClaw 2026.1.29 installed |
| Phase 3: aglwk45 check | ⚠️ Pending | - | Needs manual Windows RDP access |
| Verification | ✅ Complete | 2026-01-30 | CT179 & FGSRV6 verified working |

---

## Summary

### ✅ Completed (2026-01-30)

**CT179 (agldv03)**:
- ✅ OpenClaw 2026.1.29 operational
- ✅ Legacy clawdbot service removed
- ✅ Telegram channel working (@Jarvis3b3Bot)
- ✅ GLM-4.7 (zai/glm-4.7) configured as primary model
- ✅ ZAI API key configured (896fb1e6...fajAslfx)
- ✅ Gateway service running (port 18789)

**FGSRV6**:
- ✅ OpenClaw 2026.1.29 installed
- ✅ Legacy clawdbot config migrated
- ✅ Telegram channel working (@JarvisSrv6Bot)
- ✅ GLM-4.7 (zai/glm-4.7) configured as primary model
- ✅ ZAI API key configured (896fb1e6...fajAslfx)
- ✅ Gateway service installed and active (systemd)

**aglwk45 (VM104)** - Windows 11:
- ✅ clawdbot@2026.1.24-3 installed (via npm global)
- ⚠️ ZAI API key needs manual configuration (guest-exec timeout issues)
- ⚠️ OpenClaw installation issues (module resolution problems)
- ⚠️ Requires manual RDP access for complete setup
- ✅ Tailscale reachable (100.117.146.21)

### ZAI API Key Configuration

**Key**: `896fb1e6936a4cd1b61aa2314d6d3728.u2lsAqLNfajAslfx`

**Status**:
| Host | ZAI Key Status |
|------|----------------|
| agldv03 (CT179) | ✅ Configured |
| fgsrv6 | ✅ Configured |
| aglwk45 (VM104) | ⚠️ Pending (manual RDP needed) |

**To configure manually on aglwk45 via RDP**:
1. Connect to 192.168.0.33 or 100.117.146.21
2. Edit: `C:\windows\system32\config\systemprofile\.clawdbot\agents\main\agent\auth-profiles.json`
3. Add/Update:
```json
{
  "profiles": {
    "zai:default": {
      "type": "api_key",
      "provider": "zai",
      "key": "896fb1e6936a4cd1b61aa2314d6d3728.u2lsAqLNfajAslfx"
    }
  }
}
```

### Next Steps for aglwk45 (2026-01-30 Updated)

**Method 1: Automated Script (Recommended)**
1. Connect via RDP to 192.168.0.33 or Tailscale 100.117.146.21
2. Download and run the setup script:
   ```powershell
   # Copy script from: /mnt/overpower/apps/dev/agl/agl-hostman/scripts/aglwk45-openclaw-setup.ps1
   # Or run:
   Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
   .\aglwk45-openclaw-setup.ps1
   ```

**Method 2: Manual Steps**
1. Connect via RDP
2. Open PowerShell as Administrator
3. Run:
   ```powershell
   # Uninstall old versions
   npm uninstall -g clawdbot
   npm uninstall -g openclaw

   # Install latest OpenClaw
   npm install -g openclaw@latest

   # Run setup
   openclaw onboard --install-daemon
   openclaw doctor --fix
   ```

---

## Migration Command Reference

### Check OpenClaw Status
```bash
openclaw status
openclaw --version
```

### Run Doctor (Fix & Migrate)
```bash
openclaw doctor --fix
```

### Remove Legacy Service
```bash
systemctl --user disable --now clawdbot-gateway.service
rm ~/.config/systemd/user/clawdbot-gateway.service
```

### Install on New Host
```bash
# Linux/macOS
curl -fsSL https://openclaw.bot/install.sh | bash

# OR via npm
npm install -g openclaw@latest

# Run onboarding
openclaw onboard
```

### Windows Installation
```powershell
# Via winget
winget install openclaw

# OR via npm
npm install -g openclaw@latest

# Run onboarding
openclaw onboard
```

---

## Architecture Summary

| Host | OpenClaw Ver | Gateway | Telegram | GLM-4.7 | Tailscale | Status |
|------|-------------|---------|----------|---------|-----------|--------|
| agldv03 (CT179) | 2026.1.29 | 18789 (systemd) | @Jarvis3b3Bot | ✅ Primary | 100.94.221.87 | ✅ Active |
| fgsrv6 | 2026.1.29 | 18789 (systemd) | @JarvisSrv6Bot | ✅ Primary | 100.83.51.9 | ✅ Active |
| aglwk45 (VM104) | clawdbot 2026.1.24-3 | N/A | TBD | ⚠️ Pending | 100.117.146.21 | ⚠️ Manual needed |

---

**Document Version**: 1.2.0 (Migration Complete - CT179 & FGSRV6 with GLM-4.7)
**Last Updated**: 2026-01-30
**Maintainer**: Claude Code (agl-hostman project)

**Migration Completed**: 2/3 hosts fully configured (67%)
- ✅ CT179: OpenClaw 2026.1.29 + GLM-4.7 primary
- ✅ FGSRV6: OpenClaw 2026.1.29 + GLM-4.7 primary
- ⚠️ aglwk45: clawdbot 2026.1.24-3 (Windows - needs manual RDP setup)

**Manual Action Required**: aglwk45 (Windows 11) - RDP access needed to complete OpenClaw setup and GLM-4.7 configuration
