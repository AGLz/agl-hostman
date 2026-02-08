# Skills Implementation Guide

## Overview

This guide provides comprehensive patterns and best practices for implementing Claude Code Skills, based on the [antigravity-awesome-skills](https://github.com/sickn33/antigravity-awesome-skills) repository. Skills are specialized instruction manuals that enable AI coding assistants to become experts in specific areas.

## Table of Contents

1. [Skill Structure Reference](#skill-structure-reference)
2. [YAML Frontmatter](#yaml-frontmatter)
3. [Progressive Disclosure Pattern](#progressive-disclosure-pattern)
4. [Resource Types](#resource-types)
5. [Best Practices Checklist](#best-practices-checklist)
6. [Template Examples](#template-examples)
7. [Integration with Claude Code](#integration-with-claude-code)
8. [Common Patterns](#common-patterns)
9. [Testing and Validation](#testing-and-validation)

---

## Skill Structure Reference

### Minimal Skill Structure

```
.claude/skills/
└── my-skill/
    └── SKILL.md          # Required: Main skill definition
```

### Full-Featured Skill Structure

```
.claude/skills/
└── my-skill/
    ├── SKILL.md          # Required: Main skill file
    ├── README.md         # Optional: Human-readable docs
    ├── scripts/          # Optional: Helper scripts
    │   ├── setup.sh
    │   ├── validate.js
    │   └── generate.py
    ├── resources/        # Optional: Supporting files
    │   ├── templates/
    │   │   ├── component.tsx
    │   │   └── api-template.js
    │   ├── examples/
    │   │   └── sample-output.json
    │   └── schemas/
    │       └── config.schema.json
    └── docs/             # Optional: Extended documentation
        ├── ADVANCED.md
        ├── TROUBLESHOOTING.md
        └── API_REFERENCE.md
```

### Skills Locations

**Personal Skills** (available across all projects):
- Path: `~/.claude/skills/`
- Scope: Available in all projects for this user
- Version Control: NOT committed to git
- Use Case: Personal productivity tools, custom workflows

**Project Skills** (team-shared, version controlled):
- Path: `.claude/skills/` in project root
- Scope: Available only in this project
- Version Control: SHOULD be committed to git
- Use Case: Team workflows, project-specific tools, shared knowledge

---

## YAML Frontmatter

### Required Fields

Every SKILL.md must start with YAML frontmatter:

```yaml
---
name: "Skill Name"
description: "Brief description of what this skill does and when to use it"
---
```

### Field Specifications

#### `name` (REQUIRED)
- **Type**: String
- **Max Length**: 64 characters
- **Format**: Human-friendly display name
- **Usage**: Shown in skill lists, UI, and loaded into Claude's system prompt
- **Best Practice**: Use Title Case, be concise and descriptive
- **Examples**:
  - ✅ "API Documentation Generator"
  - ✅ "React Component Builder"
  - ✅ "Database Schema Designer"
  - ❌ "skill-1" (not descriptive)
  - ❌ "This is a very long skill name that exceeds sixty-four characters" (too long)

#### `description` (REQUIRED)
- **Type**: String
- **Max Length**: 1024 characters
- **Format**: Plain text or minimal markdown
- **Content**: MUST include:
  1. **What** the skill does (functionality)
  2. **When** Claude should invoke it (trigger conditions)
- **Usage**: Loaded into Claude's system prompt for autonomous matching
- **Best Practice**: Front-load key trigger words, be specific about use cases

**Examples**:

```yaml
# ✅ GOOD: Clear "what" and "when"
description: "Generate TypeScript interfaces from JSON schema. Use when converting schemas, creating types, or building API clients."

# ✅ GOOD: Specific technologies and triggers
description: "Debug React performance issues using Chrome DevTools. Use when components re-render unnecessarily, investigating slow updates, or optimizing bundle size."

# ✅ GOOD: Comprehensive but concise
description: "Design and implement RESTful API endpoints following REST principles with proper HTTP methods, status codes, and resource-based conventions. Use when creating or modifying API routes, designing URL structures, or implementing CRUD operations."

# ❌ BAD: No "when" clause
description: "A comprehensive guide to API documentation"

# ❌ BAD: Too vague
description: "Documentation tool"

# ❌ BAD: Missing trigger conditions
description: "Helps with React performance debugging."
```

### Optional Fields

The following fields are NOT part of the Claude Skills specification but may be used for other purposes:

```yaml
---
name: "My Skill"
description: "My description"
version: "1.0.0"       # Not used by Claude
author: "Me"           # Not used by Claude
tags: ["dev", "api"]   # Not used by Claude
---
```

**Important**: Only `name` and `description` are used by Claude. Additional fields are ignored.

### YAML Formatting Rules

```yaml
# ✅ CORRECT: Simple string
name: "API Builder"
description: "Creates REST APIs with Express and TypeScript."

# ✅ CORRECT: Multi-line description
name: "Full-Stack Generator"
description: "Generates full-stack applications with React frontend and Node.js backend. Use when starting new projects or scaffolding applications."

# ✅ CORRECT: Special characters quoted
name: "JSON:API Builder"
description: "Creates JSON:API compliant endpoints: pagination, filtering, relationships."

# ❌ WRONG: Missing quotes with special chars
name: API:Builder  # YAML parse error!

# ❌ WRONG: Missing description
name: "My Skill"
# Missing required field!
```

---

## Progressive Disclosure Pattern

Claude Code uses a **3-level progressive disclosure system** to scale to 100+ skills without context penalty:

### Level 1: Metadata (Name + Description)

**Loaded**: At Claude Code startup, always
**Size**: ~200 chars per skill
**Purpose**: Enable autonomous skill matching
**Context**: Loaded into system prompt for ALL skills

```yaml
---
name: "API Builder"                   # 11 chars
description: "Creates REST APIs..."   # ~50 chars
---
# Total: ~61 chars per skill
# 100 skills = ~6KB context (minimal!)
```

### Level 2: SKILL.md Body

**Loaded**: When skill is triggered/matched
**Size**: ~1-10KB typically
**Purpose**: Main instructions and procedures
**Context**: Only loaded for ACTIVE skills

```markdown
# API Builder

## What This Skill Does
[Main instructions - loaded only when skill is active]

## Quick Start
[Basic procedures]

## Step-by-Step Guide
[Detailed instructions]
```

### Level 3+: Referenced Files

**Loaded**: On-demand as Claude navigates
**Size**: Variable (KB to MB)
**Purpose**: Deep reference, examples, schemas
**Context**: Loaded only when Claude accesses specific files

```markdown
# In SKILL.md
See [Advanced Configuration](docs/ADVANCED.md) for complex scenarios.
See [Troubleshooting Guide](docs/TROUBLESHOOTING.md) if you encounter errors.
Use template: `resources/templates/api-template.js`

# Claude will load these files ONLY if needed
```

**Benefit**: Install 100+ skills with ~6KB context. Only active skill content (1-10KB) enters context.

### Recommended 4-Level Content Structure

```markdown
---
name: "Your Skill Name"
description: "What it does and when to use it"
---

# Your Skill Name

## Level 1: Overview (Always Read First)
Brief 2-3 sentence description of the skill.

## Prerequisites
- Requirement 1
- Requirement 2

## What This Skill Does
1. Primary function
2. Secondary function
3. Key benefit

---

## Level 2: Quick Start (For Fast Onboarding)

### Basic Usage
```bash
# Simplest use case
command --option value
```

### Common Scenarios
1. **Scenario 1**: How to...
2. **Scenario 2**: How to...

---

## Level 3: Detailed Instructions (For Deep Work)

### Step-by-Step Guide

#### Step 1: Initial Setup
```bash
# Commands
```
Expected output:
```
Success message
```

#### Step 2: Configuration
- Configuration option 1
- Configuration option 2

#### Step 3: Execution
- Run the main command
- Verify results

### Advanced Options

#### Option 1: Custom Configuration
```bash
# Advanced usage
```

#### Option 2: Integration
```bash
# Integration steps
```

---

## Level 4: Reference (Rarely Needed)

### Troubleshooting

#### Issue: Common Problem
**Symptoms**: What you see
**Cause**: Why it happens
**Solution**: How to fix
```bash
# Fix command
```

#### Issue: Another Problem
**Solution**: Steps to resolve

### Complete API Reference
See [API_REFERENCE.md](docs/API_REFERENCE.md)

### Examples
See [examples/](resources/examples/)

### Related Skills
- [Related Skill 1](#)
- [Related Skill 2](#)

### Resources
- [External Link 1](https://example.com)
- [Documentation](https://docs.example.com)
```

---

## Resource Types

### Scripts Directory

**Purpose**: Executable scripts that Claude can run
**Location**: `scripts/` in skill directory
**Usage**: Referenced from SKILL.md

```bash
scripts/
├── setup.sh          # Initialization script
├── validate.js       # Validation logic
├── generate.py       # Code generation
└── deploy.sh         # Deployment script
```

Reference from SKILL.md:
```markdown
## Setup
Run the setup script:
```bash
./scripts/setup.sh
```

## Validation
Validate your configuration:
```bash
node scripts/validate.js config.json
```
```

### Resources Directory

**Purpose**: Templates, examples, schemas, static files
**Location**: `resources/` in skill directory
**Usage**: Referenced or copied by scripts

```bash
resources/
├── templates/
│   ├── component.tsx.template
│   ├── test.spec.ts.template
│   └── story.stories.tsx.template
├── examples/
│   ├── basic-example/
│   ├── advanced-example/
│   └── integration-example/
└── schemas/
    ├── config.schema.json
    └── output.schema.json
```

Reference from SKILL.md:
```markdown
## Templates
Use the component template:
```bash
cp resources/templates/component.tsx.template src/components/MyComponent.tsx
```

## Examples
See working examples in `resources/examples/`:
- `basic-example/` - Simple component
- `advanced-example/` - With hooks and context
```

### References Directory

**Purpose**: External documentation or API references
**Location**: `reference/` in skill directory

```bash
reference/
├── api-docs.md
├── best-practices.md
└── troubleshooting.md
```

---

## Best Practices Checklist

### Content Quality

- [ ] Instructions are clear and actionable
- [ ] Examples are realistic and helpful
- [ ] No typos or grammar errors
- [ ] Technical accuracy verified

### Structure

- [ ] Frontmatter is valid YAML
- [ ] Name matches folder name (if applicable)
- [ ] Sections are logically organized
- [ ] Headings follow hierarchy (H1 → H2 → H3)

### Completeness

- [ ] Overview explains the "why"
- [ ] Instructions explain the "how"
- [ ] Examples show the "what"
- [ ] Edge cases are addressed

### Usability

- [ ] A beginner could follow this
- [ ] An expert would find it useful
- [ ] The AI can parse it correctly
- [ ] It solves a real problem

### Progressive Disclosure

- [ ] Core instructions in SKILL.md (~2-5KB)
- [ ] Advanced content in separate docs/
- [ ] Large resources in resources/ directory
- [ ] Clear navigation between levels

### Writing Style

**Use Clear, Direct Language**:

```markdown
# ❌ Bad
You might want to consider possibly checking if the user has authentication.

# ✅ Good
Check if the user is authenticated before proceeding.
```

**Use Action Verbs**:

```markdown
# ❌ Bad
The file should be created...

# ✅ Good
Create the file...
```

**Be Specific**:

```markdown
# ❌ Bad
Set up the database properly.

# ✅ Good
1. Create a PostgreSQL database
2. Run migrations: `npm run migrate`
3. Seed initial data: `npm run seed`
```

---

## Template Examples

### Template 1: Basic Skill (Minimal)

```markdown
---
name: "My Basic Skill"
description: "One sentence what. One sentence when to use."
---

# My Basic Skill

## What This Skill Does
[2-3 sentences describing functionality]

## Quick Start
```bash
# Single command to get started
```

## Step-by-Step Guide

### Step 1: Setup
[Instructions]

### Step 2: Usage
[Instructions]

### Step 3: Verify
[Instructions]

## Troubleshooting
- **Issue**: Problem description
  - **Solution**: Fix description
```

### Template 2: Intermediate Skill (With Scripts)

```markdown
---
name: "My Intermediate Skill"
description: "Detailed what with key features. When to use with specific triggers: scaffolding, generating, building."
---

# My Intermediate Skill

## Prerequisites
- Requirement 1
- Requirement 2

## What This Skill Does
1. Primary function
2. Secondary function
3. Integration capability

## Quick Start
```bash
./scripts/setup.sh
./scripts/generate.sh my-project
```

## Configuration
Edit `config.json`:
```json
{
  "option1": "value1",
  "option2": "value2"
}
```

## Step-by-Step Guide

### Basic Usage
[Steps for 80% use case]

### Advanced Usage
[Steps for complex scenarios]

## Available Scripts
- `scripts/setup.sh` - Initial setup
- `scripts/generate.sh` - Code generation
- `scripts/validate.sh` - Validation

## Resources
- Templates: `resources/templates/`
- Examples: `resources/examples/`

## Troubleshooting
[Common issues and solutions]
```

### Template 3: AGL-Hostman Style (External Reference)

```markdown
---
name: "Laravel API Development"
description: "Design and implement RESTful API endpoints for Laravel applications following REST principles with proper HTTP methods, status codes, and resource-based conventions. Use this skill when creating or modifying API routes in files like routes/api.php, controllers/, or app/Http/Controllers/, implementing API versioning strategies, designing URL structures and resource naming, adding query parameter support for filtering, sorting, pagination and search, configuring HTTP status codes and error responses, implementing rate limiting and throttling, writing API documentation, or setting up request/response handling and validation. Essential for tasks involving controller implementation, route handler configuration, endpoint organization, or any work requiring adherence to REST architectural constraints and Laravel best practices."
---

# Laravel API Development

This Skill provides Claude Code with specific guidance on how to adhere to coding standards as they relate to Laravel API development.

## When to use this skill:

- Creating or modifying Laravel API endpoints and routes
- Working on controller files or request handlers
- Implementing API versioning strategies
- Designing URL structures and resource naming
- Adding query parameter support for filtering, sorting, or pagination
- Setting up rate limiting and API throttling
- Configuring HTTP status codes and error responses
- Writing API documentation or OpenAPI/Swagger specs
- Working with files like `routes/api.php`, `app/Http/Controllers/`

## Instructions

For details, refer to the information provided in this file:
[API Development Standards](../../../agent-os/standards/backend/api.md)
```

---

## Integration with Claude Code

### Skill Discovery

Claude Code automatically discovers skills in:

1. **Personal skills directory**: `~/.claude/skills/`
2. **Project skills directory**: `.claude/skills/`

### Skill Activation

Skills are activated automatically based on:

1. **Description matching**: When user query matches the skill's description
2. **Explicit invocation**: When user mentions the skill by name (e.g., `@skill-name`)
3. **Context inference**: When Claude determines the skill is relevant

### Best Practices for Discoverability

1. **Front-load keywords** in description
2. **Include specific triggers** (file types, commands, scenarios)
3. **Use clear naming** that reflects functionality
4. **Reference in related skills** for cross-discovery

### Example Descriptions with Good Discoverability

```yaml
# Good: Specific triggers and technologies
description: "Create Express.js REST endpoints with Joi validation, Swagger docs, and Jest tests. Use when building new APIs or adding endpoints."

# Good: Clear file type references
description: "Generate React TypeScript components with hooks. Use when working with .tsx files, creating UI components, or scaffolding React apps."

# Good: Specific scenarios
description: "Debug memory leaks in Node.js applications. Use when investigating high memory usage, optimizing performance, or analyzing heap dumps."
```

---

## Common Patterns

### Pattern 1: Brainstorming First

```markdown
## When to Use This Skill

- Use before implementing any new feature
- Use when designing system architecture
- Use when planning database schema
- Use before writing code for complex problems

## Process

1. Understand current context (files, docs, commits)
2. Ask questions one at a time to refine requirements
3. Propose 2-3 approaches with trade-offs
4. Present design in sections (200-300 words each)
5. Validate each section before proceeding
```

### Pattern 2: Testing Strategy

```markdown
## When to Use This Skill

- Use when writing tests for critical user flows
- Use when implementing behavior-focused tests
- Use when setting up test fixtures and mocks
- NOT for edge case testing during development

## Testing Principles

- Test behavior, not implementation
- Focus on critical paths and workflows
- Mock external dependencies
- Keep tests fast (milliseconds for unit tests)
- Use descriptive test names
```

### Pattern 3: Progressive Workflow

```markdown
## Quick Start (80% of use cases)
```bash
# Simple command for common scenario
```

## Standard Workflow (15% of use cases)
[Step-by-step for typical cases]

## Advanced Configuration (5% of use cases)
See [Advanced Guide](docs/ADVANCED.md) for complex scenarios
```

### Pattern 4: Error Handling

```markdown
## Common Errors

### Error: "Authentication failed"
**Cause**: Invalid credentials or expired token
**Solution**:
1. Check credentials in `.env`
2. Regenerate token if needed
3. Verify API permissions

### Error: "Rate limit exceeded"
**Cause**: Too many requests
**Solution**:
- Implement exponential backoff
- Cache responses when possible
- Consider upgrading API tier
```

---

## Testing and Validation

### Validation Checklist

Before finalizing your skill:

**YAML Frontmatter**:
- [ ] Starts with `---`
- [ ] Contains `name` field (max 64 chars)
- [ ] Contains `description` field (max 1024 chars)
- [ ] Description includes "what" and "when"
- [ ] Ends with `---`
- [ ] No YAML syntax errors

**File Structure**:
- [ ] SKILL.md exists in skill directory
- [ ] Directory is DIRECTLY in `~/.claude/skills/[skill-name]/` or `.claude/skills/[skill-name]/`
- [ ] Uses clear, descriptive directory name
- [ ] **NO nested subdirectories** (Claude Code requires top-level structure)

**Content Quality**:
- [ ] Level 1 (Overview) is brief and clear
- [ ] Level 2 (Quick Start) shows common use case
- [ ] Level 3 (Details) provides step-by-step guide
- [ ] Level 4 (Reference) links to advanced content
- [ ] Examples are concrete and runnable
- [ ] Troubleshooting section addresses common issues

**Testing**:
- [ ] Skill appears in Claude's skill list
- [ ] Description triggers on relevant queries
- [ ] Instructions are clear and actionable
- [ ] Scripts execute successfully (if included)
- [ ] Examples work as documented

### How to Test Your Skill

1. **Create the skill directory**:
   ```bash
   mkdir -p ~/.claude/skills/my-skill
   ```

2. **Create SKILL.md** with your content

3. **Restart Claude Code** to refresh skill list

4. **Test with a query** that should trigger your skill:
   ```
   @my-skill help me with [task]
   ```

5. **Verify** that:
   - Skill activates correctly
   - Instructions are followed
   - Output matches expectations

---

## Additional Resources

### Official Documentation

- [Anthropic Agent Skills Documentation](https://docs.claude.com/en/docs/agents-and-tools/agent-skills)
- [GitHub Skills Repository](https://github.com/anthropics/skills)
- [Claude Code Documentation](https://docs.claude.com/en/docs/claude-code)

### Community Resources

- [antigravity-awesome-skills](https://github.com/sickn33/antigravity-awesome-skills) - 233+ community skills
- [Skills Marketplace](https://github.com/anthropics/skills) - Browse official skills

### Learning from Examples

**For Beginners**:
- `brainstorming` - Clear structure
- `git-pushing` - Simple and focused
- `copywriting` - Good examples

**For Advanced**:
- `systematic-debugging` - Comprehensive
- `react-best-practices` - Multiple files
- `mcp-builder` - Complex workflows with scripts

---

## Summary

### Key Takeaways

1. **Structure matters**: Use progressive disclosure (metadata → SKILL.md → resources)
2. **Be specific**: Clear "what" and "when" in descriptions
3. **Keep it lean**: SKILL.md should be ~2-5KB, move large content to separate files
4. **Test thoroughly**: Validate YAML, structure, and actual usage
5. **Learn from others**: Study existing skills for patterns

### Quick Reference

| Component | Required | Max Size | Purpose |
|-----------|----------|----------|---------|
| `name` | Yes | 64 chars | Display name |
| `description` | Yes | 1024 chars | Discovery & matching |
| SKILL.md | Yes | 2-5KB recommended | Main instructions |
| scripts/ | No | Variable | Executable scripts |
| resources/ | No | Variable | Templates, examples |
| docs/ | No | Variable | Extended docs |

---

**Created**: 2025-11-22
**Based on**: [antigravity-awesome-skills](https://github.com/sickn33/antigravity-awesome-skills)
**Version**: 1.0.0
