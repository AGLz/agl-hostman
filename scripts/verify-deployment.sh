#!/bin/bash
# Deployment Verification Script
# Usage: ./scripts/verify-deployment.sh [qa|uat|production]

set -e

ENVIRONMENT="${1:-qa}"
REPO="aguileraz/agl-hostman"

echo "🔍 Deployment Verification for: $ENVIRONMENT"
echo "================================================"

# 1. Check GitHub Secrets
echo -e "\n1️⃣ Checking GitHub Secrets..."
gh secret list --repo "$REPO" | grep -E "(DOKPLOY_WEBHOOK|APP_URL)" || {
    echo "❌ Missing secrets!"
    exit 1
}
echo "✅ Secrets configured"

# 2. Check Latest Workflow Run
echo -e "\n2️⃣ Checking Latest Workflow..."
LATEST_RUN=$(gh run list --repo "$REPO" --workflow "build-and-deploy.yml" --limit 1 --json databaseId,status,conclusion --jq '.[0]')
RUN_ID=$(echo "$LATEST_RUN" | jq -r '.databaseId')
STATUS=$(echo "$LATEST_RUN" | jq -r '.status')
CONCLUSION=$(echo "$LATEST_RUN" | jq -r '.conclusion')

echo "  Run ID: $RUN_ID"
echo "  Status: $STATUS"
echo "  Conclusion: $CONCLUSION"

# 3. Test Webhook (Local - bypasses Cloudflare)
echo -e "\n3️⃣ Testing Webhook Locally (CT180)..."
ssh root@192.168.0.180 "curl -X POST http://localhost:3000/api/webhook/deploy/agl-hostman-${ENVIRONMENT} \
    -H 'Content-Type: application/json' \
    -d '{\"test\": true, \"environment\": \"${ENVIRONMENT}\"}' \
    -w '\nHTTP: %{http_code}\n' \
    -s" | head -20

# 4. Test Cloudflare Bypass (External - requires bypass configured)
echo -e "\n4️⃣ Testing Webhook via Cloudflare..."
WEBHOOK_RESPONSE=$(curl -X POST "https://dok.aglz.io/api/webhook/deploy/agl-hostman-${ENVIRONMENT}" \
    -H "Content-Type: application/json" \
    -d "{\"test\": true, \"environment\": \"${ENVIRONMENT}\"}" \
    -w "\n%{http_code}" \
    -s \
    --max-time 10 2>&1 || echo "timeout")

if echo "$WEBHOOK_RESPONSE" | grep -q "Just a moment"; then
    echo "❌ Cloudflare challenge detected - bypass NOT configured"
    echo "   Configure Cloudflare WAF rule before proceeding"
elif echo "$WEBHOOK_RESPONSE" | grep -E "^(200|201|202)$" > /dev/null; then
    echo "✅ Cloudflare bypass working - webhook reached Dokploy"
else
    echo "⚠️  Unexpected response: $WEBHOOK_RESPONSE"
fi

# 5. Check Application Health (if deployed)
echo -e "\n5️⃣ Checking Application Health..."
if [ "$ENVIRONMENT" = "qa" ]; then
    HEALTH_URL="https://agl-hostman-qa.aglz.io/health"
elif [ "$ENVIRONMENT" = "uat" ]; then
    HEALTH_URL="https://agl-hostman-uat.aglz.io/health"
elif [ "$ENVIRONMENT" = "production" ]; then
    HEALTH_URL="https://hostman.aglz.io/health"
fi

HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_URL" --max-time 10 2>/dev/null || echo "000")
if [ "$HEALTH_STATUS" = "200" ]; then
    echo "✅ Application healthy: $HEALTH_URL"
elif [ "$HEALTH_STATUS" = "000" ]; then
    echo "⏸️  Application not accessible (may not be deployed yet)"
else
    echo "❌ Health check failed: HTTP $HEALTH_STATUS"
fi

# Summary
echo -e "\n📊 Verification Summary"
echo "================================================"
echo "Environment: $ENVIRONMENT"
echo "GitHub Secrets: ✅"
echo "Webhook (Local): Check output above"
echo "Webhook (Cloudflare): Check output above"
echo "Application Health: HTTP $HEALTH_STATUS"
echo ""
echo "Next Steps:"
echo "  1. If Cloudflare challenge detected: Configure WAF bypass"
echo "  2. After bypass configured: Re-run deployment workflow"
echo "  3. Monitor: gh run watch --repo $REPO"
