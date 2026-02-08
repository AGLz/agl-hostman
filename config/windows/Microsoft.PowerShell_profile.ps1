# ===============================================
# AGL PowerShell Profile - Windows 11
# ===============================================
# Baseado no .zshrc do agldv03 (CT179)
# Suporte a Claude Flow, multiplos modelos de IA e desenvolvimento
# Criado: 2025-01-24
# ===============================================

# ===============================================
# VARI??VEIS DE AMBIENTE - M??LTIPLOS MODELOS
# ===============================================

# Anthropic Claude
$env:ANTHROPIC_API_KEY = "<YOUR_ANTHROPIC_API_KEY>"

# OpenAI
$env:OPENAI_API_KEY = "<YOUR_OPENAI_API_KEY>"

# Google Gemini
$env:GOOGLE_API_KEY = "<YOUR_GOOGLE_API_KEY>"
$env:GEMINI_API_KEY = "<YOUR_GOOGLE_API_KEY>"

# ===============================================
# CLAUDE FLOW - CONFIGURA????O COMPLETA
# ===============================================

# Core Configuration
$env:CLAUDE_FLOW_MAX_AGENTS = "16"
$env:CLAUDE_FLOW_MEMORY_SIZE = "8192"
$env:CLAUDE_FLOW_NEURAL_FEATURES = "true"
$env:CLAUDE_FLOW_LOG_LEVEL = "info"
$env:CLAUDE_FLOW_VERBOSE = "false"

# Feature Toggles
$env:CLAUDE_FLOW_HOOKS_ENABLED = "true"
$env:CLAUDE_FLOW_TELEMETRY_ENABLED = "true"
$env:CLAUDE_FLOW_TRAINING_ENABLED = "true"
$env:CLAUDE_FLOW_CACHE_ENABLED = "true"
$env:CLAUDE_FLOW_PARALLEL_EXECUTION = "true"

# Performance & Rate Limiting
$env:CLAUDE_FLOW_RATE_LIMIT_ENABLED = "false"
$env:CLAUDE_FLOW_MAX_RETRIES = "3"
$env:CLAUDE_FLOW_TIMEOUT = "300"
$env:CLAUDE_FLOW_BATCH_SIZE = "10"
$env:CLAUDE_FLOW_THROTTLE_MS = "100"

# Git Automation
$env:CLAUDE_FLOW_AUTO_COMMIT = "true"
$env:CLAUDE_FLOW_AUTO_PUSH = "true"
$env:CLAUDE_FLOW_COMMIT_MESSAGE_PREFIX = "[claude-flow]"
$env:CLAUDE_FLOW_COMMIT_VERIFICATION = "true"
$env:CLAUDE_FLOW_AUTO_STAGE = "true"
$env:CLAUDE_FLOW_COMMIT_SIGN = "false"

# GitHub Integration
$env:CLAUDE_FLOW_GITHUB_ENABLED = "true"
$env:CLAUDE_FLOW_AUTO_RELEASE = "false"
$env:CLAUDE_FLOW_AUTO_PR_APPROVAL = "false"
$env:CLAUDE_FLOW_BRANCH_PROTECTION = "true"

# Workflow Automation
$env:CLAUDE_FLOW_CHECKPOINTS_ENABLED = "true"
$env:CLAUDE_FLOW_AUTO_CHECKPOINT = "true"
$env:CLAUDE_FLOW_BACKUP_ENABLED = "true"
$env:CLAUDE_FLOW_BACKUP_INTERVAL = "3600"

# Swarm & Agent Configuration
$env:CLAUDE_FLOW_SWARM_TOPOLOGY = "mesh"
$env:CLAUDE_FLOW_AGENT_TIMEOUT = "600"
$env:CLAUDE_FLOW_CONSENSUS_THRESHOLD = "0.7"
$env:CLAUDE_FLOW_MAX_SWARM_SIZE = "16"

# Memory & Storage
$env:CLAUDE_FLOW_MEMORY_RETENTION = "7d"
$env:CLAUDE_FLOW_MEMORY_TYPE = "persistent"
$env:CLAUDE_FLOW_CACHE_DIR = "$HOME\.claude-flow\cache"
$env:CLAUDE_FLOW_LOG_DIR = "$HOME\.claude-flow\logs"
$env:CLAUDE_FLOW_BACKUP_DIRECTORY = "$HOME\.claude-flow\backups"

# API & Model Configuration
$env:CLAUDE_FLOW_API_RETRY_DELAY = "1000"
$env:CLAUDE_FLOW_MAX_TOKENS = "4096"
$env:CLAUDE_FLOW_TEMPERATURE = "0.7"
$env:CLAUDE_FLOW_STREAMING = "true"

# Security & Privacy
$env:CLAUDE_FLOW_SECURE_MODE = "true"
$env:CLAUDE_FLOW_LOG_SANITIZATION = "true"
$env:CLAUDE_FLOW_ENCRYPTION_ENABLED = "true"
$env:CLAUDE_FLOW_ALLOW_SHELL_EXEC = "true"

# Notifications & Alerts
$env:CLAUDE_FLOW_NOTIFICATIONS_ENABLED = "false"
$env:CLAUDE_FLOW_ERROR_ALERTS = "true"
$env:CLAUDE_FLOW_WEBHOOK_URL = ""
$env:CLAUDE_FLOW_SLACK_WEBHOOK = ""

# Advanced Features
$env:CLAUDE_FLOW_EXPERIMENTAL = "false"
$env:CLAUDE_FLOW_DEBUG_MODE = "false"
$env:CLAUDE_FLOW_PROFILING = "false"
$env:CLAUDE_FLOW_METRICS_ENABLED = "true"

# ===============================================
# NODE.JS PERFORMANCE CONFIGURATION
# ===============================================

$env:NODE_ENV = "production"
$env:NODE_OPTIONS = "--max-old-space-size=8192"

# ===============================================
# FUNÇÕES DE CHAMADA DIRETA AOS MODELOS DE IA
# ===============================================

function ccz {
    param(
        [Parameter(Mandatory=$true, ValueFromRemainingArguments=$true)]
        [string[]]$Prompt
    )

    $promptText = $Prompt -join " "

    if (-not $env:ANTHROPIC_API_KEY -or $env:ANTHROPIC_API_KEY -eq "<YOUR_ANTHROPIC_API_KEY>") {
        Write-Host "[X] ANTHROPIC_API_KEY not configured!" -ForegroundColor Red
        Write-Host "Configure your API key in: $PROFILE" -ForegroundColor Yellow
        return
    }

    Write-Host "[i] Calling Claude (Anthropic)..." -ForegroundColor Cyan

    $headers = @{
        "x-api-key" = $env:ANTHROPIC_API_KEY
        "anthropic-version" = "2023-06-01"
        "content-type" = "application/json"
    }

    $body = @{
        model = "claude-3-5-sonnet-20241022"
        max_tokens = 4096
        messages = @(
            @{
                role = "user"
                content = $promptText
            }
        )
    } | ConvertTo-Json -Depth 10

    try {
        $response = Invoke-RestMethod -Uri "https://api.anthropic.com/v1/messages" `
            -Method Post `
            -Headers $headers `
            -Body $body

        Write-Host "`n=== Claude Response ===" -ForegroundColor Green
        Write-Host $response.content[0].text
        Write-Host "`n=== Tokens Used: $($response.usage.input_tokens + $response.usage.output_tokens) ===" -ForegroundColor Gray
    }
    catch {
        Write-Host "[X] Error calling Claude API: $_" -ForegroundColor Red
    }
}

function cccl {
    param(
        [Parameter(Mandatory=$true, ValueFromRemainingArguments=$true)]
        [string[]]$Prompt
    )

    $promptText = $Prompt -join " "

    if (-not $env:ANTHROPIC_API_KEY -or $env:ANTHROPIC_API_KEY -eq "<YOUR_ANTHROPIC_API_KEY>") {
        Write-Host "[X] ANTHROPIC_API_KEY not configured!" -ForegroundColor Red
        Write-Host "Configure your API key in: $PROFILE" -ForegroundColor Yellow
        return
    }

    Write-Host "[i] Calling Claude Code (Anthropic)..." -ForegroundColor Cyan

    $headers = @{
        "x-api-key" = $env:ANTHROPIC_API_KEY
        "anthropic-version" = "2023-06-01"
        "content-type" = "application/json"
    }

    $body = @{
        model = "claude-3-5-sonnet-20241022"
        max_tokens = 8192
        system = "You are an expert programmer. Provide code solutions with explanations."
        messages = @(
            @{
                role = "user"
                content = $promptText
            }
        )
    } | ConvertTo-Json -Depth 10

    try {
        $response = Invoke-RestMethod -Uri "https://api.anthropic.com/v1/messages" `
            -Method Post `
            -Headers $headers `
            -Body $body

        Write-Host "`n=== Claude Code Response ===" -ForegroundColor Green
        Write-Host $response.content[0].text
        Write-Host "`n=== Tokens Used: $($response.usage.input_tokens + $response.usage.output_tokens) ===" -ForegroundColor Gray
    }
    catch {
        Write-Host "[X] Error calling Claude API: $_" -ForegroundColor Red
    }
}

function gpt {
    param(
        [Parameter(Mandatory=$true, ValueFromRemainingArguments=$true)]
        [string[]]$Prompt
    )

    $promptText = $Prompt -join " "

    if (-not $env:OPENAI_API_KEY -or $env:OPENAI_API_KEY -eq "<YOUR_OPENAI_API_KEY>") {
        Write-Host "[X] OPENAI_API_KEY not configured!" -ForegroundColor Red
        Write-Host "Configure your API key in: $PROFILE" -ForegroundColor Yellow
        return
    }

    Write-Host "[i] Calling GPT-4 (OpenAI)..." -ForegroundColor Cyan

    $headers = @{
        "Authorization" = "Bearer $env:OPENAI_API_KEY"
        "Content-Type" = "application/json"
    }

    $body = @{
        model = "gpt-4-turbo-preview"
        messages = @(
            @{
                role = "user"
                content = $promptText
            }
        )
        max_tokens = 4096
        temperature = 0.7
    } | ConvertTo-Json -Depth 10

    try {
        $response = Invoke-RestMethod -Uri "https://api.openai.com/v1/chat/completions" `
            -Method Post `
            -Headers $headers `
            -Body $body

        Write-Host "`n=== GPT-4 Response ===" -ForegroundColor Green
        Write-Host $response.choices[0].message.content
        Write-Host "`n=== Tokens Used: $($response.usage.total_tokens) ===" -ForegroundColor Gray
    }
    catch {
        Write-Host "[X] Error calling OpenAI API: $_" -ForegroundColor Red
    }
}

function gemini {
    param(
        [Parameter(Mandatory=$true, ValueFromRemainingArguments=$true)]
        [string[]]$Prompt
    )

    $promptText = $Prompt -join " "

    if (-not $env:GOOGLE_API_KEY -or $env:GOOGLE_API_KEY -eq "<YOUR_GOOGLE_API_KEY>") {
        Write-Host "[X] GOOGLE_API_KEY not configured!" -ForegroundColor Red
        Write-Host "Configure your API key in: $PROFILE" -ForegroundColor Yellow
        return
    }

    Write-Host "[i] Calling Gemini Pro (Google)..." -ForegroundColor Cyan

    $body = @{
        contents = @(
            @{
                parts = @(
                    @{
                        text = $promptText
                    }
                )
            }
        )
    } | ConvertTo-Json -Depth 10

    try {
        $response = Invoke-RestMethod -Uri "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$env:GOOGLE_API_KEY" `
            -Method Post `
            -ContentType "application/json" `
            -Body $body

        Write-Host "`n=== Gemini Pro Response ===" -ForegroundColor Green
        Write-Host $response.candidates[0].content.parts[0].text
        Write-Host "`n=== Safety Ratings: $($response.candidates[0].safetyRatings.Count) checks passed ===" -ForegroundColor Gray
    }
    catch {
        Write-Host "[X] Error calling Gemini API: $_" -ForegroundColor Red
    }
}

function ai-compare {
    param(
        [Parameter(Mandatory=$true, ValueFromRemainingArguments=$true)]
        [string[]]$Prompt
    )

    $promptText = $Prompt -join " "

    Write-Host "`n========================================" -ForegroundColor Magenta
    Write-Host "AI MODEL COMPARISON" -ForegroundColor Magenta
    Write-Host "Prompt: $promptText" -ForegroundColor Magenta
    Write-Host "========================================`n" -ForegroundColor Magenta

    Write-Host "[1/3] Testing Claude..." -ForegroundColor Yellow
    ccz $promptText

    Write-Host "`n[2/3] Testing GPT-4..." -ForegroundColor Yellow
    gpt $promptText

    Write-Host "`n[3/3] Testing Gemini..." -ForegroundColor Yellow
    gemini $promptText

    Write-Host "`n========================================" -ForegroundColor Magenta
    Write-Host "COMPARISON COMPLETE" -ForegroundColor Magenta
    Write-Host "========================================`n" -ForegroundColor Magenta
}
$env:NODE_PRESERVE_SYMLINKS = "1"

# ===============================================
# PNPM CONFIGURATION
# ===============================================

$env:PNPM_HOME = "$HOME\.pnpm"
if (-not ($env:PATH -like "*$env:PNPM_HOME*")) {
    $env:PATH = "$env:PNPM_HOME;$env:PATH"
}

# ===============================================
# ALIASES - CLAUDE FLOW
# ===============================================

# Core Claude Flow Command
function claude-flow { npx -y claude-flow@v3alpha $args }
function claude-flow-v24 { npx -y claude-flow@v3alpha $args }
Set-Alias -Name cf -Value claude-flow

# Quick Control Aliases
function cf-dev {
    $env:CLAUDE_FLOW_DEBUG_MODE = "true"
    $env:CLAUDE_FLOW_VERBOSE = "true"
    $env:CLAUDE_FLOW_LOG_LEVEL = "debug"
    Write-Host "[OK]?? Claude Flow: Development mode enabled" -ForegroundColor Green
}

function cf-prod {
    $env:CLAUDE_FLOW_DEBUG_MODE = "false"
    $env:CLAUDE_FLOW_VERBOSE = "false"
    $env:CLAUDE_FLOW_LOG_LEVEL = "warn"
    Write-Host "[OK]?? Claude Flow: Production mode enabled" -ForegroundColor Green
}

function cf-safe {
    $env:CLAUDE_FLOW_AUTO_COMMIT = "false"
    $env:CLAUDE_FLOW_AUTO_PUSH = "false"
    $env:CLAUDE_FLOW_ALLOW_SHELL_EXEC = "false"
    Write-Host "[OK]?? Claude Flow: Safe mode enabled (no auto-commit/push/shell-exec)" -ForegroundColor Yellow
}

function cf-auto {
    $env:CLAUDE_FLOW_AUTO_COMMIT = "true"
    $env:CLAUDE_FLOW_AUTO_PUSH = "false"
    Write-Host "[OK]?? Claude Flow: Auto-commit enabled (no auto-push)" -ForegroundColor Green
}

# ===============================================
# HIVE-MIND ALIASES
# ===============================================

function hive {
    param([Parameter(ValueFromRemainingArguments=$true)]$command)
    npx -y claude-flow@v3alpha hive-mind spawn "$command" --claude
}

function hive-quick {
    param([Parameter(ValueFromRemainingArguments=$true)]$command)
    npx -y claude-flow@v3alpha hive-mind spawn "$command" --claude
}

function hive-manual {
    param([Parameter(ValueFromRemainingArguments=$true)]$command)
    npx -y claude-flow@v3alpha hive-mind spawn "$command" --claude --verbose
}

function hive-seq {
    param([Parameter(ValueFromRemainingArguments=$true)]$command)
    npx -y claude-flow@v3alpha hive-mind spawn "$command" --auto-spawn --claude --verbose
}

# Utility aliases
function hive-help { claude-flow hive-mind --help }
function hive-status { claude-flow hive-mind status }
function hive-agents { claude-flow hive-mind list-agents }

# ===============================================
# SPARC ALIASES
# ===============================================

function sparc-modes { claude-flow sparc modes }
function sparc-run { claude-flow sparc run $args }
function sparc-tdd { claude-flow sparc tdd $args }

# ===============================================
# ALIASES - DESENVOLVIMENTO
# ===============================================

# NPM/PNPM
Set-Alias -Name npm -Value pnpm

# Node.js Performance
function node-perf {
    $env:NODE_OPTIONS = "--max-old-space-size=8192 --trace-gc"
    Write-Host "[OK] Node.js: Performance mode enabled (8GB heap, GC tracing)" -ForegroundColor Green
}

function node-trace {
    $env:NODE_OPTIONS = "--max-old-space-size=8192 --trace-warnings --trace-deprecation"
    Write-Host "[OK] Node.js: Trace mode enabled (warnings + deprecations)" -ForegroundColor Green
}

# Git shortcuts
function gs { git status $args }
function ga { git add $args }
function gc { git commit $args }
function gp { git push $args }
function gl { git log --oneline --graph --decorate $args }
function gd { git diff $args }

# ===============================================
# FUN????ES UTILIT??RIAS
# ===============================================

# Verificar configura??ao do Claude Flow
function cf-check {
    Write-Host "`n=== Claude Flow Configuration ===" -ForegroundColor Cyan
    Write-Host "Max Agents: $env:CLAUDE_FLOW_MAX_AGENTS"
    Write-Host "Memory Size: $env:CLAUDE_FLOW_MEMORY_SIZE MB"
    Write-Host "Neural Features: $env:CLAUDE_FLOW_NEURAL_FEATURES"
    Write-Host "Auto-Commit: $env:CLAUDE_FLOW_AUTO_COMMIT"
    Write-Host "Auto-Push: $env:CLAUDE_FLOW_AUTO_PUSH"
    Write-Host "Parallel Execution: $env:CLAUDE_FLOW_PARALLEL_EXECUTION"
    Write-Host "Log Level: $env:CLAUDE_FLOW_LOG_LEVEL"
    Write-Host "`n=== Node.js Configuration ===" -ForegroundColor Cyan
    Write-Host "NODE_ENV: $env:NODE_ENV"
    Write-Host "NODE_OPTIONS: $env:NODE_OPTIONS"
    Write-Host "`n=== API Keys Status ===" -ForegroundColor Cyan
    Write-Host "Anthropic: $(if ($env:ANTHROPIC_API_KEY -and $env:ANTHROPIC_API_KEY -ne '<YOUR_ANTHROPIC_API_KEY>') { '[OK] Configured' } else { '[X] Not configured' })"
    Write-Host "OpenAI: $(if ($env:OPENAI_API_KEY -and $env:OPENAI_API_KEY -ne '<YOUR_OPENAI_API_KEY>') { '[OK] Configured' } else { '[X] Not configured' })"
    Write-Host "Gemini: $(if ($env:GOOGLE_API_KEY -and $env:GOOGLE_API_KEY -ne '<YOUR_GOOGLE_API_KEY>') { '[OK] Configured' } else { '[X] Not configured' })"
    Write-Host "`n=== AI Model Commands ===" -ForegroundColor Cyan
    Write-Host "ccz 'prompt'        - Call Claude (Anthropic)"
    Write-Host "cccl 'prompt'       - Call Claude Code (Anthropic)"
    Write-Host "gpt 'prompt'        - Call GPT-4 (OpenAI)"
    Write-Host "gemini 'prompt'     - Call Gemini Pro (Google)"
    Write-Host "ai-compare 'prompt' - Compare all models"
    Write-Host ""
}

# Criar diretorios do Claude Flow
function cf-init-dirs {
    $dirs = @(
        "$HOME\.claude-flow\cache",
        "$HOME\.claude-flow\logs",
        "$HOME\.claude-flow\backups"
    )
    foreach ($dir in $dirs) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Host "[OK]?? Created: $dir" -ForegroundColor Green
        }
    }
    Write-Host "`n[OK]?? Claude Flow directories initialized" -ForegroundColor Green
}

# Limpar cache do Claude Flow
function cf-clean {
    $cacheDir = "$HOME\.claude-flow\cache"
    if (Test-Path $cacheDir) {
        Remove-Item -Path "$cacheDir\*" -Recurse -Force
        Write-Host "[OK]?? Claude Flow cache cleaned" -ForegroundColor Green
    } else {
        Write-Host "[OK]?? Cache directory not found" -ForegroundColor Yellow
    }
}

# ===============================================
# PROMPT CUSTOMIZATION
# ===============================================

function prompt {
    $location = Get-Location
    $gitBranch = ""
    
    if (Test-Path .git) {
        try {
            $branch = git rev-parse --abbrev-ref HEAD 2>$null
            if ($branch) {
                $gitBranch = " ($branch)"
            }
        } catch {}
    }
    
    Write-Host "PS " -NoNewline -ForegroundColor Green
    Write-Host "$location" -NoNewline -ForegroundColor Cyan
    Write-Host "$gitBranch" -NoNewline -ForegroundColor Yellow
    Write-Host " >" -NoNewline -ForegroundColor Green
    return " "
}

# ===============================================
# INICIALIZA????O
# ===============================================

# Criar diret?rios do Claude Flow se n?o existirem
cf-init-dirs | Out-Null

# Mensagem de boas-vindas
Write-Host "`n=== AGL PowerShell Profile Loaded ===" -ForegroundColor Cyan
Write-Host "[OK] Claude Flow configured (v3alpha)" -ForegroundColor Green
Write-Host "[OK] Node.js optimized (8GB heap)" -ForegroundColor Green
Write-Host "[OK] Multiple AI models support" -ForegroundColor Green
Write-Host "`nQuick commands:" -ForegroundColor Yellow
Write-Host "  cf-check      - Check configuration"
Write-Host "  cf-dev        - Enable development mode"
Write-Host "  cf-safe       - Enable safe mode"
Write-Host "  hive 'task'   - Run hive-mind task"
Write-Host "  hive-help     - Show hive-mind help"
Write-Host ""

# ===============================================
# NOTAS
# ===============================================
# 
# Para configurar suas API keys:
# 1. Edite este arquivo: $PROFILE
# 2. Substitua <YOUR_*_API_KEY> pelas suas chaves reais
# 3. Recarregue o perfil: . $PROFILE
#
# Ou configure via vari?veis de ambiente do sistema:
# - ANTHROPIC_API_KEY
# - OPENAI_API_KEY
# - GOOGLE_API_KEY
#
# ===============================================

