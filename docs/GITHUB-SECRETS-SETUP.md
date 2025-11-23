# GitHub Secrets Configuration Guide

> **Project**: agl-hostman
> **Purpose**: Configure deployment webhooks and health check endpoints
> **Last Updated**: 2025-11-22

---

## 🎯 Overview

This guide configures GitHub repository secrets required for the **deployment workflow** in Phase 4.1. After fixing all build blockers, the deployment step now requires webhook URLs and health check endpoints.

**Status**: Build succeeds ✅, Deployment blocked ⏸️ (missing secrets)

---

## 🔐 Required Secrets

### **Dokploy Webhook URLs**

These webhooks trigger deployments on Dokploy (CT180) when images are pushed to ghcr.io:

```bash
DOKPLOY_WEBHOOK_URL_QA
DOKPLOY_WEBHOOK_URL_UAT
DOKPLOY_WEBHOOK_URL_PRODUCTION
```

**Format**:
```
https://dok.aglz.io/api/webhook/deploy/{application-name}
```

**Expected Values**:
```bash
DOKPLOY_WEBHOOK_URL_QA=https://dok.aglz.io/api/webhook/deploy/agl-hostman-qa
DOKPLOY_WEBHOOK_URL_UAT=https://dok.aglz.io/api/webhook/deploy/agl-hostman-uat
DOKPLOY_WEBHOOK_URL_PRODUCTION=https://dok.aglz.io/api/webhook/deploy/agl-hostman-production
```

### **Health Check Endpoints**

These endpoints verify successful deployment after webhook triggers:

```bash
APP_URL_QA
APP_URL_UAT
```

**Expected Values**:
```bash
APP_URL_QA=https://agl-hostman-qa.aglz.io
APP_URL_UAT=https://agl-hostman-uat.aglz.io
```

**Note**: Production URL is hardcoded in workflow (https://hostman.aglz.io)

---

## 📋 Configuration Steps

### **Step 1: Access Repository Secrets**

1. Navigate to GitHub repository: https://github.com/aguileraz/agl-hostman
2. Go to: **Settings** → **Secrets and variables** → **Actions**
3. You should see existing secrets:
   - ✅ `HARBOR_USERNAME`
   - ✅ `HARBOR_PASSWORD`
   - ⚠️ Missing: Dokploy webhooks and health check URLs

### **Step 2: Verify Dokploy Application Names**

Before adding secrets, verify the application names in Dokploy:

```bash
# SSH to Dokploy host
ssh root@192.168.0.180  # CT180 LAN
# or
ssh root@10.6.0.20      # CT180 WireGuard

# Check Dokploy applications (if API available)
curl -H "Authorization: Bearer $DOKPLOY_API_KEY" \
  https://dok.aglz.io/api/applications | jq '.[] | {name, id}'
```

**Alternative**: Access Dokploy Web UI
- URL: https://dok.aglz.io
- Navigate to: Applications → Find agl-hostman-qa, agl-hostman-uat
- Note the exact application names

### **Step 3: Get Webhook URLs from Dokploy**

**Option A: Dokploy Web UI**
1. Login to: https://dok.aglz.io
2. Select application: `agl-hostman-qa`
3. Go to: **Settings** → **Webhooks** or **Deployment**
4. Look for "Webhook URL" or "Deploy Webhook"
5. Copy the URL
6. Repeat for `agl-hostman-uat`

**Option B: API Request** (if available):
```bash
# List webhooks for application
curl -H "Authorization: Bearer $DOKPLOY_API_KEY" \
  https://dok.aglz.io/api/applications/{app-id}/webhooks
```

**Expected Format**:
```
https://dok.aglz.io/api/webhook/deploy/{application-name}
# OR
https://dok.aglz.io/webhook/{webhook-token}
```

### **Step 4: Add Secrets to GitHub**

For each secret:

1. Click: **"New repository secret"**
2. Enter secret details:
   - **Name**: `DOKPLOY_WEBHOOK_URL_QA`
   - **Secret**: `https://dok.aglz.io/api/webhook/deploy/agl-hostman-qa`
3. Click: **"Add secret"**
4. Repeat for all 5 secrets:
   - `DOKPLOY_WEBHOOK_URL_QA`
   - `DOKPLOY_WEBHOOK_URL_UAT`
   - `DOKPLOY_WEBHOOK_URL_PRODUCTION`
   - `APP_URL_QA`
   - `APP_URL_UAT`

### **Step 5: Verify Configuration**

After adding all secrets, verify in GitHub UI:

**Secrets and variables → Actions** should show:
```
✅ APP_URL_QA
✅ APP_URL_UAT
✅ DOKPLOY_WEBHOOK_URL_PRODUCTION
✅ DOKPLOY_WEBHOOK_URL_QA
✅ DOKPLOY_WEBHOOK_URL_UAT
✅ HARBOR_PASSWORD
✅ HARBOR_USERNAME
```

### **Step 6: Test Deployment Workflow**

Trigger a new build to test the deployment:

**Option A: Small Code Change**
```bash
# Make trivial change to trigger build
git commit --allow-empty -m "test: trigger deployment workflow after secrets config"
git push origin develop
```

**Option B: Re-run Failed Workflow**
```bash
# Re-run the failed deployment job
gh run rerun 19598631092
```

**Expected Result**:
- Build jobs succeed (already working)
- Deploy jobs succeed (now with webhook URLs)
- Health checks pass (verify applications running)

---

## 🔍 Verification & Troubleshooting

### **Check Workflow Execution**

```bash
# Monitor latest workflow
gh run watch

# Or view specific workflow
gh run view <run-id> --log
```

### **Expected Success Output**

**Deploy (QA) job**:
```bash
curl -X POST "https://dok.aglz.io/api/webhook/deploy/agl-hostman-qa" \
  -H "Content-Type: application/json" \
  -d '{
    "image": "ghcr.io/aguileraz/agl-hostman:qa-3ea651d",
    "environment": "qa"
  }'

# Expected response:
{"status": "success", "message": "Deployment triggered"}
```

**Health Check**:
```bash
# After 30s wait
curl https://agl-hostman-qa.aglz.io/health

# Expected response: 200 OK
{"status": "ok", "environment": "qa"}
```

### **Common Issues**

| Issue | Cause | Solution |
|-------|-------|----------|
| `curl: (3) URL rejected: Malformed input` | Secret not configured or empty | Add missing secret in GitHub |
| `404 Not Found` on webhook | Wrong application name | Verify Dokploy application name |
| `401 Unauthorized` on webhook | Webhook authentication required | Check if webhook needs auth token |
| Health check timeout | Application not deployed | Check Dokploy logs, verify image pull |
| Health check 502/503 | Application failed to start | Check Dokploy container logs |

### **Debug Commands**

```bash
# Check if webhook URL is accessible
curl -I https://dok.aglz.io/api/webhook/deploy/agl-hostman-qa

# Check if health endpoint exists
curl -I https://agl-hostman-qa.aglz.io/health

# SSH to Dokploy host and check containers
ssh root@192.168.0.180
docker ps | grep agl-hostman

# Check Dokploy logs
docker logs -f <dokploy-container-id>
```

---

## 📊 Workflow Integration

### **How Secrets Are Used**

**.github/workflows/build-and-deploy.yml** (lines 146-162):

```yaml
- name: Deploy to Dokploy via webhook
  env:
    WEBHOOK_URL_QA: ${{ secrets.DOKPLOY_WEBHOOK_URL_QA }}      # ← Used here
    WEBHOOK_URL_UAT: ${{ secrets.DOKPLOY_WEBHOOK_URL_UAT }}    # ← Used here
  run: |
    if [ "${{ matrix.environment }}" = "qa" ]; then
      WEBHOOK_URL="$WEBHOOK_URL_QA"
    elif [ "${{ matrix.environment }}" = "uat" ]; then
      WEBHOOK_URL="$WEBHOOK_URL_UAT"
    fi

    curl -X POST "$WEBHOOK_URL" \
      -H "Content-Type: application/json" \
      -d '{
        "image": "${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ matrix.environment }}-${{ github.sha }}",
        "environment": "${{ matrix.environment }}"
      }'
```

**.github/workflows/build-and-deploy.yml** (lines 164-183):

```yaml
- name: Verify deployment
  env:
    APP_URL_QA: ${{ secrets.APP_URL_QA }}      # ← Used here
    APP_URL_UAT: ${{ secrets.APP_URL_UAT }}    # ← Used here
  run: |
    sleep 30

    if [ "${{ matrix.environment }}" = "qa" ]; then
      HEALTH_URL="$APP_URL_QA/health"
    elif [ "${{ matrix.environment }}" = "uat" ]; then
      HEALTH_URL="$APP_URL_UAT/health"
    fi

    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_URL")
    if [ "$RESPONSE" = "200" ]; then
      echo "✅ Deployment successful - Health check passed"
    else
      echo "❌ Deployment failed - Health check returned $RESPONSE"
      exit 1
    fi
```

---

## 🎯 Success Criteria

After configuration, the complete workflow should:

1. ✅ **Build (QA)**: Docker image built and pushed to ghcr.io
2. ✅ **Build (UAT)**: Docker image built and pushed to ghcr.io
3. ✅ **Deploy (QA)**: Webhook triggers Dokploy deployment
4. ✅ **Deploy (UAT)**: Webhook triggers Dokploy deployment
5. ✅ **Health Check (QA)**: Returns 200 OK
6. ✅ **Health Check (UAT)**: Returns 200 OK

**Workflow Status**: All jobs should show "success" ✅

---

## 🔗 Related Documentation

- **Build Blockers Resolved**: `PHASE4.1-BUILD-BLOCKERS-RESOLVED.md`
- **Deployment Blockers**: `PHASE4.1-DEPLOYMENT-BLOCKERS.md`
- **Deployment Checklist**: `PHASE4.1-DEPLOYMENT-CHECKLIST.md`
- **Dokploy Integration**: `DOKPLOY.md`
- **Production Runbook**: `PRODUCTION-RUNBOOK.md`

---

## 📝 Notes

**Security Considerations**:
- Webhook URLs may contain authentication tokens (keep secret)
- Health check endpoints are public (no authentication required)
- Production deployment requires manual approval (GitHub environment protection)

**Alternative Deployment Methods**:
If webhooks don't work, Dokploy supports:
1. **Direct API calls** (requires API token)
2. **GitHub App integration** (requires app installation)
3. **Manual deployment** (Dokploy UI)

**Future Enhancements**:
- Add `DOKPLOY_API_KEY` secret for direct API deployments
- Configure GitHub environment protection rules
- Add deployment notifications (Slack/Discord webhooks)
- Implement blue-green deployment strategy

---

**Document Version**: 1.0.0
**Last Updated**: 2025-11-22
**Status**: Configuration pending
**Next Step**: Add 5 secrets to GitHub repository
