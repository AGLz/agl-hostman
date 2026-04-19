# OpenClaw Installation Script for aglwk45 (VM104)
# Created: 2026-01-30
# Usage: powershell -ExecutionPolicy Bypass -File install-openclaw-aglwk45.ps1

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "OpenClaw Installation for aglwk45" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check Node.js version
Write-Host "[1/6] Checking Node.js version..." -ForegroundColor Yellow
node --version
npm --version
Write-Host ""

# Check if OpenClaw is installed
Write-Host "[2/6] Checking OpenClaw installation..." -ForegroundColor Yellow
$openclawCmd = Get-Command openclaw -ErrorAction SilentlyContinue
if ($openclawCmd) {
    Write-Host "✓ OpenClaw found at: $($openclawCmd.Source)" -ForegroundColor Green
    & openclaw --version
} else {
    Write-Host "✗ OpenClaw not in PATH, checking C:\Program Files\nodejs..." -ForegroundColor Red
    if (Test-Path "C:\Program Files\nodejs\openclaw.cmd") {
        Write-Host "✓ Found at C:\Program Files\nodejs\openclaw.cmd" -ForegroundColor Green
        $openclawCmd = "C:\Program Files\nodejs\openclaw.cmd"
    } else {
        Write-Host "Installing OpenClaw via npm..." -ForegroundColor Yellow
        npm install -g openclaw@latest
    }
}
Write-Host ""

# Check existing clawdbot installation
Write-Host "[3/6] Checking existing clawdbot..." -ForegroundColor Yellow
$clawdbotCmd = Get-Command clawdbot -ErrorAction SilentlyContinue
if ($clawdbotCmd) {
    Write-Host "✓ Clawdbot found at: $($clawdbotCmd.Source)" -ForegroundColor Green
    & clawdbot --version
}
Write-Host ""

# Check config directories
Write-Host "[4/6] Checking configuration directories..." -ForegroundColor Yellow
$clawdbotConfig = Test-Path "$env:USERPROFILE\.clawdbot"
$openclawConfig = Test-Path "$env:USERPROFILE\.openclaw"
$systemClawdbot = Test-Path "C:\windows\system32\config\systemprofile\.clawdbot"

Write-Host "  .clawdbot (user): $clawdbotConfig"
Write-Host "  .openclaw (user): $openclawConfig"
Write-Host "  .clawdbot (system): $systemClawdbot"
Write-Host ""

# Run OpenClaw doctor
Write-Host "[5/6] Running OpenClaw doctor..." -ForegroundColor Yellow
if (Test-Path "C:\Program Files\nodejs\openclaw.cmd") {
    & "C:\Program Files\nodejs\openclaw.cmd" doctor --fix
} else {
    & openclaw doctor --fix
}
Write-Host ""

# Configure ZAI API key
Write-Host "[6/6] Configuring ZAI API key for GLM-4.7..." -ForegroundColor Yellow

# Determine config location
$configBase = "$env:USERPROFILE\.openclaw"
if (-not (Test-Path $configBase)) {
    $configBase = "C:\windows\system32\config\systemprofile\.clawdbot"
}

$authDir = "$configBase\agents\main\agent"
$authFile = "$authDir\auth-profiles.json"

if (-not (Test-Path $authFile)) {
    Write-Host "Creating auth-profiles.json..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path $authDir | Out-Null

    $authConfig = @{
        profiles = @{
            "zai:default" = @{
                type = "api_key"
                provider = "zai"
                key = "896fb1e6936a4cd1b61aa2314d6d3728.u2lsAqLNfajAslfx"
            }
        }
    }

    $authConfig | ConvertTo-Json -Depth 10 | Out-File -FilePath $authFile -Encoding utf8
    Write-Host "✓ ZAI API key configured at: $authFile" -ForegroundColor Green
} else {
    Write-Host "Auth file already exists: $authFile" -ForegroundColor Yellow
    Write-Host "Please update manually if needed." -ForegroundColor Yellow
}
Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Installation Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Green
Write-Host "  1. Run: openclaw onboard"
Write-Host "  2. Run: openclaw status"
Write-Host "  3. Run: openclaw dashboard"
Write-Host ""
Write-Host "ZAI API Key: 896fb1e6936a4cd1b61aa2314d6d3728.u2lsAqLNfajAslfx" -ForegroundColor Yellow
Write-Host ""
