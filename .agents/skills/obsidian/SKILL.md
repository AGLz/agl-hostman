---
name: obsidian
description: >
  DEPRECATED — usar a skill obsidian-cli (pablo-mano/Obsidian-CLI-skill).
  Ponte oficial Obsidian CLI ↔ vault llm-wiki: ~/.claude/skills/obsidian-cli/
  ou agl-hostman/.claude/skills/obsidian-cli/. Ver llm-wiki/wiki/Obsidian CLI Skill.md
homepage: https://github.com/pablo-mano/Obsidian-CLI-skill
---

# Obsidian (legado)

Esta skill genérica foi **substituída** por **obsidian-cli** do repositório [pablo-mano/Obsidian-CLI-skill](https://github.com/pablo-mano/Obsidian-CLI-skill).

## Usar em vez disto

- Skill: `obsidian-cli` (130+ comandos Obsidian CLI v1.12+)
- Vault AGL: `/mnt/overpower/apps/dev/agl/llm-wiki`
- Sync: `agl-hostman/scripts/skills/sync-six-repos.sh --repo obsidian`

## Referência rápida obsidian-cli

```bash
obsidian search query="termo" format=json
obsidian daily:append content="- nota"
obsidian set-default "llm-wiki"
```

Documentação completa: `~/.claude/skills/obsidian-cli/SKILL.md`
