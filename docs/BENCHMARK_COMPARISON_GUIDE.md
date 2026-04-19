# Guia de Benchmark Comparativo: SMB vs NFS vs SSHFS
**Data**: 2025-10-21
**Servidor**: aglfs1 (192.168.0.178)
**Cliente**: Windows 11 + WSL2
**Objetivo**: Comparar performance dos 3 protocolos de acesso remoto

---

## 📋 Sumário Executivo

Este guia fornece ferramentas completas para:
1. **Benchmark individual** de cada protocolo (SMB, NFS, SSHFS)
2. **Comparação automática** entre protocolos
3. **Análise Windows vs WSL** - verificar diferença de performance entre ambientes
4. **Relatórios detalhados** em formato Markdown

### Scripts Disponíveis

| Script | Ambiente | Protocolos Testados | Uso |
|--------|----------|---------------------|-----|
| `benchmark-all-protocols.sh` | WSL | SMB, NFS, SSHFS | Benchmark completo no WSL |
| `benchmark-all-protocols-windows.ps1` | Windows | SMB, NFS, SSHFS (via WSL) | Benchmark completo no Windows |
| `benchmark-smb-complete.sh` | WSL | SMB vs SSHFS | Foco em SMB |
| `benchmark-smb-windows.ps1` | Windows | SMB, NFS | Benchmark Windows puro |
| `MIGRATE-NFS-TO-SMB-SAFE.ps1` | Windows | - | Migração segura NFS → SMB |

---

## 🚀 Como Executar os Benchmarks

### Opção 1: Benchmark Completo no WSL (Recomendado)

```bash
# No WSL
cd /root/agl-hostman/scripts
chmod +x benchmark-all-protocols.sh
sudo ./benchmark-all-protocols.sh
```

**O que testa**:
- ✅ SMB via `/mnt/r` e `/mnt/s` (drives Windows R: e S:)
- ✅ NFS via `/mnt/y` e `/mnt/z` (drives Windows Y: e Z:) - se disponíveis
- ✅ SSHFS via `/mnt/nfs-overpower-base` e `/mnt/spark-sshfs` - se montados

**Saída**:
- Log detalhado em `/tmp/protocol-benchmark-*.log`
- Relatório completo em `/root/agl-hostman/docs/test-reports/benchmark-protocols-*.md`
- Resumo comparativo na tela

### Opção 2: Benchmark Completo no Windows

```powershell
# No PowerShell como Administrador
cd C:\temp
.\benchmark-all-protocols-windows.ps1
```

**O que testa**:
- ✅ SMB via drives R:, S:, T:, U:
- ✅ NFS via drives Y:, Z: (se montados)
- ✅ SSHFS via WSL (executa comandos no WSL automaticamente)

**Saída**:
- Log detalhado em `C:\NFS\benchmark-all-protocols-*.log`
- Relatório completo em `C:\NFS\benchmark-report-*.md`
- Resumo comparativo na tela

### Opção 3: Benchmark SMB Focado (WSL)

```bash
# No WSL - foco em SMB
cd /root/agl-hostman/scripts
chmod +x benchmark-smb-complete.sh
./benchmark-smb-complete.sh
```

**O que testa**:
- ✅ R: (overpower) via SMB
- ✅ S: (spark) via SMB
- ✅ SSHFS (comparação) - se disponível

**Mais rápido** que benchmark completo (apenas protocolos principais).

### Opção 4: Benchmark Windows Puro (Sem WSL)

```powershell
# No PowerShell como Administrador
cd C:\temp
.\benchmark-smb-windows.ps1
```

**O que testa**:
- ✅ Todos os drives disponíveis (R:, S:, T:, U:, Y:, Z:)
- ✅ Identifica automaticamente protocolo (SMB vs NFS)
- ✅ Não depende do WSL

---

## 📊 Interpretando os Resultados

### Escala de Performance

| Velocidade | Classificação | Cor | Observação |
|------------|---------------|-----|------------|
| > 150 MB/s | Excelente | 🟢 Verde | Performance ideal para LAN gigabit |
| 75-150 MB/s | Bom | 🟡 Amarelo | Aceitável para uso geral |
| < 75 MB/s | Fraco | 🔴 Vermelho | Possível gargalo ou problema |

### Fatores que Afetam Performance

1. **Protocolo**:
   - NFS: Geralmente mais rápido (250-300 MB/s teórico)
   - SMB: Ligeiramente mais lento (200-280 MB/s teórico)
   - SSHFS: ~20-30% mais lento devido overhead SSH (50-200 MB/s)

2. **Ambiente**:
   - **Windows direto**: Melhor performance (acesso nativo)
   - **WSL via DrvFs**: ~10-20% overhead (camada de tradução)
   - **WSL nativo**: Melhor para SSHFS

3. **Operação**:
   - **Leitura**: Geralmente mais rápida (beneficia de cache)
   - **Escrita**: Mais lenta (requer sync com disco)

4. **Hardware**:
   - Rede: Gigabit LAN = máx ~125 MB/s teórico
   - Disco servidor: SSD vs HDD
   - Carga do servidor: Outros acessos simultâneos

---

## 🎯 Cenários de Uso

### Cenário 1: Máxima Performance
**Objetivo**: Maior velocidade possível

**Recomendação**:
1. **Windows**: Usar NFS direto (Y:, Z:) - 250-300 MB/s
2. **WSL**: Usar SMB via `/mnt/r`, `/mnt/s` - 200-250 MB/s

**Trade-off**: NFS tem problemas de estabilidade (serviço NfsClnt trava)

### Cenário 2: Máxima Estabilidade
**Objetivo**: Confiabilidade e zero problemas

**Recomendação**:
1. **Windows**: Usar SMB (R:, S:, T:, U:) - 180-250 MB/s
2. **WSL**: Usar SSHFS nativo - 50-200 MB/s

**Benefício**: Sem travamentos, auto-reconnect, integração perfeita

### Cenário 3: Independência do Windows
**Objetivo**: WSL funcionar sem depender do Windows

**Recomendação**:
1. **WSL**: Usar SSHFS direto (`/mnt/nfs-*`) - 50-200 MB/s
2. Script auto-mount já configurado

**Benefício**: WSL totalmente autônomo, funciona mesmo se Windows mudar configuração

### Cenário 4: Melhor de Ambos
**Objetivo**: Performance + Estabilidade

**Recomendação** (NOSSA ESCOLHA):
1. **Migrar Y: e Z: de NFS para SMB**
2. **Windows**: Acessar via R:, S: (ou Y:, Z: SMB)
3. **WSL**: Acessar via `/mnt/r`, `/mnt/s` (ou `/mnt/y`, `/mnt/z` se migrado)
4. **Backup**: Manter SSHFS configurado como fallback

**Performance esperada**: 180-250 MB/s
**Estabilidade**: Excelente
**Integração**: Perfeita Windows + WSL

---

## 📈 Análise Comparativa

### Pergunta: "Windows é mais rápido que WSL?"

**Resposta**: Depende do protocolo e acesso.

| Protocolo | Windows Direto | WSL via DrvFs (/mnt/r) | WSL Nativo (SSHFS) |
|-----------|----------------|------------------------|-------------------|
| **SMB** | 200-280 MB/s | 180-250 MB/s (~10% overhead) | N/A |
| **NFS** | 250-300 MB/s | Não funciona (DrvFs não suporta) | N/A |
| **SSHFS** | N/A | N/A | 50-200 MB/s |

**Conclusão**:
- **SMB**: Windows ~10-20% mais rápido que WSL (overhead DrvFs)
- **NFS**: Apenas Windows funciona (WSL não detecta)
- **SSHFS**: Apenas WSL nativo (mais lento mas independente)

### Pergunta: "Vale a pena migrar NFS para SMB?"

**Análise**:

| Aspecto | NFS | SMB | Vencedor |
|---------|-----|-----|----------|
| **Performance** | 250-300 MB/s | 200-280 MB/s | NFS (+10-20%) |
| **Estabilidade** | ❌ Serviço trava | ✅ Estável | **SMB** |
| **WSL Visibilidade** | ❌ Não aparece | ✅ Auto /mnt/* | **SMB** |
| **Explorer Status** | ❌ "Disconnected" | ✅ "OK" | **SMB** |
| **Auto-mount** | ⚠️ Requer script | ✅ Nativo | **SMB** |
| **Manutenção** | ⚠️ Complexo | ✅ Simples | **SMB** |

**Conclusão**: ✅ **SIM, vale a pena migrar**
- Perda de ~10-20% performance
- Ganho de 100% estabilidade e integração
- Trade-off favorável em ambiente Windows + WSL

---

## 🔧 Troubleshooting Benchmarks

### Problema: "Velocidades muito baixas (< 30 MB/s)"

**Possíveis causas**:
1. **Rede lenta**: Verificar se está em gigabit (`ethtool eth0`)
2. **Servidor sobrecarregado**: Verificar carga no aglfs1
3. **Disco servidor lento**: HDD vs SSD
4. **Cache interferindo**: Resultado de leitura pode estar cacheado

**Solução**:
```bash
# Limpar cache antes de ler
sync
sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'

# Verificar rede
ethtool eth0 | grep Speed
# Esperado: Speed: 1000Mb/s
```

### Problema: "Escrita falha com I/O error"

**Possíveis causas**:
1. **Sem espaço em disco**: Verificar `df -h`
2. **Sem permissão de escrita**: Verificar `ls -la /mnt/r`
3. **Mount read-only**: Verificar `mount | grep /mnt/r`

**Solução**:
```bash
# Verificar espaço
df -h /mnt/r

# Verificar permissões
ls -la /mnt/r
# Deve mostrar: drwxrwxrwx ou similar

# Verificar mount options
mount | grep /mnt/r
# Não deve ter 'ro' (read-only)
```

### Problema: "SSHFS não montado"

**Solução**:
```bash
# Executar script de auto-mount
/usr/local/bin/wsl-mount-nfs-shares.sh

# Verificar log
tail -f /var/log/wsl-mount-nfs.log

# Montar manualmente
sshfs root@192.168.0.178:/mnt/overpower /mnt/nfs-overpower-base \
  -o allow_other,default_permissions,reconnect,ServerAliveInterval=15
```

### Problema: "Y: ou Z: não aparecem no WSL"

**Causa**: WSL DrvFs não suporta mounts NFS do Windows.

**Solução**:
```powershell
# Opção 1: Migrar para SMB
C:\temp\MIGRATE-NFS-TO-SMB-SAFE.ps1

# Opção 2: Usar SSHFS direto no WSL (independente do Windows)
```

---

## 📚 Relatórios Gerados

### Estrutura dos Relatórios

```
/root/agl-hostman/docs/test-reports/
├── benchmark-protocols-20251021-143022.md
├── benchmark-protocols-20251021-150315.md
└── ...

C:\NFS\
├── benchmark-all-protocols-20251021-143022.log
├── benchmark-report-20251021-143022.md
└── ...
```

### Conteúdo do Relatório

1. **Cabeçalho**: Data, hora, configurações
2. **Tabela Comparativa**: Todos os protocolos lado a lado
3. **Análise de Performance**: Vencedores por categoria
4. **Comparação por Protocolo**: Vantagens e desvantagens
5. **Recomendações**: Baseadas nos resultados

---

## 🎬 Próximos Passos

### 1. Executar Benchmarks

```bash
# No WSL
sudo /root/agl-hostman/scripts/benchmark-all-protocols.sh
```

```powershell
# No Windows (PowerShell Admin)
C:\temp\benchmark-all-protocols-windows.ps1
```

### 2. Analisar Resultados

- Verificar qual protocolo teve melhor performance
- Comparar Windows vs WSL
- Identificar gargalos

### 3. Tomar Decisão

Com base nos resultados:

**Se SMB for competitivo (> 150 MB/s)**:
```powershell
# Migrar NFS para SMB
C:\temp\MIGRATE-NFS-TO-SMB-SAFE.ps1
```

**Se SSHFS for suficiente (> 75 MB/s no WSL)**:
```bash
# Usar SSHFS como padrão no WSL
/usr/local/bin/wsl-mount-nfs-shares.sh
```

**Se NFS for crítico (precisa > 250 MB/s)**:
- Aceitar limitações (status "Disconnected", sem WSL auto-mount)
- NUNCA reiniciar serviço NfsClnt
- Usar SSHFS no WSL como alternativa

### 4. Documentar Escolha

Atualizar documentação com:
- Resultados dos benchmarks
- Decisão final tomada
- Configuração escolhida

---

## 📋 Checklist de Execução

- [ ] Executar benchmark no WSL
- [ ] Executar benchmark no Windows
- [ ] Comparar resultados
- [ ] Identificar melhor protocolo
- [ ] Verificar trade-offs (performance vs estabilidade)
- [ ] Tomar decisão baseada em dados
- [ ] Implementar mudanças (se necessário)
- [ ] Documentar configuração final
- [ ] Testar estabilidade (24-48h)
- [ ] Validar performance em uso real

---

## 🔗 Documentação Relacionada

- **NFS_WINDOWS_WSL_DIAGNOSTIC_REPORT.md** - Diagnóstico completo do problema atual
- **NFS_WINDOWS_CRITICAL_CONSTRAINT.md** - Restrição crítica do NfsClnt
- **WINDOWS_NFS_SETUP_GUIDE.md** - Configuração original NFS
- **NFS_WSL2_INVESTIGATION_REPORT.md** - Problemas NFS + WSL2
- **AGLFS1_NFS_MOUNT_CONFIGURATION.md** - Configuração SSHFS

---

## 💡 Dicas Importantes

### Performance vs Estabilidade

**Nossa Recomendação**: **Estabilidade > Performance**

- Diferença de 20% na velocidade raramente é perceptível no uso diário
- Sistema travando = downtime completo, perda de trabalho
- SMB oferece ~90% da performance do NFS com 100% estabilidade

### Independência do WSL

**Benefício do SSHFS**:
- WSL funciona independente de configuração Windows
- Útil se Windows mudar configurações ou drives
- Backup/fallback automático via script

### Migração Gradual

**Não precisa migrar tudo de uma vez**:
1. Testar SMB em um drive (ex: Y:)
2. Validar performance e estabilidade
3. Migrar outros drives gradualmente
4. Manter NFS como fallback (se necessário)

---

**Última Atualização**: 2025-10-21
**Versão**: 1.0
**Status**: ✅ Pronto para uso
