# Free LLM Models - Guia Completo 2025

> **Last Updated**: 2025-02-13
> **Repository**: agl-hostman

## 📋 Quick Reference - Funções cc*

| Função | Modelo | Provedor | Contexto | Status |
|--------|--------|----------|----------|--------|
| `ccgroq` | Llama 3 70B | Groq | 8K | ✅ Free (500 RPM) |
| `ccds` | DeepSeek V3 | DeepSeek | 64K | ✅ Free Chat |
| `ccds2` | DeepSeek V3.1 | OpenRouter | 128K | ✅ Free |
| `ccqwen` | Qwen 2.5 7B | OpenRouter | 128K | ✅ Free |
| `ccllama3` | Llama 3 70B | OpenRouter | 128K | ✅ Free |
| `ccllama31` | Llama 3.1 405B | OpenRouter | 128K | ✅ Free |
| `ccmistral` | Mistral 7B | OpenRouter | 32K | ✅ Free |
| `ccmist` | Devstral 2512 | OpenRouter | 32K | ✅ Free |
| `ccphi` | Phi-3 Mini | OpenRouter | 4K | ✅ Free |
| `ccgemma` | Gemma 3 27B | OpenRouter | 32K | ✅ Free |
| `ccgem` | Gemini 2.5 Flash | OpenRouter | 1M | ⚠️ Rate limited |
| `ccgem2` | Gemini 2.5 Flash | Google Direct | 1M | ⚠️ Rate limited |
| `ccmimo` | MiMo V2 Flash | OpenRouter | 32K | ✅ Free |
| `ccz` / `ccglm5` | GLM-5 | Zhipu AI | 128K | ✅ Recomendado |
| `ccglm4` | GLM-4.7 | Zhipu AI | 200K | ✅ Free tier |
| `ccmm` | MiniMax M2.1 | MiniMax | 128K | 💰 Pago |
| `ccmm25` | MiniMax M2.5 | MiniMax | 128K | 💰 Pago |
| `ccmm2` | MiniMax M2 | OpenRouter | 128K | ✅ Free limitado |
| `cc_tbm` | MiniMax M2 | TBM.ai | 128K | ✅ Free tier |
| `ccgpt` | GPT-4.1 Nano | OpenAI | 128K | 💰 Pago |
| `cckimi` | Kimi K2 | Moonshot | 128K | 💰 Pago |
| `ccllm` | Local LLM | localhost | - | 🔧 Local |

---

## 🆓 Melhores Opções Gratuitas

### 1. GLM-5 (Recomendado)
```bash
ccz        # ou ccglm5
```
- **Contexto**: 128K tokens
- **Preço**: $0.60/M input, $2.20/M output
- **Vantagens**: Open-source (MIT), boa em código
- **Endpoint**: `https://api.z.ai/api/anthropic`

### 2. Groq (Mais Rápido)
```bash
ccgroq
```
- **Modelo**: Llama 3 70B
- **Rate Limits**: 500 RPM, 20M TPM
- **Preço**: ~$0.59/M tokens
- **Endpoint**: `https://api.groq.com/openai/v1/chat/completions`

### 3. DeepSeek (Chat Gratuito)
```bash
ccds
```
- **Modelo**: DeepSeek V3
- **Preço**: Chat gratuito, API $0.14/M
- **Endpoint**: `https://api.deepseek.com/anthropic`

### 4. OpenRouter Free Models
```bash
ccqwen      # Qwen 2.5 7B
ccllama3    # Llama 3 70B
ccllama31   # Llama 3.1 405B
ccmistral   # Mistral 7B
ccphi       # Phi-3 Mini
ccgemma     # Gemma 3 27B
```
- **Rate Limits**: 20 RPM para modelos :free
- **Endpoint**: `https://openrouter.ai/api`

---

## 📊 Comparação de Contexto

| Modelo | Contexto | Output Max |
|--------|----------|------------|
| Gemini 2.5 Flash | 1M tokens | 8K |
| GLM-4.7 | 200K | 128K |
| Llama 3.1 | 128K | 4K |
| DeepSeek V3 | 64K | 8K |
| MiniMax M2.5 | 128K | 8K |
| GLM-5 | 128K | 8K |

---

## 🔧 Configuração do .zshrc

### Variáveis de Ambiente
```bash
# API Keys
GROQ_URL="https://api.groq.com/openai/v1/chat/completions"
GROQ_AUTH="gsk_xxx"

DEEPSEEK_URL="https://api.deepseek.com/anthropic"
DEEPSEEK_AUTH="sk-xxx"

OPENROUTER_URL="https://openrouter.ai/api"
OPENROUTER_AUTH="sk-or-v1-xxx"

GLM_URL="https://api.z.ai/api/anthropic"
GLM_AUTH="xxx"

MINIMAX_URL="https://api.minimax.io/anthropic"
MINIMAX_AUTH="sk-api-xxx"

TBM_URL="https://api.tbm.ai/anthropic"
TBM_AUTH="sk-xxx"

# Timeout e performance
export API_TIMEOUT_MS=3000000
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
```

### Função Base
```bash
cc_envs () {
    export ANTHROPIC_API_KEY=""
    export ANTHROPIC_AUTH_TOKEN="$MODEL_AUTH_TOKEN"
    export ANTHROPIC_BASE_URL="$MODEL_BASE_URL"
    export ANTHROPIC_MODEL="$MODEL_ROBUST"
    export ANTHROPIC_SMALL_FAST_MODEL="$MODEL_FAST"
    cc_envs_all
}
```

### Padrão de Função
```bash
ccXXX () {
    export MODEL_ROBUST="modelo-robusto"
    export MODEL_FAST="modelo-rapido"
    export MODEL_BASE_URL="$PROVIDER_URL"
    export MODEL_AUTH_TOKEN="$PROVIDER_AUTH"
    cc_envs
}
```

---

## 🚨 Limitações Conhecidas

### Groq
- Contexto limitado a 8K tokens
- Rate limiting agressivo em horários de pico

### DeepSeek
- Chat gratuito, mas API paga
- Rate limits não documentados

### OpenRouter Free
- 20 RPM para modelos :free
- Queue em horários de pico

### Gemini Free
- 15 RPM, 1M TPM
- Reduzido de 1500 para 20 requests/dia (Dez 2025)
- Dados usados para treinamento

### MiniMax
- **Free tier terminou em 7/Nov/2025**
- Agora pago: $0.30/M input

---

## 💡 Recomendações por Uso

| Cenário | Modelo | Função |
|---------|--------|--------|
| **Desenvolvimento geral** | GLM-5 | `ccz` |
| **Código rápido** | Groq Llama 3 | `ccgroq` |
| **Contexto longo** | Gemini Flash | `ccgem` |
| **Gratuito total** | DeepSeek | `ccds` |
| **Múltiplos modelos** | OpenRouter | `ccqwen`, etc |
| **Produção** | MiniMax M2.5 | `ccmm25` |

---

## 📚 Fontes

- [cheahjs/free-llm-api-resources](https://github.com/cheahjs/free-llm-api-resources)
- [MiniMax API Docs](https://platform.minimax.io/docs)
- [OpenRouter Models](https://openrouter.ai/models)
- [Groq Console](https://console.groq.com)
- [Zhipu AI (GLM)](https://z.ai)

---

## 🔄 Atualizações

| Data | Mudança |
|------|---------|
| 2025-02-13 | Adicionado GLM-5, TBM, MiniMax M2.5 |
| 2025-11-07 | MiniMax free tier terminou |
| 2025-12-07 | Gemini free tier reduzido drasticamente |

---

**Maintainer**: Claude Code (agl-hostman)
