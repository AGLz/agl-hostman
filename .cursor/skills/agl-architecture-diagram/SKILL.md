---
name: agl-architecture-diagram
description: |
  Gera diagramas de arquitectura a partir do codebase: Mermaid (rápido, em docs/ADRs)
  ou draw.io (estrutura de módulos, fluxos, integrações externas). Usar após features
  novas, antes de auditoria Improve, ou quando o utilizador pedir mapa visual do sistema.
---

# AGL Architecture Diagram

Clareza estrutural antes de mais prompts — alinhado ao arsenal "draw.io" (Maestros da IA).

## Quando usar

- App cresceu só com vibe coding e ninguém sabe como as partes se ligam
- Nova integração (pagamentos, LLM gateway, filas, storage)
- Handoff para outro agente ou humano
- Input para auditoria **Improve** (`/improve` com contexto visual)

## Modo 1 — Mermaid (default, zero deps)

Para ADRs e docs versionados:

```markdown
# Output: docs/architecture/diagrams/<feature>-flow.md
```

Regras:

- Um diagrama por ficheiro; título H2 + bloco `mermaid`
- Tipos: `flowchart TD`, `sequenceDiagram`, `C4Context` (quando fizer sentido)
- Nomes de nós = paths ou serviços reais (`src/api/server.js`, `CT186 LiteLLM`)
- Ligar a ADR existente em `docs/architecture/` se houver

## Modo 2 — draw.io (codebase → .drawio)

Requer skill **`drawio-skill`** (Agents365-ai) instalada:

```bash
bash scripts/skills/install-arsenal-war-skills.sh   # inclui drawio-skill
```

Workflow:

1. Mapear repo (README, `package.json`, `src/`, `docker/`, routes)
2. Pedir ao agente com drawio-skill: _"Visualize a module structure of this project"_
3. Guardar em `docs/architecture/diagrams/<nome>.drawio`
4. Export PNG opcional para wiki (não commitar PNGs grandes sem pedido)

Dependências opcionais: **draw.io desktop** (export), **graphviz** (`apt install graphviz` — auto-layout).

## Checklist do diagrama

- [ ] Onde ficam os dados (DB, ficheiros, cache)
- [ ] Serviços externos (API keys, webhooks, MCP)
- [ ] Camadas (UI → API → workers → infra)
- [ ] Paths reais citados nas caixas
- [ ] Link no ADR ou `youtube_002` / wiki se for decisão durável

## Composição com arsenal AGL

| Fase         | Ferramenta                      |
| ------------ | ------------------------------- |
| Mapear       | Esta skill (Mermaid ou draw.io) |
| Implementar  | Ponytail (diff mínimo)          |
| Auditar      | Improve (read-only)             |
| Skills novas | SkillSpector                    |

## Referências

- `projects/video-analises/youtube_002.md`
- Skill `drawio-skill` em `.cursor/skills/drawio-skill/`
- `docs/architecture/OVERVIEW.md` (command-center / padrões irmãos)
