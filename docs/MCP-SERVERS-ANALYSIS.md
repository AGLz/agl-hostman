# MCP Servers Analysis - agl-hostman Project

> **Last Updated**: 2025-12-17
> **Version**: 1.0.0
> **Purpose**: Comprehensive analysis of all MCP servers configured in this project

---

## 📑 Table of Contents

1. [Overview](#-overview)
2. [Configuration Files](#-configuration-files)
3. [Server Analysis](#-server-analysis)
4. [Installation & Setup](#-installation--setup)
5. [Troubleshooting](#-troubleshooting)
6. [Recommendations](#-recommendations)

---

## 🎯 Overview

This project uses **7 different MCP (Model Context Protocol) servers** to extend AI assistant capabilities across infrastructure management, deployment, UI development, testing, and workflow orchestration.

### MCP Protocol

**Model Context Protocol (MCP)** is an open protocol developed by Anthropic that enables AI assistants to securely connect to external data sources and tools. It acts as a bridge between AI models and external systems, allowing natural language interactions to be translated into API calls and system operations.

**Key Benefits**:
- 🔌 **Standardized Integration**: Unified protocol for tool integration
- 🔒 **Secure Communication**: Built-in authentication and authorization
- 🚀 **Real-time Updates**: Support for streaming (SSE) and stdio transports
- 🧩 **Composability**: Multiple servers can work together seamlessly

---

## 📂 Configuration Files

### 1. `.mcp.json` (Primary Configuration)

**Location**: `/mnt/overpower/apps/dev/agl/agl-hostman/.mcp.json`
**Used by**: Claude Code, Claude Desktop
**Servers**: 6 servers

```json
{
  "mcpServers": {
    "dokploy": { /* Deployment platform */ },
    "claude-flow@alpha": { /* Agent orchestration */ },
    "flow-nexus": { /* Cloud-based AI workflows */ },
    "agentic-payments": { /* Payment automation */ },
    "laravel-boost": { /* Laravel development */ },
    "shadcn": { /* UI component library */ }
  }
}
```

### 2. `.cursor/mcp.json` (Cursor IDE Configuration)

**Location**: `/mnt/overpower/apps/dev/agl/agl-hostman/.cursor/mcp.json`
**Used by**: Cursor IDE
**Servers**: 4 servers

```json
{
  "mcpServers": {
    "laravel-boost": { /* Laravel development */ },
    "shadcn": { /* UI component library */ },
    "playwright": { /* Browser automation & testing */ },
    "archon": { /* AI Command Center (SSE) */ }
  }
}
```

### 3. Deleted Configuration

**File**: `.cursor/mcp-config.json` (deleted in git status)
This file was likely deprecated or merged into `.cursor/mcp.json`.

---

## 🔍 Server Analysis

### 1. **Dokploy MCP Server**

**Package**: `@ahdev/dokploy-mcp@latest`
**Type**: stdio (NPX execution)
**Status**: ✅ Well-documented
**Repository**: https://github.com/andradehenrique/dokploy-mcp

#### Overview
Dokploy MCP Server exposes Dokploy infrastructure management platform functionalities via MCP protocol, translating natural language into deployment API calls.

#### Features
- **43 tools** for comprehensive Dokploy management
- **Project Management**: Create, update, delete, duplicate projects
- **Application Deployment**: Deploy, redeploy, start, stop applications
- **Database Management**: PostgreSQL, MySQL, MariaDB, MongoDB, Redis operations
- **Domain Management**: SSL certificates, DNS validation, Traefik configuration
- **Environment Management**: Environment variables, external ports, network configuration

#### Configuration
```json
{
  "dokploy": {
    "type": "stdio",
    "command": "npx",
    "args": ["@ahdev/dokploy-mcp@latest"],
    "env": {
      "DOKPLOY_URL": "http://192.168.0.180:3000",
      "DOKPLOY_API_KEY": "dsXeAeNn29zAMhkcdefcRhcDfwRx0xG2ZvkfkCHF-Rw"
    }
  }
}
```

#### Key Tools
- `project-all`, `project-create`, `project-update`, `project-remove`
- `application-deploy`, `application-redeploy`, `application-start`, `application-stop`
- `postgres-create`, `mysql-create`, `domain-create`
- `sandbox-create`, `sandbox-execute`, `workflow-create`

#### Documentation
- **NPM**: https://www.npmjs.com/package/@ahdev/dokploy-mcp
- **GitHub**: https://github.com/andradehenrique/dokploy-mcp
- **Requirements**: Node.js v18+ (native fetch support)

#### Integration Status
✅ Fully configured with DOKPLOY_URL and API key
✅ Points to CT180 (192.168.0.180:3000) - Dokploy deployment platform
✅ See `docs/DOKPLOY.md` for complete deployment guide

---

### 2. **Claude Flow MCP Server (Alpha)**

**Package**: `claude-flow@alpha`
**Type**: stdio (NPX execution)
**Status**: ✅ Actively maintained (Ranked #1 agent framework)
**Repository**: https://github.com/ruvnet/claude-flow

#### Overview
Leading agent orchestration platform for Claude featuring enterprise-grade architecture, distributed swarm intelligence, RAG integration, and native Claude Code support.

#### Features
- **87 specialized tools** for AI orchestration
- **Multi-Agent Swarms**: Hierarchical, mesh, ring, star topologies
- **Workflow Automation**: Event-driven processing, message queues
- **Neural Training**: 27+ model architectures with distributed training
- **GitHub Integration**: PR management, code review swarms, workflow automation
- **Sandbox Deployment**: E2B sandbox orchestration with environment isolation

#### Configuration
```json
{
  "claude-flow@alpha": {
    "type": "stdio",
    "command": "npx",
    "args": ["claude-flow@alpha", "mcp", "start"]
  }
}
```

#### Key Tool Categories
- **Swarm Management**: `swarm_init`, `agent_spawn`, `task_orchestrate`, `swarm_scale`
- **Neural Processing**: `neural_train`, `neural_predict`, `neural_cluster_init`
- **Workflow Automation**: `workflow_create`, `workflow_execute`, `workflow_status`
- **GitHub Operations**: `github_repo_analyze`, `pr_manager`, `code-review-swarm`
- **Sandbox Orchestration**: `sandbox_create`, `sandbox_execute`, `sandbox_configure`

#### Documentation
- **GitHub**: https://github.com/ruvnet/claude-flow
- **MCP Tools Wiki**: https://github.com/ruvnet/claude-flow/wiki/MCP-Tools
- **Latest Release**: v2.7.40 (MCP 2025-11 compliant)

#### Integration Status
✅ Configured with alpha channel for latest features
✅ MCP namespace: `mcp__claude-flow__*`
⚠️ See `docs/CLAUDE-FLOW.md` for ESM troubleshooting (signal-exit/restore-cursor)

---

### 3. **Flow Nexus MCP Server**

**Package**: `flow-nexus@latest`
**Type**: stdio (NPX execution)
**Status**: ⚠️ Limited web documentation available
**Repository**: Unknown (NPM package exists)

#### Overview
Cloud-based AI workflow and swarm orchestration platform. Based on available MCP tools, this appears to be an enterprise version or extension of Claude Flow with additional cloud services.

#### Features (from available MCP tools)
- **Neural Network Cluster**: Distributed training with E2B sandboxes
- **Flow Nexus Platform**: Authentication, sandboxes, app deployment, payments
- **App Store & Templates**: Template marketplace, challenge systems, leaderboards
- **GitHub Integration**: Repository analysis, code review automation
- **Payment System**: rUv credits, auto-refill, transaction management
- **Queen Seraphina**: AI guide and orchestration coordinator

#### Configuration
```json
{
  "flow-nexus": {
    "type": "stdio",
    "command": "npx",
    "args": ["flow-nexus@latest", "mcp", "start"]
  }
}
```

#### Key Tool Categories
- **Swarm Orchestration**: Similar to claude-flow but cloud-native
- **Neural Training**: `neural_train`, `neural_cluster_init`, `neural_node_deploy`
- **Sandbox Management**: `sandbox_create`, `sandbox_execute`, `sandbox_configure`
- **App Store**: `app_store_list_templates`, `app_store_publish_app`
- **Payment Processing**: `create_payment_link`, `check_balance`, `configure_auto_refill`
- **AI Assistant**: `seraphina_chat` (Queen Seraphina guidance system)

#### Documentation
⚠️ **Status**: Web search unavailable, NPM package likely has README
**Recommendation**: Check `npx flow-nexus@latest --help` or install locally

#### Integration Status
✅ Configured to run latest version
❓ May require additional environment variables or API keys
📝 **Action Required**: Test connection and review package documentation

---

### 4. **Agentic Payments MCP Server**

**Package**: `agentic-payments@latest`
**Type**: stdio (NPX execution)
**Status**: ⚠️ Limited web documentation available
**Repository**: Unknown

#### Overview
Autonomous agent payment authorization system with Active Mandates, spend caps, time windows, and merchant restrictions using Ed25519 cryptographic signatures.

#### Features (from available MCP tools)
- **Active Mandates**: Create payment authorizations with execution guards
- **Cryptographic Signing**: Ed25519 signature verification
- **Spend Controls**: Caps, time windows, merchant allow/block lists
- **Agent Identity**: Generate keypairs for payment authorization
- **Intent-Based Payments**: High-level purchase authorization
- **Cart-Based Payments**: Specific line item approval
- **Byzantine Consensus**: Multi-agent payment verification

#### Configuration
```json
{
  "agentic-payments": {
    "type": "stdio",
    "command": "npx",
    "args": ["agentic-payments@latest", "mcp"]
  }
}
```

#### Key Tools
- `create_active_mandate`: Create payment authorization with spend caps
- `sign_mandate`: Cryptographic proof with Ed25519
- `verify_mandate`: Check signature and execution guards
- `revoke_mandate`: Prevent further execution
- `generate_agent_identity`: Create Ed25519 keypair
- `create_intent_mandate`: Intent-based purchase authorization
- `create_cart_mandate`: Cart-based payment approval
- `verify_consensus`: Byzantine fault-tolerant verification

#### Documentation
⚠️ **Status**: Web search unavailable
**Recommendation**: Check NPM package for README and examples

#### Integration Status
✅ Configured to run latest version
❓ May require blockchain or payment gateway credentials
📝 **Action Required**: Review security model and test in development environment

---

### 5. **Laravel Boost MCP Server**

**Package**: Custom Laravel Artisan command
**Type**: stdio (PHP execution)
**Status**: ⚠️ No public documentation (project-specific)
**Repository**: Local project (`/mnt/overpower/apps/dev/agl/agl-hostman/src`)

#### Overview
Custom Laravel MCP server implementation providing Laravel-specific development tools and utilities through the `boost:mcp` Artisan command.

#### Configuration (.mcp.json)
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

#### Configuration (.cursor/mcp.json)
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

#### Features (Expected)
- Laravel code generation (models, controllers, migrations)
- Database operations and migrations
- Route management and API scaffolding
- Artisan command execution
- Composer dependency management
- Configuration and environment management

#### Documentation
📝 **Status**: Project-specific implementation
**Location**: Check `src/app/Console/Commands/` for `BoostMcpCommand.php`
**Recommendation**: Review local codebase for command implementation

#### Integration Status
✅ Configured with absolute and relative paths
✅ Includes COMPOSER_ALLOW_SUPERUSER for container environments
📝 **Action Required**: Verify Artisan command exists and is registered

---

### 6. **Shadcn UI MCP Server**

**Package**: `shadcn@latest`
**Type**: stdio (NPX execution)
**Status**: ✅ Official shadcn/ui MCP server (well-documented)
**Repository**: https://ui.shadcn.com/docs/mcp

#### Overview
Official shadcn/ui MCP Server allows AI assistants to browse, search, and install UI components from registries using natural language.

#### Features
- **Component Discovery**: Browse available components from configured registries
- **Semantic Search**: Find components by description or use case
- **Direct Installation**: Install components into your project via natural language
- **Multi-Registry Support**: Access components from multiple sources including private registries
- **Framework Support**: React, Vue, Svelte, React Native

#### Configuration (.mcp.json)
```json
{
  "shadcn": {
    "command": "npx",
    "args": ["shadcn@latest", "mcp"]
  }
}
```

#### Configuration (.cursor/mcp.json)
```json
{
  "shadcn": {
    "type": "stdio",
    "command": "npx",
    "args": ["shadcn@latest", "mcp"],
    "cwd": "/mnt/overpower/apps/dev/agl/agl-hostman/src"
  }
}
```

#### Usage Examples
- "Build a landing page using components from the acme registry"
- "Find me a login form from the shadcn registry"
- "Install the button component"
- "Show me all available card components"

#### Documentation
- **Official Docs**: https://ui.shadcn.com/docs/mcp
- **Vue Variant**: https://www.shadcn-vue.com/docs/mcp
- **GitHub**: https://github.com/Jpisnice/shadcn-ui-mcp-server

#### Integration Status
✅ Official package with comprehensive documentation
✅ Configured for both root and src directory
✅ Works with project's `components.json` configuration

---

### 7. **Playwright MCP Server**

**Package**: `@playwright/mcp`
**Type**: stdio (NPX execution)
**Status**: ⚠️ Limited public documentation
**Repository**: Official Playwright organization

#### Overview
Browser automation and testing MCP server from the official Playwright team, enabling AI assistants to perform web scraping, testing, and browser automation tasks.

#### Features (Expected)
- **Browser Automation**: Navigate, click, fill forms, take screenshots
- **Web Scraping**: Extract data from websites
- **Testing**: Visual regression, accessibility testing, functional testing
- **Multi-Browser Support**: Chromium, Firefox, WebKit
- **Network Interception**: Monitor and modify network requests
- **PDF Generation**: Convert web pages to PDF

#### Configuration (.cursor/mcp.json)
```json
{
  "playwright": {
    "type": "stdio",
    "command": "npx",
    "args": ["@playwright/mcp"],
    "cwd": "/mnt/overpower/apps/dev/agl/agl-hostman",
    "env": {
      "NODE_ENV": "development",
      "PLAYWRIGHT_BROWSERS_PATH": "/root/.cache/ms-playwright"
    }
  }
}
```

#### Available MCP Tools (from server configuration)
Based on the loaded tools in the current session:
- `browser_navigate`: Navigate to URLs
- `browser_screenshot`: Capture screenshots
- `browser_click`: Click elements
- `browser_fill_form`: Fill form fields
- `browser_evaluate`: Execute JavaScript in browser context
- `browser_wait_for`: Wait for elements or conditions
- `browser_network_requests`: Monitor network activity
- `browser_console_messages`: Capture console logs

#### Documentation
⚠️ **Status**: Official package but limited MCP-specific docs
**General Docs**: https://playwright.dev
**Recommendation**: Check `npx @playwright/mcp --help`

#### Integration Status
✅ Configured with custom browser cache path
✅ Development environment settings
⚠️ Requires Playwright browsers to be installed: `npx playwright install`

---

### 8. **Archon MCP Server (SSE)**

**Package**: Custom deployment (CT183 container)
**Type**: SSE (Server-Sent Events)
**Status**: ✅ Fully documented in project
**Repository**: https://github.com/coleam00/Archon

#### Overview
AI Command Center deployed on CT183 providing centralized knowledge base access, task management, and project coordination via MCP protocol.

#### Features
- **Knowledge Base**: Semantic search with PGVector and RAG
- **Code Examples**: Indexed repository with search capabilities
- **Project Management**: Create, update, track projects
- **Task Management**: Todo/Doing/Review/Done workflow
- **Document Processing**: Markdown, code, embedding generation
- **Real-time Communication**: Socket.IO for live updates

#### Configuration (.cursor/mcp.json)
```json
{
  "archon": {
    "type": "sse",
    "url": "http://192.168.0.183:8051/mcp",
    "description": "Archon MCP server for project management, PRP workflows, and task automation"
  }
}
```

#### Available Tools (28 total)
**Knowledge Base**:
- `rag_search_knowledge_base`: Semantic search in knowledge base
- `rag_search_code_examples`: Find relevant code examples
- `rag_read_full_page`: Retrieve complete page content
- `rag_get_available_sources`: List knowledge sources
- `rag_list_pages_for_source`: Browse pages in a source

**Project Management**:
- `find_projects`: List, search, get projects
- `manage_project`: Create, update, delete projects
- `get_project_features`: Get project feature list

**Task Management**:
- `find_tasks`: List, search, filter tasks
- `manage_task`: Create, update, delete tasks

**Document Management**:
- `find_documents`: List, search documents
- `manage_document`: Create, update, delete documents

**Version Control**:
- `find_versions`: List version history
- `manage_version`: Create snapshots, restore versions

**System**:
- `health_check`: Service health status
- `session_info`: Active sessions
- `archon_get_status`: System status and configuration

#### Network Access
- **Primary (LAN)**: http://192.168.0.183:8051/mcp (used in config)
- **WireGuard**: http://10.6.0.21:8051/mcp (fastest for remote)
- **Tailscale**: http://100.80.30.59:8051/mcp (backup)
- **Public DNS**: https://archon.aglz.io (Basic Auth: admin/ArchonPass2025)

#### Technology Stack
- **Backend**: Python 3.12, FastAPI, Socket.IO
- **Database**: Supabase (PostgreSQL + PGVector)
- **Frontend**: React 18, Vite, TypeScript
- **Container**: CT183 on AGLSRV1 (8 cores, 16GB RAM)

#### Documentation
- **Project Docs**: `docs/ARCHON.md` (comprehensive integration guide)
- **GitHub**: https://github.com/coleam00/Archon
- **Deployment**: CT183 (192.168.0.183) on AGLSRV1

#### Integration Status
✅ Fully deployed and operational on CT183
✅ Configured with SSE transport for real-time updates
✅ Complete documentation in project
✅ Active health monitoring at all network endpoints

---

## 🚀 Installation & Setup

### Prerequisites

**All MCP Servers**:
- Node.js v18+ (for NPX-based servers)
- npm or pnpm package manager

**Server-Specific**:
- **Dokploy**: API key and URL configured
- **Laravel Boost**: PHP 8.1+, Composer, Laravel project
- **Playwright**: Browser binaries (`npx playwright install`)
- **Archon**: CT183 container running (already deployed)

### Installation Commands

```bash
# Verify Node.js version
node --version  # Should be v18+

# Install Playwright browsers (if using playwright)
npx playwright install

# Test individual servers
npx @ahdev/dokploy-mcp@latest --help
npx claude-flow@alpha mcp start
npx flow-nexus@latest mcp start
npx agentic-payments@latest mcp
npx shadcn@latest mcp

# Test Laravel Boost
cd /mnt/overpower/apps/dev/agl/agl-hostman/src
php artisan boost:mcp

# Test Archon connection
curl http://192.168.0.183:8051/mcp
```

### Claude Code Configuration

```bash
# Add all MCP servers to Claude Code
claude mcp add --config /mnt/overpower/apps/dev/agl/agl-hostman/.mcp.json

# Or add individually
claude mcp add dokploy --transport stdio --command "npx" --args "@ahdev/dokploy-mcp@latest"
claude mcp add claude-flow --transport stdio --command "npx" --args "claude-flow@alpha,mcp,start"
claude mcp add archon --transport sse --url "http://192.168.0.183:8051/mcp"

# Verify all servers are connected
claude mcp list

# Restart Claude Code after configuration changes
claude mcp reload
```

### Environment Variables

**Dokploy** (.env or export):
```bash
export DOKPLOY_URL="http://192.168.0.180:3000"
export DOKPLOY_API_KEY="dsXeAeNn29zAMhkcdefcRhcDfwRx0xG2ZvkfkCHF-Rw"
```

**Laravel Boost**:
```bash
export COMPOSER_ALLOW_SUPERUSER="1"
```

**Playwright**:
```bash
export NODE_ENV="development"
export PLAYWRIGHT_BROWSERS_PATH="/root/.cache/ms-playwright"
```

---

## 🔧 Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| **"MCP server not found"** | NPX package not accessible | Check Node.js version (v18+), verify internet connection |
| **"Connection refused"** (Archon) | CT183 container not running | SSH to AGLSRV1: `pct start 183` |
| **"Command not found"** (Laravel Boost) | Artisan command not registered | Check `app/Console/Kernel.php` for command registration |
| **Playwright browser error** | Browsers not installed | Run `npx playwright install` |
| **Dokploy authentication error** | Invalid API key | Verify DOKPLOY_API_KEY in environment |
| **Permission denied** (PHP) | File permissions in container | Add COMPOSER_ALLOW_SUPERUSER=1 |

### Diagnostic Commands

```bash
# Test MCP server connectivity
claude mcp test <server-name>

# Check Claude Code logs
claude logs

# Verify Node.js and NPM
node --version && npm --version

# Test Archon health
curl http://192.168.0.183:8051/health

# Check Dokploy API
curl -H "Authorization: Bearer $DOKPLOY_API_KEY" \
  http://192.168.0.180:3000/api/health

# Test Laravel Boost
cd /mnt/overpower/apps/dev/agl/agl-hostman/src
php artisan list | grep boost

# Verify Playwright installation
npx playwright --version
ls -la /root/.cache/ms-playwright/
```

### Server-Specific Troubleshooting

**Claude Flow / Flow Nexus**:
- See `docs/CLAUDE-FLOW.md` for ESM module errors (signal-exit, restore-cursor)
- Run `npx claude-flow@alpha init --force` to reset configuration

**Archon**:
- Check all 3 network endpoints (LAN, WireGuard, Tailscale)
- Verify Docker containers: `ssh root@192.168.0.183 'docker ps'`
- Restart services: `ssh root@192.168.0.183 'cd /opt/archon && docker-compose restart'`

**Dokploy**:
- Verify CT180 is running: `ssh root@192.168.0.245 'pct status 180'`
- Check Dokploy web interface: http://192.168.0.180:3000
- See `docs/DOKPLOY.md` for complete troubleshooting guide

---

## 💡 Recommendations

### Priority Actions

1. **✅ Verify All Servers are Operational**
   ```bash
   claude mcp list
   claude mcp test dokploy
   claude mcp test claude-flow
   claude mcp test archon
   ```

2. **📚 Document Missing Servers**
   - Flow Nexus: Check NPM package for README
   - Agentic Payments: Review security model and payment integration
   - Laravel Boost: Document custom Artisan command implementation

3. **🔐 Security Audit**
   - Rotate Dokploy API key if exposed in git history
   - Secure Archon endpoints (currently using Basic Auth)
   - Review Agentic Payments cryptographic implementation

4. **🚀 Performance Optimization**
   - Consider caching NPX packages locally for faster startup
   - Use specific versions instead of `@latest` for production stability
   - Implement health checks for all servers

### Best Practices

**Configuration Management**:
- ✅ Keep `.mcp.json` and `.cursor/mcp.json` in sync
- ✅ Use environment variables for sensitive data
- ✅ Version-pin packages for reproducibility
- ✅ Document server-specific requirements

**Development Workflow**:
- Use Archon for project/task management
- Use Claude Flow for complex multi-agent workflows
- Use Dokploy for deployment automation
- Use Shadcn for UI component discovery
- Use Playwright for testing and scraping

**Monitoring**:
- Set up health checks for all servers
- Monitor CT183 (Archon) resource usage
- Track API rate limits (Dokploy, Flow Nexus)
- Log MCP errors to central location

### Future Improvements

1. **Unified Configuration**
   - Merge `.mcp.json` and `.cursor/mcp.json` configurations
   - Use symlinks or config inheritance

2. **Documentation**
   - Create comprehensive guide for each server
   - Add usage examples and workflows
   - Document integration patterns

3. **Testing**
   - Implement automated MCP server health checks
   - Create integration tests for server interactions
   - Test failover scenarios (network failures, server restarts)

4. **Security**
   - Implement centralized secret management
   - Add authentication for public-facing servers
   - Audit all API keys and credentials

---

## 📊 Summary Matrix

| Server | Type | Status | Documentation | Priority |
|--------|------|--------|---------------|----------|
| **Dokploy** | stdio | ✅ Excellent | Official docs available | High |
| **Claude Flow** | stdio | ✅ Excellent | GitHub + Wiki | High |
| **Flow Nexus** | stdio | ⚠️ Limited | NPM package only | Medium |
| **Agentic Payments** | stdio | ⚠️ Limited | NPM package only | Low |
| **Laravel Boost** | stdio | ⚠️ Project-specific | Local codebase | Medium |
| **Shadcn** | stdio | ✅ Excellent | Official docs | High |
| **Playwright** | stdio | ⚠️ Limited | General docs only | Medium |
| **Archon** | SSE | ✅ Excellent | Project docs (ARCHON.md) | Critical |

---

## 🔗 Quick Links

**Documentation**:
- [Dokploy Setup Guide](DOKPLOY.md)
- [Archon Integration Guide](ARCHON.md)
- [Claude Flow Guide](CLAUDE-FLOW.md)
- [Infrastructure Map](INFRA.md)

**External Resources**:
- [MCP Protocol Specification](https://modelcontextprotocol.io)
- [Claude Code Docs](https://docs.claude.com/en/docs/claude-code)
- [Anthropic MCP Servers](https://github.com/anthropics/mcp-servers)

**Repositories**:
- [Dokploy MCP](https://github.com/andradehenrique/dokploy-mcp)
- [Claude Flow](https://github.com/ruvnet/claude-flow)
- [Archon](https://github.com/coleam00/Archon)
- [Shadcn MCP](https://github.com/Jpisnice/shadcn-ui-mcp-server)

---

**Document Version**: 1.0.0
**Last Updated**: 2025-12-17
**Maintainer**: Claude Code (agl-hostman project)
**Next Review**: After testing all servers and documenting missing packages
