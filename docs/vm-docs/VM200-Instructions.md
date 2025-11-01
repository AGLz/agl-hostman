# VM200 - Instruções de Correção

## Status Atual
- **Host**: 100.98.108.66
- **VM**: 200 (WinServer2016-VirtIO)
- **Status**: Running
- **Migração**: ✓ Concluída de IDE para SCSI (scsi0: 500GB)
- **Problema**: MSSQL Server não inicia automaticamente após reboot

## Configuração Atual da VM
```
Boot: scsi0 (VirtIO SCSI)
SCSI Controller: virtio-scsi-single
Memória: 16GB
CPUs: 16 cores
Network: VirtIO (BC:24:11:DB:71:E8)
ISO VirtIO: montado em ide3
```

## Scripts Criados

Dois scripts PowerShell foram criados em `/root/`:

### 1. vm200-fix.ps1 (Diagnóstico)
Executa diagnóstico completo:
- ✓ Verifica driver VirtIO SCSI
- ✓ Verifica configuração de discos
- ✓ Lista serviços SQL Server
- ✓ Analisa logs de erro do SQL
- ✓ Verifica dependências de serviços
- ✓ Mostra informações do sistema

### 2. vm200-apply-fixes.ps1 (Correções)
Aplica todas as correções automaticamente:
- ✓ Instala drivers VirtIO (SCSI, Balloon, Network)
- ✓ Instala QEMU Guest Agent
- ✓ Corrige startup do MSSQL Server
- ✓ Otimiza Windows para VM

## Passo a Passo para Execução

### Opção 1: Copiar scripts via SSH e executar na VM

```bash
# 1. Copiar scripts para um compartilhamento acessível pela VM
# ou usar o console do Proxmox para copiar/colar o conteúdo

# 2. Acessar console da VM pelo Proxmox
ssh root@100.98.108.66
# No Proxmox web UI: VM 200 > Console
```

### Opção 2: Executar diretamente (recomendado)

**No console da VM (via Proxmox Web UI ou NoVNC):**

1. **Abrir PowerShell como Administrador**

2. **Executar diagnóstico:**
```powershell
# Copie e cole o conteúdo de vm200-fix.ps1 no PowerShell
# Isso mostrará o status atual e problemas detectados
```

3. **Aplicar correções:**
```powershell
# Copie e cole o conteúdo de vm200-apply-fixes.ps1 no PowerShell
# Isso instalará drivers, corrigirá SQL Server e otimizará Windows
```

4. **Reiniciar VM:**
```powershell
Restart-Computer -Force
```

## Correções que Serão Aplicadas

### 1. Drivers VirtIO
- **vioscsi**: Driver SCSI para o disco principal
- **Balloon**: Gerenciamento dinâmico de memória
- **NetKVM**: Driver de rede VirtIO
- Instalação automática baseada na versão do Windows

### 2. MSSQL Server
- Configuração: **Automatic (Delayed Start)**
  - Evita problemas de dependência no boot
  - Aguarda serviços de rede estarem prontos
- Dependências verificadas: LanmanServer, RPCSS, Netman
- Logs de erro serão analisados se falhar

### 3. QEMU Guest Agent
- Permite comunicação Proxmox ↔ VM
- Habilita shutdown graceful
- Permite comandos guest exec
- Melhora integração com Proxmox

### 4. Otimizações Windows
- Efeitos visuais: Desempenho otimizado
- Windows Search: Manual (indexação reduzida)
- Superfetch/SysMain: Desabilitado (desnecessário em VM)
- Power Plan: High Performance
- Hibernação: Desabilitada (economiza espaço)
- Pagefile: System managed
- VirtIO Balloon: Habilitado para memória dinâmica

## Após a Aplicação dos Fixes

### Verificação Pós-Restart

```powershell
# Verificar SQL Server
Get-Service | Where-Object {$_.Name -like "*SQL*"} | Select-Object Name, Status, StartType

# Verificar QEMU Guest Agent
Get-Service "QEMU-GA"

# Verificar drivers VirtIO
Get-WmiObject Win32_SCSIController
```

### No Proxmox (após QEMU Guest Agent)

```bash
# Habilitar QEMU Guest Agent na VM
ssh root@100.98.108.66 "qm set 200 --agent enabled=1"

# Testar comunicação
ssh root@100.98.108.66 "qm agent 200 ping"

# Verificar SQL Server remotamente
ssh root@100.98.108.66 "qm guest exec 200 -- powershell -Command 'Get-Service MSSQLSERVER'"
```

### Limpeza Final (opcional)

Após confirmar que tudo funciona:

```bash
# Remover ISOs montados
ssh root@100.98.108.66 "qm set 200 --delete ide0,ide3"

# Limpar discos não utilizados
ssh root@100.98.108.66 "qm set 200 --delete unused0,unused1,unused2"
```

## Troubleshooting

### Se MSSQL Server continuar não iniciando

1. **Verificar logs detalhados:**
```powershell
Get-EventLog -LogName Application -Source "*SQL*" -Newest 20 | Format-List
```

2. **Verificar permissões de arquivo:**
```powershell
# SQL Server precisa de acesso aos arquivos de dados
icacls "C:\Program Files\Microsoft SQL Server\"
```

3. **Verificar serviços de rede:**
```powershell
Get-Service LanmanServer, RPCSS, Netman | Select-Object Name, Status, StartType
```

4. **Tentar start manual com diagnóstico:**
```powershell
net start MSSQLSERVER
# Verificar mensagem de erro específica
```

### Se drivers VirtIO não instalarem

1. **Verificar montagem do ISO:**
```powershell
Get-Volume | Where-Object {$_.FileSystemLabel -like "*virtio*"}
```

2. **Instalação manual:**
```powershell
# Navegar até a pasta do driver
cd E:\vioscsi\2k16\amd64
pnputil /add-driver *.inf /install
```

## Melhorias de Performance Esperadas

✓ **Boot mais rápido**: Drivers VirtIO nativos
✓ **I/O de disco**: 3-5x mais rápido com VirtIO SCSI
✓ **Rede**: Throughput melhorado com VirtIO Network
✓ **Memória**: Balanceamento dinâmico com Balloon
✓ **Responsividade**: Otimizações de visual effects
✓ **SQL Server**: Startup automático confiável

## Comandos Úteis de Gerenciamento

```bash
# Status da VM
ssh root@100.98.108.66 "qm status 200"

# Reiniciar VM
ssh root@100.98.108.66 "qm reboot 200"

# Desligar gracefully (com guest agent)
ssh root@100.98.108.66 "qm shutdown 200"

# Console noVNC
# Acessar via Proxmox Web UI: https://100.98.108.66:8006

# Backup da VM
ssh root@100.98.108.66 "vzdump 200 --mode snapshot --compress zstd"
```

## Contatos de Suporte

Se precisar de ajuda adicional, inclua as seguintes informações:
- Output do script de diagnóstico (vm200-fix.ps1)
- Logs do Event Viewer (Application e System)
- Configuração da VM: `qm config 200`
