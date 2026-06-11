# LiteLLM — Tiers, subscrições e ferramentas (2026-06)

> Política AGL: **paid → local → free**. Free só para burst/fallback.
> Config: `config/litellm/config.yaml` · Benchmark: `scripts/litellm/benchmark-provider-comparison.py`

## O que cada “subscrição” expõe ao LiteLLM

| Ferramenta / plano | Expõe API ao proxy? | Como usar | Aliases LiteLLM |
|--------------------|---------------------|-----------|----------------|
| **Anthropic API** (Claude Pro/Max ≠ API) | ✅ `ANTHROPIC_API_KEY` | Direct ou `ANTHROPIC_BASE_URL` → LiteLLM | `claude-sonnet`, `claude-opus`, `claude-haiku`, `cursor-claude-*` |
| **OpenAI Platform** | ✅ `OPENAI_API_KEY` | Chat Completions | `gpt-5.4`, `gpt-5.4-mini`, `gpt-5-mini`, `cursor-composer*` |
| **Z.AI** (GLM + Coding Plan) | ✅ `ZAI_API_KEY` | OpenAI `/api/openai/v1`, Anthropic `/api/anthropic`, Coding `/api/coding/paas/v4` | `glm-5`, `zai-glm-5`, `zai-coding-glm-4.7`, `glm-4.7-flash` (free tier) |
| **DeepSeek** | ✅ `DEEPSEEK_API_KEY` | Direct | `deepseek`, `qwen-coder` |
| **Moonshot / Kimi** | ✅ `MOONSHOT_API_KEY` | Direct | `kimi`, `kimi-128k` |
| **Google AI Studio** | ✅ `GEMINI_API_KEY` | Direct | `gemini-3.1-pro`, `gemini-lite` (free tier) |
| **Cursor IDE Pro** | ❌ sem API própria | Override Base URL → `http://…:4000/cursor` + virtual key | `cursor-composer`, `cursor-claude-sonnet`, … |
| **OpenClaude CLI** | ❌ (usa proxy) | `ANTHROPIC_BASE_URL` + `ANTHROPIC_AUTH_TOKEN` = master key LiteLLM | `claude-sonnet` (modelo pedido pelo CLI) |
| **OpenCode** | ❌ (usa env) | `OPENAI_BASE_URL` / provider → LiteLLM | `gpt-5.4-mini`, `claude-sonnet`, … |
| **Verdent IDE** | ❌ (multi-modelo local) | Skills + keys como Cursor; apontar para LiteLLM se configurado | Idem Cursor / OpenAI-compat |

**Nota:** subscrições **Cursor Pro**, **Claude Max**, **ChatGPT Plus** não substituem API keys — o LiteLLM consome **billing das plataformas API** (Anthropic/OpenAI/Z.AI/etc.).

## Tiers de modelos

### Local (hardware AGL — VM310 AGLSRV3, 2× RX580 16 GB VRAM, TS `100.67.253.52:11434`)

| Alias | Backend Ollama | Uso |
|-------|----------------|-----|
| `agl-primary` | `qwen3:8b` | Default privado, OpenClaw, baixo custo (~25 tok/s quente) |
| `ollama-qwen3-8b` | Idem | Alias explícito |
| `ollama-qwen3-4b` | `qwen3:8b` | **Legado** (nome histórico) |
| `ollama-qwen3-4b-fast` | `qwen3:4b` | Latência baixa (~39 tok/s) |
| `ollama-gemma3-4b` | `gemma3:4b` | **Mais rápido local** (~44 tok/s JSON bench) |
| `ollama-llama31-8b` | `llama3.1:8b` | JSON/structured (~30 tok/s JSON) |

**Removidos da VM310 (2026-06-11):** `ollama-qwen35-9b`, `ollama-qwen25-coder-7b`, `ollama-deepseek-r1-8b`, `ollama-gemma2-9b` — lentos ou redundantes; usar `deepseek`/`qwen-coder` via API ou `gemma3:4b`/`qwen3:4b-fast` local.

**Removido (2026-06-09):** `ollama-mistral-7b` / `mistral:7b` — ~74s/inferência na RX580 (anómalo vs ~2–6s dos restantes).

**Nota:** modelos Qwen3/DeepSeek-R1 usam `think: false` no proxy + callback (`agl_glm_flash_params.py`) para preencher `content`.

### Paid (subscrição / API billing)

| Alias | Provider real | Subscrição | Verificado agldv03 |
|-------|---------------|------------|-------------------|
| `claude-sonnet` | `anthropic/claude-sonnet-4-6` | Anthropic API | ✅ 200 |
| `claude-haiku` | `anthropic/claude-haiku-4-5` | Anthropic API | ✅ 200 |
| `claude-opus` | `anthropic/claude-opus-4-7` | Anthropic API | — |
| `gpt-5.4-mini` | `openai/gpt-5.4-mini` | OpenAI API | ✅ 200 |
| `gpt-5-mini` | `openai/gpt-5-mini` | OpenAI API | ✅ 200 |
| `gpt-5.4` | `openai/gpt-5.4` | OpenAI API | ✅ 200 |
| `glm-5` | Z.AI `openai/glm-5` | Z.AI | ✅ 200 |
| `zai-glm-5` | Z.AI Anthropic-compat | Z.AI | ✅ 200 |
| `zai-coding-glm-4.7` | Z.AI Coding Plan | Z.AI Coding ~$18/m | ✅ 200 (PONG limpo) |
| `deepseek` | DeepSeek V3.2 | DeepSeek API | ✅ 200 |
| `kimi` | Moonshot | Kimi API | — |
| `cursor-composer` | **OpenAI gpt-5.4-mini** (2026-06) | OpenAI via Cursor proxy | ✅ após redeploy |
| `cursor-claude-sonnet` | Anthropic Sonnet | Anthropic API | ✅ 200 |
| `gemini-3.1-pro` | Google | Gemini API | ⚠️ 429 quota |

### Free / burst (último fallback)

| Alias | Notas |
|-------|-------|
| `glm-4.7-flash`, `glm-flash` | Z.AI free tier; quotas CN peak |
| `groq-llama-31-8b` | Groq free RPM/RPD |
| `or-*-free`, `openrouter-free` | OpenRouter 20 RPM / 50 RPD |
| `gemini-lite` | Google free tier |

## Política de routing AGL (2026-06)

Ordem de preferência para **fallbacks** e defaults de agentes:

1. **Ollama GPU** (`agl-primary`, VM310 TS `100.67.253.52`) — sem limites de tokens; contexto longo e burst
2. **Z.AI** (`zai-glm-5`, `glm-5`, `zai-coding-glm-4.7`) — quota API maior que OpenAI/Anthropic
3. **OpenAI** (`gpt-5.4-mini`, `gpt-5-mini`, …)
4. **Anthropic** (`claude-haiku`, `claude-sonnet`, …)
5. **Outros** (DeepSeek, Kimi, Groq, OpenRouter free)

**CTs aplicados:** Hermes **188** (`--paid-tier`), OpenClaw **187** (`openai/agl-primary`), LiteLLM **186** + dev **agldv03**.

## Routing por ferramenta

```
OpenClaw orchestrator     → agl-primary (Ollama) → zai-glm-5 → glm-5 → gpt-5.4-mini → claude-haiku
Hermes Jarvis             → zai-glm-5 | fallback agl-primary
Hermes Elon/Satya/Werner  → zai-coding-glm-4.7 | fallback agl-primary
EvoNexus (CT548 fgsrv7; ex.242)  → agl-primary (ver config/evonexus/model-defaults.env.example)

Claude Code / OpenClaude  → ANTHROPIC_BASE_URL=LiteLLM CT186, prefer agl-primary / zai-glm-5
Cursor Ask/Plan           → cursor-composer (gpt-5.4-mini) → zai-glm-5 → agl-primary
Cursor Agent              → limitação custom key (#19800) — preferir Ask/Plan

Default app (agl-primary) → Ollama → zai-glm-5 → glm-5 → claude-haiku → gpt-5.4-mini → free
```

## Fallback chains (resumo pós-reorganização 2026-06)

- **`agl-primary`:** `zai-glm-5` → `glm-5` → `claude-haiku` → `gpt-5.4-mini` → `deepseek` → free
- **`gpt-5.4-mini` / `cursor-composer`:** `zai-glm-5` → `glm-5` → `agl-primary` → `claude-haiku` → free (não Groq primeiro)
- **`claude-*`:** outro Claude paid → `zai-glm-5` → `agl-primary` → `gpt-5.4-mini` → free

## Benchmark

```bash
# Só modelos pagos, prompt PONG (rápido)
KEY=$(grep ^LITELLM_MASTER_KEY= /opt/agl-litellm/.env 2>/dev/null | cut -d= -f2- || grep ^LITELLM_MASTER_KEY= /opt/litellm/.env | cut -d= -f2-)
LITELLM_URL=http://100.125.249.8:4000 LITELLM_KEY="$KEY" \
  BENCH_TIER=paid BENCH_PROMPTS=latency \
  python3 scripts/litellm/benchmark-provider-comparison.py

# Suite completa (local + paid + free)
BENCH_TIER=all python3 scripts/litellm/benchmark-provider-comparison.py
```

## Deploy após alterar `config.yaml`

```bash
# CT186 (canónico) — config + callbacks + smoke scripts
bash scripts/litellm/deploy-litellm-callbacks-ct186.sh

# Smoke Ollama (desde agldv03 ou host com rota TS)
bash scripts/litellm/test-ollama-litellm-content.sh agl-primary
bash scripts/litellm/test-ollama-litellm-content.sh ollama-gemma3-4b

# Smoke no próprio CT186
LITELLM_ENV_FILE=/opt/agl-litellm/.env LITELLM_URL=http://127.0.0.1:4000 \
  bash /opt/agl-litellm/scripts/test-ollama-litellm-content.sh ollama-gemma3-4b
```

**Timeouts (2026-06-11):** `request_timeout: 240` global; cold load de modelos 8–12 GB na VM310 pode levar 60–180s.

## Benchmark Ollama (VM310)

```bash
OLLAMA_HOST=http://100.67.253.52:11434 bash scripts/aglsrv3/benchmark-ollama-models.sh --api-only
```

Detalhe: [`docs/AGL-OLLAMA-VM310.md`](AGL-OLLAMA-VM310.md)

## Referências

- [`docs/CURSOR-LITELLM-INTEGRATION.md`](CURSOR-LITELLM-INTEGRATION.md)
- [`docs/AGL-OLLAMA-VM310.md`](AGL-OLLAMA-VM310.md)
- [`docs/LITELLM-MULTI-HOST-DEPLOYMENT.md`](LITELLM-MULTI-HOST-DEPLOYMENT.md)
- [`docs/PROVIDERS-MULTIAGENT-2026.md`](PROVIDERS-MULTIAGENT-2026.md)
- [`docs/LITELLM-PROVIDER-BENCHMARK.md`](LITELLM-PROVIDER-BENCHMARK.md)
