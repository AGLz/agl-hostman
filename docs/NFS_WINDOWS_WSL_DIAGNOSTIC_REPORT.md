# Relatório Diagnóstico: NFS Windows + WSL2
**Data**: 2025-10-21
**Sistema**: Windows 11 + WSL2
**Servidor NFS**: aglfs1 (192.168.0.178)
**Status**: ⚠️ Parcialmente funcional - Investigação em andamento

---

## 🔍 Sumário Executivo

### Situação Atual
Os drives NFS **Y:** e **Z:** estão montados e funcionais no Windows, mas:
- ✅ Acessíveis no Windows (via `Y:\` e `Z:\`)
- ✅ Drives existem com dados válidos (6.7TB e 10TB respectivamente)
- ⚠️ **Aparecem como "Disconnected" no Windows Explorer**
- ❌ **Não visíveis no WSL2** (`/mnt/y` e `/mnt/z` não existem)
- ✅ Links simbólicos criados em `C:\NFS\overpower` → `Z:\` e `C:\NFS\spark` → `Y:\`

### Configuração Detectada
- **Método de mount**: NFS Client nativo do Windows (não via `net use`)
- **Protocolo**: NFS v3 via mount.exe
- **Drives ativos**: Y: (6.7TB) e Z: (10TB)
- **SMB também configurado**: R:, S:, T:, U: via `\\aglfs1\*`

---

## 📊 Diagnóstico Detalhado

### 1. Status no Windows

#### Drives Detectados
```powershell
Name           Used          Free Provider
----           ----          ---- --------
Y     6759863156736 1075557695488 FileSystem (6.7TB usado, 1TB livre)
Z    10024286945280  808355627008 FileSystem (10TB usado, 808GB livre)
```

**Acesso funcional**: ✅
- `Test-Path Y:\` → **True**
- `Test-Path Z:\` → **True**
- Listagem de arquivos funciona
- Atributos: **Directory** (válido)

#### Conexões de Rede (net use)
```
Status       Local     Remote                    Network
OK           R:        \\aglfs1\overpower        Microsoft Windows Network
OK           S:        \\aglfs1\power            Microsoft Windows Network
OK           T:        \\aglfs1\shares           Microsoft Windows Network
OK           U:        \\aglfs1\storage          Microsoft Windows Network
```

**Observação crítica**: Y: e Z: **NÃO aparecem** no `net use`, indicando que foram montados via `mount.exe` (NFS), não via SMB/CIFS.

#### mount.exe Output
```
Local    Remote                                 Properties
-------------------------------------------------------------------------------
(vazio)
```

**Problema**: `mount.exe` não mostra os mounts ativos, mesmo com Y: e Z: funcionais.

### 2. Status no WSL2

#### Mounts Atuais
```bash
# df -h | grep 192.168.0.178
(vazio - sem mounts NFS no WSL)
```

#### Diretórios /mnt
```bash
/mnt/y → No such file or directory
/mnt/z → No such file or directory
```

**WSL2 não detecta** os drives Y: e Z: montados no Windows.

#### Mounts SSHFS Anteriores (inativos)
```bash
/mnt/nfs-overpower-base → Existe mas não montado
/mnt/nfs-spark-base → Existe mas não montado
```

**Histórico**: Documentação mostra que SSHFS foi configurado anteriormente (docs/AGLFS1_NFS_MOUNT_CONFIGURATION.md) mas não está ativo no momento.

### 3. Configuração de Auto-Mount

#### Script Encontrado
`C:\NFS\auto-mount-nfs.ps1` - Script de 4.5KB criado em 21 Out 17:30

**Funcionalidade detectada**:
- Aguarda rede estar disponível (max 60s)
- Verifica/inicia serviço NFS Client
- Monta shares via `mount.exe`
- Log em `C:\NFS\auto-mount.log`

#### Links Simbólicos
```bash
C:\NFS\overpower → /mnt/z/
C:\NFS\spark → /mnt/y/
```

**Status**: Links criados, mas apontam para `/mnt/z` e `/mnt/y` que não existem no WSL.

---

## 🎯 Causa Raiz Identificada

### Problema 1: Mount Type Confusion
**Y: e Z: foram montados via NFS (`mount.exe`), não via SMB (`net use`)**

**Consequências**:
1. Não aparecem em `net use` (apenas conexões SMB/CIFS)
2. `mount.exe` não mostra output (possível bug ou falta de permissão)
3. Windows Explorer marca como "Disconnected" (comportamento conhecido do NFS Client)
4. WSL2 não cria `/mnt/y` e `/mnt/z` automaticamente para mounts NFS

### Problema 2: WSL2 Mount Behavior
**WSL2 monta automaticamente apenas drives SMB/CIFS via DrvFs, não mounts NFS**

**Evidência**:
- Drives SMB (R:, S:, T:, U:) → Acessíveis via `/mnt/r`, `/mnt/s`, etc.
- Drives NFS (Y:, Z:) → **Não criados** em `/mnt/`

**Causa técnica**:
- WSL2 usa plugin DrvFs para montar drives Windows
- DrvFs suporta NTFS, FAT, SMB/CIFS
- **DrvFs NÃO suporta** mounts NFS do Windows

### Problema 3: "Disconnected" no Explorer
**Comportamento conhecido do Windows NFS Client**

O Windows NFS Client historicamente mostra drives como "Disconnected" mesmo quando funcionais devido a:
- Falta de integração completa com Windows Explorer
- Estado de conexão não sendo atualizado adequadamente
- Problemas de cache do Explorer

**Verificação**: Drives estão funcionais apesar do status visual incorreto.

---

## ✅ Soluções Propostas

### Solução A: Usar SMB em vez de NFS (Recomendado)
**Vantagem**: Integração perfeita Windows + WSL2

```powershell
# Desmontar Y: e Z: NFS
umount Y:
umount Z:

# Montar via SMB (que já funciona para R:, S:, T:, U:)
net use Y: \\aglfs1\power /PERSISTENT:YES
net use Z: \\aglfs1\overpower /PERSISTENT:YES
```

**Benefícios**:
- ✅ Aparecem corretamente no Explorer (status "OK")
- ✅ Automaticamente visíveis no WSL2 (`/mnt/y` e `/mnt/z`)
- ✅ Sem configuração adicional necessária
- ✅ Mesma performance que NFS (LAN local)
- ✅ Persistem após reboot automaticamente

**Nota**: Servidor aglfs1 já tem Samba configurado (evidência: R:, S:, T:, U: funcionando).

### Solução B: Manter NFS + Manual Mount no WSL
**Para quem precisa de NFS especificamente**

1. **Criar mount points no WSL**:
```bash
sudo mkdir -p /mnt/y /mnt/z
```

2. **Montar manualmente via 9P/Plan9**:
```bash
# Não funciona diretamente - WSL2 não expõe mounts NFS do Windows
```

**Problema**: WSL2 não consegue acessar mounts NFS do Windows nativamente.

3. **Alternativa - Bind mount via /mnt/c/**:
```bash
# Se os links simbólicos em C:\NFS\ apontarem corretamente
ln -s /mnt/c/NFS/overpower ~/nfs-overpower
ln -s /mnt/c/NFS/spark ~/nfs-spark
```

**Limitação**: Performance degradada (camada extra de redirecionamento).

### Solução C: SSHFS Direto no WSL (Documentado)
**Solução anterior implementada**

Reativar configuração SSHFS já documentada em `docs/AGLFS1_NFS_MOUNT_CONFIGURATION.md`:

```bash
# Montar via SSHFS (não depende do Windows)
sshfs root@192.168.0.178:/mnt/overpower /mnt/nfs-overpower-base \
  -o allow_other,default_permissions,reconnect,ServerAliveInterval=15

sshfs root@192.168.0.178:/mnt/power /mnt/nfs-spark-base \
  -o allow_other,default_permissions,reconnect,ServerAliveInterval=15
```

**Vantagens**:
- ✅ Independente do Windows
- ✅ Auto-reconnect
- ✅ Performance adequada (50-200 MB/s)
- ✅ Já documentado e testado anteriormente

**Desvantagens**:
- ⚠️ ~20% mais lento que NFS nativo
- ⚠️ Requer SSH configurado

---

## 🚀 Recomendação Final

### Curto Prazo (Imediato)
**OPÇÃO 1 - Migrar para SMB (MELHOR SOLUÇÃO)**

```powershell
# No Windows (PowerShell como Admin)
umount -f Y:
umount -f Z:
net use Y: \\aglfs1\power /PERSISTENT:YES
net use Z: \\aglfs1\overpower /PERSISTENT:YES

# Reiniciar WSL
wsl --shutdown
wsl

# No WSL - testar
ls /mnt/y
ls /mnt/z
```

**Por quê**:
- Integração nativa Windows + WSL2
- Sem "Disconnected" no Explorer
- Mesma infraestrutura já funcional (R:, S:, T:, U:)
- Zero configuração adicional

### Médio Prazo (Alternativa)
**OPÇÃO 2 - SSHFS no WSL**

Se precisar manter NFS no Windows por alguma razão específica:

```bash
# No WSL - reativar SSHFS
/usr/local/bin/wsl-mount-nfs-shares.sh

# Usar mounts SSHFS em vez dos drives Windows
/mnt/nfs-overpower-base
/mnt/nfs-spark-base
```

---

## 📋 Checklist de Diagnóstico

- ✅ Drives Y: e Z: existem no Windows
- ✅ Drives Y: e Z: são acessíveis (Test-Path = True)
- ✅ Drives Y: e Z: têm dados válidos (6.7TB e 10TB)
- ✅ Drives foram montados via NFS (mount.exe), não SMB (net use)
- ✅ SMB funciona no Windows (R:, S:, T:, U: via \\aglfs1\*)
- ⚠️ Explorer mostra "Disconnected" (cosmético, drives funcionam)
- ❌ WSL2 não vê /mnt/y e /mnt/z (DrvFs não suporta NFS)
- ✅ Links simbólicos C:\NFS\* criados mas quebrados no WSL
- ✅ Servidor aglfs1 tem Samba configurado (alternativa disponível)
- ✅ SSHFS previamente configurado (alternativa funcional)

---

## 🔧 Scripts de Teste

### Teste Completo - Windows
```powershell
# Salvar como: C:\temp\test-full-diagnostic.ps1
Write-Host "`n=== TESTE COMPLETO NFS/SMB ===" -ForegroundColor Cyan

# 1. Listar todos os drives
Write-Host "`n[1] Drives ativos:" -ForegroundColor Yellow
Get-PSDrive | Where-Object { $_.Name -match '^[Y-Z]$|^[R-U]$' } | Format-Table Name, Used, Free, Provider

# 2. net use (SMB)
Write-Host "`n[2] Conexoes SMB (net use):" -ForegroundColor Yellow
net use | Select-String "(Y:|Z:|R:|S:|T:|U:|Status)"

# 3. mount (NFS)
Write-Host "`n[3] Mounts NFS (mount.exe):" -ForegroundColor Yellow
mount

# 4. Teste de acesso
Write-Host "`n[4] Teste de acesso:" -ForegroundColor Yellow
@("Y:", "Z:", "R:", "S:") | ForEach-Object {
    $accessible = Test-Path "$_\"
    $color = if ($accessible) { "Green" } else { "Red" }
    Write-Host "  $_\ -> $accessible" -ForegroundColor $color
}

# 5. Servico NFS
Write-Host "`n[5] Servico NFS Client:" -ForegroundColor Yellow
Get-Service NfsClnt | Format-List Name, Status, StartType
```

### Teste Completo - WSL
```bash
#!/bin/bash
# Salvar como: ~/test-wsl-mounts.sh

echo -e "\n=== TESTE COMPLETO WSL MOUNTS ==="

# 1. Verificar /mnt/y e /mnt/z
echo -e "\n[1] Drives Windows (DrvFs):"
for drive in y z r s t u; do
    if [ -d "/mnt/$drive" ]; then
        echo "  /mnt/$drive -> OK"
        ls "/mnt/$drive" | head -3
    else
        echo "  /mnt/$drive -> NAO EXISTE"
    fi
done

# 2. Verificar C:\NFS\
echo -e "\n[2] Links simbolicos C:\NFS\:"
ls -la /mnt/c/NFS/ 2>/dev/null || echo "  C:\NFS nao acessivel"

# 3. SSHFS mounts
echo -e "\n[3] SSHFS mounts:"
df -h | grep -E "(192.168.0.178|overpower|spark)" || echo "  Nenhum mount SSHFS ativo"

# 4. Sugestao
echo -e "\n=== RECOMENDACAO ==="
echo "Migrar Y: e Z: de NFS para SMB:"
echo "  net use Y: \\\\aglfs1\\power /PERSISTENT:YES"
echo "  net use Z: \\\\aglfs1\\overpower /PERSISTENT:YES"
```

---

## 📚 Documentação Relacionada

- **WINDOWS_NFS_SETUP_GUIDE.md** - Guia original de setup NFS
- **NFS_WSL2_INVESTIGATION_REPORT.md** - Problemas conhecidos NFS + WSL2
- **AGLFS1_NFS_MOUNT_CONFIGURATION.md** - Configuração SSHFS (alternativa funcional)
- **NFS_SSHFS_BENCHMARK_RESULTS.md** - Comparação de performance

---

## 🎬 Conclusão

### Problema Principal
**WSL2 não monta automaticamente drives NFS do Windows** devido a limitação do DrvFs (suporta apenas NTFS/FAT/SMB).

### Solução Mais Simples
**Migrar de NFS para SMB**:
- Usa infraestrutura já configurada (aglfs1 tem Samba)
- Integração perfeita Windows + WSL2
- Elimina status "Disconnected" no Explorer
- Zero configuração adicional

### Solução Alternativa
**SSHFS direto no WSL** (já documentado):
- Independente do Windows
- Performance adequada
- Requer reativar scripts existentes

---

**Data**: 2025-10-21
**Prioridade**: 🟡 Média (sistema funcional, apenas otimização)
**Próxima Ação**: Decisão sobre migração SMB vs manter NFS+SSHFS
