# Mission Control — Roadmap Laravel (agl-hostman)

> **Data:** 2026-06-12  
> **Estado:** Planeamento / Fase 0 validação AGLSRV1  
> **UI:** Inertia/React (`src/resources/js/`) + APIs Laravel existentes  
> **Second brain:** runbooks em `llm-wiki`; este doc é pointer operacional

---

## 1. Objetivo

Consolidar **Mission Control** como camada única de supervisão operacional:

- Host Proxmox **AGLSRV1** (depois AGLSRV3/5/6, FGSRV*, ALD)
- Serviços em CTs/VMs (LiteLLM, Ollama, Hermes, OpenClaw, *arr, DBs, etc.)
- Instâncias **Hermes** (CT188 + 5 futuras)
- **OpenClaw**, **media grabs**, infra **AGLz / FGz / ALD**

---

## 2. O que já existe (baseline)

### Frontend (React SPA em `view('app')`)

| Rota | Componente | Estado |
|------|------------|--------|
| `/mission-control` | `MissionControlDashboard.jsx` | Hermes agents + tasks (poll) |
| `/mission-control/minions` | iframe Minions :6969 | CT188 |
| `/mission-control/studio` | iframe Claw3D Studio :3003 | CT188 |
| `/mission-control/settings` | `MissionControlSettings.jsx` | Links + scheduled tasks |
| `/infrastructure` | `InfrastructureDashboard.jsx` | Cache analytics (30s poll) |
| `/metrics` | `MetricsDashboard.jsx` | Métricas avançadas |
| `/dokploy` | `DokployDashboard.jsx` | Integração parcial |
| `/archon/*` | Archon pages | MCP command center |

### Backend (Laravel `src/`)

| Área | Serviços / APIs | Notas |
|------|-----------------|-------|
| Proxmox | `ProxmoxService`, `ProxmoxApiClient`, `ContainerHealthMonitor` | Jobs + cache |
| Infra analytics | `/api/infrastructure/*` | `MonitorInfrastructure` job |
| Monitoring | `/api/monitoring/*`, Livewire legado | Reverb **desligado** no UI |
| Harbor | `/api/harbor/*` | Completo |
| Dokploy | `/api/dokploy/*` | Apps, deploy, logs |
| Hermes | `/api/hermes/*`, `/api/agents` | CT188 |
| OpenClaw | `/api/openclaw/*` | CT187 (legado MC) |
| Alerts | `/api/alerts/*`, rules | Phase 3 |
| Network | `/api/network/*` | WireGuard topology |
| Containers lifecycle | `/api/containers/*`, backup | Proxmox ops |

### Docs operacionais (fonte para health checks)

| Doc | Uso MC |
|-----|--------|
| `docs/INFRA.md`, `docs/CT_INVENTORY_AGLSRV1.md` | Inventário CT/VM |
| `docs/aglsrv1-key-findings.md`, `docs/AGLSRV1-TROUBLESHOOTING.md` | Problemas conhecidos |
| `docs/AGLWK45-SETUP.md` | VM104 meshagent leak |
| `docs/MEDIA-ARR-STACK-AGL.md` | *arr + downloads |
| `docs/HERMES-MISSION-CONTROL.md` | Stack Hermes UI |
| `docs/OPENCLAW.md`, `docs/LITELLM-*` | OpenClaw + gateway |
| `docs/design-dashboard-infra-20260419.md` | Grid semáforo (PegaProx) |

---

## 3. Melhores práticas (projeto + indústria)

### Arquitetura recomendada (híbrida)

```
┌──────────────┐    ┌─────────────────┐    ┌──────────────────┐
│ React MC UI  │───▶│ Laravel (src/)  │───▶│ Collectors/Jobs  │
│ shadcn polls │    │ API + cache     │    │ Horizon queue    │
└──────────────┘    └────────┬────────┘    └────────┬─────────┘
                             │                       │
                    ┌────────┴────────┐    ┌──────────┴──────────┐
                    │ SQLite/Redis    │    │ Proxmox API         │
                    │ snapshot store  │    │ HTTP health CTs     │
                    └─────────────────┘    │ Prometheus (futuro) │
                                           └─────────────────────┘
```

**Princípios (Prometheus/Grafana/Proxmox 2026):**

1. Monitorização **fora** do hypervisor quando possível (CT179 agl-hostman como painel; métricas via API/scrape).
2. **Golden signals:** CPU, RAM, disco, estado guest + health HTTP por serviço.
3. Alertas em **dois níveis** (warning 85%, critical 95% storage).
4. Tokens Proxmox com **Sys.Audit** / VM.Audit — nunca root em UI.
5. Polling 30–60s v1; **Laravel Reverb** ou SSE v2 para tempo real.
6. **Runbooks codificados:** regras derivadas de `docs/aglsrv1-key-findings.md` (ex.: meshagent RSS > 1GB → alerta VM104).

### Referências externas

- [Proxmox monitoring guide](https://proxmoxr.com/blog/proxmox-monitoring-guide) — camadas built-in vs Grafana/Prometheus
- [PVE Exporter + Grafana 2026](https://www.nxsi.io/blog/proxmox-monitoring-grafana-guide) — alert rules paradas/storage
- [Proxmox Datacenter Manager 1.1](https://proxmox.com/en/about/company-details/press-releases/proxmox-datacenter-manager-1-1) — multi-cluster (fase 3+)
- OpenClaw **command-center** skill (`.agents/skills/command-center/`) — padrão sessões/custos LLM

### Decisão Approach (design doc 2026-04-19)

- **v1:** PegaProx/Proxmox API bridge + cache 60s (já parcialmente implementado)
- **v2:** Health probes HTTP por serviço + runbooks
- **v3:** Prometheus scrape + Grafana embed (opcional)

---

## 4. Modelo de dados — Service Registry

Novo config `config/mission-control.php` (ou extensão `config/services.php`):

```php
// Exemplo — uma entrada por serviço monitorizado
'litellm_ct186' => [
    'host' => 'aglsrv1',
    'vmid' => 186,
    'health_url' => 'http://100.125.249.8:4000/health',
    'category' => 'ai-gateway',
    'runbook' => 'docs/LITELLM-TROUBLESHOOTING.md',
],
```

**Categorias:** `proxmox-host`, `ai-gateway`, `agent`, `media`, `data`, `deploy`, `tunnel`, `storage`.

**Fase AGLSRV1 — serviços prioritários:**

| Serviço | CT/VM | Health check |
|---------|-------|--------------|
| LiteLLM | 186 | GET `/health` |
| Ollama | VM110/310 | GET `/api/tags` |
| Honcho | 192 | workspace ping |
| Hermes quartet | 188 | `:8642`, Minions `:6969` |
| OpenClaw | 187 | gateway `/health` |
| Cloudflared | 117 | tunnel status |
| Plex/Radarr/Sonarr/Prowlarr | 113/123/124/172 | API `/api/v3/system/status` |
| MySQL/PostgreSQL/Redis | 131/149/137 | ping nativo |
| aria2 | 165 | RPC/jsonrpc |
| Harbor | TBD | `/api/v2.0/health` |
| Archon | 183 | MCP/HTTP |
| Dokploy | 180 | `/api/health` |
| Obsidian | 193 | Tailscale + CLI smoke |
| Samba aglfs1 | fileserver CT | mount test |
| Supabase | stack CT | `/rest/v1/` + auth |

---

## 5. Mission Controls (módulos UI)

### 5.1 AGLSRV1 Host MC (`/mission-control/hosts/aglsrv1`)

**Painéis:**

- Grid CT/VM semáforo (design 20260419)
- Node metrics (CPU/RAM/disco host)
- Storage/PBS status
- Backups recentes (`BackupService`)
- Log tail agregado (últimas N linhas via SSH proxy job — **read-only**)
- **Known issues** widget (parse runbooks → checklist automática)

**APIs novas:**

- `GET /api/mission-control/hosts/{code}/snapshot`
- `GET /api/mission-control/hosts/{code}/guests`
- `POST /api/mission-control/hosts/{code}/refresh`

### 5.2 Hermes MC (`/mission-control/hermes/{instance}`)

- Instância `default` → CT188 (existente)
- 5 instâncias futuras: config multi-tenant `hermes.instances.*`
- Reutilizar `HermesController` + rotas por `{instance}`

### 5.3 OpenClaw MC (`/mission-control/openclaw`)

- Evoluir rota actual (hoje duplica `TeamsView`)
- Consumir `/api/openclaw/*` + health CT187
- Link para command-center patterns (sessões, modelos, custos)

### 5.4 Infra AGLz / FGz / ALD

| MC | Hosts | Fase |
|----|-------|------|
| AGLz | AGLSRV1,3,5,6 + CTs dev | 1–2 |
| FGz | FGSRV6/7, fg-antigo | 2 |
| ALD | ALD hosts (inventário TBD) | 3 |

### 5.5 Media Grabs MC (`/mission-control/media`)

- Fonte: `docs/MEDIA-ARR-STACK-AGL.md`, scripts `scripts/media/`
- Estado downloads (frozen/active), queue qBittorrent/aria2, espaço disco overpower
- Integração repo `agl-media-grabber` se aplicável

---

## 6. Fases de implementação

### Fase 0 — Validação (actual)

- [ ] Inventariar endpoints que respondem hoje (smoke script)
- [ ] Documentar gaps auth Sanctum vs SPA
- [ ] Activar Reverb **ou** manter poll documentado

### Fase 1 — AGLSRV1 + Service Registry (2–3 sprints)

- [ ] `config/mission-control.php` + seeder CT_INVENTORY
- [ ] `MissionControlHostController` + job `CollectServiceHealth`
- [ ] UI `HostMissionControl.jsx` grid + detalhe guest
- [ ] Runbook engine (YAML rules → alertas Laravel)

### Fase 2 — Hermes multi-instância + OpenClaw MC

- [ ] Rotas `{instance}` + settings por instância
- [ ] OpenClaw dashboard dedicado

### Fase 3 — Multi-host + Prometheus opcional

- [ ] AGLSRV3/5/6 collectors
- [ ] FGz/ALD
- [ ] Embed Grafana ou export metrics

### Fase 4 — Media + automação

- [ ] Media MC + hooks arr-freeze scripts
- [ ] Notificações (canal existente `/api/notifications`)

---

## 7. Critérios de aceitação (Fase 1)

- [ ] Grid AGLSRV1 com ≥20 guests e cor semáforo
- [ ] ≥10 serviços com health HTTP verificado
- [ ] ≥3 runbooks automáticos (meshagent, CT locked, LiteLLM down)
- [ ] Refresh manual + auto 45s
- [ ] Testes Pest feature para API snapshot
- [ ] Tempo resposta API cache < 2s

---

## 8. Próximo passo imediato

1. Smoke: `php artisan test --filter=Hermes` + curl APIs infra/hermes/openclaw
2. Implementar **Fase 0** checklist em script `scripts/mission-control/smoke-apis.sh`
3. Kickoff **Fase 1** com `MissionControlHostController` + config registry

Ver também: `docs/HERMES-MISSION-CONTROL.md`, `docs/design-dashboard-infra-20260419.md`
