# AGLWK45 - Setup Claude Code + OpenClaw + LiteLLM

> **Host**: aglwk45 (VM Windows 11 Pro)
> **Proxmox ID**: 104 (aglsrv1)
> **IP Tailscale**: 100.117.146.21
> **Última atualização**: 2026-03-07

## Modelo Padrão: GLM-5

O **GLM-5** está configurado como modelo padrão no OpenClaw em todos os hosts AGL.

| Host | Modelo Default | Provider | IP Tailscale |
|------|----------------|----------|--------------|
| agldv03 | zai/glm-5 | ZAI API | 100.94.221.87 |
| agldv04 | zai/glm-5 | ZAI API | - |
| agldv05 | zai/glm-5 | ZAI API | - |
| agldv06 | zai/glm-5 | ZAI API | - |
| fgsrv06 | zai/glm-5 | ZAI API | 100.83.51.9 |
| aglwk45 | zai/glm-5 | ZAI API | 100.117.146.21 |

## QEMU Guest Agent (Proxmox)

O **QEMU Guest Agent** permite ao Proxmox administrar a VM104 (shutdown gracioso, snapshots com VSS, etc.).

| Item | Status |
|------|--------|
| Serviço no Windows | ✅ Instalado e em execução (`QEMU-GA`) |
| Inicialização | Automática |
| Habilitar no Proxmox | Executar no host AGLSRV1 (veja abaixo) |

**Habilitar no Proxmox** (executar no host AGLSRV1):

```bash
# Via SSH no AGLSRV1
ssh root@192.168.0.245 'qm set 104 --agent 1'

# Verificar
ssh root@192.168.0.245 'qm agent 104 ping'
```

Se `qm agent 104 ping` retornar sem erro, a comunicação está OK.

## Estado Atual

| Componente | Status | Versão |
|------------|--------|--------|
| Node.js | Instalado | v24.13.1 |
| OpenClaw | Instalado | v2026.2.26 |
| Git Bash | Instalado | - |
| Zsh (WSL) | Opcional | - |
| Docker | Não instalado | - |
| LiteLLM | Usa agldv03 remoto | - |

### Clone do repositório (unidade **U:** ↔ storage **overpower**)

No ambiente AGL, o caminho Linux do repo é tipicamente `/mnt/overpower/apps/dev/agl/agl-hostman`. Na **wk45**, com **U:** mapeada para a raiz do storage overpower (mesma árvore que no NFS), o clone deve estar em:

`U:\apps\dev\agl\agl-hostman`

Daí o patch DEP0040 (PowerShell) corre-se assim numa sessão **interativa** (PowerShell ou `cmd`):

```powershell
cd U:\apps\dev\agl\agl-hostman
powershell -ExecutionPolicy Bypass -File .\scripts\openclaw\wk45-patch-gateway-nodeopts.ps1
```

**`qm guest exec` (Proxmox)** corre comandos **sem** a tua sessão de utilizador: `net use` pode estar vazio e a unidade **U:** pode **não existir** nesse contexto, mesmo que no RDP vejas o drive. Para verificação automática via SSH ao AGLSRV1:

```bash
bash scripts/openclaw/vm104-verify-overpower-repo.sh
```

Se falhar só no guest exec mas o ficheiro existir no Explorador, mapeia **U:** como persistente para todos os utilizadores ou define `WK45_REPO_WIN` com um caminho que exista no contexto SYSTEM (ex. clone em `C:\work\agl-hostman`).

## Atualizações de Modelos (2026-03-07)

| Provider | Modelo | Preço (In/Out) | Context | Destaque |
|----------|--------|----------------|---------|----------|
| **Z.AI** | glm-5 | $1/$3.2 | 200K | 744B params (40B active), agentic |
| **Z.AI** | glm-4.7-flash | **FREE** | 131K | Ultra-barato |
| **Anthropic** | claude-opus-4-6 | $5/$25 | 1M (beta) | Agent Teams, SOTA coding |
| **Anthropic** | claude-sonnet-4-6 | $3/$15 | 200K | Opus-level coding |
| **DeepSeek** | V3.2 unificado | $0.28/$0.42 | 128K | Chat + Reasoner mesmo preço |
| **OpenAI** | gpt-5.3-chat-latest | $1.75/$14 | 128K | Instant (API; mesmo papel que antigo “gpt-5.3-instant”) |
| **OpenAI** | gpt-4.1 | $2/$8 | 1M | Long context |
| **Google** | gemini-3.1-pro-preview | ver Google | 1M | Substituir gemini-3-pro-preview (desligado) |
| **Google** | gemini-2.5-flash-lite | $0.10/$0.40 | 1M | Cheapest capable |
| **Moonshot** | kimi-k2.5 | $0.60/$3 | 256K | Agent Swarm (100 agents) |
| **Moonshot** | kimi-k2-thinking | $0.60/$2.50 | 256K | Deep reasoning |
| **Qwen** | qwen3.5-plus | $0.26/$1.56 | 1M | MoE + linear attention |

## Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                    AGLWK45 (Windows 11)                     │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────┐  │
│  │ Claude Code │───►│  OpenClaw   │───►│ LiteLLM Gateway │  │
│  │  (Git Bash) │    │  (Node.js)  │    │  (agldv03:4000) │  │
│  └─────────────┘    └─────────────┘    └─────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     AGLDV03 (Gateway)                       │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────┐  │
│  │   LiteLLM   │───►│    Redis    │───►│  Ollama (CT200) │  │
│  │   :4000     │    │   (CT137)   │    │   Local Models  │  │
│  └─────────────┘    └─────────────┘    └─────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## Passo 1: Configurar Variáveis de Ambiente no Windows

Abra o PowerShell como Administrador e execute:

```powershell
# Criar variáveis de ambiente do usuário
[Environment]::SetEnvironmentVariable("ANTHROPIC_BASE_URL", "http://100.94.221.87:4000", "User")
[Environment]::SetEnvironmentVariable("ANTHROPIC_AUTH_TOKEN", "sk-litellm-default", "User")
[Environment]::SetEnvironmentVariable("LITELLM_GATEWAY_URL", "http://100.94.221.87:4000", "User")
[Environment]::SetEnvironmentVariable("LITELLM_MASTER_KEY", "sk-litellm-default", "User")

# API Keys para OpenClaw (providers diretos)
[Environment]::SetEnvironmentVariable("ANTHROPIC_API_KEY", "sk-ant-api03-SEU_KEY", "User")
[Environment]::SetEnvironmentVariable("ZAI_API_KEY", "896fb1e6936a4cd1b61aa2314d6d3728.u2lsAqLNfajAslfx", "User")
[Environment]::SetEnvironmentVariable("GLM_AUTH", "896fb1e6936a4cd1b61aa2314d6d3728.u2lsAqLNfajAslfx", "User")
[Environment]::SetEnvironmentVariable("DEEPSEEK_API_KEY", "sk-7e5ed90fb4fc44d6b2b440d0cba7f791", "User")
[Environment]::SetEnvironmentVariable("MOONSHOT_API_KEY", "sk-8yrkMKdWtgsEVEPaq5i0NuDBAg3UTdZJNg2o6R4FMc2bnTG0", "User")
[Environment]::SetEnvironmentVariable("OPENAI_API_KEY", "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", "User")
[Environment]::SetEnvironmentVariable("GEMINI_API_KEY", "AIzaSyAt4PG2Bt_D2AWMmDc_XdR5eoklKK21tRM", "User")
[Environment]::SetEnvironmentVariable("OPENROUTER_API_KEY", "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", "User")
[Environment]::SetEnvironmentVariable("DASHSCOPE_API_KEY", "sk-48f612bb16634018a21eec165e13f78a", "User")

# URLs dos providers
[Environment]::SetEnvironmentVariable("GLM_URL", "https://api.z.ai/api/anthropic", "User")
[Environment]::SetEnvironmentVariable("KIMI_URL", "https://api.moonshot.ai/anthropic", "User")
[Environment]::SetEnvironmentVariable("KIMI_AUTH", "sk-8yrkMKdWtgsEVEPaq5i0NuDBAg3UTdZJNg2o6R4FMc2bnTG0", "User")
[Environment]::SetEnvironmentVariable("DEEPSEEK_URL", "https://api.deepseek.com/anthropic", "User")
[Environment]::SetEnvironmentVariable("DEEPSEEK_AUTH", "sk-7e5ed90fb4fc44d6b2b440d0cba7f791", "User")

Write-Host "Variaveis configuradas! Reinicie o terminal."
```

---

## Passo 2: Configurar Git Bash

Crie/edite o arquivo `~/.bashrc` no Git Bash:

```bash
# ~/.bashrc - Git Bash no Windows

# === Claude Code + LiteLLM Gateway ===
export ANTHROPIC_BASE_URL="http://100.94.221.87:4000"
export ANTHROPIC_AUTH_TOKEN="sk-litellm-default"
export LITELLM_GATEWAY_URL="http://100.94.221.87:4000"
export LITELLM_MASTER_KEY="sk-litellm-default"

# === API Keys (OpenClaw) ===
export ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"
export ZAI_API_KEY="896fb1e6936a4cd1b61aa2314d6d3728.u2lsAqLNfajAslfx"
export GLM_AUTH="${ZAI_API_KEY}"
export DEEPSEEK_API_KEY="sk-7e5ed90fb4fc44d6b2b440d0cba7f791"
export MOONSHOT_API_KEY="sk-8yrkMKdWtgsEVEPaq5i0NuDBAg3UTdZJNg2o6R4FMc2bnTG0"
export OPENAI_API_KEY="${OPENAI_API_KEY:-}"
export GEMINI_API_KEY="${GEMINI_API_KEY:-}"
export OPENROUTER_API_KEY="${OPENROUTER_API_KEY:-}"

# === URLs ===
export GLM_URL="https://api.z.ai/api/anthropic"
export KIMI_URL="https://api.moonshot.ai/anthropic"
export DEEPSEEK_URL="https://api.deepseek.com/anthropic"

# === Funções úteis ===
cclitellm() {
    export ANTHROPIC_BASE_URL="http://100.94.221.87:4000"
    export ANTHROPIC_AUTH_TOKEN="sk-litellm-default"
    echo "Claude Code usando LiteLLM Gateway (agldv03)"
}

ccdirect() {
    unset ANTHROPIC_BASE_URL
    unset ANTHROPIC_AUTH_TOKEN
    echo "Claude Code usando API direta"
}

# Testar conexão com LiteLLM
testlitellm() {
    curl -s -H "Authorization: Bearer sk-litellm-default" \
         http://100.94.221.87:4000/v1/models | jq -r '.data[].id' | head -10
}
```

Depois recarregue:
```bash
source ~/.bashrc
```

---

## Passo 2.5: Configurar Zsh (se usar WSL)

Se você usa WSL com zsh, adicione ao `~/.zshrc`:

```bash
# ~/.zshrc - WSL no Windows

# === Claude Code + LiteLLM Gateway ===
export ANTHROPIC_BASE_URL="http://100.94.221.87:4000"
export ANTHROPIC_AUTH_TOKEN="sk-litellm-default"
export LITELLM_GATEWAY_URL="http://100.94.221.87:4000"
export LITELLM_MASTER_KEY="sk-litellm-default"

# === API Keys (OpenClaw + LiteLLM) ===
export ZAI_API_KEY="896fb1e6936a4cd1b61aa2314d6d3728.u2lsAqLNfajAslfx"
export GLM_AUTH="${ZAI_API_KEY}"
export GLM_URL="https://api.z.ai/api/anthropic"
export DEEPSEEK_API_KEY="sk-7e5ed90fb4fc44d6b2b440d0cba7f791"
export DEEPSEEK_URL="https://api.deepseek.com/anthropic"
export DEEPSEEK_AUTH="${DEEPSEEK_API_KEY}"
export KIMI_AUTH="sk-8yrkMKdWtgsEVEPaq5i0NuDBAg3UTdZJNg2o6R4FMc2bnTG0"
export KIMI_URL="https://api.moonshot.ai/anthropic"
export MOONSHOT_API_KEY="${KIMI_AUTH}"
export OPENROUTER_API_KEY="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"
export DASHSCOPE_API_KEY="sk-48f612bb16634018a21eec165e13f78a"

# === Funções úteis ===
cclitellm() {
    export ANTHROPIC_BASE_URL="http://100.94.221.87:4000"
    export ANTHROPIC_AUTH_TOKEN="sk-litellm-default"
    echo "Claude Code usando LiteLLM Gateway (agldv03)"
}

ccglm5() {
    export ANTHROPIC_BASE_URL="http://100.94.221.87:4000"
    export ANTHROPIC_AUTH_TOKEN="sk-litellm-default"
    echo "Claude Code usando GLM-5 via LiteLLM"
}

ccdirect() {
    unset ANTHROPIC_BASE_URL
    unset ANTHROPIC_AUTH_TOKEN
    echo "Claude Code usando API direta"
}

# Alias para OpenClaw com GLM-5
alias ocglm5='openclaw models set zai/glm-5'
alias ocmodels='openclaw models list'
```

Depois recarregue:
```bash
source ~/.zshrc
```

---

## Passo 3: Atualizar OpenClaw

```powershell
# Atualizar OpenClaw para versão mais recente
npm update -g openclaw

# Verificar versão
openclaw --version
```

---

## Passo 4: Configurar OpenClaw com Providers

Crie o arquivo `~/.openclaw/openclaw.json` (no Git Bash, isso é `C:\Users\SEU_USUARIO\.openclaw\openclaw.json`):

```json
{
  "meta": {
    "lastTouchedVersion": "2026.2.26",
    "lastTouchedAt": "2026-03-07T00:00:00.000Z"
  },
  "auth": {
    "profiles": {
      "zai:default": { "provider": "zai", "mode": "api_key" },
      "openai:default": { "provider": "openai", "mode": "api_key" },
      "google:default": { "provider": "google", "mode": "api_key" },
      "anthropic:default": { "provider": "anthropic", "mode": "api_key" },
      "openrouter:default": { "provider": "openrouter", "mode": "api_key" }
    }
  },
  "models": {
    "providers": {
      "zai": {
        "baseUrl": "${GLM_URL}",
        "apiKey": "${ZAI_API_KEY}",
        "api": "anthropic-messages",
        "models": [
          { "id": "glm-5", "name": "GLM-5 (744B/40B)", "contextWindow": 200000, "maxTokens": 8192 },
          { "id": "glm-4.7", "name": "GLM-4.7", "contextWindow": 203000, "maxTokens": 8192 },
          { "id": "glm-4.7-flash", "name": "GLM-4.7 Flash (FREE)", "contextWindow": 131072, "maxTokens": 8192 }
        ]
      },
      "anthropic": {
        "baseUrl": "https://api.anthropic.com",
        "apiKey": "${ANTHROPIC_API_KEY}",
        "models": [
          { "id": "claude-opus-4-6", "name": "Claude Opus 4.6 (1M beta)", "contextWindow": 1000000, "maxTokens": 8192 },
          { "id": "claude-sonnet-4-6", "name": "Claude Sonnet 4.6", "contextWindow": 200000, "maxTokens": 8192 },
          { "id": "claude-haiku-4-5-20251001", "name": "Claude Haiku 4.5", "contextWindow": 200000, "maxTokens": 8192 }
        ]
      },
      "deepseek": {
        "baseUrl": "${DEEPSEEK_URL}",
        "apiKey": "${DEEPSEEK_API_KEY}",
        "api": "anthropic-messages",
        "models": [
          { "id": "deepseek-chat", "name": "DeepSeek V3.2 Chat", "contextWindow": 131072, "maxTokens": 8192 },
          { "id": "deepseek-reasoner", "name": "DeepSeek V3.2 Reasoner", "contextWindow": 131072, "maxTokens": 65536, "reasoning": true }
        ]
      },
      "moonshot": {
        "baseUrl": "${KIMI_URL}",
        "apiKey": "${KIMI_AUTH}",
        "api": "anthropic-messages",
        "models": [
          { "id": "kimi-k2.5", "name": "Kimi K2.5 (256K)", "contextWindow": 262144, "maxTokens": 16384 },
          { "id": "kimi-k2-thinking", "name": "Kimi K2 Thinking", "contextWindow": 262144, "maxTokens": 16384 },
          { "id": "moonshot-v1-128k", "name": "Kimi 128k", "contextWindow": 131072, "maxTokens": 8192 }
        ]
      },
      "google": {
        "baseUrl": "https://generativelanguage.googleapis.com/v1beta",
        "apiKey": "${GEMINI_API_KEY}",
        "models": [
          { "id": "gemini-3.1-pro-preview", "name": "Gemini 3.1 Pro Preview", "contextWindow": 1048576, "maxTokens": 65536 },
          { "id": "gemini-2.5-pro", "name": "Gemini 2.5 Pro", "contextWindow": 2097152, "maxTokens": 65536 },
          { "id": "gemini-2.5-flash", "name": "Gemini 2.5 Flash", "contextWindow": 1048576, "maxTokens": 65536 },
          { "id": "gemini-2.5-flash-lite", "name": "Gemini 2.5 Flash-Lite", "contextWindow": 1048576, "maxTokens": 65536 }
        ]
      },
      "openai": {
        "baseUrl": "https://api.openai.com/v1",
        "apiKey": "${OPENAI_API_KEY}",
        "models": [
          { "id": "gpt-5.3-chat-latest", "name": "GPT-5.3 Chat (Instant)", "contextWindow": 128000, "maxTokens": 16384 },
          { "id": "gpt-4.1", "name": "GPT-4.1 (1M)", "contextWindow": 1048576, "maxTokens": 32768 },
          { "id": "gpt-4o", "name": "GPT-4o", "contextWindow": 128000, "maxTokens": 16384 },
          { "id": "gpt-4o-mini", "name": "GPT-4o Mini", "contextWindow": 128000, "maxTokens": 16384 }
        ]
      },
      "qwen": {
        "baseUrl": "https://dashscope-intl.aliyuncs.com/compatible-mode/v1",
        "apiKey": "${DASHSCOPE_API_KEY}",
        "api": "openai-completions",
        "models": [
          { "id": "qwen3.5-plus-02-15", "name": "Qwen 3.5 Plus (1M)", "contextWindow": 1048576, "maxTokens": 131072 },
          { "id": "qwen3-max-2026-01-23", "name": "Qwen 3 Max", "contextWindow": 262144, "maxTokens": 131072 },
          { "id": "qwen3-coder-next", "name": "Qwen 3 Coder", "contextWindow": 1048576, "maxTokens": 131072 },
          { "id": "qwen-turbo", "name": "Qwen Turbo", "contextWindow": 131072, "maxTokens": 8192 }
        ]
      },
      "openrouter": {
        "baseUrl": "https://openrouter.ai/api/v1",
        "apiKey": "${OPENROUTER_API_KEY}",
        "api": "openai-completions",
        "models": [
          { "id": "z-ai/glm-4.5-air:free", "name": "GLM 4.5 Air Free", "contextWindow": 131072, "maxTokens": 8192 },
          { "id": "qwen/qwen3.5:free", "name": "Qwen 3.5 Free", "contextWindow": 256000, "maxTokens": 8192 },
          { "id": "qwen/qwen3-coder:free", "name": "Qwen 3 Coder Free", "contextWindow": 256000, "maxTokens": 8192 },
          { "id": "deepseek/deepseek-v3.2", "name": "DeepSeek V3.2 OR", "contextWindow": 160000, "maxTokens": 8192 }
        ]
      },
      "ollama": {
        "baseUrl": "http://192.168.0.200:11434/v1",
        "api": "openai-completions",
        "models": [
          { "id": "phi3:mini", "name": "Phi-3 Mini Local", "contextWindow": 4096, "maxTokens": 4096 },
          { "id": "llama3.2:3b", "name": "Llama 3.2 3B Local", "contextWindow": 4096, "maxTokens": 4096 },
          { "id": "mistral:7b", "name": "Mistral 7B Local", "contextWindow": 8192, "maxTokens": 8192 },
          { "id": "qwen3:4b", "name": "Qwen 3 4B Local", "contextWindow": 8192, "maxTokens": 8192 },
          { "id": "qwen3:8b", "name": "Qwen 3 8B Local", "contextWindow": 8192, "maxTokens": 8192 },
          { "id": "qwen2.5-coder:7b", "name": "Qwen 2.5 Coder Local", "contextWindow": 16384, "maxTokens": 16384 },
          { "id": "gemma2:9b", "name": "Gemma 2 9B Local", "contextWindow": 8192, "maxTokens": 8192 }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": "zai/glm-5",
      "fallback": [
        "anthropic/claude-sonnet-4-6",
        "deepseek/deepseek-chat",
        "moonshot/kimi-k2.5",
        "google/gemini-3.1-pro-preview",
        "openrouter/z-ai/glm-4.5-air:free"
      ],
      "compaction": { "mode": "safeguard" },
      "maxConcurrent": 4
    }
  }
}
```
        "baseUrl": "${DEEPSEEK_URL}",
        "apiKey": "${DEEPSEEK_AUTH}",
        "api": "anthropic-messages",
        "models": [
          { "id": "deepseek-chat", "name": "DeepSeek Chat", "contextWindow": 131072, "maxTokens": 8192 },
          { "id": "deepseek-reasoner", "name": "DeepSeek Reasoner", "contextWindow": 131072, "maxTokens": 8192, "reasoning": true }
        ]
      }
    },
    "defaults": {
      "model": "zai/glm-5",
      "fallback": [
        "zai/glm-4.7",
        "anthropic/claude-sonnet-4-6",
        "deepseek/deepseek-chat",
        "kimi/moonshot-v1-128k",
        "openrouter/z-ai/glm-4.5-air:free"
      ]
    }
  },
  "agents": {
    "defaults": {
      "compaction": { "mode": "safeguard" },
      "maxConcurrent": 4
    }
  }
}
```

### Definir GLM-5 como Default via CLI

Após criar o config, execute:

```bash
# Carregar variáveis de ambiente
source ~/.bashrc  # ou source ~/.zshrc

# Definir GLM-5 como modelo padrão
openclaw models set zai/glm-5

# Verificar
openclaw models list | grep default
# Deve mostrar: zai/glm-5 ... default
```

---

## Passo 5: Verificar Conectividade

No Git Bash:

```bash
# Testar conexão com LiteLLM do agldv03
curl -s http://100.94.221.87:4000/health

# Listar modelos disponíveis
curl -s -H "Authorization: Bearer sk-litellm-default" \
     http://100.94.221.87:4000/v1/models | jq -r '.data[].id'

# Testar um modelo
curl -s -H "Authorization: Bearer sk-litellm-default" \
     -H "Content-Type: application/json" \
     http://100.94.221.87:4000/v1/chat/completions \
     -d '{"model": "glm-5", "messages": [{"role": "user", "content": "Diga ola"}], "max_tokens": 20}'
```

---

## Passo 6: Testar Claude Code

```bash
# No Git Bash, com variáveis carregadas
cclitellm

# Verificar se está usando o gateway
echo $ANTHROPIC_BASE_URL
# Deve mostrar: http://100.94.221.87:4000

# Testar claude-code
claude --version
```

---

## Modelos Disponíveis no LiteLLM (agldv03)

| Modelo | Alias | Preço (In/Out) | Latência | Uso |
|--------|-------|----------------|----------|-----|
| glm-5 | - | $1/$3.2 | ~2.4s | Raciocínio geral (744B params) |
| glm-4.7 | glm | $0.6/$2.2 | ~1.5s | Uso diário |
| glm-flash | - | **FREE** | ~0.8s | Tarefas rápidas |
| qwen3.5-plus | - | $0.26/$1.56 | ~0.9s | DashScope (1M ctx) |
| deepseek | - | $0.28/$0.42 | ~1.4s | Código V3.2 |
| r1 | deepseek-reasoner | $0.28/$0.42 | ~3s | Reasoning unificado |
| kimi-k2.5 | kimi | $0.60/$3 | ~2s | 256K, Agent Swarm |
| kimi-thinking | - | $0.60/$2.50 | ~4s | Deep reasoning |
| claude-opus | - | $5/$25 | ~4s | 1M ctx, Agent Teams |
| claude-sonnet | - | $3/$15 | ~2s | Opus-level coding |
| gpt-5.3-chat-latest | (alias proxy `gpt-5.3-instant`) | $1.75/$14 | ~1.5s | 128K ctx (API OpenAI) |
| gemini-3.1-pro-preview | gemini | ver Google | ~2s | Gemini 3.1 |
| gemini-lite | - | $0.10/$0.40 | ~0.5s | Cheapest capable |
| phi3-local | - | FREE | ~8s | Local (Ollama) |
| qwen3-local | - | FREE | ~21s | Local (Ollama) |

---

## Troubleshooting

### Erro: "Network is unreachable"
```bash
# Verificar se Tailscale está rodando
tailscale status

# Se não estiver, iniciar
tailscale up
```

### Erro: "Authentication Error" / `token_not_found_in_db` (LiteLLM proxy)

O **LiteLLM** no agldv03 usa o valor real de **`LITELLM_MASTER_KEY`** em `/opt/litellm/.env`. Se for **diferente** de `sk-litellm-default`, **todos** os clientes (OpenClaw `models.providers.*.apiKey`, `ANTHROPIC_AUTH_TOKEN`, `curl`) devem usar **essa** chave — caso contrário verás 401 e mensagens com `LiteLLM_VerificationTokenTable`.

**Correção rápida (Git Bash na wk45)** — sincroniza `openclaw.json` e aponta o proxy para o agldv03:

```bash
cd /c/caminho/para/agl-hostman   # ou o clone do repo
bash scripts/openclaw/wk45-sync-openclaw-litellm.sh
openclaw gateway restart
```

O script obtém a chave por SSH (`root@100.94.221.87`) ou usa `LITELLM_MASTER_KEY` se já estiver definida. Requer `jq` e acesso SSH ao agldv03 (ou cola a chave manualmente).

### Via Proxmox (QEMU guest agent, sem RDP)

Na máquina com o repo (ou CI), a partir do host que faz SSH ao **AGLSRV1** (Proxmox onde corre a VM104):

```bash
bash scripts/openclaw/deploy-aglwk45-wk45-litellm-qemu.sh
```

Variáveis úteis:

| Variável | Significado |
|----------|-------------|
| `AGLSRV1_HOST` | SSH ao Proxmox (default `root@100.107.113.33`) |
| `AGLWK45_VMID` | VMID (default `104`) |
| `LITELLM_GATEWAY_SSH` | Host com `/opt/litellm/.env` (default `root@100.94.221.87`) — o script obtém a chave **aqui** antes do SSH ao Proxmox |
| `LITELLM_MASTER_KEY` | Opcional: se já definida, não faz SSH ao agldv03 |
| `LITELLM_PROXY_BASE_URL` | Default `http://100.94.221.87:4000` |

**Importante**: o LiteLLM em produção usa `LITELLM_MASTER_KEY` **real** (ex. em `/opt/litellm/.env`). `sk-litellm-default` no `openclaw.json` provoca **401** em todos os modelos. O script de deploy obtém a chave por SSH ao agldv03 **na máquina onde corres o bash** (não no Proxmox).

O fluxo copia `vm104_guest_wk45_litellm_sync.py` e `wk45-sync-openclaw-litellm.cjs` para o Proxmox, corre `qm guest exec` na VM104, grava `litellm-gateway.env`, aplica o merge no `openclaw.json` com **Node** (sem `jq` no Windows) e tenta `openclaw gateway restart` se existir no PATH (falha do restart não invalida o merge). O exit code do passo reflete só o **Node**; esperado: `OK wk45-sync-openclaw-litellm` na saída.

Opcional: copiar `config/openclaw/wk45-litellm-gateway.env.example` → `~/.openclaw/litellm-gateway.env`, preencher **`LITELLM_MASTER_KEY`** com o valor real e **source** antes do `zshrc-openclaw.env` no `.bashrc`.

```bash
# Obter a chave no gateway (agldv03) e testar
ssh root@100.94.221.87 'grep ^LITELLM_MASTER_KEY= /opt/litellm/.env'
export LITELLM_MASTER_KEY='(colar o valor)'
curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $LITELLM_MASTER_KEY" http://100.94.221.87:4000/v1/models
# Esperado: 200
```

Mais detalhe: `docs/LITELLM-TROUBLESHOOTING.md` (secção *token_not_found_in_db*).

### Avisos na consola do gateway (DEP0040 `punycode`, linhas `[telegram]`)

- **`(node:…) [DEP0040] DeprecationWarning: punycode`**: vem do **Node** (módulo integrado deprecado usado por dependências). Não indica config errada. Na wk45: `cd` à raiz do clone (ex. `U:\apps\dev\agl\agl-hostman` se **U:** for overpower) e `powershell -ExecutionPolicy Bypass -File .\scripts\openclaw\wk45-patch-gateway-nodeopts.ps1`, ou caminho absoluto para o `.ps1`. Altera `%USERPROFILE%\.openclaw\gateway.cmd` (backup `.bak.nodeopts`); reinicia a tarefa **OpenClaw Gateway**.
- **`[telegram] autoSelectFamily=…` / `dnsResultOrder=…`**: mensagens **informativas** da stack de rede, não são falhas.

### OpenClaw não carrega variáveis
```bash
# No Git Bash, sempre faça source antes
source ~/.bashrc
openclaw status
```

### Verificação rápida (scripts)
```bash
# Git Bash
bash scripts/verify-openclaw-aglwk45.sh

# PowerShell
powershell -ExecutionPolicy Bypass -File scripts/verify-openclaw-aglwk45.ps1
```

---

## Manutenção

### Atualizar OpenClaw
```bash
npm update -g openclaw
```

### Verificar logs do LiteLLM (no agldv03)
```bash
ssh root@agldv03 "docker logs litellm-proxy --tail 50"
```

### Reiniciar LiteLLM (no agldv03)
```bash
ssh root@agldv03 "docker restart litellm-proxy"
```

---

## Referências

- [LiteLLM Config](../config/litellm/config.yaml)
- [OpenClaw Docs](./OPENCLAW.md)
- [Claude-Flow LiteLLM](./CLAUDE-FLOW-LITELLM.md)
- [Troubleshooting LiteLLM](./LITELLM-TROUBLESHOOTING.md)
