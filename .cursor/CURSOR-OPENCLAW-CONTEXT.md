# Cursor CLI + OpenClaw — Contexto AGL Infrastructure

> **Gerado**: 2026-04-06
> **Propósito**: Dar ao Cursor CLI e OpenClaw conhecimento completo da infra AGL

## Hosts AGL (Topologia)

| Host | Tipo | IP Tailscale | IP LAN | Função |
|------|------|-------------|--------|--------|
| **aglsrv1** | Proxmox | 100.107.113.33 | 192.168.0.245 | Host principal (VMs/CTs) |
| **agldv03** | Linux CT | 100.94.221.87 | - | OpenClaw gateway + LiteLLM |
| **fgsrv06** | VPS Locaweb | 100.83.51.9 | 186.202.57.120 | WireGuard hub |
| **aglwk45** | Windows 11 VM | 100.117.146.21 | 192.168.0.33 | Workstation (VM104 no aglsrv1) |

## Problemas Conhecidos e Resoluções

### AGLWK45 (VM104) — RDP Inacessível

**Causa raiz**: meshagent memory leak no AGLSRV1
- 30+ instâncias de meshagent no host
- 3 podem vazar 10-22GB RAM cada
- Impacto: host overload → rede colapsa → RDP cai

**Runbook de emergência** (executar no Cursor CLI ou OpenClaw):

```bash
# 1. Verificar VM
ssh root@100.107.113.33 'qm status 104 && qm agent 104 ping'

# 2. Verificar meshagents com leak
ssh root@100.107.113.33 'ps aux | grep meshagent | grep -v grep | awk "{if (\$6 > 1000000) print \"LEAK: PID \"\$2\" RSS \"int(\$6/1024)\"MB\"}"'

# 3. Se leak confirmado → matar + reboot
ssh root@100.107.113.33 'ps aux | grep meshagent | grep -v grep | awk "{if (\$6 > 1000000) print \$2}" | xargs -r kill -9'
ssh root@100.107.113.33 'qm stop 104 && sleep 3 && qm start 104'

# 4. Verificar recuperação
ssh root@100.107.113.33 'qm agent 104 ping && timeout 3 bash -c "cat < /dev/null > /dev/tcp/192.168.0.33/3389" && echo RDP_OK'
```

### AGLSRV1 — Monitorização

**Thresholds de alerta**:
- Load Average > 30 (24 cores) = investigar
- RAM disponível < 10GB = limpar
- meshagent RSS > 1GB = kill imediato
- Swap > 70GB = crítico

## OpenClaw Configuração

### Gateway LiteLLM
- **agldv03**: LiteLLM principal (porta 4000)
- **aglwk45**: Usa gateway remoto do agldv03
- Modelo default: `zai/glm-5`

### Agentes OpenClaw (personas)
11 personas configuradas em `~/.openclaw/agents/`:
- `main` — Primary agent
- `altman`, `bezos`, `dean`, `gates`, `hassabis`, `hinton`, `karpathy`, `musk`, `nadella`, `pichai`

### Canais
- **Telegram**: configurado (bot token em openclaw.json)
- **Voice wake**: trigger "openclaw"

## MCP Servers (25 configurados no Cursor)

**Críticos para infra**:
- `proxmox` — VM/CT management
- `docker` — Containers
- `portainer` — Container orchestration
- `cloudflare-dns` — DNS management
- `github` — Repository operations

**Orquestração**:
- `claude-flow` — Multi-agent orchestration
- `archon` — Project management (local + tailscale)
- `ruv-swarm` — Swarm coordination
- `flow-nexus` — Orchestration platform

**Dados/Docs**:
- `context7` — Library docs
- `memory` — Knowledge graph
- `web-reader` — Web extraction
- `web-search-prime` — Web search

## Scripts de Verificação

| Script | Função |
|--------|--------|
| `scripts/verify-aglwk45-fgsrv06.sh` | Check VM104 + fgsrv06 |
| `scripts/verify-openclaw-aglwk45.sh` | OpenClaw status (bash) |
| `scripts/verify-openclaw-aglwk45.ps1` | OpenClaw status (PowerShell) |

## LiteLLM Config

**Proxy local**: `http://localhost:4000`
**Modelos Cursor**: `cursor-composer`, `cursor-composer-2-fast` → `openai/gpt-5.3-chat-latest`
**Config**: `config/litellm/config.yaml`

## Documentação de Referência

| Ficheiro | Conteúdo |
|----------|----------|
| `docs/AGLWK45-SETUP.md` | Setup VM104 completo |
| `docs/AGLSRV1-TROUBLESHOOTING.md` | Playbook troubleshooting |
| `docs/aglsrv1-key-findings.md` | Histórico diagnósticos |
| `docs/INFRA.md` | Infraestrutura geral |
| `docs/OPENCLAW.md` | OpenClaw setup |
| `AGENTS.md` | Coordenação de agentes |
| `CLAUDE.md` | Contexto workspace |
