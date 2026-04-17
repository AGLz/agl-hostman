# Cursor CLI — Skills & Agents Configuração

> **Contexto**: Portar capacidades do Claude Code / Qwen CLI para o Cursor CLI
> **Data**: 2026-04-06

## Skills Disponíveis (portadas do Claude Code)

Estas skills estão disponíveis no projeto via `.claude/skills/` e `.agents/skills/`. O Cursor CLI deve usá-las como referência:

### Infra & DevOps (prioridade AGL)
| Skill | Localização | Uso |
|-------|-------------|-----|
| `agl-infra` | `.claude/skills/agl-infra/` | Proxmox, WireGuard, Tailscale |
| `dockerfile-generator` | `~/.claude/skills/`, `~/.qwen/skills/` | Criar Dockerfiles |
| `k8s-yaml-generator` | `~/.claude/skills/`, `~/.qwen/skills/` | K8s manifests |
| `k8s-yaml-validator` | `~/.claude/skills/`, `~/.qwen/skills/` | Validar K8s |
| `helm-generator` | `~/.claude/skills/`, `~/.qwen/skills/` | Helm charts |
| `terraform-validator` | `~/.claude/skills/`, `~/.qwen/skills/` | Terraform validation |
| `ansible-generator` | `~/.claude/skills/`, `~/.qwen/skills/` | Ansible playbooks |

### Code Quality & Git
| Skill | Localização | Uso |
|-------|-------------|-----|
| `systematic-debugging` | `~/.claude/skills/`, `~/.qwen/skills/` | Debug estruturado |
| `test-driven-development` | `~/.claude/skills/`, `~/.qwen/skills/` | TDD |
| `code-review` | `~/.claude/skills/` | Review de código |
| `git-cleanup` | `~/.claude/skills/`, `~/.qwen/skills/` | Limpeza git |
| `using-git-worktrees` | `~/.claude/skills/`, `~/.qwen/skills/` | Worktrees isolados |
| `github-actions-validator` | `~/.claude/skills/`, `~/.qwen/skills/` | GitHub Actions |
| `verification-before-completion` | `~/.claude/skills/`, `~/.qwen/skills/` | Verificar antes de completar |

### Security
| Skill | Localização | Uso |
|-------|-------------|-----|
| `security-audit` | `.agents/skills/`, `~/.claude/skills/` | Auditoria segurança |
| `semgrep-rule-creator` | `~/.claude/skills/`, `~/.qwen/skills/` | Regras Semgrep |
| `zeroize-audit` | `~/.qwen/skills/` | Audit zeroization de secrets |

### Conteúdo & Diagramas
| Skill | Localização | Uso |
|-------|-------------|-----|
| `diagrama-mermaid` | `~/.claude/skills/`, `~/.qwen/skills/` | Diagramas Mermaid |
| `alt-text` | `~/.claude/skills/`, `~/.qwen/skills/` | Alt text para imagens |
| `content-research-writer` | `~/.claude/skills/`, `~/.qwen/skills/` | Escrita com pesquisa |

## Comandos Úteis para Cursor CLI

### Troubleshooting AGL
```
/troubleshoot aglwk45     # Verificar VM104 no AGLSRV1
/troubleshoot aglsrv1     # Verificar host AGLSRV1
```

### Git & Deploy
```
/git cleanup              # Limpar branches
/git worktree create      # Criar worktree isolado
/deploy                   # Deploy operations
```

### Code Quality
```
/review                   # Code review
/test                     # Run tests
/debug                    # Debug systematic
```

## Agents Especializados (referência)

O Claude Code tem 139+ agents definidos em `~/.claude/agents/`. Os mais relevantes para AGL:

| Agent | Uso AGL |
|-------|---------|
| `devops-engineer` | Infra Proxmox, Docker, K8s |
| `sre-engineer` | Reliability, monitoring |
| `security-auditor` | Security review |
| `network-engineer` | WireGuard, Tailscale |
| `performance-engineer` | Otimização |
| `incident-responder` | Incident response |
| `database-optimizer` | DB tuning |
| `backend-developer` | Laravel, Node.js |

## MCP Servers Configurados

Ver `.cursor/mcp.json` — 25 servers configurados incluindo:
- **github** — operações Git
- **proxmox** — gestão VMs/CTs
- **docker** — containers
- **context7** — docs
- **playwright** — web testing
- **archon** — project management
- **cloudflare-dns** — DNS
- **memory** — knowledge graph

## Notas

- O Cursor CLI usa o modelo `cursor-composer` via LiteLLM proxy
- Para tarefas complexas de infra, preferir modelos com reasoning (GLM-5, DeepSeek Reasoner)
- Skills devem ser invocadas por nome quando disponíveis no contexto
