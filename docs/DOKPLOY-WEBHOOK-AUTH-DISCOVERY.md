# Dokploy Webhook Authentication Discovery

**Date**: 2025-11-23
**Discovery Context**: Phase 4.1 deployment preparation

## 🔍 Discovery

During Dokploy configuration verification (CT180), discovered that webhooks require authentication:

```bash
$ ssh root@192.168.0.180 'curl -X POST http://localhost:3000/api/webhook/deploy/agl-hostman-qa \
    -H "Content-Type: application/json" \
    -d "{\"test\": true}"'

{"message":"Unauthorized"}
HTTP Status: 401
```

## 📊 Dokploy Status (CT180)

**Containers**: All healthy ✅
```
dokploy-app          Up 35 hours
dokploy-postgres     Up 35 hours (healthy)
dokploy-redis        Up 35 hours (healthy)
dokploy-traefik      Up 35 hours
```

**API Health**: ✅ Responding
```bash
curl http://localhost:3000/api/health
HTTP 200
```

**Webhook Endpoint**: ❌ Requires Authentication
```bash
curl -X POST http://localhost:3000/api/webhook/deploy/{app-name}
HTTP 401 - {"message":"Unauthorized"}
```

## 🔐 Authentication Requirements

Dokploy webhooks are protected and require one of:

### Option 1: Webhook Secret/Token (Most Common)
Dokploy generates a secret token per application that must be included in webhook requests.

**Format**:
```bash
# URL with token parameter
https://dok.aglz.io/api/webhook/deploy/{app-name}?token={SECRET_TOKEN}

# OR Authorization header
curl -X POST https://dok.aglz.io/api/webhook/deploy/{app-name} \
  -H "Authorization: Bearer {SECRET_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"image": "..."}'
```

### Option 2: GitHub Webhook Secret
Dokploy validates GitHub webhook signatures using HMAC-SHA256.

**Format**:
```bash
curl -X POST https://dok.aglz.io/api/webhook/deploy/{app-name} \
  -H "X-Hub-Signature-256: sha256={HMAC_SIGNATURE}" \
  -H "Content-Type: application/json" \
  -d '{"image": "..."}'
```

## 📝 Action Items

### CRITICAL - Determine Correct Authentication Method

1. **Access Dokploy UI**: https://dok.aglz.io
   - Login with admin credentials
   - Navigate to each application (agl-hostman-qa, agl-hostman-uat, agl-hostman-production)
   - Find webhook configuration section
   - Copy webhook URL with authentication token

2. **Expected Format** (based on common Dokploy patterns):
   ```
   https://dok.aglz.io/api/webhook/deploy/agl-hostman-qa?token=ABC123XYZ...
   ```

3. **Update GitHub Secrets**:
   ```bash
   # Replace current URLs with authenticated URLs
   echo -n "https://dok.aglz.io/api/webhook/deploy/agl-hostman-qa?token=TOKEN_HERE" | \
     gh secret set DOKPLOY_WEBHOOK_URL_QA --repo aguileraz/agl-hostman

   echo -n "https://dok.aglz.io/api/webhook/deploy/agl-hostman-uat?token=TOKEN_HERE" | \
     gh secret set DOKPLOY_WEBHOOK_URL_UAT --repo aguileraz/agl-hostman

   echo -n "https://dok.aglz.io/api/webhook/deploy/agl-hostman-production?token=TOKEN_HERE" | \
     gh secret set DOKPLOY_WEBHOOK_URL_PRODUCTION --repo aguileraz/agl-hostman
   ```

4. **Verification** (after updating secrets):
   ```bash
   # Test from CT180 (local)
   ssh root@192.168.0.180 'curl -X POST "http://localhost:3000/api/webhook/deploy/agl-hostman-qa?token=TOKEN" \
     -H "Content-Type: application/json" \
     -d "{\"test\": true}"'

   # Should return: HTTP 200/201/202 (not 401)
   ```

## 🎯 Impact on Deployment

### Current Status
- ✅ GitHub secrets configured (but missing authentication tokens)
- ✅ Webhook URLs structured correctly
- ❌ **BLOCKER**: Webhooks return 401 Unauthorized
- ⏸️ **SECONDARY BLOCKER**: Cloudflare JavaScript challenge (after auth resolved)

### Updated Blocker Priority
1. **PRIMARY**: Dokploy webhook authentication tokens missing
2. **SECONDARY**: Cloudflare WAF bypass for GitHub Actions IPs

### Resolution Order
```
Step 1: Get Dokploy webhook tokens from UI
   ↓
Step 2: Update GitHub secrets with authenticated URLs
   ↓
Step 3: Configure Cloudflare WAF bypass
   ↓
Step 4: Re-trigger deployment workflow
   ↓
Step 5: Validate deployment success
```

## 📚 Documentation References

- **Dokploy UI**: https://dok.aglz.io (admin authentication required)
- **Webhook Configuration**: Application → Settings → Webhooks
- **GitHub Secrets**: Use `scripts/configure-github-secrets.sh` to update

## 🔄 Updated Workflow After Auth Resolution

```yaml
# .github/workflows/build-and-deploy.yml
- name: Deploy to Dokploy via webhook
  env:
    WEBHOOK_URL_QA: ${{ secrets.DOKPLOY_WEBHOOK_URL_QA }}  # Now includes ?token=...
  run: |
    curl -X POST "$WEBHOOK_URL_QA" \
      -H "Content-Type: application/json" \
      -d '{
        "image": "ghcr.io/aguileraz/agl-hostman:qa-...",
        "environment": "qa"
      }'
    # Expected: HTTP 200/201/202 (after Cloudflare bypass)
```

## 🚨 Next Steps Summary

**IMMEDIATE** (User Action Required):
1. Login to Dokploy UI: https://dok.aglz.io
2. Navigate to agl-hostman-qa → Settings → Webhooks
3. Copy full webhook URL (should include `?token=...`)
4. Repeat for agl-hostman-uat and agl-hostman-production
5. Update GitHub secrets with authenticated URLs

**THEN** (After authentication working):
1. Configure Cloudflare WAF bypass (see CLOUDFLARE-BYPASS-SOLUTION.md)
2. Re-trigger deployment workflow
3. Validate deployment success

---

**Status**: Authentication tokens required
**Blocker 1**: Dokploy webhook tokens missing (PRIMARY)
**Blocker 2**: Cloudflare JavaScript challenge (SECONDARY)
**Next**: User to retrieve tokens from Dokploy UI
