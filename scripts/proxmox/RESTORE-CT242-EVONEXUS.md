# Restauro CT242 (EvoNexus / Jarvis) — fgsrv7

CT242 perdeu o disco; fonte principal: **CT189** (AGLSRV1). Backup alternativo: `/root/backups-ct242-evonexus/evonexus-jarvis-20260513-231047-FULL.tgz` no fgsrv7 (13 Mai 2026, anterior a vários fixes).

## Rede e identidade

| Campo | Valor |
|-------|--------|
| Host Proxmox | **fgsrv7** (`100.109.181.93`) |
| VMID | **242** |
| LAN | `192.168.70.242/24` (`vmbr70`) |
| Público | **https://evo.aglz.io** → Cloudflare CT170 → `:8080` / terminal `:32352` |
| LiteLLM | CT186 Tailscale `http://100.125.249.8:4000` |
| Features LXC | `nesting=1`, `keyctl=1`, `fuse=1`, mount `/dev/net/tun` |

Config LXC preservada: `/etc/pve/lxc/242.conf` no fgsrv7.

## 1. Recriar rootfs (se disco vazio)

No **fgsrv7**, se `/base/bkp/images/242/` (ou storage `bkp`) estiver vazio:

```bash
# Parar CT
pct stop 242 2>/dev/null || true

# Recriar volume 60G (ajustar storage/template conforme o nó)
# Exemplo — confirmar template disponível: ls /var/lib/vz/template/cache/
pct restore 242 /var/lib/vz/template/cache/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
  --storage bkp --rootfs bkp:60

# Ou, se a config existir mas rootfs corrupto:
# pct destroy 242 --purge 0   # só se souberes recriar a config manualmente
```

Reaplicar IP estático e mounts se o restore resetar rede (ver `242.conf`).

```bash
pct start 242
pct exec 242 -- bash -c 'apt-get update && apt-get install -y curl'
```

## 2. Bootstrap Docker no CT242

No fgsrv7, a partir do clone **agl-hostman**:

```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman   # ou caminho local equivalente
bash scripts/proxmox/bootstrap-ct242-evonexus.sh
```

## 3. Sync CT189 → CT242

```bash
# No fgsrv7 (root, com SSH para AGLSRV1)
bash scripts/proxmox/pct-sync-evonexus-189-to-242.sh

# Opcional: subir stack no fim
SYNC_COMPOSE_UP=1 bash scripts/proxmox/pct-sync-evonexus-189-to-242.sh
```

Variáveis úteis:

- `SYNC_OPT_ONLY=1` — só `/opt/evonexus`
- `SYNC_VOLUMES_ONLY=1` — só volumes Docker
- `AGLSRV1=root@100.107.113.33` — override SSH

Script inverso (242→189): `pct-sync-evonexus-242-to-189.sh` (correr no AGLSRV1).

## 4. Pós-sync — ajustes CT242 (não incluídos no sync)

Ordem sugerida após `docker compose up -d`:

### 4.1 `.env` e LiteLLM

No volume `config` ou `/opt/evonexus/.env`:

- `ANTHROPIC_BASE_URL=http://100.125.249.8:4000`
- `LITELLM_GATEWAY_URL=http://100.125.249.8:4000`
- Modelo: `ANTHROPIC_MODEL=glm-4.7-flash` (ou script abaixo)

```bash
# No repo agl-hostman (host com pct)
bash scripts/evonexus/migrate-off-dashscope-ct242.sh
```

Dentro do dashboard:

```bash
pct exec 242 -- docker exec -w /workspace evonexus-dashboard \
  python3 /opt/evonexus/sync-providers-anthropic-from-env.py
```

### 4.2 Overlays AGL (repo)

Ver `scripts/evonexus/overlays/README-evonexus-overlays.md`:

- Copiar overlays para `/opt/evonexus/` (`claude-bridge.js`, `provider-config`, `server.js.atlas-result-text`, `settings.json.uv-hooks`, `jarvis.md`)
- Confirmar mounts no `docker-compose.hub.yml` do dashboard

```bash
bash scripts/evonexus/deploy-adw-routines-ct242.sh
```

### 4.3 Telegram (Jarvis bot)

CT189 ainda usa `evo-nexus-runtime` no telegram — **no CT242** aplicar fixes da sessão anterior:

- Imagem **`evoapicloud/evo-nexus-dashboard:latest`** no serviço `telegram`
- Volume plugins **rw** + seed `claude-plugins-seed/`
- Entrypoint `telegram-entrypoint.sh` sem `claude update` em loop
- Marketplace via HTTPS (não SSH)

### 4.4 Tailscale no CT

```bash
# No fgsrv7 — hostname histórico ~ fgsrv07-evonexus
bash scripts/proxmox/pct-tailscale-up-litellm-openclaw.sh   # se incluir 242
# ou manual: pct exec 242 -- tailscale up
```

### 4.5 SQLite única

```bash
pct exec 242 -- bash /opt/evonexus/unify-single-sqlite-evonexus-db.sh
```

### 4.6 Jarvis RBAC (após pull de imagem)

```bash
pct exec 242 -- docker exec evonexus-dashboard \
  python3 /opt/evonexus/patch-dashboard-models-jarvis-layer.py
```

## 5. Validação

```bash
curl -sS -o /dev/null -w "%{http_code}\n" https://evo.aglz.io/
bash scripts/evonexus/run-ct242-claude-smoke-matrix.sh
pct exec 242 -- docker compose -f /opt/evonexus/docker-compose.hub.yml ps
```

Telegram: enviar mensagem ao bot Jarvis; se pedir login Channels, seguir `/login` no contentor telegram.

## 6. Backup futuro

No CT242 (dentro do CT):

```bash
/root/backups/evonexus-jarvis-$(date +%Y%m%d-%H%M%S)-FULL.tgz
```

Espelhar no host: `/root/backups-ct242-evonexus/` (`pct pull`). Ver `docs/INFRA.md` secção EvoNexus backup.
