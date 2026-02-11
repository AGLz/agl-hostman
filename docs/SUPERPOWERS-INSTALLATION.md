# Superpowers Plugin - Installation Summary

**Date**: 2026-02-09
**Plugin**: obra/superpowers
**Version**: 4.2.0
**Status**: ✅ Installed and Enabled

---

## What is Superpowers?

Superpowers is an open-source agentic framework that transforms Claude Code from a simple code generator into a "true senior AI developer." It has **42k+ stars on GitHub** (ranking #3).

### Key Features

- **7-Stage Development Workflow**: Complete software development process
- **Enhanced Autonomy**: Claude can autonomously program for 2+ hours without going off track
- **Forced Best Practices**:
  - Mandatory brainstorming before coding
  - Enforced TDD (Test-Driven Development)
  - Systematic debugging processes
- **Smart Interception**: Framework intercepts Claude at key moments to ask questions rather than immediately writing code

---

## Installation Details

### Installation Commands
```bash
# Add marketplace
claude plugin marketplace add obra/superpowers-marketplace

# Install plugin
claude plugin install superpowers
```

### Installation Path
```
~/.claude/plugins/cache/superpowers-marketplace/superpowers/4.2.0/
```

### Verification
```bash
# Check plugin status
claude plugin list | grep superpowers

# Output should show:
# superpowers@superpowers-marketplace
# Status: ✔ enabled
```

---

## Available Skills (14 Total)

### Core Development Skills

1. **brainstorming**
   - Use before starting any implementation
   - Forces consideration of multiple approaches

2. **test-driven-development**
   - Enforces TDD methodology
   - Write tests before implementation

3. **systematic-debugging**
   - Structured debugging approach
   - Reduces random trial-and-error

4. **writing-plans**
   - Creates detailed implementation plans
   - Breaks down complex tasks

5. **executing-plans**
   - Follows plans systematically
   - Tracks progress

### Code Review Skills

6. **requesting-code-review**
   - Use when completing code changes
   - Triggers comprehensive review process

7. **receiving-code-review**
   - Handle code review feedback
   - Address review comments properly

### Git & Collaboration Skills

8. **using-git-worktrees**
   - Manage multiple branches simultaneously
   - Work on features in parallel

9. **finishing-a-development-branch**
   - Complete branch cleanup
   - Prepare for merge

### Advanced Development Skills

10. **subagent-driven-development**
    - Spawn specialized subagents
    - Parallel task execution

11. **dispatching-parallel-agents**
    - Coordinate multiple agents
    - Orchestrate complex workflows

12. **writing-skills**
    - Create custom skills
    - Extend framework capabilities

### Quality Assurance Skills

13. **verification-before-completion**
    - Final quality checks
    - Ensure task completion

14. **using-superpowers**
    - Meta-skill for skill discovery
    - **MUST invoke before any work**

---

## Usage

### How Skills Work

**CRITICAL RULE**: If there's even a **1% chance** a skill might apply to your task, you **MUST invoke it**.

### Invoking Skills

In Claude Code, use the `Skill` tool:

```
Use Skill tool: skill = "test-driven-development"
```

When a skill is invoked:
1. Skill content is loaded and presented to you
2. Follow the skill instructions exactly
3. If skill has checklists, create TodoWrite items
4. Complete each checklist item systematically

### Skill Selection Flow

```
User message received
    ↓
Might any skill apply?
    ↓ (even 1% chance)
Invoke Skill tool
    ↓
Announce: "Using [skill] to [purpose]"
    ↓
Follow skill exactly
    ↓
Respond to user
```

---

## Best Practices

### 1. **Start with using-superpowers**
Always invoke `using-superpowers` when starting a new conversation to understand available skills.

### 2. **Check for Relevant Skills**
Before any task, ask yourself: "Is there a skill that applies to this?"

### 3. **Don't Rationalize**
Common red flags that mean you're avoiding skill usage:
- "This is too simple for a skill"
- "I'll just do it quickly this time"
- "The user didn't explicitly ask for skills"
- "I already know how to do this"

**These thoughts mean STOP—you MUST invoke the skill.**

### 4. **Follow Skills Exactly**
When a skill is invoked:
- Read the entire skill content
- Follow instructions precisely
- Don't skip steps
- Create todos for checklists

---

## Integration with Existing Tools

### Claude Flow
Superpowers works alongside:
- Claude Flow MCP server
- Hive-Mind swarm coordination
- ReasoningBank memory system

### Project Configuration
The plugin is automatically available in all Claude Code sessions once installed.

---

## Troubleshooting

### Plugin Not Showing
```bash
# Reinstall plugin
claude plugin install --force superpowers

# Check installation
claude plugin list
```

### Skills Not Invoking
```bash
# Verify skill files exist
ls ~/.claude/plugins/cache/superpowers-marketplace/superpowers/4.2.0/skills/

# Test skill invocation
# In Claude Code, use: Skill("using-superpowers", "")
```

---

## Resources

### Official Documentation
- **GitHub**: https://github.com/obra/superpowers
- **Installation Guide**: https://github.com/obra/superpowers/blob/main/.codex/INSTALL.md
- **Mirror**: https://github.com/wln/obra-superpowers

### Community Resources
- [Superpowers保姆级教程 (Chinese)](https://www.aivi.fyi/llms/introduce-Superpowers)
- [Complete Guide 2026](https://pasqualepillitteri.it/en/news/215/superpowers-claude-code-complete-guide)
- [Tutorials Collection](https://codelove.tw/@tony/post/ayYEMa)

---

## Configuration

### Project-Specific Settings
No additional configuration required. The plugin works globally across all Claude Code sessions.

### Disable Plugin (if needed)
```bash
claude plugin disable superpowers
```

### Re-enable Plugin
```bash
claude plugin enable superpowers
```

---

**Installation completed successfully! ✅**

The Superpowers framework is now ready to enhance your Claude Code development workflow with enforced best practices and systematic development processes.
