# Modelos Gratuitos (Free Tier) - Quick Reference

## Status: ✅ ATUALIZADO 2026-03-28 11:20 UTC

**✅ CONFIGURAÇÃO FINAL (OpenRouter Primary)**:
- Todos modelos via OpenRouter :free
- **agldv03 (100.94.221.87)**: ✅ OPERACIONAL (OpenClaw 2026.2.19)
- **fgsrv06 (100.83.51.9)**: ✅ RESOLVIDO (downgrade 2026.2.19)
- **Versão recomendada**: OpenClaw 2026.2.19 (evitar 2026.3.x)
- Custo: **$0/mês** (todos FREE)

## Modelos Recomendados

### 🥇 Primários (OpenRouter :free - TESTADOS E FUNCIONANDO)
| Alias | Modelo | Provider | Custo | Contexto |
|------|-------|----------|------|---------|
| `llama-free` | `openrouter/meta-llama/llama-3.3-70b-instruct:free` | OpenRouter | **FREE** | 64K |
| `nemotron-free` | `openrouter/nvidia/nemotron-3-super-120b-a12b:free` | OpenRouter | **FREE** | 262K |
| `minimax-free` | `openrouter/minimax/minimax-m2.5:free` | OpenRouter | **FREE** | 196K |

### 🔄 Fallbacks Adicionais (OpenRouter :free)
| Alias | Modelo | Contexto | Custo |
|------|-------|---------|------|
| `gemma-27b-free` | `openrouter/google/gemma-3-27b-it:free` | 131K | **FREE** |
| `gemma-12b-free` | `openrouter/google/gemma-3-12b-it:free` | 32K | **FREE** |
| `gemma-4b-free` | `openrouter/google/gemma-3-4b-it:free` | 32K | **FREE** |
| `mistral-free` | `openrouter/mistralai/mistral-small-3.1-24b-instruct:free` | 32K | **FREE** |
| `hermes-free` | `openrouter/nousresearch/hermes-3-llama-3.1-405b:free` | 131K | **FREE** |
| `step-free` | `openrouter/stepfun/step-3.5-flash:free` | 131K | **FREE** |
| `router-free` | `openrouter/openrouter/free` | 200K | **FREE** |

### ⚠️ Com Problemas (não usar por enquanto)
| Alias | Modelo | Provider | Status |
|------|-------|----------|--------|
| `glm-flash` | `zai/glm-4.7-flash` | ZAI | ❌ 429 Rate Limited |
| `qwen-coder` | `qwen/qwen-coder` | DashScope SG | ❌ 401 via OpenClaw |
| `qwen-plus` | `qwen/qwen3.5-plus` | DashScope SG | ❌ 401 via OpenClaw |
| `qwen-turbo` | `qwen/qwen-turbo` | DashScope SG | ❌ 401 via OpenClaw |

## Variáveis Necessárias

```bash
# OpenRouter (modelos :free) - OBRIGATÓRIO
export OPENROUTER_API_KEY="sk-or-v1-..."

# DashScope Singapore (Qwen gratuito) - OPCIONAL (com problemas)
export DASHSCOPE_API_KEY="sk-..."

# ZAI (GLM gratuito) - OPCIONAL (rate limited)
export ZAI_API_KEY="..."
```

## Deploy

### Opção 1: OpenRouter como Primário (RECOMENDADO)
```bash
# Deploy com OpenRouter como primário (todos FREE)
export OPENROUTER_API_KEY="sua-chave-openrouter"
./scripts/deploy-openclaw-openrouter-primary.sh

# Testar
openclaw agent -m "Hello" --to +15550000000
```

### Opção 2: Debug
```bash
# Testar providers diretos
source ~/.config/environment.d/openclaw.conf
./scripts/test-direct-providers.sh

# Verificar logs do gateway
journalctl --user -u openclaw-gateway -f
```

## Custo Total

**$0/mês** - Todos os modelos são GRATUITOS!

## Status por Host

| Host | Status | Primário | Notas |
|------|--------|----------|-------|
| agldv03 | ✅ OK | Llama 3.3 70B | Funcionando |
| fgsrv06 | ✅ OK | Llama 3.3 70B | Downgrade 2026.2.19 |
| aglwk45 | ❌ PEND | - | QEMU GA indisponível |

## Versão Recomendada

**OpenClaw 2026.2.19** - Última versão estável antes da regressão de autenticação.

**NÃO usar versões 2026.3.x** - Bug conhecido (GitHub issue #34830):
- Erro 401 "Missing Authentication header" com OpenRouter
- Regressão introduzida em 2026.3.2
- Solução: downgrade para 2026.2.19

```bash
# Instalar versão recomendada
npm install -g openclaw@2026.2.19
```

## Links

- OpenRouter: https://openrouter.ai/keys
- DashScope: https://dashscope.console.aliyun.com/ (Singapore)
- ZAI: https://api.z.ai

## Troubleshooting

### Erro 401 - Incorrect API key (DashScope)
- **Causa**: Problema no OpenClaw ao ler variáveis de ambiente
- **Solução**: Usar OpenRouter como primário
- **Teste**: curl direto funciona, OpenClaw falha

### Erro 401 - Missing Authentication header (OpenRouter)
- **Causa**: Variável de ambiente não carregada
- **Solução**: Verificar `~/.config/environment.d/openclaw.conf`
- **Teste**: `cat /proc/$(pidof openclaw)/environ | tr "\0" "\n" | grep OPENROUTER`

### Verificar environment carregado
```bash
pid=$(systemctl --user show --property MainPID openclaw-gateway | cut -d= -f2)
cat /proc/$pid/environ | tr "\0" "\n" | grep -E "(ZAI|DASHSCOPE|OPENROUTER)_API_KEY"
```
