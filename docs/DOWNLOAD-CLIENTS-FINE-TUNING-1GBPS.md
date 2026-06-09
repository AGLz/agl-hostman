# Fine-tuning — clientes de download (~1 Gb/s)

Pesquisa consolidada (2026-06) para **qBittorrent CT121**, **Deluge CT157**, **aria2 CT165**, **SABnzbd CT141** no AGLSRV1, com link ~1 Gb/s (~**125 MiB/s** teórico).

**Contexto AGL:** benchmarks com Debian netinst público ficaram ~**22–27 MiB/s** (qBit/Deluge) e ~**58 MiB/s** (aria2). Isso **não esgota** 1 Gb/s — ver secção «Expectativa realista».

Scripts existentes:

| Script | Função |
|--------|--------|
| `scripts/media/download-clients-perf-optimize.sh` | LXC + ulimit + tuning base (já aplicado) |
| `scripts/media/download-clients-perf-optimize.sh --fine-tune` | Camada 2: libtorrent/aria2/SAB avançado + sysctl host ZFS |
| `scripts/media/download-clients-perf-benchmark-qbit-deluge.sh` | Validar pico/média após mudanças |

---

## Expectativa realista (1 Gb/s vs medições)

| Factor | Impacto |
|--------|---------|
| **Swarm / peers** | ISO Debian público raramente entrega centenas de MiB/s sustentados; o limite é **peers**, não a linha. |
| **Protocolo** | BitTorrent = I/O **aleatório** (16 KiB); Usenet/HTTP multi-conexão satura melhor a GbE ([limbenjamin.com](https://limbenjamin.com/articles/saturating-1gbps-bandwidth.html)). |
| **LXC veth** | **Sem multiqueue** no veth Linux; CTs não usam SR-IOV → teto de CPU por interface ([Proxmox forum](https://forum.proxmox.com/threads/network-performance-vps-with-8-network-queue-or-lxc.71194/)). |
| **ZFS `overpower`** | Escritas aleatórias; `recordsize` e `zfs_dirty_data_max` no **host** importam mais que `vm.dirty_*` **dentro** do CT ([OpenZFS BitTorrent](https://openzfs.github.io/openzfs-docs/Performance%20and%20Tuning/Workload%20Tuning.html)). |
| **Carga do host** | Load average ~12 no AGLSRV1 compete com CPU/rede dos CTs. |

Para **validar a linha a ~1 Gb/s**, usar **iperf3** para um servidor na LAN/Internet, ou **SABnzbd** com servidor Usenet rápido + cache grande ([wiki SAB](https://sabnzbd.org/wiki/advanced/highspeed-downloading)), não só um torrent público.

---

## Camada 1 — Host Proxmox + ZFS (maior ROI para torrents em ZFS)

Aplicar no **AGLSRV1** (não dentro dos CTs). Pool `overpower` ~97% — **não** expandir dados; só tuning.

### Dataset de downloads (`overpower/base` ou subdataset `…/downs`)

| Parâmetro | Recomendação | Fonte |
|-----------|--------------|--------|
| `recordsize` | **1M** no dataset onde caem torrents ativos (`bench-*`, `torDownloading`) | [OpenZFS BitTorrent](https://openzfs.github.io/openzfs-docs/Performance%20and%20Tuning/Workload%20Tuning.html), [Practical ZFS](https://discourse.practicalzfs.com/t/zfs-performance-tuning-for-bittorrent/1789) |
| `atime` | `off` no dataset | ADMIN Magazine / ZFS speed |
| `compression` | `off` ou `lz4` (lz4 usa CPU; testar) | — |
| `xattr` | `sa` + `dnodesize=auto` se ainda não estiver | OpenZFS workload |

Exemplo (ajustar caminho do dataset real no host):

```bash
# No AGLSRV1 — confirmar dataset com: zfs list -r overpower | grep base
zfs set recordsize=1M atime=off compression=off overpower/base
# Ou só subdataset de downloads:
# zfs set recordsize=1M overpower/base/downs
```

### Módulo ZFS (host)

| Parâmetro | Sugestão | Nota |
|-----------|----------|------|
| `zfs_dirty_data_max` | Subir se writes “engasgam” (ex. 512M–2G conforme RAM livre) | Controla buffer de escrita ZFS, **não** `vm.dirty_bytes` |
| `zfs_arc_max` | Limitar se CTs + host disputam RAM (ex. 50% RAM útil) | ARC ≠ page cache |

`vm.dirty_bytes` / `vm.dirty_ratio` no CT **quase não afectam** I/O em ficheiros no pool ZFS ([Big Iron](https://www.bigiron.cc/guides/understanding-and-tuning-the-page-cache-on-debian)); no **host**, `vm.dirty_background_bytes=128M` e `vm.dirty_bytes=256M` ajudam **outros** FS (ext4 root), como sugerido no [issue qBit #22674](https://github.com/qbittorrent/qBittorrent/issues/22674).

### Rede LXC (limite estrutural)

- **veth não tem multiqueue** → para >~10 Gb/s entre CTs ou saturar 1 GbE com um fluxo único, só **SR-IOV / NIC passthrough** ([Proxmox](https://forum.proxmox.com/threads/lxc-multiqueue-and-rss.179431/)).
- Bridge `vmbr0` + firewall CT157: já removido `firewall=1` no optimize.
- **Bridge offload:** no host, `ethtool -K vmbr0` / NIC física — manter TSO/GRO coerente (evitar mixes que degradam VLAN routing, [forum virtio](https://forum.proxmox.com/threads/virtio-performance-and-offloading.149601/)).

---

## Camada 2 — qBittorrent CT121 (libtorrent 2.x)

Já aplicado: Simple pread/pwrite, 300/80 conexões, 8 downloads activos, trackers extra off.

### Ajustes adicionais (fine-tune)

| Setting (UI / `qBittorrent.conf`) | Valor sugerido | Motivo |
|-----------------------------------|----------------|--------|
| **Disk IO type** | Simple pread/pwrite | Evita mmap/dirty pages ([PR #21300](https://github.com/qbittorrent/qBittorrent/pull/21300), [#22674](https://github.com/qbittorrent/qBittorrent/issues/22674)) |
| **Disk cache** | **512–2048 MiB** (ou -1 auto se RAM sobra) | Fórum qBit ~500 Mbit+ ([t=5343](https://forum.qbittorrent.org/viewtopic.php?t=5343)); reduz overload |
| **Disk cache expiry** | **600 s** | Mesma fonte |
| **Async I/O threads** | **8** (`Session\AsyncIOThreadsCount`) | Alinhar a vCPUs; libtorrent usa threads para disco ([aio_threads](https://libtorrent.org/reference-Settings.html#aio_threads)) |
| **uTP/TCP mixed mode** | **Prefer TCP** | Evita quedas quando uTP oscila ([fórum](https://forum.qbittorrent.org/viewtopic.php?t=5343)) |
| **Send buffer watermark** | **5000–9000** | Pipeline upload; evita stalls ([t=7107](https://forum.qbittorrent.org/viewtopic.php?t=7107)) |
| **Send buffer low watermark** | **400–500** | Idem |
| **Send buffer watermark factor** | **150** | Idem |
| **Guided read cache** | On | Menos RAM, melhor cache ([wiki Options](https://github.com/qbittorrent/qBittorrent/wiki/Explanation-of-Options-in-qBittorrent)) |
| **Send upload piece suggestions** | On | Peers “HAVE FAST” |
| **Coalesce read & write** | On | Menos syscalls |
| **Upload slots** | Global ~20, por torrent ~10 | Evita abrir slots ilimitados ([PR #12162](https://github.com/qbittorrent/qBittorrent/pull/12162)) |
| **Port** | Aleatório 49160–65534 + forward | TRaSH / boas práticas |

**Não** subir `AsyncIOThreadsCount` para 16+ em HDD/ZFS com muitos torrents — pode piorar ([issue #11461](https://github.com/qbittorrent/qBittorrent/issues/11461)).

---

## Camada 2 — Deluge CT157 (libtorrent via core + **ltConfig**)

`core.conf` já alinhado (300 conn, 8 downloads, cache 1024).

### Próximo passo recomendado: plugin **ltConfig**

Expõe `settings_pack` do libtorrent ([libtorrent tuning](http://libtorrent.org/tuning.html), preset [HIGH_PERFORMANCE_SEED](https://github.com/ratanakvlun/deluge-ltconfig/blob/master/ltconfig/common/presets.py)):

| Setting ltConfig | Valor orientativo | Equivalente aria2 / notas |
|------------------|-------------------|---------------------------|
| `connections_limit` | 300–8000 | Já 300 em core.conf |
| `aio_threads` | **8** | Como aria2 paralelismo disco |
| `recv_socket_buffer_size` / `send_socket_buffer_size` | **1048576** (1 MiB) | Preset high perf |
| `cache_size` | **65536** (KiB no preset = 64 MiB) vs 1024 no core | Testar incremental |
| `file_pool_size` | **500** | Menos open/close em muitos ficheiros |
| `unchoke_slots_limit` | **200–500** | Upload slots |
| `mixed_mode_algorithm` | **Prefer TCP** (se disponível na versão) | Como qBit |

Instalação: [deluge-ltconfig](https://github.com/zakkarry/deluge-ltconfig) (Deluge 2.x). **TRaSH Deluge:** limitar half-open ~100–150, upload global ~80% upstream ([TRaSH Deluge](https://trash-guides.info/Downloaders/Deluge/Basic-Setup/)).

---

## Camada 2 — aria2 CT165 (referência ~58 MiB/s)

| Opção | Actual | Fine-tune | Nota |
|-------|--------|-----------|------|
| `split` | 16 | 16 | Máximo prático por servidor ([manual](https://aria2.github.io/manual/en/html/aria2c.html)) |
| `max-connection-per-server` | 16 | 16 | Hard cap 16 no upstream |
| `min-split-size` | 5M | **1M–2M** | Permite mais splits em ficheiros médios ([issue #715](https://github.com/aria2/aria2/issues/715) — usar `-k 2M -x 16 -s 16`) |
| `bt-max-peers` | 80 | **100–150** | Mais peers por torrent |
| `bt-request-peer-speed-limit` | 50M | Manter | Já alto |
| `file-allocation` | falloc | falloc | Correcto em ZFS |
| `max-concurrent-downloads` | 8 | 8 | Alinhado qBit |

**Limite estrutural:** aria2 **não satura 1 Gb/s** num único HTTP mirror comum ([~55 MB/s medido](https://limbenjamin.com/articles/saturating-1gbps-bandwidth.html)); precisa **vários mirrors/URLs** ou torrent com muitos peers.

**mp0 `/overpower`:** paths em `/overpower/downs` (não `base/downs`) — manter se *arr* não apontam para aí.

---

## Camada 2 — SABnzbd CT141 (melhor candidato a ~1 Gb/s)

Com Usenet premium, SAB costuma saturar melhor que torrent público ([wiki](https://sabnzbd.org/wiki/advanced/highspeed-downloading)).

| Setting | Sugestão |
|---------|----------|
| **Maximum line speed** | ~**100000** KB/s (≈100 MiB/s) ou valor real da linha |
| **Article cache** | **1000M–2000M** (RAM CT 4 GiB) |
| **Connections** | Começar **20–40** por servidor; subir até estabilizar |
| **Articles per request** | **5–10** (pipelining NNTP) |
| **Direct unpack** | **Off** se Status mostrar limite por disco; On se CPU sobra |
| **receive_threads** (Special) | **2–4** |
| **num_simd_decoders** (3.7+) | **4** se CPU limit ([fórum](https://forums.sabnzbd.org/viewtopic.php?t=25911)) |
| **Pause download during post-processing** | On se disco é gargalo |

Verificar no **Status** de SAB: «limited by CPU» vs «Disk» vs «Network».

---

## Camada 3 — sysctl dentro dos CTs (já parcialmente aplicado)

`99-agl-download.conf` com `tcp_rmem`/`wmem` elevados — OK para sockets BT.

Opcional no **host** (não CT) para forwarding:

```bash
net.core.netdev_max_backlog = 250000
net.ipv4.tcp_congestion_control = bbr   # testar vs cubic se perda na LAN
```

---

## Ordem de implementação recomendada

1. **Host ZFS:** `recordsize=1M` + `atime=off` no dataset de `downs` (sem mover dados).
2. **`--fine-tune`** nos CTs (qBit buffers + aria2 min-split + SAB cache/threads).
3. **Benchmark:** `download-clients-perf-benchmark-qbit-deluge.sh` + teste SAB com NZB grande.
4. **Deluge:** instalar **ltConfig** e aplicar preset “high performance” moderado (não 8000 conn de imediato).
5. Se ainda longe de 1 Gb/s em **Usenet:** `iperf3` host↔gateway; considerar **VM com virtio multiqueue** ou SR-IOV só para downloader de teste.

---

## Referências

- [qBittorrent #9577 — gigabit](https://github.com/qbittorrent/qBittorrent/issues/9577)
- [qBittorrent #22674 — dirty pages / Simple pread/pwrite](https://github.com/qbittorrent/qBittorrent/issues/22674)
- [libtorrent tuning](http://libtorrent.org/tuning.html)
- [OpenZFS — BitTorrent workload](https://openzfs.github.io/openzfs-docs/Performance%20and%20Tuning/Workload%20Tuning.html)
- [SABnzbd — High speed downloading](https://sabnzbd.org/wiki/advanced/highspeed-downloading)
- [aria2 — saturating 1Gbps](https://limbenjamin.com/articles/saturating-1gbps-bandwidth.html)
- [TRaSH Deluge Basic Setup](https://trash-guides.info/Downloaders/Deluge/Basic-Setup/)
- Documentação interna: [`DOWNLOAD-CLIENTS-PERF.md`](DOWNLOAD-CLIENTS-PERF.md)
