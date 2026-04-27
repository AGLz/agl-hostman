# Security Documentation

## 📚 Table of Contents

1. [Security Overview](#security-overview)
2. [Quick Start](#quick-start)
3. [Security Tools](#security-tools)
4. [Best Practices](#best-practices)
5. [Remediation Procedures](#remediation-procedures)
6. [CI/CD Integration](#cicd-integration)

---

## 🔒 Security Overview

This project implements a comprehensive security strategy with multiple layers:

### Defense in Depth

```
┌─────────────────────────────────────────────┐
│         Pre-commit Hooks (Local)            │
│  • Secret detection                         │
│  • Basic vulnerability scanning             │
│  • Code linting                             │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│      Pull Request Checks (CI/CD)            │
│  • Full security scans                      │
│  • Dependency audits                        │
│  • Configuration validation                 │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│     Container Registry (Harbor)             │
│  • Image scanning with Trivy                │
│  • Vulnerability database                   │
│  • Quality gates                            │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│        Production Deployment                │
│  • Runtime security                         │
│  • Network isolation                        │
│  • Access controls                          │
└─────────────────────────────────────────────┘
```

---

## 🚀 Quick Start

### 1. Local Setup

Install pre-commit hooks:

```bash
# Install pre-commit
pip install pre-commit

# Install hooks
pre-commit install

# Test hooks
pre-commit run --all-files
```

### 2. Run Security Checks Locally

```bash
# Full security scan
./scripts/security-check.sh

# With automatic fixes
./scripts/security-check.sh --fix
```

### 3. Review Reports

```bash
# Check reports directory
ls -la .security-reports/

# View summary
cat .security-reports/summary.txt
```

---

## 🛡️ Security Tools

### 1. Trivy (Vulnerability Scanner)

**Purpose:** Comprehensive vulnerability and misconfiguration detection

**Capabilities:**
- Filesystem scanning
- Docker image scanning
- Configuration scanning
- Secret detection
- License scanning

**Usage:**

```bash
# Scan filesystem
docker run --rm -v $(pwd):/src aquasec/trivy:latest fs /src

# Scan Docker image
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image your-image:tag

# Configuration scan
docker run --rm -v $(pwd):/src aquasec/trivy:latest config /src
```

**Quality Gates:**

| Severity | Action | Exit Code |
|----------|--------|-----------|
| CRITICAL | Block deployment | 1 |
| HIGH | Manual review | 0 (warn) |
| MEDIUM | Report only | 0 |
| LOW | Log only | 0 |

### 2. TruffleHog (Secret Detection)

**Purpose:** Find secrets in git history and code

**Capabilities:**
- Git history scanning
- 700+ credential detectors
- Verification of found secrets
- Custom regex patterns

**Usage:**

```bash
# Scan git repository
trufflehog git file://. --since-commit HEAD --only-verified

# Scan specific commit
trufflehog git file://. --since-commit <commit-sha>

# Scan with custom patterns
trufflehog filesystem . --config trufflehog-config.yaml
```

**Common Secrets Detected:**
- AWS keys
- API tokens
- Database credentials
- SSH keys
- OAuth tokens
- Slack webhooks

### 3. npm audit (Dependency Scanning)

**Purpose:** Identify vulnerabilities in npm dependencies

**Usage:**

```bash
# Check for vulnerabilities
npm audit

# Automatic fix (non-breaking)
npm audit fix

# Force fix (may be breaking)
npm audit fix --force

# JSON output
npm audit --json > audit-report.json
```

**Severity Levels:**
- **Critical:** Immediate action required
- **High:** Fix soon
- **Moderate:** Plan to fix
- **Low:** Nice to fix

### 4. Dependabot (Automated Updates)

**Purpose:** Automatic dependency updates and security patches

**Configuration:** `.github/dependabot.yml`

**Features:**
- Weekly automated checks
- Security-first prioritization
- Grouped updates
- Auto-merge capable (with tests)

---

## 📋 Best Practices

### 1. Secrets Management

**✅ DO:**

```javascript
// Use environment variables
const apiKey = process.env.API_KEY;
const dbPassword = process.env.DB_PASSWORD;

// Use secret management services
import { SecretManager } from '@aws-sdk/client-secrets-manager';
const secret = await secretsManager.getSecretValue({ SecretId: 'prod/api/key' });
```

**❌ DON'T:**

```javascript
// Hardcoded secrets
const apiKey = "sk-1234567890abcdef";
const dbPassword = "MySecretPassword123!";

// Committed .env files
// Never commit .env, .env.local, or similar files
```

**Prevention:**
1. Add `.env*` to `.gitignore`
2. Use `.env.example` for templates (no actual secrets)
3. Enable pre-commit hooks for secret detection
4. Use GitHub Secret Scanning

### 2. Input Validation

**✅ DO:**

```javascript
import validator from 'validator';

// Validate and sanitize
function processInput(userInput) {
  // Validate format
  if (!validator.isAlphanumeric(userInput)) {
    throw new ValidationError('Invalid input format');
  }

  // Sanitize
  const clean = validator.escape(userInput);

  // Additional checks
  if (clean.length > 100) {
    throw new ValidationError('Input too long');
  }

  return clean;
}

// Prepared statements for SQL
const query = 'SELECT * FROM users WHERE id = ?';
db.query(query, [userId]);
```

**❌ DON'T:**

```javascript
// Direct use of user input
const query = `SELECT * FROM users WHERE id = ${userInput}`;
db.query(query);

// No validation
function processInput(userInput) {
  return userInput; // Dangerous!
}

// Insufficient validation
if (userInput) {
  // Not enough checking
}
```

### 3. Dependency Management

**✅ DO:**

```json
{
  "dependencies": {
    "express": "4.18.2",      // Exact version
    "lodash": "^4.17.21"       // Compatible updates
  },
  "devDependencies": {
    "@types/node": "~20.10.0"  // Approximate version
  }
}
```

**Practices:**
- Use `package-lock.json` (commit it!)
- Run `npm ci` in CI/CD (not `npm install`)
- Regular `npm audit` checks
- Review dependency changes in PRs
- Use Dependabot for automated updates

**❌ DON'T:**

```json
{
  "dependencies": {
    "express": "*",      // Any version - dangerous!
    "lodash": "latest"   // Unpredictable
  }
}
```

### 4. Docker Security

**✅ DO:**

```dockerfile
# Multi-stage build
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:20-alpine
# Non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001
USER nodejs

# Only copy necessary files
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --chown=nodejs:nodejs . .

# Health check
HEALTHCHECK --interval=30s --timeout=3s \
  CMD node healthcheck.js

EXPOSE 3000
CMD ["node", "server.js"]
```

**❌ DON'T:**

```dockerfile
# Using latest tag
FROM node:latest

# Running as root
# No USER directive

# Copying everything
COPY . .

# No health check
# No security scanning
```

### 5. Authentication & Authorization

**✅ DO:**

```javascript
// Use established libraries
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';

// Hash passwords
const saltRounds = 10;
const hashedPassword = await bcrypt.hash(password, saltRounds);

// Verify password
const isValid = await bcrypt.compare(password, hashedPassword);

// JWT with expiration
const token = jwt.sign(
  { userId: user.id },
  process.env.JWT_SECRET,
  { expiresIn: '1h' }
);

// Verify JWT
const decoded = jwt.verify(token, process.env.JWT_SECRET);

// Role-based access control
function requireRole(role) {
  return (req, res, next) => {
    if (!req.user || req.user.role !== role) {
      return res.status(403).json({ error: 'Forbidden' });
    }
    next();
  };
}
```

**❌ DON'T:**

```javascript
// Plain text passwords
const password = req.body.password;
db.query('INSERT INTO users (password) VALUES (?)', [password]);

// Custom crypto (reinventing the wheel)
function myHash(password) {
  // Don't roll your own crypto!
}

// No expiration
const token = jwt.sign({ userId: user.id }, secret);

// No access control
app.get('/admin', (req, res) => {
  // Anyone can access
});
```

---

## 🔧 Remediation Procedures

### Critical Vulnerabilities

**Immediate Actions:**

1. **Assess Impact**
   ```bash
   # Get details
   cat .security-reports/trivy-fs.json | \
     jq '.Results[].Vulnerabilities[]? | select(.Severity == "CRITICAL")'
   ```

2. **Block Deployment**
   - CI/CD will automatically block
   - Do not merge PR until resolved

3. **Fix or Mitigate**
   ```bash
   # Update dependencies
   npm audit fix --force

   # Or update specific package
   npm update vulnerable-package

   # Verify fix
   npm audit
   ```

4. **Verify Resolution**
   ```bash
   ./scripts/security-check.sh
   ```

### High Severity Issues

**Within 14 days:**

1. **Create Issue**
   ```bash
   # GitHub will auto-create via workflow
   # Or manually create with security label
   ```

2. **Plan Remediation**
   - Review available patches
   - Test compatibility
   - Schedule deployment

3. **Update and Test**
   ```bash
   npm update package-name
   npm test
   npm run build
   ```

4. **Deploy Fix**
   ```bash
   git add package*.json
   git commit -m "fix(security): update package-name to address CVE-2024-XXXXX"
   git push
   ```

### Secrets Detected

**Immediate Response:**

1. **Revoke Secret**
   - Immediately invalidate the exposed credential
   - Generate new secret

2. **Update Configuration**
   ```bash
   # Add to .env (not committed)
   echo "NEW_SECRET=generated-value" >> .env

   # Update GitHub Secrets (CI/CD)
   # Via GitHub UI: Settings > Secrets > Actions
   ```

3. **Clean Git History**
   ```bash
   # If secret was just committed (not pushed)
   git reset --soft HEAD~1
   git checkout -- .

   # If already pushed - use BFG Repo-Cleaner or git-filter-repo
   # Contact security team
   ```

4. **Add to .gitignore**
   ```bash
   echo ".env" >> .gitignore
   echo ".env.local" >> .gitignore
   git add .gitignore
   git commit -m "chore: ensure .env files are ignored"
   ```

### Configuration Issues

**Resolution Steps:**

1. **Review Issue**
   ```bash
   cat .security-reports/trivy-config.json | \
     jq '.Results[].Misconfigurations[]?'
   ```

2. **Fix Configuration**
   ```yaml
   # Example: Fix Docker Compose security
   services:
     app:
       security_opt:
         - no-new-privileges:true
       read_only: true
       tmpfs:
         - /tmp
   ```

3. **Validate Fix**
   ```bash
   docker run --rm -v $(pwd):/src \
     aquasec/trivy:latest config /src
   ```

---

## 🔄 CI/CD Integration

### GitHub Actions Workflows

#### 1. Security Scan Workflow

**Trigger:** Push, PR, Daily schedule

**File:** `.github/workflows/security-scan.yml`

**Jobs:**
- `trivy-filesystem` - Scan code for vulnerabilities
- `trivy-config` - Validate configurations
- `secret-scanning` - Detect secrets
- `dependency-scanning` - npm audit
- `docker-image-scan` - Scan container images

**Outputs:**
- SARIF files → GitHub Security tab
- JSON reports → Artifacts
- Summary → PR comments

#### 2. Integration with Existing Workflows

**Development (ci-develop.yml):**
```yaml
jobs:
  lint-and-test:
    # ... existing steps

  security-scan:
    needs: lint-and-test
    uses: ./.github/workflows/security-scan.yml

  docker-build:
    needs: security-scan  # Only build if secure
    # ... existing steps
```

**Staging (deploy-staging.yml):**
```yaml
jobs:
  security-check:
    uses: ./.github/workflows/security-scan.yml

  deploy-qa:
    needs: security-check  # Block on security issues
    # ... existing steps
```

### Harbor Integration

**Automated Scanning:**

```yaml
# Webhook configuration in Harbor
webhooks:
  - event: SCANNING_COMPLETED
    url: https://api.github.com/repos/owner/repo/dispatches
    auth:
      type: bearer
      token: ${{ secrets.GITHUB_TOKEN }}
```

**Quality Gate Policy:**

```yaml
# Project policies in Harbor
policies:
  - type: vulnerability
    action: block
    severity: critical,high
  - type: vulnerability
    action: warn
    severity: medium
```

### Notifications

**Slack Integration:**

```yaml
# .github/workflows/security-scan.yml
- name: Notify security team
  if: failure()
  uses: slackapi/slack-github-action@v1
  with:
    webhook-url: ${{ secrets.SLACK_WEBHOOK_SECURITY }}
```

**Email Alerts:**

```yaml
# Dependabot notifications via .github/dependabot.yml
updates:
  - package-ecosystem: "npm"
    reviewers:
      - "security-team"
    assignees:
      - "security-lead"
```

---

## 📊 Security Metrics

Track these metrics in your security dashboard:

### Vulnerability Metrics

```
Total Vulnerabilities:    42
├─ CRITICAL:              0  ✅
├─ HIGH:                  3  ⚠️
├─ MEDIUM:               15  ℹ️
└─ LOW:                  24  ℹ️

Mean Time to Remediate:
├─ CRITICAL:           2 days
├─ HIGH:               7 days
└─ MEDIUM:            14 days

Security Scan Success Rate: 95%
```

### Compliance Metrics

```
✅ No secrets in code:           100%
✅ Pre-commit hooks installed:    95%
✅ Dependencies up-to-date:       90%
✅ Images scanned:               100%
⚠️  Coverage > 80%:               85%
```

---

## 🆘 Getting Help

### Internal Resources

- **Security Policy:** `SECURITY.md`
- **Pre-commit Hooks:** `.pre-commit-config.yaml`
- **Local Scanner:** `scripts/security-check.sh`

### External Resources

- **Trivy Documentation:** https://aquasecurity.github.io/trivy/
- **TruffleHog:** https://github.com/trufflesecurity/trufflehog
- **OWASP Top 10:** https://owasp.org/www-project-top-ten/
- **CWE Top 25:** https://cwe.mitre.org/top25/

### Contact Security Team

- **Email:** security@aglz.io
- **Slack:** #security-alerts
- **On-Call:** PagerDuty escalation

---

**Last Updated:** 2025-10-28
**Version:** 1.0.0
**Maintained By:** Security Integration Team
