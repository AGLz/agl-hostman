# AGLz Agency — Hermes-only (Jarvis · Elon · Satya · Werner · Curator · Orion)

> **Decisão (2026-05):** agência **só Hermes** no **CT188**. Sem OpenClaw/EvoNexus/GStack para a agência.  
> **Agentes KB + Media:** ver **[`docs/HERMES-AGENCY-AGENTS.md`](HERMES-AGENCY-AGENTS.md)**.  
> **Memória:** Honcho **self-hosted** no **CT192**. **Conhecimento:** **[AGLz/llm-wiki](https://github.com/AGLz/llm-wiki)** (bases curadas). **Tarefas:** **Linear** (em substituição do Archon).  
> **LLM:** LiteLLM **CT186** — Tailscale `http://100.125.249.8:4000`.

---

## Quartet executivo

| Codename | Nome       | Papel                                               | Modelo principal                                                  | Telegram |
| -------- | ---------- | --------------------------------------------------- | ----------------------------------------------------------------- | -------- |
| `jarvis` | **Jarvis** | **CEO** — visão, prioridades, delegação             | `groq-llama-31-8b` _(até quota OpenAI 2026-06-01 → `gpt-5-mini`)_ | Bot 1    |
| `elon`   | **Elon**   | **CPO/CRO** — produto, pesquisa, inovação           | `groq-llama-31-8b`                                                | Bot 2    |
| `satya`  | **Satya**  | **COO** — execução, código, entrega                 | `groq-llama-31-8b`                                                | Bot 3    |
| `werner` | **Werner** | **VP Infra** — AGL Infra, Proxmox, rede, plataforma | `groq-llama-31-8b`                                                | Bot 4    |

**Fallback LiteLLM:** `or-nemotron-super-free` · **Aux (compressão/visão):** `zai-glm-flash` (Z.AI Anthropic `glm-4.5-flash`).

Cada agente: profile isolado (`SOUL.md`, skills, memória Honcho peer distinto).

### A2A interno

- **Hoje:** `delegate_task` (Jarvis → Elon / Satya / **Werner**)
- **Futuro:** A2A entre profiles ([#25698](https://github.com/NousResearch/hermes-agent/issues/25698))

---

## Arquitectura (deploy actual — quartet profiles)

Hermes **0.14.x** não suporta multi-bot num único gateway ([PR #25660](https://github.com/NousResearch/hermes-agent/pull/25660) aberta). **Hoje:** 4 profiles = 4 contentores = 4 bots.

```
  Telegram ×4 (@hermes_jarvis_h_*)
       │
       ▼
┌────────────────────────────────────────────────────────┐
│ CT188  /opt/agl-hermes                                 │
│  agl-hermes-jarvis  :8642  (API + Telegram + hermes-desktop) │
│  agl-hermes-elon     (Telegram only)                   │
│  agl-hermes-satya    (Telegram only)                   │
│  agl-hermes-werner   (Telegram only)                   │
│  Imagem: Dockerfile.aglz-messaging (python-telegram-bot)│
└──────────────┬─────────────────────────────────────────┘
               │
     ┌─────────┴─────────┬─────────────┐
     ▼                   ▼             ▼
┌─────────────┐   ┌──────────────┐  ┌─────────────┐
│ CT186       │   │ CT192 Honcho │  │ llm-wiki    │
│ LiteLLM     │   │ memória      │  │ /opt/...    │
│ gpt-5.5 …   │   │ episódica    │  │ wiki+raw    │
└─────────────┘   └──────────────┘  └─────────────┘
     │
     ▼
┌─────────────┐
│ Linear      │  issues / roadmap (substitui Archon *tasks*)
│ (MCP+CLI)   │
└─────────────┘
```

**Rede:** CT188/192 → LiteLLM via **Tailscale** (LAN `.186` bloqueada entre CTs).

### Três camadas de estado

| Camada              | Sistema          | Papel                                                |
| ------------------- | ---------------- | ---------------------------------------------------- |
| Conhecimento curado | **llm-wiki**     | Runbooks, entidades, síntese (~120 wiki / ~1470 raw) |
| Memória de conversa | **Honcho CT192** | Peers, conclusões, contexto entre sessões            |
| Trabalho            | **Linear**       | Backlog, estados, entrega                            |

Detalhe llm-wiki: [`LLM-WIKI-AGENCY-INTEGRATION.md`](LLM-WIKI-AGENCY-INTEGRATION.md).

---

## Werner — AGL Infra no Hermes

| Campo    | Valor                                                                     |
| -------- | ------------------------------------------------------------------------- |
| Codename | `werner`                                                                  |
| Persona  | **Werner Vogels** — VP Infrastructure & Platform                          |
| Modelo   | `qwen-coder` (+ `glm-4.7-flash` triagem)                                  |
| Skill    | `.claude/skills/agl-infra` → `profiles/werner/skills/agl-infra/`          |
| Repo     | `AGL_HOSTMAN_DIR` → `/opt/agl-hostman` (`docs/INFRA.md`, scripts Proxmox) |
| Telegram | `TELEGRAM_BOT_TOKEN_WERNER`                                               |

**Delegação:** Jarvis envia Proxmox, rede, LiteLLM health, CT unlock, Tailscale → Werner. Satya coordena deploys de app; Werner garante chão infra.

### Ferramentas na imagem (`Dockerfile.aglz-agency`)

Todos os gateways usam **`agl-hermes-agency`**. Terminal Hermes = shell **dentro** do contentor.

| Camada             | Ferramentas                                                                                                              |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------ |
| Rede / diagnóstico | `curl`, `jq`, `yq`, `ping`, `dig`, `nc`, `wg`, `showmount`, `rsync`                                                      |
| Proxmox remoto     | `tailscale ssh root@100.107.113.33 -- pct list` ou `ssh aglsrv1-ts 'pct list'` — **Tailscale SSH** (sem chaves no CT188) |
| Docker CT188       | `docker` + `/run/docker.sock` (GID 996)                                                                                  |
| Dados              | `psql`, `redis-cli`, `sqlite3`                                                                                           |
| Hermes             | `python-telegram-bot`, `honcho-ai`, CLI `linear`                                                                         |
| Repo               | `/opt/agl-hostman` read-only                                                                                             |

Smoke: `bash scripts/proxmox/verify-hermes-agency-image.sh`. **`pct`/`qm` só no host Proxmox** — via **Tailscale SSH** a partir de agldv03/Cursor (ou host com `tailscale up --ssh` + ACLs).

### SSH / Tailscale (padrão AGL)

Quase todos os hosts usam **Tailscale SSH** (`tailscale up --ssh` + ACLs) — **não** é necessário distribuir chaves `id_*` para o CT188 para operação normal.

| Quem opera                     | Como                                                                                                                      |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------- |
| Tu / agentes (agldv03, Cursor) | `tailscale ssh root@100.107.113.33 -- …` ou alias `aglsrv1-ts` em `~/.ssh/config`                                         |
| Contentor Hermes (Werner)      | `docker` no CT188 via socket; Proxmox remoto = **runbooks copy-paste** para o operador (contentor não corre `tailscaled`) |
| Chaves em `/opt/data/.ssh`     | **Opcional** — só se quiseres SSH clássico dentro do contentor; mount `AGL_INFRA_SSH_DIR`                                 |

Referência: [`docs/fgsrv07-tailscale-ssh-guide.md`](fgsrv07-tailscale-ssh-guide.md), OpenClaw CT187 (mesmo padrão).

---

## Honcho (CT192)

| Item               | Valor                                                            |
| ------------------ | ---------------------------------------------------------------- |
| VMID               | **192** `agl-honcho`                                             |
| LAN                | `192.168.0.192` (DHCP pode variar)                               |
| Tailscale          | **`100.124.98.54`** (`aglsrv1-honcho.degu-chromatic.ts.net`)     |
| API                | `:8000` — CT188 usa `http://100.124.98.54:8000` em `honcho.json` |
| Runbook            | [`HONCHO-CT192-DEDICATED-LXC.md`](HONCHO-CT192-DEDICATED-LXC.md) |
| LLM interno Honcho | LiteLLM — `glm-4.7-flash` / `gemini-lite` (Deriver barato)       |

Workspace **`aglz-agency`** · AI peers: `jarvis`, `elon`, `satya`, `werner` · user peer: Sr.Big.

---

## Linear + llm-wiki (em vez de Archon)

**Porquê mudar:** Archon (CT183) — MCP instável, portas inconsistentes (8051/8052), stack pesada, sync KB frágil (`scripts/sync-archon-kb.sh`).

**Substituição em dois eixos:**

| Função Archon        | Substituto                                                                                |
| -------------------- | ----------------------------------------------------------------------------------------- |
| Tasks / backlog      | **Linear** (MCP + CLI)                                                                    |
| Knowledge base / RAG | **[AGLz/llm-wiki](https://github.com/AGLz/llm-wiki)** — wiki Markdown + ingest/query/lint |

**Linear adoptado para:**

- Backlog e issues da agência (equipa **AGLz** ou **INFRA** — definir no Linear)
- Estados, prioridades, comentários de entrega
- Integração com git (branch `INFRA-123-desc`)

**Integração Hermes:**

| Canal                                              | Uso                                                                              |
| -------------------------------------------------- | -------------------------------------------------------------------------------- |
| **MCP** `https://mcp.linear.app/mcp`               | OAuth — criar/listar/atualizar issues no chat                                    |
| **CLI** `@0xbigboss/linear-cli` + `LINEAR_API_KEY` | Skills/scripts Satya (ops)                                                       |
| **Docs**                                           | [`LINEAR-MCP-INTEGRATION.md`](LINEAR-MCP-INTEGRATION.md), skill `linear-cli-agl` |

**Archon:** manter CT183 para outros usos ou descomissionar após cutover Linear — **não** dependência da agência.

---

## Model routing (custo)

> **Regra:** **Jarvis (CEO)** usa **`gpt-5-mini`** (OpenAI, mais barato que `gpt-5.5`). Outros agentes e defaults usam aliases baratos.

| Agente / camada                | Alias LiteLLM                            |
| ------------------------------ | ---------------------------------------- |
| **Jarvis (CEO)**               | `gpt-5-mini`                             |
| Elon (CPO/CRO)                 | `glm-4.7-flash` (LiteLLM → `gpt-5-nano`) |
| Satya / Werner (código, infra) | `qwen-coder`                             |
| Default gateway (não-Jarvis)   | `glm-4.7-flash`                          |
| Auxiliares (compressão, web)   | `gemini-lite`, `glm-4.7-flash`           |
| Delegação / subtarefas         | `qwen-coder`                             |
| Honcho Deriver                 | `glm-4.7-flash`                          |
| Fallback global                | `glm-4.7-flash` → `ollama-qwen3-4b`      |

---

## Ficheiros no repo

| Path                                                               | Conteúdo                                     |
| ------------------------------------------------------------------ | -------------------------------------------- |
| `docker/hermes/profiles/{jarvis,elon,satya,werner}/SOUL.md`        | Personas                                     |
| `docker/hermes/Dockerfile.aglz-agency`                             | Telegram + Honcho + jq/yq/SSH/Docker (infra) |
| `docker/hermes/docker-compose.aglz-quartet.ct188.yml`              | 4 gateways (1 bot cada)                      |
| `scripts/proxmox/configure-ct188-hermes-quartet.sh`                | SOUL, tokens, compose CT188                  |
| `scripts/proxmox/smoke-hermes-aglz-quartet.sh`                     | Smoke LiteLLM/Honcho/wiki/Telegram           |
| `scripts/proxmox/ensure-llm-wiki-ct188.sh`                         | Symlink NFS ou clone llm-wiki                |
| `docker/hermes/config.aglz-multi-agent.yaml.example`               | **Futuro** — single gateway multi-agent      |
| `scripts/proxmox/pct-create-agl-honcho.sh`                         | CT192                                        |
| `scripts/proxmox/bootstrap-ct192-honcho.sh`                        | Honcho + LiteLLM                             |
| [`LLM-WIKI-AGENCY-INTEGRATION.md`](LLM-WIKI-AGENCY-INTEGRATION.md) | Clone, mount, fluxos ingest/query            |

---

## Ordem de implementação

1. **CT188 quartet** — tokens → `configure-ct188-hermes-quartet.sh` → `smoke-hermes-aglz-quartet.sh` → Telegram: `/start` ou `/help` (alias) ou mensagem sem `/`
2. **DNS / LAN CT188–191** — Pi-hole `192.168.0.102` · `agl-lan-routes.sh` + `pct-install-agl-lan-routes.sh` (`--accept-routes=false`)
3. **CT192 Honcho** — Tailscale `100.124.98.54` ✅ · `honcho.json` quartet
4. **llm-wiki** — NFS `/mnt/overpower/apps/dev/agl/llm-wiki` → `/opt/agl-llm-wiki` ✅ · `ensure-llm-wiki-ct188.sh`
5. **Linear** — `LINEAR_API_KEY` + OAuth MCP (`/mcp`); project _AGLz Agency_
6. **Descomissionar** sync Archon KB para agência; CT189/191 legado

---

## Referências

- Hermes multi-agent: [PR #25660](https://github.com/NousResearch/hermes-agent/pull/25660)
- Honcho self-host: [elkimek/honcho-self-hosted](https://github.com/elkimek/honcho-self-hosted)
- Personas históricas AGLz: `projects/aglz-crew/JARVIS_O_JARVIS_H_GSTACK_COMPLETE.md`
