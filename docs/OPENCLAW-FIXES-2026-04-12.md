# OpenClaw Fixes â€” 2026-04-12/13

## Problemas Identificados e Resolvidos

### 1. Auth 401 no LiteLLM (CRÃTICO) âœ… RESOLVIDO

**Sintoma:** Mensagens de erro 401 com hash `16db2bfa...` (chave OpenAI direta `sk-svcacct-...w3EA`)

**Causa raiz:** O ficheiro `~/.config/environment.d/openclaw.conf` tinha `OPENAI_API_KEY` apontando para a chave OpenAI direta em vez da chave LiteLLM master.

**Fix:**
```bash
# openclaw.conf - corrigir chave
sed -i "s|OPENAI_API_KEY=\"sk-svcacct.*\"|OPENAI_API_KEY=\"${LITELLM_MASTER_KEY}\"|" ~/.config/environment.d/openclaw.conf
sed -i "s|OPENAI_AUTH=\"sk-svcacct.*\"|OPENAI_AUTH=\"${LITELLM_MASTER_KEY}\"|" ~/.config/environment.d/openclaw.conf
sed -i "s|DASHSCOPE_API_KEY=\"sk-48f.*\"|DASHSCOPE_API_KEY=\"${LITELLM_MASTER_KEY}\"|" ~/.config/environment.d/openclaw.conf
```

### 2. Nomes de Modelo Incorretos âœ… RESOLVIDO

**Sintoma:** `dashscope/qwen-coder` â†’ 404 "model does not exist"

**Fix:** Modelos agora usam nomes compatÃ­veis com LiteLLM:
- Primary: `openai/qwen3.5-flash`
- Fallbacks: `openai/qwen-flash`, `openai/qwen3.5-plus`

### 3. Providers Incorretos âœ… RESOLVIDO

**Sintoma:** Plugins registravam providers com chaves diretas dos providers

**Fix:** `openclaw.json` configurado com:
- `openai` provider â†’ `http://localhost:4000` com `${OPENAI_API_KEY}`
- `dashscope` provider â†’ `http://localhost:4000` com `${LITELLM_MASTER_KEY}`

### 4. Plugins Override âœ… RESOLVIDO

**Fix:** Plugins desabilitados em `openclaw.json`:
- `openai`, `google`, `anthropic`, `moonshot`, `deepseek`, `openrouter` â†’ `enabled: false`
- LiteLLM proxy faz todo o roteamento

### 5. Cron Jobs - Alertas Falsos âœ… RESOLVIDO

**Problemas:**
- IPs errados (fileserver5 = fgsrv07-1)
- ICMP bloqueado por FGSRV07
- Threshold logic invertida (188GB < 100GB?)

**Fixes:**
- IPs corrigidos no `critical-services-monitor`
- `tailscale ping` como fallback para hosts que bloqueiam ICMP
- Exemplos explÃ­citos nos thresholds
- `source /root/.openclaw/litellm-master.secret.env` adicionado

### 6. Auth Store Cache âœ… RESOLVIDO

**Fix:** `rm -f /root/.openclaw/agents/main/agent/auth-profiles.json`

## ConfiguraÃ§Ã£o Atual

### `~/.config/environment.d/openclaw.conf`
```
OPENAI_API_KEY=${LITELLM_MASTER_KEY}
DASHSCOPE_API_KEY=${LITELLM_MASTER_KEY}
LITELLM_MASTER_KEY=${LITELLM_MASTER_KEY}
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
        "apiKey": "${LITELLM_MASTER_KEY}",
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

## Problemas Conhecidos (NÃ£o Resolvidos)

### Memory Leak do Gateway
- MÃºltiplas instÃ¢ncias do gateway spawn (~1-1.7GB cada)
- `openclaw-update` e `npm` processos consomem ~1-2GB
- **Workaround:** `pkill -9 -f openclaw-update && pkill -9 -f npm && pkill -9 -f openclaw-gateway` seguido de `systemctl --user start openclaw-gateway`

### Cron Jobs nÃ£o Completam Consistentemente
- Jobs sÃ£o triggerados mas agentes nÃ£o completam
- Provavelmente relacionado ao memory leak
- Morning briefing funcionou Ã s 01:47 (HEARTBEAT_OK)

## Comandos de EmergÃªncia

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

## VerificaÃ§Ã£o de Sucesso

Morning briefing Ã s 01:47 confirmou:
- âœ… Hosts: 3/3 OK
- âœ… Services: 3/3 OK (LiteLLM, n8n, wg-easy)
- âœ… Websites: 9/10 OK
- âœ… HEARTBEAT_OK

---

*Ãšltima atualizaÃ§Ã£o: 2026-04-13 02:08 UTC-03*
