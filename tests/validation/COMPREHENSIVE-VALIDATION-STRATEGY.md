# Comprehensive Validation & Testing Strategy
## AGL-Hostman Implementation Quality Assurance

> **Created**: 2025-10-29
> **Version**: 1.0.0
> **Agent**: Tester Worker 4 (Hive Mind Swarm)
> **Objective**: Ensure quality and completeness of all implementation components

---

## Executive Summary

This document provides a comprehensive testing and validation strategy for implementing improvements from the **agl-hostman** project into the **crowbar** project. The strategy covers documentation validation, configuration testing, integration verification, and performance benchmarking.

### Testing Philosophy

- **Fail-Fast**: Detect issues early in the implementation cycle
- **Defense in Depth**: Multiple validation layers at each stage
- **Automated Where Possible**: Reduce manual testing overhead
- **Evidence-Based**: All validations must produce verifiable output
- **Rollback-Ready**: Clear procedures for reverting changes if needed

---

## 1. Pre-Implementation Validation

### 1.1 Environment Verification

**Objective**: Ensure target environment meets all prerequisites before implementation begins.

#### Checklist

- [ ] **Source Project Audit** (agl-hostman)
  ```bash
  # Verify source project structure
  cd /mnt/overpower/apps/dev/agl/agl-hostman
  git status
  git log --oneline -10
  ls -la docs/
  ```
  - Expected: Clean git status or documented modifications
  - Expected: Presence of INFRA.md, ARCHON.md, WORKFLOWS.md, RULES.md, QUICK-START.md, DOKPLOY.md
  - Expected: Recent commits with clear documentation

- [ ] **Target Project Audit** (crowbar)
  ```bash
  # Verify target project structure
  cd /mnt/overpower/apps/dev/agl/crowbar
  git status
  git branch -a
  ls -la
  ```
  - Expected: Clean working directory or feature branch ready
  - Expected: No conflicting files or pending merges
  - Expected: Adequate disk space (min 1GB free)

- [ ] **Network Connectivity**
  ```bash
  # Test WireGuard mesh connectivity
  ping -c 3 10.6.0.21  # CT183 Archon (WireGuard)
  ping -c 3 10.6.0.12  # AGLSRV6 (WireGuard)

  # Test Tailscale connectivity
  ping -c 3 100.80.30.59  # CT183 Archon (Tailscale)

  # Test LAN connectivity
  ping -c 3 192.168.0.245  # AGLSRV1 host
  ```
  - Expected: <10ms latency for WireGuard
  - Expected: <50ms latency for Tailscale
  - Expected: <5ms latency for LAN

- [ ] **Archon MCP Endpoint Availability**
  ```bash
  # Test Archon MCP endpoints
  curl -s http://10.6.0.21:8051/mcp | jq .
  curl -s http://100.80.30.59:8051/mcp | jq .
  curl -s http://192.168.0.183:8052/mcp | jq .

  # Verify Claude MCP configuration
  claude mcp list
  ```
  - Expected: HTTP 200 response from all endpoints
  - Expected: Valid JSON response with MCP schema
  - Expected: 3 Archon endpoints listed (archon-wg, archon-tailscale, archon)

- [ ] **Harbor Registry Connectivity**
  ```bash
  # Test Harbor registry access
  curl -k https://harbor.aglz.io:5000/v2/_catalog
  docker login harbor.aglz.io:5000
  docker pull harbor.aglz.io:5000/library/hello-world:latest
  ```
  - Expected: HTTP 200 or 401 (auth required)
  - Expected: Successful login with credentials
  - Expected: Successful image pull

- [ ] **Dokploy Platform Access**
  ```bash
  # Test Dokploy platform availability
  curl -I https://dok.aglz.io

  # Check CT180 container status
  ssh root@192.168.0.245 'pct list | grep 180'
  ssh root@192.168.0.180 'docker ps | grep dokploy'
  ```
  - Expected: HTTP 200 or 302 (redirect to login)
  - Expected: CT180 running status
  - Expected: Dokploy containers operational

- [ ] **Storage Mounts Validation**
  ```bash
  # Verify NFS mounts
  df -h | grep -E '(fgsrv6|aglfs1)'
  mount | grep nfs

  # Test write access
  touch /mnt/pve/fgsrv6-wg/test-$(date +%s).tmp
  ```
  - Expected: NFS mounts present and accessible
  - Expected: Successful write to shared storage
  - Expected: No stale mount errors

### 1.2 Documentation Inventory

**Objective**: Catalog all documentation files to be migrated/adapted.

#### Documentation Matrix

| Source File | Purpose | Migration Required | Validation Method |
|-------------|---------|-------------------|-------------------|
| `CLAUDE.md` | Main project config | YES - Full adaptation | Syntax check, link validation |
| `docs/INFRA.md` | Infrastructure map | YES - Adapt to crowbar | Network verification |
| `docs/ARCHON.md` | Archon integration | YES - Update endpoints | MCP tool testing |
| `docs/WORKFLOWS.md` | Agent workflows | YES - Adapt workflows | Workflow execution test |
| `docs/RULES.md` | Coding standards | YES - Apply standards | Code review |
| `docs/QUICK-START.md` | Fast reference | YES - Update commands | Command execution |
| `docs/DOKPLOY.md` | Deployment guide | YES - Adapt config | Deployment test |

**Validation Script**:
```bash
#!/bin/bash
# Document inventory validation
SOURCE_DIR="/mnt/overpower/apps/dev/agl/agl-hostman"
TARGET_DIR="/mnt/overpower/apps/dev/agl/crowbar"

echo "=== Documentation Inventory ==="
for doc in CLAUDE.md docs/{INFRA,ARCHON,WORKFLOWS,RULES,QUICK-START,DOKPLOY}.md; do
  if [ -f "$SOURCE_DIR/$doc" ]; then
    echo "✓ Found: $doc ($(wc -l < "$SOURCE_DIR/$doc") lines)"
  else
    echo "✗ Missing: $doc"
  fi
done
```

---

## 2. Component-Specific Validation

### 2.1 CLAUDE.md Migration Validation

**Objective**: Ensure CLAUDE.md is correctly adapted with project-specific paths and context.

#### Validation Checklist

- [ ] **Path Replacement Verification**
  ```bash
  # Check for hardcoded agl-hostman paths
  grep -r "agl-hostman" /mnt/overpower/apps/dev/agl/crowbar/CLAUDE.md
  # Expected: No matches (all replaced with crowbar)

  # Verify working directory
  grep "Working Directory" /mnt/overpower/apps/dev/agl/crowbar/CLAUDE.md
  # Expected: Shows /root/crowbar or /mnt/overpower/apps/dev/agl/crowbar
  ```

- [ ] **Link Validation**
  ```bash
  # Extract all @docs/ references
  grep -o '@docs/[^)]*\.md' /mnt/overpower/apps/dev/agl/crowbar/CLAUDE.md

  # Verify all referenced files exist
  for doc in $(grep -o '@docs/[^)]*\.md' /mnt/overpower/apps/dev/agl/crowbar/CLAUDE.md | sed 's/@//'); do
    if [ -f "/mnt/overpower/apps/dev/agl/crowbar/$doc" ]; then
      echo "✓ $doc exists"
    else
      echo "✗ $doc MISSING"
    fi
  done
  ```

- [ ] **Markdown Syntax Validation**
  ```bash
  # Install markdownlint if not present
  npm install -g markdownlint-cli

  # Run markdown linting
  markdownlint /mnt/overpower/apps/dev/agl/crowbar/CLAUDE.md

  # Check for broken internal links
  markdown-link-check /mnt/overpower/apps/dev/agl/crowbar/CLAUDE.md
  ```

- [ ] **Project Context Accuracy**
  - Manual review: Does "Project Context" section accurately describe crowbar?
  - Manual review: Are infrastructure references still valid?
  - Manual review: Are git repository references updated?

**Success Criteria**:
- ✅ No hardcoded agl-hostman paths remaining
- ✅ All @docs/ references point to existing files
- ✅ Markdown syntax valid (no linting errors)
- ✅ Internal links resolve correctly
- ✅ Project context accurately reflects crowbar

### 2.2 Infrastructure Documentation Validation

**Objective**: Verify INFRA.md accurately reflects network topology and connection matrix.

#### Validation Tests

- [ ] **Network Topology Verification**
  ```bash
  # Test each documented WireGuard peer
  wg show | grep -E '(endpoint|allowed|latest)'

  # Verify documented IPs are reachable
  for ip in 10.6.0.5 10.6.0.12 10.6.0.21; do
    if ping -c 1 -W 2 $ip &>/dev/null; then
      echo "✓ $ip reachable"
    else
      echo "✗ $ip unreachable"
    fi
  done
  ```

- [ ] **Container Inventory Accuracy**
  ```bash
  # Compare documented containers with actual
  ssh root@192.168.0.245 'pct list' > /tmp/actual-containers.txt

  # Extract container IDs from INFRA.md
  grep -oP 'CT\d+' /mnt/overpower/apps/dev/agl/crowbar/docs/INFRA.md | sort -u > /tmp/documented-containers.txt

  # Compare
  diff /tmp/actual-containers.txt /tmp/documented-containers.txt
  ```

- [ ] **Storage Mount Documentation**
  ```bash
  # Verify all documented NFS mounts
  grep -E '/mnt/pve' /mnt/overpower/apps/dev/agl/crowbar/docs/INFRA.md | \
  while read mount; do
    if mount | grep -q "$mount"; then
      echo "✓ Mount present: $mount"
    else
      echo "✗ Mount missing: $mount"
    fi
  done
  ```

**Success Criteria**:
- ✅ All WireGuard peers reachable with <10ms latency
- ✅ Container inventory matches actual Proxmox state
- ✅ All documented mounts are active and accessible
- ✅ Connection matrix reflects current network topology

### 2.3 Archon MCP Integration Validation

**Objective**: Verify all Archon MCP tools function correctly with crowbar project.

#### MCP Tool Testing Matrix

| Tool Name | Test Method | Expected Result | Status |
|-----------|-------------|-----------------|--------|
| `health_check` | Direct call | Service healthy | ⬜ |
| `session_info` | Direct call | Active sessions | ⬜ |
| `rag_search_knowledge_base` | Query "wireguard" | Relevant results | ⬜ |
| `rag_search_code_examples` | Query "docker" | Code snippets | ⬜ |
| `rag_read_full_page` | Read specific page | Full content | ⬜ |
| `find_projects` | List all | Project list | ⬜ |
| `manage_project` | Create test project | Success | ⬜ |
| `find_tasks` | List tasks | Task list | ⬜ |
| `manage_task` | Create test task | Success | ⬜ |
| `find_documents` | Query docs | Document list | ⬜ |

**Validation Script**:
```bash
#!/bin/bash
# Archon MCP Tool Validation

echo "=== Archon MCP Tool Validation ==="

# 1. Health Check
echo "Testing: mcp__archon__health_check"
# (Requires Claude Code MCP integration)

# 2. Knowledge Base Search
echo "Testing: rag_search_knowledge_base"
# Expected: Results for infrastructure documentation

# 3. Project Management
echo "Testing: manage_project (create)"
# Expected: New project created successfully

# 4. Task Management
echo "Testing: manage_task (create)"
# Expected: New task created successfully

# Store results in validation report
```

**Success Criteria**:
- ✅ All 28 MCP tools respond without errors
- ✅ Health check returns "healthy" status
- ✅ Knowledge base queries return relevant results
- ✅ Project/task CRUD operations succeed
- ✅ Response times <2 seconds per operation

### 2.4 Harbor Registry Integration Validation

**Objective**: Verify Harbor registry connectivity and Dokploy integration.

#### Harbor Validation Tests

- [ ] **Registry Access**
  ```bash
  # Test anonymous read access
  curl -k https://harbor.aglz.io:5000/v2/_catalog

  # Test authenticated access
  docker login harbor.aglz.io:5000 -u admin -p <password>
  docker pull harbor.aglz.io:5000/library/hello-world:latest
  ```

- [ ] **Webhook Configuration**
  ```bash
  # Test webhook endpoint from Harbor perspective
  curl -X POST https://dok.aglz.io/webhooks/<project-webhook-id> \
    -H "Content-Type: application/json" \
    -d '{"type":"test","event_type":"webhook_test"}'
  ```

- [ ] **Image Push/Pull Cycle**
  ```bash
  # Build test image
  docker build -t harbor.aglz.io:5000/crowbar/test:latest .

  # Push to Harbor
  docker push harbor.aglz.io:5000/crowbar/test:latest

  # Pull from different machine
  docker pull harbor.aglz.io:5000/crowbar/test:latest
  ```

**Success Criteria**:
- ✅ Registry catalog accessible (HTTP 200)
- ✅ Authentication succeeds
- ✅ Image push/pull completes within 60s
- ✅ Webhook triggers Dokploy deployment

### 2.5 Dokploy Deployment Validation

**Objective**: Verify Dokploy platform configuration and deployment workflows.

#### Deployment Validation Tests

- [ ] **Platform Accessibility**
  ```bash
  # Check web interface
  curl -I https://dok.aglz.io

  # Verify SSL certificate
  openssl s_client -connect dok.aglz.io:443 -servername dok.aglz.io < /dev/null
  ```

- [ ] **Project Configuration**
  - Manual: Log into https://dok.aglz.io
  - Manual: Verify crowbar project exists
  - Manual: Check deployment settings (Docker Image vs Git)
  - Manual: Verify environment variables configured

- [ ] **Deployment Test**
  ```bash
  # Trigger manual deployment via webhook
  curl -X POST https://dok.aglz.io/webhooks/<project-webhook>

  # Monitor deployment logs
  # (Via Dokploy web UI)

  # Verify container running
  ssh root@192.168.0.180 'docker ps | grep crowbar'
  ```

- [ ] **Rollback Test**
  - Manual: Trigger deployment to previous version
  - Manual: Verify service availability during rollback
  - Manual: Check rollback completes within 5 minutes

**Success Criteria**:
- ✅ Dokploy web interface accessible with valid SSL
- ✅ Project configuration complete and accurate
- ✅ Deployment completes successfully within 10 minutes
- ✅ Rollback procedure tested and functional

---

## 3. Integration Testing

### 3.1 End-to-End Workflow Validation

**Objective**: Validate complete workflows from documentation to deployment.

#### Workflow Test Scenarios

**Scenario 1: Agent OS Workflow Execution**

```bash
# Test: Create tasks from spec
cd /mnt/overpower/apps/dev/agl/crowbar
claude /create-tasks --spec "Add new feature X"

# Expected:
# - Tasks created in Archon via MCP
# - Todo list generated
# - File structure created in proper directories

# Validation:
mcp__archon__find_tasks(filter_by="status", filter_value="todo")
# Expected: New tasks visible with correct status
```

**Scenario 2: SPARC Methodology Execution**

```bash
# Phase 1: Specification
# - Create specification document
# - Validate against requirements

# Phase 2: Pseudocode
# - Generate algorithm design
# - Review logic flow

# Phase 3: Architecture
# - Design system components
# - Plan integration points

# Phase 4: Refinement
# - TDD implementation
# - Unit test creation

# Phase 5: Completion
# - Integration testing
# - Deployment validation
```

**Scenario 3: Infrastructure Deployment**

```bash
# 1. Code changes committed
git add .
git commit -m "feat: implement feature X"
git push origin develop

# 2. CI/CD triggered (GitHub Actions or direct webhook)
# 3. Harbor receives webhook
# 4. Dokploy pulls new image
# 5. Zero-downtime deployment

# Validation:
# - Check GitHub Actions status
# - Verify Harbor webhook fired
# - Monitor Dokploy deployment logs
# - Test service availability
```

### 3.2 Agent Coordination Testing

**Objective**: Verify swarm agents communicate and coordinate effectively.

#### Agent Communication Tests

- [ ] **Memory Coordination**
  ```javascript
  // Test: Researcher shares findings
  mcp__claude-flow__memory_usage({
    action: "store",
    key: "swarm/researcher/findings",
    namespace: "coordination",
    value: JSON.stringify({
      agent: "researcher",
      findings: ["Key insight 1", "Key insight 2"],
      timestamp: Date.now()
    })
  })

  // Test: Coder retrieves findings
  mcp__claude-flow__memory_usage({
    action: "retrieve",
    key: "swarm/researcher/findings",
    namespace: "coordination"
  })

  // Expected: Findings successfully retrieved by coder
  ```

- [ ] **Task Status Synchronization**
  ```javascript
  // Test: Coder updates implementation status
  mcp__claude-flow__memory_usage({
    action: "store",
    key: "swarm/coder/status",
    namespace: "coordination",
    value: JSON.stringify({
      agent: "coder",
      status: "implementation_complete",
      files_modified: ["src/index.js", "src/config.js"],
      timestamp: Date.now()
    })
  })

  // Test: Tester checks implementation status
  mcp__claude-flow__memory_usage({
    action: "retrieve",
    key: "swarm/coder/status",
    namespace: "coordination"
  })

  // Expected: Tester sees implementation complete
  ```

- [ ] **Result Sharing**
  ```javascript
  // Test: Tester shares test results
  mcp__claude-flow__memory_usage({
    action: "store",
    key: "swarm/shared/test-results",
    namespace: "coordination",
    value: JSON.stringify({
      passed: 45,
      failed: 2,
      coverage: "87%",
      failures: ["test1.js:23", "test2.js:45"]
    })
  })

  // Expected: All agents can access shared results
  ```

**Success Criteria**:
- ✅ Memory operations complete within 500ms
- ✅ Cross-agent data retrieval successful
- ✅ No data loss or corruption
- ✅ Namespace isolation maintained

---

## 4. Performance & Quality Metrics

### 4.1 Documentation Quality Metrics

**Objective**: Ensure documentation meets quality standards.

#### Quality Checklist

- [ ] **Completeness** (100% coverage)
  - All major components documented
  - All workflows described
  - All integration points explained
  - All troubleshooting scenarios covered

- [ ] **Accuracy** (Zero errors)
  - All paths verified to exist
  - All commands tested and working
  - All network addresses current
  - All configuration examples valid

- [ ] **Clarity** (Readable by humans)
  - Clear headings and structure
  - Examples provided for complex topics
  - Diagrams where helpful
  - Consistent terminology

- [ ] **Maintainability** (Easy to update)
  - Modular structure (separate files)
  - Cross-references clear
  - Version information present
  - Last updated dates tracked

**Measurement**:
```bash
# Documentation coverage score
TOTAL_COMPONENTS=10
DOCUMENTED_COMPONENTS=$(grep -c "## Component" docs/*.md)
COVERAGE=$((DOCUMENTED_COMPONENTS * 100 / TOTAL_COMPONENTS))
echo "Documentation coverage: ${COVERAGE}%"

# Link validation
find docs -name "*.md" -exec markdown-link-check {} \; | grep -c "✖"
# Expected: 0 broken links
```

### 4.2 Performance Benchmarks

**Objective**: Establish baseline performance and track improvements.

#### Benchmark Categories

**Network Latency**:
```bash
# WireGuard mesh (target: <10ms)
ping -c 100 10.6.0.21 | tail -1

# Tailscale overlay (target: <50ms)
ping -c 100 100.80.30.59 | tail -1

# LAN (target: <5ms)
ping -c 100 192.168.0.245 | tail -1
```

**MCP Tool Response Time**:
```bash
# Knowledge base query (target: <2s)
time mcp__archon__rag_search_knowledge_base(query="docker", match_count=5)

# Project creation (target: <1s)
time mcp__archon__manage_project("create", title="Test", description="Benchmark")

# Task query (target: <500ms)
time mcp__archon__find_tasks(filter_by="status", filter_value="todo")
```

**Deployment Speed**:
```bash
# Harbor image push (target: <60s for 100MB image)
time docker push harbor.aglz.io:5000/crowbar/test:latest

# Dokploy deployment (target: <10min for full deployment)
# Measured from webhook trigger to service availability
```

**Agent Coordination**:
```bash
# Memory operation (target: <500ms)
time mcp__claude-flow__memory_usage(action="store", key="test", value="data")

# Cross-agent communication (target: <1s round-trip)
# Measured from store by agent A to retrieve by agent B
```

#### Performance Targets

| Metric | Baseline | Target | Threshold |
|--------|----------|--------|-----------|
| WireGuard Latency | ? | <10ms | <20ms |
| Tailscale Latency | ? | <50ms | <100ms |
| MCP Query Time | ? | <2s | <5s |
| Deployment Time | ? | <10min | <15min |
| Memory Ops | ? | <500ms | <1s |
| Agent Coordination | ? | <1s | <2s |

### 4.3 Test Coverage Metrics

**Objective**: Ensure adequate test coverage for critical paths.

#### Coverage Requirements

- **Unit Tests**: >80% code coverage
- **Integration Tests**: All critical workflows
- **E2E Tests**: All user-facing features
- **Performance Tests**: All documented benchmarks

**Validation**:
```bash
# Run test suite with coverage
npm test -- --coverage

# Expected output:
# ----------------------------|---------|----------|---------|---------|
# File                        | % Stmts | % Branch | % Funcs | % Lines |
# ----------------------------|---------|----------|---------|---------|
# All files                   |   87.23 |    82.45 |   89.12 |   87.23 |
# ----------------------------|---------|----------|---------|---------|
```

---

## 5. Rollback Procedures

### 5.1 Documentation Rollback

**Objective**: Quickly revert documentation changes if issues found.

#### Rollback Steps

```bash
# 1. Identify commit to revert to
cd /mnt/overpower/apps/dev/agl/crowbar
git log --oneline docs/

# 2. Create rollback branch
git checkout -b rollback/docs-$(date +%Y%m%d)

# 3. Revert specific files
git checkout <previous-commit> -- docs/
git checkout <previous-commit> -- CLAUDE.md

# 4. Commit rollback
git commit -m "rollback: revert documentation to stable state"

# 5. Test documentation
# (Run validation checks)

# 6. Merge if validated
git checkout develop
git merge rollback/docs-$(date +%Y%m%d)
```

### 5.2 Configuration Rollback

**Objective**: Restore previous configuration if integration fails.

#### Rollback Steps

```bash
# 1. Backup current configuration
cp /mnt/overpower/apps/dev/agl/crowbar/.mcp.json \
   /mnt/overpower/apps/dev/agl/crowbar/.mcp.json.backup-$(date +%s)

# 2. Restore previous configuration
git checkout HEAD~1 -- .mcp.json

# 3. Restart MCP server
claude mcp restart

# 4. Verify MCP tools
claude mcp list
```

### 5.3 Deployment Rollback

**Objective**: Quickly restore service if deployment fails.

#### Rollback Steps (Dokploy)

```bash
# 1. Access Dokploy UI
open https://dok.aglz.io

# 2. Navigate to crowbar project

# 3. Click "Rollback" button

# 4. Select previous stable deployment

# 5. Confirm rollback

# 6. Monitor rollback progress
# Expected: <5 minutes to complete

# 7. Verify service availability
curl -I https://crowbar.aglz.io
# Expected: HTTP 200 OK
```

#### Rollback Steps (Manual Docker)

```bash
# 1. List recent images
docker images | grep crowbar

# 2. Stop current container
docker stop crowbar

# 3. Remove current container
docker rm crowbar

# 4. Start previous version
docker run -d --name crowbar \
  harbor.aglz.io:5000/crowbar/app:<previous-tag>

# 5. Verify service
docker ps | grep crowbar
curl -I http://localhost:3000
```

---

## 6. Continuous Validation

### 6.1 Automated Health Checks

**Objective**: Continuously monitor system health post-implementation.

#### Health Check Script

```bash
#!/bin/bash
# /scripts/health-check.sh

echo "=== System Health Check ==="
echo "Timestamp: $(date)"

# Network connectivity
echo "Network Connectivity:"
ping -c 1 10.6.0.21 &>/dev/null && echo "✓ Archon (WG)" || echo "✗ Archon (WG)"
ping -c 1 192.168.0.245 &>/dev/null && echo "✓ AGLSRV1" || echo "✗ AGLSRV1"

# Archon MCP
echo "Archon MCP:"
curl -sf http://10.6.0.21:8051/mcp &>/dev/null && echo "✓ MCP Endpoint" || echo "✗ MCP Endpoint"

# Harbor Registry
echo "Harbor Registry:"
curl -skf https://harbor.aglz.io:5000/v2/_catalog &>/dev/null && echo "✓ Registry" || echo "✗ Registry"

# Dokploy Platform
echo "Dokploy Platform:"
curl -sf https://dok.aglz.io &>/dev/null && echo "✓ Platform" || echo "✗ Platform"

# Storage Mounts
echo "Storage Mounts:"
[ -d /mnt/pve/fgsrv6-wg ] && echo "✓ NFS WG" || echo "✗ NFS WG"

# Exit code based on failures
```

**Cron Schedule**:
```bash
# Run every 5 minutes
*/5 * * * * /mnt/overpower/apps/dev/agl/crowbar/scripts/health-check.sh >> /var/log/crowbar-health.log 2>&1
```

### 6.2 Documentation Drift Detection

**Objective**: Alert when documentation becomes outdated.

#### Drift Detection Script

```bash
#!/bin/bash
# /scripts/docs-drift-check.sh

# Compare documented containers vs actual
DOCUMENTED=$(grep -oP 'CT\d+' docs/INFRA.md | sort -u)
ACTUAL=$(ssh root@192.168.0.245 'pct list | awk "{print \$1}"' | grep -v VMID | sort -u)

if [ "$DOCUMENTED" != "$ACTUAL" ]; then
  echo "WARNING: Container inventory drift detected"
  diff <(echo "$DOCUMENTED") <(echo "$ACTUAL")
  # Send alert
fi

# Compare documented IPs vs active IPs
# Compare documented mounts vs active mounts
# etc.
```

### 6.3 Performance Monitoring

**Objective**: Track performance metrics over time.

#### Monitoring Script

```bash
#!/bin/bash
# /scripts/performance-monitor.sh

LOGFILE="/var/log/crowbar-performance.log"

# Network latency
WG_LATENCY=$(ping -c 10 10.6.0.21 | tail -1 | awk -F'/' '{print $5}')
echo "$(date +%s),wg_latency,$WG_LATENCY" >> $LOGFILE

# MCP response time
START=$(date +%s%N)
# (Execute MCP query)
END=$(date +%s%N)
MCP_TIME=$(( (END - START) / 1000000 ))
echo "$(date +%s),mcp_response,$MCP_TIME" >> $LOGFILE

# Generate weekly report
if [ $(date +%u) -eq 1 ]; then
  # Create performance summary
  # Send email report
fi
```

---

## 7. Success Criteria Summary

### 7.1 Critical Success Factors

**All must pass for implementation approval**:

- ✅ **Documentation Validation**
  - All files present and syntactically correct
  - All links resolve
  - All paths accurate
  - Coverage >90%

- ✅ **Integration Testing**
  - Archon MCP: All 28 tools functional
  - Harbor: Image push/pull successful
  - Dokploy: Deployment completes <10min
  - Network: All endpoints reachable

- ✅ **Performance Benchmarks**
  - WireGuard latency <20ms
  - MCP query time <5s
  - Deployment time <15min
  - Memory ops <1s

- ✅ **Agent Coordination**
  - Cross-agent communication functional
  - Task status synchronization working
  - Memory persistence confirmed
  - No data loss or corruption

- ✅ **Rollback Procedures**
  - Documentation rollback tested
  - Configuration rollback tested
  - Deployment rollback tested
  - All complete within 10 minutes

### 7.2 Quality Gates

**Implementation cannot proceed past each gate without validation**:

**Gate 1: Pre-Implementation**
- Environment verified
- Prerequisites met
- Baseline metrics captured

**Gate 2: Documentation**
- All files migrated
- Syntax validated
- Links checked
- Paths corrected

**Gate 3: Configuration**
- MCP endpoints configured
- Harbor integration tested
- Dokploy project created
- Network validated

**Gate 4: Integration**
- End-to-end workflows tested
- Agent coordination verified
- Performance benchmarks met
- Rollback procedures validated

**Gate 5: Production**
- Health checks passing
- Monitoring enabled
- Documentation current
- Team trained

---

## 8. Testing Tools & Automation

### 8.1 Validation Scripts

**Location**: `/tests/validation/scripts/`

```bash
/tests/validation/scripts/
├── 01-pre-implementation-check.sh
├── 02-documentation-validation.sh
├── 03-mcp-tool-testing.sh
├── 04-harbor-integration-test.sh
├── 05-dokploy-deployment-test.sh
├── 06-performance-benchmark.sh
├── 07-rollback-procedure-test.sh
└── 08-full-validation-suite.sh
```

### 8.2 Automated Test Execution

**Master Validation Script**:
```bash
#!/bin/bash
# /tests/validation/scripts/08-full-validation-suite.sh

set -e

echo "=== Crowbar Implementation Validation Suite ==="
echo "Started: $(date)"

# Execute all validation scripts in sequence
for script in /tests/validation/scripts/0[1-7]-*.sh; do
  echo "Running: $(basename $script)"
  if bash "$script"; then
    echo "✓ PASS: $(basename $script)"
  else
    echo "✗ FAIL: $(basename $script)"
    exit 1
  fi
done

echo "=== Validation Complete ==="
echo "Finished: $(date)"
echo "All tests passed ✓"
```

### 8.3 Continuous Integration

**GitHub Actions Workflow**:
```yaml
# .github/workflows/validation.yml
name: Validation Suite

on:
  push:
    branches: [develop, main]
  pull_request:
    branches: [develop, main]

jobs:
  validate:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v3

      - name: Run Validation Suite
        run: bash /tests/validation/scripts/08-full-validation-suite.sh

      - name: Upload Test Results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: validation-results
          path: /tests/validation/results/
```

---

## 9. Reporting & Documentation

### 9.1 Test Report Format

**Template**: `/tests/validation/reports/TEMPLATE.md`

```markdown
# Validation Report - [Component Name]
**Date**: YYYY-MM-DD
**Tester**: [Agent Name]
**Status**: PASS / FAIL / PARTIAL

## Summary
Brief overview of validation results.

## Test Execution
- Total Tests: X
- Passed: Y
- Failed: Z
- Skipped: N

## Detailed Results
### Test 1: [Test Name]
- **Status**: PASS/FAIL
- **Duration**: Xs
- **Notes**: ...

## Issues Discovered
1. Issue description
   - Severity: Critical/High/Medium/Low
   - Reproducible: Yes/No
   - Workaround: ...

## Recommendations
- Recommendation 1
- Recommendation 2

## Approval
- [ ] Approved for next phase
- [ ] Requires remediation
```

### 9.2 Metrics Dashboard

**Grafana Dashboard** (if available):
- MCP tool response times
- Network latency trends
- Deployment frequency
- Rollback rate
- Test pass rate

**Simple Metrics Log**:
```bash
# /var/log/crowbar-metrics.log
timestamp,metric_name,value,unit
1698624000,mcp_query_time,1234,ms
1698624000,wg_latency,8.3,ms
1698624000,deployment_time,456,s
```

---

## 10. Next Steps

### 10.1 Immediate Actions

1. **Create Validation Scripts**
   - Write all 8 validation scripts
   - Test scripts in isolated environment
   - Document script usage

2. **Establish Baselines**
   - Run performance benchmarks
   - Capture current metrics
   - Document baseline values

3. **Set Up Monitoring**
   - Configure health checks
   - Enable drift detection
   - Set up alerting

### 10.2 Coordination with Swarm

**Waiting For**:
- **Researcher**: Findings on crowbar project structure
- **Analyst**: Gap analysis between agl-hostman and crowbar
- **Coder**: Implementation plan and timeline

**Ready to Provide**:
- Validation criteria for each implementation phase
- Test scripts for automated validation
- Performance benchmarks and targets
- Rollback procedures if issues arise

---

## Appendix A: Test Data

### Sample Test Cases

```javascript
// Test Case 1: MCP Knowledge Base Query
{
  "test_id": "MCP-KB-001",
  "description": "Query Archon knowledge base for infrastructure docs",
  "input": {
    "query": "wireguard mesh configuration",
    "match_count": 5
  },
  "expected": {
    "status": "success",
    "result_count": 5,
    "response_time": "<2s"
  }
}

// Test Case 2: Harbor Image Push
{
  "test_id": "HARBOR-001",
  "description": "Push test image to Harbor registry",
  "input": {
    "image": "test:latest",
    "size": "100MB"
  },
  "expected": {
    "status": "success",
    "push_time": "<60s",
    "image_available": true
  }
}

// Test Case 3: Dokploy Deployment
{
  "test_id": "DOKPLOY-001",
  "description": "Deploy via webhook trigger",
  "input": {
    "webhook_url": "https://dok.aglz.io/webhooks/...",
    "payload": {"event": "push"}
  },
  "expected": {
    "status": "success",
    "deployment_time": "<10min",
    "service_available": true
  }
}
```

---

## Appendix B: Troubleshooting Guide

### Common Validation Failures

**Issue**: MCP endpoint unreachable
**Cause**: Archon container stopped or network issue
**Resolution**:
```bash
# Check Archon container
ssh root@192.168.0.245 'pct status 183'

# Restart if stopped
ssh root@192.168.0.245 'pct start 183'

# Verify WireGuard connectivity
wg show
ping 10.6.0.21
```

**Issue**: Harbor authentication fails
**Cause**: Incorrect credentials or certificate issue
**Resolution**:
```bash
# Check credentials
docker login harbor.aglz.io:5000

# Accept self-signed cert
mkdir -p /etc/docker/certs.d/harbor.aglz.io:5000
curl -k https://harbor.aglz.io:5000/ca.crt > /etc/docker/certs.d/harbor.aglz.io:5000/ca.crt
```

**Issue**: Dokploy deployment stalls
**Cause**: Resource limits or image pull timeout
**Resolution**:
```bash
# Check Dokploy logs
ssh root@192.168.0.180 'docker logs dokploy'

# Verify resource availability
ssh root@192.168.0.180 'free -h && df -h'

# Manual deployment trigger
curl -X POST https://dok.aglz.io/webhooks/...
```

---

## Document Control

**Version History**:
- v1.0.0 (2025-10-29): Initial validation strategy created by Tester Worker 4

**Reviewers**:
- [ ] Researcher Worker 1 (findings validation)
- [ ] Analyst Worker 3 (gap analysis validation)
- [ ] Coder Worker 2 (implementation validation)

**Approval**:
- [ ] All agents consensus achieved
- [ ] Ready for implementation phase

---

**End of Validation Strategy Document**
