# Scripts — stack media (*arr)

| Script | Função |
|--------|--------|
| [`arr-freeze-downloads.sh`](arr-freeze-downloads.sh) | **Por defeito:** downloads OFF, **grabs ON** (Prowlarr RSS/auto). `--no-grabs` = parar tudo |
| [`arr-enable-grabs.sh`](arr-enable-grabs.sh) | Só Prowlarr RSS/auto ON (downloads continuam OFF) |
| [`arr-unfreeze-downloads.sh`](arr-unfreeze-downloads.sh) | Reactiva clientes + Prowlarr + Autobrr (após espaço em disco) |
| [`ct165-aria2-improve.sh`](ct165-aria2-improve.sh) | Auditoria/melhorias CT165 aria2 (`--apply`, opcional `--rightsize`) |
| [`download-clients-perf-optimize.sh`](download-clients-perf-optimize.sh) | Alinha CT121/141/157/165 ao template aria2 (`--apply`); `--fine-tune` para ~1 Gb/s |
| [`../../docs/DOWNLOAD-CLIENTS-FINE-TUNING-1GBPS.md`](../../docs/DOWNLOAD-CLIENTS-FINE-TUNING-1GBPS.md) | Pesquisa + fine-tuning (ZFS, libtorrent, SAB, limites LXC) |
| [`../../docs/DOWNLOAD-CLIENTS-ROADMAP.md`](../../docs/DOWNLOAD-CLIENTS-ROADMAP.md) | Roadmap fases A–D (~1 Gb/s) |
| [`download-clients-phase-a.sh`](download-clients-phase-a.sh) | Fase A: iperf3 + SAB (opcional) |
| [`arr-download-clients-consolidate.sh`](arr-download-clients-consolidate.sh) | qBit único torrent nos *arr* (`--apply`) |
| [`arr-data-paths-verify.sh`](arr-data-paths-verify.sh) | Verificar paths *arr* / TRaSH |
| [`download-clients-perf-benchmark-qbit-deluge.sh`](download-clients-perf-benchmark-qbit-deluge.sh) | Benchmark só qBit vs Deluge (download fresco) |
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
