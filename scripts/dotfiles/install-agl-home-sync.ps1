# Instala symlinks dotfiles AGL no Windows (aglwk45).
# Uso (PowerShell admin ou Administrator):
#   powershell -ExecutionPolicy Bypass -File scripts\dotfiles\install-agl-home-sync.ps1
param(
    [string]$HomeSyncRoot = "Z:\apps\dev\agl\agl-home-sync",
    [string]$HomeUser = "win-administrator",
    [string]$RepoRoot = "Z:\apps\dev\agl\agl-hostman",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$LiveRoot = Join-Path $HomeSyncRoot $HomeUser

function Ensure-Dir([string]$Path) {
    if (-not (Test-Path $Path)) {
        if ($DryRun) { Write-Host "[dry-run] mkdir $Path"; return }
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Link-Live([string]$Local, [string]$RemoteRel) {
    $Target = Join-Path $LiveRoot $RemoteRel
    Ensure-Dir (Split-Path $Target -Parent)
    Ensure-Dir $Target
    if (Test-Path $Local) {
        if (-not (Get-Item $Local -ErrorAction SilentlyContinue).LinkType) {
            $bak = "$Local.bak.$(Get-Date -Format 'yyyyMMddHHmmss')"
            if ($DryRun) { Write-Host "[dry-run] move $Local -> $bak" }
            else { Move-Item $Local $bak -Force }
        }
    }
    if ($DryRun) {
        Write-Host "[dry-run] cmd /c mklink /D `"$Local`" `"$Target`""
        return
    }
    if (Test-Path $Local) { Remove-Item $Local -Force -Recurse -ErrorAction SilentlyContinue }
    cmd /c mklink /D "$Local" "$Target" | Out-Null
    Write-Host "[OK] $Local -> $Target"
}

Write-Host "=== install-agl-home-sync Windows user=$HomeUser ==="
Ensure-Dir $LiveRoot

$AppDataCursor = "$env:APPDATA\Cursor\User"
Ensure-Dir $AppDataCursor
Link-Live "$AppDataCursor\globalStorage" "cursor\globalStorage"
Link-Live "$env:USERPROFILE\.cursor\chats" "cursor\dot-cursor\chats"
Link-Live "$env:USERPROFILE\.cursor\projects" "cursor\dot-cursor\projects"

# Git-managed: settings via repo (junction)
$SettingsSrc = Join-Path $RepoRoot "config\dotfiles\linux\cursor\User\settings.json"
$SettingsDst = Join-Path $AppDataCursor "settings.json"
if (Test-Path $SettingsSrc) {
    if ($DryRun) { Write-Host "[dry-run] link settings $SettingsDst" }
    elseif (-not (Test-Path $SettingsDst)) {
        cmd /c mklink "$SettingsDst" "$SettingsSrc" | Out-Null
        Write-Host "[OK] settings.json -> repo"
    }
}

Write-Host "OK — correr verify manualmente; fechar Cursor antes de sync globalStorage"
