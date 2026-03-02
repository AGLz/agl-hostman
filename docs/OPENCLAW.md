# OpenClaw - Documentação AGL

> **Last Updated**: 2026-03-01 | **Version doc**: 1.1.0

**OpenClaw** é uma plataforma de agente AI autônomo self-hosted. Funciona como assistente pessoal com suporte a múltiplos canais (Telegram, Slack, Discord, WhatsApp etc.), multi-agentes, roteamento de modelos e automação via LLMs.

- **Site**: https://openclaw.ai
- **Docs**: https://docs.openclaw.ai
- **GitHub**: https://github.com/openclaw/openclaw
- **Config**: `~/.openclaw/openclaw.json`

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
| **Anthropic** | `ANTHROPIC_API_KEY` | built-in | Claude API | claude-opus-4-6, claude-sonnet-4-6, claude-haiku-4-5 |
| **ZAI/GLM** | `GLM_AUTH` / `ZAI_API_KEY` | `GLM_URL` (`api.z.ai`) | `anthropic-messages` | glm-4.7, glm-4.7-flash |
| **Kimi** | `KIMI_AUTH` / `MOONSHOT_API_KEY` | `KIMI_URL` / `api.moonshot.ai` | `anthropic-messages` / `openai-completions` | moonshot-v1-128k, kimi-k2.5 |
| **DeepSeek** | `DEEPSEEK_AUTH` | `DEEPSEEK_URL` (`deepseek.com`) | `anthropic-messages` | deepseek-chat, deepseek-reasoner |
| **OpenAI** | `OPENAI_AUTH` | `OPENAI_URL` (`openai.com`) | built-in | gpt-4o, gpt-4o-mini |
| **Gemini** | `GEMINI_AUTH` | `GEMINI_URL` (`googleapis.com`) | built-in Google | gemini-2.0-flash, flash-lite |

> **Como funciona**: O openclaw usa interpolação `${VAR}` para ler as variáveis de ambiente. As vars são definidas em `~/.zshrc` e precisam estar no ambiente quando o daemon inicializa.

### Cadeia de fallback (modelo primário → fallbacks)

```
zai/glm-4.7                      ← primário (rápido, barato)
  → anthropic/claude-sonnet-4-6  ← fallback 0 (conta PRO)
  → moonshot/kimi-k2.5           ← fallback 1 (contexto 256k)
  → kimi/moonshot-v1-128k        ← fallback 2 (contexto longo)
  → deepseek/deepseek-chat        ← fallback 3 (código/raciocínio)
  → openai/gpt-4o                 ← fallback 4 (robusto)
  → google/gemini-2.0-flash       ← fallback 5 (rápido)
  → openrouter/deepseek/...       ← fallback 6 (via OpenRouter)
  → openrouter/z-ai/glm-4.5-air:free ← último recurso (gratuito)
```

---

## 🎯 Agentes Especializados por Tarefa

Acesse com `/agent <nome>` no chat ou via routing automático:

| Agente | Modelo Primário | Fallback | Uso Ideal |
|--------|----------------|----------|-----------|
| `reasoner` | `deepseek/deepseek-reasoner` (R1) | openrouter R1, kimi | Análise complexa, lógica, matemática |
| `coder` | `deepseek/deepseek-chat` | gpt-4o, qwen-coder | Código, debugging, refactoring |
| `longctx` | `kimi/moonshot-v1-128k` | gemini-flash, deepseek | Docs longos, codebase review |
| `fast` | `zai/glm-4.7-flash` | gemini-lite, glm-free | Tarefas rápidas, heartbeats |
| `infra` | `zai/glm-4.7` | deepseek-chat, gpt-4o | SSH, Proxmox, Docker, infra |

### Mudar modelo no chat (sem restart)

```
/model list                        # Listar modelos disponíveis
/model claude-opus                 # Claude Opus 4.6 (conta PRO)
/model claude-sonnet               # Claude Sonnet 4.6
/model claude-haiku                # Claude Haiku 4.5
/model glm                         # Usar alias "glm" (zai/glm-4.7)
/model kimi                        # Kimi 128k
/model kimi-k2                     # Kimi K2.5 (256k)
/model r1                          # DeepSeek Reasoner
/model deepseek                    # DeepSeek Chat
/model gpt                         # GPT-4o
/model gemini                      # Gemini 2.0 Flash
/model openai/gpt-4o-mini          # Referência direta
```

---

## 💰 Estratégia de Custo — Model Tiering

| Tier | Modelo | Custo Input | Uso |
|------|--------|------------|-----|
| **Gratuito** | `openrouter/z-ai/glm-4.5-air:free` | $0 | Testes, dev |
| **Ultra-barato** | `zai/glm-4.7-flash` | ~$0.001/M | Heartbeats, triagem |
| **Padrão** | `zai/glm-4.7` | ~$0.05/M | Uso geral (primário) |
| **Especializado** | `deepseek/deepseek-chat` | ~$0.27/M | Código |
| **Raciocínio** | `deepseek/deepseek-reasoner` | ~$0.55/M | Análise profunda |
| **Contexto longo** | `kimi/moonshot-v1-128k` | ~$0.80/M | Docs grandes |
| **Premium** | `openai/gpt-4o` | ~$5/M | Fallback robusto |

**Economia estimada com tiering**: 60-90% vs usar sempre o modelo mais caro.

---

## ✅ Status dos Modelos (agldv03 — validado 2026-03-01)

```
Model                           Input      Ctx    Auth  Tags
zai/glm-4.7                     text       200k   yes   default, alias:glm
kimi/moonshot-v1-128k           text       128k   yes   fallback#1, alias:kimi
deepseek/deepseek-chat          text       64k    yes   fallback#2, alias:deepseek
openai/gpt-4o                   text+img   125k   no*   fallback#3, alias:gpt
google/gemini-2.0-flash         text+img   1024k  yes   fallback#4, alias:gemini
openrouter/deepseek/deepseek-v3 text       160k   yes   fallback#5
openrouter/z-ai/glm-4.5-air:free text      128k   yes   fallback#6
openrouter/gemini-2.0-flash-exp text       195k   no*   fallback#7
zai/glm-4.7-flash               text       195k   yes   alias:glm-flash
deepseek/deepseek-reasoner      text       64k    yes   alias:r1
openai/gpt-4o-mini              text+img   125k   no*   alias:gpt-mini
google/gemini-2.0-flash-lite    text+img   1024k  yes   alias:gemini-lite
openrouter/deepseek/deepseek-r1 text       63k    yes
openrouter/qwen3-coder:free     text       256k   yes
```

`*` = auth `no` → env var não disponível para o daemon systemd (ver seção abaixo).

---

## ⚠️ Env Vars e Systemd

As variáveis `OPENAI_AUTH`, `GEMINI_AUTH` etc. são definidas em `~/.zshrc`, que **não é carregado pelo systemd**. Para tornar um provider disponível no daemon:

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
| `config/openclaw/zshrc-openclaw.env` | Vars para OpenClaw + LiteLLM (source no .zshrc) |
| `scripts/deploy-openclaw-config.sh` | Deploy para agldv03 + fgsrv6 |

---

## 🐛 Troubleshooting

| Problema | Causa | Solução |
|----------|-------|---------|
| `5h ?` / `7d ?` na statusline | `cygpath` pipe retornava vazio no Linux | Fix aplicado em `/root/.claude/statusline-command.sh` (2026-03-01) |
| Provider não autenticado | Env var não carregada no systemd | Adicionar em `~/.config/environment.d/openclaw.conf` |
| `auth.profiles.X.apiKey` inválido | Campo não existe no schema | Usar apenas `provider` e `mode`; apiKey vai em `models.providers` |
| `agents.list[N].id` required | Agentes precisam de `id`, não `name` | Usar `"id": "nome-agente"` |
| `agents.list[N].description` inválido | Campo não existe no schema | Remover o campo `description` dos agentes |
| `streamMode` inválido | Renomeado na v2026.2.x | Usar `streaming: "partial"` |
| Modelo não aparece em `/model list` | Não está no `agents.defaults.models` | Adicionar ao bloco `models` no config e `gateway restart` |
| Gateway timeout no restart | Demora para subir mas fica OK | Verificar com `systemctl --user status openclaw-gateway` |
| Config não recarregado | Gateway ainda com config antigo | `openclaw gateway restart` |

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
