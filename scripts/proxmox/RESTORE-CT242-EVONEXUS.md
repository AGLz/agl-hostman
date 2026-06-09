# Restauro EvoNexus (CT548, antes CT242) — fgsrv7

> **Renumeração 2026-06:** VMID **242 → 548** (IP LAN mantém `192.168.70.242`). Ver `docs/PROXMOX-VMID-RENUMBER-2026-06.md`.

CT548 perdeu o disco (histórico CT242); fonte principal: **CT189** (AGLSRV1). Backup alternativo: `/root/backups-ct242-evonexus/evonexus-jarvis-20260513-231047-FULL.tgz` no fgsrv7 (13 Mai 2026, anterior a vários fixes).

Definir `CTID=548` (ou usar defaults dos scripts após Jun 2026).

## Rede e identidade

| Campo | Valor |
|-------|--------|
| Host Proxmox | **fgsrv7** (`100.109.181.93`) |
| VMID | **548** (legado **242**) |
| LAN | `192.168.70.242/24` (`vmbr70`) |
| Público | **https://evo.aglz.io** → Cloudflare **CT570** → `:8080` / terminal `:32352` |
| LiteLLM | CT186 Tailscale `http://100.125.249.8:4000` |
| Features LXC | `nesting=1`, `keyctl=1`, `fuse=1`, mount `/dev/net/tun` |

Config LXC: `/etc/pve/lxc/548.conf` no fgsrv7.

## 1. Recriar rootfs (se disco vazio)

No **fgsrv7**, se o rootfs do CT548 estiver vazio:

```bash
CTID=548
pct stop "${CTID}" 2>/dev/null || true

# Recriar volume 60G (ajustar storage/template conforme o nó)
pct restore "${CTID}" /var/lib/vz/template/cache/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
  --storage bkp --rootfs bkp:60
```

Reaplicar IP estático e mounts se o restore resetar rede (ver `548.conf`).

```bash
pct start "${CTID}"
pct exec "${CTID}" -- bash -c 'apt-get update && apt-get install -y curl'
```

## 2. Bootstrap Docker no CT548

No fgsrv7, a partir do clone **agl-hostman**:

```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman
bash scripts/proxmox/bootstrap-ct242-evonexus.sh
```

## 3. Sync CT189 → CT548

```bash
bash scripts/proxmox/pct-sync-evonexus-189-to-242.sh

SYNC_COMPOSE_UP=1 bash scripts/proxmox/pct-sync-evonexus-189-to-242.sh
```

Variáveis úteis:

- `SYNC_OPT_ONLY=1` — só `/opt/evonexus`
- `SYNC_VOLUMES_ONLY=1` — só volumes Docker
- `AGLSRV1=root@100.107.113.33` — override SSH
- `CT_TARGET=548` — explícito (default nos scripts)

Script inverso (548→189): `pct-sync-evonexus-242-to-189.sh` (correr no AGLSRV1).

## 4. Pós-sync — ajustes CT548 (não incluídos no sync)

Ordem sugerida após `docker compose up -d`:

### 4.1 `.env` e LiteLLM

```bash
bash scripts/evonexus/migrate-off-dashscope-ct242.sh
```

Dentro do dashboard:

```bash
pct exec 548 -- docker exec -w /workspace evonexus-dashboard \
  python3 /opt/evonexus/sync-providers-anthropic-from-env.py
```

### 4.2 Overlays AGL (repo)

Ver `scripts/evonexus/overlays/README-evonexus-overlays.md`:

```bash
bash scripts/evonexus/deploy-adw-routines-ct242.sh
```

### 4.3 Telegram (Jarvis bot)

CT189 ainda usa `evo-nexus-runtime` no telegram — **no CT548** aplicar fixes da sessão anterior (imagem dashboard, plugins, entrypoint).

### 4.4 Tailscale no CT

```bash
# manual: pct exec 548 -- tailscale up
```

### 4.5 SQLite única

```bash
pct exec 548 -- bash /opt/evonexus/unify-single-sqlite-evonexus-db.sh
```

### 4.6 Jarvis RBAC (após pull de imagem)

```bash
pct exec 548 -- docker exec evonexus-dashboard \
  python3 /opt/evonexus/patch-dashboard-models-jarvis-layer.py
```

## 5. Validação

```bash
curl -sS -o /dev/null -w "%{http_code}\n" https://evo.aglz.io/
bash scripts/evonexus/run-ct242-claude-smoke-matrix.sh
pct exec 548 -- docker compose -f /opt/evonexus/docker-compose.hub.yml ps
```

## 6. Backup futuro

No CT548 (dentro do CT):

```bash
/root/backups/evonexus-jarvis-$(date +%Y%m%d-%H%M%S)-FULL.tgz
```

Espelhar no host: `/root/backups-ct242-evonexus/` (`pct pull` — nome histórico). Ver `docs/INFRA.md`.
