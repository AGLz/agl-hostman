# Providers para Multi-Agent no OpenClaw — Abril 2026

> Análise baseada no setup atual (`config/litellm/config.yaml`, `config/openclaw/`) e pesquisa de mercado.
> Última atualização: 2026-04-02 — Groq: `GROQ_API_KEY` / `GROQ_API_KEY2`, `scripts/litellm/validate-groq-keys.sh`, sync em `sync-systemd-openclaw-env.sh`.

---

## 1. Setup Atual — O Que Você Já Tem

| Provider | Key (env) | Modelos / estado no LiteLLM | Tier |
|---|---|---|---|
| **Anthropic** | `ANTHROPIC_API_KEY` | claude-opus-4-6, claude-sonnet-4-6, claude-haiku-4-5 | Pro (Claude Code) |
| **ZAI/GLM** | `ZAI_API_KEY` (+ alias `GLM_AUTH`) | GLM-5, GLM-4.7, GLM-4.7-Flash | Zai Pro |
| **Moonshot/Kimi** | `MOONSHOT_API_KEY` (+ `KIMI_AUTH`) | kimi-k2.5 | Pago |
| **DeepSeek** | `DEEPSEEK_API_KEY` (+ `DEEPSEEK_AUTH`) | deepseek-chat, deepseek-reasoner | Pago |
| **OpenAI** | `OPENAI_API_KEY` (+ `OPENAI_AUTH`) | gpt-5.4, gpt-5.3-chat-latest | Pago (Cursor Pro proxy) |
| **Google Gemini** | `GEMINI_API_KEY` (+ `GEMINI_AUTH` / `GOOGLE_API_KEY` no direct) | gemini-3.1-pro-preview | Free / AI Studio |
| **Alibaba/DashScope** | `DASHSCOPE_API_KEY` (+ `ALIBABA_CLOUD_API_KEY` no direct) | Qwen3.5-* | Free Global |
| **OpenRouter** | `OPENROUTER_API_KEY` (+ `OPENROUTER_AUTH`) | router + `:free` (incl. llama-3.3-70b, ex. `or-llama-3.3-70b-free`) | Free |
| **Groq (API nativa)** | `GROQ_API_KEY` (+ opcional `GROQ_API_KEY2`) | `groq/` em `config.yaml` / `config-remote.yaml` (`groq-llama-33`, `groq-gpt-oss-120b`, `*-k2` com segunda chave). Ver **Groq — operação** abaixo. | Free (Groq) |
| **Cerebras (API nativa)** | `CEREBRAS_API_KEY` | `cerebras/` em `config.yaml` (`cerebras-llama-33`, `cerebras-gpt-oss-120b`); sync systemd lê `export` do `~/.zshrc` | Free tier / pago |

**Groq — operação (agl-hostman):**

- **Duas chaves:** `GROQ_API_KEY` e, se quiseres rotação ou segunda conta, `GROQ_API_KEY2` (export no `~/.zshrc` ou env). Ambas estão no `grep` de `scripts/openclaw/sync-systemd-openclaw-env.sh` e são escritas em `~/.config/environment.d/openclaw.conf` quando definidas (valores literais; linhas com `${...}` no valor são ignoradas, como nas outras keys).
- **Validar sem gastar tokens:** `scripts/litellm/validate-groq-keys.sh` chama `GET …/openai/v1/models`. Com chaves só no zsh: `./scripts/litellm/validate-groq-keys.sh --from-zshrc`. Exit 0 = todas as chaves **definidas** OK; exit 2 = nenhuma definida no ambiente.
- **LiteLLM:** o proxy expõe **Groq nativo** (`groq-llama-33`, `groq-gpt-oss-120b`, etc.) e mantém **OpenRouter** `:free` (ex. `or-llama-3.3-70b-free`) como rota alternativa.

**Aliases:** no OpenClaw (`zshrc-openclaw-*.env`), `GLM_AUTH`, `KIMI_AUTH`, `DEEPSEEK_AUTH`, `OPENAI_AUTH`, `GEMINI_AUTH`, `OPENROUTER_AUTH` **espelham** as `*_API_KEY` — não é um segundo segredo.

**Abacus Basic** — ainda não integrado no LiteLLM/OpenClaw (ver seção 5).

---

## 2. Providers Recomendados para Adicionar

### 🔴 Prioridade ALTA

#### Cerebras Inference
- **Por quê**: O provider mais rápido do mercado para agentes sequenciais — 1.800+ t/s em Llama 8B, 450 t/s em Llama 70B. Cada chamada retorna em < 1 s, o que reduz drasticamente o wall-clock de agent loops com muitas chamadas encadeadas.
- **Modelos**: Llama 3.3 70B, Qwen3 32B, Qwen3 235B, GPT-OSS 120B
- **Free tier**: **1M tokens/dia** sem cartão de crédito. Sem waitlist.
- **Pago**: Cerebras Code Pro $50/mês, Code Max $200/mês (ideal para vibe coding agentic de alto volume)
- **Key env:** `CEREBRAS_API_KEY` (`config/litellm/.env.example`, `~/.zshrc`; modelos `cerebras/` no YAML)
- **LiteLLM**: `cerebras/llama3.3-70b`
- **Ref**: https://www.cerebras.ai/pricing

#### xAI / Grok
- **Por quê**: Maior janela de contexto do mercado (2M tokens). Grok 4.1 Fast é baratíssimo para orquestração ou triagem de contexto longo. Grok 4 compete com Opus em qualidade.
- **Modelos**: Grok 4 ($3/$15 por 1M), Grok 4.1 Fast ($0.20/$0.50 por 1M)
- **Free credits**: $25 no signup + $150/mês via data sharing program
- **Rate limits**: até 4M TPM em tiers avançados
- **Key env a criar**: `XAI_API_KEY`
- **LiteLLM**: `xai/grok-4`, `xai/grok-4-fast`
- **Ref**: https://x.ai/api

#### Mistral AI
- **Por quê**: **Codestral** é o melhor modelo de código abaixo de Claude Sonnet em preço. Mistral Large 3 ($2/$6) compete com Sonnet. Mistral Nemo ($0.02/$0.04) é o modelo comercial mais barato do mercado — ideal para sub-agents de triagem, formatação e roteamento.
- **Modelos relevantes**:
  - `codestral-latest` — fill-in-the-middle, código, agentic coding
  - `mistral-large-3` — raciocínio, tasks complexas
  - `mistral-nemo` / `ministral-8b` — tasks leves, pré-triagem
- **Free tier**: 1B tokens/mês (sem cartão), rate limits baixos mas ótimos para dev
- **Key env a criar**: `MISTRAL_API_KEY`
- **LiteLLM**: `mistral/codestral-latest`, `mistral/mistral-large-latest`
- **Ref**: https://mistral.ai/pricing

---

### 🟡 Prioridade MÉDIA

#### Fireworks AI
- **Por quê**: 747 TPS, latência 0.17 s first-token — melhor latência entre os inference providers. Ótimo para code agents onde você precisa de velocidade sem gastar o budget Anthropic.
- **Modelos**: Llama 4 Scout, Llama 3.3 70B, Qwen3, DeepSeek V3
- **Key env a criar**: `FIREWORKS_API_KEY`
- **LiteLLM**: `fireworks_ai/accounts/fireworks/models/llama-v3p3-70b-instruct`
- **Ref**: https://fireworks.ai/pricing

#### Together AI
- **Por quê**: 917 TPS, $25 free credits no signup, suporte a Llama 4 Scout (multimodal), bom para workloads paralelas. Pay-as-you-go funciona bem para tráfego variável.
- **Modelos**: Llama 4 Scout, Llama 3.3 70B, Qwen3, DeepSeek R1
- **Key env a criar**: `TOGETHER_API_KEY`
- **LiteLLM**: `together_ai/meta-llama/Meta-Llama-3.3-70B-Instruct-Turbo`
- **Ref**: https://www.together.ai/pricing

#### Cohere Command A
- **Por quê**: 256K context otimizado para RAG e agentic tasks multilíngues. Command R é o mais barato da Cohere ($0.15/$0.60) para research agents.
- **Modelos**: command-a-03-2025, command-r-plus
- **Key env a criar**: `COHERE_API_KEY`
- **LiteLLM**: `cohere/command-a-03-2025`
- **Ref**: https://cohere.com/pricing

---

### 🟢 Oportunistas (Free / Baixo Custo)

#### OpenRouter :free router
Já tens a key. Aproveitar mais: `openrouter/auto` e modelos `:free` como `meta-llama/llama-3.2-3b-instruct:free` para sub-tasks de baixa criticidade. OpenRouter tem 29 modelos gratuitos permanentes em abril 2026.

#### Gemini Free Tier (melhorar uso)
Já tens a key. Gemini 2.5 Flash-Lite oferece 1.000 requests/dia e 250K TPM no free tier — muito mais do que o configurado atualmente. Útil para research agents de baixo custo com 1M de contexto.

#### Cloudflare Workers AI
- Workers AI tem modelos grátis dentro do free tier (10k neurons/dia)
- Já tens acesso Cloudflare no setup (MCP configurado)
- Útil para preprocessing/triagem sem custo
- **LiteLLM**: `cloudflare/@cf/meta/llama-3.1-8b-instruct`

---

## 3. Comparação de Performance para Multi-Agent

| Provider | Throughput | First-Token | Custo Input/1M | Custo Output/1M | Contexto | Agentic Rating |
|---|---|---|---|---|---|---|
| **Cerebras** | 1.800 t/s | ~0.3 s | $0.10 | $0.10 | 128K | ⭐⭐⭐⭐⭐ (velocidade) |
| **Groq** | 700 t/s | ~0.2 s | $0.05 | $0.08 | 128K | ⭐⭐⭐⭐ |
| **Fireworks** | 747 t/s | **0.17 s** | ~$0.20 | ~$0.90 | 128K | ⭐⭐⭐⭐ |
| **Together AI** | 917 t/s | 0.78 s | $0.18 | $0.18 | 128K | ⭐⭐⭐⭐ |
| **DeepSeek V3.2** | ~200 t/s | ~0.8 s | $0.28 | $0.42 | 64K | ⭐⭐⭐⭐ (valor) |
| **Gemini 2.5 Flash** | ~300 t/s | ~0.5 s | $0.10 | $0.40 | **1M** | ⭐⭐⭐⭐ |
| **Grok 4.1 Fast** | ~400 t/s | ~0.5 s | $0.20 | $0.50 | **2M** | ⭐⭐⭐⭐ |
| **Claude Haiku 4.5** | ~200 t/s | ~0.6 s | $1.00 | $5.00 | 200K | ⭐⭐⭐⭐ |
| **Claude Sonnet 4.6** | ~180 t/s | ~0.8 s | $3.00 | $15.00 | 200K | ⭐⭐⭐⭐⭐ (qualidade) |
| **Mistral Nemo** | ~500 t/s | ~0.3 s | **$0.02** | **$0.04** | 128K | ⭐⭐⭐ (leve) |
| **GLM-5 (ZAI)** | ~150 t/s | ~1.0 s | $1.00 | $3.20 | 200K | ⭐⭐⭐⭐ |
| **Kimi K2.5** | ~150 t/s | ~1.2 s | $0.60 | $3.00 | **262K** | ⭐⭐⭐⭐ |

---

## 4. Estratégia de Routing Recomendada para OpenClaw

```
Tarefa → Qual modelo usar?

ORCHESTRATOR (main agent)
  └─ claude-sonnet-4-6              # Melhor tool use + raciocínio

REASONING / ARQUITETURA
  └─ claude-opus-4-6                # Primário
  └─ grok-4 (fallback)              # 2M ctx, bom para análise de codebase grande

CONTEXTO MUITO LONGO (>200K tokens)
  └─ grok-4-fast                    # 2M tokens, barato
  └─ gemini-2.5-flash               # 1M tokens, free tier

CÓDIGO (geração / completion)
  └─ claude-sonnet-4-6              # Melhor qualidade
  └─ codestral (Mistral)            # Mais barato para fill-in-middle
  └─ deepseek-chat                  # Fallback, excelente valor

FAST/SEQUENTIAL LOOPS (muitas chamadas, latência importa)
  └─ cerebras/llama3.3-70b          # < 1s por chamada
  └─ groq/llama-3.3-70b             # Free, 700 t/s

TRIAGEM / PRÉ-PROCESSAMENTO (barato, não crítico)
  └─ mistral-nemo                   # $0.02/1M, mais barato do mercado
  └─ claude-haiku                   # Fallback

FREE TIER BUFFER (abuse antes de gastar dinheiro)
  └─ cerebras free (1M tok/dia)
  └─ groq free (14.4K req/dia)
  └─ openrouter :free (29 modelos)
  └─ gemini-2.5-flash-lite (1K req/dia)

INFRA AGENT (@infra)              → glm-5 (especializado, fallback sonnet)
STORAGE AGENT (@storage)          → glm-4.7-flash / gemini-flash
RESEARCH AGENT (@research)        → kimi-k2.5 / grok-4-fast
NET AGENT (@net)                  → gemini-lite / cerebras (velocidade)
```

**Alinhamento com o repo (LiteLLM):** **Groq** e **Cerebras** nativos estão em `config.yaml` / `config-remote.yaml`. **Llama 3.3 70B** também segue disponível via **OpenRouter** `:free` e via **Groq** / **Cerebras** com as respetivas keys.

---

## 5. Abacus.AI Basic — Como Integrar

O Abacus Basic dá acesso a modelos via API própria (endpoint OpenAI-compatible).

```yaml
# Adicionar ao config/litellm/config.yaml
- model_name: "abacus-claude-sonnet"
  litellm_params:
    model: "openai/claude-sonnet-4-6"          # nome no catálogo Abacus
    api_key: os.environ/ABACUS_API_KEY
    api_base: "https://api.abacus.ai/api/v0/llm"
  model_info:
    access: abacus
    notes: "usar quando quota Anthropic direta estiver apertada"
```

Adicionar ao `zshrc-openclaw.env`:
```bash
export ABACUS_API_KEY="..."
export ABACUS_URL="https://api.abacus.ai/api/v0/llm"
export ABACUS_AUTH="Bearer $ABACUS_API_KEY"
```

> Verificar o endpoint exato em https://abacus.ai/app/api — o Basic pode ter rate limits baixos (verificar dashboard).

---

## 6. Checklist de Implementação

- [ ] **Cerebras**: criar conta → https://cloud.cerebras.ai → gerar API key → `CEREBRAS_API_KEY` no `.zshrc`
- [ ] **xAI/Grok**: criar conta → https://x.ai/api → $25 free → `XAI_API_KEY`
- [ ] **Mistral**: criar conta → https://console.mistral.ai → free tier → `MISTRAL_API_KEY`
- [ ] **Fireworks**: criar conta → https://fireworks.ai → `FIREWORKS_API_KEY`
- [ ] **Together AI**: criar conta → https://api.together.ai → $25 free → `TOGETHER_API_KEY`
- [ ] Adicionar todos ao `config/litellm/config.yaml` e `config/litellm/config-remote.yaml`
- [ ] Adicionar exports ao `config/openclaw/zshrc-openclaw.env`
- [ ] Rodar `scripts/deploy-openclaw-config.sh` após updates
- [ ] Testar via `openclaw doctor` e `ochealth`
- [ ] **Groq:** validar chaves com `./scripts/litellm/validate-groq-keys.sh --from-zshrc`; no host do proxy LiteLLM, definir `GROQ_API_KEY` (e se aplicável `GROQ_API_KEY2`) no `.env` / ambiente do container

---

## 7. Referências

- [Artificial Analysis — LLM Providers Leaderboard](https://artificialanalysis.ai/leaderboards/providers)
- [API Rate Limits Compared — Stochastic Sandbox Mar 2026](https://stochasticsandbox.com/posts/api-rate-limits-compared-2026-03-22/)
- [Every Free AI API in 2026 — Awesome Agents](https://awesomeagents.ai/tools/free-ai-inference-providers-2026/)
- [Cerebras Pricing](https://www.cerebras.ai/pricing)
- [xAI Models & Pricing](https://docs.x.ai/developers/models)
- [Mistral Pricing](https://mistral.ai/pricing)
- [Fireworks Pricing](https://fireworks.ai/pricing)
- [LLM API Pricing Comparison Apr 2026](https://costgoat.com/compare/llm-api)
- [AI Speed Leaderboard — Awesome Agents](https://awesomeagents.ai/leaderboards/ai-speed-latency-leaderboard/)
