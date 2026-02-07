# ===============================================
# Claude Flow V3 Configuration
# ===============================================
# Added: 2026-02-03
# Updated: 2026-02-04 - Non-blocking version with timeout protection
# Using claude-flow@v3alpha (v3.0.0-alpha.190) with Node.js v24.13.0

# Set timeout for commands to prevent hanging
export CLAUDE_FLOW_CMD_TIMEOUT=10

# Wrapper function with timeout protection
_npx_safe() {
	timeout ${CLAUDE_FLOW_CMD_TIMEOUT} npx "$@" 2>/dev/null || return $?
}

# V3 Version Configuration
export CLAUDE_FLOW_VERSION="3.0.0-alpha.190"
export CLAUDE_FLOW_CMD="npx claude-flow@${CLAUDE_FLOW_VERSION}"

# Node.js v24 PATH (check if exists before adding)
if [[ -d "$HOME/.nvm/versions/node/v24.13.0" ]]; then
	export PATH="$HOME/.nvm/versions/node/v24.13.0/bin:$PATH"
fi

# ────────────────────────────────────────────────
# Claude Flow V3 Environment Variables (Updated for V3)
# ────────────────────────────────────────────────

# Core Configuration
export CLAUDE_FLOW_MAX_AGENTS=4
export CLAUDE_FLOW_MEMORY_SIZE=1GB
export CLAUDE_FLOW_ENABLE_NEURAL=true
export CLAUDE_FLOW_LOG_LEVEL="info"
export CLAUDE_FLOW_VERBOSE="false"

# Feature Toggles (V3)
export CLAUDE_FLOW_HOOKS_ENABLED="true"
export CLAUDE_FLOW_TELEMETRY_ENABLED="true"
export CLAUDE_FLOW_TRAINING_ENABLED="true"
export CLAUDE_FLOW_CACHING_ENABLED="true"
export CLAUDE_FLOW_PARALLEL_EXECUTION="true"

# Performance & Rate Limiting (V3)
export CLAUDE_FLOW_RATE_LIMITING="optional"
export CLAUDE_FLOW_MAX_RETRIES=3
export CLAUDE_FLOW_TIMEOUT=30
export CLAUDE_FLOW_BATCH_SIZE=5
export CLAUDE_FLOW_THROTTLE_MS=100

# Git Automation (V3)
export CLAUDE_FLOW_AUTO_COMMIT="true"
export CLAUDE_FLOW_AUTO_PUSH="true"
export CLAUDE_FLOW_COMMIT_PREFIX="chore"
export CLAUDE_FLOW_COMMIT_TEMPLATE="{{prefix}}: {{description}}"
export CLAUDE_FLOW_COMMIT_SIGN="false"
export CLAUDE_FLOW_COMMIT_VERIFY="true"

# GitHub Integration (V3)
export CLAUDE_FLOW_GITHUB_INTEGRATION="true"
export CLAUDE_FLOW_AUTO_RELEASE="false"
export CLAUDE_FLOW_PR_AUTO_APPROVE="false"
export CLAUDE_FLOW_BRANCH_PROTECTION="true"

# Workflow Automation (V3)
export CLAUDE_FLOW_AUTO_CHECKPOINT="true"
export CLAUDE_FLOW_CHECKPOINT_FREQUENCY="10"
export CLAUDE_FLOW_BACKUP_ENABLED="true"
export CLAUDE_FLOW_BACKUP_DIRECTORY="$HOME/.claude-flow/backups"

# Swarm & Agent Configuration (V3)
export CLAUDE_FLOW_DEFAULT_TOPOLOGY="adaptive"
export CLAUDE_FLOW_AGENT_TIMEOUT=60
export CLAUDE_FLOW_CONSENSUS_THRESHOLD=0.75
export CLAUDE_FLOW_SWARM_SIZE="auto"

# Memory & Storage (V3)
export CLAUDE_FLOW_MEMORY_RETENTION="30d"
export CLAUDE_FLOW_MEMORY_TYPE="hybrid"
export CLAUDE_FLOW_CACHE_DIR="$HOME/.claude-flow/cache"
export CLAUDE_FLOW_LOG_DIR="$HOME/.claude-flow/logs"

# API & Model Configuration (V3)
export CLAUDE_FLOW_API_RETRY_DELAY=1000
export CLAUDE_FLOW_API_MAX_TOKENS=4096
export CLAUDE_FLOW_MODEL_TEMPERATURE=0.7
export CLAUDE_FLOW_STREAMING="true"

# Security & Privacy (V3)
export CLAUDE_FLOW_SECURE_MODE="true"
export CLAUDE_FLOW_SANITIZE_LOGS="true"
export CLAUDE_FLOW_ENCRYPT_MEMORY="false"
export CLAUDE_FLOW_ALLOW_SHELL_EXEC="true"

# Notifications & Alerts (V3)
export CLAUDE_FLOW_NOTIFICATIONS="true"
export CLAUDE_FLOW_ALERT_ON_ERROR="true"
export CLAUDE_FLOW_SLACK_WEBHOOK=""
export CLAUDE_FLOW_DISCORD_WEBHOOK=""

# Advanced Features (V3)
export CLAUDE_FLOW_EXPERIMENTAL="true"
export CLAUDE_FLOW_DEBUG_MODE="false"
export CLAUDE_FLOW_PROFILING="false"
export CLAUDE_FLOW_METRICS_EXPORT="false"

# V3-Specific Variables
export CLAUDE_FLOW_DISABLE_WRITE_HOOKS=true
export CLAUDE_FLOW_DISABLE_FILE_OPERATIONS=true

# ===============================================
# Claude Flow V3 Aliases (using npx with version)
# ===============================================

# Core shortcuts (using $CLAUDE_FLOW_CMD variable)
alias cf="$CLAUDE_FLOW_CMD"
alias cfv="$CLAUDE_FLOW_CMD --version"
alias cfh="$CLAUDE_FLOW_CMD --help"

# Environment control
alias cf-dev='export CLAUDE_FLOW_DEBUG_MODE=true CLAUDE_FLOW_VERBOSE=true'
alias cf-prod='export CLAUDE_FLOW_DEBUG_MODE=false CLAUDE_FLOW_VERBOSE=false'
alias cf-safe='export CLAUDE_FLOW_AUTO_COMMIT=false CLAUDE_FLOW_AUTO_PUSH=false CLAUDE_FLOW_ALLOW_SHELL_EXEC=false'
alias cf-auto='export CLAUDE_FLOW_AUTO_COMMIT=true CLAUDE_FLOW_AUTO_PUSH=false'

# MCP Server
alias mcp-start='$CLAUDE_FLOW_CMD mcp start --tools all'
alias mcp-stop='$CLAUDE_FLOW_CMD mcp stop'
alias mcp-status='$CLAUDE_FLOW_CMD mcp status'
alias mcp-restart='$CLAUDE_FLOW_CMD mcp restart'
alias mcp-logs='$CLAUDE_FLOW_CMD mcp logs'
alias mcp-tools='$CLAUDE_FLOW_CMD mcp tools'

# Hive-Mind (Queen-led consensus coordination)
alias hive='$CLAUDE_FLOW_CMD hive-mind'
alias hive-init='$CLAUDE_FLOW_CMD hive-mind init'
alias hive-spawn='$CLAUDE_FLOW_CMD hive-mind spawn'
alias hive-status='$CLAUDE_FLOW_CMD hive-mind status'
alias hive-task='$CLAUDE_FLOW_CMD hive-mind task'
alias hive-shutdown='$CLAUDE_FLOW_CMD hive-mind shutdown'

# Agent Management
alias agent='$CLAUDE_FLOW_CMD agent'
alias agent-spawn='$CLAUDE_FLOW_CMD agent spawn'
alias agent-list='$CLAUDE_FLOW_CMD agent list'
alias agent-status='$CLAUDE_FLOW_CMD agent status'
alias agent-stop='$CLAUDE_FLOW_CMD agent stop'
alias agent-metrics='$CLAUDE_FLOW_CMD agent metrics'

# Swarm Coordination
alias swarm='$CLAUDE_FLOW_CMD swarm'
alias swarm-init='$CLAUDE_FLOW_CMD swarm init'
alias swarm-start='$CLAUDE_FLOW_CMD swarm start'
alias swarm-status='$CLAUDE_FLOW_CMD swarm status'
alias swarm-stop='$CLAUDE_FLOW_CMD swarm stop'
alias swarm-coord='$CLAUDE_FLOW_CMD swarm coordinate'

# Workflow & SPARC (V3)
alias workflow='$CLAUDE_FLOW_CMD workflow'
alias workflow-run='$CLAUDE_FLOW_CMD workflow run'
alias workflow-list='$CLAUDE_FLOW_CMD workflow list'
alias workflow-status='$CLAUDE_FLOW_CMD workflow status'

# SPARC Methodology (via workflow and agents in V3)
alias sparc-spec='$CLAUDE_FLOW_CMD agent spawn -t specification'
alias sparc-pseudo='$CLAUDE_FLOW_CMD agent spawn -t pseudocode'
alias sparc-arch='$CLAUDE_FLOW_CMD agent spawn -t architecture'
alias sparc-tdd='$CLAUDE_FLOW_CMD agent spawn -t sparc-coder'
alias sparc-test='$CLAUDE_FLOW_CMD agent spawn -t tester'

# Memory Management
alias memory='$CLAUDE_FLOW_CMD memory'
alias memory-search='$CLAUDE_FLOW_CMD memory search'

# Hooks
alias hooks='$CLAUDE_FLOW_CMD hooks'

# Neural Features (V3)
alias neural='$CLAUDE_FLOW_CMD neural'
alias neural-train='$CLAUDE_FLOW_CMD neural train'
alias neural-patterns='$CLAUDE_FLOW_CMD neural patterns'

# Task & Session Management (V3)
alias task='$CLAUDE_FLOW_CMD task'
alias session='$CLAUDE_FLOW_CMD session'

# Analysis & Performance (V3)
alias analyze='$CLAUDE_FLOW_CMD analyze'
alias perf='$CLAUDE_FLOW_CMD performance'
alias doctor='$CLAUDE_FLOW_CMD doctor'

# Config & Update (V3)
alias cf-config='$CLAUDE_FLOW_CMD config'
alias cf-update='$CLAUDE_FLOW_CMD update'
alias cf-migrate='$CLAUDE_FLOW_CMD migrate'

# ===============================================
# Quick Hive-Mind Commands (with --claude flag)
# ===============================================

# Quick hive-mind spawn with common objectives
alias hive-git='npx claude-flow@3.0.0-alpha.190 hive-mind spawn "add all, commit, push, pr and auto-approve" --claude'
alias hive-test='npx claude-flow@3.0.0-alpha.190 hive-mind spawn "run all tests and fix failures" --claude'
alias hive-lint='npx claude-flow@3.0.0-alpha.190 hive-mind spawn "run pint and fix all style issues" --claude'

# ===============================================
# End Claude Flow V3 Configuration
# ===============================================
