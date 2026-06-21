# Harness Router AGL — pointer

> **Fonte canónica (wiki):** [`llm-wiki/wiki/Ecossistema Harness Router AGL.md`](https://github.com/AGLz/llm-wiki)  
> Path NFS: `/mnt/overpower/apps/dev/agl/llm-wiki/wiki/Ecossistema Harness Router AGL.md`

Ecossistema multi-harness (Claude Code, Cursor, Verdent, Ruflo) com skills dispatchers, LiteLLM CT186 como control plane, e plano faseado Fase 0–5.

## Relacionado (repo)

| Doc                                                                                                   | Conteúdo                    |
| ----------------------------------------------------------------------------------------------------- | --------------------------- |
| [`docs/LITELLM-MODEL-TIERS.md`](LITELLM-MODEL-TIERS.md)                                               | Tiers paid → local → free   |
| [`docs/CURSOR-LITELLM-INTEGRATION.md`](CURSOR-LITELLM-INTEGRATION.md)                                 | Cursor → proxy `/cursor`    |
| [`ai-docs/planning/SIX-REPOS-MULTI-AGENT-PLAN.md`](../ai-docs/planning/SIX-REPOS-MULTI-AGENT-PLAN.md) | Sync skills cross-harness   |
| [`agent-os/ARCHON-INTEGRATION.md`](../agent-os/ARCHON-INTEGRATION.md)                                 | Agent-OS + MCP              |
| [`.claude/agents/dual-mode/dual-orchestrator.md`](../.claude/agents/dual-mode/dual-orchestrator.md)   | Precursor dual Claude+Codex |

## Próximo implementável

Fase 1 ✅ skills em `.claude/skills/agl-*` · sync: `bash scripts/agl/sync-harness-skills.sh`

Fase 2 ✅ `scripts/agl/harness-dispatch.sh` · env: `config/harness/*.env.example`

```bash
bash scripts/agl/harness-dispatch.sh --dry-run --harness claude-code --auth max-direct --task "..." --skip-probe
```

Fase 3 ✅ `scripts/litellm/quota-governor.sh` + `provision-virtual-keys.sh`

Fase 4 ✅ Agent-OS × Ruflo:

```bash
bash scripts/agl/agent-os-ruflo-dispatch.sh --spec infrastructure/wireguard-peer-setup --json --dry-run
bash scripts/agl/smoke-harness-agent-os.sh
```

Fase 5 ✅ Mission Control dashboard quota (`/mission-control/harness`):

```bash
bash scripts/agl/export-harness-snapshot.sh
bash scripts/agl/export-harness-snapshot.sh --run-governor
# API: GET /api/harness/snapshot
```
