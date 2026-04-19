# Windows 11 no Proxmox: Guia Completo de Otimização

> **Data**: 2026-03-15
> **Fonte**: Compilação de documentação oficial Proxmox, fóruns, benchmarks e best practices da comunidade

---

## Sumário

1. [CPU Configuration](#1-cpu-configuration)
2. [Machine Type](#2-machine-type)
3. [VirtIO Drivers](#3-virtio-drivers)
4. [Performance Tuning](#4-performance-tuning)
5. [Windows-specific Optimizations](#5-windows-specific-optimizations)
6. [Configuração Completa de Exemplo](#6-configuração-completa-de-exemplo)
7. [Troubleshooting Comum](#7-troubleshooting-comum)

---

## 1. CPU Configuration

### 1.1 Melhor CPU Type para Windows 11

| CPU Type | Recomendação | Caso de Uso |
|----------|--------------|-------------|
| `host` | **Recomendado para WSL/Hyper-V** | Passa todas as flags do host, necessário para nested virtualization |
| `x86-64-v2-AES` | **Melhor performance geral** | Melhor compatibilidade, evita mitigações de segurança desnecessárias |
| `kvm64` | **Compatibilidade máxima** | Migração entre hosts diferentes, CPUs antigos |
| `Haswell`/`Skylake` | Alternativas específicas | Se precisar de instruções específicas sem usar `host` |

#### IMPORTANTE: Problema conhecido com `host`

A partir de 2025, foi identificado que `cpu=host` pode causar **performance degradation** significativa em Windows 11 devido às flags `md_clear` e `flush_l1d` que ativam mitigações de vulnerabilidades no Windows.

**Solução recomendada:**
```bash
# Opção 1: Usar x86-64-v2-AES (melhor performance geral)
qm set <vmid> --cpu x86-64-v2-AES

# Opção 2: Usar host mas remover flags problemáticas
qm set <vmid> --cpu host --cpuflags -md_clear,-flush_l1d
```

### 1.2 Configuração Ideal de Sockets vs Cores

```bash
# RECOMENDADO: 1 socket, múltiplos cores
# Windows não lida bem com múltiplos sockets virtuais
qm set <vmid> --sockets 1 --cores 8

# Evitar (performance inferior):
# qm set <vmid> --sockets 2 --cores 4  # NÃO RECOMENDADO
```

**Regras:**
- **Sempre 1 socket** para Windows 11
- **Cores = vCPUs** lógicos que o Windows verá
- **Threads**: Deixe em branco (default) ou 1 se hyperthreading não for necessário

### 1.3 CPU Flags Recomendadas para Windows

```bash
# Flags essenciais para Windows 11
qm set <vmid> --cpu host --cpuflags +pcid,+aes,+xsave,+avx,+avx2

# Para WSL2/Hyper-V nested virtualization
qm set <vmid> --cpu host --cpuflags +vmx,+ept,+vpid

# Se precisar remover flags problemáticas (mitigações que causam lentidão)
qm set <vmid> --cpu host --cpuflags -md_clear,-flush_l1d
```

### 1.4 NUMA Settings

```bash
# Para hosts multi-socket ou VMs com muitos cores
qm set <vmid> --numa 1

# Verificar topologia NUMA do host
numactl --hardware

# Para VMs com > 16 cores, considerar NUMA explícito
# Editar /etc/pve/qemu-server/<vmid>.conf e adicionar:
# numa: 1
# numa0: nodes=0,cpus=0-7,memory=4096
# numa1: nodes=1,cpus=8-15,memory=4096
```

---

## 2. Machine Type

### 2.1 pc-q35 vs i440fx

| Feature | i440fx (PC) | pc-q35 (Q35) |
|---------|-------------|--------------|
| Idade | 1996 (legado) | 2007+ (moderno) |
| PCIe Passthrough | Não | **Sim** |
| vIOMMU | Não | **Sim** |
| AHCI nativo | Não | **Sim** |
| TPM 2.0 | Limitado | **Suporte completo** |
| Windows 11 | Funciona | **Recomendado** |
| GPU Passthrough | Problemático | **Nativo** |
| Future-proof | Sendo deprecado | **Ativo** |

### 2.2 Versão Recomendada do QEMU Machine

```bash
# RECOMENDADO: Última versão Q35 disponível
qm set <vmid> --machine pc-q35-9.0

# Verificar versões disponíveis
qm showcmd <vmid> | grep -o 'machine [^,]*'

# Listar todas as versões suportadas
ls /usr/share/qemu/ | grep q35
```

**Recomendação por versão Proxmox:**
| Proxmox VE | Machine Type Recomendado |
|------------|--------------------------|
| 8.x | `pc-q35-8.1` |
| 9.0 | `pc-q35-9.0` |

### 2.3 Comandos para Mudar Machine Type

```bash
# IMPORTANTE: Fazer backup antes de mudar!
vzdump <vmid> --mode stop --storage local-zfs

# Mudar para Q35
qm set <vmid> --machine pc-q35-9.0

# Para Windows, pode ser necessário reparar o boot após mudança
# Preparar ISO de recuperação do Windows
```

---

## 3. VirtIO Drivers

### 3.1 Versão Mais Recente Estável

```bash
# Download da versão mais recente (verificar em 2026)
# https://fedorapeople.org/groups/virtio-win/virtio-win-direct-downloads/

wget https://fedorapeople.org/groups/virtio-win/virtio-win-direct-downloads/stable-virtio/virtio-win-0.1.285.iso

# Upload para Proxmox
qm importdisk <vmid> virtio-win-0.1.285.iso local-lvm
```

**Versões estáveis conhecidas (2026):**
- `virtio-win-0.1.285` - Mais recente (pode ter bugs com Server 2025)
- `virtio-win-0.1.262` - Estável recomendado
- `virtio-win-0.1.240` - Legacy para casos específicos

### 3.2 Driver Installation Order

Durante instalação do Windows 11, carregar drivers nesta ordem:

```bash
# 1. SCSI Controller (para ver o disco)
vioscsi\w11\amd64\

# 2. Network Adapter
NetKVM\w11\amd64\

# 3. Balloon (opcional - ver seção sobre não usar)
Balloon\w11\amd64\

# 4. VioFS (para shared folders)
viofs\w11\amd64\

# 5. VioSerial (para QEMU Guest Agent)
vioserial\w11\amd64\

# 6. Viostor (VirtIO Block - alternativa ao SCSI)
viostor\w11\amd64\
```

### 3.3 Instalação via CLI/Guest Agent

```bash
# Após Windows instalado, usar o installer MSI
# No Windows, executar:
# virtio-win-gt-x64.msi

# Ou via QEMU Guest Agent (se já instalado)
qm guest exec <vmid> -- msiexec /i D:\virtio-win-gt-x64.msi /quiet /norestart
```

### 3.4 Balloon, Network, SCSI, Memory - Configuração

```bash
# Disco: SCSI com VirtIO SCSI single
qm set <vmid> --scsihw virtio-scsi-single

# Disco com IO thread (performance)
qm set <vmid> --scsi0 local-lvm:vm-<vmid>-disk-0,iothread=1,cache=writeback,discard=on,ssd=1

# Network: VirtIO
qm set <vmid> --net0 virtio=XX:XX:XX:XX:XX:XX,bridge=vmbr0

# Balloon: DESATIVAR para melhor performance (ver warnings)
qm set <vmid> --balloon 0

# Memory: Hugepages para performance consistente
qm set <vmid> --hugepages 2
```

---

## 4. Performance Tuning

### 4.1 Memory Backing Options

```bash
# Opção 1: Hugepages (recomendado para gaming/workloads pesados)
qm set <vmid> --memory 8192 --hugepages 2

# Opção 2: Hugepages de 1GB (para VMs grandes)
qm set <vmid> --memory 16384 --hugepages 1

# Configurar hugepages no host
echo "vm.nr_hugepages=8192" >> /etc/sysctl.conf
sysctl -p

# Verificar hugepages disponíveis
grep -i huge /proc/meminfo
```

### 4.2 IO Threads

```bash
# Habilitar IO thread para cada disco
qm set <vmid> --scsi0 local-lvm:vm-<vmid>-disk-0,iothread=1

# Verificar se está ativo
qm config <vmid> | grep iothread

# Para discos adicionais
qm set <vmid> --scsi1 local-lvm:vm-<vmid>-disk-1,iothread=1
```

### 4.3 Cache Settings

| Cache Mode | Performance | Segurança | Caso de Uso |
|------------|-------------|-----------|-------------|
| `none` | Média | Alta | Default Proxmox, bom equilíbrio |
| `writeback` | **Alta** | Baixa | Máxima performance, risco de perda de dados |
| `writethrough` | Baixa | Alta | Máxima segurança |
| `directsync` | Baixa | Máxima | Sem cache algum |
| `unsafe` | Máxima | Nenhuma | Apenas testes! |

```bash
# RECOMENDADO para Windows 11 com SSD/NVMe host
qm set <vmid> --scsi0 local-lvm:vm-<vmid>-disk-0,cache=writeback,iothread=1,discard=on,ssd=1

# Para ZFS com SLOG ou HW RAID com BBU
qm set <vmid> --scsi0 local-zfs:vm-<vmid>-disk-0,cache=writeback,iothread=1

# Para segurança máxima (sem BBU)
qm set <vmid> --scsi0 local-lvm:vm-<vmid>-disk-0,cache=none,iothread=1

# IMPORTANTE: Habilitar discard para TRIM
qm set <vmid> --scsi0 local-lvm:vm-<vmid>-disk-0,discard=on
```

### 4.4 Network Queues

```bash
# Para alta performance de rede
qm set <vmid> --net0 virtio=XX:XX:XX:XX:XX:XX,bridge=vmbr0,queues=4

# Se usar multiqueue no host
qm set <vmid> --net0 virtio,bridge=vmbr0,queues=8

# Verificar suporte no guest
# No Windows: Get-NetAdapterAdvancedProperty -Name "Ethernet" | Where-Object {$_.RegistryKeyword -eq "*RssQueues"}
```

### 4.5 Affinity e CPU Pinning

```bash
# Para workloads críticos, fixar CPUs específicas
# Primeiro, verificar CPUs disponíveis
lscpu -p=CPU,CORE,SOCKET

# Aplicar affinity (exemplo: cores 4-11)
qm set <vmid> --affinity 4-11

# Ou via configuração manual
# /etc/pve/qemu-server/<vmid>.conf:
# affinity: 4,5,6,7,8,9,10,11
```

---

## 5. Windows-specific Optimizations

### 5.1 Registry Tweaks para VM

```powershell
# Executar como Administrator no Windows 11 guest

# 1. Desabilitar VBS (Virtualization-Based Security) - MELHORA MUITO A PERFORMANCE
reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v "EnableVirtualizationBasedSecurity" /t REG_DWORD /d 0 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v "Enabled" /t REG_DWORD /d 0 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\SystemGuard" /v "Enabled" /t REG_DWORD /d 0 /f

# 2. Desabilitar Core Isolation (Memory Integrity)
reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\SystemGuard" /v "Enabled" /t REG_DWORD /d 0 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v "RequireMicrosoftSignedBootChain" /t REG_DWORD /d 0 /f

# 3. Desabilitar Credential Guard
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v "LsaCfgFlags" /t REG_DWORD /d 0 /f

# 4. Desabilitar hibernation (economiza espaço em VM)
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "HibernateEnabled" /t REG_DWORD /d 0 /f

# 5. Desabilitar Windows Search indexing (reduz I/O)
sc config "WSearch" start= disabled
sc stop "WSearch"

# 6. Desabilitar SysMain (Superfetch) - não ajuda em VMs
sc config "SysMain" start= disabled
sc stop "SysMain"

# 7. Otimizar visual effects para performance
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v "VisualFXSetting" /t REG_DWORD /d 2 /f

# 8. Desabilitar scheduled tasks desnecessárias
schtasks /Change /TN "Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser" /Disable
schtasks /Change /TN "Microsoft\Windows\Application Experience\ProgramDataUpdater" /Disable
schtasks /Change /TN "Microsoft\Windows\Application Experience\StartupAppTask" /Disable
schtasks /Change /TN "Microsoft\Windows\Customer Experience Improvement Program\Consolidator" /Disable
schtasks /Change /TN "Microsoft\Windows\Customer Experience Improvement Program\UsbCeip" /Disable

# Reiniciar após aplicar
shutdown /r /t 60
```

### 5.2 Power Plan Settings

```powershell
# Definir High Performance power plan
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c

# Ou criar plano customizado baseado em High Performance
powercfg /duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
# Anotar o GUID retornado e ativar:
# powercfg /setactive <GUID>

# Desabilitar USB selective suspend
powercfg /SETACVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
powercfg /SETDCVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0

# Desabilitar processor idle states (para máxima performance)
powercfg /SETACVALUEINDEX SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 893dee8e-2bef-41e0-89c6-b55d0929964c 0
powercfg /SETDCVALUEINDEX SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 893dee8e-2bef-41e0-89c6-b55d0929964c 0

# Desabilitar system sleep/hibernate
powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0

# Aplicar mudanças
powercfg /SetActive SCHEME_CURRENT
```

### 5.3 QEMU Guest Agent Optimization

```bash
# No Proxmox host - habilitar agent
qm set <vmid> --agent 1

# No Windows guest - instalar via MSI
# Localização: virtio-win ISO -> guest-agent\qemu-ga-x86_64.msi

# Verificar se está funcionando
qm agent <vmid> ping

# Comandos úteis via QEMU Guest Agent
qm agent <vmid> get-host-name
qm agent <vmid> get-osinfo
qm agent <vmid> network-get-interfaces
qm agent <vmid> get-fsinfo
qm agent <vmid> info
```

### 5.4 Windows Services para Desabilitar

```powershell
# Lista de serviços seguros para desabilitar em VMs
$services = @(
    "DiagTrack",                          # Connected User Experiences
    "dmwappushservice",                   # WAP Push Message Routing
    "WMPNetworkSvc",                      # Windows Media Player Network Sharing
    "RemoteRegistry",                     # Remote Registry
    "TrkWks",                             # Distributed Link Tracking Client
    "WSearch",                            # Windows Search (se não precisar)
    "SysMain",                            # Superfetch
    "XblAuthManager",                     # Xbox Live Auth Manager
    "XblGameSave",                        # Xbox Live Game Save
    "XboxNetApiSvc",                      # Xbox Live Networking Service
    "SEMgrSvc",                           # Payments and NFC/SE Manager
    "WalletService",                      # WalletService
    "Fax",                                # Fax
    "lfsvc",                              # Geolocation Service
    "MapsBroker",                         # Downloaded Maps Manager
    "ALG",                                # Application Layer Gateway Service
    "bthserv",                            # Bluetooth Support Service
    "BluetoothUserService",               # Bluetooth User Support Service
    "BthAvctpSvc"                         # AVCTP service
)

foreach ($service in $services) {
    try {
        Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
        Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Host "Disabled: $service" -ForegroundColor Green
    } catch {
        Write-Host "Could not disable: $service" -ForegroundColor Yellow
    }
}
```

---

## 6. Configuração Completa de Exemplo

### 6.1 Configuração Ótima para Workstation Windows 11

```bash
# Criar VM completa com todas as otimizações
VMID=104

# Criar VM base
qm create $VMID \
  --name "win11-workstation" \
  --memory 16384 \
  --balloon 0 \
  --cores 8 \
  --cpu x86-64-v2-AES \
  --cpuunits 1024 \
  --sockets 1 \
  --machine pc-q35-9.0 \
  --ostype win11 \
  --bios ovmf \
  --efidisk0 local-zfs:vm-$VMID-efi,efitype=4m,pre-enrolled-keys=1,size=4M \
  --tpmstate0 local-zfs:vm-$VMID-tpm,version=v2.0,size=4M \
  --scsihw virtio-scsi-single \
  --agent 1 \
  --hugepages 2 \
  --numa 0

# Adicionar disco principal
qm set $VMID --scsi0 local-zfs:vm-$VMID-disk-0,iothread=1,cache=writeback,discard=on,ssd=1,size=256G

# Adicionar disco secundário (opcional)
qm set $VMID --scsi1 local-zfs:vm-$VMID-disk-1,iothread=1,cache=writeback,discard=on,ssd=1,size=512G

# Rede com multiqueue
qm set $VMID --net0 virtio,bridge=vmbr0,queues=4,firewall=0

# CD-ROM para ISOs
qm set $VMID --ide2 local:iso/virtio-win-0.1.262.iso,media=cdrom
qm set $VMID --ide0 local:iso/Win11_24H2_Pro.iso,media=cdrom

# USB para mouse/keyboard
qm set $VMID --usb0 host=0d6f:0202,usb3=1

# Tablet device (desabilitar se não precisar - economiza CPU)
# qm set $VMID --tablet 0

# VGA para console
qm set $VMID --vga std

# Verificar configuração final
qm config $VMID
```

### 6.2 Configuração para Gaming/High-Performance

```bash
VMID=105

# Configuração para máxima performance
qm create $VMID \
  --name "win11-gaming" \
  --memory 32768 \
  --balloon 0 \
  --cores 12 \
  --cpu host \
  --cpuflags -md_clear,-flush_l1d \
  --cpuunits 2048 \
  --sockets 1 \
  --machine pc-q35-9.0 \
  --ostype win11 \
  --bios ovmf \
  --efidisk0 local-zfs:vm-$VMID-efi,efitype=4m,size=4M \
  --tpmstate0 local-zfs:vm-$VMID-tpm,version=v2.0,size=4M \
  --scsihw virtio-scsi-single \
  --agent 1 \
  --hugepages 1 \
  --numa 1 \
  --affinity 4-15

# Disco com máxima performance
qm set $VMID --scsi0 local-zfs:vm-$VMID-disk-0,iothread=1,cache=writeback,discard=on,ssd=1,size=512G

# Rede com mais queues
qm set $VMID --net0 virtio,bridge=vmbr0,queues=8,firewall=0

# Se tiver GPU para passthrough
# qm set $VMID --hostpci0 0000:01:00,pcie=1,x-igd-gms=1,x-igd-opregion=on
```

### 6.3 Arquivo de Configuração Final (/etc/pve/qemu-server/<vmid>.conf)

```ini
# Windows 11 Otimizado - Configuração Exemplo
agent: 1
balloon: 0
bios: ovmf
boot: order=ide0;scsi0;ide2
cores: 8
cpu: x86-64-v2-AES
cpuunits: 1024
efidisk0: local-zfs:vm-104-efi,efitype=4m,pre-enrolled-keys=1,size=4M
hugepages: 2
ide0: local:iso/Win11_24H2_Pro.iso,media=cdrom,size=5388412K
ide2: local:iso/virtio-win-0.1.262.iso,media=cdrom,size=616528K
machine: pc-q35-9.0
memory: 16384
meta: creation-qemu=9.0.2,ctime=1737000000
name: win11-workstation
net0: virtio=BC:24:11:60:87:90,bridge=vmbr0,queues=4
numa: 0
ostype: win11
scsi0: local-zfs:vm-104-disk-0,cache=writeback,discard=on,iothread=1,size=256G,ssd=1
scsihw: virtio-scsi-single
sockets: 1
tpmstate0: local-zfs:vm-104-tpm,size=4M,version=v2.0
usb0: host=0d6f:0202,usb3=1
vga: std
vmgenid: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

---

## 7. Troubleshooting Comum

### 7.1 CPU 100% com `host`

```bash
# Problema: CPU fica em 100% quando usando cpu=host
# Causa: Flags md_clear e flush_l1d ativam mitigações no Windows

# Solução 1: Usar x86-64-v2-AES
qm set <vmid> --cpu x86-64-v2-AES

# Solução 2: Remover flags específicas
qm set <vmid> --cpu host --cpuflags -md_clear,-flush_l1d

# Solução 3: No Windows, desabilitar VBS via registry (ver seção 5.1)
```

### 7.2 Disco Lento

```bash
# Verificar cache mode atual
qm config <vmid> | grep cache

# Aplicar configuração otimizada
qm set <vmid> --scsi0 local-zfs:vm-<vmid>-disk-0,cache=writeback,iothread=1,discard=on,ssd=1

# Verificar se VirtIO driver está instalado no Windows
# Device Manager -> Storage controllers -> Deve mostrar "Red Hat VirtIO SCSI controller"

# Benchmark no Windows (CrystalDiskMark ou similar)
# Esperado com SSD host: >500MB/s sequencial
```

### 7.3 Rede Lenta

```bash
# Aumentar queues
qm set <vmid> --net0 virtio,bridge=vmbr0,queues=4

# Verificar driver no Windows
# Device Manager -> Network adapters -> "Red Hat VirtIO Ethernet Adapter"

# Verificar RSS no Windows
Get-NetAdapterRss

# Habilitar RSS se necessário
Enable-NetAdapterRss -Name "Ethernet"
```

### 7.4 Mouse Desalinhado

```bash
# Instalar QEMU Guest Agent
# No Windows: executar guest-agent\qemu-ga-x86_64.msi

# Verificar se agent está funcionando
qm agent <vmid> ping

# Se ainda com problemas, usar SPICE
qm set <vmid> --vga qxl
# E instalar SPICE Guest Tools no Windows
```

### 7.5 Windows Update Lentidão

```powershell
# Desabilitar Windows Update temporariamente para testes
sc config wuauserv start= disabled
sc stop wuauserv

# Ou pausar updates
# Settings -> Update & Security -> Windows Update -> Pause updates
```

### 7.6 Verificação Geral de Saúde

```bash
# Script de verificação rápida
#!/bin/bash
VMID=$1

echo "=== VM $VMID Health Check ==="

echo -e "\n--- CPU ---"
qm config $VMID | grep -E "^(cpu|cores|sockets|cpuflags)"

echo -e "\n--- Memory ---"
qm config $VMID | grep -E "^(memory|balloon|hugepages|numa)"

echo -e "\n--- Disk ---"
qm config $VMID | grep -E "^(scsi|virtio).*cache"

echo -e "\n--- Network ---"
qm config $VMID | grep -E "^net"

echo -e "\n--- Machine ---"
qm config $VMID | grep -E "^(machine|bios)"

echo -e "\n--- Guest Agent ---"
qm agent $VMID ping && echo "OK" || echo "NOT RESPONDING"

echo -e "\n--- Current Status ---"
qm status $VMID
```

---

## Referências

- [Proxmox Windows 11 Guest Best Practices](https://pve.proxmox.com/wiki/Windows_11_guest_best_practices)
- [Proxmox Performance Tweaks](https://pve.proxmox.com/wiki/Performance_Tweaks)
- [Proxmox Windows VirtIO Drivers](https://pve.proxmox.com/wiki/Windows_VirtIO_Drivers)
- [QEMU Q35 Machine Type](https://wiki.qemu.org/Features/Chipset/Q35)
- [Fedoraproject VirtIO Downloads](https://fedorapeople.org/groups/virtio-win/virtio-win-direct-downloads/)
- [Forum: CPU type host vs x86-64-v2-AES](https://forum.proxmox.com/threads/cpu-type-host-is-significantly-slower-than-x86-64-v2-aes.159107/)
- [Forum: Reasons for poor performance with host CPU](https://forum.proxmox.com/threads/the-reasons-for-poor-performance-of-windows-when-the-cpu-type-is-host.163114/)

---

## 8. Manutenção e Drivers VirtIO

### 8.1 Verificação de Drivers Atualizados

**VM104 (aglwk45) - Atualizado em 2026-03-15**

| Driver | Versão | Data |
| --- | --- | --- |
| Red Hat VirtIO Ethernet Adapter | 100.95.104.26200 | 15/07 2024 |
| Red Hat VirtIO SCSI pass-through controller | 100.95.104.26200 | 15/07 2024 |
| VirtIO Serial Driver | 100.95.104.26200 | 15/07 2024 |
| VirtIO RNG Device | 100.95.104.26200 | 06/07 2020 |
| VirtIO Sockets | 100.95.104.26200 | 06/07 2020 |
| VirtIO Sound | 100.95.104.26200 | 06/07 2020 |
| VirtIO Input | 100.95.104.26200 | 06/07 2020 |
| VirtIO FS | 0.1.173 | 06/07 2020 |
| VirtIO Memory Balloon | 0.1.173 | 06/07 2020 |
| VirtIO Network Adapter | 0.1.173 | 06/07 2020 |

### 8.2 Atualização de Drivers via ISO Montado

**Pré-requisitos:**
- ISO `virtio-win-0.1.229.iso` montada em `ide2`
- Acessível via drive `D:` no Windows

**Procedimento:**

```powershell
# 1. Verificar se a ISO está montada
Get-Volume | Where-Object { $_.DriveLetter -eq "D" }

# 2. Executar instalador silencioso
D:\virtio-win-gt-x64.msi /quiet /norestart

# 3. Verificar drivers atualizados
Get-WmiObject Win32_PnPSignedDriver | Where-Object { $_.DeviceName -like "*VirtIO*" -or $_.DeviceName -like "*Red Hat*" } | Select-Object DeviceName, DriverVersion, DriverDate | Format-Table
```

**Via QEMU Guest Agent (do host Proxmox):**

```bash
# Executar instalador via QEMU GA
qm guest exec 104 -- PowerShell -Command "Start-Process msiexec.exe -ArgumentList '/i', 'D:\virtio-win-gt-x64.msi', '/quiet', '/norestart' -Wait"

# Verificar status
qm guest exec 104 -- PowerShell -Command "Get-WmiObject Win32_PnPSignedDriver | Where-Object { \$_.DeviceName -like '*VirtIO*' -or \$_.DeviceName -like '*Red Hat*' } | Select-Object DeviceName, DriverVersion | Format-Table"
```

### 8.3 Monitoramento Recomendado

| Frequência | Verificação |
| --- | --- |
| Inicial (setup) | Drivers VirtIO, WMI, QEMU GA |
| Diária | Event Viewer (System log) |
| Semanal | Windows Update status, storage usage |
| Mensal | Driver updates, security patches |

### 8.4 Alertas Configurados

| Condição | Threshold | Ação |
| --- | --- | --- |
| Storage > 90% | 90% | Alertar para cleanup |
| CPU > 90% sustained | 5 min | Investigar processo |
| Memory pressure | Balloon ativo | Verificar se necessário |

### 8.5 Checklist Pós-Atualização

- [ ] Verificar Device Manager (sem erros)
- [ ] Testar conectividade de rede
- [ ] Validar QEMU Guest Agent (`qm agent 104 ping`)
- [ ] Executar benchmark de disco (opcional)
- [ ] Documentar versões finais no AGLWK45-SETUP.md
