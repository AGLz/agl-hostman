# OpenClaw Monitoramento e Alertas

> **Last Updated**: 2026-04-13 13:40 UTC-03 | **Status**: ✅ All operational

## Script de Monitoramento

**Local:** `config/openclaw/scripts/monitor-openclaw.sh`

### Uso

```bash
# Verificar status
bash config/openclaw/scripts/monitor-openclaw.sh

# Verificar + enviar alerta Telegram se houver erros
bash config/openclaw/scripts/monitor-openclaw.sh --telegram
```

### Checks Realizados

| # | Check | Status | Detalhe |
|---|-------|--------|---------|
| 1 | Container Health | ✅ | Docker health check |
| 2 | LiteLLM | ✅ | Chat completions via 192.168.32.3:4000 |
| 3 | Gateway | ✅ | HTTP /healthz endpoint |
| 4 | Telegram | ✅ | Bot @Jarvis3b3Bot conectado |
| 5 | Cron Jobs | ✅ | 6/6 jobs sem erros |
| 6 | Log Errors | ⚠️ | Erros não-críticos (nodes/AGLSRV1) |
| 7 | Docker CLI | ✅ | Socket mount funcionando |
| 8 | Memory | ✅ | ~800MB (limite: 4GB) |

### Alertas Telegram

**Configuração:**
- Bot: `@Jarvis3b3Bot`
- Token: `8526208493:AAHMux0VLVq8Qsr1-xOy8ReK3XGyoCnJmcg`
- Chat ID: `1272190248`

**Quando dispara:**
- Apenas quando há **erros** (não warnings)
- Envia resumo com status de todos os 8 checks
- Inclui lista de erros e warnings

**Exemplo de alerta:**
```
🚨 OpenClaw Alert

2026-04-13 13:40 UTC-03

Status:
• Container: ✅ healthy
• LiteLLM: ✅ OK
• Gateway: ✅ OK
• Telegram: ✅ @Jarvis3b3Bot
• Cron: 6 jobs, 0 errors

Errors (1):
• Container not running
```

## Agendamento com Cron do OpenClaw

Para adicionar monitoramento automático como cron job do OpenClaw:

```bash
# Adicionar job que roda a cada 15 minutos e envia alerta se houver erro
docker exec openclaw-repo-openclaw-gateway-1 bash -c '
cd /home/node/.openclaw
python3 -c "
import json
jobs = json.load(open(\"cron/jobs.json\"))
jobs[\"jobs\"].append({
    \"id\": \"openclaw-monitor\",
    \"name\": \"openclaw-monitor\",
    \"enabled\": True,
    \"schedule\": {\"kind\": \"every\", \"everyMs\": 900000},
    \"payload\": {
        \"message\": \"Run bash /path/to/monitor-openclaw.sh --telegram and report status\"
    },
    \"state\": {}
})
json.dump(jobs, open(\"cron/jobs.json\", \"w\"), indent=2)
"
'
```

## Erros Conhecidos (Não-Críticos)

### 1. `nodes failed: agent=main node=AGLSRV1 gateway=default action=location_geo`
- **Causa:** Skill tentando acessar dados de localização do AGLSRV1
- **Impacto:** Nenhum - é um tool failure isolado
- **Ação:** Nenhuma necessária, pode ser ignorado

### 2. `read failed: ENOENT: no such file or directory, access '/home/node/.openclaw/workspace/memory/heartbeat-state.json'`
- **Causa:** Arquivo heartbeat não existia (já criado)
- **Status:** ✅ Resolvido - arquivo criado
- **Ação:** Nenhuma necessária

### 3. `gateway.controlUi.dangerouslyAllowHostHeaderOriginFallback=true`
- **Causa:** Configuração necessária para acesso WebUI via container
- **Impacto:** Security warning informativo
- **Ação:** Aceito como necessário para operação

### 4. `bonjour watchdog detected non-announced service`
- **Causa:** mDNS/Bonjour não funciona bem em Docker
- **Impacto:** Nenhum - é apenas um warning
- **Ação:** Pode ser ignorado

### 5. LiteLLM 401 em `/health` (sem auth)
- **Causa:** Docker healthcheck usa `/health/readiness` (que funciona), mas alguns scanners internos batem `/health` sem auth
- **Impacto:** Nenhum - logs only
- **Ação:** Pode ser ignorado

## Comandos Úteis

```bash
# Monitoramento rápido
bash /mnt/overpower/apps/dev/agl/openclaw-repo/config/openclaw/scripts/monitor-openclaw.sh

# Monitoramento com alerta Telegram
bash /mnt/overpower/apps/dev/agl/openclaw-repo/config/openclaw/scripts/monitor-openclaw.sh --telegram

# Ver logs em tempo real
docker logs -f openclaw-repo-openclaw-gateway-1

# Ver apenas erros
docker logs openclaw-repo-openclaw-gateway-1 2>&1 | grep -i error

# Verificar cron jobs
docker exec openclaw-repo-openclaw-gateway-1 openclaw cron list

# Enviar mensagem teste via Telegram
curl -s -X POST "https://api.telegram.org/bot8526208493:AAHMux0VLVq8Qsr1-xOy8ReK3XGyoCnJmcg/sendMessage" \
    -H "Content-Type: application/json" \
    -d '{"chat_id":1272190248,"text":"Test message","parse_mode":"Markdown"}'
```

---

*Monitoramento ativo: 2026-04-13 13:40 UTC-03*
