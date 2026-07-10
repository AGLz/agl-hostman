# AGLSRV3 — Clone aglfs3 (CT338) a partir de aglfs1 (CT178)

> **Data**: 2026-06-19  
> **Origem**: AGLSRV1 CT178 (`aglfs1` @ `192.168.0.178`)  
> **Destino**: AGLSRV3 CT338 (`aglfs3` @ `192.168.15.138`)  
> **Site**: AGLFG — fileserver local autónomo (sem mounts overpower/spark do SRV1)

## Contexto

O CT338 existente era um Debian vazio (script `pct-provision-aglfs3-from-ct178.sh`). Foi **substituído** por clone completo do CT178 (Samba, NFS, Tailscale, tuning) com storage remapeado para ZFS local `aglsrv3-tb`.

| Item          | AGLSRV1 (origem)        | AGLSRV3 (destino)                                 |
| ------------- | ----------------------- | ------------------------------------------------- |
| Host          | `100.107.113.33`        | `100.123.5.81`                                    |
| CT            | 178 `aglfs1`            | 338 `aglfs3`                                      |
| LAN           | `192.168.0.178`         | `192.168.15.138` (+ `.30.138` eth1)               |
| Tailscale     | `aglsrv1-aglfs1`        | **`aglsrv3-aglfs3`** (re-join pendente)           |
| Storage dados | overpower/spark no host | ZFS `aglsrv3-tb/{shares,overpower,power,storage}` |

## Script

```bash
# Dry-run
bash scripts/proxmox/pct-clone-aglfs3-from-ct178.sh --dry-run --replace

# Executar (destrói CT338 anterior)
bash scripts/proxmox/pct-clone-aglfs3-from-ct178.sh --apply --replace
```

Fluxo: `vzdump 178` (snapshot) → scp → `pct restore 338` → rede dual-LAN → mp ZFS → pós-clone guest.

Dump reutilizável: `/var/lib/vz/dump/vzdump-lxc-178-aglfs3-clone.tar.zst` (SRV1 e SRV3).

## Mount points (pós-clone)

| mp  | Host AGLSRV3           | Guest            |
| --- | ---------------------- | ---------------- |
| mp0 | `aglsrv3-tb/shares`    | `/mnt/shares`    |
| mp1 | `aglsrv3-tb/overpower` | `/mnt/overpower` |
| mp2 | `aglsrv3-tb/power`     | `/mnt/power`     |
| mp5 | `aglsrv3-tb/storage`   | `/mnt/storage`   |

**Não clonados** (paths SRV1): mp6–mp9 (`Extracted`, media legado).

## Pós-clone obrigatório

### Tailscale (identidade nova)

**Estado 2026-06-19:** **OK** — `aglsrv3-aglfs3` @ Tailscale **`100.89.170.85`** (CT338 `aglfs3`).

Com auth key (recomendado):

```bash
printf '%s' 'tskey-auth-…' > /root/.tailscale-authkey-aglfs3 && chmod 600 /root/.tailscale-authkey-aglfs3
bash scripts/proxmox/pct-tailscale-up-aglsrv3-aglfs3.sh
```

Interactivo (URL expira ~10 min):

```bash
ssh root@100.123.5.81
pct exec 338 -- tailscale up --accept-dns=false --hostname=aglsrv3-aglfs3 --ssh --accept-risk=lose-ssh
# Visitar URL impressa no browser (conta admin tailnet)
```

**Nunca** reutilizar `aglsrv1-aglfs1` (`100.69.187.105`).

### Verificação Samba / NFS

```bash
ssh root@100.123.5.81
pct exec 338 -- systemctl status smbd nfs-server
pct exec 338 -- exportfs -v
showmount -e 192.168.15.138   # desde AGLSRV5 (LAN AGLFG)
```

Exports herdados incluem `192.168.0.0/16` — válido para `192.168.15.x`.

## Setup cross-site (PBS + Samba/NFS + aglfs1 gateway)

```bash
# Um comando — PBS aglsrv3-tb + exports + aglfs1 gateway + link AGLSRV1
bash scripts/proxmox/aglsrv3-cross-site-setup.sh --apply
```

Documentação completa: [`AGLSRV3-PBS-FILESHARE.md`](AGLSRV3-PBS-FILESHARE.md)

## Acesso remoto (AGLSRV1 + PBS)

NFS via Tailscale **`aglsrv3-aglfs3` @ `100.89.170.85`** (use `nfsvers=3`).

```bash
# AGLSRV1 — ligar storages NFS + PBS remoto + mounts no aglsrv1-pbs (CT240)
bash scripts/proxmox/aglsrv3-pbs-host-proxy.sh --install   # no AGLSRV3
bash scripts/proxmox/aglsrv3-remote-storage-link.sh --apply --remote
```

| Destino AGLSRV1                                                       | Tipo | Origem                                   |
| --------------------------------------------------------------------- | ---- | ---------------------------------------- |
| `aglfs3-shares`, `aglfs3-overpower`, `aglfs3-power`, `aglfs3-storage` | NFS  | `100.89.170.85`                          |
| `pbs-aglsrv3-tb`                                                      | PBS  | `100.123.5.81:8007` (proxy host → CT318) |
| CT240 `mp1–mp4`                                                       | bind | `/mnt/pve/aglfs3-*` no PBS local         |

**Nota:** CT318 `aglsrv3-pbs` foi clone do PBS AGLSRV6 — identidade Tailscale colidia (`aglsrv6-pbs` / `100.70.155.60`). Proxy no host até re-auth com hostname `aglsrv3-pbs` (script futuro `pct-tailscale-up-aglsrv3-pbs.sh`).

## Recursos CT338 (herdados CT178)

- 16 cores, 16 GB RAM, 64 GB rootfs (`aglsrv3-tb`)
- Samba + NFS activos
- CT178 no SRV1 **intacto** (vzdump snapshot, sem paragem prolongada)

## Referências

- `docs/AGLSRV3-PIHOLE-CLONE.md` — padrão cross-site
- `docs/CT178-TAILSCALE-SETUP.md` — Tailscale aglfs1
- `docs/AGLFS1_NFS_MOUNT_CONFIGURATION.md` — clientes NFS
- `scripts/proxmox/aglsrv-vmid-map.env` — VMID 338, IPs
