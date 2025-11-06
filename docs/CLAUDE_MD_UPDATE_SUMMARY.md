# CLAUDE.md Update Summary - Multi-Environment Support

**Date**: 2025-10-21
**Updated By**: Claude Code
**File**: `/root/agl-hostman/CLAUDE.md`

## Overview

Updated CLAUDE.md to provide comprehensive guidance for working with the `agl-hostman` project from multiple development environments, clarifying connection methods and tooling requirements for each scenario.

## Key Changes

### 1. Project Context Section (Lines 3-47)

**Added**:
- Clear definition of 3 primary development environments
- Detailed network capabilities for each environment
- Environment detection script
- Limitations and best practices per environment

**Environments Documented**:

1. **AGLHQ11 (WSL2)**:
   - Tailscale-only connectivity
   - Remote work profile
   - Windows kernel limitations (no WireGuard)

2. **CT179 (agldv03)**:
   - Triple network stack (LAN + WireGuard + Tailscale)
   - Full development capabilities
   - 48GB RAM, Docker support

3. **CT108 (agldv06)**:
   - Tailscale-only connectivity
   - AGLSRV6 local operations

### 2. Tooling Requirements Section (Lines 49-231)

**Added**:
- Environment-specific tool availability matrix
- Network capability checklist per environment
- Recommended setup commands
- Typical workflow examples

**WSL2 Profile**:
- ✅ ssh, git, curl
- ⚠️ Tailscale (via Windows)
- ❌ WireGuard, pct, direct LAN

**CT179 Profile**:
- ✅ Full stack: ssh, git, tailscale, wg-quick, docker, pct (via host)
- ✅ All networks: LAN, WireGuard, Tailscale

**CT108 Profile**:
- ✅ ssh, git, tailscale
- ❌ WireGuard (not configured)

### 3. Connection Matrix Section (Lines 715-839)

**Replaced**: Generic connection priority with environment-specific guidance

**Structure**:
- From WSL2: Tailscale-only commands and examples
- From CT179: Triple-stack priority (WireGuard > LAN > Tailscale)
- From CT108: Tailscale-only with Proxmox fallback
- Universal connection table showing routes from each environment

**Key Features**:
- Connection priority numbered by performance
- Practical command examples for each scenario
- Clear "Cannot Use" statements for unavailable methods
- Performance notes (latency, direct vs. tunneled)

### 4. Quick Reference Section (Lines 179-231)

**Added**:
- Command routing patterns by task type
- Infrastructure status checking commands
- NFS storage access methods
- Docker command execution patterns

**Categories**:
- Check infrastructure status
- Access NFS storage
- Run Docker commands
- Each with WSL2 vs CT179 variants

## Environment Comparison Table

| Feature | WSL2 (AGLHQ11) | CT179 (agldv03) | CT108 (agldv06) |
|---------|----------------|-----------------|-----------------|
| **Networks** | Tailscale | LAN + WG + TS | Tailscale |
| **WireGuard** | ❌ | ✅ 10.6.0.19 | ❌ |
| **Local LAN** | ❌ | ✅ 192.168.0.x | ⚠️ Limited |
| **Docker** | Remote only | ✅ Native | ⚠️ Unknown |
| **Proxmox** | Remote only | ✅ Via host | Remote only |
| **Best For** | Remote work | Full dev | AGLSRV6 ops |

## Usage Patterns

### From WSL2 (Current)
```bash
# All operations via Tailscale
ssh root@100.94.221.87  # CT179
ssh root@100.107.113.33  # AGLSRV1 host
ssh root@100.98.108.66  # AGLSRV6 host

# Remote Docker
ssh root@100.94.221.87 'docker ps'

# Jump connections for LAN-only hosts
ssh -J root@100.107.113.33 root@192.168.0.202
```

### From CT179 (High Performance)
```bash
# WireGuard preferred (fastest)
ssh root@10.6.0.12  # AGLSRV6
ssh root@10.6.0.5   # FGSRV6

# LAN direct (zero latency)
ssh root@192.168.0.202  # n8n
ssh root@192.168.0.200  # ollama-gpu

# Native Docker
docker ps
docker compose up -d

# Direct storage access
ls /mnt/pve/fgsrv6-wg
```

## Benefits of This Update

1. **Context-Aware**: Claude Code now knows which commands work in which environment
2. **Clear Limitations**: Explicit statement of what's not available (WireGuard in WSL2)
3. **Performance Guidance**: Best connection methods highlighted per scenario
4. **Practical Examples**: Real commands for real tasks in each environment
5. **Quick Reference**: Fast lookup for common operations

## Preserved Information

✅ All 13 WireGuard nodes documented
✅ All 68 AGLSRV1 VMs/CTs preserved
✅ All host aliases and IPs intact
✅ Storage configuration complete (6.0 TB WireGuard storage)
✅ Migration history maintained
✅ WireGuard configuration standards preserved

## Files Modified

- `/root/agl-hostman/CLAUDE.md` (930 lines → 1000+ lines)
  - Added: Project Context (44 lines)
  - Added: Tooling Requirements (182 lines)
  - Replaced: Connection Priority (125 lines)
  - Added: Quick Reference (52 lines)

## Verification Commands

```bash
# Verify environment
if grep -q microsoft /proc/version; then
    echo "✅ Running on WSL2"
    echo "📡 Available: Tailscale only"
    echo "❌ Not available: WireGuard, local LAN"
fi

# Check network interfaces
ip addr show | grep -E "eth0|wsl|tailscale|wg"

# Test connectivity
ping -c 2 100.94.221.87  # CT179 via Tailscale (should work from WSL2)
```

## Next Steps

1. ✅ Documentation updated
2. ⏳ Test commands from each environment
3. ⏳ Update scripts to detect environment automatically
4. ⏳ Create environment-specific aliases in `.bashrc`

## Related Documentation

- `/root/agl-hostman/CLAUDE.md` - Main configuration (updated)
- `/root/agl-hostman/docs/` - Infrastructure docs (unchanged)
- `/root/.claude/CLAUDE.md` - SuperClaude Framework (global, unchanged)

---

**Summary**: CLAUDE.md now provides complete guidance for working from WSL2 (AGLHQ11), CT179 (agldv03), and CT108 (agldv06), with clear connection methods, tooling requirements, and practical examples for each environment.
