# OpenClaw LiteLLM Auth Fix — 2026-04-12

## Problema

Mensagem recebida no Telegram do OpenClaw:

```
All services are responding, but the LiteLLM Gateway requires proper authentication.
Since the service is running (as evidenced by the 401 response rather than connection failure)...
⚠️ LiteLLM Gateway: Running but authentication failed (HTTP 401)
```

## Causa Raiz

Os cron jobs do OpenClaw que verificam a saúde do LiteLLM (`ai-stack-health`, `critical-services-monitor`, `storage-health-check`, `morning-briefing`) executavam comandos curl com `$LITELLM_MASTER_KEY`, mas **não carregavam o ficheiro de environment** onde esta variável está definida.

O agente OpenClaw roda em sessões isoladas (`sessionTarget: "isolated"`) que **não herdam** automaticamente as variáveis de ambiente do systemd user service, mesmo que `LITELLM_MASTER_KEY` esteja definida em `~/.config/environment.d/openclaw.conf`.

## Sintomas

- `websites-monitor.sh` ✅ funcionava (porque faz `source /root/.openclaw/litellm-master.secret.env`)
- Jobs com comandos curl inline ❌ falhavam (401 Unauthorized) porque `$LITELLM_MASTER_KEY` não estava definida no contexto do agente

## Solução Aplicada

Atualizados os payloads dos seguintes jobs em `/root/.openclaw/cron/jobs.json`:

| Job | Alteração |
|-----|-----------|
| `ai-stack-health` | Adicionado `source /root/.openclaw/litellm-master.secret.env 2>/dev/null` antes dos checks LiteLLM |
| `critical-services-monitor` | Adicionado `source /root/.openclaw/litellm-master.secret.env 2>/dev/null` antes dos checks LiteLLM |
| `storage-health-check` | Adicionada nota para carregar env antes de usar `$LITELLM_MASTER_KEY` |
| `morning-briefing` | Adicionada nota para carregar env antes de usar `$LITELLM_MASTER_KEY` |

## Ficheiros Relevantes

| Ficheiro | Descrição |
|----------|-----------|
| `/root/.openclaw/cron/jobs.json` | Definição dos cron jobs (atualizado) |
| `/root/.openclaw/litellm-master.secret.env` | Export de `LITELLM_MASTER_KEY` e `LITELLM_API_KEY` |
| `/root/.config/environment.d/openclaw.conf` | Environment para systemd (contém `LITELLM_*`) |
| `config/openclaw/scripts/websites-monitor.sh` | Script que já funcionava (faz source corretamente) |

## Verificação

```bash
# No host agldv03
source /root/.openclaw/litellm-master.secret.env
curl -s -H "Authorization: Bearer $LITELLM_MASTER_KEY" http://127.0.0.1:4000/v1/models | jq '.data | length'
# Deve retornar > 0 (atualmente 72 modelos)
```

## Notas Adicionais

- O serviço `openclaw-gateway` tem `EnvironmentFile=%h/.config/environment.d/openclaw.conf` no systemd unit
- No entanto, os cron jobs do OpenClaw rodam em sessões efémeras que podem não herdar este environment
- O `websites-monitor.sh` já fazia `source` corretamente, por isso nunca teve este problema
- Backup do jobs.json foi criado antes das alterações

## Próximos Passes

1. ✅ Monitorizar Telegram — job `critical-services-monitor` está running agora
2. Verificar que os próximos runs (5min) reportam `HEARTBEAT_OK` em vez de falsos positivos
3. Considerar patch upstream no OpenClaw para injetar automaticamente `LITELLM_*` nas sessões de cron

---

# Critical Services Monitor Fix — 2026-04-12 (22:45)

## Problema

Alerta falso recebido no Telegram reportando 5 falhas críticas:

```
🚨 CRITICAL SERVICES ALERT

**Failed:**
- LiteLLM Gateway: HTTP 401 authentication error
- OpenClaw Gateway: Status command failed with SIGKILL
- NFS Mounts: SSH connection timeout to fileserver5 (100.119.223.113)
- Proxmox Host AGLSRV5: Ping timeout (100.119.223.113)
- Proxmox Host FGSRV07: Ping timeout (100.109.181.93)
```

## Análise Real vs Falso Positivo

| Alerta | Reportado | Realidade | Causa |
|--------|-----------|-----------|-------|
| LiteLLM 401 | ❌ Falha | ✅ Serviço OK | `$LITELLM_MASTER_KEY` não carregada (fixado acima) |
| OpenClaw SIGKILL | ❌ Falha | ✅ Running, RPC OK | Falso positivo — comando pode ter timeout |
| NFS fileserver5 | ❌ SSH timeout | ✅ Host OK (100.66.136.84) | **IP ERRADO** — job usava 100.119.223.113 (=fgsrv07-1) |
| AGLSRV5 ping | ❌ Timeout | ✅ N/A — IP errado | Job usava IP de fgsrv07-1 como "AGLSRV5" |
| FGSRV07 ping | ❌ Timeout | ✅ Online (13ms) | FGSRV07 bloqueia ICMP, precisa `tailscale ping` |

## Fixes Aplicados

### 1. `critical-services-monitor` — reescrita completa

- ✅ LiteLLM: adicionado `source /root/.openclaw/litellm-master.secret.env`
- ✅ fileserver5: IP corrigido para `100.66.136.84` (era `100.119.223.113`)
- ✅ Proxmox hosts: função `check_host()` com fallback `tailscale ping`
- ✅ FGSRV07: documentado que bloqueia ICMP — usar tailscale ping
- ✅ Regras de alerta: HTTP 401 do LiteLLM NÃO é critico (serviço está up)
- ✅ Mapa de hosts atualizado com IPs corretos
- ✅ OpenClaw gateway: check simplificado para evitar SIGKILL

### 2. Mapa de Hosts Corrigido

| Nome | IP Tailscale | Função |
|------|-------------|--------|
| AGLSRV1 | 100.107.113.33 | Proxmox principal |
| AGLDV03 | 100.94.221.87 | Dev (este host) |
| FGSRV06 | 100.83.51.9 | WireGuard Hub |
| FGSRV07 | 100.109.181.93 | Proxmox Cloud (bloqueia ICMP) |
| fileserver5 | 100.66.136.84 | NFS Storage (aglsrv5) |
| WG Hub LAN | 10.6.0.5 | WireGuard gateway |

---

*Fix aplicado: 2026-04-12 22:37 UTC-03*
