# CLAUDE.md — TurboFlow 4.0 Context

## Identity
This workspace runs TurboFlow 4.0 — a composed agentic development environment.
Orchestration: Ruflo v3.5 (skills-based, not slash commands).
Memory: Three-tier (Beads → Native Tasks → AgentDB).
Isolation: Git worktrees per parallel agent.

## Memory Protocol (MANDATORY — follow this every session)

### Session Start
1. Run `bd ready` to check project state (blockers, in-progress work, decisions)
2. Check Native Tasks: review any persisted task lists from prior sessions
3. AgentDB context loads automatically via Ruflo

### During Work — Decision Tree
- **Project roadmap / blockers / dependencies / decisions** → `bd add` (Beads)
- **Current session tasks / active checklist** → Native Tasks
- **Learned patterns / routing weights / skills** → AgentDB (automatic)

### Session End
- File any discovered work as Beads issues: `bd add --type issue "description"`
- Summarize architectural decisions in Beads: `bd add --type decision "description"`
- AgentDB persists automatically

## Isolation Rules
- Each parallel agent MUST operate in its own git worktree
- Create worktree: `git worktree add .worktrees/agent-N -b agent-N/task-name`
- Database schema per worktree: use $DATABASE_SCHEMA env var for PG Vector
- NEVER run `--dangerously-skip-permissions` on bare metal — containers only

## Agent Teams
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is enabled
- Lead agent may spawn up to 3 teammates
- Recursion limit: depth 2 (lead → sub-agents, sub-agents cannot spawn swarms)
- If 3+ agents are blocked simultaneously → pause and alert human

## Model Routing
- Ruflo auto-selects model tier per task complexity (saves ~75% API costs)
- Claude Opus 4.6: complex reasoning, architecture decisions
- Claude Sonnet 4.5: standard coding, implementation
- Claude Haiku 4.5: simple tasks, formatting, quick lookups

## Stack Reference
- Orchestration: `npx ruflo@latest` (NOT claude-flow)
- Swarms: `npx ruflo swarm init --topology hierarchical --max-agents 8`
- Memory: Beads (`bd`), Native Tasks, AgentDB (`npx ruflo agentdb`)
- Codebase Graph: GitNexus (`npx gitnexus analyze`)
- Browser: via Ruflo's bundled browser tools (59 MCP tools, element refs, snapshots)
- Observability: via Ruflo's built-in session tracking + AttestationLog
- Plugins: agentic-qe, code-intelligence, test-intelligence, perf-optimizer, teammate, gastown-bridge
- Specs: OpenSpec (`npx @fission-ai/openspec`)

## Ruflo Plugins
- **Agentic QE**: 58 QE agents — TDD, coverage, security scanning, chaos engineering
- **Code Intelligence**: code analysis, pattern detection, refactoring suggestions
- **Test Intelligence**: test generation, gap analysis, flaky test detection
- **Perf Optimizer**: performance profiling, bottleneck detection
- **Teammate Plugin**: bridges Native Agent Teams ↔ Ruflo swarms (21 MCP tools)
- **Gastown Bridge**: WASM-accelerated orchestration, Beads sync (20 MCP tools)
- **OpenSpec**: spec-driven development (`os init`, `os`)

## Codebase Intelligence (GitNexus)
- Index repo: `npx gitnexus analyze` (run from repo root, creates knowledge graph)
- Before editing shared code: check blast radius via GitNexus MCP tools
- Auto-creates AGENTS.md and CLAUDE.md context files
- One MCP server serves all indexed repos — no per-project config needed

## Cost Guardrails
- Hard session cap: $15/hr (configurable)
- Use Haiku for simple tasks — don't burn Opus on formatting
- Monitor: `claude-usage` or ruflo statusline
