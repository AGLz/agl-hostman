---
name: ci-cd-pipeline-optimization
description: "GitHub Actions CI/CD pipeline optimization including caching strategies, parallel execution, trunk-based development, deployment gates, and monitoring. Use when improving build times, deployment safety, or developer velocity."
category: devops
priority: P2
tags: [ci-cd, github-actions, pipeline, optimization, deployment]
---

# CI/CD Pipeline Optimization

Comprehensive guide for optimizing GitHub Actions CI/CD pipelines including caching strategies, parallel execution, trunk-based development, deployment gates, feature flags, rollback strategies, monitoring, security scanning, and compliance.

## Overview

A well-optimized CI/CD pipeline is critical for developer productivity and deployment reliability. This skill provides proven patterns and strategies for maximizing pipeline efficiency while maintaining safety and compliance.

### Key Benefits

- **Faster Build Times** - Reduce feedback loops from 30+ minutes to under 10 minutes
- **Improved Developer Velocity** - More deployments per day with higher confidence
- **Deployment Safety** - Multiple approval gates, automated testing, and instant rollback
- **Cost Optimization** - Reduce CI/CD minutes through caching and parallelization
- **Security Integration** - Automated vulnerability scanning at every stage

### Pipeline Optimization Metrics

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Average Build Time | 28 min | 8 min | 71% faster |
| Deployment Frequency | 2x/day | 15x/day | 7.5x more |
| Failed Deployments | 12% | 1.2% | 90% reduction |
| Mean Time to Recovery | 45 min | 5 min | 89% faster |
| CI/CD Cost | $500/mo | $180/mo | 64% savings |

## Pipeline Speed Optimization

### Caching Strategies

Effective caching is the single biggest factor in pipeline performance.

#### Composer Dependencies

```yaml
- name: Get Composer cache directory
  id: composer-cache
  run: echo "dir=$(composer config cache-files-dir)" >> $GITHUB_OUTPUT

- name: Cache Composer dependencies
  uses: actions/cache@v4
  with:
    path: ${{ steps.composer-cache.outputs.dir }}
    key: ${{ runner.os }}-composer-${{ hashFiles('**/composer.lock') }}
    restore-keys: |
      ${{ runner.os }}-composer-
```

**Cache Key Strategy:**
- Use `composer.lock` hash for exact match
- Fall back to OS-level prefix for partial hits
- Cache both vendor directory and composer cache

#### NPM Dependencies

```yaml
- name: Setup Node.js
  uses: actions/setup-node@v4
  with:
    node-version: '20'
    cache: 'npm'
    cache-dependency-path: package-lock.json

- name: Cache node_modules
  uses: actions/cache@v4
  with:
    path: |
      ~/.npm
      node_modules
    key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
    restore-keys: |
      ${{ runner.os }}-node-
```

**Best Practices:**
- Use `npm ci` instead of `npm install` for reproducible builds
- Cache both `~/.npm` cache and `node_modules`
- Pin dependency versions in `package-lock.json`

#### Docker Layer Caching

```yaml
- name: Set up Docker Buildx
  uses: docker/setup-buildx-action@v3

- name: Build and push Docker image
  uses: docker/build-push-action@v5
  with:
    context: ./src
    push: true
    tags: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest
    cache-from: |
      type=registry,ref=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:buildcache
      type=gha
    cache-to: type=registry,ref=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:buildcache,mode=max
    build-args: |
      BUILDKIT_INLINE_CACHE=1
```

**Cache Types:**
- **Registry Cache** - Shared across runners, persists indefinitely
- **GitHub Actions Cache** - Runner-local, 7-day retention
- **Local Cache** - Fastest but not shared

#### Test Results Caching

```yaml
- name: Cache Pest test results
  uses: actions/cache@v4
  with:
    path: |
      src/.phpunit.result.cache
      src/storage/framework/testing
    key: test-results-${{ github.sha }}
    restore-keys: |
      test-results-
```

### Parallel Execution

#### Matrix Strategy for Tests

```yaml
strategy:
  matrix:
    test-suite:
      - Unit
      - Feature
      - Integration
    php-version: ['8.3', '8.4']
  fail-fast: false
  max-parallel: 4
```

**Parallelization Tips:**
- Use `fail-fast: false` to allow all jobs to complete
- Set `max-parallel` to match runner availability
- Split test suites by execution time
- Run independent checks (lint, security) in parallel

#### Job Dependencies

```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    # Fast checks run first

  test:
    needs: lint
    runs-on: ubuntu-latest
    # Tests run after lint passes

  build:
    needs: test
    runs-on: ubuntu-latest
    # Only build if tests pass
```

**Dependency Best Practices:**
- Minimize job dependencies for faster feedback
- Group fast checks (lint, format) in first job
- Run expensive operations (build, scan) only if needed

### Conditional Execution

```yaml
- name: Run expensive step
  if: github.event_name == 'push' && github.ref == 'refs/heads/main'
  run: |
    # Only run on main branch pushes

- name: Skip for docs changes
  if: contains(github.event.head_commit.modified, 'docs/') == false
  run: |
    # Skip if only docs changed
```

### Build Time Monitoring

Use `scripts/ci-speed-test.sh` to track pipeline performance:

```bash
./ci-speed-test.sh --workflow ci.yml --days 30
```

## Trunk-Based Development

Trunk-based development accelerates delivery by reducing branch longevity.

### Branching Strategy

```
main (trunk)
  |
  ├── develop (integration branch)
  |
  └── feature/* (short-lived, < 1 day)
```

### Workflow Triggers

```yaml
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]
  pull_request_target:
    branches: [main]
    types: [labeled, synchronize]
```

### Branch Protection Rules

```json
{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "CI - Continuous Integration / code-quality",
      "CI - Continuous Integration / php-tests",
      "Security Scanning"
    ]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
```

### Feature Flags

Use feature flags instead of long-lived feature branches.

```php
// Laravel feature flag example
if (Feature::active('new-dashboard')) {
    return new NewDashboardResponse();
}
return new LegacyDashboardResponse();
```

### Merging Strategy

```bash
# Squash merge to main
git checkout main
git merge --squash feature/new-feature
git commit -m "feat: add new feature"
```

## Deployment Gates

### Environment Protection Rules

Configure in GitHub repository settings:

**Production Environment:**
- Required reviewers: 2 (Tech Lead + DevOps)
- Wait timer: 15 minutes
- Only branches: `main`
- Required status checks: All CI/CD checks

**Staging Environment:**
- Required reviewers: 1
- Wait timer: 5 minutes
- Allowed branches: `main`, `develop`

### Approval Gates in Workflows

```yaml
deploy-production:
  runs-on: ubuntu-latest
  environment:
    name: production
    url: https://prod-agl.aglz.io
  steps:
    - name: Manual approval
      run: |
        echo "Deployment approved by ${{ github.actor }}"
```

### Quality Gates

```yaml
- name: Quality gate check
  run: |
    # Check test coverage
    COVERAGE=$(cat coverage/clover.xml | jq -r '.metrics.coveredelements / .metrics.elements * 100')
    if (( $(echo "$COVERAGE < 80" | bc -l) )); then
      echo "Coverage below 80%: $COVERAGE%"
      exit 1
    fi

    # Check for critical vulnerabilities
    CRITICAL=$(cat trivy-report.json | jq '[.Results[].Vulnerabilities[]? | select(.Severity == "CRITICAL")] | length')
    if [ "$CRITICAL" -gt 0 ]; then
      echo "Critical vulnerabilities found: $CRITICAL"
      exit 1
    fi
```

## Rollback Strategies

### Blue-Green Deployment

See `templates/cd-with-gates.yml` for complete blue-green implementation.

```yaml
- name: Determine active slot
  id: slot
  run: |
    ACTIVE_SLOT=$(curl -s https://prod-agl.aglz.io/api/deployment/slot || echo "blue")
    INACTIVE_SLOT=$([ "$ACTIVE_SLOT" = "blue" ] && echo "green" || echo "blue")
    echo "active=$ACTIVE_SLOT" >> $GITHUB_OUTPUT
    echo "inactive=$INACTIVE_SLOT" >> $GITHUB_OUTPUT
```

### Automatic Rollback Triggers

```yaml
- name: Monitor for rollback conditions
  run: |
    for i in {1..10}; do
      ERROR_RATE=$(curl -s "https://prod-agl.aglz.io/api/metrics/error-rate" || echo "0")
      if (( $(echo "$ERROR_RATE > 0.05" | bc -l) )); then
        echo "Error rate too high: $ERROR_RATE, initiating rollback"
        exit 1
      fi
      sleep 30
    done

- name: Auto-rollback on failure
  if: failure()
  run: |
    curl -X POST "${{ secrets.PRODUCTION_LB_API_URL }}/traffic" \
      -H "Authorization: Bearer ${{ secrets.PRODUCTION_LB_TOKEN }}" \
      -d '{"percentage": 100, "slot": "previous"}'
```

### Manual Rollback Script

Use `scripts/ci-rollback.sh` for instant manual rollback:

```bash
./ci-rollback.sh --environment production --version previous
```

## Monitoring

### Pipeline Metrics

Track these key metrics:

| Metric | Description | Target |
|--------|-------------|--------|
| Build Duration | Time from trigger to completion | < 10 min |
| Success Rate | Percentage of successful builds | > 95% |
| Deployment Frequency | Deploys per day | > 10 |
| Lead Time | Commit to production | < 1 hour |
| MTTR | Recovery from failure | < 15 min |

### GitHub Actions Usage

```bash
# View workflow runs
gh run list --workflow=ci.yml --limit 50

# View specific run details
gh run view 123456789 --log

# Cancel workflow runs
gh run cancel 123456789

# Re-run failed jobs
gh run rerun 123456789
```

### Custom Metrics Reporting

```yaml
- name: Report metrics
  if: always()
  run: |
    curl -X POST "${{ secrets.METRICS_ENDPOINT }}" \
      -H "Content-Type: application/json" \
      -d '{
        "workflow": "${{ github.workflow }}",
        "run_id": "${{ github.run_id }}",
        "status": "${{ job.status }}",
        "duration": ${{ steps.build.outputs.duration }},
        "branch": "${{ github.ref_name }}",
        "commit": "${{ github.sha }}"
      }'
```

## Security Scanning

### Integrated Security Checks

```yaml
security-scan:
  runs-on: ubuntu-latest
  steps:
    # Filesystem scan
    - name: Trivy filesystem scan
      uses: aquasecurity/trivy-action@master
      with:
        scan-type: 'fs'
        format: 'sarif'
        output: 'trivy-fs-results.sarif'

    # Secret scanning
    - name: TruffleHog secret scan
      uses: trufflesecurity/trufflehog@main
      with:
        path: ./
        extra_args: --only-verified --fail

    # Dependency scan
    - name: NPM audit
      run: npm audit --audit-level=moderate

    # Upload results
    - name: Upload SARIF
      uses: github/codeql-action/upload-sarif@v3
      with:
        sarif_file: 'trivy-fs-results.sarif'
```

### Security Quality Gates

```yaml
- name: Security quality gate
  run: |
    CRITICAL=$(cat trivy-report.json | jq '[.Results[].Vulnerabilities[]? | select(.Severity == "CRITICAL")] | length')
    HIGH=$(cat trivy-report.json | jq '[.Results[].Vulnerabilities[]? | select(.Severity == "HIGH")] | length')

    echo "Security Scan Results:"
    echo "CRITICAL: $CRITICAL"
    echo "HIGH: $HIGH"

    if [ "$CRITICAL" -gt 0 ]; then
      echo "CRITICAL vulnerabilities found - blocking deployment"
      exit 1
    fi

    if [ "$HIGH" -gt 10 ]; then
      echo "Too many HIGH vulnerabilities - review required"
      exit 1
    fi
```

## Compliance

### Audit Trail

```yaml
- name: Record deployment audit
  run: |
    cat >> audit.log <<EOF
    {
      "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
      "deployment_id": "${{ github.run_id }}",
      "environment": "production",
      "version": "${{ github.sha }}",
      "deployer": "${{ github.actor }}",
      "approved_by": ["${{ needs.approval.outputs.reviewer1 }}", "${{ needs.approval.outputs.reviewer2 }}"],
      "status": "started"
    }
    EOF

    curl -X POST "${{ secrets.AUDIT_SERVICE_URL }}" \
      -H "Content-Type: application/json" \
      -d @audit.log
```

### SOX Compliance Controls

```yaml
# Required: Segregation of duties
- name: Validate approvers
  run: |
    # Approver 1: Technical (Lead Developer)
    # Approver 2: Business (Product Manager)
    [[ "${{ github.event.inputs.approver_role_1 }}" == "lead-developer" ]] || exit 1
    [[ "${{ github.event.inputs.approver_role_2 }}" == "product-manager" ]] || exit 1

# Required: Change management ticket
- name: Verify change ticket
  run: |
    TICKET="${{ github.event.inputs.change_ticket }}"
    curl -s "${{ secrets.JIRA_API }}/issue/${TICKET}" | jq '.fields.status.name' | grep -q "Approved"
```

## Best Practices

### 1. Pipeline Organization

- **Separate CI and CD** - Different triggers and goals
- **Use reusable workflows** - Reduce duplication
- **Implement proper caching** - Biggest performance gain
- **Set appropriate timeouts** - Prevent hanging jobs

### 2. Security

- **Never log secrets** - Use GitHub Secrets
- **Implement least privilege** - Minimal token scopes
- **Scan all images** - Including base images
- **Require approvals** - Multi-person for production

### 3. Performance

- **Cache everything possible** - Dependencies, layers, results
- **Run tests in parallel** - Matrix strategy
- **Cancel redundant runs** - Concurrency groups
- **Optimize Docker images** - Multi-stage builds

### 4. Reliability

- **Implement health checks** - Post-deployment verification
- **Enable rollback** - Always have previous version
- **Monitor production** - Automated alerts
- **Document failures** - Post-mortem process

## Quick Start

1. **Analyze current pipeline:**
   ```bash
   ./ci-speed-test.sh --workflow ci.yml --analyze
   ```

2. **Review caching strategy:**
   ```bash
   ./ci-cache-stats.sh --workflow ci.yml
   ```

3. **Apply optimized templates:**
   - Use `templates/ci-optimized.yml` for CI pipeline
   - Use `templates/cd-with-gates.yml` for CD pipeline

4. **Monitor improvements:**
   ```bash
   ./ci-speed-test.sh --workflow ci.yml --days 7 --compare
   ```

## Troubleshooting

### Build times not improving

1. Check cache hit rates with `ci-cache-stats.sh`
2. Verify cache keys include lock files
3. Ensure cache is not being invalidated too frequently
4. Consider registry cache for Docker layers

### Flaky tests

1. Run tests in isolation first
2. Use `fail-fast: false` to see all failures
3. Check for race conditions in parallel tests
4. Add retry logic for external dependencies

### Deployment stuck

1. Check environment protection rules
2. Verify required reviewers are available
3. Review pending status checks
4. Use `gh workflow run` to trigger manually

## References

- [GitHub Actions Best Practices](https://docs.github.com/en/actions/learn-github-actions/best-practices-for-github-actions)
- [Caching Dependencies](https://docs.github.com/en/actions/using-workflows/caching-dependencies-to-speed-up-workflows)
- [Deployment Environments](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
- [Trunk-Based Development](https://trunkbaseddevelopment.com/)
- [Blue-Green Deployment](https://martinfowler.com/bliki/BlueGreenDeployment.html)
