# Espelha agl-hostman de Z:\ (overpower SMB) para C:\ (guest exec / scripts locais).
# O git pull deve correr no Linux/NFS (mesma árvore): git pull em /mnt/overpower/.../agl-hostman
param(
    [string]$Source = "Z:\apps\dev\agl\agl-hostman",
    [string]$Dest = "C:\Users\Administrator\apps\dev\agl\agl-hostman",
    [switch]$Wait
)

$ErrorActionPreference = "Stop"
$LogFile = "C:\Users\Administrator\wk45-repo-sync-result.txt"

function Write-Log([string]$Line) {
    Add-Content -Path $LogFile -Value $Line
    Write-Host $Line
}

Remove-Item $LogFile -Force -ErrorAction SilentlyContinue
Write-Log "=== wk45-mirror-agl-hostman-repo $(Get-Date -Format o) ==="

$UncCandidates = @(
    "\\192.168.0.178\overpower",
    "\\100.69.187.105\overpower",
    "\\aglfs1\overpower"
)
$Unc = $null
foreach ($candidate in $UncCandidates) {
  $probe = cmd /c "dir /b `"$candidate`" 2>nul" 2>&1
  if ($LASTEXITCODE -eq 0) { $Unc = $candidate; break }
}
if (-not $Unc) { $Unc = $UncCandidates[0] }

if (-not (Test-Path "Z:\")) {
    $null = cmd /c "net use Z: `"$Unc`" /user:guest `"`" /persistent:yes" 2>&1
    if ($LASTEXITCODE -ne 0) {
        $null = cmd /c "net use Z: `"$Unc`" /persistent:yes" 2>&1
    }
    cmd /c "net use Z:" 2>&1 | ForEach-Object { Write-Log $_ }
}

if (-not (Test-Path $Source)) {
    $Source = Join-Path $Unc "apps\dev\agl\agl-hostman"
}
if (-not (Test-Path $Source)) {
    Write-Log "FAIL source em falta: $Source"
    exit 1
}

Write-Log "Source=$Source"
Write-Log "Dest=$Dest"

$runner = @"
`$ErrorActionPreference = 'Continue'
`$LogFile = '$LogFile'
function Write-Log([string]`$Line) { Add-Content -Path `$LogFile -Value `$Line }
Write-Log '--- robocopy /MIR (async runner) ---'
`$rc = 0
robocopy '$Source' '$Dest' /MIR /XD '.git' 'node_modules' '.beads' 'vendor' '.doltcfg' '.security-reports' /XF 'privileges.db' /R:1 /W:3 /NFL /NDL /NJH /NJS /NP /DCOPY:DA 2>&1 | ForEach-Object { Write-Log `$_ }
`$rc = `$LASTEXITCODE
if (`$rc -ge 8) { Write-Log "WARN robocopy exit=`$rc (ficheiros protegidos podem falhar)" } else { Write-Log "OK robocopy exit=`$rc" }
foreach (`$rel in @('scripts\skills\sync-six-repos.sh','.cursor\rules\karpathy-skills.mdc','CLAUDE.md')) {
  `$p = Join-Path '$Dest' `$rel
  if (Test-Path `$p) { Write-Log "OK `$rel" } else { Write-Log "WARN em falta `$rel" }
}
Write-Log 'OK wk45-mirror-agl-hostman-repo concluído'
exit 0
"@

$runnerPath = "C:\Windows\Temp\agl-hostman-mirror-run.ps1"
Set-Content -Path $runnerPath -Value $runner -Encoding UTF8
New-Item -ItemType Directory -Force -Path $Dest | Out-Null

if ($Wait) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runnerPath
    exit $LASTEXITCODE
}

Write-Log "START async mirror $runnerPath"
Start-Process -FilePath "powershell.exe" `
    -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $runnerPath) `
    -WindowStyle Hidden | Out-Null
Write-Log "OK runner iniciado (poll $LogFile)"
exit 0
