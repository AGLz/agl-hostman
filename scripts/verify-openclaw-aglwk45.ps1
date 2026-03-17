# Verificação OpenClaw - AGLWK45 (Windows)
# Executar no PowerShell ou Git Bash: powershell -ExecutionPolicy Bypass -File scripts/verify-openclaw-aglwk45.ps1

Write-Host "=== OpenClaw - AGLWK45 ===" -ForegroundColor Cyan
Write-Host ""

# Versão
$version = openclaw --version 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Versao: $version" -ForegroundColor Green
} else {
    Write-Host "OpenClaw nao encontrado. Instale: npm install -g openclaw" -ForegroundColor Red
    exit 1
}

# Status
Write-Host ""
Write-Host "--- Status ---" -ForegroundColor Yellow
openclaw status 2>&1

# Modelos
Write-Host ""
Write-Host "--- Modelos (primeiros 12) ---" -ForegroundColor Yellow
openclaw models list 2>&1 | Select-Object -First 12

# LiteLLM (agldv03)
Write-Host ""
Write-Host "--- LiteLLM Gateway (agldv03) ---" -ForegroundColor Yellow
try {
    $r = Invoke-WebRequest -Uri "http://100.94.221.87:4000/health" -UseBasicParsing -TimeoutSec 5
    Write-Host "OK: $($r.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "Falha: $_" -ForegroundColor Red
}
