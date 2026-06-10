# Propaga Six Repos na aglwk45 via contexto guest (SYSTEM + vm104_guest_exec_ps1.py).
# Scripts bash em C:\Windows\Temp\agl-six-repos (acessível em guest exec).
param(
    [string]$RepoRoot = "C:/Users/Administrator/apps/dev/agl/agl-hostman",
    [string]$ScriptsDir = "C:\Windows\Temp\agl-six-repos",
    [string]$Harness = "claude,cursor,codex,verdent,hostman",
    [switch]$Wait
)

$ErrorActionPreference = "Stop"
$HomeRoot = "C:\Users\Administrator"
$ResultFile = "$HomeRoot\wk45-six-repos-result.txt"
$RunnerPs1 = "C:\Windows\Temp\agl-six-repos-run.ps1"
$env:USERPROFILE = $HomeRoot
$env:HOME = $HomeRoot

function Write-Result([string]$Line) {
    Add-Content -Path $ResultFile -Value $Line
    Write-Host $Line
}

$RepoRoot = $RepoRoot -replace '/', '\'

Remove-Item $ResultFile -Force -ErrorAction SilentlyContinue
Write-Result "RepoRoot=$RepoRoot"
Write-Result "ScriptsDir=$ScriptsDir"

$Bash = $null
foreach ($candidate in @(
    "C:\Program Files\Git\bin\bash.exe",
    "C:\Program Files\Git\usr\bin\bash.exe"
)) {
    if (Test-Path $candidate) { $Bash = $candidate; break }
}
if (-not $Bash) {
    Write-Result "FAIL Git Bash em falta"
    exit 1
}

$syncSrc = Join-Path $ScriptsDir "sync-six-repos.sh"
$verifySrc = Join-Path $ScriptsDir "verify-six-repos.sh"
if (-not (Test-Path $syncSrc)) {
    Write-Result "FAIL sync-six-repos.sh em falta em $ScriptsDir"
    exit 1
}

New-Item -ItemType Directory -Force -Path (Join-Path $RepoRoot "scripts\skills") | Out-Null
Copy-Item $syncSrc (Join-Path $RepoRoot "scripts\skills\sync-six-repos.sh") -Force
if (Test-Path $verifySrc) {
    Copy-Item $verifySrc (Join-Path $RepoRoot "scripts\skills\verify-six-repos.sh") -Force
}

$repoBash = ($RepoRoot -replace '\\', '/')
$homeBash = ($HomeRoot -replace '\\', '/')
$runner = @"
`$ErrorActionPreference = 'Continue'
`$ResultFile = '$ResultFile'
`$HomeRoot = '$HomeRoot'
`$env:USERPROFILE = `$HomeRoot
`$env:HOME = `$HomeRoot
function Write-Result([string]`$Line) { Add-Content -Path `$ResultFile -Value `$Line }

Write-Result '--- sync-six-repos ---'
    & '$Bash' -lc "export HOME='$homeBash' && export USERPROFILE='$homeBash' && cd '$repoBash' && export HOSTMAN_ROOT_OVERRIDE='$repoBash' && export SKIP_LLM_WIKI=1 && export SKIP_RUFLO_INIT=1 && ./scripts/skills/install-post-skills-claude-code.sh" 2>&1 | ForEach-Object { Write-Result `$_ }
if (`$LASTEXITCODE -ne 0) {
    Write-Result "FAIL sync exit=`$LASTEXITCODE"
    exit `$LASTEXITCODE
}

if (Test-Path '$RepoRoot\scripts\skills\verify-six-repos.sh') {
    Write-Result '--- verify-six-repos ---'
    & '$Bash' -lc "export HOME='$homeBash' && export USERPROFILE='$homeBash' && cd '$repoBash' && export HOSTMAN_ROOT_OVERRIDE='$repoBash' && export SKIP_LLM_WIKI=1 && ./scripts/skills/verify-six-repos.sh" 2>&1 | ForEach-Object { Write-Result `$_ }
    if (`$LASTEXITCODE -ne 0) {
        Write-Result "FAIL verify exit=`$LASTEXITCODE"
        exit `$LASTEXITCODE
    }
}

`$checks = @(
    '$HomeRoot\.cursor\skills\obsidian-cli\SKILL.md',
    '$HomeRoot\.claude\skills\using-superpowers\SKILL.md',
    '$HomeRoot\.claude\skills\humanizer\SKILL.md',
    '$HomeRoot\.claude\skills\fact-check\SKILL.md',
    '$HomeRoot\.claude\skills\frontend-slides\SKILL.md',
    '$HomeRoot\.cursor\skills\od-design-md\SKILL.md'
)
foreach (`$path in `$checks) {
    if (Test-Path `$path) { Write-Result "OK skill `$path" } else { Write-Result "WARN skill em falta `$path" }
}
Write-Result 'OK wk45-propagate-six-repos-guest concluído'
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
    -WorkingDirectory $RepoRoot | Out-Null
Write-Result "OK runner iniciado (poll $ResultFile)"
exit 0
