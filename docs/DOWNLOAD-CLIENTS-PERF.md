# Performance — clientes de download (AGLSRV1)

Documentação de diagnóstico, optimização e benchmark para **qBittorrent (CT121)**, **aria2 (CT165)**, **Deluge (CT157)** e **SABnzbd (CT141)**, com contexto Proxmox/LXC e stack *arr*.

## Scripts

| Script | Uso |
|--------|-----|
| `scripts/media/download-clients-perf-optimize.sh` | Template **aria2 CT165**: LXC (cores/RAM/features), sysctl TCP, ulimit, qBit/Deluge/SAB/aria2 |
| `scripts/media/download-clients-perf-optimize.sh --fine-tune` | Camada 2 (~1 Gb/s): cache/buffers qBit, aria2 split, SAB, ZFS `recordsize` — ver [`DOWNLOAD-CLIENTS-FINE-TUNING-1GBPS.md`](DOWNLOAD-CLIENTS-FINE-TUNING-1GBPS.md) |
| `scripts/media/download-clients-perf-benchmark.sh` | Torrent Debian + aria2 + qBit + Deluge + SAB (NZB teste) |
| `scripts/media/download-clients-perf-benchmark-qbit-deluge.sh` | Só qBit CT121 vs Deluge CT157 (download fresco, comparação MiB/s) |
| `scripts/media/ct-download-mounts-apply.sh` | `mp0–mp9` iguais a CT123 Radarr em CT121/141/157/165 (`--apply --verify`) |
| `scripts/media/ct157-deluge-auth-sync.sh` | Auth daemon Deluge alinhada ao Radarr |
| `scripts/media/_bench_qbit_ct121.py` | qBit: apaga `bench-qbit` + torrent, re-add, reporta `peak_MiBs` / `avg_MiBs` |
| `scripts/media/_bench_deluge_ct157.py` | Deluge: remove+re-add, `peak_MiBs` / `avg_MiBs`, poll 5 s |
| `scripts/media/_torrent_info_hash.py` | SHA1 info-hash do `.torrent` (polling qBit) |
| `scripts/media/ct165-aria2-improve.sh` | Hook Radarr, RPC, hardening CT165 |
| `scripts/media/download-clients-phase-a.sh` | **Fase A:** iperf3, SAB prep/teste — ver [`DOWNLOAD-CLIENTS-ROADMAP.md`](DOWNLOAD-CLIENTS-ROADMAP.md) |
| `scripts/media/arr-data-paths-verify.sh` | Paths TRaSH em CT121/123/124/141/165 |

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

## Resultados (2026-06-03, pós-mounts *arr* + fine-tune)

Torrent: Debian 13.5.0 amd64 netinst (~755 MiB). Mounts **mp0–mp9** = CT123 em CT121/141/157/165. Comando: `download-clients-perf-benchmark.sh --skip-optimize`

| Cliente | CT | Download | Pico | Média | Notas |
|---------|-----|----------|------|-------|-------|
| **aria2** | 165 | **17 s** | **~76 MiB/s** (log) / **53 MiB/s** (avg report) | — | path `bench-aria2` em `/mnt/overpower/downs/` |
| **qBittorrent** | 121 | **35 s** | **45,66 MiB/s** | **21,52 MiB/s** | WebUI **167 s** até pronta (restauro) |
| **Deluge** | 157 | **40 s** | **24,96 MiB/s** | **18,85 MiB/s** | 8 cores |
| **SABnzbd** | 141 | *falhou* | — | — | NZB teste cancelado (igual corridas anteriores) |

Relatório: `/tmp/agl-download-perf-20260603-122136.txt` (AGLSRV1).

**qBit ~2× pico** vs corrida pré-mounts (~22 MiB/s) — alinhamento `mp1` + fine-tune; aria2 mantém liderança no mesmo torrent.

### Benchmark completo torrent (2026-06-03, `--skip-sab`)

Torrent Debian netinst (~755 MiB). Relatório: `/tmp/agl-download-perf-20260603-192403.txt`.

| Cliente | CT | Tempo | Pico | Média (download) |
|---------|-----|-------|------|------------------|
| **aria2** | 165 | **20 s** | **~75 MiB/s** (log) | **~52 MiB/s** (summary aria2) |
| **qBittorrent** | 121 | 45 s | **34,79 MiB/s** | **16,73 MiB/s** |
| **Deluge** | 157 | 60 s | 16,72 MiB/s | 12,57 MiB/s |

Comando: `bash scripts/media/download-clients-perf-benchmark.sh --skip-optimize --skip-sab`

**Leitura:** aria2 continua a liderar no mesmo torrent; qBit variou vs corrida das 12h (pico **45,66** → **34,79**) — swarm/carga do host (load ~10). `pct exec … ulimit -n` ainda mostra **1024**; processos do serviço têm **65535** via systemd (`prlimit` no PID do qbittorrent/deluged se precisares confirmar).

### Fase A — medição de linha (2026-06-03)

Script: `download-clients-phase-a.sh --apply --sab-test`. Relatório: `/tmp/agl-download-phase-a-20260603-124938.txt` (AGLSRV1).

| Teste | Resultado |
|-------|-----------|
| iperf3 CT121 → host (4 streams, 10 s) | **~21,2 Gbit/s** agregado — veth/LAN interna não limita 1 GbE |
| iperf3 host → 192.168.0.1 | SKIP (sem `iperf3 -s` no gateway) |
| paths TRaSH | OK (`arr-data-paths-verify.sh`) |
| SAB NZB oficial 100 MB | **Failed** `not-complete` — usar NZB no NNTP de produção |
| ulimit CT121 pós `--apply` optimize | **65535** |

Detalhe e checklist: [`DOWNLOAD-CLIENTS-ROADMAP.md`](DOWNLOAD-CLIENTS-ROADMAP.md).

### Corrida anterior (só qBit vs Deluge, pré-mounts unificados)

Torrent: Debian 13.5.0 amd64 netinst (~755 MiB). CT121 sessão limpa ([`QBIT-ARCHIVE-SPLIT.md`](QBIT-ARCHIVE-SPLIT.md)).

Comando: `bash scripts/media/download-clients-perf-benchmark-qbit-deluge.sh --skip-optimize`

| Cliente | CT | Tempo total | Pico | Média (download) | Notas |
|---------|-----|-------------|------|------------------|-------|
| **qBittorrent** | 121 | **67 s** | **22,33 MiB/s** | **12,56 MiB/s** | `bench-qbit` apagado antes do teste |
| **Deluge** | 157 | **32 s** | **25,54 MiB/s** | **18,85 MiB/s** | pico ligeiramente &gt; qBit |

Relatório: `/tmp/agl-download-perf-20260603-114607.txt` (AGLSRV1).

**Conclusão provisória:** ~22–25 MiB/s **não é só Deluge** — qBit no mesmo torrent ficou na mesma ordem (pico ~22 MiB/s). O teste de **1 s no qBit** era falso positivo (ISO já completo). **aria2 ~58 MiB/s** (corrida anterior) aponta para tuning libtorrent / conexões ou carga do host, não um cap exclusivo do Deluge.

### Corrida anterior (pré-download-fresco)

| Cliente | CT | Tempo | Velocidade | Notas |
|---------|-----|-------|------------|-------|
| **aria2** | 165 | **16 s** | **~58 MiB/s** | OK |
| **qBittorrent** | 121 | **1 s** | falso positivo | ISO já em `bench-qbit` |
| **Deluge** | 157 | **73 s** | **~22 MiB/s** (pico) | OK |
| **SABnzbd** | 141 | *falhou* | — | NZB teste cancelado |

Relatório: `/tmp/agl-download-perf-20260603-113624.txt` (AGLSRV1).

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

### 2. Mounts (igual CT123 Radarr — aplicados 2026-06-03)

| Slot | Host → CT | Uso |
|------|-----------|-----|
| mp0 | `/mnt/shares` → `/mnt/shares` | Partilhas |
| mp1 | `/overpower/base` → `/mnt/overpower` | Media + `downs/` (*arr*) |
| mp2 | `/spark/base` → `/mnt/power` | Legado |
| mp5–mp9 | `/mnt/storage` + aliases Extracted | Biblioteca mergerfs |

**CT121, 141, 157, 165:** perfil idêntico a CT123/124/113. Script: `bash scripts/media/ct-download-mounts-apply.sh --apply --verify`

**aria2:** `dir=/mnt/overpower/downs/...` passa a gravar em `/overpower/base/downs` no host (antes `mp0` apontava à raiz `/overpower/downs` ~737 MiB legado).

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

## Template aria2 CT165 (referência para alinhar)

| Parâmetro | CT165 aria2 | Alvo CT121/157/141 |
|-----------|-------------|---------------------|
| **cores** | 8 | 121: 8 · 157: **8** (era 2) · 141: **4** (Usenet) |
| **memory** | 4096 MiB | 121: 8192 (mantém) · 157: **4096** · 141: 4096 |
| **features** | fuse, mount nfs;cifs, nesting | Aplicar em 121/141/157 |
| **mp1** | `/overpower/base` → `/mnt/overpower` | Todos os download CTs (mp0 = shares) |
| **Peers/conexões** | split=16, bt-max-peers=80, max-concurrent=8 | qBit 300/80/8 · Deluge 300/80/8 |
| **Disco torrent** | `file-allocation=falloc` | qBit Preallocation=false + Disk IO simple |
| **Rede CT** | sysctl `tcp_rmem`/`wmem` elevados | `99-agl-download.conf` em todos |
| **ulimit** | 65535 | systemd `LimitNOFILE` + limits.conf |

```bash
bash scripts/media/download-clients-perf-optimize.sh --apply
bash scripts/media/download-clients-perf-benchmark-qbit-deluge.sh --skip-optimize
```

**Nota mp0:** aria2 grava em `/overpower/downs` (raiz do pool); qBit/Deluge/SAB usam `/overpower/base/downs` (biblioteca media). Unificar o mount quebraria os paths do Radarr sem migração.

## Deluge CT157

- Daemon RPC **58846**; Web UI **8112** (não usada no benchmark).
- Credencial: Radarr **Deluge AGLSRV1** → `ct157-deluge-auth-sync.sh`.
- Benchmark: `scripts/media/_bench_deluge_ct157.py` (Twisted RPC; `resume_torrent` se pausado por freeze de manutenção).
- CT157: `firewall=1` removido do `net0` no optimize (veth sem filtro PVE extra).

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
