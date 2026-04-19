# Context Rot Quick Reference Card

> **Source**: [Chroma Study](https://research.trychroma.com/context-rot) | Skill: `context-rot-mitigation`

---

## ⚡ CRITICAL RULES

| Rule | Limit | Action |
|------|-------|--------|
| Context Window | < 100k tokens | Reset session with summary |
| MCPs Active | 3-4 max | Remove unused MCPs |
| Task Duration | < 30 min | Break into atomic tasks |
| Session Exchanges | < 20 messages | Consider reset |

---

## 🔄 SESSION RESET PROTOCOL

```
1. REQUEST: "Create a comprehensive summary of everything we discussed"
2. SAVE: Store in /docs/session-summaries/YYYY-MM-DD.md
3. CLEAR: Ctrl+C twice (NOT just /clear)
4. RESUME: Start new session with summary as context
```

---

## 🔌 MCP MANAGEMENT (Updated for ENABLE_TOOL_SEARCH)

**With ENABLE_TOOL_SEARCH**: Tools load on-demand, reducing context bloat. The "3-4 MCPs max" rule is OBSOLETE.

### ToolSearch Pattern
```javascript
// Search for tools by keyword
ToolSearch({ query: "docker container", max_results: 5 })

// Direct select exact tool
ToolSearch({ query: "select:mcp__docker__docker_container_list" })

// After search, tools become callable
```

### When to Remove MCPs
| Scenario | Action |
|----------|--------|
| MCP causing errors | `claude mcp remove <name>` |
| Redundant MCPs | Keep one, remove others |
| Session sluggish | Check MCP count |

### When NOT to Remove
| Scenario | Why |
|----------|-----|
| Many MCPs configured | ENABLE_TOOL_SEARCH handles bloat |
| Tools available but unused | Not loaded until requested |

---

## 📋 ATOMIC TASK CHECKLIST

Before creating a task, verify:
- [ ] Completable in < 30 minutes?
- [ ] Clear, testable completion criteria?
- [ ] Requires < 5 files to modify?
- [ ] Describable in < 100 characters?
- [ ] Single responsibility?

---

## 📝 PRD WORKFLOW

```
Idea → /plan-product → /write-spec → /create-tasks → /implement-tasks
```

### Minimal PRD Template

```markdown
# [Feature] Requirements

## Overview
[1-2 sentences]

## Goals
- [Primary goal]

## Non-Goals
[What this is NOT]

## Features
### Feature 1
- Acceptance Criteria:
  - [ ] [Testable criterion]
```

---

## 🎯 THE 4 WEAPONS

1. **Task Management** → Atomic tasks only
2. **Session Management** → Reset at ~100k tokens
3. **Scaffolding** → Subagents get clean context
4. **MCP Consciousness** → 3-4 MCPs maximum

**Key**: Weapons 1 + 2 solve ~90% of context rot!

---

## ⚠️ COMMON MISTAKES

| Mistake | Correct |
|---------|---------|
| `/clear` resets context | Use `Ctrl+C` twice |
| Activate all MCPs | Add on-demand only |
| Code immediately | Create PRD first |
| Broad tasks | Break into atomic |

---

*Quick Ref v1.0 | 2026-02-18*
