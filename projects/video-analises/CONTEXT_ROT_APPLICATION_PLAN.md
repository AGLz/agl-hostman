# Context Rot Mitigation Application Plan

> **Source**: "The Secret Poison Killing Your Claude Code Performance" - Chase AI (YouTube)
> **Study Reference**: [Chroma Context Rot Study](https://research.trychroma.com/context-rot)
> **Created**: 2026-02-18
> **Status**: Implementation Plan

---

## Executive Summary

**Context Rot** is a scientifically-confirmed phenomenon where LLM performance degrades progressively as the context window fills. This document outlines how to apply the 4 weapons against context rot to the AGL infrastructure project.

---

## Current State Analysis

### Already Aligned (Strengths)

| Practice | Implementation | Location |
|----------|----------------|----------|
| **Modular Documentation** | `@docs/filename.md` on-demand loading | CLAUDE.md:14 |
| **Mandatory Subagents** | Task tool required for complex operations | RULES.md:57-93 |
| **Concurrent Execution** | Batch operations in single messages | RULES.md:23-41 |
| **SPARC Methodology** | 5-phase TDD development | WORKFLOWS.md |
| **Agent OS Integration** | Spec-driven development | WORKFLOWS.md:21-72 |
| **Skills System** | Auto-apply standards | 16+ skills available |

### Gaps Identified (Improvement Areas)

| Gap | Impact | Priority |
|-----|--------|----------|
| No session management guidelines | Long sessions accumulate context rot | **HIGH** |
| No MCP usage limits | Bloated context window | **HIGH** |
| No PRD requirements | Vague tasks waste tokens | **MEDIUM** |
| No atomic task checklist | Tasks too broad | **MEDIUM** |
| No explicit context rot awareness | Users don't understand the problem | **LOW** |

---

## Implementation Plan

### Phase 1: Session Management (HIGH Priority)

**Objective**: Establish session management guidelines to prevent context rot accumulation.

**Tasks**:
1. [ ] Add session management section to RULES.md
2. [ ] Define "session reset" triggers (token thresholds)
3. [ ] Create summary request templates
4. [ ] Document `/clear` + Ctrl+C restart procedure

**Implementation**:
```markdown
## Session Management Guidelines

### When to Reset Session
- Context window > 100,000 tokens (~50% of Claude's limit)
- Task completed successfully
- Starting a new major feature
- After 20+ back-and-forth exchanges

### How to Reset
1. Request summary: "Create a comprehensive summary of everything we discussed"
2. Save summary to project memory or file
3. Exit session: `Ctrl+C` twice (full clear)
4. Start fresh session with summary as context

### Summary Template
"""
## Session Summary - [Date]

### Completed Tasks
- [Task 1]: [Result]
- [Task 2]: [Result]

### In Progress
- [Task]: [Current state, blockers]

### Key Decisions
- [Decision]: [Rationale]

### Next Steps
- [Action items for next session]
"""
```

---

### Phase 2: MCP Consciousness (HIGH Priority)

**Objective**: Establish MCP usage guidelines to prevent context window bloat.

**Tasks**:
1. [ ] Audit current MCP tools (identify all active)
2. [ ] Create MCP activation matrix (when to use which)
3. [ ] Add MCP guidelines to CLAUDE.md
4. [ ] Document MCP deactivation procedure

**Implementation**:
```markdown
## MCP Usage Guidelines

### Current MCP Inventory
| MCP Server | Tools | When to Activate |
|------------|-------|------------------|
| archon-tailscale | 28 | Task management, knowledge base |
| claude-flow | 50+ | Swarm coordination, neural training |
| github | 20+ | PR management, code review |
| filesystem | 15+ | File operations (rarely needed) |

### Activation Rules
1. **Default**: Only essential MCPs active
2. **Add MCP**: When specific tool is needed
3. **Remove MCP**: After task completes
4. **Maximum**: 3-4 MCPs per session

### Deactivation Command
```bash
claude mcp remove <mcp-name>
```

### MCP Alternatives
- Prefer Skills over MCPs when possible
- Use Custom Instructions for static knowledge
- Use `@docs/` loading for documentation
```

---

### Phase 3: PRD Requirements (MEDIUM Priority)

**Objective**: Require PRD before any coding task.

**Tasks**:
1. [ ] Add PRD template to project
2. [ ] Update RULES.md with PRD requirement
3. [ ] Integrate with Agent OS `/write-spec` workflow

**Implementation**:
```markdown
## PRD Requirement

### Before ANY Coding Task
1. Use `/plan-product` to create product overview
2. Use `/write-spec` to create detailed specification
3. Use `/create-tasks` to break into atomic tasks
4. Only then proceed with `/implement-tasks`

### PRD Template
```markdown
# Product Requirements Document

## Overview
[1-2 sentence description]

## Goals
- [Primary goal]
- [Secondary goals]

## Non-Goals
[What this is NOT]

## Features
### Feature 1: [Name]
- Description: [What it does]
- Acceptance Criteria:
  - [ ] [Criterion 1]
  - [ ] [Criterion 2]

## Technical Approach
[High-level architecture]

## Dependencies
[Required tools/libraries/infrastructure]
```
```

---

### Phase 4: Atomic Task Decomposition (MEDIUM Priority)

**Objective**: Establish atomic task checklist and decomposition guidelines.

**Tasks**:
1. [ ] Create atomic task checklist
2. [ ] Add to `/create-tasks` workflow
3. [ ] Add examples of good vs. bad task decomposition

**Implementation**:
```markdown
## Atomic Task Decomposition

### The Rule
Each task should be completable in ONE session with MINIMAL context.

### Task Size Checklist
- [ ] Can be completed in < 30 minutes?
- [ ] Has clear, testable completion criteria?
- [ ] Requires < 5 files to modify?
- [ ] Can be described in < 100 characters?
- [ ] Has single responsibility?

### Decomposition Examples

#### BAD (Too Broad)
> "Build user authentication system"

#### GOOD (Atomic)
> "Implement password hashing in User model"
> "Create login form component"
> "Add session middleware"
> "Write password validation tests"
> "Create password reset token model"

### Decomposition Pattern
```
Broad Task
  → Feature
    → Component
      → Function
        → Test case
```
```

---

### Phase 5: Documentation Updates (LOW Priority)

**Objective**: Add context rot awareness to project documentation.

**Tasks**:
1. [ ] Add context rot section to CLAUDE.md
2. [ ] Update RULES.md with best practices
3. [ ] Create context rot mitigation skill

---

## Success Metrics

| Metric | Before | Target | Timeline |
|--------|--------|--------|----------|
| Avg session tokens | Unknown | < 80,000 | 2 weeks |
| Tasks per session | Unknown | 3-5 atomic | 2 weeks |
| MCPs active | 10+ | 3-4 | 1 week |
| PRD adoption | 0% | 100% | 1 week |

---

## Implementation Timeline

| Phase | Duration | Start | End |
|-------|----------|-------|-----|
| Phase 1: Session Management | 2 days | Week 1 | Week 1 |
| Phase 2: MCP Consciousness | 2 days | Week 1 | Week 1 |
| Phase 3: PRD Requirements | 3 days | Week 2 | Week 2 |
| Phase 4: Atomic Tasks | 3 days | Week 2 | Week 2 |
| Phase 5: Documentation | 2 days | Week 3 | Week 3 |

---

## Next Actions

1. **Immediate**: Add session management guidelines to RULES.md
2. **Today**: Audit and limit MCP usage
3. **This Week**: Implement PRD requirement for new features
4. **Ongoing**: Apply atomic task decomposition to all work

---

## References

- [Chroma Context Rot Study](https://research.trychroma.com/context-rot)
- Video: "The Secret Poison Killing Your Claude Code Performance" - Chase AI
- Ralph Loop Framework (mentioned in video)
- GSD Framework (mentioned in video)

---

*Document created as part of Hive Mind swarm analysis - 2026-02-18*
