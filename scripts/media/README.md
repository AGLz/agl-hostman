# Scripts — stack media (*arr)

| Script | Função |
|--------|--------|
| [`arr-freeze-downloads.sh`](arr-freeze-downloads.sh) | **Por defeito:** downloads OFF, **grabs ON** (Prowlarr RSS/auto). `--no-grabs` = parar tudo |
| [`arr-enable-grabs.sh`](arr-enable-grabs.sh) | Só Prowlarr RSS/auto ON (downloads continuam OFF) |
| [`arr-unfreeze-downloads.sh`](arr-unfreeze-downloads.sh) | Reactiva clientes + Prowlarr + Autobrr (após espaço em disco) |
| [`ct165-aria2-improve.sh`](ct165-aria2-improve.sh) | Auditoria/melhorias CT165 aria2 (`--apply`, opcional `--rightsize`) |
| [`download-clients-perf-optimize.sh`](download-clients-perf-optimize.sh) | Tuning qBit CT121 + aria2 CT165 (`--apply`) |
| [`download-clients-perf-benchmark.sh`](download-clients-perf-benchmark.sh) | Benchmark Debian netinst (~755 MiB): aria2, qBit, Deluge, SAB (100 MB NZB) |
| [`_torrent_info_hash.py`](_torrent_info_hash.py) | Info-hash para API qBittorrent |

**Documentação:** [`docs/MEDIA-ARR-STACK-AGL.md`](../../docs/MEDIA-ARR-STACK-AGL.md), [`docs/MEDIA-ARR-MAINTENANCE.md`](../../docs/MEDIA-ARR-MAINTENANCE.md), [`docs/CT165-ARIA2.md`](../../docs/CT165-ARIA2.md), [`docs/DOWNLOAD-CLIENTS-PERF.md`](../../docs/DOWNLOAD-CLIENTS-PERF.md).

**Host:** `AGLSRV1` — `ssh root@100.107.113.33` (override: `AGLSRV1=root@lan`).

```bash
# Verificar freeze
bash scripts/media/arr-freeze-downloads.sh --verify-only

# Congelar de novo
bash scripts/media/arr-freeze-downloads.sh
```

API keys são lidas nos CTs via `config.xml` — não são guardadas neste repositório.
