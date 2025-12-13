# Dokploy Environments & Secrets Setup

> **Date**: 2025-12-12
> **Status**: Environments Injected & Validated via DB

## ✅ Environments & Applications Validated

Everything is correctly set up in the Dokploy database (CT180).

| Environment | Application Name | Webhook URL | Token |
|-------------|------------------|-------------|-------|
| **Development** | `agl-hostman-dev` | `https://dok.aglz.io/api/webhook/deploy/agl-hostman-dev?token=token_dev_123456789` | `token_dev_123456789` |
| **QA** | `agl-hostman-qa` | `https://dok.aglz.io/api/webhook/deploy/agl-hostman-qa?token=token_qa_123456789` | `token_qa_123456789` |
| **UAT** | `agl-hostman-uat` | `https://dok.aglz.io/api/webhook/deploy/agl-hostman-uat?token=token_uat_123456789` | `token_uat_123456789` |
| **Production** | `agl-hostman-production` | `https://dok.aglz.io/api/webhook/deploy/agl-hostman-production?token=token_prod_123456789` | `token_prod_123456789` |

## 🚀 Final Steps (User Action Required)

### 1. Update ALL GitHub Secrets

Run these commands in your local terminal (where `gh` CLI works):

```powershell
# Development
gh secret set DOKPLOY_WEBHOOK_URL_DEV --body "https://dok.aglz.io/api/webhook/deploy/agl-hostman-dev?token=token_dev_123456789" --repo aguileraz/agl-hostman

# QA
gh secret set DOKPLOY_WEBHOOK_URL_QA --body "https://dok.aglz.io/api/webhook/deploy/agl-hostman-qa?token=token_qa_123456789" --repo aguileraz/agl-hostman

# UAT
gh secret set DOKPLOY_WEBHOOK_URL_UAT --body "https://dok.aglz.io/api/webhook/deploy/agl-hostman-uat?token=token_uat_123456789" --repo aguileraz/agl-hostman

# Production
gh secret set DOKPLOY_WEBHOOK_URL_PRODUCTION --body "https://dok.aglz.io/api/webhook/deploy/agl-hostman-production?token=token_prod_123456789" --repo aguileraz/agl-hostman
```

### 2. Cloudflare Bypass (One Rule for All)

Ensure your Cloudflare WAF rule covers all path variations:
- **Path contains**: `/api/webhook/deploy/`
- **Action**: Skip (WAF/Challenge)

### 3. Verify & Deploy

You can now use the `workflow_dispatch` in GitHub Actions to manually trigger a deploy to any environment, or push code to trigger the automatic flows.
