# CT165 — aria2 (AGLSRV1)

| Campo | Valor |
|-------|--------|
| **VMID** | 165 |
| **Hostname** | aria2 |
| **LAN** | 192.168.0.165 |
| **RPC** | `6800` (aria2 JSON-RPC; token em Radarr/Sonarr, não no Git) |
| **Web UI** | nginx `6880` (helper script; sites-enabled vazio — default nginx) |
| **Download dir** | `/mnt/overpower/downs/torDownloading` |
| **Completo (hook)** | `/mnt/overpower/downs/torFiles` (alinhado CT121 qBittorrent) |
| **Mount** | `mp0`: overpower → `/mnt/overpower` |
| **Recursos** | 4 GiB RAM, 8 cores (rightsizing opcional → 2 cores em modo freeze) |
| **Stack** | Cliente **Aria2 AGLSRV1** em Radarr/Sonarr — **desactivado** em modo [grabs only](MEDIA-ARR-MAINTENANCE.md) |

## Estado operacional (2026-06-02)

- CT **running**, `aria2` activo, sessão vazia (sem transferências).
- **overpower ~97%** — não reactivar downloads até expansão AGLSRV3 / espaço livre.
- Load average no CT espelha o **host** AGLSRV1 (~13), não carga do aria2.
- Hook `ariahook.sh` estava em falta no baseline; script `ct165-aria2-improve.sh --apply` recria-o.

## Melhorias aplicáveis

```bash
# Auditoria
bash scripts/media/ct165-aria2-improve.sh

# Config + apt + hook + restart aria2
bash scripts/media/ct165-aria2-improve.sh --apply

# Opcional: reduzir cores 8→2 (parar/iniciar CT)
bash scripts/media/ct165-aria2-improve.sh --apply --rightsize
```

| Melhoria | Motivo |
|----------|--------|
| Hook pós-download | Path completo para import *arr (torFiles) |
| `rpc-allow-origin-all=false` | Menos superfície RPC |
| Remover `save-session` duplicado | Config limpa |
| apt upgrade | OpenSSL security (Debian 12) |
| Rightsize CPU | 8 cores desnecessários com serviço idle |

## Segurança

- RPC com **secret** configurado; Radarr usa `192.168.0.165:6800`.
- Manter `rpc-listen-all` enquanto *arr estão em outros CTs na LAN; restringir com firewall se expuseres além de `192.168.0.0/24`.
- **Não** commitar `rpc-secret` nem API keys.

## Referências

- [MEDIA-ARR-STACK-AGL.md](MEDIA-ARR-STACK-AGL.md) — roadmap fases 0–7
- [MEDIA-ARR-MAINTENANCE.md](MEDIA-ARR-MAINTENANCE.md) — freeze / unfreeze
- `scripts/media/ct165-aria2-improve.sh`
