# Harbor Proxy Cache Configuration

**Last Updated:** 2025-11-27
**Phase:** 4.1 - Build Pipeline Optimization
**Harbor Instance:** harbor.aglz.io:5000

## Table of Contents

1. [Overview](#overview)
2. [Benefits](#benefits)
3. [Architecture](#architecture)
4. [Configuration Steps](#configuration-steps)
5. [Docker Hub Pull-Through Cache](#docker-hub-pull-through-cache)
6. [Other Registry Proxies](#other-registry-proxies)
7. [Client Configuration](#client-configuration)
8. [Retention Policies](#retention-policies)
9. [Cache Warming](#cache-warming)
10. [Monitoring](#monitoring)
11. [Troubleshooting](#troubleshooting)

---

## Overview

Harbor proxy cache acts as a pull-through cache for Docker registries (Docker Hub, Quay.io, etc.). Instead of pulling images directly from upstream registries, clients pull through Harbor, which caches the layers locally for faster subsequent pulls.

### Key Features

- **Reduced bandwidth usage:** Images cached locally after first pull
- **Faster builds:** No external network latency for cached images
- **Improved reliability:** Works even if upstream registry is down (for cached images)
- **Cost savings:** Reduces Docker Hub rate limit pressure
- **Better control:** Centralized image governance and scanning

---

## Benefits

### Performance Improvements

| Scenario | Without Cache | With Harbor Cache | Improvement |
|----------|---------------|-------------------|-------------|
| First pull (cold) | ~120s | ~120s | - |
| Subsequent pulls (warm) | ~120s | ~5-10s | **90-95%** |
| Multiple parallel builds | ~120s each | ~10s each | **90%+** |
| Docker Hub rate limited | ❌ Failed | ✅ Cached | **100%** |

### Build Pipeline Impact

- **GitHub Actions:** Faster Docker layer pulls
- **Local Development:** Instant base image pulls
- **CI/CD:** Reduced build queue times
- **Team Workflow:** Consistent image versions

---

## Architecture

```
┌─────────────────┐
│ Docker Hub      │
│ (upstream)      │
└────────┬────────┘
         │
         │ First pull only
         ▼
┌─────────────────┐
│ Harbor Registry │
│ (proxy cache)   │◄──────────────┐
│ 10.6.0.20:5000  │               │
└────────┬────────┘               │
         │                         │
         │ All subsequent pulls    │
         ▼                         │
┌─────────────────┐               │
│ Client (Docker) │───────────────┘
│ Build Environment│
└─────────────────┘
```

### Cache Flow

1. **First Pull:** Client → Harbor → Docker Hub → Harbor → Client (cached)
2. **Subsequent Pulls:** Client → Harbor (from cache)
3. **Cache Miss:** Harbor checks upstream, caches, serves client

---

## Configuration Steps

### 1. Access Harbor Admin Console

```bash
# Navigate to Harbor web interface
https://harbor.aglz.io

# Login credentials
Username: admin
Password: <HARBOR_ADMIN_PASSWORD>
```

### 2. Create Proxy Cache Project

1. **Navigate to Projects** → Click "New Project"
2. **Fill in details:**
   - **Project Name:** `dockerhub-proxy`
   - **Access Level:** Public (for team access)
   - **Proxy Cache:** ✅ Enable
   - **Registry Endpoint:** Select or create Docker Hub endpoint

3. **Advanced Settings:**
   - **Storage Quota:** 100 GB (adjust based on needs)
   - **Immutable Tags:** Disabled (allow updates)

### 3. Configure Registry Endpoint

If Docker Hub endpoint doesn't exist:

1. **Navigate to Registries** → Click "New Endpoint"
2. **Fill in details:**
   - **Provider:** Docker Hub
   - **Name:** `dockerhub-official`
   - **Endpoint URL:** `https://hub.docker.com`
   - **Access ID:** Your Docker Hub username (for rate limits)
   - **Access Secret:** Docker Hub access token
   - **Verify Remote Certificate:** ✅ Enable

3. **Test Connection** → Should return green checkmark

### 4. Link Endpoint to Project

1. **Back to Project** → `dockerhub-proxy`
2. **Configuration** → **Registry**
3. **Select Endpoint:** `dockerhub-official`
4. **Save**

---

## Docker Hub Pull-Through Cache

### Usage Example

Instead of pulling from Docker Hub directly:

```dockerfile
# Before (direct from Docker Hub)
FROM php:8.4-fpm-alpine

# After (via Harbor proxy cache)
FROM harbor.aglz.io:5000/dockerhub-proxy/library/php:8.4-fpm-alpine
```

### Format Breakdown

```
harbor.aglz.io:5000/dockerhub-proxy/[namespace]/[image]:[tag]
│                   │               │          │        │
│                   │               │          │        └─ Image tag
│                   │               │          └────────── Image name
│                   │               └───────────────────── Docker Hub namespace
│                   └───────────────────────────────────── Harbor project name
└───────────────────────────────────────────────────────── Harbor registry URL
```

### Common Namespace Mappings

| Docker Hub Image | Harbor Proxy Path |
|------------------|-------------------|
| `php:8.4-fpm-alpine` | `harbor.aglz.io:5000/dockerhub-proxy/library/php:8.4-fpm-alpine` |
| `node:20-alpine` | `harbor.aglz.io:5000/dockerhub-proxy/library/node:20-alpine` |
| `composer:2.7` | `harbor.aglz.io:5000/dockerhub-proxy/library/composer:2.7` |
| `nginx:alpine` | `harbor.aglz.io:5000/dockerhub-proxy/library/nginx:alpine` |
| `mysql:8.0` | `harbor.aglz.io:5000/dockerhub-proxy/library/mysql:8.0` |

**Note:** Official Docker images use the `library` namespace.

---

## Other Registry Proxies

### Quay.io Proxy

```bash
# Create new endpoint
Name: quay-official
Provider: Quay.io
URL: https://quay.io
```

**Usage:**
```dockerfile
FROM harbor.aglz.io:5000/quay-proxy/redhat/ubi8:latest
```

### GitHub Container Registry (GHCR) Proxy

```bash
# Create new endpoint
Name: ghcr-official
Provider: GitHub Container Registry
URL: https://ghcr.io
Access ID: GitHub username
Access Secret: GitHub PAT (with read:packages scope)
```

**Usage:**
```dockerfile
FROM harbor.aglz.io:5000/ghcr-proxy/organization/image:tag
```

### Private Registry Proxy

```bash
# Create new endpoint
Name: company-registry
Provider: Docker Registry
URL: https://registry.company.com
Credentials: As needed
```

---

## Client Configuration

### Docker Engine Configuration

Add Harbor as a mirror in `/etc/docker/daemon.json`:

```json
{
  "registry-mirrors": [
    "https://harbor.aglz.io:5000"
  ],
  "insecure-registries": [],
  "dns": ["8.8.8.8", "8.8.4.4"]
}
```

**Restart Docker:**
```bash
sudo systemctl restart docker
```

### Docker Compose Configuration

Update `docker-compose.yml` to use Harbor proxy:

```yaml
services:
  app:
    # Before
    # image: php:8.4-fpm-alpine

    # After
    image: harbor.aglz.io:5000/dockerhub-proxy/library/php:8.4-fpm-alpine
```

### Dockerfile Configuration

Update base images in Dockerfile:

```dockerfile
# Stage 1: PHP base
FROM harbor.aglz.io:5000/dockerhub-proxy/library/php:8.4-fpm-alpine AS php-base

# Stage 2: Node builder
FROM harbor.aglz.io:5000/dockerhub-proxy/library/node:20-alpine AS node-deps

# Stage 3: Composer
FROM harbor.aglz.io:5000/dockerhub-proxy/library/composer:2.7 AS composer-deps
```

### GitHub Actions Configuration

Update workflow to use Harbor proxy:

```yaml
jobs:
  build:
    steps:
      - name: Build with Harbor cache
        uses: docker/build-push-action@v5
        with:
          context: .
          file: ./Dockerfile
          # Harbor proxy images will be auto-cached
          build-args: |
            BASE_IMAGE_REGISTRY=harbor.aglz.io:5000/dockerhub-proxy/library
```

---

## Retention Policies

### Purpose

Retention policies automatically clean up old or unused images to free storage space.

### Recommended Policy

```yaml
Policy Name: cleanup-old-images
Rule Type: By Days Since Last Pull
Retention Days: 30
Exclude Tags: latest, stable, v*
Dry Run: Enabled (for testing)
```

### Configuration Steps

1. **Navigate to Project** → `dockerhub-proxy`
2. **Tag Retention** → Click "Add Rule"
3. **Fill in details:**
   - **Rule Name:** `cleanup-old-images`
   - **Retain:** Most recently pulled N images
   - **Count:** 10
   - **Tag Pattern:** `*` (all tags)
   - **Exclude Pattern:** `latest|stable|v.*`
   - **Dry Run:** Enabled

4. **Test with Dry Run:**
   ```bash
   # Review what would be deleted
   curl -u admin:password \
     https://harbor.aglz.io/api/v2.0/projects/dockerhub-proxy/tag_retention/executions
   ```

5. **Enable Policy:** Disable dry run if results look good

### Best Practices

- **Keep frequently used images:** Exclude production tags
- **Monitor storage usage:** Set up alerts at 80% capacity
- **Regular review:** Check policy effectiveness monthly
- **Team communication:** Notify before enabling aggressive policies

---

## Cache Warming

### Why Warm Cache?

Pre-populate Harbor cache with commonly used images to avoid cold starts.

### Manual Cache Warming

```bash
#!/bin/bash
# warm-cache.sh - Pre-populate Harbor proxy cache

HARBOR_REGISTRY="harbor.aglz.io:5000/dockerhub-proxy/library"

# Common base images
IMAGES=(
  "php:8.4-fpm-alpine"
  "php:8.3-fpm-alpine"
  "node:20-alpine"
  "node:18-alpine"
  "composer:2.7"
  "nginx:alpine"
  "mysql:8.0"
  "redis:alpine"
  "postgres:15-alpine"
)

for img in "${IMAGES[@]}"; do
  echo "Warming cache: $img"
  docker pull "${HARBOR_REGISTRY}/${img}"
done

echo "Cache warming complete!"
```

### Automated Cache Warming

Add to CI/CD pipeline:

```yaml
# .github/workflows/cache-warm.yml
name: Warm Harbor Cache

on:
  schedule:
    - cron: '0 2 * * 0'  # Weekly on Sunday at 2 AM
  workflow_dispatch:

jobs:
  warm-cache:
    runs-on: ubuntu-latest
    steps:
      - name: Login to Harbor
        uses: docker/login-action@v3
        with:
          registry: harbor.aglz.io:5000
          username: ${{ secrets.HARBOR_USERNAME }}
          password: ${{ secrets.HARBOR_PASSWORD }}

      - name: Pull common images
        run: |
          docker pull harbor.aglz.io:5000/dockerhub-proxy/library/php:8.4-fpm-alpine
          docker pull harbor.aglz.io:5000/dockerhub-proxy/library/node:20-alpine
          docker pull harbor.aglz.io:5000/dockerhub-proxy/library/composer:2.7
```

---

## Monitoring

### Harbor Dashboard Metrics

**Navigate to:** Harbor UI → Projects → `dockerhub-proxy` → Summary

**Key Metrics:**
- **Total Images:** Count of cached images
- **Total Storage:** Disk usage
- **Pull Count:** Number of image pulls
- **Push Count:** Number of cache writes

### API Monitoring

```bash
# Get project statistics
curl -u admin:password \
  https://harbor.aglz.io/api/v2.0/projects/dockerhub-proxy \
  | jq '.repo_count, .chart_count'

# Get storage usage
curl -u admin:password \
  https://harbor.aglz.io/api/v2.0/quotas \
  | jq '.[] | select(.ref.name=="dockerhub-proxy")'
```

### Performance Metrics

Track cache hit rate:

```bash
# Cache hits (served from Harbor)
CACHE_HITS=$(docker system events --filter 'type=image' --filter 'event=pull' \
  | grep -c 'harbor.aglz.io')

# Total pulls
TOTAL_PULLS=$(docker system events --filter 'type=image' --filter 'event=pull' \
  | wc -l)

# Hit rate percentage
echo "Cache hit rate: $((CACHE_HITS * 100 / TOTAL_PULLS))%"
```

### Alerting

Set up Prometheus alerts:

```yaml
# prometheus-alerts.yml
groups:
  - name: harbor-proxy-cache
    rules:
      - alert: HarborStorageHigh
        expr: harbor_project_quota_usage_bytes{project="dockerhub-proxy"} > 90GB
        for: 1h
        labels:
          severity: warning
        annotations:
          summary: "Harbor proxy cache storage above 90%"

      - alert: HarborCacheMissRate
        expr: rate(harbor_proxy_cache_miss_total[5m]) > 0.5
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: "Harbor cache miss rate above 50%"
```

---

## Troubleshooting

### Issue: Images Not Caching

**Symptoms:** Every pull goes to Docker Hub, not cached

**Diagnosis:**
```bash
# Check Harbor project configuration
curl -u admin:password \
  https://harbor.aglz.io/api/v2.0/projects/dockerhub-proxy \
  | jq '.metadata.proxy_cache'

# Should return: "true"
```

**Solutions:**
1. Verify proxy cache is enabled on project
2. Check endpoint connectivity
3. Ensure correct image path format
4. Review Harbor logs: `docker logs harbor-core`

### Issue: Authentication Failures

**Symptoms:** 401 Unauthorized when pulling

**Diagnosis:**
```bash
# Test credentials
docker login harbor.aglz.io:5000
Username: <user>
Password: <pass>

# Should return: "Login Succeeded"
```

**Solutions:**
1. Verify credentials are correct
2. Check user has access to proxy project
3. Ensure project is set to "Public" or user is member
4. Generate new access token if using automation

### Issue: Slow Cache Performance

**Symptoms:** Pulls from cache slower than expected

**Diagnosis:**
```bash
# Test network speed to Harbor
time docker pull harbor.aglz.io:5000/dockerhub-proxy/library/alpine:latest

# Compare with direct Docker Hub pull
time docker pull alpine:latest
```

**Solutions:**
1. Check Harbor server resources (CPU, RAM, disk I/O)
2. Verify network connectivity and bandwidth
3. Review storage backend performance
4. Consider upgrading Harbor server specs
5. Check for concurrent pull contention

### Issue: Storage Quota Exceeded

**Symptoms:** Cannot cache new images

**Diagnosis:**
```bash
# Check quota usage
curl -u admin:password \
  https://harbor.aglz.io/api/v2.0/quotas \
  | jq '.[] | select(.ref.name=="dockerhub-proxy") | .used'
```

**Solutions:**
1. Review and adjust retention policies
2. Manually delete unused images
3. Increase project storage quota
4. Add more storage to Harbor server

### Issue: Upstream Registry Unreachable

**Symptoms:** "dial tcp: lookup hub.docker.com: no such host"

**Diagnosis:**
```bash
# Test endpoint from Harbor server
ssh root@10.6.0.20
curl -I https://hub.docker.com

# Check Harbor endpoint configuration
curl -u admin:password \
  https://harbor.aglz.io/api/v2.0/registries
```

**Solutions:**
1. Verify Harbor server can reach internet
2. Check DNS resolution on Harbor server
3. Review firewall rules
4. Test endpoint credentials
5. Use alternative upstream registry (Quay.io)

---

## Best Practices

### Security

1. **Use HTTPS:** Always access Harbor over TLS
2. **Strong passwords:** Enforce password policy
3. **Role-based access:** Limit who can manage proxy projects
4. **Audit logs:** Review access logs regularly
5. **Scan images:** Enable Trivy scanning on cached images

### Performance

1. **Pre-warm cache:** Pull common images during off-hours
2. **Monitor metrics:** Track cache hit rate and storage usage
3. **Optimize network:** Use WireGuard for fastest connectivity
4. **Scale storage:** Plan for 2x growth annually
5. **CDN support:** Consider CloudFlare in front of Harbor

### Maintenance

1. **Regular updates:** Keep Harbor updated to latest stable
2. **Backup configuration:** Export project settings monthly
3. **Test retention:** Run dry-run before enabling policies
4. **Document changes:** Track modifications in CHANGELOG
5. **Team training:** Ensure team knows how to use proxy cache

---

## Summary

Harbor proxy cache provides significant build performance improvements:

- **90-95% faster** image pulls (cached)
- **Reduced bandwidth** and Docker Hub rate limits
- **Better reliability** with local caching
- **Centralized governance** for base images

**Next Steps:**
1. Configure proxy cache projects for Docker Hub, Quay, GHCR
2. Update Dockerfiles to use proxy paths
3. Warm cache with common images
4. Set up retention policies
5. Monitor metrics and optimize

---

**Documentation:** Phase 4.1 - Build Pipeline Optimization
**Related:** BUILD-OPTIMIZATION.md, Dockerfile, docker-compose.yml
**Support:** AGL Infrastructure Team
