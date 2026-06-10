# AGLSRV1 — NUMA, QPI, microcode e optimização VM104

> **Última atualização**: 2026-06-06  
> **Host**: aglsrv1 | **Tailscale**: `100.107.113.33` | **LAN**: `192.168.0.245`  
> **Placa**: HUANANZHI X99-F8D PLUS V1.3 (dual socket)  
> **CPUs**: 2× Intel Xeon E5-2680 v4 (14 cores/socket, 56 threads)  
> **RAM**: ~128 GB ECC DDR4 (8× 16 GB Atermiter, rated 3200 MT/s, configured 2400 MT/s)

## Resumo executivo

| Tema | Estado | Acção |
|------|--------|-------|
| Erros QPI (CRC) | ~1/s, `Corrected_error` | Monitorizar; reduzir tráfego cross-socket (NUMA) |
| Microcode | Pacote Debian actualizado; runtime antigo | **Reboot do host** na janela de manutenção |
| RAM 3200 vs 2400 | 2400 = máximo oficial do CPU | **Não** forçar 3200 na BIOS (overclock arriscado com QPI instável) |
| BIOS C-state | **C2** (confirmado) | Manter; rever Spread Spectrum / C6 / QPI power na próxima janela |
| Undervolt | N/A (CPUs **v4**, não v3) | Sem BIOS undervolt nesta placa |
| VM104 NUMA | **`numa: 1`** aplicado 2026-06-06 | Activo; monitorizar 3–7 dias |
| VM110 NUMA | **`numa: 0`** aplicado 2026-06-06 | GPU `05:00.0` em socket **0** — não usar `numa: 1` |
| VM110 GPU | **Parada** — GTX 1650 **invisível** em `lspci` (2026-05-18) | **Reboot AGLSRV1** → `lspci 05:00` → `qm start 110` |
| Migrate C: → NVMe | Pendente | Só após **backups** dos 2 NVMe + QPI estável |

---

## Topologia NUMA

| NUMA node | Socket | CPUs lógicos | Distância remota |
|-----------|--------|--------------|------------------|
| **0** | Socket 0 (CPU 0) | `0-13`, `28-41` | 21 |
| **1** | Socket 1 (CPU 1) | `14-27`, `42-55` | 21 |

**NVMe físicos** (só detectados nos slots PCIe do socket 1):

| Disco | Modelo | PCI | NUMA |
|-------|--------|-----|------|
| nvme0n1 | NE-1TB 2280 | `81:00.0` | 1 |
| nvme1n1 | X16 Plus SSD 2TB | `82:00.0` | 1 |

IOMMU groups **15** e **16** isolados — candidatos futuros a PCI passthrough (`hostpci`).

**GPU GTX 1650** (VM110 agl-ollama):

| Dispositivo | PCI | NUMA |
|-------------|-----|------|
| GeForce GTX 1650 | `05:00.0` | **0** |
| HDMI audio | `05:00.1` | **0** |

Pin VM110 em `numa: 0` + `affinity 0-13,28-41` (espelho lógico da VM104 em socket 1). Ver [`AGL-OLLAMA-VM110.md`](AGL-OLLAMA-VM110.md).

---

## Erros QPI (rasdaemon)

**Instalado**: `rasdaemon` no host AGLSRV1.

**Tipo de erro** (recorrente):

- `Rx detected CRC error - successful LLR without Phy re-init` (MSCOD `0x31`)
- Classificação: `Corrected_error` (bank 5, QPI / BUS Level-3)
- Frequência observada: ~**1 erro/segundo**
- **Sem** erros de memória ECC, PCIe AER ou disco em `ras-mc-ctl --summary`

**Interpretação**: problema no **interconnect QPI** entre os dois sockets, não necessariamente CPU ou RAM defeituosa. Erros corrigidos pelo hardware (LLR), mas indicam degradação do link e overhead de retransmissão.

### Monitorização

```bash
HOST=root@100.107.113.33

# Resumo (memória, PCIe, etc.)
ssh $HOST 'ras-mc-ctl --summary'

# Últimos erros QPI
ssh $HOST 'ras-mc-ctl --errors | tail -20'

# Contagem rápida (última hora via journal)
ssh $HOST 'journalctl -u rasdaemon --since "1 hour ago" --no-pager | grep -c "CRC error" || true'
```

### Critérios de alerta (parar migrate / escalar)

- Aparecer `Uncorrected_error` ou `LLR abort`
- Instabilidade em VM104 (BSOD, I/O hang, RDP repetidamente morto)
- QPI deixa de ser só `Corrected_error`

---

## Microcode

### Estado (2026-06-06)

| Item | Valor |
|------|--------|
| Pacote | `intel-microcode` **3.20251111.1~deb13u1** (Debian) |
| Em execução (`/proc/cpuinfo`) | **0xb000040** (até reboot) |

### Procedimento (janela de manutenção)

```bash
HOST=root@100.107.113.33

# Antes do reboot
ssh $HOST 'grep microcode /proc/cpuinfo | sort -u'
ssh $HOST 'dpkg -l intel-microcode | tail -1'

# Reboot do host (preferir de outro nó, não de dentro de CT)
ssh $HOST 'reboot'

# Após voltar (minutos depois)
ssh $HOST 'grep microcode /proc/cpuinfo | sort -u'
```

**Nota**: em placas X99 chinesas o microcode é carregado pelo **SO** (`intel-microcode`), não pela BIOS. Ganho típico em Broadwell-EP é modesto; não substitui correcção física de QPI, mas deve manter-se actualizado.

---

## RAM ECC — 3200 MT/s vs 2400 MT/s

`dmidecode` reporta:

- **Speed**: 3200 MT/s (SPD dos módulos)
- **Configured Memory Speed**: **2400 MT/s**

O **E5-2680 v4** suporta oficialmente até **DDR4-2400** ([Intel ARK](https://www.intel.com/content/www/us/en/products/sku/91754/intel-xeon-processor-e52680-v4-35m-cache-2-40-ghz/specifications.html)). Os módulos 3200 fazem **downclock** para o máximo do processador — **já está no limite suportado**.

**Não recomendado** com QPI instável:

- Forçar 2666 / 2933 / 3200 na BIOS (overclock de memória em X99)

**Na próxima janela BIOS**:

- Perfil **2400** explícito
- **XMP desligado**
- Confirmar slots populados correctamente (dual-channel por socket)
- Verificar que não há mistura de kits com timings diferentes

---

## BIOS — checklist (próxima janela)

| Opção | Estado / acção |
|-------|----------------|
| C-state | **C2** — confirmado; manter |
| Undervolt | N/A (v4) |
| Spread Spectrum | Desligar se existir |
| C6 / C7 | Desligar se existir |
| QPI Link Power Management | Desligar se existir |

---

## VM104 (aglwk45) — discos e NUMA

### Discos (2026-06-06)

| ID | Dispositivo | Tipo | Cache / I/O |
|----|-------------|------|-------------|
| scsi0 | `local-zfs:vm-104-disk-1` (720G, boot) | ZFS zvol | `cache=directsync`, `aio=threads` |
| scsi1 | `/dev/disk/by-id/nvme-…` NE-1TB | Passthrough físico | `ssd=1`, `cache=none`, `aio=native`, `iothread=1`, `discard=on` |
| scsi2 | `/dev/disk/by-id/nvme-…` X16 2TB | Passthrough físico | idem |

`scsihw: virtio-scsi-single`

### NUMA — socket 1 (aplicado 2026-06-06)

```
numa: 1
numa0: cpus=0-23,hostnodes=1,memory=32768,policy=bind
affinity: 14-27,42-55
cores: 24
memory: 32768
balloon: 12288
```

**Objectivo**: alinhar vCPUs e RAM ao socket onde estão os NVMe (`81:00.0`, `82:00.0`), reduzindo tráfego QPI para I/O de disco.

**Tradeoff**: 24 vCPUs + 32 GB no socket 1 com QPI degradado — teste aceite para monitorização; se o socket 1 ficar saturado, reavaliar.

### Comandos

```bash
HOST=root@100.107.113.33

# Ver config
ssh $HOST 'qm config 104 | grep -E "numa|affinity|scsi|cores|memory"'

# Reboot VM (activa NUMA)
ssh $HOST 'qm reboot 104'

# Estado
ssh $HOST 'qm status 104 && qm agent 104 ping'
```

### Migrate futuro: C: → X16 2TB (NVMe)

**Pré-requisitos**:

1. Backups completos dos conteúdos dos 2 NVMe
2. QPI estável (sem uncorrected)
3. VM104 validada com `numa: 1` alguns dias

**Passos planeados** (não executados):

1. `qm snapshot 104 pre-nvme-boot-migration`
2. Clonar partição C: (`scsi0`) → X16 (`scsi2`)
3. Boot por NVMe passthrough (`scsi2`); manter `scsi0` como fallback até validação
4. PCI passthrough (`hostpci`) — ganho marginal; só se necessário

---

## Redistribuição VMs / CTs (plano gradual)

**Objectivo**: menos workloads pesados a cruzar QPI entre sockets.

### Sugestão

| NUMA node 1 (socket 1) | NUMA node 0 (socket 0) |
|------------------------|------------------------|
| **VM104** aglwk45 (24c / 32 GB) | Routers leves: VM101, VM105, VM106 |
| test-k3s VM151–156 (já `numa: 1`) | Dev: CT179, CT181 |
| CTs com I/O pesado em storage do node 1 (futuro) | VMs Windows leves, stack media em ZFS local (se storage no socket 0) |
| | Maioria das VMs hoje em `numa: 0` |

### Inventário NUMA actual (VMs)

Quase todas as VMs em `numa: 0` excepto VM104 (após alteração), VM151–156 (`numa: 1`). CTs sem `numa` explícito → default node 0.

### Aplicar NUMA a um CT (exemplo)

```bash
pct set <vmid> -numa 1
# Reiniciar CT para efeito
pct reboot <vmid>
```

**Ordem recomendada**:

1. VM104 `numa: 1` + reboot → monitorizar 3–7 dias  
2. Reboot host (microcode)  
3. Mover 1–2 CTs pesados de cada vez; observar `ras-mc-ctl`  
4. Migrate C: → NVMe só após backups

---

## Monitorização diária (Hermes Werner / CT188)

Watchdog **só envia Telegram quando há falha** (stdout vazio = silêncio). Bot **@hermes_jarvis_h_werner_bot** → `1272190248`.

| Item | Valor |
|------|--------|
| Script | `scripts/monitoring/aglsrv1-qpi-numa-daily.sh` |
| Deploy | `scripts/proxmox/deploy-hermes-werner-aglsrv1-monitor-ct188.sh` |
| Cron Hermes | `aglsrv1-qpi-numa-daily` — `0 8 * * *` (08:00) |
| Modo | `--no-agent` (stdout → Telegram apenas se alerta) |

### Condições de alerta

| Check | Limite default |
|-------|----------------|
| VM104 não `running` | — |
| Guest Agent DOWN | — |
| Ping LAN `192.168.0.33` FAIL | — |
| `numa` ≠ 1 | — |
| QPI `Uncorrected_error` | ≥ 1 |
| ECC RAM / PCIe AER (ras) | qualquer erro |
| CPU KVM VM104 | > 1000% |
| Load 1m | > 48 (24 cores × 2) |
| RAM avail | < 10 Gi |
| Swap usado | > 60% |
| meshagent leak | RSS > 1 Gi por processo |

**Não alerta:** erros QPI CRC **corrigidos** (~1/s baseline).

Variáveis: `VM_CPU_ALERT_PCT`, `LOAD_ALERT_MULT`, `MEM_AVAIL_MIN_GB`, `SWAP_USED_PCT_MAX`, `MESHAGENT_LEAK_RSS_KB`.

**Instalar / actualizar (CT188):**

```bash
ssh root@100.107.113.33 'pct exec 188 -- bash /mnt/overpower/apps/dev/agl/agl-hostman/scripts/proxmox/deploy-hermes-werner-aglsrv1-monitor-ct188.sh /mnt/overpower/apps/dev/agl/agl-hostman --test-run'
```

**Executar manualmente (envia Telegram):**

```bash
ssh root@100.107.113.33 'pct exec 188 -- docker exec -e HERMES_HOME=/opt/data agl-hermes-werner /opt/hermes/.venv/bin/hermes cron run aglsrv1-qpi-numa-daily'
```

**Teste local (sem SSH):**

```bash
bash scripts/monitoring/aglsrv1-qpi-numa-daily.sh --dry-run
```

---

## Referências

- [`docs/AGLWK45-SETUP.md`](AGLWK45-SETUP.md) — Setup VM104, emergência RDP
- [`docs/AGLSRV1-TROUBLESHOOTING.md`](AGLSRV1-TROUBLESHOOTING.md) — Runbook host
- [`docs/aglsrv1-key-findings.md`](aglsrv1-key-findings.md) — Histórico de incidentes
- [`docs/WINDOWS11-PROXMOX-OPTIMIZATION.md`](WINDOWS11-PROXMOX-OPTIMIZATION.md) — Optimizações Windows no Proxmox
- [`AGENTS.md`](../AGENTS.md) — meshagent leak, diagnóstico VM104
