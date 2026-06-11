# Benchmark comparativo — LiteLLM providers vs Ollama GPU (VM310 qwen3:8b / gemma3:4b)

**Gerado:** 2026-06-06 02:23 UTC  
**LiteLLM (canónico CT186):** `http://100.125.249.8:4000`  
**Nota:** execuções anteriores usavam `100.94.221.87:4000` (agldv03, descontinuado 2026-06-05).
**Ollama directo (VM310):** `http://100.67.253.52:11434`  
**Host benchmark:** `agldv04`  
**Filtro tier:** `all`  

## Resumo executivo

- Testes OK: **24/25**
- Falhas: **1**

### Latência (prompt PONG) — ranking

| Rank | Modelo | Provider | Tier | ms | tok/s | Preview |
|------|--------|----------|------|-----|-------|---------|
| 1 | `glm-4.7-flash` | zai | free | 297 | 26.9 | Jogo clássico de videog |
| 2 | `groq-llama-31-8b` | groq | free | 317 | 25.2 | Jogo clássico de videog |
| 3 | `gemini-lite` | google | free | 424 | 4.7 | PONG |
| 4 | `ollama-qwen3-4b` | ollama | local | 555 | 14.4 |  |
| 5 | `qwen3:4b` | ollama-gpu | unknown | 724 | 33.1 |  |
| 6 | `agl-primary` | ollama | local | 760 | 10.5 |  |
| 7 | `gpt-5-mini` | openai | paid | 908 | 4.4 | PONG |
| 8 | `claude-haiku` | anthropic | paid | 927 | 4.3 | PONG |
| 9 | `glm-flash` | zai | free | 970 | 4.1 | PONG |
| 10 | `qwen-coder` | deepseek | paid | 975 | 8.2 | Jogo clássico de videog |
| 11 | `zai-glm-5` | zai | paid | 1042 | 3.8 | PONG |
| 12 | `cursor-claude-sonnet` | anthropic | paid | 1461 | 2.7 | PONG |
| 13 | `claude-sonnet` | anthropic | paid | 1462 | 2.7 | PONG |
| 14 | `claude-opus` | anthropic | paid | 1468 | 2.7 | PONG |
| 15 | `or-mistral-small-free` | openrouter | free | 1602 | 2.5 | PONG |
| 16 | `openrouter-free` | openrouter | free | 1947 | 10.8 | PONG |
| 17 | `deepseek` | deepseek | paid | 2051 | 1.9 | PONG |
| 18 | `zai-coding-glm-4.7` | zai | paid | 4425 | 44.1 | PONG |
| 19 | `gpt-5.4` | openai | paid | 5610 | 0.7 | PONG |
| 20 | `cursor-composer` | openai | paid | 6211 | 0.6 | PONG |

## Capacidade por prompt

| Modelo | Provider | Tier | PONG | Raciocínio | JSON | PT | Notas |
|--------|----------|------|------|------------|------|-----|-------|
| `agl-primary` | ollama | local | parcial | — | — | — | OK |
| `claude-haiku` | anthropic | paid | OK | — | — | — | OK |
| `claude-opus` | anthropic | paid | OK | — | — | — | OK |
| `claude-sonnet` | anthropic | paid | OK | — | — | — | OK |
| `cursor-claude-sonnet` | anthropic | paid | OK | — | — | — | OK |
| `cursor-composer` | openai | paid | OK | — | — | — | OK |
| `deepseek` | deepseek | paid | OK | — | — | — | OK |
| `gemini-3.1-pro` | google | paid | — | — | — | — | litellm.RateLimitError: litellm.RateLimitError: geminiExcept |
| `gemini-lite` | google | free | OK | — | — | — | OK |
| `glm-4.7-flash` | zai | free | parcial | — | — | — | OK |
| `glm-5` | zai | paid | OK | — | — | — | OK |
| `glm-flash` | zai | free | OK | — | — | — | OK |
| `gpt-5-mini` | openai | paid | OK | — | — | — | OK |
| `gpt-5.4` | openai | paid | OK | — | — | — | OK |
| `gpt-5.4-mini` | openai | paid | OK | — | — | — | OK |
| `groq-llama-31-8b` | groq | free | parcial | — | — | — | OK |
| `kimi` | moonshot | paid | OK | — | — | — | OK |
| `ollama-qwen3-4b` | ollama | local | parcial | — | — | — | OK |
| `openrouter-free` | openrouter | free | OK | — | — | — | OK |
| `or-mistral-small-free` | openrouter | free | OK | — | — | — | OK |
| `or-nemotron-super-free` | openrouter | free | parcial | — | — | — | OK |
| `qwen-coder` | deepseek | paid | parcial | — | — | — | OK |
| `qwen3:4b` | ollama-gpu | unknown | parcial | — | — | — | OK |
| `zai-coding-glm-4.7` | zai | paid | OK | — | — | — | OK |
| `zai-glm-5` | zai | paid | OK | — | — | — | OK |

## Falhas

| Modelo | Prompt | HTTP | Erro |
|--------|--------|------|------|
| `gemini-3.1-pro` | latency | 429 | litellm.RateLimitError: litellm.RateLimitError: geminiException - {
  "error": { |

## Limites de uso por provider (referência web, 2026)

| Provider | Modelo(s) AGL | Limites típicos | Custo |
|----------|---------------|-----------------|-------|
| **Ollama VM110 GPU** | `qwen3:4b` | Sem rate limit; 1 modelo, 4 GB VRAM, `OLLAMA_MAX_LOADED_MODELS=1` | Grátis (hardware local) |
| **Z.AI** | `glm-4.7-flash`, `glm-flash` | GLM-4.7-Flash API grátis; Coding Plan ~$18/mês com quotas 5h+7d; pico 14–18h UTC+8 consome 2–3× | Flash free; resto pay-per-token ou plano |
| **Groq** | `groq-llama-31-8b` | ~30 RPM, 6K–12K TPM, 1K–14.4K RPD (por modelo) | Free tier |
| **OpenRouter** | `or-*-free`, `openrouter-free` | 20 RPM; 50 RPD (sem créditos) ou 1000 RPD após $10 | Free variants |
| **DeepSeek** | `deepseek`, `qwen-coder` | Concurrency-based; throttling em pico; sem RPM fixo público | Pay-per-use baixo |
| **Google Gemini** | `gemini-lite` | Quotas GCP/AI Studio; free tier com limites diários | Free tier limitado |
| **Moonshot/Kimi** | `kimi` | Rate limits por conta API | Pay-per-use |
| **Anthropic** | `claude-*` | RPM/TPM por tier API | Pago (subscrição API) |
| **OpenAI** | `gpt-5.4*`, `cursor-composer*` | Billing platform.openai.com | Pago (subscrição API) |
| **Z.AI Coding** | `zai-coding-glm-4.7` | Quotas plano Coding (~5h/7d) | Plano ~\$18/mês |

Matriz completa subscrições × ferramentas: `docs/LITELLM-MODEL-TIERS.md`.

## Recomendações AGL

- **Qualidade cloud paga:** `claude-sonnet`, `gpt-5.4-mini`, `glm-5`, `zai-coding-glm-4.7`.
- **Privacidade / offline:** `agl-primary` (Ollama GPU).
- **Burst free (último recurso):** `groq-llama-31-8b`, `glm-4.7-flash`, OpenRouter `:free`.
- **Fallback:** paid → local → free (`config/litellm/config.yaml`).

---

_Script: `scripts/litellm/benchmark-provider-comparison.py`_
