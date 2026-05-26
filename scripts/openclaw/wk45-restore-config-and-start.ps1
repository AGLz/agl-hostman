$ErrorActionPreference = 'Continue'
$homeRoot = 'C:\Users\Administrator'
$oc = Join-Path $homeRoot '.openclaw'
$log = Join-Path $homeRoot 'wk45-restore.log'
$bak = Join-Path $oc 'openclaw.json.bak'
$cfg = Join-Path $oc 'openclaw.json'
$node = 'C:\Program Files\nodejs\node.exe'
$fixCjs = Join-Path $homeRoot 'AppData\Local\Temp\wk45-fix-extension-minhost.cjs'

function Log($m) { "$(Get-Date -Format o) $m" | Tee-Object -FilePath $log -Append }
$env:USERPROFILE = $homeRoot
$env:HOME = $homeRoot
$env:CI = 'true'
Remove-Item $log -Force -EA SilentlyContinue

if (Test-Path $bak) {
  Copy-Item $bak $cfg -Force
  Log "Restored openclaw.json from openclaw.json.bak"
} else {
  Log "WARN: no openclaw.json.bak"
}

if (Test-Path $fixCjs) {
  & $node $fixCjs 2>&1 | ForEach-Object { Log $_ }
}

foreach ($ld in @("$homeRoot\AppData\Local\Temp\openclaw")) {
  if (Test-Path $ld) {
    Get-ChildItem -LiteralPath $ld -Filter '*.lock' -EA SilentlyContinue | Remove-Item -Force -EA SilentlyContinue
  }
}

schtasks /End /TN 'OpenClaw Gateway' 2>&1 | ForEach-Object { Log $_ }
Start-Sleep 2
schtasks /Run /TN 'OpenClaw Gateway' 2>&1 | ForEach-Object { Log $_ }
Start-Sleep 30

try {
  $r = Invoke-WebRequest -Uri 'http://127.0.0.1:18789/healthz' -UseBasicParsing -TimeoutSec 15
  Log "healthz OK: $($r.Content)"
} catch {
  Log "healthz FAIL: $($_.Exception.Message)"
  $err = Join-Path $homeRoot 'AppData\Local\Temp\openclaw-gateway-stderr.log'
  if (Test-Path $err) { Get-Content $err -Tail 15 | ForEach-Object { Log "stderr: $_" } }
}
Log '=== FIM restore ==='
