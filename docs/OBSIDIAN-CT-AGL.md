# CT193 agl-obsidian — hub Obsidian + CouchDB + Git bridge

> **Fonte de verdade curada:** página wiki `[[Obsidian CT AGL]]` em [llm-wiki](https://github.com/AGLz/llm-wiki).  
> Scripts: `scripts/obsidian/`, `scripts/proxmox/pct-create-agl-obsidian.sh`, `docker/obsidian/`, `config/systemd/`.

## Resumo

| Item | Valor |
|------|--------|
| VMID | **193** |
| Hostname | `agl-obsidian` |
| IP LAN | `192.168.0.193/24` |
| RAM | 2048 MB mínimo |
| Vault | `/mnt/overpower/apps/dev/agl/llm-wiki` (NFS, perfil CT179) |
| CouchDB | Docker `127.0.0.1:5984` (LiveSync); LAN/TS via firewall |
| Git remote | `https://github.com/AGLz/llm-wiki.git` (credenciais via **gh**) |

**Stack no CT:** Obsidian Linux 24/7 (Xvfb) + CouchDB + bridge Git + Tailscale.

Ver também: [`LLM-WIKI-AGENCY-INTEGRATION.md`](LLM-WIKI-AGENCY-INTEGRATION.md), [`INFRA.md`](INFRA.md).

---

## Ordem de implementação

1. **AGLSRV1:** `pct-create-agl-obsidian.sh` → `pct-apply-agldv03-lxc-profile.sh --with-apparmor 193`
2. **CT193:** IP estático `.193`, Tailscale (`pct-tailscale-up-ct193-obsidian.sh`, `--accept-routes=false`)
3. **CT193:** `bootstrap-ct193-obsidian.sh` (Docker, CouchDB, Obsidian hub, bridge, systemd)
4. **Manual (uma vez):** abrir vault no Obsidian hub, activar CLI, instalar plugin LiveSync, E2EE
5. **Clientes:** CT179 / wk45 / mobile — LiveSync via Tailscale IP do CT193
6. **Validar:** `verify-obsidian-ct.sh`

---

## 1. Criar CT193 (AGLSRV1, root)

Script: [`scripts/proxmox/pct-create-agl-obsidian.sh`](../scripts/proxmox/pct-create-agl-obsidian.sh)

```bash
# No AGLSRV1
cd /mnt/overpower/apps/dev/agl/agl-hostman
bash scripts/proxmox/pct-create-agl-obsidian.sh
bash scripts/proxmox/pct-apply-agldv03-lxc-profile.sh --with-apparmor 193
pct reboot 193
```

---

## 2. Bootstrap no CT193

Script: [`scripts/proxmox/bootstrap-ct193-obsidian.sh`](../scripts/proxmox/bootstrap-ct193-obsidian.sh)

```bash
pct exec 193 -- bash /mnt/overpower/apps/dev/agl/agl-hostman/scripts/proxmox/bootstrap-ct193-obsidian.sh
# Editar COUCHDB_PASSWORD em docker/obsidian/.env antes de expor CouchDB à LAN
```

---

## 3. CouchDB Compose

Ficheiros: `docker/obsidian/docker-compose.couchdb.yml`, `.env.example`

```yaml
services:
  couchdb:
    image: couchdb:3.4.2
    container_name: agl-obsidian-couchdb
    restart: unless-stopped
    environment:
      COUCHDB_USER: ${COUCHDB_USER:-obsidian}
      COUCHDB_PASSWORD: ${COUCHDB_PASSWORD:?definir COUCHDB_PASSWORD}
    volumes:
      - ${COUCHDB_DATA_DIR:-/var/lib/agl-obsidian/couchdb}:/opt/couchdb/data
    ports:
      - "${COUCHDB_BIND:-127.0.0.1}:5984:5984"
    healthcheck:
      test: ["CMD", "curl", "-fsS", "http://127.0.0.1:5984/_up"]
      interval: 30s
      timeout: 10s
      retries: 5
```

Para clientes na LAN/Tailscale, alterar `COUCHDB_BIND=0.0.0.0` e restringir com `ufw`/Proxmox firewall.

---

## 4. Obsidian hub 24/7

Ficheiro: `scripts/obsidian/install-obsidian-hub.sh`

- Descarrega `.deb` de [Obsidian Download](https://obsidian.md/download) / GitHub releases
- Fallback `OBSIDIAN_VERSION_FALLBACK=v1.8.9` se `api.github.com` falhar (rede lenta)
- Instala deps Electron incl. `libasound2` (sem isto o hub falha com exit 127)
- Instala em `/opt/obsidian/`
- Cria `obsidian-hub.service` (Xvfb + `--no-sandbox --disable-gpu`)

Se o bootstrap abortar no download:

```bash
pct exec 193 -- OBSIDIAN_VERSION=v1.8.9 bash .../scripts/obsidian/install-obsidian-hub.sh
pct exec 193 -- apt-get install -y libasound2
```

**Configuração manual (obrigatória, primeira vez):**

1. Entrar no CT com tunnel X11 ou VNC temporário **ou** copiar config de outro host
2. Abrir Obsidian → vault pasta `llm-wiki` em `/mnt/overpower/apps/dev/agl/llm-wiki`
3. Settings → Command line interface → **ON**
4. Community plugins → **Self-hosted LiveSync** → endpoint `http://127.0.0.1:5984`, user/pass do `.env`
5. Activar **E2EE** (passphrase em secret manager, não Git)
6. `obsidian set-default "llm-wiki"`

CLI remoto a partir do agldv03:

```bash
ssh root@192.168.0.193 'obsidian search query="Proxmox" vault=llm-wiki format=json | head'
```

---

## 5. Bridge Git

Ficheiro: `scripts/obsidian/bridge-llm-wiki-git.sh`

Comportamento:

- `pull` — `git pull --rebase` com lockfile `/var/run/agl-llm-wiki-bridge.lock`
- `watch` — `inotifywait` em `wiki/` e `raw/` → debounce 30s → commit `docs(wiki): sync from obsidian hub` → push
- `push` — commit pendente + push
- Em conflito: abort rebase, log em `wiki/log.md`, alerta manual

**GitHub via `gh` (recomendado — sem deploy key):**

Script: `scripts/obsidian/setup-github-gh.sh`

```bash
# No CT193 (device flow, uma vez)
pct exec 193 -- bash /mnt/overpower/apps/dev/agl/agl-hostman/scripts/obsidian/setup-github-gh.sh
# ou interactivo: pct exec 193 -- gh auth login -h github.com -p https -w

# Propagar auth do agldv03 (se gh já autenticado aí)
bash scripts/obsidian/propagate-gh-auth-to-ct193.sh

# Verificar
pct exec 193 -- gh repo view AGLz/llm-wiki
pct exec 193 -- git -C /mnt/overpower/apps/dev/agl/llm-wiki remote -v
```

O bridge usa `gh auth setup-git` — `git pull`/`git push` em HTTPS com token gh.
Alternativa headless: `GH_TOKEN=... bash setup-github-gh.sh` (fine-grained PAT com repo write).

---

## 6. Tailscale (CT193)

Script: `scripts/proxmox/pct-tailscale-up-ct193-obsidian.sh` (no AGLSRV1)

Parâmetros canónicos LAN AGLSR1 (`docs/INFRA.md`):

```bash
tailscale up \
  --hostname=agl-obsidian-ct193 \
  --accept-dns=false \
  --accept-routes=false \
  --ssh \
  --accept-risk=lose-ssh
```

Após autenticar no link `login.tailscale.com`:

```bash
bash scripts/proxmox/pct-install-agl-lan-routes.sh 193
pct exec 193 -- tailscale ip -4
```

---

## 7. LiveSync — clientes

| Cliente | CouchDB URL |
|---------|-------------|
| Hub CT193 | `http://127.0.0.1:5984` |
| agldv03 / wk45 | `http://192.168.0.193:5984` ou `http://<tailscale-ct193>:5984` |
| Mobile | Tailscale + mesma URL |

Importar setup URI gerado no hub. **Não** usar Obsidian Sync oficial no mesmo vault.

---

## 8. Verificação

Ficheiro: `scripts/obsidian/verify-obsidian-ct.sh`

```bash
# No CT193 ou via SSH
curl -fsS http://127.0.0.1:5984/_up && echo OK couchdb
test -f /mnt/overpower/apps/dev/agl/llm-wiki/wiki/index.md && echo OK nfs
systemctl is-active obsidian-hub agl-llm-wiki-bridge
command -v obsidian && obsidian vaults
```

Hermes CT188 (leitura após push):

```bash
pct exec 188 -- head -5 /opt/llm-wiki/wiki/index.md
```

---

## 9. Verificação automática

```bash
bash scripts/obsidian/verify-obsidian-ct.sh
npm test -- --test-name-pattern=obsidian
```

---

## Troubleshooting

| Sintoma | Causa | Fix |
|---------|-------|-----|
| `libasound.so.2` / exit 127 | Falta ALSA em headless | `apt-get install -y libasound2` |
| `api.github.com` timeout | Rede AGLSRV1 lenta | `OBSIDIAN_VERSION=v1.8.9` no install |
| `dubious ownership` no git | NFS uid ≠ root CT | `git config --global --add safe.directory /mnt/.../llm-wiki` (bootstrap já faz) |
| Bridge não arranca | gh não autenticado / password CouchDB placeholder | `setup-github-gh.sh` + secção 2 |

---

## Referências

- [Obsidian Download](https://obsidian.md/download)
- [Obsidian CLI](https://obsidian.md/cli)
- [LiveSync + Proxmox LXC](https://www.madmode.com/2026/04/madmode-blog-237-issuecomment-4228178391)
- [CouchDB self-hosted sync](https://selfhosting.sh/apps/obsidian-sync/)
