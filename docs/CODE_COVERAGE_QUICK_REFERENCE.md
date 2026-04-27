# Code Coverage & Review Quick Reference
**Implementation Guide for DevSecOps and CI/CD**

---

## Quick Setup Commands

### 1. Initialize GitHub Secrets
```bash
# Via GitHub CLI
gh secret set CODECOV_TOKEN
gh secret set SNYK_TOKEN
gh secret set SONAR_TOKEN
gh secret set SONAR_HOST_URL
gh secret set GITLEAKS_LICENSE
gh secret set APP_URL
```

### 2. Enable Required Actions
```bash
# Enable GitHub Actions
gh repo edit --enable-actions=true

# Enable Branch Protection
gh api repos/:owner/:repo/branches/main/protection \
  -X PUT \
  -F required_status_checks='{"strict":true,"contexts":["coverage/overall","sonarqube-quality-gate"]}' \
  -F enforce_admins=true \
  -F required_pull_request_reviews='{"required_approving_review_count":1}'
```

### 3. Install Codecov
```bash
# Via npm
npm install -g codecov

# Upload coverage
codecov --token=$CODECOV_TOKEN
```

### 4. Install Snyk
```bash
# Via npm
npm install -g snyk

# Authenticate
snyk auth $SNYK_TOKEN

# Test
snyk test
```

---

## Branch Protection Rules

### Minimum Required Checks
```yaml
required_status_checks:
  - coverage/overall        # Code coverage >= 80%
  - coverage/diff           # No decrease in coverage
  - sonarqube-quality-gate  # Quality gate passed
  - Snyk Security Scan      # No high/critical vulns
  - Gitleaks Scan           # No secrets detected
  - Lint                    # Code linting passed
  - Test                    # Tests passed
```

### Approval Rules
```yaml
required_approving_review_count: 1      # Minimum 1 approval
require_code_owner_review: true         # CODEOWNERS approval
dismiss_stale_reviews: true             # Re-review on new commits
require_last_push_approval: true        # Author can't approve own commits
```

---

## Coverage Thresholds

### Recommended Thresholds
| Project Type | Line Coverage | Branch Coverage | Function Coverage |
|--------------|---------------|-----------------|-------------------|
| Critical Path | 90% | 85% | 95% |
| Main Application | 80% | 75% | 85% |
| Utility Code | 70% | 65% | 75% |
| Configuration | 50% | 40% | 60% |

### Enforce in Workflow
```yaml
- name: Coverage Gate
  run: |
    MINIMUM=80
    COVERAGE=$(node -e "console.log(require('./coverage/coverage-summary.json').total.lines.pct)")
    if (( $(echo "$COVERAGE < $MINIMUM" | bc -l) )); then
      echo "::error::Coverage ${COVERAGE}% is below ${MINIMUM}%"
      exit 1
    fi
```

---

## PR Review Automation

### CodeRabbit AI Setup
```bash
# Install CodeRabbit GitHub App
# Visit: https://coderabbit.ai/

# Auto-approve conditions
# - All AI comments resolved
# - No blocking issues found
# - Coverage threshold met
```

### CODEOWNERS File Structure
```
# Global rules
* @platform-team

# Path-based rules
frontend/** @frontend-team
backend/** @backend-team
**/*.go @backend-team
**/*.tsx @frontend-team

# No review required
node_modules/** @no-one
dist/** @no-one
```

---

## Security Scanning Commands

### SAST (SonarQube)
```bash
# Local scan
sonar-scanner \
  -Dsonar.projectKey=my-project \
  -Dsonar.sources=src \
  -Dsonar.host.url=$SONAR_HOST_URL \
  -Dsonar.login=$SONAR_TOKEN
```

### SCA (Snyk)
```bash
# Test dependencies
snyk test --severity-threshold=high

# Monitor for vulnerabilities
snyk monitor

# Test all dependencies
snyk test --all-projects
```

### Secrets (Gitleaks)
```bash
# Scan repository
gitleaks detect --source . --verbose

# Scan with config
gitleaks detect --config .gitleaks.toml --source .
```

### DAST (OWASP ZAP)
```bash
# Docker scan
docker run -t owasp/zap2docker-stable zap-baseline.py \
  -t https://example.com

# API scan
zap-api-scan.py -t https://api.example.com -f openapi
```

---

## Workflow Optimization Tips

### 1. Use Caching Effectively
```yaml
- uses: actions/cache@v4
  with:
    path: |
      ~/.npm
      node_modules
    key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
    restore-keys: |
      ${{ runner.os }}-node-
```

### 2. Enable Concurrency
```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

### 3. Use Matrix for Testing
```yaml
strategy:
  matrix:
    os: [ubuntu-latest, windows-latest]
    node: [18, 20, 22]
```

### 4. Conditional Execution
```yaml
if: github.event_name == 'pull_request'
if: github.ref == 'refs/heads/main'
if: needs.test.result == 'success'
```

---

## Coverage Badges

### Markdown Format
```markdown
![Codecov](https://codecov.io/gh/user/repo/branch/main/graph/badge.svg)
![Coverage](https://img.shields.io/badge/coverage-85%25-brightgreen)
```

### HTML Format
```html
<a href="https://codecov.io/gh/user/repo">
  <img src="https://codecov.io/gh/user/repo/branch/main/graph/badge.svg" alt="Coverage">
</a>
```

---

## Troubleshooting

### Coverage Not Uploading
```bash
# Check codecov token
echo $CODECOV_TOKEN

# Test upload locally
codecov --dry-run --token=$CODECOV_TOKEN

# Check coverage file exists
ls -la coverage/
```

### Branch Protection Not Working
```bash
# Check branch protection status
gh api repos/:owner/:repo/branches/main/protection

# List required checks
gh api repos/:owner/:repo/branches/main/protection/required_status_checks
```

### SonarQube Quality Gate Failing
```bash
# Check SonarQube status
curl -u $SONAR_TOKEN:$SONAR_TOKEN \
  $SONAR_HOST_URL/api/qualitygates/project_status?projectKey=my-project

# View detailed report
# Visit: $SONAR_HOST_URL/dashboard?id=my-project
```

---

## Tools Quick Reference

| Purpose | Tool | Command |
|---------|------|---------|
| Coverage | Codecov | `codecov` |
| Coverage | Vitest | `npm run test:coverage` |
| SAST | SonarQube | `sonar-scanner` |
| SCA | Snyk | `snyk test` |
| Secrets | Gitleaks | `gitleaks detect` |
| DAST | OWASP ZAP | `zap-baseline.py` |
| AI Review | CodeRabbit | Auto via GitHub |
| Linting | ESLint | `npm run lint` |

---

## Common Workflows

### Before Committing
```bash
npm run lint          # Check code style
npm run test          # Run tests
npm run test:coverage # Check coverage
npm run type-check    # TypeScript check
npm run format:check  # Prettier check
```

### Before Pushing
```bash
snyk test             # Security scan
npm run build         # Verify build
npm run test:e2e      # End-to-end tests
```

### Before Merging PR
1. ✅ All status checks passed
2. ✅ Coverage threshold met
3. ✅ At least 1 approval
4. ✅ No blocking comments
5. ✅ Security scan clean

---

**Document Version**: 1.0.0
**Last Updated**: 2026-02-16
**Related**: [Full Research Report](./CODE_COVERAGE_REVIEW_DEVSECOPS_2026.md)
