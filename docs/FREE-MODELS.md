# Modelos Gratuitos (Free Tier) - OpenClaw + LiteLLM

## Visão Geral

Configuração otimizada para usar **apenas modelos gratuitos** nos ambientes:
- **agldv03** (CT179 - dev)
- **fgsrv6** (MySQL/APIs/WireGuard)
- **aglwk45** (workstation)

## Modelos Gratuitos Disponíveis (2026-03)

### 1. GLM-4.7-Flash (ZAI) - RECOMENDADO PRIMÁRIO
- **Provider**: ZAI (api.z.ai)
- **Modelo**: `zai/glm-4.7-flash`
- **Contexto**: 131K tokens
- **Custo**: **GRATUITO**
- **Vantagens**: Rápido, boa qualidade, endpoint Anthropic-compatible
- **Obter chave**: https://api.z.ai

### 2. Qwen via DashScope Singapore - FREE TIER
**IMPORTANTE**: Free tier disponível APENAS na região Singapore!

#### Qwen3 Coder Plus
- **Modelo**: `qwen/qwen-coder`
- **Contexto**: 1M tokens
- **Custo**: **GRATUITO**
- **Especialidade**: Código

#### Qwen3.5 Plus
- **Modelo**: `qwen/qwen3.5-plus`
- **Contexto**: 1M tokens
- **Custo**: **GRATUITO**

#### Qwen Turbo
- **Modelo**: `qwen/qwen-turbo`
- **Contexto**: 131K tokens
- **Custo**: **GRATUITO**

- **Obter chave**: https://dashscope.console.aliyun.com/ (região Singapore)

### 3. OpenRouter :free Models
**Provider**: OpenRouter (openrouter.ai)

#### NVIDIA Nemotron 3 Super
- **Modelo**: `openrouter/nvidia/nemotron-3-super-120b-a12b:free`
- **Contexto**: 262K tokens
- **Arquitetura**: Hybrid Mamba-Transformer MoE
- **Custo**: **GRATUITO**

#### MiniMax M2.5
- **Modelo**: `openrouter/minimax/minimax-m2.5:free`
- **Contexto**: 196K tokens
- **Custo**: **GRATUITO**

#### Meta Llama 3.3 70B
- **Modelo**: `openrouter/meta-llama/llama-3.3-70b-instruct:free`
- **Contexto**: 64K tokens
- **Custo**: **GRATUITO**
- **Nível**: GPT-4

#### StepFun Step 3.5 Flash
- **Modelo**: `openrouter/stepfun/step-3.5-flash:free`
- **Contexto**: 131K tokens
- **Custo**: **GRATUITO**

#### Google Gemma 3
- **Gemma 3 4B**: `openrouter/google/gemma-3-4b-it:free` (32K ctx)
- **Gemma 3 12B**: `openrouter/google/gemma-3-12b-it:free` (32K ctx)
- **Gemma 3 27B**: `openrouter/google/gemma-3-27b-it:free` (131K ctx)
- **Custo**: **GRATUITO**

#### Mistral Small 3.1 24B
- **Modelo**: `openrouter/mistralai/mistral-small-3.1-24b-instruct:free`
- **Contexto**: 32K tokens
- **Custo**: **GRATUITO**

#### NousResearch Hermes 3
- **Modelo**: `openrouter/nousresearch/hermes-3-llama-3.1-405b:free`
- **Contexto**: 131K tokens
- **Custo**: **GRATUITO**

#### Router Inteligente
- **Modelo**: `openrouter/openrouter/free`
- **Função**: Seleciona automaticamente modelos gratuitos disponíveis
- **Custo**: **GRATUITO**

- **Obter chave**: https://openrouter.ai/keys

## Modelos REMOVIDOS (não funcionam)

### ❌ Google Gemini 2.5 Flash-Lite via OpenRouter
- **Motivo**: Não funciona via OpenRouter (`:free` tag)
- **Alternativa**: Usar `zai/glm-4.7-flash` (gratuito, melhor qualidade)

## Configuração

### 1. Variáveis de Ambiente Necessárias

```bash
# ZAI (GLM gratuito)
export ZAI_API_KEY="sua-chave-zai"

# DashScope Singapore (Qwen gratuito)
export DASHSCOPE_API_KEY="sua-chave-dashscope-singapore"

# OpenRouter (modelos :free)
export OPENROUTER_API_KEY="sua-chave-openrouter"
```

### 2. Deploy

```bash
# Deploy para agldv03, fgsrv06, aglwk45
./scripts/deploy-openclaw-free-config.sh
```

### 3. Testar Modelos

```bash
# Testar todos os modelos gratuitos
./scripts/test-free-models.sh
```

## Fallbacks Configurados

Os fallbacks no LiteLLM estão configurados para:

1. **Primário**: `zai/glm-4.7-flash` (mais rápido)
2. **Fallback 1**: `qwen/qwen-coder` (bom para código)
3. **Fallback 2**: `qwen/qwen3.5-plus` (1M contexto)
4. **Fallback 3**: `openrouter/nvidia/nemotron-3-super-120b-a12b:free` (262K ctx)
5. **Fallback 4**: `openrouter/meta-llama/llama-3.3-70b-instruct:free`

## Endpoints

### LiteLLM Gateway
- **Local**: `http://localhost:4000`
- **OpenClaw**: Configurado para usar `localhost:4000`

### Uso via OpenClaw

```json
{
  "model": "zai/glm-4.7-flash",
  "messages": [{"role": "user", "content": "Hello"}]
}
```

## Custos

| Modelo | Custo |
|--------|-------|
| GLM-4.7-Flash | **GRATUITO** |
| Qwen Coder | **GRATUITO** |
| Qwen3.5 Plus | **GRATUITO** |
| Qwen Turbo | **GRATUITO** |
| Nemotron 3 Super | **GRATUITO** |
| MiniMax M2.5 | **GRATUITO** |
| Llama 3.3 70B | **GRATUITO** |
| Step 3.5 Flash | **GRATUITO** |
| Gemma 3 | **GRATUITO** |
| Mistral Small | **GRATUITO** |
| Hermes 3 | **GRATUITO** |
| OpenRouter Free | **GRATUITO** |

**Total**: **$0/mês** para todos os modelos!

## Comparação com Modelos Pagos

| Recurso | Gratuito (GLM-4.7-Flash) | Pago (Claude Sonnet 4.6) |
|---------|---------------------------|---------------------------|
| Contexto | 131K | 200K |
| Input | $0/M | $3/M |
| Output | $0/M | $15/M |
| Qualidade | Muito Boa | Excelente |
| Velocidade | Rápido | Rápido |

## Referências

- ZAI API: https://docs.z.ai
- DashScope: https://www.alibabacloud.com/help/en/model-studio
- OpenRouter: https://openrouter.ai/models?q=:free
- LiteLLM: https://github.com/BerriAI/litellm

## Changelog

### 2026-03-28
- ✅ Adicionado GLM-4.7-Flash como primário gratuito
- ✅ Configurado Qwen via DashScope Singapore (free tier)
- ✅ Adicionados todos os modelos OpenRouter :free
- ❌ Removido google/gemini-2.5-flash-lite:free (não funciona)
- ✅ Criado script de teste `test-free-models.sh`
- ✅ Criado script de deploy `deploy-openclaw-free-config.sh`
