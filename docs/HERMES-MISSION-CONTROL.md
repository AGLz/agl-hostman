# Hermes — Mission Control, Claw3D e Web UI

Pesquisa GitHub (mai/2026) e recomendação para infra AGL (CT188 Jarvis).

## Existe “Hermes Mission Control + Claw3D” integrado?

**Não.** Não há repositório ou produto oficial que una Kanban mission control + escritório 3D numa só Web UI. São camadas diferentes:

| Projeto | GitHub | ⭐ | Função |
|---------|--------|---|--------|
| **[Minions](https://github.com/Agent-3-7/minions)** (`minionsai`) | Agent-3-7/minions | ~570 | **Mission Control** — Kanban, tarefas autónomas, review, cron |
| **[Claw3D](https://github.com/iamlukethedev/Claw3D)** | iamlukethedev/Claw3D | ~1860 | **Escritório 3D** — visualização, chat gateway, multi-agente |
| **[hermes-office](https://github.com/fathah/hermes-office)** | fork Claw3D + adapter Hermes | ~9 | Claw3D com backend Hermes |
| **[hermes-desktop](https://github.com/fathah/hermes-desktop)** | fathah/hermes-desktop | ~9100 | App desktop — Remote HTTP + Claw3D/Office integrado |
| **Hermes Agent** | NousResearch/hermes-agent | — | Runtime; **dashboard oficial** opcional (`HERMES_DASHBOARD=1`) |

Pesquisa `hermes mission control claw3d` no GitHub: **0 resultados**.

Minions **não** integra Claw3D. Claw3D **não** inclui Kanban mission control. O ecossistema combina **2–3 URLs** diferentes.

## Web UI oficial do Hermes (Nous Research)

Com `HERMES_DASHBOARD_JARVIS=1` e `HERMES_DASHBOARD_INSECURE_JARVIS=1` (LAN/Tailscale confiável — expõe `.env`; usar só atrás de VPN/firewall):

- Chat web + bridge WebSocket TUI (`/api/ws`)
- **Não** é mission control Kanban
- **Não** é escritório 3D Claw3D

Documentação: [hermes-agent.nousresearch.com/docs](https://hermes-agent.nousresearch.com/docs/)

No quartet AGL, Jarvis expõe **9119** com `HERMES_DASHBOARD_JARVIS=1` (por omissão no compose; outros agents mantêm `HERMES_DASHBOARD=0` no `.env` global).

## Stack recomendada AGL (CT188)

Combinação mais usada e compatível com o que já tens:

| Camada | URL (LAN) | URL (Tailscale) | Uso |
|--------|-----------|-----------------|-----|
| **API Hermes** (hermes-desktop Remote) | `http://192.168.0.188:8642` | `http://100.81.225.22:8642` | Chat OpenAI-compatible, desktop |
| **Claw3D adapter** (Office 3D) | `ws://192.168.0.188:18789` | `ws://100.81.225.22:18789` | hermes-desktop / Claw3D Studio |
| **Minions** (Mission Control) | `http://192.168.0.188:6969` | `http://100.81.225.22:6969` | Kanban, tarefas, cron, ficheiros |
| **Dashboard oficial** | `http://192.168.0.188:9119` | `http://100.81.225.22:9119` | Chat web Nous (leve) |

Token API (8642 + 18789): `API_SERVER_KEY` em `/opt/agl-hermes/.env`.

### Porque Minions (e não só o dashboard oficial)?

- **Minions** é o projecto Hermes-only mais adoptado para **supervisão de trabalho autónomo** (Kanban, review, streaming, scheduled tasks).
- **Claw3D** cobre **presença 3D** — já tens o adaptador WS no CT188.
- **hermes-desktop** (9k+ stars) é a forma mais popular de **usar os dois no PC**; no browser usamos Minions + dashboard + (opcional) Claw3D Studio.

Minions importa `AIAgent` via Python **no mesmo host** — não usa só HTTP remoto. Por isso corre **no CT188** partilhando `/opt/agl-hermes/data` com Jarvis.

## Deploy no CT188

```bash
# Claw3D WS adapter (:18789) — já documentado
bash .../bootstrap-hermes-claw3d-adapter-ct188.sh /mnt/overpower/apps/dev/agl/agl-hostman

# Minions Mission Control (:6969)
bash .../bootstrap-hermes-minions-ct188.sh /mnt/overpower/apps/dev/agl/agl-hostman

# Claw3D Studio (:3003 host — Langfuse ocupa :3000) — Docker no CT188
bash .../bootstrap-hermes-claw3d-studio-ct188.sh /mnt/overpower/apps/dev/agl/agl-hostman

# Recriar Jarvis com dashboard (:9119) se ainda HERMES_DASHBOARD=0
cd /opt/agl-hermes
docker compose -f docker-compose.aglz-quartet.ct188.yml up -d hermes-jarvis
```

Contentores: `agl-hermes-jarvis`, `agl-hermes-claw3d-adapter`, `agl-hermes-minions`, `agl-hermes-claw3d-studio`.

## Claw3D Studio no browser

Deploy Docker (recomendado no CT188):

```bash
bash scripts/proxmox/bootstrap-hermes-claw3d-studio-ct188.sh /mnt/overpower/apps/dev/agl/agl-hostman
```

- **LAN:** `http://192.168.0.188:3003`
- **Tailscale:** `http://100.81.225.22:3003`
- Autenticação: cookie `studio_access=<HERMES_STUDIO_ACCESS_TOKEN>` (gerado em `/opt/agl-hermes/.env`)
- Gateway WS interno: `ws://192.168.0.188:18789` (adaptador Claw3D)

Dev local (alternativa):

```bash
git clone https://github.com/fathah/hermes-office.git
cd hermes-office && npm install
HERMES_API_URL=http://192.168.0.188:8642 HERMES_API_KEY=<API_SERVER_KEY> npm run hermes-adapter &
STUDIO_ACCESS_TOKEN=<token> npm run dev   # :3000
```

Alternativa desktop: **hermes-desktop** no PC com Remote + Claw3D.

## Mission Control Laravel (agl-hostman)

O dashboard React em `src/resources/js/pages/MissionControl*` foi migrado para **Hermes CT188**:

| Rota UI | API Laravel | Backend |
|---------|-------------|---------|
| `/mission-control` | `/api/agents`, `/api/tasks/summary`, `/api/agent-status` | Hermes + Minions |
| `/mission-control/team` | `/api/hermes/agents/*/chat` | API `:8642` |
| `/mission-control/minions` | iframe → Minions `:6969` | — |
| `/mission-control/studio` | iframe → Studio `:3003` | Claw3D adapter `:18789` |
| `/mission-control/settings` | `/api/hermes/status`, `/api/hermes/scheduled-tasks` | CT188 |

Config: `src/config/hermes.php` + variáveis `HERMES_*` no `.env`.

Rotas **OpenClaw** legadas mantidas em `/api/openclaw/*` (CT187) — não usadas pelo Mission Control principal.

## Referências

- [Minions README](https://github.com/Agent-3-7/minions)
- [Claw3D / hermes-gateway.md](https://github.com/fathah/hermes-office/blob/main/docs/hermes-gateway.md)
- [HERMES-DESKTOP-REMOTE.md](HERMES-DESKTOP-REMOTE.md)
- [AGLZ-HERMES-ONLY-AGENCY.md](AGLZ-HERMES-ONLY-AGENCY.md)
