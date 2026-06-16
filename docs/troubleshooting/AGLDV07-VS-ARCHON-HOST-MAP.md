# agldv07 vs archon — mapa de hosts

> **Correcção 2026-06-09:** documentação e scripts confundiam **agldv07** com **CT183 archon**.

## Resumo

| Nome        | VMID             | Proxmox     | Hostname Tailscale | IP Tailscale      | LAN                          |
| ----------- | ---------------- | ----------- | ------------------ | ----------------- | ---------------------------- |
| **agldv07** | **547** (ex.241) | **FGSRV7**  | `fgsrv07-agldv07`  | **100.64.175.89** | `192.168.70.241/24` (vmbr70) |
| **archon**  | **183**          | **AGLSRV1** | `aglsrv1-archon`   | **100.80.30.59**  | `192.168.0.183/24`           |

## Implicações operacionais

- Propagação OpenClaw / skills / Six Repos para **agldv07** → **`root@100.64.175.89`** — **não** usar `100.80.30.59` (archon).
- MCP Archon, RAG, UI Archon → **`100.80.30.59`** (CT183), independente de agldv07.
- WireGuard **10.6.0.21** pertence ao **archon** (CT183), não ao agldv07.
- **agldv07** (FGSRV7) usa rede **192.168.70.0/24** — regras Tailscale `accept-routes`/`accept-dns` da LAN AGL (`192.168.0.0/24`) **não** se aplicam da mesma forma que em CTs AGLSR1.

## Comandos úteis

```bash
## Restore disco CT547 (2026-06-09)

1. Disco OS real: `fileserver5-nfs:241/vm-241-disk-0.raw` (hardlink → `547/vm-547-disk-0.raw`).
2. **NFS como rootfs PVE** falha (`fastboot.tmp` read-only) — copiar para `bkp` local com `e2image -rapf` a partir de loop mount.
3. CT **privilegiado** (remover `unprivileged: 1` se clone falhar).
4. Após `pct start 547`: Tailscale em **NeedsLogin** — `pct exec 547 -- tailscale up --accept-dns=false --accept-routes=false --hostname=fgsrv07-agldv07 --ssh` (+ authkey ou URL browser).
5. **CT546** (fileserver7): disco local `bkp` foi removido para libertar espaço — repor de backup/NFS antes de arrancar.

# FGSRV7 — arrancar agldv07
ssh root@100.109.181.93 'pct start 547 && pct exec 547 -- tailscale ip -4'

# SSH directo (quando CT online)
ssh root@100.64.175.89

# Archon (sempre CT183 AGLSRV1)
ssh root@100.80.30.59
# ou via jump: ssh -J root@100.107.113.33 root@192.168.0.183
```

## Referências

- `docs/INFRA.md` — inventário Tailscale + CT547
- `docs/PROXMOX-VMID-RENUMBER-2026-06.md` — VMID 547
- `scripts/skills/propagate-six-repos.sh` — `AGLDV07_HOST`
