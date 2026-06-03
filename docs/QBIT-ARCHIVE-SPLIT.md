# qBittorrent CT121 — arquivo vs produção

## Problema

- **CT121** (`192.168.0.121:8090`) é o cliente **qBittorrent AGLSRV1** em Radarr/Sonarr.
- ~**600+** torrents na sessão; muitos em **`missingFiles`** (ficheiros já não existem no disco).
- Queres **manter** esses torrents para recuperação futura, mas **fora** da instância activa (API/WebUI lentas, arranque lento, benchmarks impossíveis).

O qBittorrent **não tem** “arquivo invisível”: tudo o que está na sessão entra na API e no `sync/maindata` (~400 MB).

## Abordagem recomendada: clone + CT121 limpo

| Instância | CT | IP sugerido | Papel |
|-----------|-----|-------------|--------|
| **Produção** | **121** (actual) | `192.168.0.121` | Limpo; só *arr* / grabs / testes |
| **Arquivo** | **clone** (novo VMID) | ex. `192.168.0.221` | Cópia integral; **parado** por defeito; consulta manual |

**Vantagens**

- Zero perda: o clone é disco + config + `BT_backup` + histórico.
- Radarr/Sonarr **não mudam** host/porta (continuam no 121).
- Recuperar um torrent antigo: ligar o CT arquivo, WebUI, exportar/relocalizar, desligar.

**Não fazer agora**

- Apagar dados no pool **`overpower`** (97% cheio) — aguardar AGLSRV3.
- `optimize` + restart do qBit sem necessidade.

## Pré-requisitos

1. **Snapshot ZFS** `rpool/data/subvol-121-disk-0@pre-qbit-split-YYYYMMDD` (`pct snapshot` LXC não disponível neste host).
2. VMID livre no AGLSRV1 (verificar com `pct list`).
3. Downloads *arr* ainda em **freeze** até validares cliente limpo.

## Estado (2026-06-03)

| CT | Hostname | IP | Estado |
|----|----------|-----|--------|
| **121** | qbittorrent | 192.168.0.121 | running — **sessão limpa** (produção / *arr*) |
| **221** | qbittorrent-archive | 192.168.0.221 | **stopped** — arquivo (~600+ torrents legados) |

Snapshot: `rpool/data/subvol-121-disk-0@pre-qbit-split-20260602`

**Limpeza CT121 (2026-06-03):** `BT_backup` → `BT_backup.archive-20260603-112620` (+ cópia em `/mnt/overpower/qbit-legacy/`). API `torrents/info` vazia (~0 bytes).

## Fases (script)

```bash
# Inventário (só leitura)
bash scripts/media/qbit-split-archive.sh inventory

# Snapshot + clone (sem mexer no 121)
bash scripts/media/qbit-split-archive.sh clone --archive-vmid 221 --archive-ip 192.168.0.221/24

# Limpar sessão no 121 (DESTRUTIVO — só após clone OK)
bash scripts/media/qbit-split-archive.sh clean-production --apply
```

### O que `clean-production` faz no CT121

1. Para `qbittorrent-nox`.
2. Move `BT_backup` → `BT_backup.archive-<data>` (no rootfs do CT, ~10 MB).
3. Copia opcional para `/mnt/overpower/qbit-legacy/` **só se** houver espaço (hoje ~332 G livres no mount — OK para cópia pequena).
4. Cria `BT_backup` vazio; arranca qBit → WebUI rápida.
5. Reaplica paths/categorias para *arr* (`/mnt/overpower/downs/...`).

**Não apaga** o clone nem o snapshot.

## Alternativa (sem clone)

Exportar torrents por API (`/torrents/export`) + remover da sessão — lento com 600 entradas e mesma API pesada. O **clone** é mais rápido e reversível.

## Após limpeza

1. Confirmar WebUI &lt;30 s e API `torrents/info` pequena.
2. `download-clients-perf-benchmark.sh --skip-optimize` no 121.
3. Reactivar **qBittorrent AGLSRV1** nos *arr* quando saíres de `MEDIA-ARR-MAINTENANCE.md`.
4. Ajustar **Remote Path Mappings** se mudares `savepath` default.

## Referências

- `docs/DOWNLOAD-CLIENTS-PERF.md`
- `docs/MEDIA-ARR-MAINTENANCE.md`
- `docs/MEDIA-ARR-STACK-AGL.md` (secção download clients)
