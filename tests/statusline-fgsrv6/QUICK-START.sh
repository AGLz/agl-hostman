#!/bin/bash
# Quick Start - One-Command Deployment
# Executes complete test and deployment workflow

set -e

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  Statusline FGSRV6 Deployment - Quick Start              ║"
echo "║  Target: root@192.168.1.131                              ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo

cd "$(dirname "$0")"

# Phase 1: Pre-Deployment
echo "🔍 Phase 1: Pre-Deployment Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if ./pre-deployment-checks.sh; then
    echo "✅ Pre-deployment checks passed"
else
    echo "❌ Pre-deployment checks failed - ABORTING"
    exit 1
fi
echo

# Phase 2: Deployment
echo "🚀 Phase 2: Deployment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if ./deploy-and-test.sh; then
    echo "✅ Deployment successful"
else
    echo "❌ Deployment failed - Running rollback..."
    ./rollback-procedure.sh
    exit 1
fi
echo

# Phase 3: Validation
echo "✅ Phase 3: Post-Deployment Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if ./post-deployment-validation.sh; then
    echo "✅ Validation successful"
else
    echo "❌ Validation failed - Consider rollback"
    echo "Run: ./rollback-procedure.sh"
    exit 1
fi
echo

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  🎉 DEPLOYMENT COMPLETE AND VALIDATED                    ║"
echo "║                                                           ║"
echo "║  Next steps:                                             ║"
echo "║  1. Configure Claude Code on FGSRV6                      ║"
echo "║  2. Add: \"statuslineCommand\": \"/root/.claude/statusline-command.sh\" ║"
echo "║  3. Restart Claude Code or reload window                 ║"
echo "╚═══════════════════════════════════════════════════════════╝"

exit 0
