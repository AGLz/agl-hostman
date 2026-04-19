# OpenClaw Fixes — 2026-04-12/13

## Problemas Identificados e Resolvidos

### 1. Auth 401 no LiteLLM (CRÍTICO) ✅ RESOLVIDO

**Sintoma:** Mensagens de erro 401 com hash `16db2bfa...` (chave OpenAI direta `sk-svcacct-...w3EA`)

**Causa raiz:** O ficheiro `~/.config/environment.d/openclaw.conf` tinha `OPENAI_API_KEY` apontando para a chave OpenAI direta em vez da chave LiteLLM master.

**Fix:**
```bash
# openclaw.conf - corrigir chave
sed -i "s|OPENAI_API_KEY=\"sk-svcacct.*\"|OPENAI_API_KEY=\"sk-litellm-8fd0003fd1a3883e7d6308c60cb5eed3ac4680832e801ded90e1873ce4dfe1a0\"|" ~/.config/environment.d/openclaw.conf
sed -i "s|OPENAI_AUTH=\"sk-svcacct.*\"|OPENAI_AUTH=\"sk-litellm-8fd0003fd1a3883e7d6308c60cb5eed3ac4680832e801ded90e1873ce4dfe1a0\"|" ~/.config/environment.d/openclaw.conf
sed -i "s|DASHSCOPE_API_KEY=\"sk-48f.*\"|DASHSCOPE_API_KEY=\"sk-litellm-8fd0003fd1a3883e7d6308c60cb5eed3ac4680832e801ded90e1873ce4dfe1a0\"|" ~/.config/environment.d/openclaw.conf
```

### 2. Nomes de Modelo Incorretos ✅ RESOLVIDO

**Sintoma:** `dashscope/qwen-coder` → 404 "model does not exist"

**Fix:** Modelos agora usam nomes compatíveis com LiteLLM:
- Primary: `openai/qwen3.5-flash`
- Fallbacks: `openai/qwen-flash`, `openai/qwen3.5-plus`

### 3. Providers Incorretos ✅ RESOLVIDO

**Sintoma:** Plugins registravam providers com chaves diretas dos providers

**Fix:** `openclaw.json` configurado com:
- `openai` provider → `http://localhost:4000` com `${OPENAI_API_KEY}`
- `dashscope` provider → `http://localhost:4000` com `sk-litellm-8fd...`

### 4. Plugins Override ✅ RESOLVIDO

**Fix:** Plugins desabilitados em `openclaw.json`:
- `openai`, `google`, `anthropic`, `moonshot`, `deepseek`, `openrouter` → `enabled: false`
- LiteLLM proxy faz todo o roteamento

### 5. Cron Jobs - Alertas Falsos ✅ RESOLVIDO

**Problemas:**
- IPs errados (fileserver5 = fgsrv07-1)
- ICMP bloqueado por FGSRV07
- Threshold logic invertida (188GB < 100GB?)

**Fixes:**
- IPs corrigidos no `critical-services-monitor`
- `tailscale ping` como fallback para hosts que bloqueiam ICMP
- Exemplos explícitos nos thresholds
- `source /root/.openclaw/litellm-master.secret.env` adicionado

### 6. Auth Store Cache ✅ RESOLVIDO

**Fix:** `rm -f /root/.openclaw/agents/main/agent/auth-profiles.json`

## Configuração Atual

### `~/.config/environment.d/openclaw.conf`
```
OPENAI_API_KEY=sk-litellm-8fd0003fd1a3883e7d6308c60cb5eed3ac4680832e801ded90e1873ce4dfe1a0
DASHSCOPE_API_KEY=sk-litellm-8fd0003fd1a3883e7d6308c60cb5eed3ac4680832e801ded90e1873ce4dfe1a0
LITELLM_MASTER_KEY=sk-litellm-8fd0003fd1a3883e7d6308c60cb5eed3ac4680832e801ded90e1873ce4dfe1a0
```

### `openclaw.json` (modelo)
```json
{
  "models": {
    "providers": {
      "openai": {
        "baseUrl": "http://localhost:4000",
        "apiKey": "${OPENAI_API_KEY}",
        "api": "openai-completions",
        "models": []
      },
      "dashscope": {
        "baseUrl": "http://localhost:4000",
        "apiKey": "sk-litellm-8fd...",
        "api": "openai-completions",
        "models": []
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "openai/qwen3.5-flash",
        "fallbacks": ["openai/qwen-flash", "openai/qwen3.5-plus"]
      }
    }
  },
  "plugins": {
    "entries": {
      "openai": {"enabled": false},
      "google": {"enabled": false},
      "anthropic": {"enabled": false},
      "moonshot": {"enabled": false},
      "deepseek": {"enabled": false},
      "openrouter": {"enabled": false}
    }
  }
}
```

## Problemas Conhecidos (Não Resolvidos)

### Memory Leak do Gateway
- Múltiplas instâncias do gateway spawn (~1-1.7GB cada)
- `openclaw-update` e `npm` processos consomem ~1-2GB
- **Workaround:** `pkill -9 -f openclaw-update && pkill -9 -f npm && pkill -9 -f openclaw-gateway` seguido de `systemctl --user start openclaw-gateway`

### Cron Jobs não Completam Consistentemente
- Jobs são triggerados mas agentes não completam
- Provavelmente relacionado ao memory leak
- Morning briefing funcionou às 01:47 (HEARTBEAT_OK)

## Comandos de Emergência

```bash
# Kill everything
systemctl --user stop openclaw-gateway
pkill -9 -f openclaw
pkill -9 -f npm

# Start fresh
systemctl --user start openclaw-gateway

# Check
openclaw gateway status
openclaw cron list
```

## Verificação de Sucesso

Morning briefing às 01:47 confirmou:
- ✅ Hosts: 3/3 OK
- ✅ Services: 3/3 OK (LiteLLM, n8n, wg-easy)
- ✅ Websites: 9/10 OK
- ✅ HEARTBEAT_OK

---

*Última atualização: 2026-04-13 02:08 UTC-03*
