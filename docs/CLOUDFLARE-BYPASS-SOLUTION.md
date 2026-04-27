# Cloudflare Bypass Solution for GitHub Actions Webhooks

## Problem Identified

**Workflow**: Build and Deploy (ID: 19604604303)
**Status**: Partial Success - Secrets Working, Cloudflare Blocking

### What's Working ✅
- GitHub secrets correctly configured via `gh` CLI
- Webhook URLs properly injected into deployment jobs
- curl executes successfully (no more "Malformed input to URL function")
- Build and image push to ghcr.io working perfectly

### What's Blocking ❌
Cloudflare is protecting Dokploy webhooks with JavaScript challenge:
```html
<title>Just a moment...</title>
Enable JavaScript and cookies to continue
```

**GitHub Actions can't solve JavaScript challenges** (headless environment, no browser).

## Solution Options

### Option 1: Cloudflare WAF Bypass Rule (RECOMMENDED)
**Configure Cloudflare to bypass GitHub Actions IPs**

```bash
# GitHub Actions IP Ranges (update from https://api.github.com/meta)
# 140.82.112.0/20
# 143.55.64.0/20
# 185.199.108.0/22
# 192.30.252.0/22
# etc.
```

**Steps**:
1. Login to Cloudflare dashboard
2. Navigate to: `dok.aglz.io` → Security → WAF → Custom Rules
3. Create rule: "GitHub Actions Webhook Bypass"
   - **Field**: IP Source Address
   - **Operator**: is in
   - **Value**: `140.82.112.0/20, 143.55.64.0/20, 185.199.108.0/22` (add all GitHub ranges)
   - **Path**: contains `/api/webhook/deploy`
   - **Action**: Skip → All remaining security checks

**Verification**:
```bash
curl -X POST "https://dok.aglz.io/api/webhook/deploy/agl-hostman-qa" \
  -H "Content-Type: application/json" \
  -d '{"test": true}'
```

---

### Option 2: API Token Authentication
**Add authentication to webhook URLs** (requires Dokploy configuration)

```bash
# Update secrets with token parameter
DOKPLOY_WEBHOOK_URL_QA="https://dok.aglz.io/api/webhook/deploy/agl-hostman-qa?token=SECRET_TOKEN"
```

**Pros**: More secure, token-based auth
**Cons**: Requires Dokploy API token support verification

---

### Option 3: Disable Cloudflare for /api/webhook/*
**Create Page Rule to disable Cloudflare for webhook endpoints**

1. Cloudflare Dashboard → `dok.aglz.io` → Rules → Page Rules
2. Create rule:
   - **URL**: `*dok.aglz.io/api/webhook/*`
   - **Settings**: Security Level → Essentially Off

**Pros**: Simple, immediate
**Cons**: Less secure (webhook endpoints exposed)

---

## Implementation Priority

1. ✅ **COMPLETED**: Configure GitHub secrets (automation script created)
2. ⏸️ **PENDING**: Implement Cloudflare bypass (Option 1 recommended)
3. ⏸️ **PENDING**: Re-test deployment workflow
4. ⏸️ **PENDING**: Validate health checks pass

## Technical Evidence

### Successful Webhook Execution (with Cloudflare block)
```log
deploy (qa)  Deploy to Dokploy via webhook  
  WEBHOOK_URL_QA: ***
  WEBHOOK_URL_UAT: ***
  
  curl -X POST "https://dok.aglz.io/api/webhook/deploy/agl-hostman-qa"
    -H "Content-Type: application/json"
    -d '{"image": "ghcr.io/aguileraz/agl-hostman:qa-823769e", "environment": "qa"}'
  
  100  7310    0  7191  100   119  90693   1500 --:--:-- --:--:-- --:--:-- 92531
```

**Status**: ✅ curl succeeded (HTTP request completed)
**Response**: Cloudflare challenge HTML (7191 bytes)

### Deploy Job Status
- **build (qa)**: ✅ success
- **build (uat)**: ✅ success  
- **deploy (qa) → webhook**: ✅ success
- **deploy (uat) → webhook**: ✅ success
- **deploy (qa) → health check**: ❌ failed (app not deployed)
- **deploy (uat) → health check**: ❌ failed (app not deployed)

## Next Actions

1. SSH to Dokploy server (CT180):
   ```bash
   ssh root@192.168.0.180
   ```

2. Check Dokploy webhook configuration:
   ```bash
   # Check if applications exist
   dokploy app list
   
   # Verify webhook endpoints
   curl -I http://localhost:3000/api/webhook/deploy/agl-hostman-qa
   ```

3. Implement Cloudflare bypass (Option 1)

4. Re-test deployment:
   ```bash
   git commit --allow-empty -m "test: retry deployment after Cloudflare bypass"
   git push origin develop
   ```

## References

- **GitHub Actions IP Ranges**: https://api.github.com/meta
- **Cloudflare WAF**: https://developers.cloudflare.com/waf/
- **Dokploy Webhooks**: https://dok.aglz.io/api/webhook/deploy/{app-name}

---

**Created**: 2025-11-23
**Status**: Secrets ✅ Working | Cloudflare ⏸️ Blocking | Deployment ⏸️ Pending

## GitHub Actions IP Ranges (Auto-Generated)

**Source**: https://api.github.com/meta (updated automatically)

```
$(curl -s https://api.github.com/meta | jq -r '.actions[]' | sort -u)
```

**For Cloudflare WAF Rule**: Copy all ranges above into IP list.

**Alternative**: Use Cloudflare Terraform/API to automate:
```hcl
# Cloudflare Terraform example
resource "cloudflare_firewall_rule" "github_actions_bypass" {
  zone_id     = var.zone_id
  description = "Bypass GitHub Actions for webhook endpoints"
  filter_id   = cloudflare_filter.github_actions.id
  action      = "allow"
  priority    = 1
}

resource "cloudflare_filter" "github_actions" {
  zone_id     = var.zone_id
  description = "GitHub Actions IPs + webhook path"
  expression  = "(ip.src in {140.82.112.0/20 143.55.64.0/20 185.199.108.0/22} and http.request.uri.path contains \"/api/webhook/deploy\")"
}
```

**Quick Test** (from CT179):
```bash
# Verify current Cloudflare block
curl -v https://dok.aglz.io/api/webhook/deploy/test 2>&1 | grep -i cloudflare

# After bypass rule configured
curl -X POST "https://dok.aglz.io/api/webhook/deploy/agl-hostman-qa" \
  -H "Content-Type: application/json" \
  -d '{"image": "test", "environment": "qa"}' \
  -w "\nHTTP Status: %{http_code}\n"
```
