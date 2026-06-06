# AGLSRV1 Service Diagnostics - Key Findings

**Date**: 2025-10-21 23:00
**Diagnostician**: Service Diagnostics Agent (Hive-Mind)
**Updated**: 2026-06-06 — Erros QPI (rasdaemon), NUMA VM104, NVMe passthrough

---

## Descoberta 2026-06-06 — Erros QPI + optimização NUMA VM104

**Sintoma**: `rasdaemon` regista erros QPI contínuos (~1/s): `Rx detected CRC error - successful LLR without Phy re-init` (`Corrected_error`, bank 5). Sem erros ECC de RAM ou PCIe AER.

**Hardware**: X99-F8D PLUS, 2× E5-2680 v4, RAM ECC 3200 MT/s configurada a **2400** (máximo oficial do CPU). BIOS C-state **C2**. Undervolt N/A (v4).

**Acções**:

1. `intel-microcode` 3.20251111.1~deb13u1 instalado — **reboot host** pendente para carregar revisão nova
2. VM104: 2 NVMe passthrough (NE-1TB, X16 2TB) no socket 1; `numa: 1` + `policy=bind` + `affinity` aplicados
3. Plano gradual de redistribuição VMs/CTs entre sockets

**Doc**: [`docs/AGLSRV1-NUMA-QPI-OPTIMIZATION.md`](AGLSRV1-NUMA-QPI-OPTIMIZATION.md)

---

## Incidente 2026-05-25 — WebUI Proxmox: login bloqueado (SSH OK)

**Sintoma**: Impossível logar em `https://192.168.0.245:8006`; SSH com `root` OK. Página de login carrega; submit falha (HTTP 596 → depois 500).

**Causa raiz**: Três `pvedaemon worker` em estado **`D`** (desde 20/May), bloqueados em NFS **`hard`** para `10.6.0.20` (`ct111-shares`, `ct111-sistema`). CT111 offline na mesh WG → I/O hang → autenticação WebUI nunca completa. `pvestatd` também preso.

**Resolução** (sem reboot do host):

```bash
systemctl restart pvedaemon pveproxy
umount -l /mnt/pve/ct111-shares /mnt/pve/ct111-sistema
systemctl restart pvestatd
```

**Nota**: Reset de password (`pveum passwd root@pam`) não resolveu — não era problema de credencial. Realm correcto: **Linux PAM standard authentication**.

**Doc completa**: [`docs/AGLSRV1-WEBUI-LOGIN-NFS-BLOCK-2026-05-25.md`](AGLSRV1-WEBUI-LOGIN-NFS-BLOCK-2026-05-25.md)

---

## Incidente 2026-04-06 — VM104 RDP Inacessível + Host Colapso

**Sintoma**: aglwk45 (VM104) com RDP inacessível, CPU 2122%, QEMU Guest Agent inativo.

**Causa raiz**: 3 instâncias de **meshagent** com memory leak (~49GB RAM total):
| PID | RSS | Início |
|-----|-----|--------|
| 1827260 | 22GB | Mar16 |
| 57783 | 14GB | Mar15 |
| 2468815 | 13GB | Mar27 |

**Impacto**: Host com load 146+ (24 cores), 116GB/125GB RAM, 66GB/79GB swap, stack de rede colapsou (Tailscale + LAN timeout).

**Resolução**:
1. `qm stop 104` → `qm start 104`
2. `kill -9 1827260 57783 2468815`
3. `qm set 104 --ide0 none,media=cdrom` (remover ISO desnecessária)
4. Resultado: CPU 224%, RDP aberto, GA OK, load 33

**Risco persistente**: 30+ instâncias de meshagent ainda ativas (~20-27MB cada). Recomenda-se auditoria e consolidação.

---

## TL;DR - Executive Summary

**Question**: Is the Proxmox WebUI working?
**Answer**: ✅ **YES** - WebUI is fully operational on https://192.168.0.245:8006

**Critical Issue**: 🔴 **/tmp filesystem is 100% full** (63GB consumed by rclone cache)

**System Health**: 🔴 **CRITICAL** - High memory pressure, sustained load, resource exhaustion

---

## Root Cause Analysis

### Primary Issue: rclone Google Drive Cache Bloat

**Location**: `/tmp/rclone-gd` (63GB of 63GB tmpfs)

**Process**: PID 4507 - `/usr/bin/rclone mount gdrive:/ /mnt/gdrive`

**Configuration**:
```
--cache-tmp-upload-path=/tmp/rclone-gd/upload
--cache-chunk-path=/tmp/rclone-gd/chunks
--cache-dir=/tmp/rclone-gd/vfs
--cache-db-path=/tmp/rclone-gd/db
--vfs-cache-mode full
--vfs-cache-max-age=5m
--buffer-size 256M
```

**Problem**: Full VFS cache mode with 5min max-age on 63GB tmpfs is unsustainable

**Fix Options**:

1. **Immediate** (Emergency):
   ```bash
   systemctl stop rclone-wg.service
   rm -rf /tmp/rclone-gd/*
   systemctl start rclone-wg.service
   ```

2. **Long-term** (Permanent):
   - Move cache to disk: `--cache-dir=/var/cache/rclone-gd`
   - Reduce cache mode: `--vfs-cache-mode writes` (instead of full)
   - Lower cache age: `--vfs-cache-max-age=1m`
   - Limit cache size: `--vfs-cache-max-size 10G`

---

## Top Memory Consumers

| Process | PID | RAM | %CPU | Purpose | Issue |
|---------|-----|-----|------|---------|-------|
| VM 104 (aglwk45) | 7706 | 16GB | 87% | Workstation | High CPU |
| qbittorrent | 11219 | 2.9GB | 0.1% | Torrent | OK |
| meshagent (multiple) | various | 2.4GB each | 0% | Remote mgmt | Multiple instances |
| Minecraft server | 23119 | 2.1GB | 7.3% | Game server | High CPU |
| VM 148 (zabbix) | 19862 | 1.9GB | 10.1% | Monitoring | High CPU |
| VM 138 (haos) | 17087 | 1.8GB | 1.5% | Home Assistant | OK |
| rclone mount | 4507 | 587MB | 1.2% | Google Drive | Cache issue |

**Analysis**:
- VM 104 consuming 87% CPU (16GB RAM) - investigate hung process
- Multiple meshagent instances (3+ running) - consolidate or remove duplicates
- Minecraft server using 7.3% CPU sustained - normal behavior

---

## Service Status Matrix

| Service | Status | Port | Issue |
|---------|--------|------|-------|
| **pveproxy** | ✅ Running | 8006 | None |
| **pvedaemon** | ✅ Running | 85 | None |
| **pvestatd** | ✅ Running | - | PBS timeout warnings |
| **pve-cluster** | ✅ Running | - | None |
| **pvescheduler** | ✅ Running | - | Vzdump lock timeout |
| fgsrv5-nfs.mount | ❌ Failed | - | Obsolete (use fgsrv5-wg) |
| fgsrv6-nfs.mount | ❌ Failed | - | Obsolete (use fgsrv6-wg) |
| rclone-wg.service | ❌ Failed | - | Running but systemd shows failed |
| pve-container@200 | ✅ Running (CT200) | 11434 no CT | Ollama só no CT200, não no host |
| pve-container@999 | ❌ Failed | - | Orphaned (config missing) |
| zfs-snapshot-manager | ❌ Failed | - | Needs investigation |

---

## Storage Configuration Issues

### Corrupted pvesm Output

```
400 Result verification failed
[5].used: type check ('integer') failed - got '-1.84467190920302e+19'
```

**Cause**: Failed NFS mount services (fgsrv5-nfs, fgsrv6-nfs) reporting invalid metrics

**Fix**:
```bash
pvesm remove fgsrv5-nfs
pvesm remove fgsrv6-nfs
pvesm status  # Verify clean output
```

---

## Backup Status

### Long-Running Backup (LOCKED)

**Task**: `UPID:algsrv1:00078F80:000B3A20:68F5D6E9:vzdump`
**Started**: Oct 21 03:15:04
**Timeout**: Oct 21 06:15:04 (3 hours)
**Status**: Still running (PID 495488)

**Issue**: Backup started at 3am, timed out waiting for lock at 6am, but process still exists

**Investigation Needed**:
```bash
ps aux | grep 495488
ls -lh /var/run/vzdump.lock  # 0 bytes = lock held by running process
```

**Action**: Monitor backup completion. If stuck >24h, consider kill/restart.

---

## Container Issues

### CT200 (ollama) — canónico para Ollama

**Política**: Ollama corre **só** no CT200 (`pct exec 200`, IP típica `192.168.0.200:11434`). **Não** instalar `ollama.service` no host Proxmox.

**GPU**: pass-through para o CT; no host manter apenas `post-reboot-gpu.service` (wake PCI / verificação), sem serviço Ollama.

**Verificação**:
```bash
pct status 200
pct exec 200 -- systemctl is-active ollama
pct exec 200 -- curl -sS http://127.0.0.1:11434/api/tags
```

### CT999 - ORPHANED 🗑️

**Status**: Service exists but config file missing
**Config**: `/etc/pve/lxc/999.conf` (not found)

**Action**: Remove orphaned service
```bash
systemctl disable pve-container@999.service
systemctl reset-failed
```

---

## Network Storage Status

### Active Mounts (Working) ✅

- `fgsrv5-wg`: 77GB NFS via WireGuard (10.6.0.11)
- `fgsrv6-wg`: 197GB NFS via WireGuard (10.6.0.5)
- `ct111-shares`: 66GB NFS via WireGuard (10.6.0.20)
- `ct111-sistema`: 818GB NFS via WireGuard (10.6.0.20)
- `aglsrv6-bb`: 954GB SSHFS via WireGuard (10.6.0.12)
- `aglsrv6-usb4tb`: 3.9TB SSHFS via WireGuard (10.6.0.12)

**Total**: 6TB+ WireGuard storage accessible

### Failed Mounts (Obsolete) ❌

- `fgsrv5-nfs`: Legacy Tailscale mount (replaced by fgsrv5-wg)
- `fgsrv6-nfs`: Legacy Tailscale mount (replaced by fgsrv6-wg)

**Action**: Remove from `/etc/fstab` and Proxmox storage config

---

## PBS Backup Storage Timeouts

**CT113** (10.6.0.14:8007) - AGLSRV6 PBS: Connection timeout
**CT172** (10.6.0.15:8007) - AGLSRV6B PBS: Connection timeout

**Impact**: Backup storage status not reporting, backups may be functional

**Investigation**:
```bash
ssh root@10.6.0.14 'systemctl status proxmox-backup-proxy'
curl -k https://10.6.0.14:8007
```

---

## Immediate Action Plan (Priority Order)

### 1. Clear /tmp Filesystem (CRITICAL) 🔴

**Urgency**: Immediate (system operations blocked)

```bash
# Stop rclone, clear cache, reconfigure
systemctl stop rclone-wg.service
rm -rf /tmp/rclone-gd/*
# Edit rclone config: move cache to /var/cache/
vim /etc/systemd/system/rclone-wg.service
systemctl daemon-reload
systemctl start rclone-wg.service
```

### 2. Investigate VM 104 High CPU (HIGH) 🟠

**Urgency**: Within 1 hour

```bash
# Check process inside VM
pct enter 104
top -c
# Consider restart if hung
```

### 3. Clean Failed Services (MEDIUM) 🟡

**Urgency**: Within 24 hours

```bash
# Run automated remediation script
bash /root/agl-hostman/scripts/aglsrv1-emergency-remediation.sh
```

### 4. CT200 (ollama) (MEDIUM) 🟡

**Urgency**: Within 24 hours if parado

```bash
pct start 200
# Ollama: usar API em http://192.168.0.200:11434 (não no host)
```

### 5. Remove Obsolete Storage Configs (LOW) 🔵

**Urgency**: Within 1 week

```bash
pvesm remove fgsrv5-nfs fgsrv6-nfs
```

---

## Monitoring Recommendations

### Real-time Monitoring

```bash
# Terminal 1: System resources
watch -n 5 'free -h; df -h /tmp; uptime'

# Terminal 2: Proxmox services
watch -n 10 'systemctl status pveproxy pvedaemon --no-pager | grep Active'

# Terminal 3: Failed services
watch -n 60 'systemctl --failed --no-pager'
```

### Alert Thresholds

- /tmp usage: Alert at 90%, Critical at 95%
- Memory: Alert at 85% RAM + 80% swap
- Load average: Alert when >4.0 sustained (>5min)
- Service failures: Alert on any pve* service failure

---

## Documentation Updated

- ✅ `/Users/admin/apps/dev/agl/agl-hostman/docs/aglsrv1-service-diagnostics-2025-10-21.md` (Full report)
- ✅ `/Users/admin/apps/dev/agl/agl-hostman/docs/aglsrv1-key-findings.md` (This summary)
- ✅ `/Users/admin/apps/dev/agl/agl-hostman/scripts/aglsrv1-emergency-remediation.sh` (Automated fix script)

---

## Next Steps

1. Execute immediate remediation (clear /tmp)
2. Run automated remediation script
3. Monitor system for 24 hours
4. Update CLAUDE.md with lessons learned
5. Schedule follow-up diagnostics in 1 week

---

**Report End** - Service Diagnostics Agent
