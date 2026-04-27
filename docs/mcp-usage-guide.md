# MCP Server Usage Guide - AGL-25

**Last Updated**: 2026-02-10
**Project**: AGL Hostman
**Total Servers**: 26

---

## Quick Reference

### Essential Commands

```bash
# List all MCP servers
claude mcp list

# Health check
./scripts/mcp-monitoring/mcp-health-check.sh check

# Health report
./scripts/mcp-monitoring/mcp-health-check.sh report

# Restart unhealthy servers
./scripts/mcp-monitoring/mcp-health-check.sh restart

# Continuous monitoring
./scripts/mcp-monitoring/mcp-health-check.sh monitor 60

# Auto-restart status
./scripts/mcp-monitoring/mcp-auto-restart.sh status
```

---

## Server Categories

### 1. Orchestration & Coordination (P0-P1)

#### claude-flow (CRITICAL - P0)
- **Purpose**: Core orchestration and swarm coordination
- **Tools**: 70+ tools for swarming, memory, hooks, GitHub
- **Usage**: All coordination workflows
- **Response Time**: ~2800ms (needs optimization)

#### ruv-swarm (HIGH - P1)
- **Purpose**: Enhanced coordination patterns
- **Tools**: Advanced swarm orchestration
- **Usage**: Complex multi-agent workflows
- **Response Time**: ~2800ms

#### flow-nexus (MEDIUM - P2)
- **Purpose**: Cloud features and neural AI
- **Tools**: 70+ cloud orchestration tools
- **Usage**: Cloud deployment, neural training
- **Response Time**: ~2800ms
- **Note**: Requires registration at flow-nexus.ruv.io

#### context7 (MEDIUM - P2)
- **Purpose**: Context management
- **Usage**: Enhanced context tracking
- **Type**: HTTP service

---

### 2. Project Management (P0-P1)

#### archon (CRITICAL - P0)
- **Purpose**: Local project management, PRP workflows
- **URL**: http://192.168.0.183:8052/mcp
- **Response Time**: ~13ms (EXCELLENT)
- **Tools**: Projects, tasks, documents, versions, memory

#### archon-tailscale (CRITICAL - P0)
- **Purpose**: Remote project management via VPN
- **URL**: http://100.80.30.59:8051/mcp
- **Response Time**: ~16ms (EXCELLENT)
- **Note**: IP may change on Tailscale reconnect

#### linear (HIGH - P1 - REQUIRES AUTH)
- **Purpose**: Linear project management
- **URL**: https://mcp.linear.app/mcp
- **Status**: Needs authentication
- **Setup**: Set LINEAR_API_TOKEN environment variable

#### github (HIGH - P1)
- **Purpose**: GitHub integration
- **Usage**: Repos, PRs, issues, releases
- **Tools**: repo analysis, code review, issue tracking

---

### 3. Media Analysis (P1)

#### zai-mcp-server (HIGH - P1)
- **Purpose**: Image and video analysis
- **Tools**:
  - `analyze_image` - General image understanding
  - `ui_to_artifact` - UI to code/spec/prompt/description
  - `extract_text_from_screenshot` - OCR text extraction
  - `diagnose_error_screenshot` - Error analysis
  - `understand_technical_diagram` - Architecture diagrams
  - `analyze_data_visualization` - Charts and graphs
  - `ui_diff_check` - UI comparison
  - `analyze_video` - Video content analysis

---

### 4. Search & Web (P1-P2)

#### exa (HIGH - P1)
- **Purpose**: AI-powered search
- **Response Time**: ~3000ms
- **Usage**: Intelligent web search

#### web-search-prime (HIGH - P1)
- **Purpose**: Web search with recent data
- **URL**: https://api.z.ai/api/mcp/web_search_prime/mcp
- **Features**: Location-aware, domain filtering

#### web-reader (MEDIUM - P2)
- **Purpose**: Web page scraping
- **URL**: https://api.z.ai/api/mcp/web_reader/mcp
- **Usage**: Extract content from web pages

#### zread (MEDIUM - P2)
- **Purpose**: GitHub repository reader
- **URL**: https://api.z.ai/api/mcp/zread/mcp
- **Tools**: `get_repo_structure`, `read_file`, `search_doc`

---

### 5. Infrastructure (P1-P3)

#### docker (HIGH - P1)
- **Purpose**: Docker container management
- **Usage**: Container operations, image management

#### proxmox (MEDIUM - P2)
- **Purpose**: Proxmox VM management
- **Wrapper**: /usr/local/bin/proxmox-mcp-wrapper.sh

#### harbor (MEDIUM - P2)
- **Purpose**: Container registry management
- **Usage**: Harbor registry operations

#### portainer (MEDIUM - P2)
- **Purpose**: Portainer container UI
- **Wrapper**: /usr/local/bin/portainer-mcp

#### dokploy (MEDIUM - P2)
- **Purpose**: Deployment automation
- **Usage**: Application deployment

#### cloudflare-dns (LOW - P3)
- **Purpose**: Cloudflare DNS management
- **Usage**: DNS record management

---

### 6. Data Storage (P2)

#### filesystem (HIGH - P1)
- **Purpose**: File system operations
- **Paths**: /root, /mnt/overpower/apps/dev
- **Usage**: File read/write operations

#### memory (MEDIUM - P2)
- **Purpose**: In-memory key-value storage
- **Usage**: Temporary data storage

#### sqlite (MEDIUM - P2)
- **Purpose**: SQLite database access
- **Database**: /root/.claude/data.db
- **Usage**: Persistent data storage

---

### 7. Development Tools (P3)

#### azure-devops (LOW - P3)
- **Purpose**: Azure DevOps integration
- **Usage**: Azure pipelines, boards

#### minecraft (LOW - P3)
- **Purpose**: Minecraft game development
- **Usage**: Minecraft-specific operations

---

### 8. Utilities (P2)

#### agentic-payments (MEDIUM - P2)
- **Purpose**: Payment processing
- **Response Time**: ~2900ms
- **Usage**: Payment operations

---

## Usage Patterns

### Common Combinations

#### Full Stack Development
```
claude-flow (orchestration) +
github (code) +
docker (containers) +
archon (project tracking)
```

#### Research & Analysis
```
exa (search) +
web-reader (scraping) +
zai-mcp-server (image analysis) +
memory (store findings)
```

#### Deployment
```
dokploy (deploy) +
docker (containers) +
harbor (registry) +
github (code source)
```

#### Project Management
```
archon (local) +
archon-tailscale (remote) +
linear (issue tracking) +
github (code review)
```

---

## Performance Optimization

### Current Status
- HTTP servers: ~15ms (EXCELLENT)
- npx servers: ~2800ms (NEEDS OPTIMIZATION)

### Optimization Tips

1. **Pre-install packages** (already done):
   ```bash
   npm install -g claude-flow@alpha
   npm install -g ruv-swarm@latest
   npm install -g flow-nexus@latest
   npm install -g exa-mcp-server
   npm install -g agentic-payments@latest
   ```

2. **Use HTTP servers when possible**:
   - archon: 13ms vs npx: 2800ms

3. **Cache npm packages**:
   ```bash
   npm config set cache /tmp/.npm-cache
   npm cache verify
   ```

4. **Batch operations**:
   - Use multiple tools in one message
   - Minimize round trips

---

## Troubleshooting

### Server Not Responding

```bash
# Check health
./scripts/mcp-monitoring/mcp-health-check.sh check

# Restart unhealthy
./scripts/mcp-monitoring/mcp-health-check.sh restart

# Check individual server
claude mcp list | grep server-name
```

### High Response Time

```bash
# Clear npm cache
npm cache clean --force

# Pre-install package globally
npm install -g package-name@latest

# Check network
ping registry.npmjs.org
```

### Authentication Issues

```bash
# linear requires token
export LINEAR_API_TOKEN="your-token-here"

# cloudflare-dns requires API key
# Already configured in mcp.json
```

---

## Configuration Files

| File | Purpose | Servers |
|------|---------|---------|
| .claude/mcp.json | **Primary config** | All 26 |
| .mcp.json | Legacy config | ruv-swarm only |
| .cursor/mcp.json | Cursor IDE | Laravel-specific |
| src/.cursor/mcp.json | Cursor IDE subset | Minimal |

**Use .claude/mcp.json as single source of truth**

---

## Monitoring

### Health Status
```bash
# View current status
cat logs/mcp-monitoring/mcp-health-status.json | jq

# Real-time monitoring
tail -f logs/mcp-monitoring/mcp-alerts.log
```

### Prometheus Metrics
- Port: 9099
- Path: /metrics
- Metrics include:
  - mcp_server_up
  - mcp_server_response_time_seconds
  - mcp_health_check_success

---

## Maintenance Schedule

### Daily (Automated)
- Health checks every 5 minutes
- Auto-restart daemon monitoring

### Weekly
- Review health reports
- Check for package updates
- Review logs for warnings

### Monthly
- Audit MCP configurations
- Update documentation
- Performance tuning
- Security updates

---

## Support

- **Documentation**: /docs/mcp-*.md
- **Scripts**: /scripts/mcp-monitoring/
- **Logs**: /logs/mcp-monitoring/
- **Task**: AGL-25 (MCP Server Optimization)

---

**Last Updated**: 2026-02-10
**Next Review**: 2026-03-10
