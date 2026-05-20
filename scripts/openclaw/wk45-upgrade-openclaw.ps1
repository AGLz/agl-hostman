# Atualiza OpenClaw no clone C:\Users\Administrator\src\openclaw e reinicia o gateway (tarefa agendada).
# Uso: powershell -ExecutionPolicy Bypass -File wk45-upgrade-openclaw.ps1
$ErrorActionPreference = 'Stop'
$clone = 'C:\Users\Administrator\src\openclaw'
$gitBin = 'C:\Program Files\Git\bin'
if (Test-Path $gitBin) { $env:PATH = "$gitBin;$env:PATH" }

if (-not (Test-Path "$clone\.git")) {
  Write-Error "Clone em falta: $clone"
}

Set-Location $clone
Write-Host "=== git fetch + pull ==="
git fetch --tags origin
git pull --ff-only
$ver = (Get-Content package.json -Raw | ConvertFrom-Json).version
Write-Host "package.json version: $ver"

Write-Host "=== pnpm install ==="
pnpm install

Write-Host "=== pnpm ui:build ==="
pnpm ui:build

Write-Host "=== pnpm build ==="
pnpm build

Write-Host "=== gateway install --force ==="
if (Get-Command openclaw -ErrorAction SilentlyContinue) {
  openclaw gateway install --force
} else {
  & "$clone\dist\index.js" --version 2>$null
  Write-Host "openclaw CLI global ausente; gateway.cmd deve usar dist\index.js"
}

Write-Host "=== reiniciar tarefa OpenClaw Gateway ==="
schtasks /End /TN "OpenClaw Gateway" 2>$null
Start-Sleep -Seconds 3
schtasks /Run /TN "OpenClaw Gateway"
Start-Sleep -Seconds 8

$listen = Get-NetTCPConnection -LocalPort 18789 -State Listen -ErrorAction SilentlyContinue
if ($listen) { Write-Host "OK: porta 18789 Listen" } else { Write-Warning "AVISO: 18789 nao em Listen" }

try {
  $r = Invoke-WebRequest -Uri 'http://127.0.0.1:18789/healthz' -UseBasicParsing -TimeoutSec 15
  Write-Host "healthz: $($r.StatusCode) $($r.Content)"
} catch {
  Write-Warning "healthz falhou: $_"
}

Write-Host "=== FIM upgrade $ver ==="
