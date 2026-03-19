# OpenClaw - Documentação AGL

> **Last Updated**: 2026-03-07 | **Version doc**: 1.3.0

**OpenClaw** é uma plataforma de agente AI autônomo self-hosted. Funciona como assistente pessoal com suporte a múltiplos canais (Telegram, Slack, Discord, WhatsApp etc.), multi-agentes, roteamento de modelos e automação via LLMs.

- **Site**: https://openclaw.ai
- **Docs**: https://docs.openclaw.ai
- **GitHub**: https://github.com/openclaw/openclaw
- **Config**: `~/.openclaw/openclaw.json`

---

## 🔄 Atualizações de Modelos (2026-03-07)

| Provider | Modelo Anterior | Modelo Atual | Preço (In/Out) | Context |
|----------|----------------|--------------|----------------|---------|
| **Anthropic** | claude-opus-4-5 | **claude-opus-4-6** | $5/$25 | 1M (beta) |
| **Z.AI** | glm-4.7 | **glm-5** | $1/$3.2 | 200K |
| **Z.AI** | glm-4.5-air | **glm-4.7-flash** | FREE | 131K |
| **Moonshot** | kimi-k2.5 | **kimi-k2.5** | $0.60/$3 | 256K |
| **Moonshot** | - | **kimi-k2-thinking** | $0.60/$2.50 | 256K |
| **DeepSeek** | V3/R1 | **V3.2 unificado** | $0.28/$0.42 | 128K |
| **OpenAI** | gpt-5 | **gpt-5.3-instant** | $1.10/$10 | 400K |
| **OpenAI** | - | **gpt-4.1** | $2/$8 | 1M |
| **Google** | gemini-2.0-flash | **gemini-3.1-pro** | $2/$12 | 1M |
| **Google** | - | **gemini-2.5-flash-lite** | $0.10/$0.40 | 1M |
| **Qwen** | qwen-plus | **qwen3.5-plus-02-15** | $0.26/$1.56 | 1M |

---

## 📦 Versões Instaladas

| Host | Tailscale IP | Versão | Última Atualização |
|------|-------------|--------|--------------------|
| agldv03 (CT179) | 100.94.221.87 | **v2026.2.26** | 2026-03-01 |
| fgsrv6 | 100.83.51.9 | **v2026.2.26** | 2026-03-01 |

**Versão instalada antes do update**: v2026.1.29 (agldv03) / v2026.2.24 (fgsrv6)

### Atualizar openclaw

```bash
npm install -g openclaw@latest
openclaw --version
```

### Histórico de versões relevantes

| Versão | Data | Destaques |
|--------|------|-----------|
| v2026.2.26 | 2026-02-27 | External Secrets, ACP agents, Android, Codex WebSocket transport |
| v2026.2.24 | 2026-02-25 | Multilingual stop-phrase, security hardening |
| v2026.2.23 | 2026-02-23 | Prompt injection/SSRF/XSS hardening, Kimi video, Kilo Gateway |
| v2026.1.29 | 2026-01-29 | Versão anterior instalada |

---

## 🤖 Configuração Multi-Model (agldv03)

A configuração em `/root/.openclaw/openclaw.json` usa os providers definidos em `~/.zshrc`.

### Providers configurados

| Provider | Variável de Auth | URL Base | API Format | Modelos |
|----------|-----------------|----------|------------|---------|
| **Anthropic** | `ANTHROPIC_API_KEY` | built-in | Claude API | claude-opus-4-6 (1M ctx), claude-sonnet-4-6, claude-haiku-4-5 |
| **ZAI/GLM** | `GLM_AUTH` / `ZAI_API_KEY` | `GLM_URL` (`api.z.ai`) | `anthropic-messages` | **glm-5** (744B/40B), glm-4.7, glm-4.7-flash (FREE) |
| **Kimi** | `KIMI_AUTH` / `MOONSHOT_API_KEY` | `KIMI_URL` / `api.moonshot.ai` | `anthropic-messages` / `openai-completions` | **kimi-k2.5** (256K), kimi-k2-thinking, kimi-k2-turbo-preview, moonshot-v1-128k |
| **DeepSeek** | `DEEPSEEK_AUTH` / `DEEPSEEK_API_KEY` | `DEEPSEEK_URL` (`deepseek.com`) | `anthropic-messages` | **deepseek-chat** (V3.2), deepseek-reasoner (64K out) |
| **OpenAI** | `OPENAI_AUTH` / `OPENAI_API_KEY` | `OPENAI_URL` (`openai.com`) | built-in | **gpt-5.3-instant** (400K), gpt-4.1 (1M ctx), gpt-4o, gpt-4o-mini |
| **Gemini** | `GEMINI_AUTH` / `GEMINI_API_KEY` | `GEMINI_URL` (`googleapis.com`) | built-in Google | **gemini-3.1-pro**, gemini-2.5-pro, gemini-2.5-flash, gemini-2.5-flash-lite |

> **Como funciona**: O openclaw usa interpolação `${VAR}` para ler as variáveis de ambiente. As vars são definidas em `~/.zshrc` e precisam estar no ambiente quando o daemon inicializa.

### Cadeia de fallback (modelo primário → fallbacks)

```
zai/glm-5                              ← primário (744B params, agentic)
  → anthropic/claude-sonnet-4-6        ← fallback 1 (conta PRO, 1M beta)
  → moonshot/kimi-k2.5                 ← fallback 2 (multimodal, 256K, Agent Swarm)
  → kimi/moonshot-v1-128k              ← fallback 3 (contexto 128k)
  → deepseek/deepseek-chat             ← fallback 4 (código — V3.2, $0.28/M)
  → openai/gpt-5.3-instant             ← fallback 5 (400K ctx, anti-cringe)
  → google/gemini-3.1-pro              ← fallback 6 (ARC-AGI-2, native video)
  → openrouter/deepseek/deepseek-v3.2  ← fallback 7 (via OpenRouter)
  → openrouter/z-ai/glm-4.5-air:free   ← último recurso (gratuito)
```

---

## 🎯 Agentes Especializados por Tarefa

Acesse com `/agent <nome>` no chat ou via routing automático:

| Agente | Modelo Primário | Fallback | Uso Ideal |
|--------|----------------|----------|-----------|
| `reasoner` | `deepseek/deepseek-reasoner` (V3.2) | **kimi-k2-thinking**, openrouter R1, glm-5 | Análise complexa, lógica, matemática |
| `coder` | `deepseek/deepseek-chat` (V3.2) | **gpt-5.3-instant**, qwen-coder, glm-5 | Código, debugging, refactoring |
| `longctx` | **`moonshot/kimi-k2.5`** (256K) | kimi 128k, gemini-3.1-pro, gpt-4.1 | Docs longos, codebase review |
| `fast` | `zai/glm-4.7-flash` | **gemini-2.5-flash-lite**, glm-flash | Tarefas rápidas, heartbeats |
| `infra` | `zai/glm-5` | deepseek-chat, **gpt-5.3-instant** | SSH, Proxmox, Docker, infra |

### Mudar modelo no chat (sem restart)

```
/model list                        # Listar modelos disponíveis
/model claude-opus                 # Claude Opus 4.6 (1M ctx)
/model claude-sonnet               # Claude Sonnet 4.6
/model claude-haiku                # Claude Haiku 4.5
/model glm                         # GLM-5 (zai/glm-5)
/model glm-4.7                     # GLM-4.7
/model glm-flash                   # GLM-4.7-flash (FREE)
/model kimi                        # Kimi 128k (moonshot-v1-128k)
/model kimi-k2                     # Kimi K2.5 (multimodal, 256k)
/model kimi-turbo                  # Kimi K2 Turbo Preview (256k)
/model kimi-think                  # Kimi K2 Thinking (reasoning, 256k)
/model r1                          # DeepSeek Reasoner (V3.2, 64K out)
/model deepseek                    # DeepSeek Chat (V3.2, 128k)
/model gpt                         # GPT-5.3 Instant (400K ctx)
/model gpt-4.1                     # GPT-4.1 (1M context)
/model gpt-mini                    # GPT-4o-mini
/model gemini                      # Gemini 3.1 Pro
/model gemini-pro                  # Gemini 2.5 Pro
/model gemini-lite                 # Gemini 2.5 Flash-Lite ($0.10/M)
/model openai/gpt-4o               # GPT-4o (legacy, 128k)
```

---

## 💰 Estratégia de Custo — Model Tiering

| Tier | Modelo | Custo Input | Uso |
|------|--------|------------|-----|
| **Gratuito** | `zai/glm-4.7-flash` | $0 | Testes, dev, heartbeats |
| **Ultra-barato** | `google/gemini-2.5-flash-lite` | $0.10/M | Tarefas rápidas |
| **Barato** | `deepseek/deepseek-chat` (V3.2) | $0.28/M | Código, 128K ctx |
| **Padrão** | `zai/glm-5` | $1/M | Uso geral (primário) |
| **Contexto longo** | `moonshot/kimi-k2.5` | $0.60/M | Docs grandes, 256K, multimodal |
| **Premium** | `openai/gpt-5.3-instant` | $1.10/M | Fallback robusto, 400K ctx |
| **Topo** | `anthropic/claude-opus-4-6` | $5/M | 1M context, Agent Teams |
| **Frontier** | `google/gemini-3.1-pro` | $2/M | ARC-AGI-2, native video |

**Economia estimada com tiering**: 60-90% vs usar sempre o modelo mais caro.

---

## ✅ Status dos Modelos (agldv03 — validado 2026-03-07)

```
Model                                 Input      Ctx      Auth  Tags
zai/glm-5                             text       200k     yes   default, alias:glm
anthropic/claude-sonnet-4-6           text+img   200k     yes   fallback#1, alias:claude-sonnet
moonshot/kimi-k2.5                    text+img   256k     yes   fallback#2, alias:kimi-k2
kimi/moonshot-v1-128k                 text       128k     yes   fallback#3, alias:kimi
deepseek/deepseek-chat (V3.2)         text       128k     yes   fallback#4, alias:deepseek
openai/gpt-5.3-instant                text+img   400k     yes   fallback#5, alias:gpt
google/gemini-3.1-pro                 text+img   1M       yes   fallback#6, alias:gemini
openrouter/deepseek/deepseek-v3.2     text       160k     yes   fallback#7
openrouter/z-ai/glm-4.5-air:free      text       128k     yes   fallback#8
zai/glm-4.7                           text       203k     yes   alias:glm-4.7
zai/glm-4.7-flash                     text       131k     yes   alias:glm-flash, FREE
deepseek/deepseek-reasoner (V3.2)     text       128k     yes   alias:r1
openai/gpt-4.1                        text+img   1M       yes   alias:gpt-4.1
openai/gpt-4o-mini                    text+img   128k     yes   alias:gpt-mini
google/gemini-2.5-pro                 text+img   2M       yes   alias:gemini-pro
google/gemini-2.5-flash-lite          text+img   1M       yes   alias:gemini-lite
moonshot/kimi-k2-thinking             text       256k     yes   alias:kimi-think
moonshot/kimi-k2-thinking-turbo       text       256k     yes   alias:kimi-turbo
openrouter/deepseek/deepseek-r1       text       63k      yes
openrouter/qwen/qwen3-coder:free      text       256k     yes
anthropic/claude-opus-4-6             text+img   1M(beta) yes   alias:claude-opus
```

**Nota**: Todos os modelos acima têm `auth: yes` após configuração do systemd EnvironmentFile.

---

## ⚠️ Env Vars e Systemd

As variáveis `OPENAI_AUTH`, `GEMINI_AUTH` etc. são definidas em `~/.zshrc`, que **não é carregado pelo systemd**. **Solução aplicada** (2026-03-02): EnvironmentFile via systemd drop-in.

### Solução Aplicada (agldv03 e fgsrv6)

```bash
# 1. Arquivo de vars (criado em ambos os hosts)
~/.config/environment.d/openclaw.conf  # formato KEY=VALUE simples

# 2. Override systemd para carregar o arquivo
~/.config/systemd/user/openclaw-gateway.service.d/env.conf
# Conteúdo:
# [Service]
# EnvironmentFile=%h/.config/environment.d/openclaw.conf

# 3. Recarregar e reiniciar
systemctl --user daemon-reload
openclaw gateway restart
```

Vars adicionadas no `.zshrc` (para sessão interativa):
```bash
export MOONSHOT_API_KEY="${KIMI_AUTH}"     # Kimi K2.5 / turbo / thinking
export ZAI_API_KEY="${GLM_AUTH}"           # GLM-4.7 via zai
export OPENAI_API_KEY="${OPENAI_AUTH}"     # GPT-5, GPT-4.1
export DEEPSEEK_API_KEY="${DEEPSEEK_AUTH}" # DeepSeek V3.2
```

Para tornar um provider disponível no daemon (método alternativo):

```bash
# Opção 1: adicionar ao unit file do serviço
systemctl --user edit openclaw-gateway --force
# Adicionar na seção [Service]:
# Environment="OPENAI_AUTH=sk-..."
# Environment="GEMINI_AUTH=AIza..."

# Opção 2: via ~/.config/environment.d/ (carregado por PAM/systemd user)
echo 'OPENAI_AUTH=sk-...' >> ~/.config/environment.d/openclaw.conf
echo 'GEMINI_AUTH=AIza...' >> ~/.config/environment.d/openclaw.conf
systemctl --user daemon-reload && openclaw gateway restart
```

Providers que usam `models.providers` com `apiKey: "${VAR}"` e auth `yes` confirmados: **GLM (zai), Kimi, DeepSeek, Gemini via google built-in** — estes já resolvem as vars corretamente pois o openclaw provavelmente lê do ambiente em runtime ou via `openclaw.json` credential store.

---

## 🔧 Gerenciamento do Daemon

```bash
# Status
openclaw status
openclaw doctor

# Restart gateway (sem perder sessões)
openclaw gateway restart

# Ver logs
openclaw logs gateway

# Listar modelos disponíveis com status de auth
openclaw models list

# Testar model específico
openclaw models test deepseek/deepseek-chat

# Dashboard web
openclaw dashboard   # http://localhost:8080
```

---

## 📡 Canal Telegram (agldv03)

O openclaw em agldv03 está integrado ao Telegram:
- **dmPolicy**: `pairing` — DMs precisam de pareamento
- **groupPolicy**: `allowlist` — grupos precisam estar na allowlist
- **streamMode**: `partial` — streaming parcial de respostas

---

## 🔑 Variáveis de Ambiente Necessárias

Definidas em `/root/.zshrc` ou via `~/.openclaw/zshrc-openclaw.env`:

```bash
# Anthropic Claude (conta PRO)
export ANTHROPIC_API_KEY="<key>"

# GLM / Z.AI (provider "zai" built-in)
export GLM_URL="https://api.z.ai/api/anthropic"
export GLM_AUTH="<key>"
export ZAI_API_KEY="${ZAI_API_KEY:-$GLM_AUTH}"  # LiteLLM

# Kimi / Moonshot (provider "kimi" + "moonshot")
export KIMI_URL="https://api.moonshot.ai/anthropic"
export KIMI_AUTH="<key>"
export MOONSHOT_API_KEY="${MOONSHOT_API_KEY:-$KIMI_AUTH}"  # kimi-k2.5, LiteLLM

# DeepSeek (provider "deepseek" custom)
export DEEPSEEK_URL="https://api.deepseek.com/anthropic"
export DEEPSEEK_AUTH="<key>"
export DEEPSEEK_API_KEY="${DEEPSEEK_API_KEY:-$DEEPSEEK_AUTH}"  # LiteLLM

# OpenAI (provider "openai" built-in)
export OPENAI_URL="https://api.openai.com/v1"
export OPENAI_AUTH="<key>"
export OPENAI_API_KEY="${OPENAI_API_KEY:-$OPENAI_AUTH}"  # LiteLLM

# Google Gemini (provider "google" built-in)
export GEMINI_URL="https://generativelanguage.googleapis.com/v1beta"
export GEMINI_AUTH="<key>"
export GEMINI_API_KEY="${GEMINI_API_KEY:-$GEMINI_AUTH}"  # LiteLLM

# OpenRouter (fallbacks)
export OPENROUTER_API_KEY="<key>"
```

**Deploy**: `./scripts/deploy-openclaw-config.sh` aplica config + zshrc em agldv03 e fgsrv6.

> **Daemon**: Se o openclaw rodar como systemd service, adicionar as vars em
> `~/.config/environment.d/openclaw.conf` ou no unit file. Para Anthropic:
> `echo 'ANTHROPIC_API_KEY=sk-ant-...' >> ~/.config/environment.d/openclaw.conf`

---

## 🔄 Usar LiteLLM local (localhost:4000)

Para OpenClaw e Claude Flow usarem LiteLLM rodando localmente em cada host (agldv03, agldv04, agldv12, fgsrv06 ou Docker no Windows):

```bash
# OpenClaw: apontar todos os providers para localhost:4000
node scripts/openclaw/use-litellm-local.mjs
# ou (Linux/WSL com jq): bash scripts/openclaw/use-litellm-local.sh

# Claude Flow: .claude/settings.json já tem ANTHROPIC_BASE_URL=http://localhost:4000
# Reiniciar gateway OpenClaw
openclaw gateway restart
```

**Requisito**: LiteLLM rodando em `http://localhost:4000` em cada host. Ver [LITELLM-MULTI-HOST-DEPLOYMENT.md](LITELLM-MULTI-HOST-DEPLOYMENT.md).

---

## 🔄 Sincronizar config para outros hosts

```bash
# Deploy completo (config + zshrc) para agldv03 e fgsrv6
./scripts/deploy-openclaw-config.sh

# Reiniciar gateway após deploy
for h in 100.94.221.87 100.83.51.9; do ssh root@$h 'openclaw gateway restart'; done

# Copiar apenas config manualmente
scp ~/.openclaw/openclaw.json root@100.83.51.9:~/.openclaw/openclaw.json

# Verificar versão após update
for host in 100.94.221.87 100.83.51.9; do
  echo -n "$host: "
  ssh root@$host "openclaw --version 2>/dev/null"
done
```

### Arquivos no repositório (agl-hostman)

| Arquivo | Descrição |
|---------|-----------|
| `config/openclaw/openclaw-patch.json` | Patch com Anthropic, moonshot/kimi-k2.5, fallbacks |
| `config/openclaw/openclaw-litellm-local.jq` | Patch jq para providers → localhost:4000 |
| `config/openclaw/litellm-gateway-local.env` | LITELLM_GATEWAY_URL=http://localhost:4000 |
| `config/openclaw/zshrc-openclaw.env` | Vars para OpenClaw + LiteLLM (source no .zshrc) |
| `scripts/openclaw/use-litellm-local.mjs` | Configura OpenClaw para LiteLLM local (Node, sem jq) |
| `scripts/deploy-openclaw-config.sh` | Deploy para agldv03 + fgsrv6 |

---

## 🐛 Troubleshooting

| Problema | Causa | Solução |
|----------|-------|---------|
| `5h ?` / `7d ?` na statusline | `cygpath` pipe retornava vazio no Linux | Fix aplicado em `/root/.claude/statusline-command.sh` (2026-03-01) |
| `Missing env var MOONSHOT_API_KEY` no CLI | CLI não carrega .zshrc | `source ~/.zshrc && openclaw models list` OU use inline: `MOONSHOT_API_KEY=$KIMI_AUTH openclaw ...` |
| Provider auth `no` no daemon | Vars do .zshrc não são carregadas pelo systemd | Configurar `~/.config/environment.d/openclaw.conf` + drop-in systemd (já aplicado 2026-03-02) |
| `auth.profiles.X.apiKey` inválido | Campo não existe no schema | Usar apenas `provider` e `mode`; apiKey vai em `models.providers` |
| `agents.list[N].id` required | Agentes precisam de `id`, não `name` | Usar `"id": "nome-agente"` |
| `agents.list[N].description` inválido | Campo não existe no schema | Remover o campo `description` dos agentes |
| `streamMode` inválido | Renomeado na v2026.2.x | Usar `streaming: "partial"` |
| Modelo não aparece em `/model list` | Não está no `agents.defaults.models` | Adicionar ao bloco `models` no config e `gateway restart` |
| `device signature invalid` no status | Token do config ≠ token do serviço em execução | `MOONSHOT_API_KEY=$KIMI_AUTH openclaw gateway install --force && restart` |
| Gateway timeout no restart | Demora para subir mas fica OK | Verificar com `systemctl --user status openclaw-gateway` |
| Config não recarregado | Gateway ainda com config antigo | `source ~/.zshrc && openclaw gateway restart` |

---

## 📚 Referências

- [Model Providers - Docs](https://docs.openclaw.ai/concepts/model-providers)
- [Models CLI](https://docs.openclaw.ai/concepts/models)
- [Configuration Reference](https://docs.openclaw.ai/gateway/configuration-reference)
- [Multi-model routing guide](https://velvetshark.com/openclaw-multi-model-routing)
- [Using DeepSeek, Kimi & Alternative Models](https://www.getopenclaw.ai/help/deepseek-minimax-alternative-models)
- [Cost optimization guide](https://lumadock.com/tutorials/openclaw-cost-optimization-budgeting)

---

**Maintainer**: Claude Code (agl-hostman)
**Config file**: `/root/.openclaw/openclaw.json`
**Hosts**: agldv03 (primary), fgsrv6
**Última atualização de modelos**: 2026-03-07 (GLM-5, GPT-5.3 Instant, Gemini 3.1 Pro, DeepSeek V3.2 unificado, Kimi K2.5/Thinking)
