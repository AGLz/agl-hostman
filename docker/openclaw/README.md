# OpenClaw CT187 (AGLSRV1)

Stack Docker para o LXC **CT187** (`/opt/agl-openclaw`). Runbook: [`docs/LITELLM-OPENCLAW-DEDICATED-LXC.md`](../../docs/LITELLM-OPENCLAW-DEDICATED-LXC.md).

## Imagem

| Tag | Origem | Uso |
|-----|--------|-----|
| **`agl-openclaw:ops`** | `Dockerfile.ct187` (build local) | **Produção** — inclui `openssh-client` e ferramentas dos cron jobs |
| `ghcr.io/openclaw/openclaw:latest` | Upstream | Gateway apenas; **não** usar com `critical-services-monitor` / `storage-health-check` (falta `ssh`) |

```bash
cd /opt/agl-openclaw
docker compose build openclaw-gateway   # compose usa network: host no build (DNS no CT187)
docker compose up -d
```

Se `docker build` falhar com pacotes apt inexistentes, repetir com `docker build --network=host -f Dockerfile.ct187 -t agl-openclaw:ops .`

Em `.env`: `OPENCLAW_IMAGE=agl-openclaw:ops` (nunca só `latest` se os jobs SSH estiverem activos).

## SSH para monitorização

Os scripts em `workspace/scripts/` usam `~/.ssh/config` (hosts `aglsrv1`, `ct186`, `ct187` via Tailscale).

Montar chaves **fora** do volume `config/`:

```bash
mkdir -p /opt/agl-openclaw/docker-ssh-node
chmod 700 /opt/agl-openclaw/docker-ssh-node
# Copiar id_openclaw_infra, config, known_hosts (uid 1000)
chown -R 1000:1000 /opt/agl-openclaw/docker-ssh-node
```

No `.env`: `OPENCLAW_SSH_DIR=./docker-ssh-node`

## Sincronizar a partir do agl-hostman

No **AGLSRV1**:

```bash
bash /caminho/agl-hostman/scripts/proxmox/pct187-sync-openclaw-stack-from-repo.sh
```

## Validar após deploy

```bash
pct exec 187 -- curl -sf http://127.0.0.1:28789/healthz
pct exec 187 -- docker exec agl-openclaw-openclaw-gateway-1 \
  /home/node/.openclaw/workspace/scripts/critical-services-monitor.sh
```

Saída esperada: `HEARTBEAT_OK`.
