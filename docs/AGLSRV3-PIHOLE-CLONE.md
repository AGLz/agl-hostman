# AGLSRV3 — Clone Pi-hole (CT117 pihole3)

> **Data**: 2026-05-28  
> **Origem**: AGLSRV1 CT102 (`pihole` @ `192.168.0.102`)  
> **Destino**: AGLSRV3 CT117 (`pihole3` @ `192.168.15.102`)  
> **Site**: AGLFG (LAN `192.168.15.0/24`) — **sem rota LAN** para Pi-hole AGLHQ

## Contexto

O AGLSRV3 está num site físico remoto (segmento `192.168.15.0/24`). O host **não** alcança o Pi-hole central em `192.168.0.102` (AGLHQ). Foi clonado o CT102 via `vzdump` + restore cross-site para DNS local autónomo.

| Item | AGLSRV1 (origem) | AGLSRV3 (destino) |
|------|------------------|-------------------|
| Host | `100.107.113.33` / `192.168.0.245` | `100.123.5.81` / `192.168.15.247` |
| CT | 102 `pihole` | 117 `pihole3` |
| LAN DNS | `192.168.0.102` | `192.168.15.102` |
| Tailscale | `aglsrv1-pihole` (`100.114.66.80`) | `aglsrv3-pihole` (**join pendente**) |

## Procedimento executado (2026-05-28)

```bash
# AGLSRV1 — backup
vzdump 102 --mode stop --compress zstd --storage local

# Transferência (Tailscale)
rsync -avP root@100.107.113.33:/var/lib/vz/dump/vzdump-lxc-102-*.tar.zst /var/lib/vz/dump/

# AGLSRV3 — restore (rootfs 12G; unprivileged → ignore unpack errors)
pct restore 117 /var/lib/vz/dump/vzdump-lxc-102-2026_05_28-11_31_00.tar.zst \
  --storage local-lvm --rootfs local-lvm:12 --ignore-unpack-errors 1

# Rede CT117
pct set 117 -hostname pihole3 -tags aglsrv3,dns,pihole
pct set 117 -net0 name=eth0,bridge=vmbr0,ip=192.168.15.102/24,gw=192.168.15.1,type=veth

# Pós-clone no CT117
systemctl disable --now wg-quick@wg0 2>/dev/null || true
tailscale logout  # remover identidade aglsrv1-pihole herdada
# DHCP Pi-hole: desactivado no clone (evitar conflito com CT102)

# DNS do host AGLSRV3
# /etc/resolv.conf → 192.168.15.102, 1.1.1.1, 8.8.8.8
# tailscale set --accept-dns=false
```

## Tailscale join (CT117)

Script: `scripts/proxmox/pct-tailscale-up-aglsrv3-pihole.sh`

**Opção A — auth key (recomendado, não interactivo):**

1. [Tailscale Admin → Settings → Keys](https://login.tailscale.com/admin/settings/keys) — criar chave **reusable** (opcional: tag `tag:server`).
2. No AGLSRV3:

```bash
printf '%s' 'tskey-auth-…' > /root/.tailscale-authkey && chmod 600 /root/.tailscale-authkey
bash /path/to/agl-hostman/scripts/proxmox/pct-tailscale-up-aglsrv3-pihole.sh
pct exec 117 -- tailscale ip -4   # anotar IP 100.x para docs/INFRA.md
```

**Opção B — login interactivo:**

```bash
ssh root@100.123.5.81
pct exec 117 -- tailscale up --accept-dns=false --hostname=aglsrv3-pihole --ssh --accept-risk=lose-ssh
# Visitar URL impressa (expira em ~10 min) com conta admin da tailnet
```

**Verificação:**

```bash
pct exec 117 -- tailscale status --peers=false
pct exec 117 -- tailscale ip -4
```

## Verificação Pi-hole

```bash
# Web UI
http://192.168.15.102/admin

# DNS
dig @192.168.15.102 google.com +short

# Host AGLSRV3
grep nameserver /etc/resolv.conf
```

## Notas operacionais

- **Nunca** reutilizar hostname/identidade `aglsrv1-pihole` no clone.
- WireGuard legado **dentro** do CT117 (herdado do clone) deve ficar **desactivado**.
- CT102 no AGLSRV1 permanece **intacto** e é o Pi-hole de produção AGLHQ.
- Backup vzdump no AGLSRV3 (`/var/lib/vz/dump/vzdump-lxc-102-*.tar.zst`) pode ser removido após validação.

## Referências

- `docs/HOSTS.md` — secção AGLSRV3
- `docs/TOPOLOGY.md` — site AGLFG / papel AGLSRV3
- `docs/INFRA.md` — tabela Tailscale
- `scripts/proxmox/pct-tailscale-up-aglsrv3-pihole.sh`
