# Performance — clientes de download (AGLSRV1)

Documentação de diagnóstico, optimização e benchmark para **qBittorrent (CT121)**, **aria2 (CT165)**, **Deluge (CT157)** e **SABnzbd (CT141)**, com contexto Proxmox/LXC e stack *arr*.

## Scripts

| Script | Uso |
|--------|-----|
| `scripts/media/download-clients-perf-optimize.sh` | Ajusta `qBittorrent.conf`, aria2, `LimitNOFILE` via systemd |
| `scripts/media/download-clients-perf-benchmark.sh` | Torrent Debian + aria2 + qBit + Deluge + SAB (NZB teste) |
| `scripts/media/download-clients-perf-benchmark-qbit-deluge.sh` | Só qBit CT121 vs Deluge CT157 (download fresco, comparação MiB/s) |
| `scripts/media/ct-download-mounts-apply.sh` | `mp0` overpower em CT121/141/157 (idempotente) |
| `scripts/media/ct157-deluge-auth-sync.sh` | Auth daemon Deluge alinhada ao Radarr |
| `scripts/media/_bench_qbit_ct121.py` | qBit: apaga `bench-qbit` + torrent, re-add, reporta `peak_MiBs` / `avg_MiBs` |
| `scripts/media/_bench_deluge_ct157.py` | Deluge: remove+re-add, `peak_MiBs` / `avg_MiBs`, poll 5 s |
| `scripts/media/_torrent_info_hash.py` | SHA1 info-hash do `.torrent` (polling qBit) |
| `scripts/media/ct165-aria2-improve.sh` | Hook Radarr, RPC, hardening CT165 |

```bash
# Optimizar (requer SSH a AGLSRV1)
bash scripts/media/download-clients-perf-optimize.sh --apply

# Benchmark (~755 MiB Debian netinst; aguardar WebUI qBit até 10 min)
TORRENT_URL="https://cdimage.debian.org/debian-cd/current/amd64/bt-cd/debian-13.5.0-amd64-netinst.iso.torrent" \
TORRENT_NAME="debian-13.5.0-amd64-netinst.iso" \
bash scripts/media/download-clients-perf-benchmark.sh --skip-optimize

# Só comparar qBit vs Deluge (sem aria2/SAB; download fresco)
bash scripts/media/download-clients-perf-benchmark-qbit-deluge.sh --skip-optimize
```

**Metodologia qBit (2026-06-03):** antes do teste, `torrents/delete` + `deleteFiles`, `rm -rf bench-qbit`, re-adiciona o `.torrent`. Evita falso positivo de 1 s com ficheiro já a 100%. Procurar no relatório `peak_MiBs` e `avg_MiBs`.

Torrent **~1 GiB** alternativo (quando mirror responder): Arch Linux — `https://archlinux.org/download/` ou `archlinux-x86_64.iso.torrent` nos mirrors oficiais.

## Resultados (2026-06-03, pós-limpeza CT121 + `--skip-optimize`)

Torrent: Debian 13.5.0 amd64 netinst (~755 MiB). **Sem alterações ao pool `overpower`**. CT121 com sessão vazia ([`QBIT-ARCHIVE-SPLIT.md`](QBIT-ARCHIVE-SPLIT.md) → arquivo no **CT221**).

| Cliente | CT | Tempo | Velocidade (pico / média) | Notas |
|---------|-----|-------|---------------------------|-------|
| **aria2** | 165 | **16 s** | **~58 MiB/s** | OK |
| **qBittorrent** | 121 | **1 s** | instantâneo (`uploading` 100%) | WebUI **0 s**; ISO já em `bench-qbit` ou rede local — API `info_hash` ~instantânea |
| **Deluge** | 157 | **73 s** | **~22 MiB/s** (pico) | OK; progresso 0–1 corrigido no script |
| **SABnzbd** | 141 | *falhou* | — | `sab_test_1000MB` **Failed**: *Cancelado, não é possível concluir* — re-testar com Usenet/fila limpa |

Relatório remoto: `/tmp/agl-download-perf-20260603-113624.txt` (AGLSRV1).

### Histórico (pré-limpeza CT121)

| Cliente | Tempo | Notas |
|---------|-------|-------|
| qBit (sessão ~600 torrents) | ~51–116 s | API ~225 MB; `missingFiles` antes de `bench-qbit` |
| SAB | — | Paused / 2–5 % durante freeze |

**Script:** polling qBit com `torrents/info?hashes=` + `_torrent_info_hash.py`. SAB: `filename` + `resume` por `nzo_id`.

Disco `dd` 1 GiB (overpower): CT121/141/157 ~1,4–1,7 GB/s após mounts — I/O não é o gargalo no Debian netinst.

**Pool host:** continuar **sem libertar espaço** em `overpower` até AGLSRV3; ver `docs/MEDIA-ARR-MAINTENANCE.md`.

## Causas identificadas (prioridade)

### 1. qBittorrent CT121 — arranque e carga

- **Resolvido (2026-06-03):** torrents legados no **CT221**; CT121 com `BT_backup` vazio → WebUI **&lt;1 s**, API leve.
- Antes: **~600 torrents** → restauro bloqueava WebUI (**5+ min**).
- Após `optimize --apply`, **não reiniciar** qBit sem necessidade.

### 2. Mounts `overpower` (aplicados 2026-06-02)

| CT | Serviço | `mp0` |
|----|---------|--------|
| 121 | qBittorrent | `/overpower/base` → `/mnt/overpower` |
| 141 | SABnzbd | `/overpower/base` → `/mnt/overpower` |
| 157 | Deluge | `/overpower/base` → `/mnt/overpower` |
| 165 | aria2 | `/overpower` → `/mnt/overpower` |

Script: `bash scripts/media/ct-download-mounts-apply.sh --apply` (para CTs 121, 141, 157).

**Não migrar dados antigos** no pool até haver espaço livre (AGLSRV3).

### 3. Trackers públicos em massa

- `Session\AddTrackersEnabled=true` + lista enorme em `Session\AdditionalTrackers` → tráfego HTTP announce desnecessário.
- **Corrigido:** `AddTrackersEnabled=false` (aplicar com qBit **parado** para não ser sobrescrito).
- Limpar `Session\AdditionalTrackers` manualmente ou via UI se ainda presente.

### 4. Limites de processo

- Shell `ulimit -n` = 1024; processo qBit/aria2: **`LimitNOFILE=65535`** em `systemd` drop-in (correcto).
- Antes: `MaxConnections=500` com ulimit 1024 → bottleneck.

### 5. Pool overpower quase cheio

- CT165 escreve no pool **97%** — risco de degradação ZFS; **não reactivar downloads *arr*** até libertar espaço (`docs/MEDIA-ARR-MAINTENANCE.md`).

### 6. Host AGLSRV1

- Load average **~15** — carga geral do nó, não só downloads.
- `pct set … queues=8` em veth **não suportado** neste PVE (erro schema).

## qBittorrent — parâmetros recomendados

Aplicados por `download-clients-perf-optimize.sh` (confirmar com serviço parado):

| Chave | Valor |
|-------|--------|
| `Session\AddTrackersEnabled` | `false` |
| `Session\MaxConcurrentHTTPAnnounces` | `50` |
| `Session\MaxActiveDownloads` | `8` |
| `Session\MaxActiveTorrents` | `12` |
| `Session\MaxConnections` | `300` |
| `Session\MaxConnectionsPerTorrent` | `80` |
| `Session\Preallocation` | `false` |

**UI (TRaSH / issues qBit):** Options → Advanced → Disk IO:

- **Disk IO type:** `Simple pread/pwrite`
- **Disable OS cache** para downloads (útil em ZFS)

## aria2 CT165

Ver `docs/CT165-ARIA2.md`. Parâmetros de benchmark: `split=16`, `max-connection-per-server=16`, `file-allocation=falloc`.

## Deluge CT157

- Daemon RPC **58846**; Web UI **8112** (não usada no benchmark).
- Credencial: Radarr **Deluge AGLSRV1** → `ct157-deluge-auth-sync.sh`.
- Benchmark: `scripts/media/_bench_deluge_ct157.py` (Twisted RPC; `resume_torrent` se pausado por freeze de manutenção).

### Porque Deluge pode ficar ~22 MiB/s vs aria2 ~58 MiB/s (hipóteses)

| Factor | CT157 Deluge | CT121 qBit / CT165 aria2 |
|--------|----------------|---------------------------|
| **vCPU** | **2** cores | **8** cores |
| **Cliente** | libtorrent via Deluge 2.x | aria2 nativo / qBit |
| **Limites** | `core.conf`: `max_connections`, `max_download_speed` | qBit/aria2 já optimizados no script `download-clients-perf-optimize.sh` |

O benchmark regista `core.conf` / `host.conf` no relatório. Se `max_download_speed` &gt; 0, é cap global. Comparar sempre **download fresco** (scripts removem ISO anterior).

**Próximos passos Deluge:** subir `cores` no LXC (teste A/B), alinhar `max_connections` ao qBit (~300), confirmar que não há rate limit na UI nem no plugin Label.

## SABnzbd CT141

- API **7777**; chave em Radarr **SABnzbd AGLSRV1**.
- Se arranque ficar em *Loading postproc queue*, renomear `history1.db` / `rss_data.sab` (backup `.bak-bench`) e reiniciar — ver notas da sessão de diagnóstico.
- NZB oficial: default **100 MB** (`test_download_100MB.nzb`); override com `SAB_TEST_NZB_URL=…1000MB.nzb`.

## Referências

- [qBittorrent #18827](https://github.com/qbittorrent/qBittorrent/issues/18827) — Disk IO / OS cache  
- [TRaSH Guides](https://trash-guides.info/) — download clients  
- `docs/MEDIA-ARR-STACK-AGL.md`, `docs/MEDIA-ARR-MAINTENANCE.md`
