# Agent OS Skills Registry

> **Version:** 1.0.0
> **Last Updated:** 2026-02-07
> **Total Skills:** 0

This registry documents all available skills in the Agent OS system. Skills are organized by category and provide specific capabilities for agents to perform tasks.

## Structure

```
.agent/skills/
├── skills_index.json          # Central tracking file
├── development/               # Laravel, PHP, Testing skills
├── monitoring/               # Performance, Alerts, Harbor skills
├── devops/                   # Docker, CI/CD, Dokploy skills
├── hive-mind/                # Swarm coordination, Consensus skills
├── integration/              # API, Database, Redis skills
└── _template/                # Skill template structure
    ├── SKILL.md              # Template for new skills
    ├── scripts/              # Skill-specific scripts
    ├── references/           # Reference materials
    └── assets/               # Images, diagrams, etc.
```

## Categories

### Development
**Path:** `.agent/skills/development/`
**Description:** Laravel framework, PHP development, and testing skills

**Available Skills:**
- *None yet - structure created*

### Monitoring
**Path:** `.agent/skills/monitoring/`
**Description:** Performance tracking, alerts, and Harbor integration skills

**Available Skills:**
- *None yet - structure created*

### DevOps
**Path:** `.agent/skills/devops/`
**Description:** Docker containers, CI/CD pipelines, and Dokploy deployment skills

**Available Skills:**
- *None yet - structure created*

### Hive-Mind
**Path:** `.agent/skills/hive-mind/`
**Description:** Swarm coordination, consensus mechanisms, and distributed decision making

**Available Skills:**
- *None yet - structure created*

### Integration
**Path:** `.agent/skills/integration/`
**Description:** API development, database operations, and Redis caching skills

**Available Skills:**
- *None yet - structure created*

## Creating New Skills

### 1. Use the Template

Copy the template structure:
```bash
cp -r .agent/skills/_template .agent/skills/[category]/[skill-name]
```

### 2. Update SKILL.md

Replace template placeholders:
- `{{SKILL_ID}}` - Unique identifier (e.g., `DEV-001`)
- `{{SKILL_NAME}}` - Human-readable name
- `{{CATEGORY}}` - Category from above
- `{{CREATION_DATE}}` - Current date (YYYY-MM-DD)
- All other placeholders with actual content

### 3. Update skills_index.json

Add the new skill to the appropriate category in `skills_index.json`:

```json
{
  "skill_id": "SKILL-ID",
  "name": "Skill Name",
  "file": "category/skill-name/SKILL.md",
  "status": "draft",
  "created": "2026-02-07"
}
```

### 4. Register Here

Add to the appropriate category section in this file.

## Skill Status

- **draft** - Initial definition, not yet implemented
- **in_development** - Being actively developed
- **testing** - Ready for testing
- **production_ready** - Fully implemented and tested

## Skill Metadata

Each skill includes:
- **Skill ID** - Unique identifier
- **Name** - Human-readable name
- **Category** - Primary category
- **Version** - Semantic version
- **Status** - Current development status
- **Dependencies** - Required skills or systems
- **Capabilities** - What the skill can do
- **Usage** - How to use the skill
- **Integration Points** - Files and APIs affected

## Maintenance

- Keep `skills_index.json` synchronized with actual skills
- Update this registry when adding/removing skills
- Use semantic versioning for skill updates
- Archive deprecated skills, don't delete them

---

**Next Steps:**
1. Create individual skill files using the template
2. Update `skills_index.json` with new skills
3. Register skills in this document
4. Test skill capabilities before marking as production_ready
