# AGLWK45 - Setup Claude Code + OpenClaw + LiteLLM

> **Host**: aglwk45 (VM Windows 11 Pro)
> **Proxmox ID**: 104 (aglsrv1)
> **IP Tailscale**: 100.117.146.21
> **Última atualização**: 2026-03-07

## Modelo Padrão: GLM-5

O **GLM-5** está configurado como modelo padrão no OpenClaw em todos os hosts AGL.

| Host | Modelo Default | Provider |
|------|----------------|----------|
| agldv03 | zai/glm-5 | ZAI API |
| fgsrv06 | zai/glm-5 | ZAI API |
| aglwk45 | zai/glm-5 | ZAI API |

## Estado Atual

| Componente | Status | Versão |
|------------|--------|--------|
| Node.js | Instalado | v24.13.1 |
| OpenClaw | Instalado | v2026.2.22-2 |
| Git Bash | Instalado | - |
| Zsh (WSL) | Opcional | - |
| Docker | Não instalado | - |
| LiteLLM | Usa agldv03 remoto | - |

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
          { "id": "glm-5", "name": "GLM-5", "contextWindow": 125000, "maxTokens": 8192 },
          { "id": "glm-4.7", "name": "GLM-4.7", "contextWindow": 200000, "maxTokens": 8192 },
          { "id": "glm-4.7-flash", "name": "GLM-4.7 Flash", "contextWindow": 195000, "maxTokens": 8192 }
        ]
      },
      "anthropic": {
        "baseUrl": "https://api.anthropic.com",
        "apiKey": "${ANTHROPIC_API_KEY}",
        "models": [
          { "id": "claude-opus-4-6", "name": "Claude Opus 4.6", "contextWindow": 195000, "maxTokens": 8192 },
          { "id": "claude-sonnet-4-6", "name": "Claude Sonnet 4.6", "contextWindow": 195000, "maxTokens": 8192 },
          { "id": "claude-haiku-4-5-20251001", "name": "Claude Haiku 4.5", "contextWindow": 195000, "maxTokens": 8192 }
        ]
      },
      "deepseek": {
        "baseUrl": "${DEEPSEEK_URL}",
        "apiKey": "${DEEPSEEK_API_KEY}",
        "api": "anthropic-messages",
        "models": [
          { "id": "deepseek-chat", "name": "DeepSeek Chat V3.2", "contextWindow": 131072, "maxTokens": 8192 },
          { "id": "deepseek-reasoner", "name": "DeepSeek Reasoner R1", "contextWindow": 131072, "maxTokens": 8192, "reasoning": true }
        ]
      },
      "kimi": {
        "baseUrl": "${KIMI_URL}",
        "apiKey": "${KIMI_AUTH}",
        "api": "anthropic-messages",
        "models": [
          { "id": "moonshot-v1-128k", "name": "Kimi 128k", "contextWindow": 131072, "maxTokens": 8192 }
        ]
      },
      "google": {
        "baseUrl": "https://generativelanguage.googleapis.com/v1beta",
        "apiKey": "${GEMINI_API_KEY}",
        "models": [
          { "id": "gemini-2.5-flash", "name": "Gemini 2.5 Flash", "contextWindow": 1024000, "maxTokens": 8192 },
          { "id": "gemini-2.0-flash", "name": "Gemini 2.0 Flash", "contextWindow": 1024000, "maxTokens": 8192 }
        ]
      },
      "openai": {
        "baseUrl": "https://api.openai.com/v1",
        "apiKey": "${OPENAI_API_KEY}",
        "models": [
          { "id": "gpt-5", "name": "GPT-5", "contextWindow": 391000, "maxTokens": 8192 },
          { "id": "gpt-4o", "name": "GPT-4o", "contextWindow": 125000, "maxTokens": 8192 },
          { "id": "gpt-5-mini", "name": "GPT-5 Mini", "contextWindow": 391000, "maxTokens": 8192 }
        ]
      },
      "qwen": {
        "baseUrl": "https://dashscope-intl.aliyuncs.com/compatible-mode/v1",
        "apiKey": "${DASHSCOPE_API_KEY}",
        "api": "openai-completions",
        "models": [
          { "id": "qwen-turbo", "name": "Qwen Turbo", "contextWindow": 131072, "maxTokens": 8192 },
          { "id": "qwen-plus", "name": "Qwen Plus", "contextWindow": 131072, "maxTokens": 8192 },
          { "id": "qwen-max", "name": "Qwen Max", "contextWindow": 131072, "maxTokens": 8192 },
          { "id": "qwen3.5", "name": "Qwen 3.5", "contextWindow": 131072, "maxTokens": 8192 },
          { "id": "qwen3.5-plus", "name": "Qwen 3.5 Plus", "contextWindow": 131072, "maxTokens": 8192 },
          { "id": "qwen3-max", "name": "Qwen 3 Max", "contextWindow": 131072, "maxTokens": 8192 },
          { "id": "qwen-coder", "name": "Qwen Coder", "contextWindow": 131072, "maxTokens": 8192 }
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
          { "id": "phi3:mini", "name": "Phi-3 Mini Local", "contextWindow": 8192, "maxTokens": 4096 },
          { "id": "llama3.2:3b", "name": "Llama 3.2 3B Local", "contextWindow": 8192, "maxTokens": 4096 },
          { "id": "mistral:7b", "name": "Mistral 7B Local", "contextWindow": 8192, "maxTokens": 4096 },
          { "id": "qwen3:4b", "name": "Qwen 3 4B Local", "contextWindow": 8192, "maxTokens": 4096 },
          { "id": "qwen3:8b", "name": "Qwen 3 8B Local", "contextWindow": 8192, "maxTokens": 4096 },
          { "id": "qwen2.5-coder:7b", "name": "Qwen 2.5 Coder Local", "contextWindow": 8192, "maxTokens": 4096 },
          { "id": "gemma2:9b", "name": "Gemma 2 9B Local", "contextWindow": 8192, "maxTokens": 4096 }
        ]
      }
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

| Modelo | Alias | Latência | Uso |
|--------|-------|----------|-----|
| glm-5 | - | ~2.4s | Raciocínio geral |
| glm-4.7 | glm | ~1.5s | Uso diário |
| glm-flash | - | ~0.8s | Tarefas rápidas |
| qwen3.5-plus | - | ~0.9s | FREE (DashScope) |
| deepseek | - | ~1.4s | Código |
| r1 | deepseek-reasoner | ~3s | Reasoning |
| kimi | moonshot-v1-128k | ~2s | Contexto longo |
| phi3-local | - | ~8s | Local (Ollama) |
| qwen3-local | - | ~21s | Local (Ollama) |

---

## Troubleshooting

### Erro: "Network is unreachable"
```bash
# Verificar se Tailscale está rodando
tailscale status

# Se não estiver, iniciar
tailscale up
```

### Erro: "Authentication Error"
```bash
# Verificar se a API key está correta
echo $ANTHROPIC_AUTH_TOKEN
# Deve mostrar: sk-litellm-default
```

### OpenClaw não carrega variáveis
```bash
# No Git Bash, sempre faça source antes
source ~/.bashrc
openclaw status
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
