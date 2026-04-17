---
name: qwen-code-agl
description: >
  Manage Qwen Code CLI agent on AGL infrastructure. Use when working with Qwen Code (通义千问),
  its Skills system, SKILL.md files, extensions, or deploying Qwen Code configurations across
  AGL hosts. Covers skill creation (~/.qwen/skills/), project skills (.qwen/skills/),
  skill discovery, model configuration via LiteLLM, and Qwen Code CLI commands.
---
# Qwen Code — AGL Infrastructure

## Overview

Qwen Code is the open-source terminal coding agent from Alibaba (通义千问). It supports
modular **Skills** — capabilities packaged as directories with `SKILL.md` files.

## Skill Locations

| Scope     | Path                        | Shared via Git |
|-----------|-----------------------------|----------------|
| Personal  | `~/.qwen/skills/<name>/`    | No             |
| Project   | `.qwen/skills/<name>/`      | Yes            |
| Extension | `qwen-extension.json` → skills field | Yes  |

## AGL Qwen Code Setup

### Hosts with Qwen Code

| Host     | Tailscale IP      | Skills Installed | LiteLLM       |
|----------|-------------------|------------------|---------------|
| macOS    | local             | ✅ 44 skills     | Remote        |
| agldv03  | 100.94.221.87     | ✅ (sync from 03)| Local :4000   |
| agldv04  | 100.113.9.98      | ✅ (sync from 03)| Local :4000   |
| agldv05  | 100.119.41.63     | ✅ (sync from 03)| Remote (03)   |
| agldv06  | 100.71.229.12     | ✅ (sync from 03)| Remote (03)   |
| agldv07  | 100.80.30.59      | ✅ (sync from 03)| N/A (Archon)  |
| agldv12  | 100.71.217.115    | ✅ (sync from 03)| Local :4000   |
| fgsrv06  | 100.83.51.9       | ✅ (sync from 03)| Local :4000   |

### Current macOS Skills (44 installed)

```
~/.qwen/skills/
├── alt-text/              # Image alt text generation
├── analise-swot/          # SWOT analysis
├── ansible-generator/     # Ansible playbook generation
├── audit-context-building/ # Deep code audit
├── brainstorming/         # Creative brainstorming
├── diagrama-mermaid/      # Mermaid diagrams
├── dockerfile-generator/  # Dockerfile generation
├── github-actions-validator/ # GitHub Actions validation
├── helm-generator/        # Helm chart generation
├── k8s-yaml-generator/    # K8s YAML generation
├── k8s-yaml-validator/    # K8s YAML validation
├── mcp-builder/           # MCP server creation
├── semgrep-rule-creator/  # Semgrep rules
├── skill-creator/         # Skill creation
├── systematic-debugging/  # Systematic debugging
├── terraform-validator/   # Terraform validation
├── webapp-testing/        # Web app testing
├── zeroize-audit/         # Zeroization audit
└── ... (and more)
```

## Skill Structure

```
<skill-name>/
├── SKILL.md              # Required - frontmatter + instructions
├── reference.md          # Optional - reference docs
├── scripts/              # Optional - helper scripts
└── templates/            # Optional - templates
```

### SKILL.md Template

```yaml
---
name: my-skill
description: Brief description of what this Skill does and when to use it.
  Include trigger keywords for reliable model discovery.
---
# My Skill Name

## Instructions
Step-by-step guidance for Qwen Code.

## Examples
Concrete examples of using this Skill.
```

## Common Operations

### List available skills
```bash
ls ~/.qwen/skills/
ls .qwen/skills/
```

### Ask Qwen Code about skills
```
"What Skills are available?"
"Show me my installed skills"
```

### Trigger a skill explicitly
```
/skills <skill-name>
```

### Create a new skill
```bash
mkdir -p ~/.qwen/skills/my-skill
cat > ~/.qwen/skills/my-skill/SKILL.md << 'EOF'
---
name: my-skill
description: Description with trigger keywords
---
# My Skill

## Instructions
...
EOF
```

### Share skills with team
```bash
# Add to project
cp -r ~/.qwen/skills/my-skill .qwen/skills/
git add .qwen/skills/my-skill
git commit -m "feat(skills): add my-skill"
git push
```

## LiteLLM Integration

Qwen Code connects via LiteLLM proxy on AGL hosts:

```bash
# Configure Qwen Code to use LiteLLM
# Set in environment or config
ANTHROPIC_BASE_URL=http://localhost:4000  # Local LiteLLM
# Or for remote:
ANTHROPIC_BASE_URL=http://100.94.221.87:4000  # agldv03 gateway
```

## Deploy Skills to Remote Hosts

```bash
# From macOS to agldv03
scp -r ~/.qwen/skills/proxmox-agl root@100.94.221.87:~/.qwen/skills/
scp -r ~/.qwen/skills/tailscale-agl root@100.94.221.87:~/.qwen/skills/
scp -r ~/.qwen/skills/qemu-agl root@100.94.221.87:~/.qwen/skills/

# Or use the deploy script
./scripts/deploy-skills-all-hosts.sh
```

## Debugging

### Skill not triggering
1. Check description specificity — include exact trigger keywords
2. Verify file path — `SKILL.md` must exist at correct location
3. Check YAML syntax — must start/end with `---`, no tabs
4. Run `qwen --debug` to view loading errors

### Skills not loading
```bash
# Check permissions
ls -la ~/.qwen/skills/

# Check YAML validity
python3 -c "import yaml; yaml.safe_load(open('~/.qwen/skills/my-skill/SKILL.md').split('---')[1])"
```

## References
- https://qwenlm.github.io/qwen-code-docs/en/users/features/skills/
- `.qwen/skills/` — Project skills in this repo
- `~/.qwen/skills/` — Personal skills on macOS
