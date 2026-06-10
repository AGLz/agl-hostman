# Renumeração Proxmox VMID — Junho 2026

**Estado:** aplicada em **AGLSRV5**, **AGLSRV6** e **FGSRV7** (faixas 500–599 e 600–699).  
**AGLSRV1 / AGLSRV3:** sem renumber global nesta fase (AGLSRV3 tem mapa próprio 300–399).

Mapa fonte: `scripts/proxmox/aglsrv-vmid-map.env` · scripts: `pct-renumber.sh`, `pbs-setup-renumbered-hosts.sh`.

## Regra rápida

| Host | Faixa VMID | PBS |
|------|------------|-----|
| AGLSRV5 | 528–540 (CTs 530–539) | **540** aglsrv5-pbs |
| FGSRV7 | 545–571 | **545** fgsrv7-pbs |
| AGLSRV6 | 600–622 | **613** man6-pbs |

**IPs LAN:** a maioria dos CTs manteve o **último octeto** (ex. EvoNexus continua `192.168.70.242` no **CT548**). Comandos `pct exec` e jobs PBS devem usar o **VMID novo**.

---

## FGSRV7 (verificado 2026-06-06)

| VMID novo | VMID antigo | Nome | IP LAN (typ.) | Notas |
|-----------|-------------|------|---------------|--------|
| **545** | — | fgsrv7-pbs | 191.252.93.245 | PBS |
| **546** | 240 | fileserver7 | — | stopped |
| **547** | 241 | agldv07 | **192.168.70.241** | Dev satélite; TS **`fgsrv07-agldv07`** **`100.64.139.79`** — **≠ CT183 archon** (AGLSRV1) |
| **548** | **242** | **evonexus** | **192.168.70.242** | EvoNexus / evo.aglz.io |
| **549** | 243 | fg-legacy | 192.168.70.243 | |
| **550** | 244 | fg-ngrok | 192.168.70.244 | |
| **561** | 535 | mysql7 | 192.168.70.235 | MySQL HA master |
| **562** | 539 | pihole7 | 192.168.70.139 | |
| **570** | **170** | cloudflared7 | 192.168.70.170 | Túnel fgsrv7 |
| **571** | **171** | cloudflared7b | 192.168.70.171 | Túnel fgsrv7b |

SSH host: `root@100.109.181.93` (`FGSRV7_SSH`).

### EvoNexus (CT242 → CT548)

```bash
# No fgsrv7
pct exec 548 -- docker compose -f /opt/evonexus/docker-compose.hub.yml ps
bash scripts/proxmox/bootstrap-ct242-evonexus.sh   # CTID=548 por omissão
bash scripts/proxmox/pct-sync-evonexus-189-to-242.sh  # CT_TARGET=548 por omissão
```

Runbook: `scripts/proxmox/RESTORE-CT242-EVONEXUS.md` (nome histórico; VMID actual **548**).

### Cloudflare (CT170/171 → CT570/571)

IPs **inalterados** (`192.168.70.170` / `.171`). Actualizar só `pct exec`:

```bash
ssh root@100.109.181.93 'pct exec 570 -- systemctl status cloudflared'
ssh root@100.109.181.93 'pct exec 571 -- tailscale ip -4'
```

---

## AGLSRV5 (verificado 2026-06-06)

| VMID novo | VMID antigo | Nome | Notas |
|-----------|-------------|------|--------|
| **530** | 130 | cloudflared5 | Túnel aglsrv5 |
| **532** | 132 | plex5 | |
| **533** | 133 | mesh5 | |
| **534** | 134 | ipmitool5 | |
| **535** | 135 | mysql5 | MySQL HA slave |
| **536** | **136** | **agldv05** | Dev |
| **538** | 138 | fileserver5 | |
| **539** | 139 | pihole5 | |
| **540** | — | aglsrv5-pbs | PBS |

VMs: **528** (aglwk79, ex.128), **531** (UbuntuDesktop7, ex.131). VM **127** (server) — renumber manual pendente.

SSH: `root@100.119.223.113` (`AGLSRV5_SSH`).

---

## AGLSRV6 (verificado 2026-06-06)

| VMID novo | VMID antigo | Nome | Notas |
|-----------|-------------|------|--------|
| **601** | 101 | cloudflared6 | |
| **602** | 102 | meshcentral6 | |
| **604** | 104 | luzdivina | |
| **608** | **108** | **agldv06** | Dev (`192.168.0.108`) |
| **609** | 109 | redis6 | |
| **610** | 110 | mssql6 | |
| **611** | 111 | aluzdivina | |
| **613** | **113** | **man6-pbs** | PBS template canónico |
| **614** | 114 | cloudflared6b | |
| **616** | 116 | wgtest-priv | |
| **617** | 117 | pihole6 | |
| **621** | 121 | wireguard-aglsrv6 | |
| **622** | 201 | CT201 | |

VMs: **600** SSPADLD01, **603** opnsense, **605** aglhq26, **606** UbuntuDesktop, **612** dell-ome, **620** WinServer2016.

**Pendente:** CT **107** (kuber601) — conflito rootfs com PBS antigo; não renumerado automaticamente.

SSH: `root@100.98.108.66` (`AGLSRV6_SSH`).

---

## Variáveis canónicas (scripts)

Sourced de `scripts/proxmox/aglsrv-vmid-map.env`:

```bash
FGSRV7_CT_EVONEXUS=548
FGSRV7_CT_CLOUDFLARED=570
FGSRV7_CT_CLOUDFLARED_B=571
AGLSRV5_CT_CLOUDFLARED=530
AGLSRV5_CT_AGLDV05=536
AGLSRV6_CT_AGLDV06=608
AGLSRV6_PBS_VMID=613
```

---

## Documentação a actualizar quando referir VMIDs antigos

- `docs/INFRA.md`, `docs/HOSTS.md`, `docs/CLOUDFLARE-TUNNELS.md`
- `docs/PROXMOX-CLUSTER-AGLSRV5-FGSRV7.md`
- Scripts `scripts/proxmox/*242*`, `scripts/evonexus/*ct242*`
- `AGENTS.md`, `CLAUDE.md`, skills `proxmox-agl`

**Legado:** pastas de backup `backups-ct242-evonexus/` mantêm o nome histórico.
