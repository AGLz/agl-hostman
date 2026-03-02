---
name: "Context Rot Mitigation"
description: "Combat the scientifically-confirmed phenomenon where LLM performance degrades as context windows fill. Implements the 4 weapons: Task Management, Session Management, Scaffolding Frameworks, and MCP Consciousness."
version: "1.0.0"
category: "performance-optimization"
tags: ["context-rot", "performance", "tokens", "session-management", "mcp", "prd"]
references:
  - name: "Chroma Context Rot Study"
    url: "https://research.trychroma.com/context-rot"
  - name: "Chase AI Video"
    url: "https://www.youtube.com/watch?v=-xHprsdG4ME"
---

# Context Rot Mitigation Skill

## What This Skill Does

This skill helps prevent **Context Rot** - a scientifically-confirmed phenomenon where LLM performance degrades progressively as the context window fills with conversation history, tools, and MCP servers.

**Key Capabilities**:
- **Token Budget Monitoring**: Track context window usage
- **Session Management**: Know when to reset and how
- **MCP Optimization**: Limit active MCPs to prevent bloat
- **Atomic Task Decomposition**: Break tasks into minimal units
- **PRD Enforcement**: Require specifications before coding

## When to Use This Skill

- Starting a new session or task
- Context window approaching limits (>100k tokens)
- Quality degrading noticeably
- Activating new MCPs
- Planning complex features
- Session running >20 message exchanges

## The 4 Weapons Against Context Rot

### 1. Task Management (Atomic Tasks)

**Principle**: Break tasks into the smallest possible units.

**Checklist for Atomic Tasks**:
- [ ] Completable in < 30 minutes?
- [ ] Clear, testable completion criteria?
- [ ] Requires < 5 files to modify?
- [ ] Describable in < 100 characters?
- [ ] Single responsibility?

**Decomposition Pattern**:
```
Broad Task → Feature → Component → Function → Test case (atomic!)
```

**Example**:
| BAD (Too Broad) | GOOD (Atomic) |
|-----------------|---------------|
| "Build auth system" | "Write test for password validation" |
| "Implement login" | "Create login form component" |
| "Add user management" | "Add password hashing to User model" |

### 2. Session Management

**When to Reset Session**:
- Context window > 100,000 tokens (~50% of Claude's limit)
- Task completed successfully
- Starting a new major feature
- After 20+ back-and-forth exchanges
- Quality noticeably degrading

**How to Reset Correctly**:
1. **Request Summary**: Ask for comprehensive summary
2. **Save Summary**: Store in memory or file
3. **Full Clear**: `Ctrl+C` twice (NOT just `/clear`)
4. **Fresh Start**: Begin new session with summary as context

**Summary Template**:
```markdown
## Session Summary - YYYY-MM-DD

### Completed Tasks
- [Task]: [Result]

### In Progress
- [Task]: [Current state, blockers]

### Key Decisions
- [Decision]: [Rationale]

### Next Steps
1. [Action item]
```

### 3. Scaffolding Frameworks

**Using Subagents with Clean Context**:
- Each subagent gets its own context window
- Delegate complex tasks to specialized agents
- Use Task tool for exploration, coding, testing

**Already Implemented**:
- SPARC methodology (5 phases)
- Agent OS integration
- Mandatory subagent usage (see RULES.md)

### 4. MCP Consciousness (Updated for ENABLE_TOOL_SEARCH)

**With ENABLE_TOOL_SEARCH**: MCPs use deferred/on-demand loading, reducing context bloat significantly.

**How ENABLE_TOOL_SEARCH Changes Things**:
- MCP tools are listed but NOT loaded into context
- Use `ToolSearch` to load specific tools when needed
- Can safely have 20+ MCPs without context pollution
- The "3-4 MCPs max" rule is now OBSOLETE

**ToolSearch Pattern**:
```javascript
// Search for tools by keyword
ToolSearch({ query: "docker container", max_results: 5 })

// Direct select if you know the exact tool name
ToolSearch({ query: "select:mcp__docker__docker_container_list" })

// After ToolSearch returns tools, they become callable
```

**When MCP Removal IS Still Needed**:
- MCP server causing errors
- Unused MCP consuming memory
- Redundant MCPs (keep one, remove others)

**Commands**:
```bash
# Add MCP when needed
claude mcp add --transport http <name> <url>

# Remove MCP if problematic
claude mcp remove <name>

# List active MCPs
claude mcp list
```

**Key Insight**: Focus on Task Management and Session Management - these solve ~90% of context rot. With ENABLE_TOOL_SEARCH, MCP limits are less critical.

## PRD Requirement

**Mandatory**: Before ANY coding task, create a PRD or use the Agent OS workflow:

```
Idea → /plan-product → /write-spec → /create-tasks → /implement-tasks
```

**Minimal PRD Template**:
```markdown
# [Feature Name] Requirements

## Overview
[1-2 sentence description]

## Goals
- [Primary goal]

## Non-Goals
[What this is NOT]

## Features
### Feature 1: [Name]
- Acceptance Criteria:
  - [ ] [Specific, testable criterion]

## Technical Approach
[High-level architecture]

## Dependencies
[Required tools/libraries]
```

## Quick Reference Commands

```bash
# Check active MCPs
claude mcp list

# Remove unused MCP
claude mcp remove <name>

# Request session summary
"Create a comprehensive summary of everything we discussed"

# Start with Agent OS workflow
/plan-product  # Create product overview
/write-spec    # Create detailed spec
/create-tasks  # Break into atomic tasks
/implement-tasks  # Execute with subagents
```

## Context Window Monitoring

**Rough Estimates**:
- 1 token ≈ 1 word (simplified)
- Claude Opus 4.5: 200,000 tokens max
- Warning threshold: 100,000 tokens (50%)
- Auto-compact trigger: ~150,000 tokens

**What Fills Context**:
| Source | Relative Impact |
|--------|-----------------|
| Messages | Medium |
| System prompts | Low |
| Tools | Medium |
| **MCP Tools** | **HIGH** |

## Common Mistakes to Avoid

| Mistake | Correct Approach |
|---------|-----------------|
| Using `/clear` to reset context | Use `Ctrl+C` twice for full clear |
| Removing MCPs just because you have "too many" | With ENABLE_TOOL_SEARCH, keep all useful MCPs |
| Starting to code immediately | Create PRD first, then decompose |
| Tasks too broad | Break into atomic units |
| Long sessions without summaries | Reset at ~100k tokens with summary |

## Integration with Other Skills

This skill works well with:
- **verification-quality**: Verify outputs before claiming completion
- **sparc-methodology**: SPARC phases align with task decomposition
- **performance-analysis**: Analyze token usage patterns
- **swarm-orchestration**: Subagents get clean context windows

## References

- [Chroma Context Rot Study](https://research.trychroma.com/context-rot)
- Video: "The Secret Poison Killing Your Claude Code Performance" - Chase AI
- Ralph Loop Framework (mentioned in video)
- GSD Framework (mentioned in video)

---

*Skill created: 2026-02-18 | Based on Chroma Research Study*
