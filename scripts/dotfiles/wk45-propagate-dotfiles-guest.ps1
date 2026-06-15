# Propaga dotfiles + live sync na aglwk45 via guest exec (SYSTEM).
# Chamado por propagate-dotfiles-wk45-qemu.sh no AGLSRV1.
param(
    [string]$RepoRoot = "C:\Users\Administrator\apps\dev\agl\agl-hostman",
    [string]$HomeSyncRoot = "Z:\apps\dev\agl\agl-home-sync",
    [string]$HomeUser = "linux-root",
    [switch]$Wait
)

$ErrorActionPreference = "Stop"
$HomeRoot = "C:\Users\Administrator"
$ResultFile = "$HomeRoot\wk45-dotfiles-result.txt"
$RunnerPs1 = "C:\Windows\Temp\agl-dotfiles-run.ps1"
$env:USERPROFILE = $HomeRoot
$env:HOME = $HomeRoot

function Write-Result([string]$Line) {
    Add-Content -Path $ResultFile -Value $Line
    Write-Host $Line
}

Remove-Item $ResultFile -Force -ErrorAction SilentlyContinue
Write-Result "=== wk45-propagate-dotfiles $(Get-Date -Format o) ==="

# Mapear overpower (guest exec corre como SYSTEM — net use explícito)
$UncOverpower = "\\aglfs1\overpower"
foreach ($pair in @(
    @{ Letter = "Z:"; Share = $UncOverpower },
    @{ Letter = "U:"; Share = "\\aglfs1\storage" }
)) {
    if (-not (Test-Path ($pair.Letter + "\"))) {
        $null = cmd /c "net use $($pair.Letter) $($pair.Share) /persistent:yes" 2>&1
        Write-Result "net use $($pair.Letter) $($pair.Share) exit=$LASTEXITCODE"
    } else {
        Write-Result "OK drive $($pair.Letter) já mapeado"
    }
}

$RepoCandidates = @(
    $RepoRoot,
    "Z:\apps\dev\agl\agl-hostman",
    "U:\apps\dev\agl\agl-hostman",
    (Join-Path $UncOverpower "apps\dev\agl\agl-hostman")
) | Select-Object -Unique

$ResolvedRepo = $null
foreach ($path in $RepoCandidates) {
    if (Test-Path (Join-Path $path "scripts\dotfiles\install-agl-home-sync.ps1")) {
        $ResolvedRepo = $path
        Write-Result "OK repo: $ResolvedRepo"
        break
    }
}
if (-not $ResolvedRepo) {
    Write-Result "FAIL repo agl-hostman com scripts/dotfiles em falta"
    exit 1
}

$SyncRootCandidates = @(
    $HomeSyncRoot,
    "Z:\apps\dev\agl\agl-home-sync",
    (Join-Path $UncOverpower "apps\dev\agl\agl-home-sync")
) | Select-Object -Unique

$ResolvedSync = $null
foreach ($path in $SyncRootCandidates) {
    if (Test-Path $path) {
        $ResolvedSync = $path
        Write-Result "OK home-sync: $ResolvedSync"
        break
    }
}
if (-not $ResolvedSync) {
    Write-Result "WARN home-sync root em falta — install pode criar subdirs"
    $ResolvedSync = "Z:\apps\dev\agl\agl-home-sync"
}

$InstallPs1 = Join-Path $ResolvedRepo "scripts\dotfiles\install-agl-home-sync.ps1"
$VerifySh = Join-Path $ResolvedRepo "scripts\dotfiles\verify-agl-home-sync.sh"

$Bash = $null
foreach ($candidate in @(
    "C:\Program Files\Git\bin\bash.exe",
    "C:\Program Files\Git\usr\bin\bash.exe"
)) {
    if (Test-Path $candidate) { $Bash = $candidate; break }
}

$repoEsc = $ResolvedRepo -replace '\\', '/'
$syncEsc = $ResolvedSync -replace '\\', '/'
$homeEsc = $HomeRoot -replace '\\', '/'

$runner = @"
`$ErrorActionPreference = 'Continue'
`$ResultFile = '$ResultFile'
function Write-Result([string]`$Line) { Add-Content -Path `$ResultFile -Value `$Line }

Write-Result '--- install-agl-home-sync.ps1 ---'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File '$InstallPs1' `
    -RepoRoot '$ResolvedRepo' `
    -HomeSyncRoot '$ResolvedSync' `
    -HomeUser '$HomeUser'
if (`$LASTEXITCODE -ne 0) {
    Write-Result "FAIL install exit=`$LASTEXITCODE"
    exit `$LASTEXITCODE
}

if (Test-Path '$VerifySh') {
    Write-Result '--- verify-agl-home-sync.sh ---'
    `$bash = '$Bash'
    if (-not (Test-Path `$bash)) {
        Write-Result 'WARN Git Bash em falta — skip verify bash'
    } else {
        & `$bash -lc "export HOME='$homeEsc' && export USERPROFILE='$homeEsc' && export AGL_HOME_SYNC_ROOT='$syncEsc' && export AGL_HOME_USER='$HomeUser' && cd '$repoEsc' && ./scripts/dotfiles/verify-agl-home-sync.sh" 2>&1 | ForEach-Object { Write-Result `$_ }
        if (`$LASTEXITCODE -ne 0) {
            Write-Result "FAIL verify exit=`$LASTEXITCODE"
            exit `$LASTEXITCODE
        }
    }
}

`$checks = @(
    '$HomeRoot\.cursor\chats',
    '$env:APPDATA\Cursor\User\globalStorage',
    '$HomeRoot\.claude\settings.json'
)
foreach (`$path in `$checks) {
    `$item = Get-Item `$path -ErrorAction SilentlyContinue
    if (`$item -and `$item.LinkType) {
        Write-Result "OK symlink `$path -> `$(`$item.Target)"
    } elseif (Test-Path `$path) {
        Write-Result "OK exists `$path (não symlink)"
    } else {
        Write-Result "WARN em falta `$path"
    }
}
Write-Result 'OK wk45-propagate-dotfiles concluído'
exit 0
"@

Set-Content -Path $RunnerPs1 -Value $runner -Encoding UTF8

if ($Wait) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $RunnerPs1
    exit $LASTEXITCODE
}

Write-Result "START async runner $RunnerPs1"
Start-Process -FilePath "powershell.exe" `
    -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $RunnerPs1) `
    -WindowStyle Hidden `
    -WorkingDirectory $ResolvedRepo | Out-Null
Write-Result "OK runner iniciado (poll $ResultFile)"
exit 0
