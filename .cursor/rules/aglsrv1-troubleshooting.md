# AGLSRV1 Troubleshooting Skill for Cursor

> **Contexto**: aglwk45 (VM104) no AGLSRV1 — problemas recorrentes de RDP/CPU/memória
> **Última atualização**: 2026-04-06

## Quando usar

Sempre que o utilizador mencionar:
- "aglwk45 inacessível", "RDP não funciona", "VM104 problema"
- "AGLSRV1 lento", "host sobrecarregado", "memória cheia"
- "OpenClaw não responde", "wk45 offline"

## Diagnóstico Rápido

### 1. Verificar estado da VM104

```bash
# SSH ao AGLSRV1 via Tailscale
ssh root@100.107.113.33 'qm status 104 && qm agent 104 ping'
```

### 2. Verificar meshagent memory leak (CAUSA #1)

```bash
# Detectar meshagents com RSS > 1GB
ssh root@100.107.113.33 'ps aux | grep meshagent | grep -v grep | awk "{if (\$6 > 1000000) print \"LEAK: PID \"\$2\" RSS \"int(\$6/1024)\"MB\"}"'
```

### 3. Verificar memória do host

```bash
ssh root@100.107.113.33 'free -h && uptime'
```

## Resolução

### meshagent Memory Leak Confirmado

```bash
# 1. Matar processos com leak
ssh root@100.107.113.33 'ps aux | grep meshagent | grep -v grep | awk "{if (\$6 > 1000000) print \$2}" | xargs -r kill -9'

# 2. Reboot da VM104
ssh root@100.107.113.33 'qm stop 104 && sleep 3 && qm start 104'

# 3. Verificar recuperação
ssh root@100.107.113.33 'qm agent 104 ping && ping -c 2 -W 2 192.168.0.33'
```

### VM104 CPU Spike (>1000%)

```bash
# Verificar CPU atual
ssh root@100.107.113.33 'ps aux | grep "kvm.*-id 104 " | grep -v grep | awk "{print \"CPU: \"\$3\"%\"}"'

# Se >1000% sustentado → reboot
ssh root@100.107.113.33 'qm stop 104 && sleep 3 && qm start 104'
```

### QEMU Guest Agent Inativo

```bash
# Via guest exec
ssh root@100.107.113.33 'qm guest exec 104 -- powershell -Command "Restart-Service QEMU-GA"'

# Se não responder → reboot VM
ssh root@100.107.113.33 'qm stop 104 && sleep 3 && qm start 104'
```

## Host AGLSRV1 Referência

| Item | Valor |
|------|-------|
| Tailscale IP | `100.107.113.33` |
| LAN IP | `192.168.0.245` |
| RAM | 125GB total |
| Cores | 24 |
| meshagent instâncias | 30+ (alerta: podem vazar) |

## VM104 Configuração

| Item | Valor |
|------|-------|
| VMID | 104 |
| Nome | aglwk45 |
| OS | Windows 11 Pro |
| Cores | 24 |
| RAM | 32GB (balloon: 16384) |
| Disco | 720GB (local-zfs) |
| LAN IP | 192.168.0.33 |
| Tailscale | 100.117.146.21 |
| RDP Port | 3389 |

## Notas Importantes

- **meshagent tem 30+ instâncias** — 3 podem desenvolver memory leak (10-22GB cada)
- **ISO do Sergei Strelec** foi removida de `ide0` (não remontar sem necessidade)
- **Host sem serviço systemd para meshagent** — processos são auto-geridos
- **24 cores é excessivo** para Windows 11 — considerar reduzir para 8-12

## Documentação Completa

- `docs/AGLWK45-SETUP.md` — Setup completo
- `docs/AGLSRV1-TROUBLESHOOTING.md` — Playbook completo
- `docs/aglsrv1-key-findings.md` — Histórico de diagnósticos
