# Arsenal de Guerra — Plano de Aplicação AGL

> **Fonte:** [youtube_002.md](./youtube_002.md) — Maestros da IA (4 pérolas GitHub)  
> **Criado:** 2026-06-29  
> **Status:** Fase 1 implementada

---

## Objetivo

Replicar no ecossistema AGL (Cursor, Claude Code, Hermes CT188, multi-projetos) o pipeline:

**Clareza → Minimalismo → Auditoria separada → Segurança de skills**

---

## Fase 1 — Concluída

| Item                | Harness         | Path / comando                                           |
| ------------------- | --------------- | -------------------------------------------------------- |
| Transcrição YouTube | Todos           | `video-transcript-downloader` / `vtd.js`                 |
| Ponytail            | Cursor          | `.cursor/rules/ponytail.mdc`                             |
| Ponytail            | Claude          | `.claude/skills/ponytail/SKILL.md`                       |
| Improve             | Cursor + Claude | `.cursor/skills/improve/`, `.claude/skills/improve/`     |
| SkillSpector        | CI/local        | `scripts/skills/scan-skill-security.sh`                  |
| Propagação          | Dev LXC         | `scripts/skills/install-arsenal-war-skills.sh`           |
| Hermes              | CT188           | `scripts/proxmox/install-hermes-arsenal-skills-ct188.sh` |
| Workflow vídeo      | Cursor          | `.cursor/skills/agl-video-analysis/SKILL.md`             |

---

## Fase 2 — Concluída (2026-06-29)

1. **draw.io** — skill `agl-architecture-diagram` + `drawio-skill` (Agents365-ai) via install script
2. **SkillSpector** — `install-skillspector.sh`, CI `.github/workflows/skill-security-scan.yml`
3. **Hermes Ponytail** — `install-hermes-arsenal-skills-ct188.sh` tenta `hermes plugins install`
4. **Wiki** — [[Arsenal de Guerra — Vibe Coding com IA]] no llm-wiki

### Fase 3 (opcional)

- Correr install no CT188 em produção
- Ingest automático Curator cron
- Gate CI bloqueante (hoje warning) em findings SkillSpector

---

## Regras de composição (evitar conflitos)

| Situação                               | Prevalece                                       |
| -------------------------------------- | ----------------------------------------------- |
| Ponytail vs shadcn/Laravel em `src/**` | `laravel-boost.mdc` + componentes existentes    |
| Improve vs implementador               | Improve **nunca** edita; Satya/Agent implementa |
| SkillSpector bloqueia skill            | Revisão humana; não `--force` em produção       |
| Auditoria vídeo                        | Curator faz ingest; Jarvis prioriza             |

---

## Comandos rápidos

```bash
# Propagar arsenal (agldv03 / dev)
bash scripts/skills/install-arsenal-war-skills.sh

# Offline / sem Docker para SkillSpector
SKIP_SKILL_SCAN=1 bash scripts/skills/install-arsenal-war-skills.sh

# Scan segurança de uma skill
bash scripts/skills/scan-skill-security.sh .cursor/skills/improve

# Transcrição + análise (agente)
node ~/.cursor/skills/video-transcript-downloader/scripts/vtd.js transcript --url 'URL'

# Hermes CT188 (root no host)
bash scripts/proxmox/install-hermes-arsenal-skills-ct188.sh
```

---

## Definition of Done (fase 1)

- [x] Análise `youtube_002.md` completa
- [x] Ponytail + Improve instalados projeto + global
- [x] Scripts de propagação e scan
- [x] Skill workflow `agl-video-analysis`
- [x] Script Hermes CT188
- [ ] Teste unitário scripts
- [ ] Code review
- [ ] Ingest llm-wiki (opcional fase 2)
