# Instala symlinks dotfiles AGL no Windows (aglwk45).
# Uso:
#   powershell -ExecutionPolicy Bypass -File scripts\dotfiles\install-agl-home-sync.ps1
param(
    [string]$HomeSyncRoot = "Z:\apps\dev\agl\agl-home-sync",
    [string]$HomeUser = "linux-root",
    [string]$RepoRoot = "Z:\apps\dev\agl\agl-hostman",
    [switch]$DryRun,
    [switch]$SkipNetUse
)

$ErrorActionPreference = "Stop"
$HomeRoot = $env:USERPROFILE
$env:APPDATA = Join-Path $HomeRoot "AppData\Roaming"
$env:LOCALAPPDATA = Join-Path $HomeRoot "AppData\Local"
$UsedLocalLiveFallback = $false

function Test-RemotePath([string]$Path) {
    if ($Path -match '^\\\\') {
        $null = cmd /c "dir /b `"$Path`" 2>nul"
        return $LASTEXITCODE -eq 0
    }
    if ($Path -match '^[A-Za-z]:\\') {
        $drive = $Path.Substring(0, 2)
        $null = cmd /c "if exist ${drive}\ exit 0 else exit 1"
        if ($LASTEXITCODE -ne 0) { return $false }
    }
    return Test-Path $Path
}

function Clear-StaleNetUse {
    foreach ($letter in @("Z:", "U:")) {
        $status = cmd /c "net use $letter 2>&1" | Out-String
        if ($status -match 'Unavailable|disconnected|not found') {
            cmd /c "net use $letter /delete /y" 2>&1 | Out-Null
        }
    }
}

function Write-Step([string]$Msg) {
    Write-Host "[OK] $Msg"
}

function Enable-DeveloperSymlinks {
    if ($DryRun) { return }
    $key = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App ModelUnlock"
    if (-not (Test-Path $key)) {
        New-Item -Path $key -Force | Out-Null
    }
    Set-ItemProperty -Path $key -Name AllowDevelopmentWithoutDevLicense -Value 1 -Type DWord -Force
    Write-Step "Developer Mode symlinks activado"
}

function Invoke-Mklink([string]$ArgsLine) {
    $output = cmd /c "mklink $ArgsLine" 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        throw "mklink $ArgsLine falhou: $output"
    }
}

function Ensure-Dir([string]$Path) {
    if (-not (Test-Path $Path)) {
        if ($DryRun) { Write-Host "[dry-run] mkdir $Path"; return }
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Backup-IfExists([string]$Path) {
    if (-not (Test-Path $Path)) { return $true }
    $item = Get-Item $Path -Force -ErrorAction SilentlyContinue
    if ($item.LinkType) { return $true }
    $bak = "$Path.bak.$(Get-Date -Format 'yyyyMMddHHmmss')"
    if ($DryRun) { Write-Host "[dry-run] backup $Path -> $bak"; return $true }
    try {
        Move-Item $Path $bak -Force -ErrorAction Stop
        Write-Step "backup $Path"
        return $true
    } catch {
        Write-Host "[WARN] backup ignorado ($Path): $($_.Exception.Message)"
        return $false
    }
}

function Link-LiveDir([string]$Local, [string]$RemoteRel) {
    $Target = Join-Path $LiveRoot $RemoteRel
    Ensure-Dir (Split-Path $Target -Parent)
    Ensure-Dir $Target
    if (-not (Backup-IfExists $Local)) { return }
    if ($DryRun) {
        Write-Host "[dry-run] mklink /D `"$Local`" `"$Target`""
        return
    }
    if (Test-Path $Local) { Remove-Item $Local -Force -Recurse -ErrorAction SilentlyContinue }
    Invoke-Mklink "/D `"$Local`" `"$Target`""
    Write-Step "$Local -> $Target"
}

function Link-LiveFile([string]$Local, [string]$RemoteRel) {
    $Target = Join-Path $LiveRoot $RemoteRel
    Ensure-Dir (Split-Path $Target -Parent)
    if (-not (Test-Path $Target)) {
        if ($DryRun) { Write-Host "[dry-run] touch $Target" }
        else { New-Item -ItemType File -Path $Target -Force | Out-Null }
    }
    if (-not (Backup-IfExists $Local)) { return }
    if ($DryRun) {
        Write-Host "[dry-run] mklink `"$Local`" `"$Target`""
        return
    }
    if (Test-Path $Local) { Remove-Item $Local -Force -ErrorAction SilentlyContinue }
    Invoke-Mklink "`"$Local`" `"$Target`""
    Write-Step "$Local -> $Target"
}

function Link-GitFile([string]$Local, [string]$RelSource) {
    $Source = Join-Path $RepoRoot ($RelSource -replace '/', '\')
    if (-not (Test-Path $Source)) {
        Write-Host "[WARN] fonte Git em falta: $Source"
        return
    }
    Ensure-Dir (Split-Path $Local -Parent)
    if (-not (Backup-IfExists $Local)) { return }
    if ($DryRun) {
        Write-Host "[dry-run] mklink `"$Local`" `"$Source`""
        return
    }
    if (Test-Path $Local) { Remove-Item $Local -Force -ErrorAction SilentlyContinue }
    Invoke-Mklink "`"$Local`" `"$Source`""
    Write-Step "git $Local -> $Source"
}

Write-Host "=== install-agl-home-sync Windows user=$HomeUser ==="

Clear-StaleNetUse

if (-not $SkipNetUse) {
    $UncCandidates = @(
        "\\192.168.0.178\overpower",
        "\\100.69.187.105\overpower",
        "\\aglfs1\overpower"
    )
    $UncOverpower = $null
    foreach ($unc in $UncCandidates) {
        $null = cmd /c "dir /b `"$unc`" 2>nul"
        if ($LASTEXITCODE -eq 0) { $UncOverpower = $unc; break }
    }
    if ($UncOverpower) {
        foreach ($pair in @(
            @{ Letter = "Z:"; Share = $UncOverpower },
            @{ Letter = "U:"; Share = ($UncOverpower -replace '\\overpower$', '\storage') }
        )) {
            if (-not $pair.Share) { continue }
            if (-not (Test-Path ($pair.Letter + "\"))) {
                if ($DryRun) {
                    Write-Host "[dry-run] net use $($pair.Letter) $($pair.Share)"
                } else {
                    $null = cmd /c "net use $($pair.Letter) `"$($pair.Share)`" /user:guest `"`" /persistent:yes" 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        $null = cmd /c "net use $($pair.Letter) `"$($pair.Share)`" /persistent:yes" 2>&1
                    }
                    Write-Step "net use $($pair.Letter)"
                }
            }
        }
    }
}

if (-not (Test-RemotePath $HomeSyncRoot)) {
    $HomeSyncRoot = Join-Path $HomeRoot "agl-home-sync"
    $UsedLocalLiveFallback = $true
    Write-Host "[WARN] SMB/NFS live indisponivel - fallback local: $HomeSyncRoot"
    Write-Host "[WARN] Re-correr install com Z: ou UNC quando rede ao aglfs1 estiver OK"
}

$LiveRoot = Join-Path $HomeSyncRoot $HomeUser

# Resolver RepoRoot se Z: indisponível
$manifest = Join-Path $RepoRoot "config\dotfiles\manifest.yaml"
if (-not (Test-Path $manifest)) {
    foreach ($alt in @(
        "C:\Windows\Temp\agl-dotfiles\agl-hostman",
        "C:\Users\Administrator\apps\dev\agl\agl-hostman",
        "U:\apps\dev\agl\agl-hostman"
    )) {
        if (Test-Path (Join-Path $alt "config\dotfiles\manifest.yaml")) {
            $RepoRoot = $alt
            Write-Step "RepoRoot=$RepoRoot"
            break
        }
    }
}

Ensure-Dir $LiveRoot
if ($UsedLocalLiveFallback) {
    Set-Content -Path (Join-Path $HomeSyncRoot ".agl-local-fallback") -Value "guest-or-offline $(Get-Date -Format o)"
}
Ensure-Dir (Join-Path $LiveRoot "cursor\globalStorage")
Ensure-Dir (Join-Path $LiveRoot "cursor\dot-cursor\chats")
Ensure-Dir (Join-Path $LiveRoot "cursor\dot-cursor\projects")
Ensure-Dir (Join-Path $LiveRoot "claude\file-history")

$AppDataCursor = Join-Path $env:APPDATA "Cursor\User"
Ensure-Dir $AppDataCursor

Enable-DeveloperSymlinks

Link-LiveDir "$AppDataCursor\globalStorage" "cursor\globalStorage"
Link-LiveDir "$HomeRoot\.cursor\chats" "cursor\dot-cursor\chats"
Link-LiveDir "$HomeRoot\.cursor\projects" "cursor\dot-cursor\projects"
Link-LiveFile "$HomeRoot\.claude\history.jsonl" "claude\history.jsonl"
Link-LiveDir "$HomeRoot\.claude\file-history" "claude\file-history"

Link-GitFile "$AppDataCursor\settings.json" "config/dotfiles/linux/cursor/User/settings.json"
Link-GitFile "$AppDataCursor\keybindings.json" "config/dotfiles/linux/cursor/User/keybindings.json"
Link-GitFile "$HomeRoot\.claude\settings.json" "config/dotfiles/linux/claude/settings.json"

$McpExample = Join-Path $RepoRoot "config\dotfiles\linux\cursor\dot-cursor\mcp.json.example"
$McpLocal = "$HomeRoot\.cursor\mcp.json"
if (-not (Test-Path $McpLocal) -and (Test-Path $McpExample)) {
    if ($DryRun) { Write-Host "[dry-run] copy mcp.json.example" }
    else {
        Copy-Item $McpExample $McpLocal
        Write-Step "template mcp.json"
    }
}

Write-Host ""
Write-Host "OK install - fechar Cursor antes de sync globalStorage; correr verify-agl-home-sync.sh"
