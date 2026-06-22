---
name: agl-media
description: Stack media AGL (*arr, grabs, freeze) — scripts em agl-hostman/scripts/media/
---

# agl-media — Media \*arr AGL

## Documentação canónica

- `docs/MEDIA-ARR-STACK-AGL.md` — arquitectura, CTs, roadmap
- `docs/MEDIA-ARR-MAINTENANCE.md` — modos grabs-only / freeze / normal
- `scripts/media/README.md` — índice de scripts

## Modos

| Modo                 | Comando verificação                                                         |
| -------------------- | --------------------------------------------------------------------------- |
| Grabs only (default) | `bash /opt/agl-hostman/scripts/media/arr-freeze-downloads.sh --verify-only` |
| Freeze total         | `arr-freeze-downloads.sh --no-grabs`                                        |
| Normal               | `arr-unfreeze-downloads.sh` (só após espaço livre)                          |

## CTs (AGLSRV1)

| CT  | Serviço     | IP                 |
| --- | ----------- | ------------------ |
| 172 | Prowlarr    | 192.168.0.172:9696 |
| 123 | Radarr      | 192.168.0.123:7878 |
| 124 | Sonarr      | 192.168.0.124:8989 |
| 121 | qBittorrent | 192.168.0.121:8090 |
| 141 | SABnzbd     | 192.168.0.141      |
| 144 | Autobrr     | 192.168.0.144      |

## Regras

1. **Nunca** unfreeze downloads com pool `overpower` >95% sem aprovação humana.
2. API keys Servarr: ler `config.xml` **no CT** via `pct exec` — nunca commitar.
3. SSH host: `root@100.107.113.33` (Tailscale AGLSRV1).

## Cron Orion (referência)

Ver `scripts/proxmox/setup-hermes-orion-media-crons-ct188.sh`.
