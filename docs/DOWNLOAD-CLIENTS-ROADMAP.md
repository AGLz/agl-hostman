# Roadmap — performance de downloads (~1 Gb/s)

Plano consolidado (pesquisa web + benchmarks AGL, 2026-06) para **qBittorrent CT121**, **SABnzbd CT141**, **Deluge CT157**, **aria2 CT165** no AGLSRV1.

**Relacionado:** [`DOWNLOAD-CLIENTS-PERF.md`](DOWNLOAD-CLIENTS-PERF.md) · [`DOWNLOAD-CLIENTS-FINE-TUNING-1GBPS.md`](DOWNLOAD-CLIENTS-FINE-TUNING-1GBPS.md) · [`MEDIA-ARR-STACK-AGL.md`](MEDIA-ARR-STACK-AGL.md) · [`MEDIA-ARR-MAINTENANCE.md`](MEDIA-ARR-MAINTENANCE.md)

---

## Estado actual (baseline 2026-06-03)

| Item | Estado |
|------|--------|
| Mounts download CTs | **mp0–mp9** = CT123 Radarr (`ct-download-mounts-apply.sh --apply`) |
| Fine-tune camada 2 | qBit buffers, aria2 2M split, SAB cache 1500M, host `vm.dirty_*` |
| ZFS `overpower` | `recordsize=1M`, `atime=off`, `compression=lz4` |
| Benchmark torrent Debian | aria2 ~53–76 MiB/s · qBit pico **45,66** · Deluge pico **24,96** |
| Pool `overpower` | **~97%** — downloads *arr* em freeze |
| Fase A iperf CT121→host | **~21,2 Gbit/s** agregado (4 streams) — veth **não** limita 1 GbE |
| Fase A paths TRaSH | `arr-data-paths-verify.sh` OK (mp1, dirs, root folders) |
| Fase A SABnzbd | NZB oficial `sabnzbd.org/tests/test_download_100MB.nzb` → **Failed** `not-complete` (ver abaixo) |
| ulimit CT121 | **65535** re-aplicado (`download-clients-perf-optimize.sh --apply`, 2026-06-03) |

**Conclusão:** o gargalo não é “falta de outro cliente”. **aria2** já mostra margem na mesma infra; qBit/Deluge/libtorrent e **medição** (torrent público vs Usenet vs iperf) precisam de separação.

---

## Panorama de clientes (referência)

### Torrent

| Cliente | Quando considerar | Para AGL |
|---------|-------------------|----------|
| **qBittorrent** | *arr* principal — [TRaSH](https://trash-guides.info/Downloaders/qBittorrent/) | **Manter CT121** como único activo nos *arr* |
| **aria2** | RPC, batch, melhor pico medido | **CT165** — referência de performance, não substituir qBit nos *arr* sem integração madura |
| **Deluge + ltConfig** | Tuning libtorrent avançado | **CT157** — backup/bench; instalar ltConfig ou desactivar nos *arr* |
| **Transmission** | RAM mínima | Pouco ganho vs qBit em velocidade |
| **rTorrent** | 1000+ torrents, seedbox | Complexidade alta; *arr* prefere qBit |

### Usenet

| Cliente | Quando considerar | Para AGL |
|---------|-------------------|----------|
| **SABnzbd** | Padrão *arr*, activo | **CT141** — corrigir teste + tuning high-speed |
| **NZBGet** (fork) | C++ / pós-processamento mais rápido | Só **após** SAB medido e estável |

---

## Limites estruturais (não resolvem só com “outro binário”)

1. **LXC veth** — sem multiqueue; teto prático em GbE ([Proxmox](https://forum.proxmox.com/threads/lxc-multiqueue-and-rss.179431/)).
2. **ZFS + torrent** — I/O aleatório; `recordsize=1M` no host já aplicado ([OpenZFS](https://openzfs.github.io/openzfs-docs/Performance%20and%20Tuning/Workload%20Tuning.html)).
3. **Swarm público** — ISO Debian não prova 1 Gb/s ([limbenjamin.com](https://limbenjamin.com/articles/saturating-1gbps-bandwidth.html)).
4. **Pool cheio** — degrada I/O; bloqueia reactivação de downloads.
5. **Nunca** download torrent directo para SMB/NFS — usar bind local `/mnt/overpower` ([fórum Proxmox](https://forum.proxmox.com/threads/slow-speed-torrenting-using-an-lxc-container.118211/)).

---

## Fases

### Fase A — Medir a linha (sem mudar stack)

**Objectivo:** separar limite de **rede**, **Usenet** e **torrent**.

| # | Tarefa | Script / comando | Critério | Estado |
|---|--------|------------------|----------|--------|
| A.1 | iperf3 host ↔ CT121 (veth) | `download-clients-phase-a.sh --apply` | ≥1 Gbit/s agregado | **OK** ~21 Gbit/s |
| A.2 | iperf3 host → LAN (opcional) | `IPERF_TARGET=…` | Destino com `iperf3 -s` | SKIP (0.1 sem servidor no gateway) |
| A.3 | SABnzbd: limpar testes, tuning | idem `--apply` | fila limpa, `bandwidth_max`/`receive_threads` | **OK** |
| A.4 | SAB teste NZB 100MB | `--apply --sab-test` | `Completed` + pico Mbps | **FALHOU** `not-complete` |
| A.5 | Verificar paths TRaSH | `arr-data-paths-verify.sh` | CT121/123/124/141/165 coerentes | **OK** |
| A.6 | Relatório no host | `/tmp/agl-download-phase-a-*.txt` | Não commitar (pode ter metadados API) | 2026-06-03T12:49 |

```bash
bash scripts/media/download-clients-phase-a.sh
bash scripts/media/download-clients-phase-a.sh --apply
bash scripts/media/download-clients-phase-a.sh --apply --sab-test
bash scripts/media/arr-data-paths-verify.sh
# NZB real Usenet (quando A.4 oficial falhar):
SAB_TEST_NZB_URL='https://…/seu_teste.nzb' bash scripts/media/download-clients-phase-a.sh --apply --sab-test
```

#### Diagnóstico SAB A.4 (2026-06-03)

O NZB de demonstração em [sabnzbd.org/tests](https://sabnzbd.org/tests/) falhou com **Cancelado, não é possível concluir** (`https://sabnzbd.org/not-complete`) após ~11 min com pico ~143 KB/s na fila — típico de **artigos em falta no servidor de teste**, não de disco local (pool 97% mas ainda com ~334 G livres no mount).

**Próximo passo Usenet:** repetir A.4 com NZB pequeno no **servidor NNTP de produção** (Newshosting já configurado no CT141) via `SAB_TEST_NZB_URL`, ou teste manual na UI SAB + histórico `Completed`. Validar também em SAB: *Status → Test server* e warnings (sem expor API keys em docs/commits).

### Fase B — Infra (maior ROI)

| # | Tarefa | Notas |
|---|--------|-------|
| B.1 | Espaço `overpower` / AGLSRV3 | Pré-requisito para reactivar *arr* |
| B.2 | `zfs_dirty_data_max` no host | Se writes engasgam |
| B.3 | Re-aplicar ulimit 65535 | `download-clients-perf-optimize.sh --apply` (pós-restart CTs) |
| B.4 | Modelo `/data` TRaSH sob `/mnt/overpower` | `torrents/` vs `media/` — hardlinks |
| B.5 | Subdataset ZFS opcional só `downs` | `recordsize=1M` isolado |

### Fase C — Clientes (consolidar)

| # | Tarefa |
|---|--------|
| C.1 | qBit único torrent activo nos *arr* |
| C.2 | SAB: `bandwidth_max`, `receive_threads`, par2 turbo, servidores NNTP |
| C.3 | Deluge: plugin **ltConfig** ou desactivar |
| C.4 | Reduzir Remote Path Mappings quando paths locais coincidem |

### Fase D — Só se Usenet ainda &lt; ~800 Mbps

| # | Tarefa |
|---|--------|
| D.1 | VM downloader com virtio multiqueue (teste A/B vs LXC) |
| D.2 | Avaliar NZBGet após SAB estável |
| D.3 | Scratch NVMe para incomplete (avaliar tradeoff TRaSH) |

---

## Ordem de execução (checklist)

- [x] Mounts unificados (2026-06-03)
- [x] Fine-tune camada 2 aplicado
- [x] **Fase A** — `download-clients-phase-a.sh --apply` (iperf + prep SAB)
- [x] **Fase A** — `arr-data-paths-verify.sh`
- [~] **Fase A** — iperf / SAB **adiados** (foco torrent + infra)
- [x] **Fase B.3** — ulimit 65535 re-apply (2026-06-03)
- [ ] **Fase B.1** — espaço pool (AGLSRV3 / política retenção) — **bloqueador** para unfreeze
- [~] **Fase C.2** — SAB adiado
- [x] **Fase C.3** — Deluge/Aria2 OFF + prioridade 50 nos *arr*
- [x] **Fase C.1** — qBit prio 1; `arr-unfreeze` só qBit + SAB
- [x] **Fase B.2** — `zfs_dirty_data_max=1G` runtime + `/etc/modprobe.d/zfs-agl-download.conf`
- [ ] Reactivar downloads *arr* (`arr-unfreeze-downloads.sh`) só após B.1

### Próximos passos concretos (ordem sugerida)

| Prioridade | Acção | Comando / nota |
|------------|--------|----------------|
| 1 | Benchmark torrent (sem SAB) | `… --skip-optimize --skip-sab` (inclui aria2) — última: 20260603-185409 |
| 2 | Consolidar *arr* | `arr-download-clients-consolidate.sh --apply` — **feito** |
| 3 | Espaço pool | Política retenção / AGLSRV3 — **bloqueador** unfreeze |
| 4 | Unfreeze | `arr-unfreeze-downloads.sh` só qBit + SAB, após pool &lt;90% |
| — | *Adiado* | iperf, SAB benchmark |

---

## Scripts

| Script | Fase |
|--------|------|
| [`download-clients-phase-a.sh`](../scripts/media/download-clients-phase-a.sh) | A (iperf/SAB — opcional) |
| [`arr-download-clients-consolidate.sh`](../scripts/media/arr-download-clients-consolidate.sh) | C.1 |
| [`arr-data-paths-verify.sh`](../scripts/media/arr-data-paths-verify.sh) | A |
| [`download-clients-perf-optimize.sh`](../scripts/media/download-clients-perf-optimize.sh) | B, C |
| [`download-clients-perf-benchmark.sh`](../scripts/media/download-clients-perf-benchmark.sh) | Validação pós-mudanças |

---

## Referências externas

- [TRaSH — Downloaders](https://trash-guides.info/Downloaders/)
- [TRaSH — Hardlinks](https://trash-guides.info/File-and-Folder-Structure/Hardlinks-and-Instant-Moves/)
- [SABnzbd — High speed](https://sabnzbd.org/wiki/advanced/highspeed-downloading)
- [qBittorrent #9577 — gigabit](https://github.com/qbittorrent/qBittorrent/issues/9577)
- [Self-hosted download managers 2026](https://selfhostwise.com/posts/self-hosted-download-managers-in-2026-qbittorrent-transmission-and-deluge-compared/)
- [NZBGet vs SABnzbd](https://selfhosting.sh/compare/nzbget-vs-sabnzbd/)

---

*Última actualização: 2026-06-03 (Fase A executada; A.4 SAB pendente NZB real)*
