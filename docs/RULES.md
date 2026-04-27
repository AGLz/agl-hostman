# Development Rules & Standards

> **Last Updated**: 2026-02-18 | **Version**: 2.0.0

**Purpose**: Coding standards, execution patterns, and best practices for AGL infrastructure development.

**When to read**: Before implementing code, when debugging issues, or when uncertain about coding patterns.

---

## 📑 Table of Contents

1. [Critical Rules](#-critical-concurrent-execution--file-management)
2. [File Organization](#-file-organization-rules)
3. [Subagent Delegation](#-mandatory-subagent-usage)
4. [Claude Code vs MCP](#-claude-code-vs-mcp-tools)
5. [Concurrent Execution](#-concurrent-execution-examples)
6. [Context Rot Mitigation](#-context-rot-mitigation---new)
7. [Session Management](#-session-management---new)
8. [MCP Conscious Usage](#-mcp-conscious-usage---new)
9. [PRD Requirements](#-prd-requirements---new)
10. [Performance Metrics](#-performance-benefits)
11. [Integration Tips](#-integration-tips)

---

## 🚨 CRITICAL: CONCURRENT EXECUTION & FILE MANAGEMENT

**ABSOLUTE RULES**:
1. ALL operations MUST be concurrent/parallel in a single message
2. **NEVER save working files, text/mds and tests to the root folder**
3. ALWAYS organize files in appropriate subdirectories
4. **ALWAYS use Task tool with subagents for complex operations** - NEVER execute complex tasks directly

---

### ⚡ GOLDEN RULE: "1 MESSAGE = ALL RELATED OPERATIONS"

**MANDATORY PATTERNS:**
- **TodoWrite**: ALWAYS batch ALL todos in ONE call (5-10+ todos minimum)
- **Task tool**: ALWAYS spawn ALL agents in ONE message with full instructions
- **File operations**: ALWAYS batch ALL reads/writes/edits in ONE message
- **Bash commands**: ALWAYS batch ALL terminal operations in ONE message
- **Memory operations**: ALWAYS batch ALL memory store/retrieve in ONE message
- **Parallelism & Subagents**: ALWAYS use parallelism and spawn subagents whenever necessary and/or possible to maximize efficiency and performance

---

### 📁 File Organization Rules

**NEVER save to root folder. Use these directories:**
- `/src` - Source code files
- `/tests` - Test files
- `/docs` - Documentation and markdown files
- `/config` - Configuration files
- `/scripts` - Utility scripts
- `/examples` - Example code

---

### 🤖 MANDATORY SUBAGENT USAGE

**CRITICAL: ALWAYS delegate to specialized subagents using the Task tool**

**When to use subagents** (ALWAYS, not optional):
- Code analysis and exploration (use `Explore` agent)
- Research and information gathering (use `researcher` agent)
- Code implementation (use `coder` or `sparc-coder` agent)
- Testing (use `tester` or `tdd-london-swarm` agent)
- Code review (use `code-reviewer` or `reviewer` agent)
- Architecture design (use `architect` or `system-architect` agent)
- Performance analysis (use `perf-analyzer` agent)
- Documentation (use appropriate specialized agent)

**How to use subagents**:
```javascript
// ✅ CORRECT - Delegate to subagent
Task({
  subagent_type: "Explore",
  description: "Find error handling code",
  prompt: "Search the codebase for error handling patterns and document all locations where client errors are caught and processed"
})

// ❌ WRONG - Direct execution
Grep("pattern: error", "path: .")
Read("file.ts")
// Manual analysis...
```

**Benefits**:
- 🎯 Specialized expertise for each task type
- ⚡ Parallel execution (spawn multiple agents concurrently)
- 💾 Reduced token usage (agents work in isolation)
- 📊 Better context management
- 🔄 Reusable agent patterns

**Remember**: If you're tempted to do complex work directly, STOP and spawn a subagent instead.

---

## 🎯 Claude Code vs MCP Tools

### Claude Code Handles ALL:
- File operations (Read, Write, Edit, MultiEdit, Glob, Grep)
- Code generation and programming
- Bash commands and system operations
- Implementation work
- Project navigation and analysis
- TodoWrite and task management
- Git operations
- Package management
- Testing and debugging

### MCP Tools ONLY:
- Coordination and planning
- Memory management
- Neural features
- Performance tracking
- Swarm orchestration
- GitHub integration

**KEY**: MCP coordinates, Claude Code executes.

---

## 🎯 Concurrent Execution Examples

### ✅ CORRECT (Single Message):
```javascript
[BatchTool]:
  // Initialize swarm
  mcp__claude-flow__swarm_init { topology: "mesh", maxAgents: 6 }
  mcp__claude-flow__agent_spawn { type: "researcher" }
  mcp__claude-flow__agent_spawn { type: "coder" }
  mcp__claude-flow__agent_spawn { type: "tester" }

  // Spawn agents with Task tool
  Task("Research agent: Analyze requirements...")
  Task("Coder agent: Implement features...")
  Task("Tester agent: Create test suite...")

  // Batch todos
  TodoWrite { todos: [
    {id: "1", content: "Research", status: "in_progress", priority: "high"},
    {id: "2", content: "Design", status: "pending", priority: "high"},
    {id: "3", content: "Implement", status: "pending", priority: "high"},
    {id: "4", content: "Test", status: "pending", priority: "medium"},
    {id: "5", content: "Document", status: "pending", priority: "low"}
  ]}

  // File operations
  Bash "mkdir -p app/{src,tests,docs}"
  Write "app/src/index.js"
  Write "app/tests/index.test.js"
  Write "app/docs/README.md"
```

### ❌ WRONG (Multiple Messages):
```javascript
Message 1: mcp__claude-flow__swarm_init
Message 2: Task("agent 1")
Message 3: TodoWrite { todos: [single todo] }
Message 4: Write "file.js"
// This breaks parallel coordination!
```

---

## 🧠 CONTEXT ROT MITIGATION - NEW

**CRITICAL**: Context Rot is a scientifically-confirmed phenomenon where LLM performance degrades progressively as the context window fills. This affects ALL LLMs (Claude, GPT, Gemini).

**Source**: [Chroma Context Rot Study](https://research.trychroma.com/context-rot) | Video: "The Secret Poison Killing Your Claude Code Performance" (Chase AI)

### What is Context Rot?
- **Definition**: Performance degrades ~proportionally to context window usage
- **Mechanism**: Each message carries ALL previous history (input + output tokens accumulated)
- **Silent Killer**: Degradation is gradual, so users don't notice until quality drops significantly

### What Fills Context Window
| Source | Impact | Mitigation |
|--------|--------|------------|
| Messages (back-and-forth) | Medium | Session management |
| System prompts | Low | Keep concise |
| Tools | Medium | Use only needed |
| **MCP Tools** | **HIGH** | **Limit MCPs to 3-4 max** |

### The 4 Weapons Against Context Rot
1. **Task Management** → Break tasks into atomic units (see PRD Requirements)
2. **Session Management** → Use summaries + fresh sessions (see Session Management)
3. **Scaffolding Frameworks** → Use subagents with clean context (already implemented)
4. **MCP Consciousness** → Use only needed MCPs (see MCP Conscious Usage)

**Key Insight**: Just the first 2 weapons (task management + session management) solve ~90% of context rot!

---

## 🔄 SESSION MANAGEMENT - NEW

**Principle**: Don't let conversations drag for hours without active management.

### When to Reset Session
- Context window > 100,000 tokens (~50% of Claude's 200k limit)
- Task completed successfully
- Starting a new major feature
- After 20+ back-and-forth exchanges
- Quality noticeably degrading

### How to Reset Session

**Step 1: Request Summary**
```
Create a comprehensive summary of everything we discussed:
- Completed tasks and results
- In-progress work and blockers
- Key decisions and rationale
- Next steps for continuation
```

**Step 2: Save Summary**
- Store in project memory: `mcp__memory__create_entities` or file
- Use file for complex state: `/docs/session-summaries/YYYY-MM-DD.md`

**Step 3: Full Clear**
- `Ctrl+C` twice to fully exit (NOT just `/clear` which doesn't clear context)
- Start fresh session
- Provide summary as initial context

### Summary Template
```markdown
## Session Summary - YYYY-MM-DD

### Completed Tasks
- [Task]: [Result/Status]

### In Progress
- [Task]: [Current state, blockers, next action]

### Key Decisions
- [Decision]: [Rationale]

### Important Context
- [Context needed for continuation]

### Next Steps
1. [Action item]
2. [Action item]
```

### Autocompact Feature
Claude Code automatically triggers at ~150k-155k tokens:
1. Asks Claude to generate summary
2. Starts new session with summary as context
3. Continues seamlessly

---

## 🔌 MCP CONSCIOUS USAGE - NEW

**IMPORTANT**: With `ENABLE_TOOL_SEARCH: true` configuration, MCPs use **on-demand/deferred tool loading**. Tools are NOT loaded into context until explicitly requested via `ToolSearch`. This dramatically reduces context pollution.

### How ENABLE_TOOL_SEARCH Works
- **Deferred Loading**: MCP tools are listed but NOT loaded into context
- **On-Demand Access**: Use `ToolSearch` to load specific tools when needed
- **Context Savings**: Only actively-used tools consume context window
- **No Removal Needed**: You can have 20+ MCPs without context bloat

### ToolSearch Usage Pattern
```javascript
// Search for tools by keyword
ToolSearch({ query: "docker container", max_results: 5 })

// Direct select if you know the exact tool
ToolSearch({ query: "select:mcp__docker__docker_container_list" })

// After ToolSearch returns tools, they become available for use
// Example: mcp__docker__docker_container_list() is now callable
```

### When MCP Removal IS Still Needed
| Scenario | Action |
|----------|--------|
| MCP server causing errors | Remove problematic MCP |
| Unused MCP consuming memory | Consider removal |
| Redundant MCPs | Keep one, remove others |
| Session feels sluggish | Check active MCP count |

### When MCP Removal IS NOT Needed
| Scenario | Why |
|----------|-----|
| Many MCPs configured | ENABLE_TOOL_SEARCH prevents bloat |
| Need many tools available | Load on-demand only |
| Working normally | No action needed |

### Current MCP Inventory (Safe to Keep All)
| MCP Server | Tools | Purpose |
|------------|-------|---------|
| archon-tailscale | 28 | Task management, RAG search |
| claude-flow | 80+ | Swarm coordination, neural |
| github | 25 | PR management, code review |
| ruv-swarm | 20+ | Distributed agents |
| flow-nexus | 80+ | Cloud platform operations |
| docker | 8 | Container management |
| proxmox | 6 | VM/CT management |
| cloudflare-dns | 60 | DNS, workers, R2 |

### Key Insight
> **With ENABLE_TOOL_SEARCH, the "3-4 MCPs max" rule is obsolete.** Focus on Task Management and Session Management instead - these still solve ~90% of context rot.

---

## 📋 PRD REQUIREMENTS - NEW

**MANDATORY**: Before ANY coding task, create a PRD or specification.

### Why PRD Matters
- Reduces token waste on vague tasks
- Enables atomic task decomposition
- Provides clear completion criteria
- Supports session continuity

### PRD Workflow
```
Idea → /plan-product → /write-spec → /create-tasks → /implement-tasks
```

### Minimal PRD Template
```markdown
# [Feature Name] Requirements

## Overview
[1-2 sentence description]

## Goals
- [Primary goal]
- [Secondary goal]

## Non-Goals
[What this is NOT - prevents scope creep]

## Features
### Feature 1: [Name]
- Description: [What it does]
- Acceptance Criteria:
  - [ ] [Specific, testable criterion]
  - [ ] [Another criterion]

## Technical Approach
[High-level architecture - keep brief]

## Dependencies
[Required tools/libraries/infrastructure]
```

### Atomic Task Decomposition

**Rule**: Each task should be completable in ONE session with MINIMAL context.

**Task Size Checklist**:
- [ ] Completable in < 30 minutes?
- [ ] Clear, testable completion criteria?
- [ ] Requires < 5 files to modify?
- [ ] Describable in < 100 characters?
- [ ] Single responsibility?

**Decomposition Example**:

| Level | BAD (Too Broad) | GOOD (Atomic) |
|-------|-----------------|---------------|
| 5 | "Build auth system" | - |
| 4 | "Implement login" | - |
| 3 | - | "Create login form component" |
| 2 | - | "Add password hashing to User model" |
| 1 | - | "Write test for password validation" |

**Pattern**:
```
Broad Task
  → Feature
    → Component
      → Function
        → Test case (atomic!)
```

---

## 📊 Performance Benefits

### Execution Performance
- **84.8% SWE-Bench solve rate**
- **32.3% token reduction**
- **2.8-4.4x speed improvement**
- **Concurrent operations**: 10-20x faster than sequential

### Architecture Benefits
- **27+ neural models** for specialized tasks
- **Automatic topology selection** based on complexity
- **Self-healing workflows** with adaptive error recovery
- **Cross-session memory** for context continuity

### Token Optimization
- **Modular documentation**: Load only what's needed
- **On-demand references**: Use @docs/file.md pattern
- **Subagent isolation**: Independent context per agent
- **Batch operations**: Reduce overhead with single calls

---

## 🔧 Integration Tips

### 1. Start Simple
- Begin with basic swarm init
- Scale agents gradually
- Use memory for context persistence
- Monitor progress regularly

### 2. Use Memory Effectively
- Train patterns from successful operations
- Persist critical state across sessions
- Cache expensive computations
- Share knowledge between agents

### 3. Enable Automation
- Use hooks for pre/post operation tasks
- Auto-format code after edits
- Train neural patterns automatically
- Track performance metrics

### 4. GitHub Integration First
- Use GitHub tools before custom solutions
- Leverage existing workflows
- Coordinate PR reviews with swarms
- Automate issue triage

### 5. Monitor and Optimize
- Track token usage
- Analyze bottlenecks
- Optimize topologies
- Review agent performance

---

## 🎓 Best Practices Summary

### DO ✅
- ✅ Batch all operations in single messages
- ✅ Use subagents for complex tasks
- ✅ Organize files in proper directories
- ✅ Write tests before implementation
- ✅ Keep files under 500 lines
- ✅ Use modular design patterns
- ✅ Update documentation with changes
- ✅ Verify before claiming completion
- ✅ **Reset sessions at ~100k tokens**
- ✅ **Use ToolSearch to load MCP tools on-demand**
- ✅ **Create PRD before coding**
- ✅ **Break tasks into atomic units**
- ✅ **Request summaries before session reset**

### DON'T ❌
- ❌ Save files to root folder
- ❌ Execute complex tasks directly
- ❌ Use multiple messages for related operations
- ❌ Skip test coverage
- ❌ Hardcode secrets or credentials
- ❌ Create files without clear purpose
- ❌ Mix multiple concerns in one file
- ❌ Claim success without verification
- ❌ **Let sessions exceed 150k tokens**
- ❌ **Remove MCPs just because you have "too many"** (ENABLE_TOOL_SEARCH handles bloat)
- ❌ **Start coding without PRD/spec**
- ❌ **Create tasks too broad for one session**
- ❌ **Use `/clear` expecting context reset (use Ctrl+C twice)**

---

## 🚦 Code Quality Standards

### Modular Design
- **Files under 500 lines** - Split if larger
- **Single responsibility** - One purpose per module
- **Clear interfaces** - Well-defined APIs
- **Dependency injection** - Enable testing

### Environment Safety
- **Never hardcode secrets** - Use env vars or config
- **Config validation** - Fail fast on missing config
- **Secret rotation support** - No code changes needed
- **Audit logging** - Track sensitive operations

### Test-Driven Development
- **Write tests first** - Before implementation
- **High coverage** - Aim for 80%+ minimum
- **Test edge cases** - Not just happy paths
- **Integration tests** - Component interactions
- **Performance tests** - Benchmark critical paths

### Clean Architecture
- **Separate concerns** - Business logic, data, presentation
- **Clear boundaries** - Well-defined layers
- **Dependency direction** - Inner layers independent
- **Interface abstractions** - Depend on abstractions

---

## 📋 Git Workflow Standards

### Commit Messages
```bash
# Format: <type>: <description>
#
# - <details>
# - Impact/benefit

# Examples:
git commit -m "fix: resolve session ID error in MCP server

- Added stateless_http=True to FastMCP init
- Prevents session loss on container restart
- Impact: 100% method availability"

git commit -m "feat: add knowledge upload via MCP

- Fixed endpoint from /api/sources to /api/knowledge-items/crawl
- Updated payload to match KnowledgeItemRequest model
- Benefit: Automated knowledge base workflows"
```

### Commit Types
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `refactor`: Code refactoring
- `test`: Adding/updating tests
- `perf`: Performance improvement
- `chore`: Maintenance tasks

### Branch Strategy
- `main`: Production-ready code
- `develop`: Integration branch
- `feature/*`: New features
- `fix/*`: Bug fixes
- `hotfix/*`: Production hotfixes

---

## 🛡️ Error Handling Standards

### Fail-Fast Philosophy
```python
# ✅ CORRECT - Fail immediately with clear message
def process_data(data):
    if not data:
        raise ValueError("Data cannot be None or empty")
    if not isinstance(data, dict):
        raise TypeError(f"Expected dict, got {type(data)}")
    # Process...

# ❌ WRONG - Silent failures or unclear errors
def process_data(data):
    if not data:
        return None  # Silent failure
    # Process...
```

### Error Recovery
- **Retry with backoff** - For transient failures
- **Circuit breakers** - Prevent cascade failures
- **Graceful degradation** - Partial functionality better than total failure
- **Comprehensive logging** - Aid troubleshooting

### Validation
- **Input validation** - At boundaries
- **Type checking** - Use type hints (Python) or TypeScript
- **Range validation** - Numeric bounds
- **Format validation** - Strings, dates, etc.

---

## 🔍 Code Review Checklist

### Before Submitting
- [ ] All tests passing
- [ ] Coverage > 80%
- [ ] No linter errors
- [ ] Documentation updated
- [ ] No hardcoded secrets
- [ ] Files in correct directories
- [ ] Modular design (< 500 lines per file)
- [ ] Git commit messages clear

### Review Focus
- [ ] Business logic correctness
- [ ] Edge case handling
- [ ] Error handling
- [ ] Performance implications
- [ ] Security concerns
- [ ] API design
- [ ] Test quality
- [ ] Documentation accuracy

---

## 📚 Related Documentation

- **Main Config**: `CLAUDE.md` - Core rules and navigation
- **Workflows**: `docs/WORKFLOWS.md` - SPARC and Agent OS methodologies
- **Infrastructure**: `docs/INFRA.md` - Infrastructure map and topology
- **Archon Guide**: `docs/ARCHON.md` - Archon MCP integration
- **Quick Start**: `docs/QUICK-START.md` - Common commands

---

**Document Version**: 2.0.0
**Last Updated**: 2026-02-18
**Maintainer**: Claude Code (AGL Infrastructure Management)
**Context Rot Mitigation**: Added based on Chroma Study research
