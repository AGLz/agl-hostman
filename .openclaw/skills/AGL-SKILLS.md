# OpenClaw AGL Infrastructure Skills

> **Data**: 2026-04-06
> **Propósito**: Portar skills do Claude Code/Qwen para OpenClaw

## Skills Portadas

### 1. AGL Infra Troubleshooting
- **Trigger**: "aglwk45", "vm104", "aglsrv1", "rdp", "meshagent"
- **Função**: Diagnóstico e resolução de problemas na infra AGL
- **Config**: Ver `agl-infra-troubleshooting.json`

### 2. Systematic Debugging
- **Metodologia**: Investigar → Hipótese → Teste → Fix → Verificar
- **Aplicação**: Qualquer bug, falha de teste, comportamento inesperado
- **Regra**: Nunca propor fix antes de investigar root cause

### 3. Git & Deployment
- **Comandos**: cleanup branches, worktrees, push, PR
- **Regra**: Sempre verificar tests antes de push
- **Regra**: Commits descritivos com prefixo `feat|fix|docs|...`

### 4. Security Audit
- **Verificação**: Sem segredos no git, queries parametrizadas, paths validados
- **Scan**: CVE, vulnerabilidades conhecidas
- **Regra**: Nunca expor API keys, tokens, passwords

### 5. Code Review
- **Checklist**: Arquitetura, SOLID, segurança, performance, testes
- **Categorias**: Critical / Important / Suggestions
- **Regra**: Evidence-based, não opinião

## Comandos OpenClaw Úteis

### Infra
```
check aglwk45          # Verificar VM104
fix aglsrv1 memory     # Limpar meshagent leak
restart vm104          # Reboot VM104
```

### Code Quality
```
review code            # Code review
run tests              # npm test + php artisan test
debug issue            # Systematic debugging
```

### Git
```
git cleanup            # Limpar branches
git worktree           # Criar worktree isolado
commit and push        # Commit + push
```

## MCP Servers Disponíveis

O OpenClaw pode aceder MCP servers configurados no `openclaw.json` e via gateway LiteLLM.

**Infra**:
- proxmox (VM/CT management)
- docker (containers)
- portainer (orchestration)
- cloudflare-dns (DNS)

**Dev**:
- github (repo operations)
- context7 (docs)
- memory (knowledge graph)

## Modelos Recomendados por Tarefa

| Tarefa | Modelo | Alias |
|--------|--------|-------|
| Infra troubleshooting | GLM-5 | `glm-5` |
| Code generation | GLM-4.7 | `glm-4.7` |
| Fast tasks | GLM-4.7 Flash | `glm-4.7-flash` |
| Deep reasoning | Kimi K2 Thinking | `kimi-think` |
| Free tier | Llama 3.3 70B | `groq` |

## Integração com LiteLLM

O OpenClaw usa o gateway LiteLLM em agldv03:
- **Gateway**: `http://agldv03:4000`
- **Modelos**: Config em `config/litellm/config.yaml`
- **Cursor**: `cursor-composer` → `openai/gpt-5.3-chat-latest`
