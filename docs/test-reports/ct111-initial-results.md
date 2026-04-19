# 📊 CT111 Initial Performance Test Results

**Date:** 2025-10-15 03:15 UTC
**Test Target:** CT111 @ AGLSRV6 (100.65.189.83)
**Test Source:** AGLSRV1
**Network:** Tailscale VPN (direct P2P connection)

---

## 🌐 Network Characteristics

### Tailscale Connection
- **Status:** Active - Direct P2P
- **Latency (avg):** 23.3ms
- **Latency (min/max):** 19.4ms / 30.7ms
- **Remote Endpoint:** 189.100.68.34:17263
- **Connection Type:** Direct (não está usando DERP relay) ✅

### Storage Backend (CT111)
- **Filesystem:** XFS on /dev/mapper/pve-root
- **Mount:** /mnt/shares
- **Local Write Speed:** **331 MB/s** (baseline excelente)
- **Available Space:** 34GB / 66GB (49% used)

---

## 📈 Performance Test Results

### Test Parameters
- **File Size:** 500MB (scaled down due to network limitations)
- **Block Size:** 1MB
- **Sync Mode:** fdatasync (garantir dados em disco)

### SSHFS Performance (Baseline)
| Metric | Result |
|--------|--------|
| **Sequential Write** | **10.0 MB/s** |
| **Test Duration** | 52.5 seconds |
| **Status** | ✅ Completed |

### NFS v4.2 Performance
| Metric | Result |
|--------|--------|
| **Sequential Write** | **10.6 MB/s** |
| **Test Duration** | 49.3 seconds |
| **Mount Options** | vers=4.2, rsize=1048576, wsize=1048576, nconnect=4 |
| **Status** | ✅ Completed |

---

## 🔍 Analysis

### Key Findings

1. **Performance Similar Between Protocols**
   - SSHFS: 10.0 MB/s
   - NFS v4.2: 10.6 MB/s
   - **Diferença:** +6% (marginal)

2. **Bottleneck Identificado: REDE TAILSCALE**
   - Storage local CT111: **331 MB/s** ✅
   - Performance remota: **~10 MB/s** ❌
   - **Limitação:** ~97% de overhead de rede

3. **Latência Aceitável**
   - Média 23ms está OK para VPN
   - Conexão direta P2P (não usando relay)

### Root Cause: Tailscale Bandwidth Limitation

**Possíveis causas da limitação a 10 MB/s:**

1. **WAN Bandwidth Limitado**
   - Provavelmente limitado pelo uplink/downlink da internet
   - 10 MB/s = 80 Mbps (típico para conexões DSL/fibra entry-level)

2. **Não é problema do protocolo**
   - SSHFS e NFS performam similarmente
   - Indica limitação abaixo da camada de protocolo

3. **CPU/Encryption Overhead**
   - WireGuard (Tailscale) com baixo overhead
   - Não parece ser gargalo (performance similar entre protocolos)

---

## 🎯 Recommendations

### Imediato

1. **✅ NFS v4.2 é Válido**
   - Performance equivalente ao SSHFS
   - Melhor para operações de metadata
   - Mais estável para production

2. **⚠️ Expectativas Realistas**
   - Com bandwidth atual: esperar ~10-12 MB/s
   - Para melhorar: necessário upgrade de rede WAN

### Melhorias de Rede Possíveis

#### Opção A: Otimizar Tailscale (Ganho +20-30%)
```bash
# Aumentar MTU
sudo ip link set dev tailscale0 mtu 1420

# Habilitar BBR congestion control
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

# Aumentar buffers TCP
echo "net.core.rmem_max = 134217728" >> /etc/sysctl.conf
echo "net.core.wmem_max = 134217728" >> /etc/sysctl.conf
sysctl -p
```

**Ganho esperado:** 10 MB/s → 12-15 MB/s

#### Opção B: Testar Hosts na Mesma Rede Local
- **AGLSRV6 ↔ AGLSRV6b:** Mesma LAN = 500-1000 MB/s
- **Validar:** NFS v4.2 pode atingir performance máxima

#### Opção C: Comprimir Dados (Trade-off CPU vs Bandwidth)
```bash
# rsync com compressão
rsync -avz --compress-level=1 source/ remote:/dest/

# NFS com compressão (não nativo, usar nfs-ganesha)
```

**Ganho esperado:** Depende do tipo de dados (logs/text: 3-5x, binários: 1.1-1.3x)

---

## 📋 Next Steps

### Fase 1: Validação em Rede Local ✅ PRÓXIMO
```bash
# Testar AGLSRV6 → AGLSRV6b (mesma rede local)
# Esperar: 500-1000 MB/s com NFS v4.2
```

### Fase 2: Deploy em FGSRV5/FGSRV6
```bash
# Instalar NFS v4.2 nos hosts remotos
/root/host-admin/scripts/deploy-nfs-to-remote.sh --host 100.71.107.26 --hostname FGSRV5
/root/host-admin/scripts/deploy-nfs-to-remote.sh --host 100.83.51.9 --hostname FGSRV6
```

### Fase 3: Otimizações de Rede
```bash
# Aplicar tuning Tailscale em todos os hosts
# Testar com compressão para workloads específicos
```

---

## 💡 Conclusões

### ✅ O Que Funciona
- NFS v4.2 montando e operando corretamente
- Conexão Tailscale direta (P2P) estabelecida
- Storage local CT111 com performance excelente

### ⚠️ Limitações Encontradas
- **Bandwidth Tailscale:** ~10 MB/s (80 Mbps)
- Provável limitação de WAN, não do protocolo
- NFS v4.2 não resolve limitação de rede WAN

### 🎯 Valor do NFS v4.2
Mesmo com bandwidth limitado, NFS v4.2 oferece:
1. **Estabilidade:** Mais robusto que SSHFS
2. **Metadata:** Operações de diretório mais rápidas
3. **Features:** ACLs, locks, parallel connections
4. **Production-ready:** Melhor para cargas críticas

---

## 📊 Summary Table

| Aspect | SSHFS | NFS v4.2 | Winner |
|--------|-------|----------|--------|
| **Write Speed** | 10.0 MB/s | 10.6 MB/s | NFS (+6%) |
| **Stability** | Médio | Alto | NFS ✅ |
| **Metadata Ops** | Lento | Rápido | NFS ✅ |
| **Setup Complexity** | Simples | Médio | SSHFS |
| **Production Use** | Não recomendado | Recomendado | NFS ✅ |
| **Network Overhead** | ~97% | ~97% | Empate |

---

**Recomendação Final:**
- ✅ **Migrar para NFS v4.2** para melhor estabilidade e features
- ⚠️ **Expectativa realista:** ~10-12 MB/s com bandwidth WAN atual
- 🚀 **Testar rede local** para validar NFS pode atingir >500 MB/s
- 📈 **Considerar upgrade WAN** se throughput for crítico

---

**Teste realizado por:** Hive Mind Collective Intelligence
**Próximo teste:** AGLSRV6 ↔ AGLSRV6b (local network validation)
**Status:** ✅ Baseline estabelecido, pronto para próxima fase
