#!/usr/bin/env pwsh
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Configura montagens NFS no Windows para aglfs1
.DESCRIPTION
    Cria e monta dois shares NFS do servidor aglfs1:
    - /mnt/overpower -> C:\NFS\overpower
    - /mnt/power -> C:\NFS\spark
.NOTES
    Requer: Windows com NFS Client instalado e execução como Administrador
#>

$ErrorActionPreference = "Stop"

# Configurações
$NFS_SERVER = "192.168.0.178"  # aglfs1
$NFS_SERVER_NAME = "aglfs1"

# Mapeamento de shares NFS para pontos de montagem locais
$NFS_MOUNTS = @(
    @{
        Share = "/mnt/overpower"
        LocalPath = "C:\NFS\overpower"
        DriveName = "NFSOverpower"
    },
    @{
        Share = "/mnt/power"
        LocalPath = "C:\NFS\spark"
        DriveName = "NFSSpark"
    }
)

function Write-Step {
    param(
        [int]$Step,
        [int]$Total,
        [string]$Message
    )
    Write-Host "`n[$Step/$Total] $Message..." -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "   OK $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "   X $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "   - $Message" -ForegroundColor Yellow
}

# Banner
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "CONFIGURACAO DE MOUNTS NFS - AGLFS1" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# [1/6] Verificar se NFS Client está instalado
Write-Step -Step 1 -Total 6 -Message "Verificando NFS Client"
$nfsFeature = Get-WindowsOptionalFeature -Online -FeatureName "ServicesForNFS-ClientOnly" -ErrorAction SilentlyContinue
if ($nfsFeature -and $nfsFeature.State -eq "Enabled") {
    Write-Success "NFS Client instalado e ativo"
} else {
    Write-Error "NFS Client nao instalado!"
    Write-Info "Execute: Enable-WindowsOptionalFeature -Online -FeatureName ServicesForNFS-ClientOnly"
    exit 1
}

# [2/6] Verificar conectividade
Write-Step -Step 2 -Total 6 -Message "Verificando conectividade com $NFS_SERVER_NAME"
if (Test-Connection -ComputerName $NFS_SERVER -Count 2 -Quiet) {
    Write-Success "Servidor $NFS_SERVER_NAME acessivel ($NFS_SERVER)"
} else {
    Write-Error "Servidor $NFS_SERVER_NAME nao acessivel"
    exit 1
}

# [3/6] Verificar exports NFS
Write-Step -Step 3 -Total 6 -Message "Verificando exports NFS disponiveis"
try {
    $exports = & showmount.exe -e $NFS_SERVER 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Exports disponiveis:"
        $exports | ForEach-Object { Write-Host $_ }
    } else {
        Write-Error "Nao foi possivel listar exports NFS"
        exit 1
    }
} catch {
    Write-Error "Erro ao executar showmount: $_"
    exit 1
}

# [4/6] Criar pontos de montagem
Write-Step -Step 4 -Total 6 -Message "Criando pontos de montagem"
foreach ($mount in $NFS_MOUNTS) {
    if (-not (Test-Path $mount.LocalPath)) {
        New-Item -ItemType Directory -Path $mount.LocalPath -Force | Out-Null
        Write-Success "Criado: $($mount.LocalPath)"
    } else {
        Write-Info "Ja existe: $($mount.LocalPath)"
    }
}

# [5/6] Desmontar shares existentes
Write-Step -Step 5 -Total 6 -Message "Removendo montagens anteriores (se existirem)"
foreach ($mount in $NFS_MOUNTS) {
    # Verificar se PSDrive existe
    $existingDrive = Get-PSDrive -Name $mount.DriveName -ErrorAction SilentlyContinue
    if ($existingDrive) {
        Write-Info "Removendo PSDrive: $($mount.DriveName)"
        Remove-PSDrive -Name $mount.DriveName -Force -ErrorAction SilentlyContinue
    }

    # Tentar desmontar usando umount (pode não existir)
    Write-Info "Desmontando: $($mount.LocalPath)"
    & umount.exe -f $mount.LocalPath 2>&1 | Out-Null
}

# [6/6] Montar NFS shares usando New-PSDrive
Write-Step -Step 6 -Total 6 -Message "Montando NFS shares"
$mountSuccess = 0
$mountFailed = 0

foreach ($mount in $NFS_MOUNTS) {
    $nfsPath = "\\$NFS_SERVER$($mount.Share -replace '/', '\')"

    Write-Info "Montando $($mount.Share) em $($mount.LocalPath)..."

    try {
        # Usar New-PSDrive com FileSystem provider
        $psDrive = New-PSDrive -Name $mount.DriveName `
                               -PSProvider FileSystem `
                               -Root $nfsPath `
                               -Persist `
                               -Scope Global `
                               -ErrorAction Stop

        Write-Success "Montado: $($mount.Share) -> $($mount.LocalPath)"
        Write-Info "  PSDrive: $($mount.DriveName):"
        $mountSuccess++

    } catch {
        Write-Error "Falha ao montar $($mount.Share): $($_.Exception.Message)"
        $mountFailed++

        # Tentar método alternativo usando mount.exe
        Write-Info "Tentando metodo alternativo com mount.exe..."
        try {
            $mountCmd = "mount -o anon $NFS_SERVER`:$($mount.Share) $($mount.LocalPath)"
            Invoke-Expression $mountCmd
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Montado via mount.exe: $($mount.Share) -> $($mount.LocalPath)"
                $mountSuccess++
                $mountFailed--
            } else {
                Write-Error "mount.exe tambem falhou"
            }
        } catch {
            Write-Error "Erro ao executar mount.exe: $_"
        }
    }
}

# Status final
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "STATUS DOS MOUNTS NFS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`nPSDrives NFS:" -ForegroundColor Yellow
Get-PSDrive | Where-Object { $_.Name -like "NFS*" } | Format-Table -AutoSize

Write-Host "`nMounts ativos (via mount):" -ForegroundColor Yellow
& mount.exe 2>&1

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "RESUMO" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Montagens bem-sucedidas: $mountSuccess" -ForegroundColor Green
Write-Host "Montagens falhadas: $mountFailed" -ForegroundColor $(if ($mountFailed -gt 0) { "Red" } else { "Green" })

if ($mountSuccess -eq $NFS_MOUNTS.Count) {
    Write-Host "`nTodas as montagens foram criadas com sucesso!" -ForegroundColor Green
    exit 0
} elseif ($mountSuccess -gt 0) {
    Write-Host "`nAlgumas montagens falharam. Verifique os erros acima." -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "`nNenhuma montagem foi criada. Verifique a configuracao do NFS." -ForegroundColor Red
    exit 1
}
