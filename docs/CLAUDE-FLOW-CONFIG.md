# Claude Flow / Ruflo / Claude Code — Config e Sync Multi-Host

> **Objetivo**: Mesmas configs em agldv03, agldv04, agldv12 e fgsrv06.  
> **Regra**: Cada host com LiteLLM local usa `localhost:4000`. Hosts sem LiteLLM usam override apontando para agldv03.

---

## 1. Checklist de verificação

### 1.1 Claude Code / settings.json

| Item | Esperado | Verificação |
|------|----------|-------------|
| `ANTHROPIC_BASE_URL` | `http://localhost:4000` | Cada host com LiteLLM local |
| `ANTHROPIC_AUTH_TOKEN` | `sk-litellm-default` ou `LITELLM_MASTER_KEY` | Via apiKeyHelper |
| `apiKeyHelper` | `.claude/helpers/get-litellm-key.sh` | Script retorna key de config ou /opt/litellm |
| `CLAUDE_FLOW_HOOKS_ENABLED` | `true` | Hooks route, pre-bash, post-edit ativos |
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | `1` | Agent teams habilitado |

### 1.2 Hooks (.claude/helpers)

| Hook | Handler | Função |
|------|---------|-------|
| UserPromptSubmit | `hook-handler.cjs route` | Roteia tarefa para agente ideal |
| PreToolUse (Bash) | `hook-handler.cjs pre-bash` | Valida comando antes de executar |
| PostToolUse (Write/Edit) | `hook-handler.cjs post-edit` | Registra edição para aprendizado |
| SessionStart | `hook-handler.cjs session-restore` + `auto-memory-hook.mjs import` | Restaura sessão e importa memória |
| SessionEnd | `hook-handler.cjs session-end` | Persiste estado |
| Stop | `auto-memory-hook.mjs sync` | Sincroniza memória |

### 1.3 Ruflo (config/ruflo)

| Arquivo | Conteúdo |
|---------|----------|
| `hive-mind.env` | Topologia, consenso, queen type |
| `ruvector.env` | Storage path, dimensions, index type |
| `background-workers.json` | Workers ultralearn, consolidate, etc. |

### 1.4 OpenClaw (config/openclaw)

| Arquivo | Uso |
|---------|-----|
| `zshrc-openclaw.env` | Variáveis LITELLM_GATEWAY_URL, ANTHROPIC_* para shell |
| `litellm-gateway-local.env` | Override para localhost:4000 |

---

## 2. Hosts e IPs

| Host | Tailscale IP | LiteLLM local | settings |
|------|--------------|---------------|----------|
| agldv03 | 100.94.221.87 | ✅ | settings.json (localhost:4000) |
| agldv04 | 100.113.9.98 | Opcional | settings.json ou settings.agldv04.json |
| agldv12 | 100.71.217.115 | Opcional | settings.json ou settings.agldv04.json |
| fgsrv06 | 100.83.51.9 | ✅ | settings.json (localhost:4000) |

**Override para hosts sem LiteLLM**: `cp .claude/settings.agldv04.json .claude/settings.json` (aponta para agldv03:4000).

---

## 3. Sync de config para todos os hosts

```bash
# Sync completo (agldv03, agldv04, agldv12, fgsrv06)
./scripts/ruflo/sync-config-all-hosts.sh

# Sync apenas hosts específicos
./scripts/ruflo/sync-config-all-hosts.sh agldv04 fgsrv06
```

**Arquivos replicados**:
- `.claude/settings.json`
- `.claude/plugins.json`
- `.claude/helpers/` (todo o diretório)
- `config/ruflo/`
- `config/openclaw/zshrc-openclaw.env`
- `scripts/ruflo/`

---

## 4. Deploy Ruflo completo (por host)

```bash
# Deploy em host específico (ex: agldv04)
./scripts/ruflo-deploy-agldv03.sh root@100.113.9.98

# Deploy local
./scripts/ruflo-deploy-agldv03.sh local
```

Passos executados: validate-ruflo → setup-ruvector → setup-background-workers → setup-hive-mind → setup-reasoningbank.

---

## 5. Ordem recomendada

1. **LiteLLM** em cada host: `./scripts/litellm/deploy-litellm-host.sh <host>`
2. **Sync config** Claude Flow: `./scripts/ruflo/sync-config-all-hosts.sh`
3. **Deploy Ruflo** (opcional): `./scripts/ruflo-deploy-agldv03.sh root@<ip>`

---

## 6. Referências

- **LiteLLM multi-host**: `docs/LITELLM-MULTI-HOST-DEPLOYMENT.md`
- **Ruflo avançado**: `docs/RUFLO-ADVANCED.md`
- **Claude Flow + LiteLLM**: `docs/CLAUDE-FLOW-LITELLM.md`
