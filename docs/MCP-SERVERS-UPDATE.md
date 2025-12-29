# MCP Servers - Update & Additional Discoveries

> **Date**: 2025-12-17
> **Update to**: MCP-SERVERS-ANALYSIS.md
> **Status**: 5 Additional Servers Discovered

---

## 🔍 Summary of Findings

Durante a análise do ambiente, foram descobertos **5 servidores MCP adicionais** que não estavam documentados nos arquivos de configuração local (`.mcp.json` e `.cursor/mcp.json`). Estes servidores estão configurados globalmente via comando `claude mcp add`.

### Status Overview

**Total MCP Servers**: 12 servidores
- **Documentados** (7): dokploy, flow-nexus, agentic-payments, claude-flow, laravel-boost, shadcn, playwright, archon
- **Descobertos** (5): docker, harbor, proxmox, portainer, cloudflare-dns

### Connection Status (from `claude mcp list`)

| Server | Status | Transport | Location |
|--------|--------|-----------|----------|
| ✅ dokploy | Connected | stdio | NPX package |
| ✅ flow-nexus | Connected | stdio | NPX package |
| ✅ agentic-payments | Connected | stdio | NPX package |
| ❌ claude-flow | **Failed** | stdio | NPX package |
| ✅ archon | Connected | HTTP | CT183 (port 8052) |
| ❌ archon-tailscale | Failed | HTTP | Tailscale endpoint |
| ✅ docker | Connected | stdio | NPX package |
| ✅ harbor | Connected | stdio | NPX package |
| ✅ proxmox | Connected | stdio | Custom wrapper script |
| ✅ portainer | Connected | stdio | Custom binary |
| ✅ cloudflare-dns | Connected | stdio | NPX package |
| ❌ exa | Failed | stdio | NPX package |

**Success Rate**: 9/12 servidores (75%)

---

## 📦 Additional Servers Discovered

### 1. **Docker MCP Server**

**Package**: `docker-mcp` (via NPX)
**Status**: ✅ Connected
**Type**: stdio
**Command**: `npx -y docker-mcp`

#### Overview
MCP server for Docker container management, providing AI assistants with tools to manage containers, images, networks, and volumes.

#### Expected Features
- Container lifecycle management (create, start, stop, restart, remove)
- Image operations (pull, build, tag, push)
- Network management
- Volume management
- Docker Compose operations
- Container logs and monitoring

#### Configuration (Inferred)
```json
{
  "docker": {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "docker-mcp"]
  }
}
```

#### Documentation
**Research Needed**: Check NPM package `docker-mcp` or GitHub repository

#### Integration Notes
- **Available MCP Tools** (from current session):
  - `docker_container_list`: List all containers
  - `docker_container_inspect`: Get container details
  - `docker_container_start/stop/restart`: Lifecycle management
  - `docker_container_logs`: Retrieve container logs
  - `docker_system_info`: Docker system information
  - `docker_system_version`: Docker version info

---

### 2. **Harbor MCP Server**

**Package**: `mcp-harbor` (via NPX)
**Status**: ✅ Connected
**Type**: stdio
**Command**: `npx -y mcp-harbor`

#### Overview
MCP server for Harbor container registry management, enabling AI-assisted operations on Harbor projects, repositories, and Helm charts.

#### Expected Features
- Project management (list, create, delete)
- Repository operations (list, delete)
- Tag management (list, delete)
- Helm chart management
- Repository scanning and vulnerabilities
- Replication management

#### Configuration (Inferred)
```json
{
  "harbor": {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "mcp-harbor"],
    "env": {
      "HARBOR_URL": "https://harbor.aglz.io:5000",
      "HARBOR_USERNAME": "admin",
      "HARBOR_PASSWORD": "..."
    }
  }
}
```

#### Documentation
**Research Needed**: Check NPM package `mcp-harbor`

#### Integration Notes
- **Available MCP Tools** (from current session):
  - `list_projects`: List Harbor projects
  - `get_project`: Get project details
  - `create_project`: Create new project
  - `delete_project`: Delete project
  - `list_repositories`: List repositories
  - `delete_repository`: Delete repository
  - `list_tags`: List image tags
  - `delete_tag`: Delete tag
  - `list_charts`: List Helm charts
  - `list_chart_versions`: List chart versions
  - `delete_chart`: Delete chart version

#### Infrastructure Context
- **Harbor Registry**: harbor.aglz.io:5000
- **Deployment**: Part of Dokploy infrastructure (see `docs/DOKPLOY.md`)
- **Purpose**: Private container registry for AGL infrastructure

---

### 3. **Proxmox MCP Server**

**Package**: Custom Python module (`proxmox_mcp`)
**Status**: ✅ Connected
**Type**: stdio
**Command**: `/usr/local/bin/proxmox-mcp-wrapper.sh`

#### Overview
Custom MCP server for Proxmox VE management, providing comprehensive tools for VM/container lifecycle, storage, networking, and cluster operations.

#### Wrapper Script
**Location**: `/usr/local/bin/proxmox-mcp-wrapper.sh`

```bash
#!/bin/bash
export PROXMOX_MCP_CONFIG=/root/ProxmoxMCP/proxmox-config/config.json
exec python3 -m proxmox_mcp.server "$@"
```

#### Configuration File
**Location**: `/root/ProxmoxMCP/proxmox-config/config.json`

```json
{
  "proxmox": {
    "host": "192.168.0.245",
    "port": 8006,
    "verify_ssl": false,
    "service": "PVE"
  },
  "auth": {
    "user": "root@pam",
    "token_name": "agldv03",
    "token_value": "4550565a-1a84-4d67-83eb-6d1bc2be54d1"
  },
  "logging": {
    "level": "INFO",
    "format": "%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    "file": "proxmox_mcp.log"
  }
}
```

#### Expected Features
- Node management (list, status, reboot)
- VM/Container lifecycle (create, start, stop, destroy)
- Storage operations
- Network management
- Backup and restore
- Cluster operations
- Resource monitoring

#### Documentation
**Location**: Check `/root/ProxmoxMCP/` directory for README or docs

#### Integration Notes
- **Available MCP Tools** (from current session):
  - `get_nodes`: List all cluster nodes
  - `get_node_status`: Get node details
  - `get_vms`: List all VMs
  - `execute_vm_command`: Execute commands in VM (via QEMU guest agent)
  - `get_storage`: List storage pools
  - `get_cluster_status`: Cluster health

#### Infrastructure Context
- **Target Host**: AGLSRV1 (192.168.0.245)
- **Authentication**: API token-based (agldv03)
- **SSL**: Disabled (internal network)
- **See**: `docs/INFRA.md`, `docs/PROXMOX.md` for complete infrastructure details

---

### 4. **Portainer MCP Server**

**Package**: Custom binary (`portainer-mcp`)
**Status**: ✅ Connected
**Type**: stdio
**Command**: `/usr/local/bin/portainer-mcp -server portainer.aglz.io -token ptr_... -disable-version-check`

#### Overview
Custom MCP server for Portainer management, enabling AI-driven Docker and Kubernetes operations through Portainer API.

#### Binary Information
**Location**: `/usr/local/bin/portainer-mcp`
**Type**: ELF 64-bit executable (compiled binary, likely Go)
**Size**: Large (contains embedded resources)

#### Command Line Arguments
```bash
/usr/local/bin/portainer-mcp \
  -server portainer.aglz.io \
  -token ptr_tPhR+YNqloPJXvCWCcknuaiLqE4jQnK842fJ24u8jH8= \
  -disable-version-check
```

#### Expected Features
- Environment management (list, create, update)
- Stack deployment and management
- Container operations via Portainer API
- Network and volume management
- Team and user management
- Access control and RBAC

#### Documentation
**Research Needed**: Check binary help (`portainer-mcp --help`) or GitHub repository

#### Integration Notes
- **Available MCP Tools** (from current session):
  - `listEnvironments`: List all environments
  - `listStacks`: List all stacks
  - `createStack`: Deploy new stack
  - `updateStack`: Update existing stack
  - `listTeams`: List teams
  - `createTeam`: Create new team
  - `listUsers`: List users
  - `dockerProxy`: Proxy Docker API calls
  - `kubernetesProxy`: Proxy Kubernetes API calls
  - Many more (comprehensive Portainer API coverage)

#### Infrastructure Context
- **Portainer URL**: https://portainer.aglz.io
- **Purpose**: Centralized container management across multiple Docker hosts
- **Integration**: Manages CT179, CT108, and other container environments

---

### 5. **Cloudflare DNS MCP Server**

**Package**: `@cloudflare/mcp-server-cloudflare` (via NPX)
**Status**: ✅ Connected
**Type**: stdio
**Command**: `npx -y @cloudflare/mcp-server-cloudflare run 08e7b6e3a5084b4a3a2e0b3de153b02e`

#### Overview
Official Cloudflare MCP server for managing DNS, Workers, KV, R2, D1, and other Cloudflare services.

#### Configuration (Inferred)
```json
{
  "cloudflare-dns": {
    "type": "stdio",
    "command": "npx",
    "args": [
      "-y",
      "@cloudflare/mcp-server-cloudflare",
      "run",
      "08e7b6e3a5084b4a3a2e0b3de153b02e"
    ],
    "env": {
      "CLOUDFLARE_API_KEY": "..."
    }
  }
}
```

#### Expected Features
- DNS record management (A, AAAA, CNAME, MX, TXT, etc.)
- Zone management
- Workers deployment and management
- KV namespace operations
- R2 bucket management
- D1 database operations
- Durable Objects
- Pages deployment
- Analytics and logs

#### Documentation
- **Official**: https://developers.cloudflare.com/mcp
- **NPM**: https://www.npmjs.com/package/@cloudflare/mcp-server-cloudflare
- **GitHub**: https://github.com/cloudflare/mcp-server-cloudflare

#### Integration Notes
- **Available MCP Tools** (extensive list, 100+ tools):
  - **KV**: `kv_get`, `kv_put`, `kv_delete`, `kv_list`
  - **Workers**: `worker_list`, `worker_get`, `worker_put`, `worker_deploy`
  - **R2**: `r2_list_buckets`, `r2_get_object`, `r2_put_object`
  - **D1**: `d1_list_databases`, `d1_query`
  - **DNS**: `zones_list`, `zones_get`
  - **Domains**: `domain_list`
  - **And many more...**

#### Infrastructure Context
- **Account ID**: 08e7b6e3a5084b4a3a2e0b3de153b02e
- **DNS Zones**: aglz.io and related domains
- **Workers**: Various deployed workers
- **Purpose**: DNS management for AGL infrastructure

---

## ❌ Failed Connections

### 1. **claude-flow@alpha** - Failed

**Issue**: Connection failure
**Possible Causes**:
- ESM module errors (signal-exit, restore-cursor)
- Package version incompatibility
- Missing dependencies

**Troubleshooting**:
```bash
# Reinstall claude-flow
npx claude-flow@alpha init --force

# Check for ESM errors
npx claude-flow@alpha mcp start --verbose

# See docs/CLAUDE-FLOW.md for ESM troubleshooting
```

**Reference**: See `docs/CLAUDE-FLOW.md` for complete troubleshooting guide

---

### 2. **archon-tailscale** - Failed

**Issue**: Tailscale endpoint not reachable
**Possible Causes**:
- Tailscale network down
- CT183 not advertising Tailscale IP
- Firewall blocking port 8051

**Troubleshooting**:
```bash
# Check Tailscale status on CT183
ssh root@192.168.0.183 'tailscale status'

# Verify service is listening on Tailscale interface
ssh root@192.168.0.183 'ss -tlnp | grep 8051'

# Test from Tailscale network
ssh root@100.80.30.59 'curl http://100.80.30.59:8051/health'
```

**Workaround**: Use LAN endpoint (192.168.0.183:8052) - ✅ Working

---

### 3. **exa** - Failed

**Package**: `exa-mcp-server`
**Issue**: Connection failure
**Status**: Unknown package, may not be installed or configured correctly

**Research Needed**: Determine if this is a required package or can be removed

---

## 🔧 Archon MCP Corrections

### Port Configuration Issue

**Documented**: Port 8051 (incorrect)
**Actual**: Port 8052 (working)

**Evidence**:
```bash
$ curl http://192.168.0.183:8052/mcp
{"jsonrpc":"2.0","id":"server-error","error":{"code":-32600,"message":"Not Acceptable: Client must accept text/event-stream"}}
```

The error message confirms the MCP server is running on port 8052 and expecting SSE (Server-Sent Events) transport.

### Update Required

**File**: `docs/ARCHON.md`
**Section**: Network Access

**Current** (incorrect):
```
- Primary (LAN): http://192.168.0.183:8051/mcp
```

**Should be**:
```
- Primary (LAN): http://192.168.0.183:8052/mcp
```

**File**: `.cursor/mcp.json`

**Current** (correct):
```json
{
  "archon": {
    "type": "sse",
    "url": "http://192.168.0.183:8051/mcp"
  }
}
```

**Note**: The `.cursor/mcp.json` file shows port 8051, but `claude mcp list` shows successful connection on port 8052. Need to verify which port is actually in use.

---

## 📊 Playwright Installation

### Status
✅ **Installation Attempted**: Chromium browser
**Command**: `npx playwright install chromium`
**Expected Location**: `/root/.cache/ms-playwright/`

### Verification Needed
```bash
# Check if browsers are installed
ls -lh /root/.cache/ms-playwright/

# Verify Playwright functionality
npx playwright --version
```

---

## 🔍 Laravel Boost Investigation

### Current Status
**Command**: `php artisan boost:mcp`
**Status**: ❓ Command registration unknown

### Troubleshooting Required
```bash
# Check if Artisan is working
cd /mnt/overpower/apps/dev/agl/agl-hostman/src
php artisan --version

# List all registered commands
php artisan list | grep boost

# Check command registration
cat app/Console/Kernel.php | grep -i boost
cat app/Providers/AppServiceProvider.php | grep -i boost

# Search for command file
find app/Console/Commands -name "*Boost*" -o -name "*boost*"
```

### Configuration Files
**Primary**: `/mnt/overpower/apps/dev/agl/agl-hostman/src`

**MCP Config** (.mcp.json):
```json
{
  "laravel-boost": {
    "type": "stdio",
    "command": "php",
    "args": [
      "/mnt/overpower/apps/dev/agl/agl-hostman/src/artisan",
      "boost:mcp"
    ],
    "cwd": "/mnt/overpower/apps/dev/agl/agl-hostman/src"
  }
}
```

**MCP Config** (.cursor/mcp.json):
```json
{
  "laravel-boost": {
    "type": "stdio",
    "command": "php",
    "args": ["artisan", "boost:mcp"],
    "cwd": "/mnt/overpower/apps/dev/agl/agl-hostman/src",
    "env": {
      "COMPOSER_ALLOW_SUPERUSER": "1"
    }
  }
}
```

---

## 📝 Summary & Recommendations

### Immediate Actions Required

1. **✅ Document Additional Servers** (This document)
   - Created comprehensive documentation for 5 new servers

2. **🔧 Fix claude-flow Connection**
   ```bash
   npx claude-flow@alpha init --force
   claude mcp reload
   ```

3. **📝 Update ARCHON.md**
   - Correct port number from 8051 to 8052 (verify which is correct)

4. **🔍 Investigate Laravel Boost**
   - Verify command exists and is registered
   - May need to create the command if it doesn't exist

5. **🧹 Remove Failed Servers**
   - Consider removing `exa` if not needed
   - Fix or remove `archon-tailscale` endpoint

### Security Audit Required

**Exposed Credentials** in configuration:
- ✅ Proxmox token: Stored in config file (local)
- ✅ Portainer token: In command line (visible in process list)
- ✅ Cloudflare API key: In NPX arguments
- ⚠️ Dokploy API key: In `.mcp.json` (git tracked?)

**Recommendations**:
1. Use environment variables for sensitive data
2. Add `.mcp.json` to `.gitignore` if it contains secrets
3. Rotate any exposed tokens/keys
4. Implement secret management system (Vault, SOPS, etc.)

### Documentation Updates Needed

1. **docs/MCP-SERVERS-ANALYSIS.md** - Add 5 new servers
2. **docs/ARCHON.md** - Correct port number
3. **docs/INFRA.md** - Reference MCP tools integration
4. **docs/DOKPLOY.md** - Add Harbor MCP integration details
5. **README.md** - Add MCP servers overview

### Testing Checklist

- [ ] Verify Playwright browsers installed
- [ ] Test Docker MCP tools with sample container
- [ ] Test Harbor MCP tools with test project
- [ ] Test Proxmox MCP tools (list nodes, VMs)
- [ ] Test Portainer MCP tools (list environments)
- [ ] Test Cloudflare MCP tools (list zones)
- [ ] Fix claude-flow connection
- [ ] Verify Laravel Boost command exists
- [ ] Document all tool capabilities

---

## 🔗 Related Documentation

- **Main Analysis**: [MCP-SERVERS-ANALYSIS.md](MCP-SERVERS-ANALYSIS.md)
- **Infrastructure**: [INFRA.md](INFRA.md)
- **Archon Integration**: [ARCHON.md](ARCHON.md)
- **Dokploy Platform**: [DOKPLOY.md](DOKPLOY.md)
- **Claude Flow**: [CLAUDE-FLOW.md](CLAUDE-FLOW.md)

---

**Document Version**: 1.0.0
**Date**: 2025-12-17
**Next Steps**: Update all related documentation and fix failed connections
