# Development Rules & Standards

> **Last Updated**: 2025-10-28 | **Version**: 1.0.0

**Purpose**: Coding standards, execution patterns, and best practices for AGL infrastructure development.

**When to read**: Before implementing code, when debugging issues, or when uncertain about coding patterns.

---

## 📑 Table of Contents

1. [Critical Rules](#-critical-concurrent-execution--file-management)
2. [File Organization](#-file-organization-rules)
3. [Subagent Delegation](#-mandatory-subagent-usage)
4. [Claude Code vs MCP](#-claude-code-vs-mcp-tools)
5. [Concurrent Execution](#-concurrent-execution-examples)
6. [Performance Metrics](#-performance-benefits)
7. [Integration Tips](#-integration-tips)

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

### DON'T ❌
- ❌ Save files to root folder
- ❌ Execute complex tasks directly
- ❌ Use multiple messages for related operations
- ❌ Skip test coverage
- ❌ Hardcode secrets or credentials
- ❌ Create files without clear purpose
- ❌ Mix multiple concerns in one file
- ❌ Claim success without verification

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

**Document Version**: 1.0.0
**Last Updated**: 2025-10-28
**Maintainer**: Claude Code (AGL Infrastructure Management)
