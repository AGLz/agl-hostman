# OpenClaw - Documentação AGL

> **Last Updated**: 2026-03-21 | **Version doc**: 1.7.1

**OpenClaw** é uma plataforma de agente AI autônomo self-hosted. Funciona como assistente pessoal com suporte a múltiplos canais (Telegram, Slack, Discord, WhatsApp etc.), multi-agentes, roteamento de modelos e automação via LLMs.

- **Site**: https://openclaw.ai
- **Docs**: https://docs.openclaw.ai
- **GitHub**: https://github.com/openclaw/openclaw
- **Config**: `~/.openclaw/openclaw.json`

---

## 🔄 Atualizações de Modelos (2026-03-20)

Sincronizado com docs oficiais: [Anthropic models](https://docs.anthropic.com/en/docs/about-claude/models/overview), [OpenAI GPT-5.3 Chat / GPT-5.4](https://developers.openai.com/api/docs/models), [Gemini](https://ai.google.dev/gemini-api/docs/models).

| Provider | Modelo Anterior | Modelo Atual (ID API) | Preço (In/Out)* | Context |
|----------|----------------|----------------------|-----------------|---------|
| **Anthropic** | claude-opus-4-5 | **claude-opus-4-6** | $5/$25 | 1M |
| **Z.AI** | glm-4.7 | **glm-5** | $1/$3.2 | 200K |
| **Z.AI** | glm-4.5-air | **glm-4.7-flash** | FREE | 131K |
| **Moonshot** | kimi-k2.5 | **kimi-k2.5** | $0.60/$3 | 256K |
| **Moonshot** | - | **kimi-k2-thinking** | $0.60/$2.50 | 256K |
| **DeepSeek** | V3/R1 | **V3.2** (`deepseek-chat`) | $0.28/$0.42 | 128K |
| **OpenAI** | gpt-5.2 | **gpt-5.4** (frontier) | $2.50/$15 | ~1.05M |
| **OpenAI** | — | **gpt-5.3-chat-latest** (= Instant ChatGPT) | $1.75/$14 | 128K |
| **OpenAI** | - | **gpt-4.1** | $2/$8 | 1M |
| **Google** | gemini-3-pro-preview (desligado) | **gemini-3.1-pro-preview** | ver pricing | 1M |
| **Google** | - | **gemini-2.5-flash-lite** | $0.10/$0.40 | 1M |
| **Qwen** | qwen-plus | **qwen3.5-plus-02-15** | $0.26/$1.56 | 1M |

\*Preços OpenAI/Gemini conforme páginas de modelo em mar/2026.

---

## 📦 Versões Instaladas

| Host | Tailscale IP | Versão | Última Atualização |
|------|-------------|--------|--------------------|
| agldv03 (CT179) | 100.94.221.87 | **v2026.3.13** | 2026-03-21 |
| fgsrv6 | 100.83.51.9 | **v2026.3.13** | 2026-03-21 |

**Versão instalada antes do update (histórico)**: v2026.1.29 (agldv03) / v2026.2.24 (fgsrv6)

### Atualizar openclaw

```bash
source ~/.nvm/nvm.sh && nvm use 24.14.0   # ou a versão Node usada no gateway
# Se `npm view openclaw version` mostrar versão antiga: cache npm desatualizado (ex. prefer-offline)
npm cache clean --force
npm install -g openclaw@latest
openclaw --version
# Alinhar o systemd ao binário global (evita /usr/lib/... ou Node antigo)
openclaw gateway install --force
systemctl --user daemon-reload && systemctl --user restart openclaw-gateway
```

> **Nota**: `gateway install --force` pode regenerar `gateway.auth.token` e gravar backup em `~/.openclaw/openclaw.json.bak`. Clientes que usam o token antigo precisam do valor novo em `~/.openclaw/openclaw.json` ou novo *pairing*.

### Histórico de versões relevantes

| Versão | Data | Destaques |
|--------|------|-----------|
| v2026.3.13 | 2026-03 (npm `latest`) | Tratamento de `model_context_window_exceeded`, melhorias de gateway (ver changelog upstream) |
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
| **Anthropic** | `ANTHROPIC_API_KEY` | built-in | Claude API | claude-opus-4-6, claude-sonnet-4-6 (1M), claude-haiku-4-5-20251001 |
| **ZAI/GLM** | `GLM_AUTH` / `ZAI_API_KEY` | `GLM_URL` (`api.z.ai`) | `anthropic-messages` | **glm-5** (744B/40B), glm-4.7, glm-4.7-flash (FREE) |
| **Kimi** | `KIMI_AUTH` / `MOONSHOT_API_KEY` | `KIMI_URL` / `api.moonshot.ai` | `anthropic-messages` / `openai-completions` | **kimi-k2.5** (256K), kimi-k2-thinking, kimi-k2-turbo-preview, moonshot-v1-128k |
| **DeepSeek** | `DEEPSEEK_AUTH` / `DEEPSEEK_API_KEY` | `DEEPSEEK_URL` (`deepseek.com`) | `anthropic-messages` | **deepseek-chat** (V3.2), deepseek-reasoner (64K out) |
| **OpenAI** | `OPENAI_AUTH` / `OPENAI_API_KEY` | `OPENAI_URL` (`openai.com`) | built-in | **gpt-5.4**, **gpt-5.3-chat-latest** (128K), gpt-4.1, gpt-4o, gpt-4o-mini |
| **Gemini** | `GEMINI_AUTH` / `GEMINI_API_KEY` | `GEMINI_URL` (`googleapis.com`) | built-in Google | **gemini-3.1-pro-preview**, gemini-2.5-pro, gemini-2.5-flash, gemini-2.5-flash-lite |

> **Como funciona**: O openclaw usa interpolação `${VAR}` para ler as variáveis de ambiente. As vars são definidas em `~/.zshrc` e precisam estar no ambiente quando o daemon inicializa.

### Cadeia de fallback (modelo primário → fallbacks)

```
zai/glm-5                              ← primário (744B params, agentic)
  → anthropic/claude-sonnet-4-6        ← fallback 1 (conta PRO, 1M beta)
  → moonshot/kimi-k2.5                 ← fallback 2 (multimodal, 256K, Agent Swarm)
  → kimi/moonshot-v1-128k              ← fallback 3 (contexto 128k)
  → deepseek/deepseek-chat             ← fallback 4 (código — V3.2, $0.28/M)
  → openai/gpt-5.3-chat-latest         ← fallback 5 (128K ctx, Instant API)
  → google/gemini-3.1-pro-preview      ← fallback 6 (Gemini 3.1)
  → openrouter/deepseek/deepseek-v3.2  ← fallback 7 (via OpenRouter)
  → openrouter/z-ai/glm-4.5-air:free   ← último recurso (gratuito)
```

---

## 🎯 Agentes Especializados por Tarefa

Acesse com `/agent <nome>` no chat ou via routing automático:

| Agente | Modelo Primário | Fallback | Uso Ideal |
|--------|----------------|----------|-----------|
| `reasoner` | `deepseek/deepseek-reasoner` (V3.2) | **kimi-k2-thinking**, openrouter R1, glm-5 | Análise complexa, lógica, matemática |
| `coder` | `deepseek/deepseek-chat` (V3.2) | **gpt-5.3-chat-latest**, qwen-coder, glm-5 | Código, debugging, refactoring |
| `longctx` | **`moonshot/kimi-k2.5`** (256K) | kimi 128k, gemini-3.1-pro-preview, gpt-4.1 | Docs longos, codebase review |
| `fast` | `zai/glm-4.7-flash` | **gemini-2.5-flash-lite**, glm-flash | Tarefas rápidas, heartbeats |
| `infra` | `zai/glm-5` | deepseek-chat, **gpt-5.3-chat-latest** | SSH, Proxmox, Docker, infra |

### Múltiplos agentes no gateway (`agents.list` + `bindings`)

Alinhado a [Multi-Agent](https://docs.openclaw.ai/concepts/multi-agent) e ao [skill roadmap de infra](infrastructure/skill-roadmap.md) (storage, Harbor, rede). O repositório inclui um **fragmento** versionado — **não** está dentro de `openclaw-patch.json` (o merge `jq` substituiria arrays inteiros; o script abaixo faz merge profundo seguro).

| Ficheiro | Função |
|----------|--------|
| `config/openclaw/openclaw-agents-list.fragment.json` | `agents.list` (`main`, `infra`, `storage`, `harbor`, `net`) + exemplo de `bindings` Telegram |
| `scripts/openclaw/merge-openclaw-agents.mjs` | Aplica o fragmento em `~/.openclaw/openclaw.json` (backup `.bak`), preserva `agents.defaults` e restantes chaves |

**Modelos por agente (fragmento)**:

| `id` | Workspace | Primário | Notas |
|------|-----------|----------|--------|
| `main` | `~/.openclaw/workspace` | herdado de `agents.defaults` | `default: true`; `subagents.allowAgents` aponta para os especialistas |
| `infra` | `~/.openclaw/workspace-infra` | `zai/glm-5` | Proxmox, Docker, stacks AGL |
| `storage` | `~/.openclaw/workspace-storage` | `zai/glm-4.7-flash` | Pools, disco, alertas (tier barato) |
| `harbor` | `~/.openclaw/workspace-harbor` | `deepseek/deepseek-chat` | Registry, imagens, CI |
| `net` | `~/.openclaw/workspace-net` | **`gemini-lite`** (alias LiteLLM; evita `google/...:free` → 404) | WireGuard, Tailscale, conectividade |

**Aplicar no host**:

```bash
node scripts/openclaw/merge-openclaw-agents.mjs --dry-run   # pré-visualizar
node scripts/openclaw/merge-openclaw-agents.mjs             # escrever + backup
# Opcional: só agents.list sem bindings de exemplo
node scripts/openclaw/merge-openclaw-agents.mjs --no-bindings
openclaw gateway restart
```

Substituir em `bindings[].match.peer.id` o placeholder `-100REPLACE_WITH_TELEGRAM_GROUP_ID` pelo ID real do grupo (ou remover `bindings` se não usar roteamento por canal).

**aglwk45 (Windows, VM104 no AGLSRV1)**: SSH ao Proxmox não expõe `openclaw` ao Windows; usar guest agent. Script `scripts/openclaw/deploy-aglwk45-openclaw-guest.sh` copia o fragmento para o host e executa `scripts/openclaw/vm104_guest_merge.py` (base64 em **chunks** para respeitar o limite de linha de comando do Windows). Requer `python3` no AGLSRV1 e `node` na VM104.

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
/model gpt                         # GPT-5.4 / alias gpt (LiteLLM: openai/gpt-5.4)
/model gpt-4.1                     # GPT-4.1 (1M context)
/model gpt-mini                    # GPT-4o-mini
/model gemini                      # Gemini 3.1 Pro Preview (google/gemini-3.1-pro-preview)
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
| **Premium** | `openai/gpt-5.3-chat-latest` | $1.75/M | Fallback Instant, 128K ctx |
| **Topo** | `anthropic/claude-opus-4-6` | $5/M | 1M context, Agent Teams |
| **Frontier** | `google/gemini-3.1-pro-preview` | ver Google | Gemini 3.1 |

**Economia estimada com tiering**: 60-90% vs usar sempre o modelo mais caro.

---

## ✅ Status dos Modelos (agldv03 — validado 2026-03-07)

```
Model                                 Input      Ctx      Auth  Tags
zai/glm-5                             text       200k     yes   default, alias:glm
anthropic/claude-sonnet-4-6           text+img   1M       yes   fallback#1, alias:claude-sonnet
moonshot/kimi-k2.5                    text+img   256k     yes   fallback#2, alias:kimi-k2
kimi/moonshot-v1-128k                 text       128k     yes   fallback#3, alias:kimi
deepseek/deepseek-chat (V3.2)         text       128k     yes   fallback#4, alias:deepseek
openai/gpt-5.3-chat-latest            text+img   128k     yes   fallback#5 (Instant API)
google/gemini-3.1-pro-preview         text+img   1M       yes   fallback#6, alias:gemini
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

As variáveis `OPENAI_AUTH`, `GEMINI_AUTH` etc. são definidas em `~/.zshrc`, que **não é carregado pelo systemd**. **Solução aplicada** (2026-03-02): EnvironmentFile via systemd drop-in. **Regeneração segura** (2026-03-21): `scripts/openclaw/sync-systemd-openclaw-env.sh` — copiado para o host e executado pelo `scripts/deploy-openclaw-config.sh`; garante `OPENAI_URL`, `OPENROUTER_URL`, etc. **literais** após `source` de `~/.openclaw/zshrc-openclaw.env` (systemd não expande `${VAR:-default}`).

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

## 📡 Canal Telegram (Linux)

### Limitação (um bot = um gateway)

O Telegram só entrega updates a **um** destino por bot (long-polling ou webhook). **Não** uses o **mesmo** `botToken` em **agldv03** e **fgsrv6** em simultâneo — um dos lados deixa de receber mensagens. Usa **dois bots** (BotFather) ou **um** bot só no host que deve responder.

### Restaurar a partir de backup (recomendado se já existia config)

Nos hosts existem backups com `channels.telegram` válido, p.ex. `~/.openclaw/openclaw.json.bak.20260301`:

```bash
chmod +x ~/merge-telegram-from-backup.sh   # ou copiar de scripts/openclaw/ no repo
bash ~/merge-telegram-from-backup.sh ~/.openclaw/openclaw.json.bak.20260301
systemctl --user restart openclaw-gateway
bash -lc 'set -a; . ~/.config/environment.d/openclaw.conf; set +a; openclaw channels list'
```

Script no repositório: `scripts/openclaw/merge-telegram-from-backup.sh`.

### Nova configuração (CLI)

Com o token do BotFather em variável (ou inline):

```bash
export TELEGRAM_BOT_TOKEN="123456:ABC..."
openclaw channels add --channel telegram --token "$TELEGRAM_BOT_TOKEN"
systemctl --user restart openclaw-gateway
```

Políticas típicas (já presentes nos backups AGL): **dmPolicy** `pairing`, **groupPolicy** `allowlist`, **streaming** `partial` — ajustar em `~/.openclaw/openclaw.json` ou via wizard conforme a [documentação do canal](https://docs.openclaw.ai/cli/channels).

Se `groupPolicy` for `allowlist` e **não** houver `groupAllowFrom` (nem IDs em `allowFrom` aplicáveis a grupos), o CLI pode avisar. Opções: preencher **`channels.telegram.groupAllowFrom`** com IDs de grupo (ex. `-100…`) ou, em rede interna, definir temporariamente `groupPolicy` para `open`:

```bash
jq '.channels.telegram.groupPolicy = "open"' ~/.openclaw/openclaw.json > /tmp/oc.json && mv /tmp/oc.json ~/.openclaw/openclaw.json
systemctl --user restart openclaw-gateway
```

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
| `config/openclaw/fgsrv06-litellm.jq` | **fgsrv06**: mesmo que o local (LiteLLM no próprio host); **não** usar `100.94.221.87:4000` aqui |
| `config/openclaw/litellm-gateway-local.env` | LITELLM_GATEWAY_URL + ANTHROPIC_BASE_URL → localhost:4000 (deploy copia para `~/.openclaw/litellm-gateway.env` em hosts com LiteLLM local) |
| `config/openclaw/litellm-gateway-client.env` | Apenas agldv04/05/06 (sem proxy local): aponta ao agldv03 |
| `config/openclaw/zshrc-openclaw.env` | Vars para OpenClaw + LiteLLM (source no .zshrc) |
| `scripts/openclaw/use-litellm-local.mjs` | Configura OpenClaw para LiteLLM local (Node, sem jq) |
| `scripts/deploy-openclaw-config.sh` | Deploy para agldv03 + fgsrv6 |
| `tests/unit/openclaw-patch-schema.test.js` | Valida JSON do patch (CI/local) |
| `config/openclaw/openclaw-agents-list.fragment.json` | `agents.list` multi-agente + bindings exemplo |
| `scripts/openclaw/merge-openclaw-agents.mjs` | Merge seguro do fragmento no `openclaw.json` |
| `scripts/openclaw/vm104_guest_merge.py` | Merge na VM104 (Windows) via `qm guest exec` + chunks base64 |
| `scripts/openclaw/deploy-aglwk45-openclaw-guest.sh` | Orquestra scp + `vm104_guest_merge.py` no AGLSRV1 |
| `scripts/openclaw/deploy-aglwk45-wk45-litellm-qemu.sh` | **wk45**: sincroniza LiteLLM (`apiKey`/`baseUrl` + `litellm-gateway.env`) via `qm guest exec` |
| `scripts/openclaw/vm104_guest_wk45_litellm_sync.py` | Python no Proxmox: upload + `node wk45-sync-openclaw-litellm.cjs` na VM104 |
| `scripts/openclaw/wk45-sync-openclaw-litellm.cjs` | Merge JSON no Windows sem `jq` (mesma lógica que o `.jq`) |
| `scripts/openclaw/wk45-patch-gateway-nodeopts.ps1` | **wk45**: suprime aviso Node **DEP0040** (`punycode`) no `gateway.cmd` |
| `scripts/openclaw/vm104-verify-overpower-repo.sh` | Via `qm guest exec`: confirma se o `.ps1` existe no caminho Windows (default `U:\\apps\\dev\\agl\\agl-hostman`; ver limitação sessão no `AGLWK45-SETUP.md`) |
| `scripts/openclaw/wk45-sync-openclaw-litellm.sh` | **aglwk45**: alinha `apiKey` + `baseUrl` ao agldv03 (evita 401 `sk-litellm-default`) |
| `config/openclaw/wk45-litellm-gateway.env.example` | Template `~/.openclaw/litellm-gateway.env` na VM Windows (chave real) |
| `tests/unit/openclaw-agents-fragment.test.js` | Valida fragmento multi-agente |

---

## 🐛 Troubleshooting

| Problema | Causa | Solução |
|----------|-------|---------|
| `5h ?` / `7d ?` na statusline | `cygpath` pipe retornava vazio no Linux | Fix aplicado em `/root/.claude/statusline-command.sh` (2026-03-01) |
| `Missing env var MOONSHOT_API_KEY` no CLI | CLI não carrega .zshrc | `source ~/.zshrc && openclaw models list` OU use inline: `MOONSHOT_API_KEY=$KIMI_AUTH openclaw ...` |
| `MissingEnvVarError` / gateway em loop com `${VAR}` no JSON | OpenClaw resolve `${…}` no config; variável ausente no **ambiente do processo** (systemd `--user`) | Garantir cada `KEY` referenciada no JSON em `~/.config/environment.d/openclaw.conf` com **valor literal** (systemd **não** expande `MOONSHOT_API_KEY="${KIMI_AUTH}"`). O script `scripts/deploy-openclaw-config.sh` duplica `MOONSHOT_API_KEY` a partir de `KIMI_AUTH` quando aplicável. Evitar bloco extra `models.providers.moonshot` no patch se já usas Kimi via provider nativo. |
| Provider auth `no` no daemon | Vars do .zshrc não são carregadas pelo systemd | Configurar `~/.config/environment.d/openclaw.conf` + drop-in systemd (já aplicado 2026-03-02) |
| `Unrecognized key: "pdfModel"` / config inválido | Gateways em **2026.2.x** rejeitam `agents.defaults.pdfModel` (só ≥ 2026.3.x) | `jq 'del(.agents.defaults.pdfModel)' ~/.openclaw/openclaw.json` + restart; o patch em `openclaw-patch.json` **não** inclui `pdfModel` para compatibilidade. |
| `groupPolicy` allowlist sem IDs | `groupAllowFrom` / allowlist vazia | Preencher IDs ou `groupPolicy: open` (ver secção Telegram Linux). |
| `auth.profiles.X.apiKey` inválido | Campo não existe no schema | Usar apenas `provider` e `mode`; apiKey vai em `models.providers` |
| `agents.list[N].id` required | Agentes precisam de `id`, não `name` | Usar `"id": "nome-agente"` |
| `agents.list[N].description` inválido | Campo não existe no schema | Remover o campo `description` dos agentes |
| `streamMode` inválido | Renomeado na v2026.2.x | Usar `streaming: "partial"` |
| Modelo não aparece em `/model list` | Não está no `agents.defaults.models` | Adicionar ao bloco `models` no config e `gateway restart` |
| `device signature invalid` no status | Token do config ≠ token do serviço em execução | `MOONSHOT_API_KEY=$KIMI_AUTH openclaw gateway install --force && restart` |
| CLI **OpenClaw 2026.2.x** mas config/serviço **2026.3.x** (**fgsrv06** e hosts com NVM) | Dois installs globais: o **systemd --user** usa `node` do **NVM** (`~/.nvm/.../lib/node_modules/openclaw`); o `openclaw` no PATH pode ser o de **`/usr/lib`** (outro `npm -g`). | Atualizar **ambos**: `source ~/.nvm/nvm.sh && nvm use 24 && npm i -g openclaw@latest` e `/usr/bin/npm i -g openclaw@latest`; `export XDG_RUNTIME_DIR=/run/user/0` e `openclaw gateway install --force`; `systemctl --user restart openclaw-gateway`. Verificar: `systemctl --user status openclaw-gateway` e `openclaw --version`. |
| Gateway timeout no restart | Demora para subir mas fica OK | Verificar com `systemctl --user status openclaw-gateway` |
| Config não recarregado | Gateway ainda com config antigo | `source ~/.zshrc && openclaw gateway restart` |
| `Unhandled stop reason: model_context_window_exceeded` | Contexto da sessão (ou sessão **embedded** heartbeat/cron) excedeu o limite do modelo; em versões antigas o stop reason não disparava compactação automática ([issue #35868](https://github.com/openclaw/openclaw/issues/35868)) | **Curto prazo**: `/new` ou `/reset` no canal, ou apagar sessão inchada em `~/.openclaw/**/sessions/*.jsonl` e `systemctl --user restart openclaw-gateway`. **Definitivo**: `npm install -g openclaw@latest` (build com fix do stop reason). Manter `compaction` ativo; reduzir histórico anexado em tarefas periódicas. |
| `404 No endpoints found for google/gemini-2.5-flash-lite:free` (**fgsrv06** / Telegram) | Muitas vezes o **GLM principal falha**: OpenClaw pede `zai/glm-5` mas o proxy só tinha `glm-5` → fallbacks até Gemini e erro confuso. | 1) LiteLLM com `model_name` **`zai/glm-5`** (e `zai/glm-4.7*`) no `config.yaml`; `./scripts/litellm/replicate-all-hosts.sh`. 2) `curl` de teste com `"model":"zai/glm-5"`. 3) `baseUrl` → `http://127.0.0.1:4000`. Ver `docs/LITELLM-TROUBLESHOOTING.md` §11. |
| `(node:…) [DEP0040] DeprecationWarning: punycode` ao subir o gateway | Dependências ainda usam o módulo **integrado** `punycode` do Node (deprecated). Não é erro do teu `openclaw.json`. | **Windows (wk45)**: `cd` à raiz do repo `agl-hostman`, depois `powershell -ExecutionPolicy Bypass -File .\scripts\openclaw\wk45-patch-gateway-nodeopts.ps1` (ou `-File "C:\…\agl-hostman\scripts\openclaw\wk45-patch-gateway-nodeopts.ps1"`). Reinicia o gateway. **Linux**: export `NODE_OPTIONS=--disable-warning=DEP0040` antes de `openclaw gateway` ou no unit systemd. Definitivo: upgrades Node/OpenClaw quando upstream remover o uso. |
| Linhas `[telegram] autoSelectFamily=…` / `dnsResultOrder=…` | **Informativas** (stack de rede Node/undici), não são erros. | Ignorar ou reduzir verbosidade nas opções do OpenClaw se existirem. |

---

## 🧩 Capacidades avançadas (schema oficial)

Alinhado à [Configuration Reference](https://docs.openclaw.ai/gateway/configuration-reference) e ao índice [`llms.txt`](https://docs.openclaw.ai/llms.txt). O patch em `config/openclaw/openclaw-patch.json` aplica no deploy:

| Área | O que faz | Notas AGL |
|------|-----------|-----------|
| **`commands`** | Desliga `bash` (`!`), `/restart`, `/config`, `/debug` por defeito | Reduz superfície de ataque em bots expostos (Telegram, etc.); operadores podem reativar com critério no host. |
| **`channels.defaults.heartbeat`** | `showAlerts` / `useIndicator` | Visibilidade de canais degradados sem poluir com “OK” em cada tick. |
| **`agents.defaults.imageModel`** | Rota explícita para ferramenta `image` / multimodal | Primário **Kimi K2.5** (256K, multimodal), fallbacks Gemini / Sonnet / GLM-5. |
| **`agents.defaults.pdfModel`** | Rota para ferramenta `pdf` | Suportado em **OpenClaw ≥ 2026.3.x**; **não** incluir no patch AGL enquanto gateways em **2026.2.x** — usar `openclaw doctor` no host após upgrade. |
| **`timeoutSeconds` / `maxConcurrent`** | Limites de sessão | Evita bloqueios longos e sobrecarga; ajustar por host (CPU/RAM). |

**Casos de uso extra (configurar no `openclaw.json` do host se necessário)**:

- **`channels.modelByChannel`**: fixar modelo por ID de grupo/canal (ex.: grupo Telegram “só fast” com `zai/glm-4.7-flash`).
- **`tools.elevated` + `commands.bash`**: só ativar shell no host com `allowFrom` explícito — ver docs *Command details*.
- **External Secrets** (v2026.2.26+): integrar segredos fora do ficheiro JSON em ambientes mais rígidos.
- **`openclaw security audit --deep`**: auditoria periódica (também referido em `docs/OPENCLAW-MIGRATION-PLAN.md`).

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
