# Propaga dotfiles + live sync na aglwk45 via guest exec (SYSTEM).
# Sai rápido: trabalho pesado no runner async (evita timeout qm guest-exec-status).
param(
    [string]$RepoRoot = "C:\Users\Administrator\apps\dev\agl\agl-hostman",
    [string]$HomeSyncRoot = "Z:\apps\dev\agl\agl-home-sync",
    [string]$HomeUser = "linux-root",
    [string]$BundledRepo = "C:\Windows\Temp\agl-dotfiles\agl-hostman",
    [switch]$Wait
)

$ErrorActionPreference = "Stop"
$HomeRoot = "C:\Users\Administrator"
$ResultFile = "$HomeRoot\wk45-dotfiles-result.txt"
$RunnerPs1 = "C:\Windows\Temp\agl-dotfiles-run.ps1"
$InstallPs1 = "C:\Windows\Temp\agl-dotfiles\install-agl-home-sync.ps1"
$VerifySh = "C:\Windows\Temp\agl-dotfiles\verify-agl-home-sync.sh"

$runner = @"
`$ErrorActionPreference = 'Continue'
`$ResultFile = '$ResultFile'
`$HomeRoot = '$HomeRoot'
`$BundledRepo = '$BundledRepo'
`$RepoRoot = '$RepoRoot'
`$HomeSyncRoot = '$HomeSyncRoot'
`$HomeUser = '$HomeUser'
`$InstallPs1 = '$InstallPs1'
`$VerifySh = '$VerifySh'
`$env:USERPROFILE = `$HomeRoot
`$env:HOME = `$HomeRoot
`$env:APPDATA = Join-Path `$HomeRoot 'AppData\Roaming'
`$env:LOCALAPPDATA = Join-Path `$HomeRoot 'AppData\Local'

function Write-Result([string]`$Line) {
    Add-Content -Path `$ResultFile -Value `$Line
}

Remove-Item `$ResultFile -Force -ErrorAction SilentlyContinue
Write-Result "=== wk45-propagate-dotfiles `$(Get-Date -Format o) ==="

foreach (`$letter in @('Z:', 'U:')) {
    `$status = cmd /c "net use `$letter 2>&1" | Out-String
    if (`$status -match 'Unavailable|disconnected|not found') {
        cmd /c "net use `$letter /delete /y" 2>&1 | Out-Null
        Write-Result "cleared stale `$letter"
    }
}

`$UncOverpower = `$null
foreach (`$unc in @('\\\\192.168.0.178\\overpower', '\\\\100.69.187.105\\overpower')) {
    `$null = cmd /c "dir /b `"`$unc`" 2>nul"
    if (`$LASTEXITCODE -eq 0) { `$UncOverpower = `$unc; break }
}
if (`$UncOverpower) {
    Write-Result "OK UNC `$UncOverpower"
    foreach (`$pair in @(
        @{ Letter = 'Z:'; Share = `$UncOverpower },
        @{ Letter = 'U:'; Share = (`$UncOverpower -replace '\\\\overpower`$', '\\\\storage') }
    )) {
        if (-not (Test-Path (`$pair.Letter + '\\'))) {
            `$null = cmd /c "net use `$(`$pair.Letter) `"`$(`$pair.Share)`" /user:guest `"`" /persistent:yes" 2>&1
            Write-Result "net use `$(`$pair.Letter) exit=`$LASTEXITCODE"
        }
    }
}

`$ResolvedRepo = `$null
`$RepoCandidates = @(`$BundledRepo, 'C:\Users\Administrator\apps\dev\agl\agl-hostman', `$RepoRoot)
if (Test-Path 'Z:\') { `$RepoCandidates += 'Z:\apps\dev\agl\agl-hostman' }
if (`$UncOverpower) { `$RepoCandidates += (Join-Path `$UncOverpower 'apps\dev\agl\agl-hostman') }
foreach (`$path in (`$RepoCandidates | Select-Object -Unique)) {
    if (`$path -and (Test-Path (Join-Path `$path 'config\dotfiles\manifest.yaml'))) {
        `$ResolvedRepo = `$path
        break
    }
}
if (-not `$ResolvedRepo) {
    Write-Result 'FAIL repo com config/dotfiles em falta'
    exit 1
}
Write-Result "OK repo: `$ResolvedRepo"

`$ResolvedSync = Join-Path `$HomeRoot 'agl-home-sync'
foreach (`$path in @('Z:\apps\dev\agl\agl-home-sync')) {
    if (`$path) {
        `$null = cmd /c "if exist `"`$path\`" exit 0 else exit 1"
        if (`$LASTEXITCODE -eq 0) { `$ResolvedSync = `$path; break }
    }
}
Write-Result "home-sync: `$ResolvedSync user=`$HomeUser"

Write-Result '--- install-agl-home-sync.ps1 ---'
try {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File `$InstallPs1 -RepoRoot `$ResolvedRepo -HomeSyncRoot `$ResolvedSync -HomeUser `$HomeUser -SkipNetUse 2>&1 | ForEach-Object { Write-Result `$_ }
} catch {
    Write-Result "FAIL install exception: `$(`$_.Exception.Message)"
    exit 1
}
if (`$LASTEXITCODE -ne 0) {
    Write-Result "FAIL install exit=`$LASTEXITCODE"
    exit `$LASTEXITCODE
}

`$Bash = `$null
foreach (`$candidate in @(
    'C:\Program Files\Git\bin\bash.exe',
    'C:\Program Files\Git\usr\bin\bash.exe'
)) {
    if (Test-Path `$candidate) { `$Bash = `$candidate; break }
}

if (`$Bash -and (Test-Path `$VerifySh)) {
    Write-Result '--- verify-agl-home-sync.sh ---'
    `$repoBash = (`$ResolvedRepo -replace '\\', '/')
    `$syncBash = (`$ResolvedSync -replace '\\', '/')
    `$homeBash = (`$HomeRoot -replace '\\', '/')
    `$verifyCmd = "export HOME='`$homeBash' USERPROFILE='`$homeBash' AGL_HOME_SYNC_ROOT='`$syncBash' AGL_HOME_USER='`$HomeUser' HOSTMAN_ROOT_OVERRIDE='`$repoBash' && bash '`$(`$VerifySh -replace '\\','/')'"
    & `$Bash -lc `$verifyCmd 2>&1 | ForEach-Object { Write-Result `$_ }
    if (`$LASTEXITCODE -ne 0) {
        Write-Result "WARN verify exit=`$LASTEXITCODE (continuar)"
    }
} else {
    Write-Result 'WARN skip verify (bash ou script em falta)'
}

foreach (`$path in @(
    "`$HomeRoot\.cursor\chats",
    "`$env:APPDATA\Cursor\User\globalStorage",
    "`$HomeRoot\.claude\settings.json"
)) {
    `$item = Get-Item `$path -ErrorAction SilentlyContinue
    if (`$item -and `$item.LinkType) {
        Write-Result "OK symlink `$path"
    } elseif (Test-Path `$path) {
        Write-Result "OK exists `$path"
    } else {
        Write-Result "WARN missing `$path"
    }
}

Write-Result 'OK wk45-propagate-dotfiles concluido'
exit 0
"@

Set-Content -Path $RunnerPs1 -Value $runner -Encoding UTF8

if ($Wait) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $RunnerPs1
    exit $LASTEXITCODE
}

Remove-Item $ResultFile -Force -ErrorAction SilentlyContinue
Add-Content -Path $ResultFile -Value "START async runner $RunnerPs1"
Start-Process -FilePath "powershell.exe" `
    -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $RunnerPs1) `
    -WindowStyle Hidden `
    -WorkingDirectory $HomeRoot | Out-Null
Write-Host "OK runner iniciado (poll $ResultFile)"
exit 0
