# Skills Antigravity - Quick Reference

> Referência rápida das 38 skills instaladas no projeto AGL Hostman

## 🚀 Uso Rápido

Digite `@skill-name` no chat do Cursor seguido da sua pergunta ou comando.

## 📋 Skills por Categoria

### 🎯 Essenciais (5)
| Skill | Quando usar |
|-------|-------------|
| `@concise-planning` | Planejar qualquer tarefa antes de implementar |
| `@lint-and-validate` | Validar código antes de commitar |
| `@git-pushing` | Fazer commits convencionais e push |
| `@systematic-debugging` | Debugar erros de forma estruturada |
| `@kaizen` | Melhorar código existente |

### 🔧 Backend & API (5)
| Skill | Quando usar |
|-------|-------------|
| `@nodejs-backend-patterns` | Padrões Node.js/Express |
| `@nodejs-best-practices` | Boas práticas Node.js |
| `@api-patterns` | Design de APIs REST/GraphQL |
| `@api-security-best-practices` | Segurança de APIs |
| `@backend-security-coder` | Código backend seguro |

### 🐳 DevOps (5)
| Skill | Quando usar |
|-------|-------------|
| `@docker-expert` | Docker, containers, Compose |
| `@bash-linux` | Scripts shell, automação |
| `@deployment-procedures` | Deploy, rollback, estratégias |
| `@observability-engineer` | Monitoramento, métricas, logs |
| `@incident-responder` | Resposta a incidentes |

### 🧪 Testes (3)
| Skill | Quando usar |
|-------|-------------|
| `@test-driven-development` | TDD red-green-refactor |
| `@testing-patterns` | Jest, mocking, factories |
| `@javascript-testing-patterns` | Testes JavaScript/Node |

### 🤖 AI & Agentes (4)
| Skill | Quando usar |
|-------|-------------|
| `@mcp-builder` | Criar ferramentas MCP |
| `@ai-agents-architect` | Arquitetura de agentes |
| `@agent-memory-systems` | Memória de agentes |
| `@prompt-engineering` | Otimizar prompts |

### 🏗️ Arquitetura (3)
| Skill | Quando usar |
|-------|-------------|
| `@architecture` | Decisões arquiteturais |
| `@architecture-decision-records` | Documentar ADRs |
| `@clean-code` | Código limpo, refatoração |

### 🔐 Segurança (2)
| Skill | Quando usar |
|-------|-------------|
| `@vulnerability-scanner` | Escanear vulnerabilidades |
| `@security-auditor` | Auditoria de segurança |

### 💾 Banco de Dados (3)
| Skill | Quando usar |
|-------|-------------|
| `@database-design` | Design de schemas |
| `@database-migration` | Migrações zero-downtime |
| `@sql-optimization-patterns` | Otimizar queries SQL |

### 🔄 Git & OSS (4)
| Skill | Quando usar |
|-------|-------------|
| `@commit` | Conventional commits |
| `@create-pr` | Pull requests estruturados |
| `@github-workflow-automation` | GitHub Actions, CI/CD |
| `@git-advanced-workflows` | Rebase, cherry-pick, bisect |

### 🛠️ Utilitários (4)
| Skill | Quando usar |
|-------|-------------|
| `@environment-setup-guide` | Setup de ambientes |
| `@postmortem-writing` | Postmortems de incidentes |
| `@auth-implementation-patterns` | Autenticação, JWT, OAuth |
| `@changelog-automation` | Gerar changelogs |

## 🎬 Workflows Prontos

### Nova Feature
```
@concise-planning → @test-driven-development → @nodejs-backend-patterns → @lint-and-validate → @git-pushing
```

### Bug Fix
```
@systematic-debugging → @testing-patterns → @kaizen → @lint-and-validate → @git-pushing
```

### Deploy
```
@deployment-procedures → @docker-expert → @observability-engineer
```

### Code Review
```
@clean-code → @security-auditor → @architecture
```

### Incident Response
```
@incident-responder → @systematic-debugging → @postmortem-writing
```

## 💡 Exemplos Práticos

### Implementar Autenticação JWT
```
@concise-planning Implementar autenticação JWT no backend
@api-security-best-practices Revisar estratégia de segurança
@nodejs-backend-patterns Criar middleware de autenticação
@test-driven-development Criar testes para autenticação
@lint-and-validate Validar código
@git-pushing Commitar mudanças
```

### Otimizar Container Docker
```
@docker-expert Otimizar este Dockerfile para produção
@deployment-procedures Configurar health checks
@observability-engineer Adicionar métricas
```

### Criar Agente AI
```
@ai-agents-architect Projetar arquitetura do agente
@mcp-builder Criar ferramentas MCP
@agent-memory-systems Implementar memória
@prompt-engineering Otimizar prompts
```

### Debug de Erro em Produção
```
@incident-responder Analisar falha no serviço
@systematic-debugging Investigar logs
@observability-engineer Melhorar observabilidade
@postmortem-writing Documentar incidente
```

## 🔄 Atualização

```powershell
.\scripts\skills\install-antigravity-skills.ps1
```

## 📚 Documentação Completa

Ver `ai-docs/ANTIGRAVITY_SKILLS_INTEGRATION.md` para:
- Guia detalhado de uso
- Casos de uso específicos do projeto
- Troubleshooting
- Melhores práticas

## 🔗 Links

- [Catálogo Completo](https://github.com/sickn33/antigravity-awesome-skills/blob/main/CATALOG.md)
- [Repositório](https://github.com/sickn33/antigravity-awesome-skills)
