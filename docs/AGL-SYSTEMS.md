# AGL Systems Reference Guide

> **Reference documentation for AGL internal systems and tools**
> **Last Updated:** March 27, 2026

---

## 📋 Table of Contents

1. [Claude Flow](#claude-flow)
2. [Hive Mind](#hive-mind)
3. [Gemini Flow](#gemini-flow)
4. [Ruflo](#ruflo)
5. [Agentos](#agentos)
6. [OpenClaw](#openclaw)
7. [Other Projects](#other-projects)

---

## Claude Flow

### Overview

**Claude Flow** is a multi-agent orchestration system built by Ruvnet (ruvnet). It enables collaborative AI workflows with specialized agents working together.

### Location

```
Root: /mnt/overpower/apps/dev/agl/
- agl-hostman/.claude-flow/ (main installation)
- agl-hostman/.hive-mind/ (Hive Mind integration)
- agl-hostman/.gemini-flow/ (Gemini Flow integration)
- agl-hostman/.claude/commands/hive-mind/ (Claude commands)
```

### Installation

```bash
# Install Claude Flow
npm install -g claude-flow

# Initialize
npx claude-flow@alpha hive-mind init
```

### Hive Mind Integration

The Hive Mind feature provides:

- **Collective Intelligence**: Multiple AI agents working together
- **Consensus Building**: Democratic decision-making process
- **Adaptive Learning**: System improves over time
- **Fault Tolerance**: Self-healing and recovery capabilities
- **Performance Monitoring**: Real-time metrics and optimization

#### Commands

```bash
# Spawn swarm
npx claude-flow@alpha hive-mind spawn "your objective"

# Check status
npx claude-flow@alpha hive-mind status

# View sessions
npx claude-flow@alpha hive-mind sessions

# Check memory
npx claude-flow@alpha hive-mind memory
```

#### Hive Mind Database

**Location:** `/mnt/overpower/apps/dev/agl/agl-hostman/.hive-mind/hive.db`

**Tables:**
- `sessions` - Active and historical sessions
- `memory` - Collective knowledge base
- `config` - System configuration
- `templates` - Agent templates

#### Configuration

Edit: `/mnt/overpower/apps/dev/agl/agl-hostman/.hive-mind/config.json`

```json
{
  "queen": {
    "type": "leader",
    "capabilities": ["decide", "coordinate"]
  },
  "workers": [
    {"name": "researcher", "specialization": "research"},
    {"name": "coder", "specialization": "code"},
    {"name": "reviewer", "specialization": "review"},
    {"name": "tester", "specialization": "test"}
  ]
}
```

### Claude Flow Commands

**Location:** `/mnt/overpower/apps/dev/agl/agl-hostman/.claude/commands/hive-mind/`

Available commands:
- `hive-mind init` - Initialize system
- `hive-mind spawn` - Create swarm
- `hive-mind status` - Check status
- `hive-mind export` - Export data

### Use Cases

1. **Code Review**: Multiple agents review code from different perspectives
2. **Documentation**: Agents generate and update docs collaboratively
3. **Project Planning**: Agents collaborate on project roadmap
4. **Testing**: Agents create and execute test cases
5. **Research**: Agents gather and synthesize information

---

## Hive Mind

### Overview

**Hive Mind** is the collective intelligence component of Claude Flow. It enables multiple AI agents to work together, share memory, and make consensus decisions.

### Architecture

```
┌─────────────────────────────────────────────┐
│              Queen (Leader)                  │
│  - Makes final decisions                     │
│  - Coordinates agents                         │
│  - Manages memory                            │
└────────────┬────────────────────────────────┘
             │
    ┌────────┴────────┬────────┬────────┐
    │                 │        │        │
┌───▼────┐    ┌──────▼────┐ ┌─▼──────┐ ┌▼──────────┐
│Research│    │  Coder   │ │ Reviewer│ │  Tester   │
│  Agent │    │   Agent  │ │  Agent  │ │   Agent   │
└────────┘    └──────────┘ └─────────┘ └───────────┘
```

### Directory Structure

```
.hive-mind/
├── config/           # Configuration files
│   └── config.json
├── sessions/         # Session data
│   └── (SQLite database)
├── memory/           # Collective memory
├── templates/        # Agent templates
├── logs/             # System logs
├── backups/          # Backups
├── hive.db           # Main database (SQLite)
└── memory.db         # Memory database (SQLite)
```

### Features

- **Shared Memory**: All agents share common knowledge
- **Consensus Building**: Agents debate and agree on solutions
- **Session Management**: Track active and completed sessions
- **Memory Persistence**: Knowledge persists across sessions
- **Auto-Save**: Automatic backup of system state

### Database Schema

#### Sessions Table
- `id` - Unique session ID
- `queen_id` - Queen agent ID
- `created_at` - Creation timestamp
- `status` - status (active, completed, failed)
- `objective` - Original objective

#### Memory Table
- `id` - Memory entry ID
- `session_id` - Associated session
- `content` - Memory content
- `type` - memory type
- `created_at` - Timestamp

#### Config Table
- `key` - Configuration key
- `value` - Configuration value
- `type` - Value type

### Use Cases

1. **Multi-Agent Coding**: Multiple agents collaborate on code
2. **Research Projects**: Agents research and synthesize findings
3. **Testing Suites**: Agents create comprehensive tests
4. **Documentation**: Agents generate and maintain docs
5. **Code Review**: Agents review from multiple perspectives

---

## Gemini Flow

### Overview

**Gemini Flow** is an AI-powered project management system built with Google's Gemini models. It orchestrates specialized agents for various tasks.

### Location

```
Root: /mnt/overpower/apps/dev/agl/agl-hostman/.gemini-flow/
```

### Configuration

**File:** `/mnt/overpower/apps/dev/agl/agl-hostman/.gemini-flow/config.json`

```json
{
  "name": "gemini-flow-project",
  "description": "AI-powered project using Gemini-Flow",
  "version": "1.0.0",
  "template": "basic",
  "swarm": {
    "defaultTopology": "hierarchical",
    "maxAgents": 8
  },
  "google": {
    "projectId": null,
    "enabled": false
  },
  "agents": {
    "autoSpawn": true,
    "types": [
      "coder",
      "researcher",
      "tester",
      "reviewer",
      "planner"
    ]
  }
}
```

### Agent Types

1. **Coder** - Code generation and modification
2. **Researcher** - Information gathering and analysis
3. **Tester** - Test creation and validation
4. **Reviewer** - Code review and optimization
5. **Planner** - Project planning and coordination

### Swarm Topology

- **Hierarchical**: Agents organized in levels (planner → specialist → worker)
- **Flat**: All agents on same level
- **Mixed**: Combination of both

### Features

- **Auto-Spawn**: Automatic agent spawning based on needs
- **Task Allocation**: Automatic assignment of tasks
- **Progress Tracking**: Real-time progress monitoring
- **Agent Pool**: Dynamic agent management

### Use Cases

1. **Project Management**: Track and manage projects
2. **Task Automation**: Automate repetitive tasks
3. **Team Coordination**: Coordinate team workflows
4. **Progress Tracking**: Monitor project progress

---

## Ruflo

### Overview

**Ruflo** is a deployment and orchestration system used in AGL infrastructure. It's likely a custom or proprietary system for managing deployments.

### Location

```
Root: /mnt/overpower/apps/dev/agl/agl-hostman/
- scripts/ruflo/                    # Scripts directory
- config/ruflo/                     # Configuration
- scripts/setup-ruflo.sh            # Setup script
- scripts/validate-ruflo.sh         # Validation script
```

### Scripts

#### setup-ruflo.sh
- **Purpose**: Setup Ruflo on hosts
- **Usage**: Run on target hosts to install Ruflo
- **Target**: AGLDV03 and other hosts

#### validate-ruflo.sh
- **Purpose**: Validate Ruflo configuration
- **Usage**: Run to verify installation
- **Output**: Validation results

#### deploy-is-sandbox-all-hosts.sh
- **Purpose**: Deploy to sandbox environment
- **Target**: All hosts
- **Usage**: `./deploy-is-sandbox-all-hosts.sh`

#### setup-background-workers.sh
- **Purpose**: Setup background workers
- **Usage**: Configure worker processes

### Configuration

**Location:** `/mnt/overpower/apps/dev/agl/agl-hostman/config/ruflo/`

**Files:**
- `config.json` - Main configuration
- Various other config files

### Use Cases

1. **Deployment Orchestration**: Deploy applications across hosts
2. **Infrastructure Management**: Manage system infrastructure
3. **Configuration Management**: Manage configurations
4. **Worker Management**: Manage background worker processes

---

## Agentos

### Overview

**Agentos** appears to be a frontend project or system. It's being developed in the AGL backend/api infrastructure.

### Location

```
Root: /mnt/overpower/apps/dev/agl/apis-evo/
- api9/src/resources/js/Pages/Si/agentos/
```

### Current State

- **Status**: Under development
- **Type**: Frontend application/page
- **Project**: api9 (part of apis-evo)

### Purpose

Likely:
- Agent management interface
- Dashboard for monitoring agents
- Management console for agents
- Agent operations interface

### Next Steps

1. Explore the code structure
2. Identify the specific functionality
3. Create documentation

---

## OpenClaw

### Overview

**OpenClaw** is the AI Agent Gateway used by AGL. It manages agents, sessions, and workflows.

### Configuration

**Location:** `/root/.openclaw/`

**Key Files:**
- `config-patch.json` - Configuration patch
- Skills directory - Available skills

### Skills Available

Located: `/root/.openclaw/workspace/skills/`

**Key Skills:**
- `coding-agent` - Code generation and building
- `github` - GitHub operations
- `skill-creator` - Create and edit skills
- `command-center` - Central command
- `weather` - Weather information
- `healthcheck` - Security hardening

### Default Model

**Model:** `zai/glm-5` (alias: `glm`)

**Fallbacks (patch repo):**
1. `openrouter/deepseek/deepseek-chat` (DeepSeek V3 Chat via OpenRouter)
2. `openrouter/meta-llama/llama-3.3-70b-instruct:free`
3. `openrouter/z-ai/glm-4.5-air:free`
4. `zai/glm-5`
5. `dashscope/qwen-plus`

### Available Models

- **Zai**: GLM-5, GLM-4.7, GLM-4.7-flash
- **Anthropic**: Claude Opus, Sonnet, Haiku
- **OpenAI**: GPT-4.1, GPT-4o, GPT-4o-mini
- **Google**: Gemini 3.1 Pro, 2.5 Pro, 2.5 Flash
- **DeepSeek (OpenClaw direct)**: via OpenRouter — `openrouter/deepseek/deepseek-chat`, `openrouter/deepseek/deepseek-r1`
- **Moonshot**: Kimi K2.5, Kimi K2 Thinking
- **OpenRouter**: Multiple free models

---

## Other Projects

### AGL-V8 Partnership

**Location:** `/mnt/overpower/apps/dev/agl/agl-v8-partnership/`

**Purpose:** Partnership with V8.Tech (now owned by TIM)

**Components:**
- Presentation materials
- Executive summary
- Project status
- Technical architecture
- AI Agent descriptions

### AGL Hostman

**Location:** `/mnt/overpower/apps/dev/agl/agl-hostman/`

**Purpose:** Main infrastructure management project

**Components:**
- Hive Mind system
- Gemini Flow
- Ruflo deployment
- Multiple agents
- Infrastructure management

### AGL Dropship

**Location:** `/mnt/overpower/apps/dev/agl/agl-dropship/`

**Purpose:** Dropshipping project (details unknown)

### AGL G1 / G2

**Location:** `/mnt/overpower/apps/dev/agl/agl-g1/`, `/mnt/overpower/apps/dev/agl/agl-g2/`

**Purpose:** Project G1 and G2 (details unknown)

### AGL G1-G2

**Location:** `/mnt/overpower/apps/dev/agl/agl-hostman/`

**Purpose:** Project G1-G2 integration (details unknown)

### AGL GS

**Location:** `/mnt/overpower/apps/dev/agl/agl-hostman/`

**Purpose:** Project GS (details unknown)

---

## Quick Reference Commands

### Claude Flow / Hive Mind

```bash
# Initialize Hive Mind
npx claude-flow@alpha hive-mind init

# Spawn swarm
npx claude-flow@alpha hive-mind spawn "your objective"

# Check status
npx claude-flow@alpha hive-mind status

# View sessions
npx claude-flow@alpha hive-mind sessions

# View memory
npx claude-flow@alpha hive-mind memory

# Export data
npx claude-flow@alpha hive-mind export
```

### Ruflo

```bash
# Setup on hosts
cd /mnt/overpower/apps/dev/agl/agl-hostman/scripts
./setup-ruflo.sh

# Validate
./validate-ruflo.sh

# Deploy to all hosts
./deploy-is-sandbox-all-hosts.sh

# Setup background workers
./setup-background-workers.sh
```

### OpenClaw

```bash
# Check model status
openclaw models list

# Set default model
openclaw config set model zai/glm-5

# Check status
openclaw status
```

---

## Usage Guidelines

### When to Use Claude Flow

1. **Multi-Agent Projects** - When you need multiple specialized agents
2. **Complex Workflows** - When you need orchestrated workflows
3. **Collaborative Tasks** - When multiple perspectives are needed
4. **Knowledge Management** - When you need shared memory
5. **Research Projects** - When gathering and synthesizing information

### When to Use Hive Mind

1. **Consensus Building** - When you need decision consensus
2. **Collective Intelligence** - When you need intelligence from multiple agents
3. **Memory Persistence** - When you need knowledge persistence
4. **Fault Tolerance** - When you need self-healing systems

### When to Use Gemini Flow

1. **Project Management** - When managing AI-powered projects
2. **Task Automation** - When automating tasks with AI
3. **Team Coordination** - When coordinating team workflows
4. **Progress Tracking** - When tracking project progress

### When to Use Ruflo

1. **Deployment** - When deploying to infrastructure
2. **Orchestration** - When orchestrating multiple components
3. **Configuration** - When managing configurations
4. **Worker Management** - When managing worker processes

---

## Documentation Links

- **Claude Flow GitHub**: https://github.com/ruvnet/claude-flow
- **Hive Mind Docs**: https://github.com/ruvnet/claude-flow/docs/hive-mind.md
- **Gemini Flow**: Internal documentation
- **Ruflo**: Internal project documentation
- **Agentos**: Under development

---

## Contact

For questions about AGL systems:
- **Primary Contact**: Carlos Fernando Aguilera
- **Email**: carlos@aguileraz.net
- **Workspace**: `/mnt/overpower/apps/dev/agl/`

---

**Version:** 1.0
**Last Updated:** March 27, 2026
**Owner**: AGL Engineering Team
