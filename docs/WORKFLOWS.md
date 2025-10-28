# Development Workflows & Methodologies

> **Last Updated**: 2025-10-28 | **Version**: 1.0.0

**Purpose**: Development workflows, methodologies, and tool integration for AGL infrastructure management.

**When to read**: When implementing features, using SPARC/Agent OS, or following development workflows.

---

## 📑 Table of Contents

1. [Agent OS Integration](#-agent-os-integration---spec-driven-development)
2. [SPARC Methodology](#-sparc-methodology)
3. [Code Style & Best Practices](#-code-style--best-practices)
4. [Available Agents](#-available-agents-54-total)
5. [MCP Tool Categories](#-mcp-tool-categories)

---

## 📦 Agent OS Integration - SPEC-DRIVEN DEVELOPMENT

### Overview

Agent OS provides a specification-driven development framework with 7 commands and 16 skills for infrastructure management workflows.

**Installation**:
```bash
npm install -g @agentos/cli
agentos init
```

**Core Philosophy**: Spec-first development with automated agent coordination.

---

### Available Commands (7 Total)

1. **`agentos spec`** - Create/manage workflow specifications
   - `agentos spec create <name>` - New spec from template
   - `agentos spec validate` - Validate spec syntax
   - `agentos spec list` - Show all specs

2. **`agentos run`** - Execute workflows from specs
   - `agentos run <spec-file>` - Execute specific spec
   - `agentos run --interactive` - Step-through mode
   - `agentos run --dry-run` - Preview without execution

3. **`agentos agent`** - Agent management
   - `agentos agent list` - Show available agents
   - `agentos agent spawn <type>` - Create new agent
   - `agentos agent status` - Agent health

4. **`agentos skill`** - Skill system management
   - `agentos skill list` - Available skills
   - `agentos skill install <name>` - Add new skill
   - `agentos skill update` - Update skills

5. **`agentos memory`** - Persistent memory operations
   - `agentos memory store <key> <value>` - Save data
   - `agentos memory get <key>` - Retrieve data
   - `agentos memory clear` - Reset memory

6. **`agentos status`** - System health and metrics
   - Shows active agents, workflows, memory usage
   - Performance metrics and bottlenecks

7. **`agentos config`** - Configuration management
   - `agentos config set <key> <value>`
   - `agentos config get <key>`
   - `agentos config reset`

---

### Skills System (16 Total)

**Infrastructure Skills** (5):
- `condition-based-waiting` - Replace arbitrary timeouts with condition polling
- `verification-before-completion` - Run verification before claiming success
- `receiving-code-review` - Handle code review feedback properly
- `requesting-code-review` - Dispatch code reviewer before completion
- `testing-anti-patterns` - Prevent testing mock behavior and test pollution

**Development Skills** (4):
- `using-superpowers` - Find and use skills effectively
- `sharing-skills` - Contribute skills back to upstream
- `testing-skills-with-subagents` - Test skills under pressure
- `skill-builder` - Create new Claude Code Skills

**Infrastructure Automation** (7 managed):
- `agentdb-*` - Advanced vector database features (5 skills)
- `flow-nexus-*` - Cloud platform integration
- `github-*` - Repository management (5 skills)
- `hive-mind-advanced` - Multi-agent coordination
- `hooks-automation` - Automated pre/post operation hooks
- `pair-programming` - AI-assisted pair programming modes
- `performance-analysis` - Bottleneck detection
- `reasoningbank-*` - Adaptive learning (2 skills)
- `sparc-methodology` - SPARC development coordination
- `stream-chain` - Multi-agent pipelines
- `swarm-*` - Advanced swarm orchestration (2 skills)
- `verification-quality` - Truth scoring and rollback

**Usage**:
```bash
# Invoke skill
agentos skill use condition-based-waiting --task "wait for API ready"

# Or via Claude Code
Skill: condition-based-waiting
```

---

### Infrastructure Workflows (4 Specs)

#### 1. WireGuard Mesh Maintenance

**Spec**: `specs/wg-mesh-health.yaml`
```yaml
name: wireguard-mesh-health
description: Monitor and maintain WireGuard mesh connectivity
agents:
  - type: monitor
    task: Check peer status and latency
  - type: optimizer
    task: Optimize routing if latency > 50ms
schedule: "*/15 * * * *"  # Every 15 minutes
```

**Usage**:
```bash
agentos run specs/wg-mesh-health.yaml
```

---

#### 2. NFS Storage Health Check

**Spec**: `specs/nfs-storage-check.yaml`
```yaml
name: nfs-storage-health
description: Verify NFS mounts and storage health
agents:
  - type: monitor
    task: Check mount status
  - type: analyst
    task: Analyze storage usage trends
conditions:
  - mount_accessible: true
  - usage < 90%
alerts:
  - slack: #infrastructure-alerts
```

**Usage**:
```bash
agentos run specs/nfs-storage-check.yaml --interactive
```

---

#### 3. Container Configuration Audit

**Spec**: `specs/container-audit.yaml`
```yaml
name: container-configuration-audit
description: Audit and validate container configurations
agents:
  - type: analyst
    task: Scan Docker Compose files
  - type: reviewer
    task: Check security best practices
output:
  format: markdown
  destination: docs/audit-reports/
```

**Usage**:
```bash
agentos run specs/container-audit.yaml
```

---

#### 4. Documentation Sync

**Spec**: `specs/docs-sync.yaml`
```yaml
name: documentation-sync
description: Keep documentation up-to-date with infrastructure
agents:
  - type: researcher
    task: Scan infrastructure for changes
  - type: documenter
    task: Update INFRA.md and ARCHON.md
triggers:
  - file_change: "*.conf"
  - file_change: "docker-compose.yml"
```

**Usage**:
```bash
agentos run specs/docs-sync.yaml --watch
```

---

### Integration with Archon MCP

Agent OS workflows can use Archon MCP tools for:
- Project management (`manage_project`, `manage_task`)
- Knowledge base operations (`rag_search_knowledge_base`)
- Document tracking (`manage_document`)

**Example**:
```yaml
name: archon-project-init
agents:
  - type: coordinator
    mcp_tools:
      - archon__manage_project
      - archon__manage_task
    task: Create project and initial tasks
```

---

### Environment-Specific Usage

**From WSL2** (Tailscale only):
```bash
# Remote execution via CT179
ssh root@100.94.221.87 'cd /root/agl-hostman && agentos run specs/wg-mesh-health.yaml'
```

**From CT179** (Full stack):
```bash
# Local execution with full network access
cd /root/agl-hostman
agentos run specs/wg-mesh-health.yaml
```

---

## 🎯 SPARC Methodology

### Overview

SPARC (Specification, Pseudocode, Architecture, Refinement, Completion) is a systematic Test-Driven Development methodology with Claude-Flow orchestration.

**Key Principle**: Design → Code → Test → Refine

---

### SPARC Commands

#### Core Commands
```bash
# List available modes
npx claude-flow sparc modes

# Execute specific mode
npx claude-flow sparc run <mode> "<task>"

# Complete TDD workflow
npx claude-flow sparc tdd "<feature>"

# Get mode details
npx claude-flow sparc info <mode>
```

#### Batch Tools
```bash
# Parallel execution
npx claude-flow sparc batch <modes> "<task>"

# Full pipeline processing
npx claude-flow sparc pipeline "<task>"

# Multi-task processing
npx claude-flow sparc concurrent <mode> "<tasks-file>"
```

#### Build Commands
```bash
npm run build      # Build project
npm run test       # Run tests
npm run lint       # Linting
npm run typecheck  # Type checking
```

---

### SPARC Workflow Phases

#### 1. Specification
**Command**: `npx claude-flow sparc run spec-pseudocode "<feature>"`

**Purpose**: Requirements analysis and high-level design

**Deliverables**:
- Functional requirements list
- Acceptance criteria
- User stories
- High-level algorithm design

**Example**:
```bash
npx claude-flow sparc run spec-pseudocode "Add WireGuard peer auto-discovery"
```

---

#### 2. Pseudocode
**Included in**: `spec-pseudocode` mode (combined with spec)

**Purpose**: Algorithm design without implementation details

**Deliverables**:
- Step-by-step algorithm
- Data structures
- Control flow
- Edge case handling

---

#### 3. Architecture
**Command**: `npx claude-flow sparc run architect "<feature>"`

**Purpose**: System design and component structure

**Deliverables**:
- Component diagram
- Module dependencies
- API contracts
- Database schema
- Integration points

**Example**:
```bash
npx claude-flow sparc run architect "WireGuard mesh auto-discovery service"
```

---

#### 4. Refinement (TDD Implementation)
**Command**: `npx claude-flow sparc tdd "<feature>"`

**Purpose**: Test-driven implementation

**Process**:
1. Write failing test
2. Implement minimal code to pass
3. Refactor for quality
4. Repeat

**Deliverables**:
- Full test suite
- Implementation code
- Code coverage report

**Example**:
```bash
npx claude-flow sparc tdd "Implement peer discovery protocol"
```

---

#### 5. Completion (Integration)
**Command**: `npx claude-flow sparc run integration "<feature>"`

**Purpose**: Integration and final validation

**Deliverables**:
- Integration tests
- Documentation
- Deployment plan
- Performance validation

**Example**:
```bash
npx claude-flow sparc run integration "Deploy peer discovery service"
```

---

### Complete SPARC Workflow Example

```bash
# 1. Create specification
npx claude-flow sparc run spec-pseudocode "Add health check endpoint to archon-mcp"

# 2. Design architecture
npx claude-flow sparc run architect "Health check endpoint architecture"

# 3. TDD implementation
npx claude-flow sparc tdd "Implement health check endpoint with tests"

# 4. Integration
npx claude-flow sparc run integration "Integrate health check into MCP server"

# 5. Verify
npm run test
npm run build
```

---

### SPARC Best Practices

#### Design Phase
- ✅ **Do**: Write clear acceptance criteria
- ✅ **Do**: Consider edge cases upfront
- ❌ **Don't**: Jump to implementation details
- ❌ **Don't**: Skip pseudocode

#### Implementation Phase
- ✅ **Do**: Write tests first (TDD)
- ✅ **Do**: Keep files under 500 lines
- ✅ **Do**: Use modular design
- ❌ **Don't**: Skip test coverage
- ❌ **Don't**: Hardcode secrets

#### Integration Phase
- ✅ **Do**: Run full test suite
- ✅ **Do**: Update documentation
- ✅ **Do**: Verify in production-like environment
- ❌ **Don't**: Skip integration tests

---

## 📝 Code Style & Best Practices

### Modular Design
- **Files under 500 lines** - Split large files
- **Single responsibility** - One purpose per module
- **Clear interfaces** - Well-defined APIs
- **Dependency injection** - Testable components

### Environment Safety
- **Never hardcode secrets** - Use environment variables
- **Config validation** - Fail fast on missing config
- **Secret rotation** - Support key updates without code changes

### Test-First Development
- **Write tests before implementation** - TDD approach
- **High test coverage** - Aim for 80%+
- **Test edge cases** - Don't just test happy path
- **Integration tests** - Test component interactions

### Clean Architecture
- **Separate concerns** - Business logic, data access, presentation
- **Clear boundaries** - Well-defined layers
- **Dependency direction** - Inner layers don't depend on outer

### Documentation
- **Keep updated** - Update docs with code changes
- **Examples required** - Show usage patterns
- **Architecture diagrams** - Visual system overview
- **Inline comments** - Explain "why", not "what"

---

## 🚀 Available Agents (54 Total)

### Core Development (5)
`coder`, `reviewer`, `tester`, `planner`, `researcher`

### Swarm Coordination (5)
`hierarchical-coordinator`, `mesh-coordinator`, `adaptive-coordinator`, `collective-intelligence-coordinator`, `swarm-memory-manager`

### Consensus & Distributed (7)
`byzantine-coordinator`, `raft-manager`, `gossip-coordinator`, `consensus-builder`, `crdt-synchronizer`, `quorum-manager`, `security-manager`

### Performance & Optimization (5)
`perf-analyzer`, `performance-benchmarker`, `task-orchestrator`, `memory-coordinator`, `smart-agent`

### GitHub & Repository (9)
`github-modes`, `pr-manager`, `code-review-swarm`, `issue-tracker`, `release-manager`, `workflow-automation`, `project-board-sync`, `repo-architect`, `multi-repo-swarm`

### SPARC Methodology (6)
`sparc-coord`, `sparc-coder`, `specification`, `pseudocode`, `architecture`, `refinement`

### Specialized Development (8)
`backend-dev`, `mobile-dev`, `ml-developer`, `cicd-engineer`, `api-docs`, `system-architect`, `code-analyzer`, `base-template-generator`

### Testing & Validation (2)
`tdd-london-swarm`, `production-validator`

### Migration & Planning (2)
`migration-planner`, `swarm-init`

---

## 🎯 MCP Tool Categories

### Coordination
`swarm_init`, `agent_spawn`, `task_orchestrate`

### Monitoring
`swarm_status`, `agent_list`, `agent_metrics`, `task_status`, `task_results`

### Memory & Neural
`memory_usage`, `neural_status`, `neural_train`, `neural_patterns`

### GitHub Integration
`github_swarm`, `repo_analyze`, `pr_enhance`, `issue_triage`, `code_review`

### System
`benchmark_run`, `features_detect`, `swarm_monitor`

---

## 📋 Agent Coordination Protocol

### Every Agent MUST:

**1️⃣ BEFORE Work:**
```bash
npx claude-flow@alpha hooks pre-task --description "[task]"
npx claude-flow@alpha hooks session-restore --session-id "swarm-[id]"
```

**2️⃣ DURING Work:**
```bash
npx claude-flow@alpha hooks post-edit --file "[file]" --memory-key "swarm/[agent]/[step]"
npx claude-flow@alpha hooks notify --message "[what was done]"
```

**3️⃣ AFTER Work:**
```bash
npx claude-flow@alpha hooks post-task --task-id "[task]"
npx claude-flow@alpha hooks session-end --export-metrics true
```

---

## 🎓 Performance Benefits

- **84.8% SWE-Bench solve rate**
- **32.3% token reduction**
- **2.8-4.4x speed improvement**
- **27+ neural models**
- **Automatic topology selection**
- **Self-healing workflows**

---

## 📚 Related Documentation

- **Core Rules**: `CLAUDE.md` - Main configuration and rules
- **Infrastructure**: `docs/INFRA.md` - Infrastructure map and network topology
- **Archon Integration**: `docs/ARCHON.md` - Archon MCP tools and guidelines
- **Coding Standards**: `docs/RULES.md` - Execution patterns and best practices
- **Quick Reference**: `docs/QUICK-START.md` - Common commands and operations

---

**Document Version**: 1.0.0
**Last Updated**: 2025-10-28
**Maintainer**: Claude Code (AGL Infrastructure Management)
