# Arranca gateway sem doctor/build (apos pnpm install + minhost fix).
$ErrorActionPreference = 'Continue'
$homeRoot = 'C:\Users\Administrator'
$log = Join-Path $homeRoot 'wk45-gateway-only.log'
$env:USERPROFILE = $homeRoot
$env:HOME = $homeRoot
$env:APPDATA = Join-Path $homeRoot 'AppData\Roaming'
$env:LOCALAPPDATA = Join-Path $homeRoot 'AppData\Local'
$env:PATH = "C:\Program Files\Git\bin;C:\Program Files\nodejs;$env:PATH"

function Log($m) { "$(Get-Date -Format o) $m" | Tee-Object -FilePath $log -Append }
Remove-Item $log -Force -EA SilentlyContinue

foreach ($ld in @("$homeRoot\AppData\Local\Temp\openclaw", "$env:TEMP\openclaw")) {
  if (Test-Path $ld) {
    Get-ChildItem -LiteralPath $ld -Filter '*.lock' -EA SilentlyContinue | Remove-Item -Force -EA SilentlyContinue
  }
}

Get-CimInstance Win32_Process -Filter "Name = 'node.exe'" -EA SilentlyContinue | Where-Object {
  $_.CommandLine -match 'openclaw\\dist\\index\.js'
} | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -EA SilentlyContinue }
Start-Sleep 2

schtasks /End /TN 'OpenClaw Gateway' 2>&1 | ForEach-Object { Log $_ }
Start-Sleep 2
schtasks /Run /TN 'OpenClaw Gateway' 2>&1 | ForEach-Object { Log $_ }
Start-Sleep 30

if (Get-NetTCPConnection -LocalPort 18789 -State Listen -EA SilentlyContinue) {
  Log 'OK: 18789 Listen'
} else {
  Log 'WARN: 18789 not Listen'
}

try {
  $r = Invoke-WebRequest -Uri 'http://127.0.0.1:18789/healthz' -UseBasicParsing -TimeoutSec 15
  Log "healthz OK: $($r.Content)"
} catch {
  Log "healthz FAIL: $($_.Exception.Message)"
  $err = Join-Path $homeRoot 'AppData\Local\Temp\openclaw-gateway-stderr.log'
  if (Test-Path $err) { Get-Content $err -Tail 20 | ForEach-Object { Log "stderr: $_" } }
}

Log '=== FIM gateway-only ==='
