# Arranca o gateway OpenClaw na aglwk45 (porta 18789).
$ErrorActionPreference = 'Continue'
$homeRoot = 'C:\Users\Administrator'
$oc = Join-Path $homeRoot '.openclaw'
$gwCmd = Join-Path $oc 'gateway.cmd'
$logDir = Join-Path $env:TEMP 'openclaw'
$adminTempOc = Join-Path $homeRoot 'AppData\Local\Temp\openclaw'

foreach ($ld in @($logDir, $adminTempOc)) {
  if (Test-Path $ld) {
    Get-ChildItem -LiteralPath $ld -Filter '*.lock' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
  }
}

Get-CimInstance Win32_Process -Filter "Name = 'node.exe'" -ErrorAction SilentlyContinue | Where-Object {
  $_.CommandLine -match 'openclaw\\dist\\index\.js.*gateway|dist\\index\.js gateway'
} | ForEach-Object {
  Write-Host "A terminar PID $($_.ProcessId)"
  Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Seconds 2

schtasks /End /TN "OpenClaw Gateway" 2>$null
Start-Sleep -Seconds 2

if (-not (Test-Path $gwCmd)) {
  Write-Error "Falta $gwCmd"
  exit 1
}

$env:USERPROFILE = $homeRoot
$env:APPDATA = Join-Path $homeRoot 'AppData\Roaming'
$env:LOCALAPPDATA = Join-Path $homeRoot 'AppData\Local'

Write-Host "=== Arrancar gateway.cmd ==="
$p = Start-Process -FilePath 'cmd.exe' -ArgumentList @('/c', $gwCmd) -WorkingDirectory $oc -WindowStyle Hidden -PassThru
Start-Sleep -Seconds 15

$listen = Get-NetTCPConnection -LocalPort 18789 -State Listen -ErrorAction SilentlyContinue
if ($listen) {
  Write-Host "OK: porta 18789 Listen (PID gateway via node)"
} else {
  Write-Host "Tentar tarefa agendada..."
  schtasks /Run /TN "OpenClaw Gateway"
  Start-Sleep -Seconds 15
  $listen = Get-NetTCPConnection -LocalPort 18789 -State Listen -ErrorAction SilentlyContinue
  if ($listen) { Write-Host "OK: 18789 Listen (tarefa)" } else { Write-Host "ERRO: 18789 nao Listen" }
}

try {
  $r = Invoke-WebRequest -Uri 'http://127.0.0.1:18789/healthz' -UseBasicParsing -TimeoutSec 15
  Write-Host "healthz: $($r.Content)"
} catch {
  Write-Host "healthz ERRO: $($_.Exception.Message)"
}
