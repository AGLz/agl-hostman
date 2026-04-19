# Phase 4.1 Deployment Blockers

> **Date**: 2025-11-22 16:00 UTC
> **Status**: 🔴 **BLOCKED** - Critical Infrastructure Issues
> **Commits**: a2ce65a (workflow fix), 6225e0d (Phase 4.1 implementation)

---

## 🚨 Critical Blocker: Harbor Registry Not Accessible from GitHub Actions

### Issue Description
GitHub Actions workflows are failing to connect to Harbor registry at `harbor.aglz.io:5000`.

**Error Message**:
```
Error response from daemon: Get "https://harbor.aglz.io:5000/v2/":
net/http: request canceled while waiting for connection
(Client.Timeout exceeded while awaiting headers)
```

### Root Cause Analysis

#### DNS Configuration
```bash
$ host harbor.aglz.io
harbor.aglz.io has address 104.21.85.124      # Cloudflare proxy
harbor.aglz.io has address 172.67.205.182     # Cloudflare proxy
```

**Problem**: Harbor is behind Cloudflare proxy, but Cloudflare **does not proxy custom ports**.

#### Cloudflare Port Restrictions
Cloudflare only proxies these ports:
- HTTP: 80, 8080, 8880
- HTTPS: 443, 2053, 2083, 2087, 2096, 8443

**Port 5000 is NOT supported** → Connection times out from GitHub Actions runners.

### Impact

**Affected Workflows** (all failing due to Harbor timeout):
1. ✅ **build-and-deploy.yml** - Syntax fixed, but Harbor login fails (lines 64-69)
2. ❌ **integration-tests.yml** - Fixed deprecated action, no Harbor dependency
3. ⚠️ **deploy-staging.yml** - Uses Harbor (line 50)
4. ⚠️ **deploy-production.yml** - Uses Harbor
5. ⚠️ **deploy-uat.yml** - Uses Harbor

**Build Pipeline Status**:
- ✅ Syntax errors fixed (nested expressions resolved)
- ✅ Workflow structure validated
- 🔴 **Cannot push Docker images** to Harbor from GitHub Actions
- 🔴 **Cannot pull base images** from Harbor proxy cache

---

## 📋 Solutions (Ranked by Effort)

### Option 1: Use GitHub Container Registry (ghcr.io) - **RECOMMENDED**

**Effort**: Low (2-3 hours)
**Cost**: Free (included with GitHub)
**Public Access**: Yes
**Cache Performance**: Excellent (GitHub infrastructure)

**Changes Required**:
```yaml
# .github/workflows/build-and-deploy.yml
env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build:
    steps:
      - name: Login to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
```

**Advantages**:
- ✅ No infrastructure changes needed
- ✅ Automatic authentication with GITHUB_TOKEN
- ✅ Integrated with GitHub (same org/repo namespace)
- ✅ Free for public repos, generous limits for private
- ✅ Excellent CDN performance
- ✅ No DNS/Cloudflare issues

**Disadvantages**:
- ❌ Harbor proxy cache cannot be used for base images (Docker Hub cache)
- ⚠️ Need to configure Dokploy to pull from ghcr.io instead of Harbor

**Implementation Steps**:
1. Update `REGISTRY` environment variable in workflows
2. Replace Harbor login with GitHub Container Registry login
3. Update image tags from `harbor.aglz.io:5000/agl-hostman-*` to `ghcr.io/aguileraz/agl-hostman-*`
4. Configure Dokploy webhooks to pull from ghcr.io
5. Update Dokploy image pull credentials

---

### Option 2: Expose Harbor on Standard HTTPS Port (443) - **COMPLEX**

**Effort**: Medium-High (1-2 days)
**Cost**: None (uses existing infrastructure)
**Public Access**: Yes (through Cloudflare)

**Changes Required**:
1. **Reverse Proxy Setup** (on AGLSRV1 or dedicated proxy):
   ```nginx
   # Nginx config
   server {
       listen 443 ssl http2;
       server_name harbor.aglz.io;

       location / {
           proxy_pass http://192.168.0.245:5000;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
           proxy_set_header X-Forwarded-Proto $scheme;

           # Docker registry specific
           proxy_read_timeout 900;
           client_max_body_size 0;
       }
   }
   ```

2. **Harbor Configuration**:
   - Update `harbor.yml` to handle proxy headers
   - Configure external URL as https://harbor.aglz.io

3. **Cloudflare Settings**:
   - Ensure SSL/TLS mode is "Full" or "Full (strict)"
   - Enable WebSocket support (for Harbor UI)

**Advantages**:
- ✅ Keeps Harbor proxy cache functional
- ✅ Single registry for all environments
- ✅ Works with existing Harbor setup

**Disadvantages**:
- ❌ Requires reverse proxy setup and maintenance
- ❌ Additional point of failure
- ⚠️ Cloudflare caching may interfere with Docker registry operations
- ⚠️ Large image pushes may hit Cloudflare timeouts/limits

---

### Option 3: Dual Registry Setup - **HYBRID APPROACH**

**Effort**: Medium (4-6 hours)
**Cost**: None
**Public Access**: Partial

**Strategy**:
- **GitHub Actions** → Use ghcr.io (public builds)
- **Internal Deployments** → Use Harbor (local network)
- **Harbor Proxy Cache** → Keep for development/testing

**Changes Required**:
1. Workflows use ghcr.io for builds
2. Dokploy configured to pull from ghcr.io for QA/UAT
3. Harbor remains for:
   - Local development
   - Docker Hub proxy cache (saves bandwidth)
   - Internal image storage
   - Production deployments (if needed)

**Advantages**:
- ✅ Best of both worlds
- ✅ No loss of Harbor functionality
- ✅ GitHub Actions work immediately
- ✅ Harbor proxy cache still beneficial for dev environments

**Disadvantages**:
- ⚠️ More complex configuration (two registries)
- ⚠️ Need to manage credentials for both
- ⚠️ Image synchronization between registries (if needed)

---

## 🎯 Recommendation

**Implement Option 1 (ghcr.io) immediately** to unblock Phase 4.1 deployment, then evaluate Option 3 for long-term hybrid approach.

### Immediate Actions (Today - 22 Nov)
1. ✅ **Commit workflow syntax fixes** - DONE (commit a2ce65a)
2. ✅ **Fix upload-artifact deprecation** - DONE
3. 🔄 **Switch build-and-deploy.yml to ghcr.io** - IN PROGRESS
4. 🔄 **Test GitHub Actions build** - PENDING
5. 🔄 **Update Dokploy webhook** - PENDING

### Short-term (Week 1: 25-29 Nov)
- Validate ghcr.io builds complete successfully
- Update all deployment workflows (staging, UAT, production)
- Configure Dokploy to pull from ghcr.io
- Update Phase 4.1 documentation with ghcr.io setup

### Long-term (Week 2-4: Dec 2-13)
- Evaluate Harbor proxy setup on port 443
- Implement dual-registry approach if beneficial
- Document Harbor proxy cache usage for development

---

## ⚠️ Other Blockers

### 1. Missing GitHub Secrets

**Required but not configured**:
- `DOKPLOY_WEBHOOK_URL_QA` ← deployment webhook
- `DOKPLOY_WEBHOOK_URL_UAT` ← deployment webhook
- `APP_URL_QA` ← health check endpoint
- `APP_URL_UAT` ← health check endpoint

**Current secrets**:
- ✅ `HARBOR_USERNAME`
- ✅ `HARBOR_PASSWORD`

**Impact**: Deployment step will fail even if build succeeds

**Solution**: Add missing secrets to GitHub repository settings
```bash
# GitHub Settings → Secrets and variables → Actions → New repository secret

DOKPLOY_WEBHOOK_URL_QA=https://dok.aglz.io/api/webhook/deploy/agl-hostman-qa
DOKPLOY_WEBHOOK_URL_UAT=https://dok.aglz.io/api/webhook/deploy/agl-hostman-uat
APP_URL_QA=https://agl-hostman-qa.aglz.io
APP_URL_UAT=https://agl-hostman-uat.aglz.io
```

---

### 2. Harbor Proxy Cache Setup

**Status**: Manual setup required (Docker Hub token creation)

**From Phase 4.1 Deployment Checklist**:
- Step 1: Create Docker Hub access token (manual)
- Step 2: Configure Harbor endpoint (UI)
- Step 3: Create proxy project (UI)
- Step 4: Verify setup (test pull)

**Impact**: Cannot benefit from proxy cache until configured

**Priority**: Medium (nice-to-have, not blocking)

---

## 📊 Current Workflow Status

| Workflow | Syntax | Harbor Access | Secrets | Status |
|----------|--------|---------------|---------|--------|
| build-and-deploy.yml | ✅ Fixed | 🔴 Timeout | ⚠️ Partial | 🔴 BLOCKED |
| integration-tests.yml | ✅ Fixed | ✅ N/A | ✅ N/A | ✅ WORKING |
| deploy-staging.yml | ✅ OK | 🔴 Timeout | ⚠️ Missing | 🔴 BLOCKED |
| deploy-production.yml | ❓ Unknown | 🔴 Timeout | ⚠️ Missing | 🔴 BLOCKED |
| deploy-uat.yml | ❓ Unknown | 🔴 Timeout | ⚠️ Missing | 🔴 BLOCKED |
| tests.yml | ❓ Unknown | ✅ N/A | ✅ N/A | ❓ Unknown |
| code-quality.yml | ❓ Unknown | ✅ N/A | ✅ N/A | ❓ Unknown |

---

## 🎯 Success Criteria (Revised)

**To unblock Phase 4.1**:
- ✅ Workflow syntax errors fixed (nested expressions)
- 🔄 Registry access working (ghcr.io migration)
- 🔄 All GitHub secrets configured
- ✅ Deprecated actions upgraded (upload-artifact@v4)
- 🔄 At least one successful build + deploy

**Original Phase 4.1 Targets** (delayed until registry fixed):
- Build time: 600s → 150s (75% reduction)
- Cache hit rate: >80%
- Layer reuse: >90%

---

## 📝 Related Documentation

- **Phase 4.1 Implementation**: `PHASE4.1-IMPLEMENTATION-SUMMARY.md`
- **Phase 4.1 Deployment Checklist**: `PHASE4.1-DEPLOYMENT-CHECKLIST.md`
- **Harbor Setup Guide**: `HARBOR-PROXY-SETUP.md`
- **Build Optimization Guide**: `BUILD-OPTIMIZATION-GUIDE.md`
- **Docker Cache Strategies**: `DOCKER-CACHE-STRATEGIES.md`

---

**Document Version**: 1.0.0
**Last Updated**: 2025-11-22 16:00 UTC
**Next Review**: After ghcr.io migration
**Responsible**: Claude Code + Infrastructure Team
