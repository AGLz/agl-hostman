# ===============================================
# AGL PowerShell Profile - Instalador Windows 11
# ===============================================
# Instala e configura o perfil PowerShell com suporte a Claude Flow
# e múltiplos modelos de IA
# ===============================================

param(
    [switch]$Force,
    [switch]$Backup,
    [string]$AnthropicKey,
    [string]$OpenAIKey,
    [string]$GeminiKey
)

$ErrorActionPreference = "Stop"

# Definições de funções para output formatado
function Write-Success { param($msg) Write-Host "✓ $msg" -ForegroundColor Green }
function Write-ErrorMsg { param($msg) Write-Host "✗ $msg" -ForegroundColor Red }
function Write-Info { param($msg) Write-Host "ℹ $msg" -ForegroundColor Cyan }
function Write-Warning { param($msg) Write-Host "⚠ $msg" -ForegroundColor Yellow }

Write-Host "`n=== AGL PowerShell Profile Installer ===" -ForegroundColor Cyan
Write-Host "Installing Claude Flow configuration for Windows 11`n" -ForegroundColor White

# Verificar se está rodando como administrador
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Not running as Administrator. Some features may not work properly."
    Write-Info "Consider running: Start-Process powershell -Verb RunAs"
}

# Verificar PowerShell version
$psVersion = $PSVersionTable.PSVersion
Write-Info "PowerShell Version: $psVersion"
if ($psVersion.Major -lt 5) {
    Write-ErrorMsg "PowerShell 5.0 or higher is required"
    exit 1
}

# Localizar perfil PowerShell
$profilePath = $PROFILE.CurrentUserAllHosts
$profileDir = Split-Path -Parent $profilePath
Write-Info "Profile path: $profilePath"

# Criar diretório do perfil se não existir
if (-not (Test-Path $profileDir)) {
    Write-Info "Creating profile directory..."
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    Write-Success "Profile directory created"
}

# Backup do perfil existente
if ((Test-Path $profilePath) -and $Backup) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupPath = "$profilePath.backup.$timestamp"
    Write-Info "Creating backup of existing profile..."
    Copy-Item $profilePath $backupPath
    Write-Success "Backup created: $backupPath"
}

# Verificar se o perfil já existe
if ((Test-Path $profilePath) -and -not $Force) {
    Write-Warning "Profile already exists: $profilePath"
    $response = Read-Host "Overwrite? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Info "Installation cancelled"
        exit 0
    }
}

# Copiar perfil
$sourceProfile = Join-Path $PSScriptRoot "Microsoft.PowerShell_profile.ps1"
if (-not (Test-Path $sourceProfile)) {
    Write-ErrorMsg "Source profile not found: $sourceProfile"
    exit 1
}

Write-Info "Installing PowerShell profile..."
Copy-Item $sourceProfile $profilePath -Force
Write-Success "Profile installed"

# Configurar API keys se fornecidas
if ($AnthropicKey -or $OpenAIKey -or $GeminiKey) {
    Write-Info "Configuring API keys..."

    $content = Get-Content $profilePath -Raw

    if ($AnthropicKey) {
        $content = $content -replace '<YOUR_ANTHROPIC_API_KEY>', $AnthropicKey
        Write-Success "Anthropic API key configured"
    }

    if ($OpenAIKey) {
        $content = $content -replace '<YOUR_OPENAI_API_KEY>', $OpenAIKey
        Write-Success "OpenAI API key configured"
    }

    if ($GeminiKey) {
        $content = $content -replace '<YOUR_GOOGLE_API_KEY>', $GeminiKey
        Write-Success "Gemini API key configured"
    }
    
    Set-Content $profilePath $content -NoNewline
}

# Verificar Node.js
Write-Info "Checking Node.js installation..."
try {
    $nodeVersion = node --version 2>$null
    if ($nodeVersion) {
        Write-Success "Node.js installed: $nodeVersion"
    } else {
        Write-Warning "Node.js not found. Install from: https://nodejs.org/"
    }
} catch {
    Write-Warning "Node.js not found. Install from: https://nodejs.org/"
}

# Verificar pnpm
Write-Info "Checking pnpm installation..."
try {
    $pnpmVersion = pnpm --version 2>$null
    if ($pnpmVersion) {
        Write-Success "pnpm installed: $pnpmVersion"
    } else {
        Write-Warning "pnpm not found. Install with: npm install -g pnpm"
    }
} catch {
    Write-Warning "pnpm not found. Install with: npm install -g pnpm"
}

# Verificar Git
Write-Info "Checking Git installation..."
try {
    $gitVersion = git --version 2>$null
    if ($gitVersion) {
        Write-Success "Git installed: $gitVersion"
    } else {
        Write-Warning "Git not found. Install from: https://git-scm.com/"
    }
} catch {
    Write-Warning "Git not found. Install from: https://git-scm.com/"
}

# Criar diretórios do Claude Flow
Write-Info "Creating Claude Flow directories..."
$dirs = @(
    "$HOME\.claude-flow\cache",
    "$HOME\.claude-flow\logs",
    "$HOME\.claude-flow\backups"
)
foreach ($dir in $dirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}
Write-Success "Claude Flow directories created"

# Configurar ExecutionPolicy se necessário
$executionPolicy = Get-ExecutionPolicy -Scope CurrentUser
if ($executionPolicy -eq 'Restricted' -or $executionPolicy -eq 'Undefined') {
    Write-Warning "ExecutionPolicy is $executionPolicy"
    Write-Info "Setting ExecutionPolicy to RemoteSigned for CurrentUser..."
    try {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Write-Success "ExecutionPolicy updated"
    } catch {
        Write-Warning "Could not update ExecutionPolicy. Run manually: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser"
    }
}

# Resumo
Write-Host "`n=== Installation Complete ===" -ForegroundColor Green
Write-Host ""
Write-Success "PowerShell profile installed: $profilePath"
Write-Info "Reload profile: . `$PROFILE"
Write-Info "Or restart PowerShell"
Write-Host ""

# Próximos passos
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Configure API keys in profile (if not done):"
Write-Host "   - Edit: $profilePath"
Write-Host "   - Replace <YOUR_*_API_KEY> with your actual keys"
Write-Host ""
Write-Host "2. Install required tools (if missing):"
Write-Host "   - Node.js: https://nodejs.org/"
Write-Host "   - pnpm: npm install -g pnpm"
Write-Host "   - Git: https://git-scm.com/"
Write-Host ""
Write-Host "3. Test configuration:"
Write-Host "   - Reload profile: . `$PROFILE"
Write-Host "   - Check config: cf-check"
Write-Host "   - Test Claude Flow: claude-flow --version"
Write-Host ""

# Oferecer recarregar o perfil
$response = Read-Host "Reload profile now? (Y/n)"
if ($response -ne 'n' -and $response -ne 'N') {
    Write-Info "Reloading profile..."
    . $PROFILE
    Write-Success "Profile reloaded"
    Write-Host ""
    Write-Info "Run 'cf-check' to verify configuration"
}

Write-Host ""
