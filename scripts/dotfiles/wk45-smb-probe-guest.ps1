# Diagnóstico SMB no guest (SYSTEM) — aglwk45 VM104
$ErrorActionPreference = "Continue"
$Log = "C:\Users\Administrator\wk45-smb-probe.txt"
Remove-Item $Log -Force -ErrorAction SilentlyContinue

function L([string]$m) { Add-Content $Log $m; Write-Host $m }

L "=== smb-probe $(Get-Date -Format o) ==="

foreach ($letter in @("Z:", "U:")) {
    if (Test-Path "${letter}\") {
        L "delete $letter"
        cmd /c "net use $letter /delete /y" 2>&1 | ForEach-Object { L $_ }
    }
}

$Unc = "\\192.168.0.178\overpower"
L "ping 192.168.0.178"
ping -n 2 192.168.0.178 2>&1 | ForEach-Object { L $_ }

L "net use guest"
cmd /c "net use Z: `"$Unc`" /user:guest `"`" /persistent:yes" 2>&1 | ForEach-Object { L $_ }
L "net use guest exit=$LASTEXITCODE"

if ($LASTEXITCODE -ne 0) {
    L "net use anonymous"
    cmd /c "net use Z: `"$Unc`" /persistent:yes" 2>&1 | ForEach-Object { L $_ }
    L "net use anon exit=$LASTEXITCODE"
}

net use 2>&1 | ForEach-Object { L $_ }

L "dir unc"
cmd /c "dir /b `"$Unc`" 2>&1" | ForEach-Object { L $_ }
L "dir unc exit=$LASTEXITCODE"

if (Test-Path "Z:\") {
    cmd /c "dir /b Z:\apps\dev\agl 2>&1" | ForEach-Object { L $_ }
}

L "=== done ==="
