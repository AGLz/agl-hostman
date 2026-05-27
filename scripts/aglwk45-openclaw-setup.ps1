# OpenClaw Setup Script for aglwk45 (VM104)
# ===========================================
# Run this script via RDP on aglwk45 (192.168.0.33 or 100.117.146.21)
# Created: 2026-01-30

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "`n[$Message]" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "  $Message" -ForegroundColor White
}

function Write-Error-Host {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

Clear-Host
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "OpenClaw Setup for aglwk45" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Step 1: Check Node.js
Write-Step "1/7: Checking Node.js version"
$nodeVersion = node --version
$npmVersion = npm --version
Write-Info "Node: $nodeVersion"
Write-Info "npm: $npmVersion"

if (-not ($nodeVersion -match "^v2[2-9]\.")) {
    Write-Error-Host "Node.js version must be >= 22. Current: $nodeVersion"
    exit 1
}
Write-Success "Node.js version OK"

# Step 2: Uninstall old packages
Write-Step "2/7: Removing old clawdbot/openclaw packages"
try {
    npm uninstall -g clawdbot 2>$null
    Write-Info "Removed clawdbot"
} catch {
    Write-Info "clawdbot not installed"
}
try {
    npm uninstall -g openclaw 2>$null
    Write-Info "Removed openclaw"
} catch {
    Write-Info "openclaw not installed"
}
npm cache clean --force
Write-Success "Cleanup complete"

# Step 3: Install OpenClaw
Write-Step "3/7: Installing OpenClaw via npm"
npm install -g openclaw@latest
Write-Success "OpenClaw installed"

# Verify installation
$openclawCmd = Get-Command openclaw -ErrorAction SilentlyContinue
if ($openclawCmd) {
    Write-Info "OpenClaw location: $($openclawCmd.Source)"
    & openclaw --version
}

# Step 4: Run doctor to fix any issues
Write-Step "4/7: Running OpenClaw doctor"
& openclaw doctor --fix
Write-Success "Doctor check complete"

# Step 5: Configure ZAI API key
Write-Step "5/7: Configuring ZAI API key for GLM-4.7"

$zaiKey = "896fb1e6936a4cd1b61aa2314d6d3728.u2lsAqLNfajAslfx"

# Check for existing config in different locations
$possiblePaths = @(
    "$env:USERPROFILE\.openclaw\agents\main\agent",
    "$env:USERPROFILE\.clawdbot\agents\main\agent",
    "C:\windows\system32\config\systemprofile\.openclaw\agents\main\agent",
    "C:\windows\system32\config\systemprofile\.clawdbot\agents\main\agent"
)

$authFile = $null
foreach ($path in $possiblePaths) {
    if (Test-Path "$path\auth-profiles.json") {
        $authFile = "$path\auth-profiles.json"
        Write-Info "Found existing auth file: $authFile"
        break
    }
}

if (-not $authFile) {
    # Create new config in user profile
    $configDir = "$env:USERPROFILE\.openclaw\agents\main\agent"
    New-Item -ItemType Directory -Force -Path $configDir | Out-Null
    $authFile = "$configDir\auth-profiles.json"
}

# Backup existing file
if (Test-Path $authFile) {
    $backupPath = "$authFile.backup"
    Copy-Item $authFile $backupPath -Force
    Write-Info "Backed up existing auth file to: $backupPath"
}

# Create new auth config
$authConfig = @{
    profiles = @{
        "zai:default" = @{
            type = "api_key"
            provider = "zai"
            key = $zaiKey
        }
    }
}

$authConfig | ConvertTo-Json -Depth 10 | Out-File -FilePath $authFile -Encoding utf8
Write-Success "ZAI API key configured"

# Step 6: Run onboarding
Write-Step "6/7: Running OpenClaw onboarding"
Write-Info "This will open the configuration wizard..."
Write-Info "(Press Ctrl+C to skip onboarding if you want to configure manually)"
& openclaw onboard --install-daemon

# Step 7: Show status
Write-Step "7/7: Checking OpenClaw status"
& openclaw status

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Setup Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "`nNext steps:" -ForegroundColor Green
Write-Info "1. Check status: openclaw status"
Write-Info "2. Run doctor: openclaw doctor"
Write-Info "3. Open dashboard: openclaw dashboard"
Write-Info "4. View logs: openclaw logs --follow"
Write-Host "`nGateway ports:" -ForegroundColor Yellow
Write-Info "Primary: 18789"
Write-Info "Workstation: 18791"
Write-Host "`nZAI API Key configured:" -ForegroundColor Yellow
Write-Info "$zaiKey"
Write-Host "`nConfig file:" -ForegroundColor Yellow
Write-Info "$authFile"
Write-Host "`n"

pause
