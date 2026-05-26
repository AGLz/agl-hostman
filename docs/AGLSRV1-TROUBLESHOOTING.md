# AGLSRV1 Troubleshooting Playbook

> **Última atualização**: 2026-05-25
> **Host**: aglsrv1 | **Tailscale**: `100.107.113.33` | **LAN**: `192.168.0.245`

## TL;DR — Runbook de Emergência

Quando aglwk45 (VM104) estiver inacessível via RDP:

```bash
HOST="root@100.107.113.33"

# 1. Diagnóstico rápido
ssh $HOST 'echo "=== VM104 ===" && qm status 104 && qm agent 104 ping 2>&1 && echo "" && echo "=== Load ===" && uptime && echo "" && echo "=== Memory ===" && free -h && echo "" && echo "=== Meshagents Leak ===" && ps aux | grep meshagent | grep -v grep | awk "{if (\$6 > 1000000) print \"LEAK: PID \"\$2\" RSS \"int(\$6/1024)\"MB\"}"'

# 2. Se meshagents com leak (>1GB RSS) → matar
ssh $HOST 'ps aux | grep meshagent | grep -v grep | awk "{if (\$6 > 1000000) print \$2}" | xargs -r kill -9'

# 3. Reboot VM104
ssh $HOST 'qm stop 104 && sleep 3 && qm start 104'

# 4. Verificar recuperação
ssh $HOST 'qm agent 104 ping && echo "GA: OK" && ping -c 2 -W 2 192.168.0.33'
```

---

## Problemas Conhecidos

### 1. meshagent Memory Leak (CRÍTICO)

**Frequência**: Recorrente (pelo menos desde Mar 2025)
**Impacto**: Host colapsa — load 146+, rede timeout, todas as VMs afetadas

**Detalhe**: 30+ instâncias de meshagent rodam no host. 3 delas podem desenvolver memory leak, consumindo 10-22GB RAM cada.

**Detecção**:
```bash
# Processos com RSS > 1GB são leak confirmado
ps aux | grep meshagent | grep -v grep | awk '{if ($6 > 1000000) print "LEAK: PID "$2" RSS "int($6/1024)"MB"}'
```

**Histórico de leaks (2026-04-06)**:
| PID | RSS | CPU% | Inicio |
|-----|-----|------|--------|
| 1827260 | 22GB | 14.2% | Mar16 |
| 57783 | 14GB | 0% | Mar15 |
| 2468815 | 13GB | 0% | Mar27 |

**Resolução**: `kill -9` nos PIDs com leak. Sem serviço systemd — os processos são auto-geridos.

**Prevenção futura**: Investigar porque existem 30+ instâncias. Idealmente deveria haver apenas 1.

### 2. VM104 CPU Spike

**Causa**: Windows update, indexer, ou processo hung após boot
**Normal**: 200-300% no boot, estabiliza em 50-100%
**Alerta**: >1000% sustentado = processo hung

```bash
ssh root@100.107.113.33 'ps aux | grep "kvm.*-id 104 " | grep -v grep | awk "{print \"CPU: \"\$3\"%\"}"'
```

### 3. QEMU Guest Agent Inativo

**Sintoma**: `qm agent 104 ping` retorna "not running"
**Causa**: Serviço Windows `QEMU-GA` parado ou VM em estado inconsistente

**Fix**:
```bash
# Via guest exec (se ainda responder)
ssh root@100.107.113.33 'qm guest exec 104 -- powershell -Command "Restart-Service QEMU-GA"'

# Se não responder → reboot VM
ssh root@100.107.113.33 'qm stop 104 && sleep 3 && qm start 104'
```

### 4. ISO Montada Desnecessária

A ISO do Sergei Strelec (`WinPE11_10_8_Sergei_Strelec_x86_x64_2024.08.21_English.iso`) estava montada em `ide0`. Já foi removida:

```bash
qm set 104 --ide0 none,media=cdrom
```

### 5. WebUI — login bloqueado (SSH OK) — NFS CT111

**Frequência**: Quando CT111 (`10.6.0.20` WG) está offline  
**Impacto**: Login WebUI impossível; VMs/CTs continuam a correr  
**Incidente documentado**: [`AGLSRV1-WEBUI-LOGIN-NFS-BLOCK-2026-05-25.md`](AGLSRV1-WEBUI-LOGIN-NFS-BLOCK-2026-05-25.md)

**Sintoma**: página `https://192.168.0.245:8006` carrega; login falha com HTTP 500 ou timeout. SSH com `root` funciona.

**Causa**: `pvedaemon worker` em estado **`D`**, bloqueado em NFS `hard` para `/mnt/pve/ct111-shares` e `/mnt/pve/ct111-sistema` (`10.6.0.20` inacessível). Também `pvestatd` pode ficar preso.

**Detecção**:

```bash
ssh root@100.107.113.33 '
  ps aux | awk "\$8 ~ /D/ && /pve(daemon|statd)/ {print}"
  ping -c 2 -W 2 10.6.0.20
  grep access/ticket /var/log/pveproxy/access.log | tail -5
'
```

**Fix imediato** (sem reboot do host):

```bash
ssh root@100.107.113.33 '
  systemctl restart pvedaemon pveproxy
  umount -l /mnt/pve/ct111-shares /mnt/pve/ct111-sistema 2>/dev/null
  systemctl restart pvestatd
'
```

**Login WebUI**: utilizador `root`, realm **Linux PAM standard authentication** (não «Proxmox VE authentication server»).

**Prevenção**: repor CT111 no AGLSRV6 ou desactivar storage `ct111-*` no Proxmox enquanto o peer WG estiver down.

---

## Estado Atual do Host (2026-04-06)

| Recurso | Valor |
|---------|-------|
| RAM Total | 125GB |
| RAM Disponível | ~15GB (pós-cleanup) |
| Swap | 79GB total, 64GB usada |
| Cores | 24 |
| Load Average Normal | <10 |
| Load Average Sob Leak | 146+ |
| meshagent instâncias | 30+ (~750MB total sem leak) |

### VMs/CTs Importantes no AGLSRV1

| VMID | Nome | RAM | Função |
|------|------|-----|--------|
| 104 | aglwk45 | 32GB | Windows 11 Workstation (OpenClaw) |
| 148 | zabbix | 4GB | Monitoring |

---

## Configuração VM104 (referência)

```
cores: 24
sockets: 1
memory: 32768
balloon: 16384
cpu: host,hidden=1,flags=+pcid;+spec-ctrl;+hv-evmcs;+aes
scsi0: local-zfs, aio=threads, cache=directsync, iothread=1, size=720G
net0: virtio, bridge=vmbr0, queues=16
vga: virtio
agent: 1
ostype: win11
```

**Nota**: 24 cores é excessivo para Windows 11 workstation. Se CPU spikes forem frequentes, reduzir para 8-12 cores:
```bash
qm set 104 --cores 8
```

---

## Scripts Úteis

| Script | Função |
|--------|--------|
| `scripts/verify-aglwk45-fgsrv06.sh` | Verificação completa VM104 + fgsrv06 |
| `scripts/verify-openclaw-aglwk45.sh` | OpenClaw check (Git Bash) |
| `scripts/verify-openclaw-aglwk45.ps1` | OpenClaw check (PowerShell) |

---

## Referências

- `docs/AGLSRV1-WEBUI-LOGIN-NFS-BLOCK-2026-05-25.md` — Incidente WebUI + NFS CT111 (2026-05-25)
- `docs/AGLWK45-SETUP.md` — Setup completo da VM104
- `docs/aglsrv1-key-findings.md` — Diagnósticos históricos
- `docs/WINDOWS11-PROXMOX-OPTIMIZATION.md` — Otimizações Windows 11 no Proxmox
- `docs/OPENCLAW.md` — Documentação OpenClaw
