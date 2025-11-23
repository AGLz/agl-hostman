#!/bin/bash
# GitHub Secrets Configuration for Dokploy Deployment
# Using gh CLI for automated setup
#
# Usage:
#   ./scripts/configure-github-secrets.sh
#
# Prerequisites:
#   - gh CLI installed and authenticated
#   - Repository access (admin permissions)
#   - Dokploy applications created (agl-hostman-qa, agl-hostman-uat)

set -e

REPO="aguileraz/agl-hostman"

echo "🔐 Configurando GitHub Secrets para agl-hostman..."
echo ""

# ============================================================================
# CONFIGURATION SECTION - Update these URLs based on your Dokploy setup
# ============================================================================

# Dokploy Webhook URLs
# Format: https://dok.aglz.io/api/webhook/deploy/{application-name}
#
# To verify webhook URLs:
#   1. Login to https://dok.aglz.io
#   2. Navigate to each application (qa, uat, production)
#   3. Check Settings → Webhooks or Deployment section
#   4. Copy the webhook URL

WEBHOOK_QA="https://dok.aglz.io/api/webhook/deploy/agl-hostman-qa"
WEBHOOK_UAT="https://dok.aglz.io/api/webhook/deploy/agl-hostman-uat"
WEBHOOK_PROD="https://dok.aglz.io/api/webhook/deploy/agl-hostman-production"

# Health Check Endpoints
# Format: https://{subdomain}.aglz.io
# These endpoints will be called after deployment to verify application health

APP_URL_QA="https://agl-hostman-qa.aglz.io"
APP_URL_UAT="https://agl-hostman-uat.aglz.io"

# ============================================================================
# VALIDATION
# ============================================================================

echo "📋 Secrets a serem configurados:"
echo "  - DOKPLOY_WEBHOOK_URL_QA          = $WEBHOOK_QA"
echo "  - DOKPLOY_WEBHOOK_URL_UAT         = $WEBHOOK_UAT"
echo "  - DOKPLOY_WEBHOOK_URL_PRODUCTION  = $WEBHOOK_PROD"
echo "  - APP_URL_QA                      = $APP_URL_QA"
echo "  - APP_URL_UAT                     = $APP_URL_UAT"
echo ""

read -p "⚠️  Confirma os valores acima? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Configuração cancelada"
    echo "   Edite os valores no script antes de executar novamente"
    exit 1
fi

echo ""
echo "🔧 Configurando secrets..."
echo ""

# ============================================================================
# SECRET CONFIGURATION
# ============================================================================

# Function to set secret with error handling
set_secret() {
    local name=$1
    local value=$2

    echo -n "  Configurando $name... "
    if echo -n "$value" | gh secret set "$name" --repo "$REPO" 2>&1; then
        echo "✅"
        return 0
    else
        echo "❌"
        return 1
    fi
}

# Set each secret
set_secret "DOKPLOY_WEBHOOK_URL_QA" "$WEBHOOK_QA"
set_secret "DOKPLOY_WEBHOOK_URL_UAT" "$WEBHOOK_UAT"
set_secret "DOKPLOY_WEBHOOK_URL_PRODUCTION" "$WEBHOOK_PROD"
set_secret "APP_URL_QA" "$APP_URL_QA"
set_secret "APP_URL_UAT" "$APP_URL_UAT"

echo ""
echo "✅ Configuração completa!"
echo ""

# ============================================================================
# VERIFICATION
# ============================================================================

echo "🔍 Verificando secrets configurados:"
echo ""
gh secret list --repo "$REPO"

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "🎉 Secrets configurados com sucesso!"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "📋 Próximos passos:"
echo ""
echo "1️⃣  Testar deployment workflow:"
echo "   git commit --allow-empty -m \"test: validate deployment workflow with secrets\""
echo "   git push origin develop"
echo ""
echo "2️⃣  Monitorar execução:"
echo "   gh run watch"
echo ""
echo "3️⃣  Verificar health checks após deployment:"
echo "   curl -I $APP_URL_QA/health"
echo "   curl -I $APP_URL_UAT/health"
echo ""
echo "📚 Documentação completa: docs/GITHUB-SECRETS-SETUP.md"
echo "═══════════════════════════════════════════════════════════════════"
