# Corrige minHostVersion nos extensions, rebuild completo, arranca gateway (Administrator).
$ErrorActionPreference = 'Continue'
$homeRoot = 'C:\Users\Administrator'
$clone = Join-Path $homeRoot 'src\openclaw'
$log = Join-Path $homeRoot 'wk45-rebuild.log'
$node = 'C:\Program Files\nodejs\node.exe'
$dist = Join-Path $clone 'dist\index.js'
$fixCjs = Join-Path $homeRoot 'AppData\Local\Temp\wk45-fix-extension-minhost.cjs'

$env:USERPROFILE = $homeRoot
$env:HOME = $homeRoot
$env:CI = 'true'
$env:APPDATA = Join-Path $homeRoot 'AppData\Roaming'
$env:LOCALAPPDATA = Join-Path $homeRoot 'AppData\Local'
$env:PATH = "C:\Program Files\Git\bin;C:\Program Files\nodejs;$env:PATH"

function Log($m) { "$(Get-Date -Format o) $m" | Tee-Object -FilePath $log -Append }
Remove-Item $log -Force -EA SilentlyContinue
Set-Location $clone

if (Test-Path $fixCjs) {
  Log '=== fix extension minHostVersion ==='
  & $node $fixCjs 2>&1 | ForEach-Object { Log $_ }
}

Log '=== pnpm install ==='
pnpm install 2>&1 | ForEach-Object { Log $_ }

Log '=== pnpm build ==='
pnpm build 2>&1 | ForEach-Object { Log $_ }

Log '=== doctor --fix --yes ==='
& $node $dist doctor --fix --yes 2>&1 | ForEach-Object { Log $_ }

foreach ($ld in @("$homeRoot\AppData\Local\Temp\openclaw", "$env:TEMP\openclaw")) {
  if (Test-Path $ld) {
    Get-ChildItem -LiteralPath $ld -Filter '*.lock' -EA SilentlyContinue | Remove-Item -Force -EA SilentlyContinue
  }
}

Get-CimInstance Win32_Process -Filter "Name = 'node.exe'" -EA SilentlyContinue | Where-Object {
  $_.CommandLine -match 'dist\\index\.js'
} | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -EA SilentlyContinue }
Start-Sleep 3

$gwDir = Join-Path $homeRoot '.openclaw'
schtasks /End /TN 'OpenClaw Gateway' 2>&1 | ForEach-Object { Log $_ }
Start-Sleep 2
schtasks /Run /TN 'OpenClaw Gateway' 2>&1 | ForEach-Object { Log $_ }
Start-Sleep 25

try {
  $r = Invoke-WebRequest -Uri 'http://127.0.0.1:18789/healthz' -UseBasicParsing -TimeoutSec 15
  Log "healthz OK: $($r.Content)"
} catch {
  Log "healthz FAIL: $($_.Exception.Message)"
  $err = Join-Path $homeRoot 'AppData\Local\Temp\openclaw-gateway-stderr.log'
  if (Test-Path $err) { Get-Content $err -Tail 15 | ForEach-Object { Log "stderr: $_" } }
}

Log '=== FIM rebuild ==='
