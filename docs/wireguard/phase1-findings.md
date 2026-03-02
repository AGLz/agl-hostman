# WireGuard Phase 1 - Findings and Recommendations
**Date**: 2025-10-16
**Status**: Infrastructure Análise Completa

## 📊 Executive Summary

Completamos a análise e tentativa de implementação do WireGuard kernel puro para melhorar a performance entre AGLSRV1 e AGLSRV6. Descobrimos limitações importantes que impactam a viabilidade da solução.

## ✅ O Que Foi Feito

### 1. Infraestrutura WireGuard Criada
- **CT121** criado no AGLSRV6 (192.168.0.18)
- **CT120** já existente no AGLSRV1 (192.168.0.120)
- WireGuard kernel instalado em ambos
- Kernel tuning aplicado (BBR, buffers TCP)
- Mesh configurado: 10.6.0.0/24

### 2. Chaves e Configuração
```
CT120 (Hub):  10.6.0.1:51820
CT121 (Spoke): 10.6.0.3:51821
```

Chaves geradas com PSK para segurança adicional.

### 3. Tentativas de Conectividade

#### Tentativa 1: LAN Direta ❌
- **Problema**: AGLSRV1 e AGLSRV6 estão em locais FÍSICOS diferentes
- **Resultado**: Sem conectividade (192.168.0.x não roteável entre sites)

#### Tentativa 2: Internet Pública ❌
- **IPs Públicos Identificados**:
  - AGLSRV1: 191.183.137.104
  - AGLSRV6: 189.100.68.34
- **Bloqueador**: Requer port forwarding manual nos routers
- **Risco**: Expor portas UDP na internet (segurança)

#### Tentativa 3: Tailscale como Transporte ❌
- **Configuração**: Port forwarding Tailscale → Container
- **Problema**: Pacotes UDP WireGuard não atravessam Tailscale corretamente
- **Resultado**: 0% conectividade entre CT120 ↔ CT121

## 🔍 Descobertas Importantes

### 1. Performance Atual (Baseline)

**NFS sobre Tailscale (FGSRV5)**:
```
Write Performance: 3.6-3.8 MB/s
```

**Configuração Atual**:
```
Mount: NFS v4.2
Options: nconnect=4, rsize=524KB, wsize=524KB
TCP: BBR congestion control
Buffers: 128MB rmem/wmem
```

### 2. Limitações do Tailscale

- **Userspace Implementation**: WireGuard-go (não kernel)
- **Overhead**: Encapsulamento adicional
- **CPU**: Processamento userspace mais intensivo
- **Latência**: +5-10ms vs kernel mode

### 3. Complexidade do WireGuard Puro

**Desafios Identificados**:
1. **Port Forwarding Necessário**: Ambos routers precisam ser configurados manualmente
2. **Segurança**: Expor portas UDP na internet
3. **NAT Traversal**: Complexidade adicional se IPs mudarem
4. **Manutenção**: Configuração manual em múltiplos pontos

## 📈 Performance Comparison

| Método | Throughput Esperado | Implementação | Segurança | Status |
|--------|---------------------|---------------|-----------|--------|
| Tailscale (atual) | 3-4 MB/s | ✅ Funciona | ✅ Ótima | ✅ Ativo |
| WireGuard Kernel (puro) | 40-60 MB/s | ⚠️ Complexo | ⚠️ Requer port forward | ❌ Bloqueado |
| WireGuard sobre Tailscale | 5-8 MB/s | ❌ Não funciona | ✅ Ótima | ❌ Falhou |
| Netmaker | 15-20 MB/s | ⏳ Não testado | ✅ Boa | ⏳ Opção futura |

## 💡 Recomendações

### Opção 1: Otimizar Tailscale Existente (RECOMENDADO)

**Benefícios**:
✓ Já está funcionando
✓ Sem mudanças de infraestrutura
✓ Seguro (criptografia end-to-end)
✓ Zero configuração de router

**Otimizações Possíveis**:
1. **Atualizar Tailscale** para última versão
2. **Tuning NFS**:
   - Aumentar rsize/wsize para 1MB
   - Testar nconnect=8 ou nconnect=16
   - async ao invés de sync (se aceitável)
3. **Kernel Tuning**:
   - Já aplicado (BBR, buffers grandes)
4. **Compressão NFS**: Desabilitar (overhead > benefício)

**Performance Esperada**: 5-7 MB/s (melhora de 40-80%)

### Opção 2: Netmaker (Médio Prazo)

**O Que é**: VPN mesh com WireGuard kernel + gerenciamento centralizado

**Benefícios**:
✓ WireGuard kernel mode (não userspace)
✓ Configuração automática de peers
✓ NAT traversal automático
✓ Performance 4-5x melhor que Tailscale

**Implementação**:
- Instalar Netmaker server (1 hora)
- Registrar todos hosts (30 min)
- Migrar gradualmente de Tailscale

**Performance Esperada**: 15-20 MB/s

### Opção 3: WireGuard Puro (Longo Prazo)

**Quando Considerar**:
- Se Netmaker não atender
- Se performance crítica justificar complexidade
- Se puder gerenciar port forwarding

**Requisitos**:
- Configurar port forwarding em 4+ routers
- Implementar monitoramento de conectividade
- Gerenciar IPs públicos (idealmente estáticos)

**Performance Esperada**: 40-60 MB/s

## 🎯 Ação Imediata Recomendada

### 1. Otimizar Tailscale (Esta Semana)

```bash
# FGSRV5: Remontar com opções otimizadas
umount /mnt/pve/fgsrv5-nfs
mount -t nfs -o vers=4.2,rsize=1048576,wsize=1048576,nconnect=8,hard,intr,noatime 100.71.107.26:/ /mnt/pve/fgsrv5-nfs

# Teste
dd if=/dev/zero of=/mnt/pve/fgsrv5-nfs/test.dat bs=1M count=500 oflag=direct
```

### 2. Avaliar Netmaker (Próximo Mês)

- Pesquisar caso de uso similar
- Testar em lab (CT temporário)
- Benchmark vs Tailscale
- Decidir migração

### 3. Documentar Alternativas (Background)

- Manter WireGuard configs para referência futura
- Documentar port forwarding necessário
- Avaliar custos/benefícios periodicamente

## 📁 Arquivos Criados

```
/root/host-admin/docs/wireguard/
├── mesh-architecture-plan.md
├── deployment-guide.md
├── router-port-forwarding.md
├── NEXT-STEPS.md
└── phase1-findings.md (este arquivo)

/root/host-admin/scripts/wireguard/
└── deploy-wireguard-mesh.sh

/root/wireguard-keys/
├── aglsrv6-ct/
├── fgsrv5/
└── fgsrv6/
```

## 🔐 Segurança

**Chaves Geradas** (manter seguras):
- Nunca commitar para git
- Backup em local seguro
- Rotação a cada 6 meses se implementar

## 📊 Performance Atual Detalhada

### FGSRV5 NFS
```
Protocol: NFS v4.2 over Tailscale
Write: 3.6-3.8 MB/s
Read: (não testado ainda)
Latência: ~15-20ms
CPU: ~10-15% (NFS + Tailscale)
```

### FGSRV6 NFS
```
Protocol: NFS v4.2 over Tailscale
Write: (baseline anterior: 12.6 MB/s - precisa re-teste)
Read: (baseline anterior: 5.5 MB/s - precisa re-teste)
Storage: 132GB disponível
```

## 🚀 Próximos Passos

1. ✅ **Completo**: Análise de viabilidade WireGuard
2. ✅ **Completo**: Performance baseline Tailscale
3. ⏳ **Próximo**: Otimizar NFS mounts (rsize/wsize/nconnect)
4. ⏳ **Próximo**: Re-testar performance FGSRV5 e FGSRV6
5. ⏳ **Futuro**: Avaliar Netmaker
6. ⏳ **Futuro**: Considerar WireGuard puro (se justificável)

## 💭 Conclusão

**WireGuard kernel puro** ofereceria performance excelente (10-15x melhoria) mas a complexidade de implementação e requisitos de segurança não justificam a mudança no momento.

**Recomendação final**:
1. Otimizar Tailscale existente (ganho de 40-80%)
2. Avaliar Netmaker em 30 dias (ganho de 4-5x)
3. Manter WireGuard puro como opção de longo prazo

---

**Status**: Análise Completa ✅
**Decisão**: Otimizar infraestrutura atual
**ROI**: Melhor custo/benefício com Tailscale otimizado
**Risco**: Baixo (sem mudanças de infraestrutura)
