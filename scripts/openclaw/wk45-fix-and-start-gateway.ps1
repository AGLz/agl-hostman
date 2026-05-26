# Corrige config, rebuild se necessario, arranca gateway. Grava log em C:\Users\Administrator\wk45-result.txt
$ErrorActionPreference = 'Continue'
$logFile = 'C:\Users\Administrator\wk45-result.txt'
function Log($m) { "$(Get-Date -Format o) $m" | Tee-Object -FilePath $logFile -Append }

$homeRoot = 'C:\Users\Administrator'
$clone = Join-Path $homeRoot 'src\openclaw'
$node = 'C:\Program Files\nodejs\node.exe'
$dist = Join-Path $clone 'dist\index.js'
$pruneCjs = Join-Path $homeRoot 'AppData\Local\Temp\wk45-prune-invalid-plugin-entries.cjs'
$env:USERPROFILE = $homeRoot
$env:HOME = $homeRoot
$env:CI = 'true'
$env:APPDATA = Join-Path $homeRoot 'AppData\Roaming'
$env:LOCALAPPDATA = Join-Path $homeRoot 'AppData\Local'
$env:PATH = "C:\Program Files\Git\bin;C:\Program Files\nodejs;$env:PATH"

Remove-Item $logFile -Force -EA SilentlyContinue
Set-Location $clone

if (Test-Path $pruneCjs) {
  Log "=== prune invalid plugin entries ==="
  & $node $pruneCjs 2>&1 | ForEach-Object { Log $_ }
}

Log "=== pnpm install ==="
pnpm install 2>&1 | ForEach-Object { Log $_ }

Log "=== pnpm ui:build ==="
pnpm ui:build 2>&1 | ForEach-Object { Log $_ }

Log "=== pnpm build (pos-upgrade) ==="
pnpm build 2>&1 | ForEach-Object { Log $_ }

Log "=== doctor --fix --yes ==="
& $node $dist doctor --fix --yes 2>&1 | ForEach-Object { Log $_ }

foreach ($ld in @("$env:TEMP\openclaw", "$homeRoot\AppData\Local\Temp\openclaw")) {
  if (Test-Path $ld) {
    Get-ChildItem -LiteralPath $ld -Filter '*.lock' -EA SilentlyContinue | Remove-Item -Force -EA SilentlyContinue
  }
}

Get-CimInstance Win32_Process -Filter "Name = 'node.exe'" -EA SilentlyContinue | Where-Object {
  $_.CommandLine -match 'dist\\index\.js'
} | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -EA SilentlyContinue }
Start-Sleep 3

Log "=== start gateway (gateway.cmd + schtasks) ==="
$gwDir = Join-Path $homeRoot '.openclaw'
$gwCmd = Join-Path $gwDir 'gateway.cmd'
if (Test-Path $gwCmd) {
  Start-Process -FilePath 'cmd.exe' -ArgumentList @('/c', $gwCmd) -WorkingDirectory $gwDir -WindowStyle Hidden
  Start-Sleep 20
}
schtasks /End /TN "OpenClaw Gateway" 2>&1 | ForEach-Object { Log $_ }
Start-Sleep 3
schtasks /Run /TN "OpenClaw Gateway" 2>&1 | ForEach-Object { Log $_ }
Start-Sleep 30

if (Get-NetTCPConnection -LocalPort 18789 -State Listen -EA SilentlyContinue) {
  Log "OK: 18789 Listen"
} else {
  Log "Retry schtasks"
  schtasks /Run /TN "OpenClaw Gateway"
  Start-Sleep 20
}

try {
  $r = Invoke-WebRequest -Uri 'http://127.0.0.1:18789/healthz' -UseBasicParsing -TimeoutSec 15
  Log "healthz: $($r.Content)"
} catch {
  Log "healthz FAIL: $($_.Exception.Message)"
  $err = Join-Path $env:TEMP 'openclaw-gateway-stderr.log'
  if (Test-Path $err) { Get-Content $err -Tail 20 | ForEach-Object { Log "stderr: $_" } }
}

Log "=== FIM ==="
