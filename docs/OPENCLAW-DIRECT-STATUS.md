# Status: OpenClaw com Acesso Direto aos Providers

## 📅 Última Atualização: 2026-03-28 11:20 UTC

## ✅ Status Atual (OpenRouter Primary) - RESOLVIDO

### agldv03 (100.94.221.87) - ✅ OPERACIONAL
- **Gateway**: ✅ Rodando (porta 18789)
- **OpenRouter Primary**: ✅ Funcionando
- **Versão OpenClaw**: 2026.2.19 (downgrade de 2026.3.13)
- **Modelo primário**: `openrouter/meta-llama/llama-3.3-70b-instruct:free`
- **Teste**: ✅ "Okay, I see your test."
- **Conclusão**: **OPERACIONAL**

### fgsrv06 (100.83.51.9) - ✅ RESOLVIDO (Downgrade)
- **Gateway**: ✅ Rodando
- **OpenRouter**: ✅ Autenticação funcionando (downgrade para 2026.2.19)
- **Versão OpenClaw**: 2026.2.19 (downgrade de 2026.3.13)
- **Variável de ambiente**: ✅ Carregada no processo
- **Status**: Alguns modelos com rate limit 429 (upstream)
- **Conclusão**: **RESOLVIDO** - Bug era regressão na versão 2026.3.x

**Causa confirmada**:
- Bug de regressão no OpenClaw 2026.3.x (GitHub issue #34830)
- Solução: Downgrade para versão 2026.2.19

### aglwk45 - ❌ PENDENTE
- **Status**: QEMU Guest Agent não disponível
- **Ação necessária**: Iniciar qemu-guest-agent na VM

---

## 🔍 Diagnóstico

### Problema DashScope (401 Incorrect API key)

**Teste direto via curl (localhost)**: ✅ FUNCIONA
```bash
curl -X POST "https://dashscope-intl.aliyuncs.com/compatible-mode/v1/chat/completions" \
  -H "Authorization: Bearer sk-48f612bb16634018a21eec165e13f78a" \
  ...
# HTTP 200 - OK
```

**Teste via OpenClaw**: ❌ FALHA (401)
```
openai/qwen3.5-plus: HTTP 401: Incorrect API key provided
```

**Causa provável**: OpenClaw não está passando a API key corretamente para o provider.

### Verificações Realizadas

✅ Environment file existe: `~/.config/environment.d/openclaw.conf`
✅ Variáveis corretas no arquivo
✅ Variáveis carregadas no processo (verificado via `/proc/$PID/environ`)
✅ Config OpenClaw correta: `apiKey: "os.environ/DASHSCOPE_API_KEY"`
✅ Formato do environment file: `DASHSCOPE_API_KEY=sk-...` (sem export)

### Hipóteses

1. **OpenClaw bug**: Pode haver um bug na versão 2026.3.13 do OpenClaw ao ler variáveis de ambiente
2. **Encoding**: Algum problema com encoding das variáveis
3. **Timing**: Gateway pode estar lendo as variáveis antes do environment file ser carregado

---

## 📋 Próximos Passos

### Prioridade Alta

1. **Investigar fgsrv06**
   - Verificar por que OpenRouter também falha com 401
   - Comparar ambiente entre agldv03 e fgsrv06
   - Testar downgrade/upgrade do OpenClaw

2. **Contornar problema no agldv03**
   - **SOLUÇÃO TEMPORÁRIA**: Usar OpenRouter como primário
   - Configurar modelo primário: `openrouter/meta-llama/llama-3.3-70b-instruct:free`
   - DashScope pode ser reabilitado após investigação

### Prioridade Média

3. **Corrigir aglwk45**
   ```bash
   # Na VM aglwk45
   sudo systemctl start qemu-guest-agent
   sudo systemctl enable qemu-guest-agent
   ```

4. **Abrir issue no OpenClaw**
   - Documentar problema com `os.environ/VAR_NAME`
   - Incluir logs e diagnóstico

---

## 🔧 Configuração Atual

### agldv03 (~/.openclaw/openclaw.json)
```json
{
  "gateway": {
    "mode": "local",
    "port": 18789
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "openai/qwen3.5-plus",
        "fallbacks": [
          "openai/qwen-turbo",
          "openrouter/meta-llama/llama-3.3-70b-instruct:free",
          "openrouter/nvidia/nemotron-3-super-120b-a12b:free",
          "openrouter/minimax/minimax-m2.5:free"
        ]
      }
    }
  },
  "models": {
    "mode": "merge",
    "providers": {
      "openai": {
        "baseUrl": "https://dashscope-intl.aliyuncs.com/compatible-mode/v1",
        "api": "openai-completions",
        "apiKey": "os.environ/DASHSCOPE_API_KEY",
        "models": [
          {"id": "qwen3.5-plus", "name": "Qwen3.5 Plus (FREE)", ...},
          {"id": "qwen-turbo", "name": "Qwen Turbo (FREE)", ...}
        ]
      },
      "openrouter": {
        "baseUrl": "https://openrouter.ai/api/v1",
        "api": "openai-completions",
        "apiKey": "os.environ/OPENROUTER_API_KEY",
        "models": [...]
      }
    }
  }
}
```

### Environment File (~/.config/environment.d/openclaw.conf)
```
ZAI_API_KEY=896fb1e6936a4cd1b61aa2314d6d3728.u2lsAqLNfajAslfx
DASHSCOPE_API_KEY=sk-48f612bb16634018a21eec165e13f78a
OPENROUTER_API_KEY=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
```

---

## 📊 Resumo

| Host | Status | Primário | Fallback | Notas |
|------|--------|----------|----------|-------|
| agldv03 | ✅ OK | Qwen (❌ 401) | Nemotron (✅) | Funciona via fallback |
| fgsrv06 | ❌ FAIL | Qwen (❌ 401) | Todos (❌ 401) | Investigando |
| aglwk45 | ❌ PEND | - | - | QEMU GA indisponível |

**Custo atual**: **$0/mês** (todos modelos FREE)

---

## 🐛 Debug Commands

### Verificar environment carregado no processo
```bash
pid=$(systemctl --user show --property MainPID openclaw-gateway | cut -d= -f2)
cat /proc/$pid/environ | tr "\0" "\n" | grep -E "(ZAI|DASHSCOPE|OPENROUTER)_API_KEY"
```

### Testar provider diretamente (fora do OpenClaw)
```bash
source ~/.config/environment.d/openclaw.conf

# DashScope
curl -X POST "https://dashscope-intl.aliyuncs.com/compatible-mode/v1/chat/completions" \
  -H "Authorization: Bearer $DASHSCOPE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model": "qwen3.5-plus", "max_tokens": 10, "messages": [{"role": "user", "content": "test"}]}'

# OpenRouter
curl -X POST "https://openrouter.ai/api/v1/chat/completions" \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model": "meta-llama/llama-3.3-70b-instruct:free", "max_tokens": 10, "messages": [{"role": "user", "content": "test"}]}'
```

### Verificar logs do gateway
```bash
journalctl --user -u openclaw-gateway -f
```

### Reiniciar gateway
```bash
systemctl --user restart openclaw-gateway
```

---

## 📝 Notas

- **Importante**: DashScope API key **FUNCIONA** quando testada diretamente via curl
- **Importante**: O problema é específico de como OpenClaw lê/passa as API keys
- **Solução temporária**: Usar OpenRouter como primário no agldv03
- **Custo**: Todos os modelos são **GRATUITOS** ($0/mês)
