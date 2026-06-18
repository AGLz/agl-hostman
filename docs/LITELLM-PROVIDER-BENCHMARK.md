# Benchmark comparativo — LiteLLM providers vs Ollama GPU (VM310)

**Gerado:** 2026-06-18 02:29 UTC  
**LiteLLM:** `http://100.125.249.8:4000`  
**Ollama directo:** `http://100.67.253.52:11434`  
**Config:** `/mnt/overpower/apps/dev/agl/agl-hostman/config/litellm/config.yaml`  
**Host benchmark:** `agldv04`  
**Filtro tier:** `all`  
**Filtro providers:** `all`  
**Modelos LiteLLM:** `84`  

## Resumo executivo

- Testes OK: **76/86**
- Falhas: **10**

### Latência (prompt PONG) — ranking

| Rank | Modelo | Provider | Tier | ms | tok/s | Preview |
|------|--------|----------|------|-----|-------|---------|
| 1 | `groq-llama-33` | groq | free | 201 | 14.9 | PONG |
| 2 | `groq-gpt-oss-120b` | groq | free | 206 | 38.8 |  |
| 3 | `groq-llama-31-8b` | groq | free | 206 | 38.8 | Jogo clássico de videog |
| 4 | `glm-4.7-flash` | zai | paid | 235 | 34.0 | Jogo clássico de videog |
| 5 | `openrouter/openrouter/free` | openrouter | free | 295 | 27.1 | Jogo clássico de videog |
| 6 | `zai/glm-4.7-flash` | zai | free | 297 | 26.9 | Jogo clássico de videog |
| 7 | `openai/ollama-qwen3-4b` | ollama | local | 389 | 20.6 | Okay, the user wants me to respond |
| 8 | `ollama-qwen3-4b-fast` | ollama | local | 405 | 19.8 | Okay, the user wants me to respond |
| 9 | `google/gemini-2.5-flash` | google | paid | 437 | 11.4 |  |
| 10 | `gemini-lite` | google | free | 481 | 4.2 | PONG |
| 11 | `google/gemini-2.5-flash-lite:free` | google | free | 482 | 4.2 | PONG |
| 12 | `google/gemini-2.5-flash-lite` | google | paid | 493 | 4.1 | PONG |
| 13 | `gemini-2.0` | google | paid | 541 | 9.2 |  |
| 14 | `openrouter-free` | openrouter | free | 549 | 14.6 | Jogo clássico de vídeo |
| 15 | `ollama-gemma4-qat` | ollama | local | 576 | 6.9 | PONG  |
| 16 | `gemini-2.5-pro` | google | paid | 644 | 6.2 |  |
| 17 | `qwen3-max` | zai | free | 798 | 5.0 | PONG |
| 18 | `or-mistral-small-free` | openrouter | free | 896 | 4.5 | PONG |
| 19 | `qwen/qwen-turbo` | zai | free | 901 | 4.4 | PONG |
| 20 | `qwen3.5-plus` | zai | free | 952 | 4.2 | PONG |

## Capacidade por prompt

| Modelo | Provider | Tier | PONG | Raciocínio | JSON | PT | Notas |
|--------|----------|------|------|------------|------|-----|-------|
| `agl-primary` | ollama | local | — | — | — | — | timeout after 120s |
| `agl-primary-strong` | ollama | local | OK | — | — | — | OK |
| `agl-primary-zai-glm-flash` | zai | free | OK | — | — | — | OK |
| `claude-haiku` | anthropic | paid | OK | — | — | — | OK |
| `claude-haiku-4-5-20251001` | anthropic | paid | OK | — | — | — | OK |
| `claude-opus` | anthropic | paid | OK | — | — | — | OK |
| `claude-opus-4-6` | anthropic | paid | OK | — | — | — | OK |
| `claude-opus-4-7` | anthropic | paid | OK | — | — | — | OK |
| `claude-sonnet` | anthropic | paid | OK | — | — | — | OK |
| `claude-sonnet-4-5-20250929` | anthropic | paid | OK | — | — | — | OK |
| `claude-sonnet-4-6` | anthropic | paid | OK | — | — | — | OK |
| `gemini` | google | paid | parcial | — | — | — | OK |
| `gemini-2.0` | google | paid | parcial | — | — | — | OK |
| `gemini-2.5-pro` | google | paid | parcial | — | — | — | OK |
| `gemini-3.1-pro` | google | paid | parcial | — | — | — | OK |
| `gemini-lite` | google | free | OK | — | — | — | OK |
| `gemma4-qat` | ollama-gpu | unknown | OK | — | — | — | OK |
| `glm` | zai | paid | OK | — | — | — | OK |
| `glm-4.5-flash` | zai | free | OK | — | — | — | OK |
| `glm-4.7` | zai | paid | — | — | — | — | litellm.RateLimitError: RateLimitError: ZaiException - Insuf |
| `glm-4.7-flash` | zai | paid | parcial | — | — | — | OK |
| `glm-5` | zai | paid | OK | — | — | — | OK |
| `glm-5-turbo` | zai | paid | OK | — | — | — | OK |
| `glm-air` | zai | paid | OK | — | — | — | OK |
| `glm-flash` | zai | free | OK | — | — | — | OK |
| `google/gemini-2.5-flash` | google | paid | parcial | — | — | — | OK |
| `google/gemini-2.5-flash-lite` | google | paid | OK | — | — | — | OK |
| `google/gemini-2.5-flash-lite:free` | google | free | OK | — | — | — | OK |
| `gpt` | openai | paid | OK | — | — | — | OK |
| `gpt-4o` | openai | paid | OK | — | — | — | OK |
| `gpt-4o-mini` | openai | paid | OK | — | — | — | OK |
| `gpt-5-mini` | openai | paid | OK | — | — | — | OK |
| `gpt-5-nano` | openai | paid | OK | — | — | — | OK |
| `gpt-5.4` | openai | paid | OK | — | — | — | OK |
| `gpt-5.4-mini` | openai | paid | OK | — | — | — | OK |
| `gpt-5.4-nano` | openai | paid | parcial | — | — | — | OK |
| `gpt-5.5` | openai | paid | OK | — | — | — | OK |
| `groq-gpt-oss-120b` | groq | free | parcial | — | — | — | OK |
| `groq-llama-31-8b` | groq | free | parcial | — | — | — | OK |
| `groq-llama-33` | groq | free | OK | — | — | — | OK |
| `kimi` | moonshot | paid | OK | — | — | — | OK |
| `kimi-128k` | moonshot | paid | OK | — | — | — | OK |
| `kimi/moonshot-v1-128k` | moonshot | paid | OK | — | — | — | OK |
| `moonshot-v1-128k` | moonshot | paid | OK | — | — | — | OK |
| `ollama-gemma3-4b` | ollama | local | OK | — | — | — | OK |
| `ollama-gemma4-qat` | ollama | local | OK | — | — | — | OK |
| `ollama-llama31-8b` | ollama | local | OK | — | — | — | OK |
| `ollama-qwen3-4b` | ollama | local | parcial | — | — | — | OK |
| `ollama-qwen3-4b-fast` | ollama | local | parcial | — | — | — | OK |
| `ollama-qwen3-8b` | ollama | local | OK | — | — | — | OK |
| `openai/ollama-qwen3-4b` | ollama | local | parcial | — | — | — | OK |
| `openrouter-free` | openrouter | free | parcial | — | — | — | OK |
| `openrouter/google/gemini-2.5-flash-lite:free` | openrouter | free | — | — | — | — | litellm.AuthenticationError: AuthenticationError: Openrouter |
| `openrouter/google/gemma-3-4b-it:free` | openrouter | free | — | — | — | — | litellm.AuthenticationError: AuthenticationError: Openrouter |
| `openrouter/meta-llama/llama-3.3-70b-instruct:free` | openrouter | free | — | — | — | — | litellm.AuthenticationError: AuthenticationError: Openrouter |
| `openrouter/minimax/minimax-m2.5:free` | openrouter | free | — | — | — | — | litellm.AuthenticationError: AuthenticationError: Openrouter |
| `openrouter/mistralai/mistral-small-3.1-24b-instruct:free` | openrouter | free | — | — | — | — | litellm.AuthenticationError: AuthenticationError: Openrouter |
| `openrouter/nousresearch/hermes-3-llama-3.1-405b:free` | openrouter | free | — | — | — | — | litellm.AuthenticationError: AuthenticationError: Openrouter |
| `openrouter/nvidia/nemotron-3-super-120b-a12b:free` | openrouter | free | — | — | — | — | litellm.AuthenticationError: AuthenticationError: Openrouter |
| `openrouter/openrouter/free` | openrouter | free | parcial | — | — | — | OK |
| `or-gemma-3-12b-free` | openrouter | free | OK | — | — | — | OK |
| `or-gemma-3-27b-free` | openrouter | free | OK | — | — | — | OK |
| `or-gemma-3-4b-free` | openrouter | free | OK | — | — | — | OK |
| `or-glm-air-free` | openrouter | free | — | — | — | — | litellm.AuthenticationError: AuthenticationError: Openrouter |
| `or-hermes-free` | openrouter | free | OK | — | — | — | OK |
| `or-llama-3.3-70b-free` | openrouter | free | OK | — | — | — | OK |
| `or-minimax-m2.5-free` | openrouter | free | OK | — | — | — | OK |
| `or-mistral-small-free` | openrouter | free | OK | — | — | — | OK |
| `or-nemotron-super-free` | openrouter | free | OK | — | — | — | OK |
| `qwen-max` | zai | free | OK | — | — | — | OK |
| `qwen-plus` | zai | free | OK | — | — | — | OK |
| `qwen-turbo` | zai | free | OK | — | — | — | OK |
| `qwen/qwen-turbo` | zai | free | OK | — | — | — | OK |
| `qwen/qwen3.5-plus` | zai | free | OK | — | — | — | OK |
| `qwen3-max` | zai | free | OK | — | — | — | OK |
| `qwen3.5` | zai | free | OK | — | — | — | OK |
| `qwen3.5-flash` | zai | free | OK | — | — | — | OK |
| `qwen3.5-plus` | zai | free | OK | — | — | — | OK |
| `qwen3:8b` | ollama-gpu | unknown | parcial | — | — | — | OK |
| `zai-coding-glm-4.7` | zai | paid | OK | — | — | — | OK |
| `zai-glm-5` | zai | paid | OK | — | — | — | OK |
| `zai-glm-flash` | zai | paid | OK | — | — | — | OK |
| `zai/glm-4.5-flash` | zai | free | OK | — | — | — | OK |
| `zai/glm-4.7` | zai | paid | OK | — | — | — | OK |
| `zai/glm-4.7-flash` | zai | free | parcial | — | — | — | OK |
| `zai/glm-5` | zai | paid | OK | — | — | — | OK |

## Falhas

| Modelo | Prompt | HTTP | Erro |
|--------|--------|------|------|
| `agl-primary` | latency | 408 | timeout after 120s |
| `glm-4.7` | latency | 429 | litellm.RateLimitError: RateLimitError: ZaiException - Insufficient balance or n |
| `openrouter/google/gemini-2.5-flash-lite:free` | latency | 401 | litellm.AuthenticationError: AuthenticationError: OpenrouterException - {"error" |
| `or-glm-air-free` | latency | 401 | litellm.AuthenticationError: AuthenticationError: OpenrouterException - {"error" |
| `openrouter/nvidia/nemotron-3-super-120b-a12b:free` | latency | 401 | litellm.AuthenticationError: AuthenticationError: OpenrouterException - {"error" |
| `openrouter/minimax/minimax-m2.5:free` | latency | 401 | litellm.AuthenticationError: AuthenticationError: OpenrouterException - {"error" |
| `openrouter/meta-llama/llama-3.3-70b-instruct:free` | latency | 401 | litellm.AuthenticationError: AuthenticationError: OpenrouterException - {"error" |
| `openrouter/google/gemma-3-4b-it:free` | latency | 401 | litellm.AuthenticationError: AuthenticationError: OpenrouterException - {"error" |
| `openrouter/mistralai/mistral-small-3.1-24b-instruct:free` | latency | 401 | litellm.AuthenticationError: AuthenticationError: OpenrouterException - {"error" |
| `openrouter/nousresearch/hermes-3-llama-3.1-405b:free` | latency | 401 | litellm.AuthenticationError: AuthenticationError: OpenrouterException - {"error" |

## Limites de uso por provider (referência web, 2026)

| Provider | Modelo(s) AGL | Limites típicos | Custo |
|----------|---------------|-----------------|-------|
| **Ollama VM310 dual-GPU** | `gemma4-qat`, `qwen3:8b` | Sem rate limit; GPU0+GPU1 RX580 | Grátis (hardware local) |
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
