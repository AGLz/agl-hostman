# OpenClaw Docker Migration — 2026-04-13

## Resumo

OpenClaw migrado do host (systemd) para container Docker, com integração LiteLLM e Telegram funcionando.

## Problemas Resolvidos

### 1. Networking Docker
**Problema:** OpenClaw e LiteLLM estavam em redes Docker diferentes, sem comunicação.
**Solução:** Conectar o container OpenClaw à rede `litellm_litellm-net`:
```bash
docker network connect litellm_litellm-net openclaw-repo-openclaw-gateway-1
```

### 2. Provider Configuration
**Problema:** Provider apontava para 127.0.0.1:4000 (não acessível do container).
**Solução:** Configurar para usar o IP do LiteLLM na rede compartilhada:
```json
{
  "baseUrl": "http://192.168.32.3:4000",
  "apiKey": "sk-litellm-8fd0003fd1a3883e7d6308c60cb5eed3ac4680832e801ded90e1873ce4dfe1a0",
  "api": "openai-completions",
  "models": []
}
```

### 3. Config Validation Errors
**Problemas encontrados:**
- `channels.telegram.streaming`: "partial" não é válido → mudar para `true`
- `agents.defaults.tools`: chave não reconhecida → remover
- `models.providers.openai.models`: obrigatório ser array → adicionar `[]`
- `models.providers.openai.api`: obrigatório → adicionar `"openai-completions"`

### 4. Telegram Bot Token
**Token encontrado em:** `/root/.openclaw/openclaw.json.backup`
```
8011672931:AAHncB9gYDsj61ODli8xzz4mOW3RiBeQtR8
```
**Bot:** @JarvisWK45_bot

### 5. Host Process Cleanup
**Problema:** Processos openclaw-gateway órfãos no host consumindo memória.
**Solução:**
```bash
systemctl --user stop openclaw-gateway
systemctl --user disable openclaw-gateway
# Kill any remaining
ps aux | grep openclaw | grep -v grep | grep -v docker | awk '{print $2}' | xargs -r kill -9
```

### 6. Cron Jobs Paths
**Problema:** Paths `/root/.openclaw/` e `127.0.0.1:4000` não funcionam no container.
**Solução:** Substituir por `/home/node/.openclaw/` e `http://192.168.32.3:4000`.

## Configuração Final

### Container
- **Nome:** `openclaw-repo-openclaw-gateway-1`
- **Status:** healthy
- **Portas:** 28789 (gateway), 28790 (bridge)
- **Memória:** ~630MB
- **Rede:** `openclaw-repo_default` (172.30.0.2) + `litellm_litellm-net` (192.168.32.4)

### LiteLLM
- **Container:** `litellm-proxy`
- **IP interno:** 192.168.32.3
- **Rede:** `litellm_litellm-net`
- **Status:** healthy

### Cron Jobs
| Job | Schedule | Status |
|-----|----------|--------|
| critical-services-monitor | every 5m | ok |
| websites-monitor | every 15m | ok |
| morning-briefing | every 8h | ok |
| daily-maintenance | every 1d | ok |
| daily-backup | every 1d | ok |
| nightly-proactive-task | every 1d | ok |

### Arquivos Modificados
- `/mnt/overpower/apps/dev/agl/openclaw-repo/.env`
- `/mnt/overpower/apps/dev/agl/openclaw-repo/docker-compose.yml`
- `/mnt/overpower/apps/dev/agl/openclaw-repo/config/openclaw.json`
- `/mnt/overpower/apps/dev/agl/openclaw-repo/config/cron/jobs.json`

## Comandos Úteis

```bash
# Check container status
docker ps --format '{{.Names}} {{.Status}}' | grep openclaw

# View logs
docker logs openclaw-repo-openclaw-gateway-1 --tail=30

# List cron jobs
docker exec openclaw-repo-openclaw-gateway-1 openclaw cron list

# Health check
curl -s http://127.0.0.1:28789/healthz

# Restart container
cd /mnt/overpower/apps/dev/agl/openclaw-repo && docker compose restart

# Connect to LiteLLM network (if needed)
docker network connect litellm_litellm-net openclaw-repo-openclaw-gateway-1
```

## Host Status
- **systemd openclaw-gateway:** disabled ✅
- **Host processes:** 0 ✅
- **All services running in Docker** ✅

## Scripts Criados
- `scripts/openclaw/validate-openclaw-docker.sh` — Validação completa (23 checks)
- `scripts/openclaw/health-vs-schedules.sh` — Gateway health vs cron schedules alignment

## Arquivos Marcados como DEPRECATED
- `config/openclaw/openclaw-gateway.service.d-env.conf`
- `config/openclaw/zshrc-openclaw.env`
- `config/openclaw/zshrc-openclaw-direct.env`
- `config/openclaw/zshrc-openclaw-litellm.env`

---

## Validação Final (2026-04-13 10:31 UTC-03)

### Validation Script Results
```
✅ Pass: 23
❌ Fail: 0
⚠️  Warn: 1 (websites-monitor was running at check time)
STATUS: ⚠️  WARNINGS (all checks passed)
```

### Health vs Schedules Results
```
✅ Pass: 5
❌ Fail: 0
⚠️  Warn: 0
STATUS: ✅ ALL GOOD
```

### Checks Validated
| Category | Check | Result |
|----------|-------|--------|
| Container Health | openclaw-repo-openclaw-gateway-1 | ✅ healthy |
| Container Health | litellm-proxy | ✅ healthy |
| Network | LiteLLM network connected | ✅ |
| Network | LiteLLM chat completions | ✅ OK |
| Gateway | /healthz endpoint | ✅ OK |
| Config | File exists + valid JSON | ✅ |
| Config | Provider URL (192.168.32.3:4000) | ✅ |
| Config | Primary model (openai/qwen3.5-flash) | ✅ |
| Config | Telegram enabled | ✅ |
| Telegram | Bot connected (@JarvisWK45_bot) | ✅ |
| Models | Primary model responds | ✅ |
| Cron | 6/6 jobs ok | ✅ |
| Schedule | All intervals match expected | ✅ |
| LiteLLM | 72 models available | ✅ |
| LiteLLM | qwen3.5-flash in model list | ✅ |
| Fallback | qwen-flash responds | ✅ |

---

*Fix aplicado: 2026-04-13 09:20 UTC-03*
*Validação final: 2026-04-13 10:43 UTC-03*

---

## Fix 2: Telegram Bot Corrigido (2026-04-13 11:03 UTC-03)

### Problema
O bot estava configurado como @JarvisWK45_bot, mas o bot correto do host é **@Jarvis3b3Bot**.

### Token
```
8526208493:AAHMux0VLVq8Qsr1-xOy8ReK3XGyoCnJmcg
```

### Alterações
- `.env`: TELEGRAM_BOT_TOKEN atualizado
- `dmPolicy`: `pairing` → `open` (sem necessidade de pairing)
- `groupPolicy`: `allowlist` → `open`
- `allowFrom`: `["*"]` (obrigatório para política open)

## Fix 3: Docker Network Persistente (2026-04-13 11:21 UTC-03)

### Problema
`docker compose down/up` removia a conexão com a rede `litellm_litellm-net`, causando timeout no LiteLLM.

### Solução
Adicionado ao `docker-compose.yml`:
```yaml
networks:
  default:
    driver: bridge
  litellm_litellm-net:
    external: true
```

## Endpoints

### WebUI
- **Local:** http://127.0.0.1:28789/?token=e74cbe3eba5ed049ca0c0a5807a0414ce97f8270a77a0962
- **Tailscale:** http://100.94.221.87:28789/?token=e74cbe3eba5ed049ca0c0a5807a0414ce97f8270a77a0962

### Telegram
- Bot: @Jarvis3b3Bot
- Chat ID do operador: 1272190248

---

*Fix Telegram: 2026-04-13 11:03 UTC-03*
*Fix Network: 2026-04-13 11:21 UTC-03*

---

## Migration Completa: Agents, Skills, Workspaces, Memories (2026-04-13 12:07-12:13 UTC-03)

### Dados Migrados do Host → Container

| Item | Host Path | Container Path | Count/Size |
|------|-----------|----------------|------------|
| **Agents** | `/root/.openclaw/agents/` | `/home/node/.openclaw/agents/` | 16 agents |
| **Skills** | `workspace/skills/` | `workspace/skills/` | 101 skills |
| **Workspaces** | `workspace-*` (33 dirs) | `workspace-*` (via volume mounts) | 34 total |
| **Memory DB** | `memory/main.sqlite` | `memory/main.sqlite` + `workspace/memory/` | 69KB |
| **Memory Files** | `workspace/memory/*.md` | `workspace/memory/*.md` | 10 files |
| **Tasks DB** | `tasks/runs.sqlite` | `tasks/runs.sqlite` | 896 runs |
| **Flows DB** | `flows/registry.sqlite` | `flows/registry.sqlite` | 24KB |
| **Sessions** | `agents/*/sessions/` | `agents/*/sessions/` | 217 total |
| **Subagents** | `subagents/` | `subagents/` | copied |
| **Credentials** | `credentials/` | `credentials/` | copied |
| **Secrets** | `secrets/` | `secrets/` | copied |
| **Telegram** | `telegram/` | `telegram/` | copied |
| **Memory MDs** | workspace AGENTS.md, MEMORY.md, etc. | workspace/ | 26 files |

### Agents Configurados

| Agent | Workspace | Modelo Primário |
|-------|-----------|-----------------|
| main | ~/.openclaw/workspace | openai/qwen3.5-flash |
| altman | ~/.openclaw/workspace-altman | openai/gpt-5.3-chat-latest |
| bezos | ~/.openclaw/workspace-bezos | openai/qwen3.5-flash |
| dean | ~/.openclaw/workspace-dean | openai/qwen3.5-flash |
| gates | ~/.openclaw/workspace-gates | openai/qwen3.5-flash |
| hassabis | ~/.openclaw/workspace-hassabis | openai/qwen3.5-flash |
| hinton | ~/.openclaw/workspace-hinton | openai/qwen3.5-flash |
| karpathy | ~/.openclaw/workspace-karpathy | openai/qwen3.5-flash |
| li | ~/.openclaw/workspace-li | openai/qwen3.5-flash |
| musk | ~/.openclaw/workspace-musk | openai/qwen3.5-flash |
| nadella | ~/.openclaw/workspace-nadella | openai/qwen3.5-flash |
| norvig | ~/.openclaw/workspace-norvig | openai/qwen3.5-flash |
| ogilvy | ~/.openclaw/workspace-ogilvy | openai/qwen3.5-flash |
| pichai | ~/.openclaw/workspace-pichai | openai/qwen3.5-flash |
| cheskin | ~/.openclaw/workspace-cheskin | openai/qwen3.5-flash |
| cto | ~/.openclaw/workspace-cto | openai/qwen3.5-flash |

### Notas
- **docker-compose.yml** atualizado com 33 workspace mounts + litellm network
- **openclaw.json** com `agents.list` contendo todos os 16 agents
- Tasks/Flows DBs copiados (896 task runs de histórico, registry de flows)
- Memory main.sqlite copiada para ambos `memory/` e `workspace/memory/`
- Host systemd service: **disabled** (não será mais usado)

---

*Migration completa: 2026-04-13 12:13 UTC-03*
