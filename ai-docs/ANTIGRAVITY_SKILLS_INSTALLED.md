# Skills Antigravity Instaladas - AGL Hostman

> Instalação automatizada das skills do [antigravity-awesome-skills](https://github.com/sickn33/antigravity-awesome-skills)

## Localização

- **Diretório**: `~/.cursor/skills`
- **Uso no Cursor**: `@skill-name` no chat

## Skills Instaladas

### Essenciais

| Skill | Uso | Comando |
|-------|-----|---------|
| concise-planning | Planejamento estruturado de tarefas | `@concise-planning` |
| lint-and-validate | Validação e lint automáticos | `@lint-and-validate` |
| git-pushing | Commits convencionais e push seguro | `@git-pushing` |
| systematic-debugging | Debug estruturado e metódico | `@systematic-debugging` |
| kaizen | Melhoria contínua de código | `@kaizen` |

### Backend & API

| Skill | Uso | Comando |
|-------|-----|---------|
| nodejs-backend-patterns | Padrões Node.js/Express | `@nodejs-backend-patterns` |
| nodejs-best-practices | Boas práticas Node.js | `@nodejs-best-practices` |
| api-patterns | Design de APIs REST/GraphQL | `@api-patterns` |
| api-security-best-practices | Segurança de APIs | `@api-security-best-practices` |
| backend-security-coder | Código backend seguro | `@backend-security-coder` |

### DevOps & Infraestrutura

| Skill | Uso | Comando |
|-------|-----|---------|
| docker-expert | Docker e containers | `@docker-expert` |
| bash-linux | Scripts shell e automação | `@bash-linux` |
| deployment-procedures | Estratégias de deploy | `@deployment-procedures` |
| observability-engineer | Monitoramento e métricas | `@observability-engineer` |
| incident-responder | Resposta a incidentes | `@incident-responder` |

### Testes

| Skill | Uso | Comando |
|-------|-----|---------|
| test-driven-development | TDD red-green-refactor | `@test-driven-development` |
| testing-patterns | Jest, mocking, factories | `@testing-patterns` |
| javascript-testing-patterns | Testes JavaScript/Node | `@javascript-testing-patterns` |

### AI & Agentes

| Skill | Uso | Comando |
|-------|-----|---------|
| mcp-builder | Construção de ferramentas MCP | `@mcp-builder` |
| ai-agents-architect | Arquitetura de agentes | `@ai-agents-architect` |
| agent-memory-systems | Sistemas de memória | `@agent-memory-systems` |
| prompt-engineering | Engenharia de prompts | `@prompt-engineering` |

### Arquitetura

| Skill | Uso | Comando |
|-------|-----|---------|
| architecture | Decisões arquiteturais | `@architecture` |
| architecture-decision-records | ADRs | `@architecture-decision-records` |
| clean-code | Código limpo | `@clean-code` |

### GitHub & OSS

| Skill | Uso | Comando |
|-------|-----|---------|
| commit | Conventional commits | `@commit` |
| create-pr | Pull requests estruturados | `@create-pr` |
| github-workflow-automation | GitHub Actions | `@github-workflow-automation` |

### Segurança

| Skill | Uso | Comando |
|-------|-----|---------|
| vulnerability-scanner | Scanner de vulnerabilidades | `@vulnerability-scanner` |
| security-auditor | Auditoria de segurança | `@security-auditor` |

### Opcionais

| Skill | Uso | Comando |
|-------|-----|---------|
| database-design | Design de schemas | `@database-design` |
| database-migration | Migrações seguras | `@database-migration` |
| sql-optimization-patterns | Otimização SQL | `@sql-optimization-patterns` |
| environment-setup-guide | Setup de ambientes | `@environment-setup-guide` |
| postmortem-writing | Postmortems | `@postmortem-writing` |
| auth-implementation-patterns | Autenticação e autorização | `@auth-implementation-patterns` |
| changelog-automation | Changelogs automáticos | `@changelog-automation` |
| git-advanced-workflows | Git avançado | `@git-advanced-workflows` |

## Workflows Recomendados

### 1. Nova Feature
```
@concise-planning → @test-driven-development → @nodejs-backend-patterns → @lint-and-validate → @git-pushing
```

### 2. Bug Fix
```
@systematic-debugging → @testing-patterns → @kaizen → @lint-and-validate → @git-pushing
```

### 3. Deploy
```
@deployment-procedures → @docker-expert → @observability-engineer
```

### 4. Code Review
```
@clean-code → @security-auditor → @architecture
```

### 5. Incident Response
```
@incident-responder → @systematic-debugging → @postmortem-writing
```

## Atualização

Para atualizar as skills:

```powershell
.\scripts\skills\install-antigravity-skills.ps1
```

## Referências

- [Antigravity Awesome Skills](https://github.com/sickn33/antigravity-awesome-skills)
- [Catálogo Completo](https://github.com/sickn33/antigravity-awesome-skills/blob/main/CATALOG.md)
- [Bundles](https://github.com/sickn33/antigravity-awesome-skills/blob/main/docs/BUNDLES.md)
