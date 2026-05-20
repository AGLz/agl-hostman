# Hermes (CT188) + EvoNexus (CT189) + OpenHuman (CT190) — AGLSRV1

Objetivo: três LXC dedicados na mesma linha dos CT186/187, cada um com um papel de agente na stack AGLz.

| VMID | Hostname | Função | RAM / CPU / Disco | Gateway LLM |
|------|----------|--------|-------------------|-------------|
| **188** | agl-hermes | [Hermes Agent](https://hermes-agent.nousresearch.com/) (NousResearch) | 8 GB / 4 / 32 GB | CT186 `http://192.168.0.186:4000` |
| **189** | agl-evonexus | EvoNexus hub (dashboard + scheduler + telegram) | 16 GB / 8 / 64 GB | CT186 (preferir IP Tailscale do CT186) |
| **190** | agl-openhuman | [OpenHuman](https://github.com/tinyhumansai/openhuman) (assistente + Memory Tree) | 8 GB / 4 / 48 GB | CT186 ou subscrição TinyHumans |

**Produção actual canónica:** LiteLLM **CT186**, OpenClaw **CT187** — ver [`LITELLM-OPENCLAW-DEDICATED-LXC.md`](LITELLM-OPENCLAW-DEDICATED-LXC.md).

## Casos de uso (síntese)

| Serviço | Quando usar | Isolamento |
|---------|-------------|------------|
| **Hermes** | Assistente estratégico, pesquisa, memória Hermes, API OpenAI-compatible na porta 8642; migração desde OpenClaw (`hermes claw migrate`) | Docker-in-LXC; dados em `/opt/agl-hermes/data` |
| **EvoNexus** | Agência AGLz: terminal Claude, SPA `evo.aglz.io`, rotinas ADW, Jarvis, SQLite `evonexus.db` | Stack Docker pesada; overlays em `scripts/evonexus/` |
| **OpenHuman** | Assistente pessoal com integrações OAuth, Memory Tree, Obsidian wiki, auto-fetch 20 min | UI desktop (Tauri); em servidor: install + dados; ver cloud deploy na doc upstream |

## Perfil LXC (mounts + Tailscale, como CT179)

Bind mounts (`/mnt/overpower`, `/mnt/shares`, …) e **`/dev/net/tun`** para Tailscale. Os CTs permanecem **unprivileged** (`unprivileged: 1`), igual ao CT179 — **não** são privileged.

```bash
bash scripts/proxmox/pct-apply-agldv03-lxc-profile.sh --with-apparmor 188 189 190
```

## Pré-requisitos

- Root no **AGLSRV1** (`192.168.0.245` / Tailscale `100.107.113.33`).
- VMIDs **188**, **189**, **190** livres (`pct list`).
- Template `debian-12-standard` em `local:vztmpl/`.
- `config/litellm/.env` no CT186 (não commitar).

## 1. Criar os LXC

No agl-hostman (ou copiar scripts para o nó):

```bash
cd /caminho/agl-hostman
cp scripts/proxmox/agl-hermes-evonexus-openhuman-lxc.env.example \
   scripts/proxmox/agl-hermes-evonexus-openhuman-lxc.env
# editar storage/bridge se necessário

set -a && source scripts/proxmox/agl-hermes-evonexus-openhuman-lxc.env && set +a
bash scripts/proxmox/pct-create-agl-hermes-evonexus-openhuman.sh
```

Features LXC (igual CT186/187): `nesting=1,keyctl=1,fuse=1,mknod=1`. Se Docker falhar, considerar `lxc.apparmor.profile: unconfined` no `*.conf` do CT (ver runbook LiteLLM/OpenClaw).

```bash
pct passwd 188 && pct passwd 189 && pct passwd 190
```

## 2. IPs e Tailscale

```bash
pct exec 188 -- ip -4 addr show eth0
pct exec 189 -- ip -4 addr show eth0
pct exec 190 -- ip -4 addr show eth0
```

Hostnames Tailscale sugeridos: `agl-hermes-ct188`, `agl-evonexus-ct189`, `agl-openhuman-ct190` (mesmo padrão que CT186/187).

## 3. Bootstrap CT188 — Hermes

```bash
# Copiar agl-hostman para o CT (git clone, scp, ou NFS no CT179 → rsync)
pct enter 188
bash /caminho/agl-hostman/scripts/proxmox/bootstrap-ct188-hermes.sh \
  /caminho/agl-hostman http://192.168.0.186:4000
```

Config de referência (sem segredos): repositório irmão `agl-hermes-config` e [`docs/HERMES-AGENT-AGLDV03.md`](HERMES-AGENT-AGLDV03.md).

Validação:

```bash
curl -sS http://127.0.0.1:8642/health
```

## 4. Bootstrap CT189 — EvoNexus

Origem de referência: **CT242** em fgsrv7 (`/opt/evonexus`, `evo.aglz.io`). No CT189:

1. Copiar stack e `.env` do CT242 **ou** clonar `EVONEXUS_REPO` (definir no bootstrap).
2. Ajustar `ANTHROPIC_BASE_URL` / `LITELLM_GATEWAY_URL` para o LiteLLM do **CT186** (IP Tailscale recomendado).
3. Aplicar overlays: [`scripts/evonexus/overlays/README-evonexus-overlays.md`](../scripts/evonexus/overlays/README-evonexus-overlays.md).

```bash
pct enter 189
bash /caminho/agl-hostman/scripts/proxmox/bootstrap-ct189-evonexus.sh \
  /caminho/agl-hostman http://100.x.x.x:4000
```

Rotinas AGLz (adaptar `CTID=189`):

```bash
CTID=189 bash scripts/evonexus/deploy-adw-routines-ct242.sh
```

Cloudflare: atualizar `evo.aglz.io` para o IP do CT189 quando fizer cutover (ver [`docs/CLOUDFLARE-TUNNELS.md`](CLOUDFLARE-TUNNELS.md)).

## 5. Bootstrap CT190 — OpenHuman

```bash
pct enter 190
bash /caminho/agl-hostman/scripts/proxmox/bootstrap-ct190-openhuman.sh http://192.168.0.186:4000
```

OpenHuman é **beta** e **UI-first**; em LXC sem ambiente gráfico use install oficial + config manual, ou seguir [Cloud Deploy](https://tinyhumans.gitbook.io/openhuman/developing/developing) na doc upstream. Requisitos build: Node 24+, pnpm, Rust 1.93+.

## 6. Monitorização

Adicionar entradas em `config/monitoring/jarvis-openclaw-http-endpoints.example.json` (ex.: Hermes `:8642/health`, EvoNexus `:8080/`, OpenHuman conforme serviço exposto).

## Tailscale (CT188–191)

Binário instalado no bootstrap; estado inicial **Logged out**. Com chave reutilizável:

```bash
export TAILSCALE_AUTHKEY='tskey-auth-…'
bash scripts/proxmox/pct-tailscale-up-agency-cts.sh
```

CT186/187 já estão na tailnet (`aglsrv1-litellm`, `aglsrv1-openclaw`) — não repetir `tailscale up` sem necessidade.

## Ligações

- Hermes Docker: https://hermes-agent.nousresearch.com/docs/user-guide/docker
- EvoNexus overlays: `scripts/evonexus/overlays/README-evonexus-overlays.md`
- OpenHuman: https://tinyhumans.gitbook.io/openhuman/
- Plano agência: `docs/AGLZ_AI_AGENCY_PLAN_FINAL_V6.md` — VMIDs 188–191 em AGLSRV1; **Jarvis O (OpenClaw+GStack)** = **CT191** — [`AGL-GSTACK-CT191-DEDICATED-LXC.md`](AGL-GSTACK-CT191-DEDICATED-LXC.md)
