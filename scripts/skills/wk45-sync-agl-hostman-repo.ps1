# Sincroniza agl-hostman na aglwk45: git pull no clone SMB + mirror para C:\ (guest exec).
# Uso local (RDP): powershell -ExecutionPolicy Bypass -File scripts\skills\wk45-sync-agl-hostman-repo.ps1
# Uso remoto: bash scripts/skills/propagate-sync-agl-hostman-wk45-qemu.sh
param(
    [string]$GitRemote = "https://github.com/aguileraz/agl-hostman.git",
    [string]$LocalMirror = "C:\Users\Administrator\apps\dev\agl\agl-hostman"
)

$ErrorActionPreference = "Stop"
$HomeRoot = "C:\Users\Administrator"
$LogFile = "$HomeRoot\wk45-repo-sync-result.txt"
$env:USERPROFILE = $HomeRoot
$env:HOME = $HomeRoot

function Write-Log([string]$Line) {
    Add-Content -Path $LogFile -Value $Line
    Write-Host $Line
}

Remove-Item $LogFile -Force -ErrorAction SilentlyContinue
Write-Log "=== wk45-sync-agl-hostman-repo $(Get-Date -Format o) ==="

$Git = "C:\Program Files\Git\cmd\git.exe"
if (-not (Test-Path $Git)) {
    Write-Log "FAIL git.exe em falta"
    exit 1
}

# Mapear overpower se ainda não existir (SYSTEM + sessões sem login)
$UncOverpower = "\\aglfs1\overpower"
foreach ($pair in @(
    @{ Letter = "Z:"; Share = $UncOverpower },
    @{ Letter = "U:"; Share = "\\aglfs1\storage" }
)) {
    if (-not (Test-Path ($pair.Letter + "\"))) {
        $null = cmd /c "net use $($pair.Letter) $($pair.Share) /persistent:yes" 2>&1
        Write-Log "net use $($pair.Letter) $($pair.Share) exit=$LASTEXITCODE"
    }
}

$RepoRel = "apps\dev\agl\agl-hostman"
$Candidates = @(
    "U:\$RepoRel",
    "Z:\$RepoRel",
    (Join-Path $UncOverpower $RepoRel),
    "R:\$RepoRel",
    $LocalMirror
) | Select-Object -Unique

$GitRoot = $null
foreach ($path in $Candidates) {
    if (Test-Path (Join-Path $path ".git")) {
        $GitRoot = $path
        Write-Log "OK repo git encontrado: $GitRoot"
        break
    }
}

if (-not $GitRoot) {
    $parent = Split-Path $LocalMirror -Parent
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    Write-Log "Clone inicial -> $LocalMirror"
    & $Git clone --depth 1 $GitRemote $LocalMirror 2>&1 | ForEach-Object { Write-Log $_ }
    if ($LASTEXITCODE -ne 0) {
        Write-Log "FAIL git clone exit=$LASTEXITCODE"
        exit $LASTEXITCODE
    }
    $GitRoot = $LocalMirror
}

Write-Log "--- git pull --ff-only ($GitRoot) ---"
Push-Location $GitRoot
& $Git -c safe.directory="$GitRoot" pull --ff-only 2>&1 | ForEach-Object { Write-Log $_ }
$pullExit = $LASTEXITCODE
Pop-Location
if ($pullExit -ne 0) {
    Write-Log "FAIL git pull exit=$pullExit"
    exit $pullExit
}

$head = & $Git -C $GitRoot rev-parse --short HEAD 2>&1
Write-Log "HEAD=$head"

if ($GitRoot -ne $LocalMirror) {
    Write-Log "--- robocopy mirror $GitRoot -> $LocalMirror ---"
    New-Item -ItemType Directory -Force -Path $LocalMirror | Out-Null
    $robolog = "$HomeRoot\wk45-repo-robocopy.log"
    & robocopy $GitRoot $LocalMirror /MIR /XD ".git" "node_modules" ".beads" /R:2 /W:5 /NFL /NDL /NJH /NJS /NP 2>&1 | ForEach-Object { Write-Log $_ }
    $rc = $LASTEXITCODE
    if ($rc -ge 8) {
        Write-Log "FAIL robocopy exit=$rc (ver $robolog)"
        exit $rc
    }
    Write-Log "OK robocopy exit=$rc (0-7 = sucesso parcial/total)"
}

if (Test-Path (Join-Path $LocalMirror "scripts\skills\sync-six-repos.sh")) {
    Write-Log "OK sync-six-repos.sh no mirror local"
} else {
    Write-Log "WARN sync-six-repos.sh em falta no mirror"
}

Write-Log "OK wk45-sync-agl-hostman-repo concluído"
exit 0
