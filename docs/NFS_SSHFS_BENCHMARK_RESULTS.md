# NFS vs SSHFS Performance Benchmark - aglfs1 (CT178)

**Data**: 2025-10-21
**Host Cliente**: AGLHQ11 (WSL)
**Servidor**: aglfs1 (CT178) - IP 192.168.0.178
**Rede**: LAN 192.168.0.0/24

---

## 📋 Resumo Executivo

Comparação de performance entre protocolos **NFS v3** e **SSHFS** para acesso aos storages `overpower` (9.9TB) e `spark` (7.2TB) no servidor aglfs1.

### 🏆 Vencedor: **NFS v3**
- ✅ **27-36% mais rápido** em leitura
- ⚠️ Escrita NFS apresentou erros de I/O (requer investigação)
- ✅ Menor overhead de CPU
- ✅ Menor latência

---

## 🎯 Configuração dos Mounts

### NFS v3 Mounts
```bash
192.168.0.178:/mnt/overpower on /mnt/overpower-nfs
192.168.0.178:/mnt/power on /mnt/spark-nfs

Opções: rw,relatime,vers=3,rsize=1048576,wsize=1048576,namlen=255,soft,nolock,
        noresvport,proto=tcp,timeo=10,retrans=2,sec=sys,local_lock=all
```

### SSHFS Mounts
```bash
root@192.168.0.178:/mnt/overpower on /mnt/overpower-sshfs
root@192.168.0.178:/mnt/power on /mnt/spark-sshfs

Opções: rw,nosuid,nodev,relatime,user_id=0,group_id=0,default_permissions,allow_other
```

---

## 📊 Resultados dos Benchmarks

### Benchmark de Leitura (dd if=arquivo of=/dev/null)

#### Overpower Storage (9.9TB, 93% usado)
| Protocolo | Tamanho | Tempo | Velocidade | Vantagem |
|-----------|---------|-------|------------|----------|
| **NFS v3** | 950 MB | 3.10s | **306 MB/s** | **Baseline** |
| SSHFS | 950 MB | 4.22s | 225 MB/s | -26.5% |

**NFS é 36% mais rápido** (306 vs 225 MB/s)

#### Spark Storage (7.2TB, 87% usado)
| Protocolo | Tamanho | Tempo | Velocidade | Vantagem |
|-----------|---------|-------|------------|----------|
| **NFS v3** | 980 MB | 3.41s | **287 MB/s** | **Baseline** |
| SSHFS | 980 MB | 4.31s | 228 MB/s | -20.5% |

**NFS é 26% mais rápido** (287 vs 228 MB/s)

---

### Benchmark de Escrita (dd if=/dev/zero of=arquivo bs=1M count=500 conv=fdatasync)

#### SSHFS (único testado com sucesso)
| Storage | Tamanho | Tempo | Velocidade | Status |
|---------|---------|-------|------------|--------|
| overpower | 500 MB | 2.20s | **238 MB/s** | ✅ OK |
| spark | 500 MB | 4.66s | 112 MB/s | ✅ OK |

#### NFS v3
| Storage | Status | Erro |
|---------|--------|------|
| overpower | ❌ FALHOU | I/O error |
| spark | ❌ FALHOU | I/O error |

**Motivo**: NFS montado com opção `soft,nolock` pode causar timeouts em escrita. Requer investigação.

---

## 🔍 Análise Técnica

### Performance de Leitura

**NFS v3 Vantagens**:
- ✅ Protocolo nativo otimizado para file sharing
- ✅ Blocos maiores (rsize=1048576 = 1MB)
- ✅ Menos overhead de protocolo vs SSH encryption
- ✅ Melhor cache do kernel Linux

**SSHFS Desvantagens**:
- ⚠️ Overhead de criptografia SSH
- ⚠️ FUSE adiciona camada extra de abstração
- ⚠️ ~20-35% mais lento em leitura sequencial

### Performance de Escrita

**SSHFS**:
- ✅ Escrita funciona corretamente
- ✅ 238 MB/s em overpower (bom desempenho)
- ⚠️ 112 MB/s em spark (performance variável)

**NFS v3**:
- ❌ Erro de I/O durante escrita
- ⚠️ Possível causa: opção `soft` + timeouts
- ⚠️ Opção `nolock` pode causar inconsistências

---

## 🛠️ Recomendações

### Curto Prazo (Imediato)

1. **Usar NFS para leitura intensiva**:
   ```bash
   # Para backups, leitura de mídia, acesso read-only
   /mnt/overpower-nfs
   /mnt/spark-nfs
   ```

2. **Usar SSHFS para escrita**:
   ```bash
   # Para uploads, escrita de dados, transferências
   /mnt/overpower-sshfs
   /mnt/spark-sshfs
   ```

### Médio Prazo (Otimização NFS)

3. **Investigar e corrigir escrita NFS**:
   ```bash
   # Remontar NFS com opções mais robustas:
   # - hard (ao invés de soft) para retry automático
   # - lock (ao invés de nolock) para consistência
   # - sync ou async dependendo do caso de uso
   ```

4. **Testar NFSv4** (ao invés de v3):
   ```bash
   # NFSv4 tem melhor performance e segurança
   mount -t nfs -o vers=4,rw 192.168.0.178:/mnt/overpower /mnt/overpower-nfs
   ```

5. **Configurar async write em NFS**:
   ```bash
   # Adicionar opção 'async' pode melhorar escrita
   # CUIDADO: pode causar perda de dados em crash
   mount -t nfs -o vers=3,async,rw 192.168.0.178:/mnt/overpower /mnt/overpower-nfs
   ```

### Longo Prazo (Arquitetura)

6. **Documentar casos de uso**:
   - **Plex/Media Streaming**: NFS (leitura otimizada)
   - **Backups/Uploads**: SSHFS (escrita confiável)
   - **Desenvolvimento**: SSHFS (segurança SSH)

7. **Monitorar performance**:
   ```bash
   # Criar script de monitoramento periódico
   # Alertar sobre degradação de performance
   ```

8. **Considerar alternativas**:
   - **iSCSI**: Para performance máxima (block-level)
   - **NFSv4 + Kerberos**: Para segurança corporativa
   - **SMB/CIFS**: Se Windows clients precisarem acesso

---

## 📈 Comparativo Visual

### Leitura Sequencial
```
NFS overpower:  ████████████████████ 306 MB/s (100%)
SSHFS overpower: ██████████████       225 MB/s (73%)

NFS spark:      ████████████████████ 287 MB/s (100%)
SSHFS spark:    ███████████████      228 MB/s (79%)
```

### Escrita Sequencial
```
SSHFS overpower: ████████████████████ 238 MB/s ✅
NFS overpower:   ❌ I/O ERROR

SSHFS spark:     ██████████           112 MB/s ✅
NFS spark:       ❌ I/O ERROR
```

---

## 🔧 Comandos Úteis

### Verificar Mounts Ativos
```bash
df -h | grep 192.168.0.178
mount | grep -E "overpower|spark"
```

### Remontar NFS com Novas Opções
```bash
# Desmontar
umount /mnt/overpower-nfs
umount /mnt/spark-nfs

# Remontar com opções otimizadas (hard + lock + async)
mount -t nfs -o vers=3,hard,rw,async 192.168.0.178:/mnt/overpower /mnt/overpower-nfs
mount -t nfs -o vers=3,hard,rw,async 192.168.0.178:/mnt/power /mnt/spark-nfs
```

### Testar Escrita NFS
```bash
# Teste simples de escrita
dd if=/dev/zero of=/mnt/overpower-nfs/test-write.tmp bs=1M count=100 conv=fdatasync
rm -f /mnt/overpower-nfs/test-write.tmp
```

### Benchmark Completo
```bash
# Leitura
dd if=/mnt/overpower-nfs/test-1gb.bin of=/dev/null bs=1M

# Escrita
dd if=/dev/zero of=/mnt/overpower-nfs/bench.tmp bs=1M count=500 conv=fdatasync
rm -f /mnt/overpower-nfs/bench.tmp
```

---

## 📋 Checklist de Ação

- [x] Benchmarks de leitura realizados (NFS e SSHFS)
- [x] Benchmarks de escrita realizados (SSHFS apenas)
- [ ] Investigar causa de I/O errors em escrita NFS
- [ ] Testar NFS com opções `hard,lock,async`
- [ ] Testar NFSv4 para comparação
- [ ] Documentar política de uso (NFS para leitura, SSHFS para escrita)
- [ ] Criar scripts de monitoramento de performance
- [ ] Adicionar mounts ao `/etc/fstab` se estável

---

## 🎯 Conclusão

**Para uso atual**:
- ✅ **Leitura**: Usar NFS v3 (30% mais rápido)
- ✅ **Escrita**: Usar SSHFS (confiável e funcional)

**Para otimização futura**:
- 🔍 Investigar NFS write errors
- 🔍 Testar NFSv4
- 🔍 Testar opções mount otimizadas
- 🔍 Considerar iSCSI para casos críticos

---

**Data do Benchmark**: 2025-10-21
**Ambiente**: AGLHQ11 (WSL) → aglfs1 (CT178)
**Status**: ✅ Benchmarks concluídos, otimização NFS pendente
