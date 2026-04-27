# Jarvis Operations - Runbook

## Overview

**Purpose**: Manage and troubleshoot Jarvis (OpenClaw AI Butler) operations.

**Maintainer**: Sr.Big + Jarvis (self-documenting)

**Last Updated**: 2026-04-12

---

## Arquitetura (2026-04): monitorização vs AGLWK45

| Papel | Host | Notas |
|-------|------|--------|
| **Monitorização HTTP / AI stack / alertas** | **agldv03** (CT179, `100.94.221.87`) | Schedulers OpenClaw (`openclaw cron`) e/ou systemd/cron Linux; scripts em `scripts/monitoring/` no repo |
| **openclaw.json alinhado** | Satélites: agldv04, agldv05, agldv07, agldv12, fgsrv06, aglwk45 | `propagate-openclaw-from-agldv03.sh` (+ **`AGLWK45_VIA_AGLSRV1=1`** para VM104 via **SSH AGLSRV1** + **qemu guest agent**); **não** copia `~/.openclaw/cron/` |
| **AGLWK45** | VM104 Windows | OpenClaw para **outras finalidades** (sem replicar os jobs de monitorização do agldv03); manter schedulers locais próprios |

Sincronizar só a **config** (modelos, canais, políticas) desde agldv03: `bash scripts/openclaw/propagate-openclaw-from-agldv03.sh` (`DRY_RUN=1` para listar destinos). **aglwk45** requer passo manual (ver final desse script).

---

## Jarvis Configuration

### Host Details
| Setting | Value |
|---------|-------|
| **VM** | AGLWK45 (VM104 no AGLSRV1) |
| **OS** | Windows 11 |
| **Resources** | 32GB RAM, 24 Cores |
| **Tailscale IP** | 100.117.146.21 |
| **LAN IP** | 192.168.0.245 |
| **Workspace** | C:\Users\Administrator\.openclaw\workspace |
| **Clawd** | C:\Users\Administrator\clawd |

### OpenClaw Configuration
| File | Purpose |
|------|---------|
| `C:\Users\Administrator\.openclaw\openclaw.json` | Main configuration |
| `C:\Users\Administrator\.openclaw\cron\jobs.json` | Schedulers **locais** da VM104 (não substituir pelos do agldv03) |
| `C:\Users\Administrator\.openclaw\workspace\` | Agent workspace |

### Model Configuration
- **Primary**: zai/glm-5 (via LiteLLM 100.94.221.87:4000)
- **Fallbacks**: claude-sonnet, kimi-k2.5, deepseek, openai/gpt-5.3-chat-latest (LiteLLM → gpt-5.4-mini), gemini
- **Local Ollama**: 192.168.0.200:11434/v1 (CT200 GPU)

---

## Monitoring (agldv03 — canónico)

Os monitores **não** correm na AGLWK45; correm no **agldv03** (CT179). OpenClaw nesse host: `openclaw cron` e `~/.openclaw/cron/jobs.json` **só aqui** para jobs de infra.

### Referência de endpoints HTTP

- **`config/monitoring/jarvis-openclaw-http-endpoints.example.json`** — URLs, anti-flood, erros comuns (**100.72.240.65** = cloudflared7).

### HTTP checks canónicos (evitar falsos positivos)

| Serviço | ❌ Erro comum | ✅ URL preferido (desde agldv03 / LAN AGL) | Fallback |
|---------|----------------|--------------------------------------------|----------|
| **n8n** (CT202) | `http://100.72.240.65:5679/...` | `http://192.168.0.202:5678/healthz` | Confirmar porta no CT202 |
| **wg-easy** (FGSRV6) | Check em **100.72.240.65:51821** | `http://10.6.0.5:51821/` | `http://100.83.51.9:51821/` |
| **LiteLLM** | — | `http://127.0.0.1:4000/health/readiness` (no CT179) ou `http://100.94.221.87:4000/...` | `http://192.168.0.179:4000/...` |

**100.72.240.65** = **`fgsrv07-cloudflared7`** — não usar para n8n/wg-easy.

**Boas práticas:** uma URL primária por serviço; anti-flapping — ver `antiFlapping` no JSON exemplo.

### Job Management (Linux, agldv03)
```bash
ssh root@100.94.221.87
openclaw cron list
openclaw cron run --name "<nome>"
```

### Legado Windows (AGLWK45)

`websites-monitor-final.ps1` no workspace Windows é **legado** se os mesmos checks já existirem no agldv03 — evitar **dois** emissores Telegram.

### Job Management (Windows — schedulers locais VM104)
```bash
# List all cron jobs
openclaw cron list

# Add new job
openclaw cron add --name "job-name" --schedule "*/15 * * * *" --command "script.ps1"

# Run job immediately
openclaw cron run --name "job-name"

# Remove job
openclaw cron remove --name "job-name"
```

---

## Common Issues & Resolution

### Issue 1: Jarvis Not Responding

**Symptoms**:
- No response to Telegram messages
- Cron jobs not running
- Gateway not accessible

**Diagnosis**:
```powershell
# Check OpenClaw service
Get-Service openclaw*

# Check gateway
Invoke-WebRequest -Uri "http://localhost:18789/health" -UseBasicParsing

# Check logs
Get-Content "C:\Users\Administrator\.openclaw\logs\*.log" -Tail 50
```

**Resolution**:
```powershell
# Restart OpenClaw
openclaw gateway restart

# Or restart service
Restart-Service openclaw

# Check status
openclaw status
```

### Issue 2: Cron Jobs Not Running

**Symptoms**:
- Scheduled jobs not executing
- No logs in cron directory
- Jobs disabled

**Diagnosis**:
```powershell
# Check cron jobs
Get-Content "C:\Users\Administrator\.openclaw\cron\jobs.json" | ConvertFrom-Json

# Check cron service
Get-ScheduledTask -TaskName "*openclaw*" | Select-Object TaskName, State, LastRunTime
```

**Resolution**:
```powershell
# Enable all jobs
openclaw cron list | ForEach-Object { openclaw cron update --name $_.name --enabled true }

# Run test job
openclaw cron run --name "websites-monitor"

# Check logs
Get-Content "C:\Users\Administrator\.openclaw\cron\logs\*.log" -Tail 100
```

### Issue 3: Flood de alertas Telegram (monitor HTTP)

**Sintomas**: mensagens repetidas com `TIMEOUT/UNREACHABLE` para n8n ou wg-easy em **100.72.240.65**.

**Causa**: IP é o Tailscale do **cloudflared7** (FGSRV7), não o host dos serviços.

**Resolução**: no **agldv03**, atualizar o job/script de monitorização com os URLs em `config/monitoring/jarvis-openclaw-http-endpoints.example.json`; aplicar limiar de falhas consecutivas antes de enviar Telegram. Na AGLWK45, remover ou desativar checks duplicados.

### Issue 4: Model Connection Issues

**Symptoms**:
- "Model not available" errors
- Slow responses
- LiteLLM gateway down

**Diagnosis**:
```powershell
# Check LiteLLM
Invoke-WebRequest -Uri "http://100.94.221.87:4000/v1/models" -UseBasicParsing

# Check Ollama
Invoke-WebRequest -Uri "http://192.168.0.200:11434/api/tags" -UseBasicParsing

# Test model directly
openclaw session_status
```

**Resolution**:
```powershell
# Switch to fallback model
openclaw session_status --model "claude-sonnet"

# Check network connectivity
ping -n 1 100.94.221.87
ping -n 1 192.168.0.200

# Restart LiteLLM if needed (from agldv03)
ssh root@192.168.0.245 "pct exec 179 -- systemctl restart litellm"
```

### Issue 5: Memory/Performance Issues

**Symptoms**:
- Slow responses
- High memory usage
- Agent crashes

**Diagnosis**:
```powershell
# Check memory usage
Get-Process | Where-Object { $_.Name -like "*node*" -or $_.Name -like "*openclaw*" } | Select-Object Name, CPU, WorkingSet

# Check disk space
Get-PSDrive C | Select-Object Used, Free

# Check logs for OOM errors
Get-Content "C:\Users\Administrator\.openclaw\logs\*.log" | Select-String "memory|OOM|crash"
```

**Resolution**:
```powershell
# Clear workspace cache
Remove-Item "C:\Users\Administrator\.openclaw\workspace\temp\*" -Recurse -Force

# Restart with memory limit
openclaw gateway restart --memory-limit 4096

# Monitor performance
openclaw session_status
```

---

## Daily Operations

### Morning Briefing
**Time**: 08:00 local (GMT-3) — job no **agldv03** (não na VM104)

**Checks**:
1. Host connectivity (AGLSRV1, AGLDV03, FGSRV6, AGLSRV6)
2. Services health (LiteLLM, n8n, wg-easy)
3. Websites monitor status
4. Storage alerts
5. AI stack status

**Command**: `openclaw cron run --name "morning-briefing"` (no agldv03) ou equivalente agendado nesse host

### Daily Memory Logging
**Purpose**: Track all work sessions

**Auto-logging**:
```bash
# Jarvis creates log after each session
POST http://localhost:8000/api/daily-memory
Headers: X-API-Key: dev
Body: {
  "occurred_on": "2026-03-23",
  "title": "Session title",
  "summary": "Discussion summary...",
  "topics": ["infra", "monitoring"],
  "project_tags": ["agl-hostman"]
}
```

**Manual access**: `http://localhost:8000/daily-memory`

### Health Monitoring
**Local canónico (agldv03)** — intervalos orientativos; ver `~/.openclaw/cron/jobs.json` nesse CT:
- Websites / HTTP: vários endpoints (ex. 15 min)
- Hosts: ping periódico
- Storage / AI stack: LiteLLM, n8n, wg-easy (ex. 1 h)

**Alerts**: Telegram a partir dos jobs no **agldv03**; evitar o mesmo fluxo na AGLWK45.

---

## Backup & Recovery

### Configuration Backup
```powershell
# Backup OpenClaw config
Copy-Item "C:\Users\Administrator\.openclaw\openclaw.json" "U:\backups\openclaw\config-$(Get-Date -Format 'yyyy-MM-dd').json"

# Backup cron jobs
Copy-Item "C:\Users\Administrator\.openclaw\cron\jobs.json" "U:\backups\openclaw\cron-$(Get-Date -Format 'yyyy-MM-dd').json"

# Backup workspace
Compress-Archive -Path "C:\Users\Administrator\.openclaw\workspace\*" -DestinationPath "U:\backups\openclaw\workspace-$(Get-Date -Format 'yyyy-MM-dd').zip"
```

### Recovery Procedures
**Full recovery**:
```powershell
# Restore config
Copy-Item "U:\backups\openclaw\config-latest.json" "C:\Users\Administrator\.openclaw\openclaw.json"

# Restore cron jobs
Copy-Item "U:\backups\openclaw\cron-latest.json" "C:\Users\Administrator\.openclaw\cron\jobs.json"

# Restore workspace
Expand-Archive -Path "U:\backups\openclaw\workspace-latest.zip" -DestinationPath "C:\Users\Administrator\.openclaw\workspace\" -Force

# Restart OpenClaw
openclaw gateway restart
```

**Partial recovery**:
```powershell
# Restore only memory files
Copy-Item "U:\backups\openclaw\workspace\memory\*" "C:\Users\Administrator\.openclaw\workspace\memory\" -Recurse -Force

# Restore identity
Copy-Item "U:\backups\openclaw\workspace\IDENTITY.md" "C:\Users\Administrator\.openclaw\workspace\IDENTITY.md"
Copy-Item "U:\backups\openclaw\workspace\USER.md" "C:\Users\Administrator\.openclaw\workspace\USER.md"
```

---

## Security

### Access Control
- **Telegram**: Allowlist only (1272190248)
- **Gateway**: Local loopback only (127.0.0.1:18789)
- **API Keys**: Stored in environment variables
- **Workspace**: User-specific, not shared

### API Security
```bash
# Daily Memory API requires API key
curl -X POST http://localhost:8000/api/daily-memory \
  -H "X-API-Key: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"title": "Test"}'
```

**Valid keys**: From env `API_KEY` or `API_KEYS` (comma-separated)

### Audit Logging
```powershell
# Check OpenClaw logs
Get-Content "C:\Users\Administrator\.openclaw\logs\gateway.log" -Tail 100

# Check cron logs
Get-Content "C:\Users\Administrator\.openclaw\cron\logs\*.log" -Tail 100

# Check Telegram interactions
Get-Content "C:\Users\Administrator\.openclaw\telegram\*.log" -Tail 100
```

---

## Integration Points

### agl-hostman Integration
- **Daily Memory API**: `POST /api/daily-memory`
- **Monitoring**: Shares scripts from `scripts/monitoring/`
- **Documentation**: Updates `docs/INFRA.md`

### LiteLLM Integration
- **Gateway**: http://100.94.221.87:4000
- **Models**: All major providers via proxy
- **Local models**: Ollama on CT200

### Telegram Integration
- **Bot**: @OpenClawBot
- **Channels**: Direct messages only
- **Notifications**: Cron job failures, health alerts

### Multi-Agent Coordination
```bash
# Spawn subagent for parallel work
openclaw sessions_spawn --runtime "subagent" --agentId "infra" --task "Check storage health"

# List active agents
openclaw subagents list

# Send message to agent
openclaw sessions_send --sessionKey "agent:infra:main" --message "Check ZFS pools"
```

---

## Performance Tuning

### Memory Optimization
```json
{
  "agents": {
    "defaults": {
      "compaction": {
        "mode": "safeguard"
      },
      "maxConcurrent": 4,
      "subagents": {
        "maxConcurrent": 8
      }
    }
  }
}
```

### Model Selection
**Priority order**:
1. zai/glm-5 (primary)
2. anthropic/claude-sonnet-4-6
3. moonshot/kimi-k2.5
4. deepseek/deepseek-chat
5. openai/gpt-5.3-chat-latest (gateway → gpt-5.4-mini)

**Fast models for monitoring**:
- zai/glm-4.7-flash
- google/gemini-2.5-flash-lite

### Workspace Management
```powershell
# Clean old memory files
Get-ChildItem "C:\Users\Administrator\.openclaw\workspace\memory\*.md" | 
  Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } |
  Remove-Item

# Archive completed tasks
Get-ChildItem "C:\Users\Administrator\.openclaw\workspace\*.md" |
  Where-Object { $_.Name -notin @("IDENTITY.md", "USER.md", "SOUL.md") } |
  Move-Item -Destination "C:\Users\Administrator\.openclaw\archive\"
```

---

## Escalation Procedures

### Level 1: Self-healing
- Automatic model fallback
- Job retry with exponential backoff
- Workspace cleanup

### Level 2: Manual intervention
- Restart OpenClaw service
- Check network connectivity
- Verify model availability

### Level 3: Sr.Big intervention
- VM restart (AGLWK45)
- LiteLLM service restart
- Configuration restore

### Level 4: Infrastructure team
- Proxmox host issues (AGLSRV1)
- Network infrastructure
- Storage failures

---

## Related Runbooks

- [Service Down](./service-down.md)
- [High Error Rate](./high-error-rate.md)
- [Database Issues](./database-issues.md)
- [Storage Alerts](./storage-alerts.md)

---

## Change Log

### 2026-03-23 - Initial Version
- Created by Jarvis (self-documenting)
- Added all current configurations
- Documented monitoring jobs
- Added integration points

### Future Updates
- Auto-update by Jarvis after configuration changes
- Version tracking in daily memory system
- Regular review by Sr.Big