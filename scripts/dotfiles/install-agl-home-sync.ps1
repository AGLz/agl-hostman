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
$LiveRoot = Join-Path $HomeSyncRoot $HomeUser

function Write-Step([string]$Msg) {
    Write-Host "[OK] $Msg"
}

function Ensure-Dir([string]$Path) {
    if (-not (Test-Path $Path)) {
        if ($DryRun) { Write-Host "[dry-run] mkdir $Path"; return }
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Backup-IfExists([string]$Path) {
    if (-not (Test-Path $Path)) { return }
    $item = Get-Item $Path -Force -ErrorAction SilentlyContinue
    if ($item.LinkType) { return }
    $bak = "$Path.bak.$(Get-Date -Format 'yyyyMMddHHmmss')"
    if ($DryRun) { Write-Host "[dry-run] backup $Path -> $bak"; return }
    Move-Item $Path $bak -Force
    Write-Step "backup $Path"
}

function Link-LiveDir([string]$Local, [string]$RemoteRel) {
    $Target = Join-Path $LiveRoot $RemoteRel
    Ensure-Dir (Split-Path $Target -Parent)
    Ensure-Dir $Target
    Backup-IfExists $Local
    if ($DryRun) {
        Write-Host "[dry-run] mklink /D `"$Local`" `"$Target`""
        return
    }
    if (Test-Path $Local) { Remove-Item $Local -Force -Recurse -ErrorAction SilentlyContinue }
    cmd /c mklink /D "$Local" "$Target" | Out-Null
    Write-Step "$Local -> $Target"
}

function Link-LiveFile([string]$Local, [string]$RemoteRel) {
    $Target = Join-Path $LiveRoot $RemoteRel
    Ensure-Dir (Split-Path $Target -Parent)
    if (-not (Test-Path $Target)) {
        if ($DryRun) { Write-Host "[dry-run] touch $Target" }
        else { New-Item -ItemType File -Path $Target -Force | Out-Null }
    }
    Backup-IfExists $Local
    if ($DryRun) {
        Write-Host "[dry-run] mklink `"$Local`" `"$Target`""
        return
    }
    if (Test-Path $Local) { Remove-Item $Local -Force -ErrorAction SilentlyContinue }
    cmd /c mklink "$Local" "$Target" | Out-Null
    Write-Step "$Local -> $Target"
}

function Link-GitFile([string]$Local, [string]$RelSource) {
    $Source = Join-Path $RepoRoot ($RelSource -replace '/', '\')
    if (-not (Test-Path $Source)) {
        Write-Host "[WARN] fonte Git em falta: $Source"
        return
    }
    Ensure-Dir (Split-Path $Local -Parent)
    Backup-IfExists $Local
    if ($DryRun) {
        Write-Host "[dry-run] mklink `"$Local`" `"$Source`""
        return
    }
    if (Test-Path $Local) { Remove-Item $Local -Force -ErrorAction SilentlyContinue }
    cmd /c mklink "$Local" "$Source" | Out-Null
    Write-Step "git $Local -> $Source"
}

Write-Host "=== install-agl-home-sync Windows user=$HomeUser ==="

if (-not $SkipNetUse) {
    $UncOverpower = "\\aglfs1\overpower"
    foreach ($pair in @(
        @{ Letter = "Z:"; Share = $UncOverpower },
        @{ Letter = "U:"; Share = "\\aglfs1\storage" }
    )) {
        if (-not (Test-Path ($pair.Letter + "\"))) {
            if ($DryRun) {
                Write-Host "[dry-run] net use $($pair.Letter) $($pair.Share)"
            } else {
                $null = cmd /c "net use $($pair.Letter) $($pair.Share) /persistent:yes" 2>&1
                Write-Step "net use $($pair.Letter)"
            }
        }
    }
}

# Resolver RepoRoot se Z: indisponível
if (-not (Test-Path (Join-Path $RepoRoot "config\dotfiles\manifest.yaml"))) {
    foreach ($alt in @(
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
Ensure-Dir (Join-Path $LiveRoot "cursor\globalStorage")
Ensure-Dir (Join-Path $LiveRoot "cursor\dot-cursor\chats")
Ensure-Dir (Join-Path $LiveRoot "cursor\dot-cursor\projects")
Ensure-Dir (Join-Path $LiveRoot "claude\file-history")

$AppDataCursor = Join-Path $env:APPDATA "Cursor\User"
Ensure-Dir $AppDataCursor

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
Write-Host "OK install — fechar Cursor antes de sync globalStorage; correr verify-agl-home-sync.sh"
