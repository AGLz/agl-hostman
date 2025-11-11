# SuperClaude Hive-Mind System - Deployment Guide

> **Version**: 2.0.0
> **Last Updated**: 2025-11-10
> **Status**: Production deployments on CT179 and CT181

---

## 📊 Overview

**SuperClaude** is a multi-agent orchestration system that provides collective intelligence capabilities through:

- **116 VoltAgent Agents**: Production-ready specialists across 10 categories
- **64 wshobson Plugins**: Modular functionality extensions
- **9 obra/superpowers Skills**: Auto-applied best practices
- **ReasoningBank Database**: Persistent memory for agent decisions
- **Swarm Configuration**: Hive-mind coordination architecture

**Total System Size**: ~5.0 MB uncompressed

---

## 🚀 Current Deployments

### Production Containers

| Container | Hostname | Network | Installation Date | Status | Version |
|-----------|----------|---------|-------------------|--------|---------|
| **CT179** | agldv03 | WG: 10.6.0.19, TS: 100.94.221.87 | 2025-10-21 | ✅ Active | 2.7.0-alpha.10 |
| **CT181** | agldv04 | WG: 10.6.0.24, TS: 100.113.9.98 | 2025-11-10 | ✅ Active | 2.7.0-alpha.10 |

### CT181 Deployment Details

**Installation Method**: Tarball transfer from CT179 via WireGuard mesh
**Duration**: ~7 minutes
**Transfer Size**: 1.2 MB compressed → 5.0 MB uncompressed

**Components Installed**:
```
✅ VoltAgent Agents:    10 categories, 116 agents, 1.4 MB
✅ wshobson Plugins:    64 plugins, 3.5 MB
✅ obra/superpowers:    9 skills, 94 KB
✅ ReasoningBank DB:    10 tables, 128 KB
✅ Swarm Config:        hive-mind configuration, 11 KB
✅ Scripts:             configure-api-keys.sh, 6.5 KB
```

---

## 📦 Component Details

### 1. VoltAgent Agents (116 agents, 1.4 MB)

**Location**: `~/.claude/agents-voltgent/`

**10 Categories**:

1. **Meta-Orchestration** (9 agents)
   - multi-agent-coordinator, agent-organizer, workflow-orchestrator
   - task-distributor, context-manager, knowledge-synthesizer
   - performance-monitor, error-coordinator, decision-maker

2. **Core Development** (12 agents)
   - backend-developer, frontend-developer, fullstack-developer
   - api-designer, mobile-developer, microservices-architect
   - websocket-engineer, graphql-architect, electron-pro

3. **Language Specialists** (24 agents)
   - JavaScript/TypeScript, Python, PHP, Ruby, .NET, Java
   - Rust, Go, C++, Swift, Kotlin, Flutter, SQL specialists

4. **Infrastructure & Quality** (26 agents)
   - DevOps, SRE, Kubernetes, Terraform, cloud-architect
   - Security, QA, testing, CI/CD

5. **Data & AI** (13 agents)
   - Data science, ML, MLOps, NLP, LLM architecture
   - Database optimization

6. **Developer Experience** (8 agents)
   - Documentation, API docs, code review, mentorship

7. **Specialized Domains** (10 agents)
   - Blockchain, IoT, embedded, game dev, AR/VR

8. **Business & Product** (6 agents)
   - Product manager, business analyst, technical writer

9. **Research & Analysis** (5 agents)
   - Research, algorithm design, performance analysis

10. **Support & Operations** (3 agents)
    - Technical support, incident response

### 2. wshobson Plugins (64 modules, 3.5 MB)

**Location**: `~/.claude/agents-wshobson/`

**Categories**:
- Accessibility compliance
- Agent orchestration
- API scaffolding
- API testing & observability
- Architecture patterns
- Authentication & authorization
- CI/CD automation
- Code generation
- Database design
- Documentation generation
- Error handling
- Microservices
- Performance optimization
- Security scanning
- Testing frameworks
- UI/UX patterns

### 3. obra/superpowers Skills (9 skills, 94 KB)

**Location**: `~/.claude/skills/`

**Skills**:
1. `verification-before-completion` - Verify output before claiming completion
2. `testing-anti-patterns` - Prevent common testing mistakes
3. `receiving-code-review` - Handle code review feedback properly
4. `requesting-code-review` - Request code reviews effectively
5. `condition-based-waiting` - Replace timeouts with condition polling
6. `sharing-skills` - Contribute skills upstream via PR
7. `testing-skills-with-subagents` - Test skills under pressure
8. `using-superpowers` - Mandatory workflows for finding/using skills
9. `commands/` - Slash command configurations

### 4. ReasoningBank Database (128 KB)

**Location**: `~/.claude/memory/reasoning-bank.db`

**Schema** (10 tables):
- `schema_version` - Database version tracking
- `reasoning_chains` - Agent decision chains
- `agent_decisions` - Individual agent choices
- `consensus_results` - Multi-agent consensus outcomes
- `task_assignments` - Task distribution records
- `agent_metrics` - Performance metrics
- `swarm_sessions` - Hive-mind session tracking
- `sqlite_sequence` - Auto-increment tracking
- Additional tables for extended functionality

**Views**:
- `v_recent_reasoning` - Recent decision chains
- `v_agent_performance` - Agent metrics summary
- `v_consensus_stats` - Consensus statistics

**Purpose**: Persistent memory enabling agents to learn from past decisions and maintain context across sessions.

### 5. Swarm Configuration (11 KB)

**Location**: `~/.claude/swarm/swarm-config.yml`

**Configuration**:
```yaml
swarm_id: "swarm-agldv<X>-<timestamp>"
version: "2.7.0-alpha.10"
mode: "hive-mind"

queen:
  type: "strategic"
  role: "Task decomposition | Agent coordination | Consensus validation"

workers:
  researcher:
    agent_type: "researcher"
    description: "Research and analysis specialist"
    persona_mapping:
      primary: "analyzer"
      secondary: "mentor"

  coder:
    agent_type: "coder"
    description: "Implementation specialist"
    persona_mapping:
      primary: "backend"
      secondary: ["frontend", "refactorer"]

  analyst:
    agent_type: "analyst"
    description: "Impact assessment specialist"
    persona_mapping:
      primary: "architect"
      secondary: "analyzer"

  tester:
    agent_type: "tester"
    description: "Validation specialist"
    persona_mapping:
      primary: "qa"
      secondary: ["performance", "security"]
```

**Purpose**: Defines swarm topology and agent coordination rules for hive-mind operations.

### 6. Scripts (6.5 KB)

**Location**: `~/.claude/scripts/`

**Files**:
- `configure-api-keys.sh` - Automated API credential configuration for MCP servers

---

## 🔧 Installation Methods

### Method 1: Tarball Transfer (Recommended)

**Use Case**: Deploying to new container from existing SuperClaude installation
**Speed**: ~7 minutes
**Reliability**: ✅ Highest (proven working configuration)

**Steps**:

```bash
# 1. On source container (e.g., CT179)
cd ~/.claude
tar -czf /tmp/superclaude-system.tar.gz \
  agents-voltgent/ \
  agents-wshobson/ \
  memory/ \
  scripts/ \
  swarm/ \
  *.md

# 2. Transfer via WireGuard (fastest) or other network
scp /tmp/superclaude-system.tar.gz root@<TARGET_WG_IP>:/tmp/

# 3. On target container (e.g., CT181)
cd ~/.claude
tar -xzf /tmp/superclaude-system.tar.gz
chmod +x scripts/configure-api-keys.sh

# 4. Install skills (if not in tarball)
cd /tmp
tar -czf skills.tar.gz ~/.claude/skills/  # On source
scp skills.tar.gz root@<TARGET_WG_IP>:/tmp/  # Transfer
cd ~/.claude && tar -xzf /tmp/skills.tar.gz  # On target

# 5. Clean up
rm -f /tmp/superclaude-system.tar.gz /tmp/skills.tar.gz

# 6. Verify installation
ls -lh ~/.claude/agents-voltgent/ ~/.claude/agents-wshobson/ ~/.claude/skills/
sqlite3 ~/.claude/memory/reasoning-bank.db ".tables"
```

### Method 2: Clone from GitHub Repositories

**Use Case**: Fresh installation with latest upstream versions
**Speed**: ~20-30 minutes
**Reliability**: ✅ Good (requires configuration)

**Steps**:

```bash
cd ~/.claude

# Clone VoltAgent (116 agents)
git clone --depth 1 https://github.com/VoltAgent/awesome-claude-code-subagents.git
mv awesome-claude-code-subagents/categories agents-voltgent
rm -rf awesome-claude-code-subagents

# Clone obra/superpowers (9 skills)
git clone --depth 1 https://github.com/obra/superpowers.git
cp -r superpowers/skills ~/.claude/
rm -rf superpowers

# Clone wshobson/agents (64 plugins)
git clone --depth 1 https://github.com/wshobson/agents.git
mv agents/plugins agents-wshobson
rm -rf agents

# Initialize ReasoningBank database
# (Copy schema from existing installation or create new)
mkdir -p memory
scp root@<SOURCE_IP>:~/.claude/memory/schema.sql memory/
sqlite3 memory/reasoning-bank.db < memory/schema.sql

# Copy swarm configuration
mkdir -p swarm
scp root@<SOURCE_IP>:~/.claude/swarm/swarm-config.yml swarm/

# Copy scripts
mkdir -p scripts
scp root@<SOURCE_IP>:~/.claude/scripts/configure-api-keys.sh scripts/
chmod +x scripts/configure-api-keys.sh
```

### Method 3: Selective Installation

**Use Case**: Installing specific components only
**Speed**: Variable
**Reliability**: ✅ Good (for specific needs)

Install only what you need:
- Agents only: `agents-voltgent/` (1.4 MB)
- Plugins only: `agents-wshobson/` (3.5 MB)
- Skills only: `skills/` (94 KB)
- Database only: `memory/` (128 KB)
- Swarm config only: `swarm/` (11 KB)

---

## ✅ Verification Checklist

After installation, verify all components:

```bash
# 1. VoltAgent agents (should show 10 categories)
ls -1 ~/.claude/agents-voltgent/ | grep -E "^[0-9]" | wc -l

# 2. wshobson plugins (should show 64 directories)
ls -1 ~/.claude/agents-wshobson/ | wc -l

# 3. Skills (should show 9 directories)
ls -1 ~/.claude/skills/ | wc -l

# 4. ReasoningBank database (should show 8-10 tables)
sqlite3 ~/.claude/memory/reasoning-bank.db ".tables"

# 5. Swarm configuration (should show hive-mind config)
cat ~/.claude/swarm/swarm-config.yml | head -20

# 6. Total system size
du -sh ~/.claude/{agents-voltgent,agents-wshobson,skills,memory,swarm,scripts}
```

**Expected Output**:
```
✅ VoltAgent:    10 categories, 1.4 MB
✅ Plugins:      64 directories, 3.5 MB
✅ Skills:       9 directories, 94 KB
✅ Database:     8-10 tables, 128 KB
✅ Swarm:        11 KB config file
✅ Scripts:      6.5 KB
───────────────────────────────────
   TOTAL:       ~5.0 MB
```

---

## 🔍 Troubleshooting

### Issue: Database schema missing

**Solution**:
```bash
# Copy from existing installation
scp root@10.6.0.19:~/.claude/memory/schema.sql ~/.claude/memory/
sqlite3 ~/.claude/memory/reasoning-bank.db < ~/.claude/memory/schema.sql
```

### Issue: Skills not loading

**Solution**:
```bash
# Verify skills directory structure
ls -la ~/.claude/skills/
# Should show directories, not skill files in root
# Each skill should be in its own directory
```

### Issue: Swarm config not found

**Solution**:
```bash
# Copy from CT179
scp root@10.6.0.19:~/.claude/swarm/swarm-config.yml ~/.claude/swarm/
# Update swarm_id for new container
```

### Issue: Scripts not executable

**Solution**:
```bash
chmod +x ~/.claude/scripts/*.sh
```

---

## 📚 External Resources

**Repositories**:
- VoltAgent: https://github.com/VoltAgent/awesome-claude-code-subagents
- obra/superpowers: https://github.com/obra/superpowers
- wshobson/agents: https://github.com/wshobson/agents

**Documentation**:
- `AGLDV3-DEPLOYMENT-GUIDE.md` - Original CT179 deployment
- `SUPERCLAUDE-AGLDV3-COMPLETE.md` - CT179 implementation summary
- `CT179-vs-CT181-COMPARISON.md` - Comparison and CT181 deployment
- `CT178_CT179_MIGRATION_ANALYSIS.md` - Migration analysis

---

## 📊 Performance Impact

**System Growth**:

| Metric | Before | After | Growth |
|--------|--------|-------|--------|
| Agents | ~65 (default) | 181+ | +178% |
| Skills | ~7 (default) | 16+ | +128% |
| Plugins | 0 | 64 | NEW |
| Disk Usage | ~100 MB | ~105 MB | +5% |

**Benefits**:
- Multi-agent orchestration with 116 specialists
- Collective intelligence via ReasoningBank
- Persistent memory across sessions
- Hive-mind swarm coordination
- Auto-applied best practices

---

## 🔐 Security Notes

**API Keys**:
- Use `scripts/configure-api-keys.sh` to set up MCP credentials
- Never commit API keys to git
- Store keys in environment variables or secure vault

**Database**:
- ReasoningBank contains agent decision history
- Review sensitive data before backing up
- Encrypt backups if storing externally

**Network Access**:
- SuperClaude operates locally within container
- No external network access required for core functionality
- MCP servers may require API keys for external services

---

## 📝 Maintenance

### Regular Tasks

**Weekly**:
- Review agent performance metrics in ReasoningBank
- Check swarm session logs
- Update documentation if configuration changes

**Monthly**:
- Update VoltAgent agents from upstream
- Update wshobson plugins from upstream
- Update obra/superpowers skills
- Backup ReasoningBank database

**Quarterly**:
- Review and optimize database (VACUUM, ANALYZE)
- Update swarm configuration if needed
- Review and remove unused agents/plugins

### Backup Procedure

```bash
# Full backup
cd ~/.claude
tar -czf superclaude-backup-$(date +%Y%m%d).tar.gz \
  agents-voltgent/ \
  agents-wshobson/ \
  skills/ \
  memory/ \
  swarm/ \
  scripts/

# Database only
sqlite3 ~/.claude/memory/reasoning-bank.db ".backup /tmp/reasoningbank-$(date +%Y%m%d).db"
```

### Restore Procedure

```bash
# Full restore
cd ~/.claude
tar -xzf superclaude-backup-YYYYMMDD.tar.gz

# Database only
cp /tmp/reasoningbank-YYYYMMDD.db ~/.claude/memory/reasoning-bank.db
```

---

## 🎯 Future Enhancements

**Planned**:
- [ ] Automated deployment script
- [ ] Health check monitoring
- [ ] Performance benchmarking suite
- [ ] Integration with Archon MCP for cross-container coordination
- [ ] Swarm synchronization across multiple containers

**Under Consideration**:
- [ ] Web UI for agent management
- [ ] Real-time swarm visualization
- [ ] Agent marketplace integration
- [ ] Custom agent development toolkit

---

**Document Version**: 2.0.0
**Last Updated**: 2025-11-10
**Maintainer**: Claude Code (agl-hostman project)
**Status**: Production documentation - CT179 and CT181 deployments
