# agl-gstack (CT191) — OpenClaw + GStack / AGLz AI Agency

**CT191** é o contentor **Jarvis O** da [AGLz AI Agency](AGLZ_AI_AGENCY_PLAN_FINAL_V6.md): **OpenClaw** (assistente executivo) + **GStack** (browser automation), no mesmo padrão do plano **CT-203**, com VMID real **191** em AGLSRV1.

| Item | Valor |
|------|--------|
| VMID | **191** |
| Hostname | `agl-gstack` |
| IP LAN | `192.168.0.191` |
| Recursos | 16 GB RAM / 8 CPU / 64 GB (`local-zfs`) |
| LiteLLM | **CT186** — `http://192.168.0.186:4000` |
| OpenClaw | Docker `/opt/agl-openclaw` (igual CT187) |
| GStack | `/opt/gstack`, config `/etc/gstack/jarvis-o.yaml` |

**Distinção:** **CT187** (`agl-openclaw`) = OpenClaw de **produção** (Jarvis infra). **CT191** = OpenClaw **GStack Edition** + browser daemon para a agência (ver [`TRANSFORMACAO_OPENCLAW_HERMES_83_AGENTES.md`](../projects/aglz-crew/TRANSFORMACAO_OPENCLAW_HERMES_83_AGENTES.md)).

## Arquitectura AGLz (peers)

```
                    CT186 LiteLLM :4000
                           ▲
         ┌─────────────────┼─────────────────┐
         │                 │                 │
    CT191 Jarvis O    CT188 Jarvis H    CT189 EvoNexus
    OpenClaw+GStack   Hermes            Hub agência
    .191              .188              .189
         │                 │
         └──── A2A :8080 (GStack config) ───┘
```

Peers em `projects/aglz-crew/gstack/config/jarvis-o-ct191.yaml`.

## Perfil LXC (CT179 + tun)

```bash
bash scripts/proxmox/pct-apply-agldv03-lxc-profile.sh --with-apparmor 191
```

Mantém **unprivileged=1** (igual CT179); Tailscale via `lxc.mount.entry` para `/dev/net/tun`.

## 1. Criar o LXC (Proxmox)

```bash
cd /caminho/agl-hostman
cp scripts/proxmox/agl-gstack-lxc.env.example scripts/proxmox/agl-gstack-lxc.env
set -a && source scripts/proxmox/agl-gstack-lxc.env && set +a
bash scripts/proxmox/pct-create-ct191-agl-gstack.sh
bash scripts/proxmox/pct-set-static-ip-ct191.sh
```

## 2. Bootstrap OpenClaw + GStack

```bash
pct passwd 191
# Copiar agl-hostman para o CT; preparar OpenClaw:
#   /opt/agl-openclaw/.env  (ver docker/openclaw/.env.ct187.example)
#   /opt/agl-openclaw/config/openclaw.json  (rsync desde CT187 ou openclaw-repo)

pct enter 191
bash /caminho/agl-hostman/scripts/proxmox/bootstrap-ct191-openclaw-gstack.sh \
  /caminho/agl-hostman http://192.168.0.186:4000
```

## 3. Validação

```bash
# OpenClaw
curl -sS http://127.0.0.1:28789/healthz

# GStack
gstack-browser status
gstack-browser goto https://aglz.io
gstack-browser snapshot -i
```

## 4. Comandos GStack (AGLz)

Ver [`projects/aglz-crew/README_GSTACK.md`](../projects/aglz-crew/README_GSTACK.md): `/autoplan`, browser refs `@e1`, A2A para Hermes (188) e EvoNexus (189).

## 5. AppArmor / Docker-in-LXC

Se `docker compose` ou Chromium falharem, aplicar no `191.conf` (como CT185/187):

```text
lxc.apparmor.profile: unconfined
```

Reiniciar o CT.

## Telegram (não duplicar CT187)

**Não** activar `channels.telegram` no CT191 com o **mesmo** `TELEGRAM_BOT_TOKEN` do CT187 — o Telegram só permite um `getUpdates` por token (erro **409 Conflict**). Produção Telegram: **CT187** apenas. CT191 usa Control UI / GStack / A2A.

```bash
# No AGLSRV1, após sync de config desde CT187:
bash scripts/proxmox/pct191-disable-telegram-duplicate.sh --restart
```

## 6. Tailscale

```bash
export TAILSCALE_AUTHKEY='tskey-auth-…'
bash scripts/proxmox/pct-tailscale-up-agency-cts.sh
# ou manual:
pct exec 191 -- tailscale up --auth-key="$TAILSCALE_AUTHKEY" --accept-dns=false --hostname=agl-gstack-ct191 --ssh --accept-routes
```

## Ligações

- Plano agência: [`docs/AGLZ_AI_AGENCY_PLAN_FINAL_V6.md`](AGLZ_AI_AGENCY_PLAN_FINAL_V6.md)
- GStack AGLz: [`projects/aglz-crew/GSTACK_ARCHITECTURE_AGLZ.md`](../projects/aglz-crew/GSTACK_ARCHITECTURE_AGLZ.md)
- OpenClaw LXC: [`LITELLM-OPENCLAW-DEDICATED-LXC.md`](LITELLM-OPENCLAW-DEDICATED-LXC.md)
- CT188–190: [`HERMES-EVONEXUS-OPENHUMAN-DEDICATED-LXC.md`](HERMES-EVONEXUS-OPENHUMAN-DEDICATED-LXC.md)
