# AGL-20: Security Hardening and Audit - Validation Checklist

**Issue ID**: AGL-20
**Title**: Security Hardening and Audit
**Priority**: High
**Estimate**: 3-4 weeks
**Current Status**: Critical Vulnerabilities Identified
**Security Grade**: C- (70/100) → Target: A (90%+)
**Document Version**: 1.0
**Last Updated**: 2026-02-11

---

## Checklist Overview

This validation checklist ensures comprehensive security hardening across the AGL infrastructure. Use this checklist during implementation and for final security audit validation before marking task as complete.

**Legend**:
- [ ] = Not started
- [~] = In progress
- [x] = Complete
- [!] = Failed/Blocked
- [n/a] = Not applicable
- ⚠️ = Manual verification required
- 🔴 = Critical priority
- 🟠 = High priority
- 🟡 = Medium priority

---

## Phase 1: Critical Credential Remediation (Week 1)

### 1.1 Exposed Credential Inventory

**Identify All Exposed Credentials**:
- [ ] Inventory all API keys in /root/.claude.json
- [ ] Inventory all secrets in .env files
- [ ] Search for credentials in git history
- [ ] Search for credentials in documentation
- [ ] Document credential locations and purposes

**Current Exposed Credentials** (from security audit):

| Service | Credential | Location | CVSS | Status |
|---------|-----------|----------|--------|
| Cloudflare | API token | .claude.json + .env | 9.8 | [ ] |
| Harbor | admin/Harbor12345 | .claude.json:283 | 9.8 | [ ] |
| Dokploy #1 | API key | .claude.json:259 | 9.1 | [ ] |
| Dokploy #2 | API key | .claude.json:801 | 9.1 | [ ] |
| Portainer | Token | .claude.json:300 | 9.1 | [ ] |
| Azure DevOps | PAT | .claude.json:762 | 9.1 | [ ] |
| Z.AI | API keys | .claude.json:812-838 | 7.5 | [ ] |
| Exa AI | API key | .claude.json:326 | 6.5 | [ ] |
| Ref.tools | API key | .claude.json:135 | 7.5 | [ ] |

### 1.2 Credential Rotation

**Rotate All Exposed Credentials**:

**Cloudflare**:
- [ ] Generate new API token
- [ ] Update applications using token
- [ ] Invalidate old token
- [ ] Update .env file
- [ ] Remove from documentation

**Harbor**:
- [ ] Change admin password (strong password)
- [ ] Change robot account passwords
- [ ] Update API tokens
- [ ] Update .claude.json
- [ ] Test new credentials

**Dokploy**:
- [ ] Rotate API key #1
- [ ] Rotate API key #2
- [ ] Update application configuration
- [ ] Update .claude.json
- [ ] Test deployments

**Portainer**:
- [ ] Generate new API token
- [ ] Update integrations
- [ ] Update .claude.json
- [ ] Revoke old token

**Azure DevOps**:
- [ ] Generate new PAT
- [ ] Update CI/CD pipelines
- [ ] Update .claude.json
- [ ] Revoke old PAT

**Z.AI / Exa / Ref.tools**:
- [ ] Rotate API keys
- [ ] Update application code
- [ ] Update .claude.json
- [ ] Invalidate old keys

### 1.3 Secure Configuration Files

**File Permissions**:
```bash
# Execute and verify
chmod 600 /root/.claude.json
chmod 600 /mnt/overpower/apps/dev/agl/agl-hostman/.env
chmod 600 /root/.config/dokploy/*
chown root:root /root/.claude.json
```

- [ ] /root/.claude.json permissions: 600
- [ ] /root/.claude.json owner: root:root
- [ ] .env files permissions: 600
- [ ] No credentials in git history
- [ ] No credentials in documentation

**Gitleaks Scan**:
- [ ] Scan entire repository
- [ ] Review and remediate findings
- [ ] Add pre-commit hook for secrets detection
- [ ] Verify no false negatives

### 1.4 Remove Credentials from Documentation

**Documentation Cleanup**:
- [ ] Scan all .md files for credentials
- [ ] Remove passwords from documentation
- [ ] Remove API keys from documentation
- [ ] Use placeholders (e.g., YOUR_API_KEY)
- [ ] Add warning about committing secrets

### 1.5 Immediate MCP Security

**Laravel Boost MCP**:
- [ ] Add authentication middleware
- [ ] Add rate limiting (60 req/min)
- [ ] Add input validation
- [ ] Add CORS restrictions
- [ ] Add audit logging

**Test Authentication**:
```bash
# Test without auth → should fail
curl -X POST http://agl-hostman/mcp
# Expected: 401/403 Forbidden

# Test with auth → should succeed
curl -X POST http://agl-hostman/mcp \
  -H "X-MCP-API-Key: <valid-key>"
# Expected: 200 OK
```

---

## Phase 2: Secrets Management Implementation (Week 2-3)

### 2.1 HashiCorp Vault Deployment

**Installation**:
- [ ] Vault container/image deployed
- [ ] Persistent storage configured
- [ ] Network access configured
- [ ] TLS certificates configured
- [ ] Auto-unseal configured (if using HSM/KMS)

**Initial Configuration**:
```bash
# Initialize Vault
vault operator init -key-shares=5 -key-threshold=3

# Unseal Vault
vault operator unseal <key1>
vault operator unseal <key2>
vault operator unseal <key3>

# Enable secrets engine
vault secrets enable -path=agl kv-v2
```

- [ ] Vault initialized
- [ ] Root token secured offline
- [ ] Unseal keys secured offline
- [ ] KV secrets engine enabled
- [ ] Audit logging enabled

### 2.2 Migrate Secrets to Vault

**Create Secret Structure**:
```
agl/
├── mcp/
│   ├── dokploy/
│   │   ├── api-key-1
│   │   └── api-key-2
│   ├── harbor/
│   │   ├── admin-password
│   │   └── robot-password
│   ├── cloudflare/
│   │   └── api-token
│   ├── portainer/
│   │   └── api-token
│   ├── azure-devops/
│   │   └── pat
│   └── external-apis/
│       ├── zai
│       ├── exa
│       └── reftools
├── database/
│   ├── postgres/
│   ├── mysql/
│   └── redis
└── application/
    ├── laravel-app-key
    └── jwt-secrets
```

**Migrate Each Secret**:
- [ ] Cloudflare API token → vault
- [ ] Harbor credentials → vault
- [ ] Dokploy API keys → vault
- [ ] Portainer token → vault
- [ ] Azure DevOps PAT → vault
- [ ] Z.AI/Exa/Ref API keys → vault
- [ ] Laravel APP_KEY → vault
- [ ] Database passwords → vault
- [ ] JWT secrets → vault
- [ ] Any other secrets → vault

**Verify Migration**:
- [ ] All secrets in Vault
- [ ] No secrets in .env files
- [ ] No secrets in code
- [ ] Applications can read from Vault
- [ ] Backup Vault unseal keys offline

### 2.3 Application Integration

**Laravel Integration**:
```php
// composer.json
"require": {
    "laravel-vault/vault": "^1.0"
}

// config/vault.php
return [
    'host' => env('VAULT_HOST', 'vault.aglz.io'),
    'port' => env('VAULT_PORT', '8200'),
    'scheme' => 'https',
    'path' => 'agl',
    'token' => env('VAULT_TOKEN'),
];

// Usage
$vault = app('vault');
$dokployKey = $vault->get('mcp/dokploy/api-key-1');
```

- [ ] Laravel Vault package installed
- [ ] Vault configuration file created
- [ ] Vault facade registered
- [ ] Application reads secrets from Vault
- [ ] Fallback to .env if Vault unavailable
- [ ] Secrets cached appropriately

**Environment Variables**:
- [ ] VAULT_ADDR configured
- [ ] VAULT_TOKEN configured (via AppRole/Kubernetes)
- [ ] VAULT_SKIP_VERIFY=false (production requires valid TLS)
- [ ] VAULT_NAMESPACE=agl (if using namespaces)

### 2.4 Secret Rotation

**Rotation Policy**:
- [ ] API keys rotate every 90 days
- [ ] Database passwords rotate every 180 days
- [ ] JWT secrets rotate every 365 days
- [ ] Admin passwords rotate every 90 days

**Automation**:
- [ ] Rotation scripts created
- [ ] Rotation scheduled in cron
- [ ] Application restart after rotation automated
- [ ] Old secrets invalidated after rotation
- [ ] Rotation logged to audit trail

### 2.5 Vault Backup & Disaster Recovery

**Backup Strategy**:
- [ ] Vault data snapshot automated
- [ ] Unseal keys backed up offline
- [ ] Root token backed up offline
- [ ] Backup encrypted with GPG
- [ ] Backup stored in separate location

**Restore Testing**:
- [ ] Quarterly restore test
- [ ] Unseal process tested
- [ ] Secret access verified post-restore

---

## Phase 3: Network Security (Week 4-6)

### 3.1 Network Segmentation Design

**VLAN Architecture**:
```yaml
Proposed VLANs:
  VLAN 10 (DMZ):
    - Archon (CT183)
    - Harbor (CT182)
    - Public-facing services
    - Firewall rules: HTTP/HTTPS only

  VLAN 20 (Application):
    - CT179 (Development)
    - CT180 (Dokploy)
    - Application containers
    - Firewall rules: DB access only

  VLAN 30 (Database):
    - PostgreSQL
    - MariaDB
    - Redis
    - Firewall rules: Application VLAN only

  VLAN 40 (Management):
    - Proxmox hosts
    - Monitoring
    - Backup services
    - Firewall rules: VPN only
```

- [ ] VLAN design document created
- [ ] Firewall rules documented per VLAN
- [ ] Inter-VLAN communication rules defined
- [ ] VPN access requirements defined

### 3.2 Firewall Configuration

**Proxmox Firewall**:
```bash
# Example firewall rules to implement
pvesh set /nodes/<node>/firewall/options \
  --input_policy ACCEPT \
  --output ACCEPT \
  --enable 1

# Add rules to each container
for ct in CT179 CT180 CT182 CT183; do
  pct exec $ct -- iptables -A INPUT -i lo -j ACCEPT
  pct exec $ct -- iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  pct exec $ct -- iptables -A INPUT -s 10.6.0.0/24 -j ACCEPT  # WireGuard
  pct exec $ct -- iptables -A INPUT -s 100.64.0.0/10 -j ACCEPT  # Tailscale
  pct exec $ct -- iptables -A INPUT -p tcp --dport 22 -j ACCEPT  # SSH (VPN only)
  pct exec $ct -- iptables -A INPUT -p tcp --dport 443 -j ACCEPT  # HTTPS
  pct exec $ct -- iptables -A INPUT -j DROP  # Deny all else
done
```

- [ ] Firewall enabled on all containers
- [ ] Default DROP policy configured
- [ ] VPN networks whitelisted (WireGuard, Tailscale)
- [ ] Specific ports only allowed
- [ ] Firewall rules persistent across reboots

**Host-Level Firewall**:
- [ ] iptables rules on all Proxmox hosts
- [ ] ufw/iptables configured
- [ ] Only necessary ports open
- [ ] Intrusion detection (fail2ban)

### 3.3 HTTPS for Internal Services

**SSL/TLS Setup**:
- [ ] CA certificate created (internal)
- [ ] Wildcard cert for *.internal.aglz.io
- [ ] Certificates deployed to all services
- [ ] Nginx reverse proxy with TLS
- [ ] HTTP redirects to HTTPS

**Services to Secure**:
- [ ] Archon MCP: http://192.168.0.183:8052 → https
- [ ] Archon MCP Tailscale: http://100.80.30.59:8051 → https
- [ ] Harbor: Already HTTPS
- [ ] Dokploy: Already HTTPS
- [ ] Portainer: Already HTTPS

**Verification**:
```bash
# Test each service
curl -k https://archon.internal.aglz.io:8443/mcp
# Expected: Valid SSL handshake
```

### 3.4 Zero Trust Architecture (Optional/Phase 2)

**Service Mesh**:
- [ ] Service mesh evaluated (Istio/Linkerd)
- [ ] mTLS between services
- [ ] Service identity (SPIFFE)
- [ ] Policy enforcement

**Zero Trust Principles**:
- [ ] Identity verified every request
- [ ] Least privilege access
- [ ] Assume breach mentality
- [ ] Micro-segmentation

---

## Phase 4: Vulnerability Scanning & Compliance (Week 7-8)

### 4.1 Container Scanning

**Trivy Scanning** (already implemented):
```yaml
# .github/workflows/security-scan.yml
- name: Run Trivy
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ${{ env.IMAGE_NAME }}
    format: 'sarif'
    severity: 'CRITICAL,HIGH'
```

- [ ] Trivy scans all images
- [ ] Scans on every build
- [ ] Blocks on CRITICAL vulnerabilities
- [ ] Warns on HIGH vulnerabilities
- [ ] SARIF uploads to GitHub Security

**Grype Scanning** (complementary):
```yaml
# Add to CI/CD
- name: Run Grype
  uses: anchore/grype-action@v0
  with:
    image-ref: ${{ env.IMAGE_NAME }}:latest
    format: sarif
    severity: CRITICAL,HIGH
```

- [ ] Grype added to pipeline
- [ ] Results compared with Trivy
- [ ] Complementary coverage validated

### 4.2 Dependency Scanning

**npm audit**:
- [ ] npm audit in CI/CD
- [ ] npm audit fix on schedule
- [ ] Vulnerability tracking
- [ ] Automate patching where possible

**composer audit**:
- [ ] composer audit in CI/CD
- [ ] Security advisories monitored
- [ ] Patch process documented

### 4.3 OWASP Top 10 Compliance

**Target: 90%+ Compliance**

**A01: Broken Access Control** (Current: 70% → Target: 90%)
- [ ] IDOR testing completed
- [ ] Authorization checks on all routes
- [ ] No direct object references without auth
- [ ] API permission testing

**A02: Cryptographic Failures** (Current: 60% → Target: 90%)
- [ ] All secrets encrypted at rest
- [ ] TLS for all data transit
- [ ] No hardcoded encryption keys
- [ ] Strong ciphers only

**A03: Injection** (Current: 90% → Target: 95%)
- [ ] Parameterized queries (Eloquent) - ✅
- [ ] Input validation on all endpoints
- [ ] ORM usage enforced
- [ ] No raw SQL queries

**A04: Insecure Design** (Current: 75% → Target: 85%)
- [ ] Threat modeling completed
- [ ] Security architecture reviewed
- [ ] Business logic abuse testing

**A05: Security Misconfiguration** (Current: 55% → Target: 90%)
- [ ] Debug mode disabled in production
- [ ] Default credentials changed
- [ ] Security headers configured
- [ ] Error handling doesn't leak info

**A06: Vulnerable Components** (Current: 60% → Target: 85%)
- [ ] Dependency inventory maintained
- [ ] Vulnerability scanning in CI/CD
- [ ] Patching SLA defined
- [ ] No @latest in production

**A07: Authentication Failures** (Current: 75% → Target: 90%)
- [ ] Strong password policy - ✅
- [ ] MFA available
- [ ] Session timeout configured - ✅
- [ ] Secure session cookies - ✅

**A08: Data Integrity Failures** (Current: 70% → Target: 85%)
- [ ] Code signing implemented
- [ ] Checksums verified
- [ ] Immutable backups (AGL-22)
- [ ] Audit log integrity

**A09: Logging Failures** (Current: 80% → Target: 90%)
- [ ] Audit logging comprehensive - ✅
- [ ] Log integrity protected
- [ ] Log monitoring/alerting
- [ ] Log retention policy

**A10: Server-Side SSRF** (Current: 85% → Target: 95%)
- [ ] URL validation implemented
- [ ] Network egress controls
- [ ] Allow-list for external calls

### 4.4 SOC2 Readiness (Target: 80%)

**CC6.1 Logical Access**:
- [ ] Unique user accounts
- [ ] Access review process
- [ ] Access revocation procedure

**CC6.6 Security Logging**:
- [ ] Audit trail for all access
- [ ] Log retention: 90 days
- [ ] Log tamper protection

**CC6.7 Privileged Access**:
- [ ] Privileged access request process
- [ ] Privileged session monitoring
- [ ] Just-in-time access

**CC7.2 Encryption**:
- [ ] Data encryption at rest
- [ ] Data encryption in transit
- [ ] Key management process

**CC9.2 Transmission**:
- [ ] HTTPS for all connections
- [ ] SSH with keys only
- [ ] VPN required for admin access

---

## Phase 5: Documentation & Training (Week 9-10)

### 5.1 Security Documentation

**Required Documents**:
- [ ] Security architecture diagram
- [ ] Network topology diagram
- [ ] Firewall rules documentation
- [ ] Secret management runbook
- [ ] Incident response plan
- [ ] Security acceptance criteria

**Policies**:
- [ ] Access control policy
- [ ] Password policy
- [ ] Acceptable use policy
- [ ] Data classification policy
- [ ] Incident response policy

### 5.2 Security Training

**Team Training**:
- [ ] Security awareness training
- [ ] OWASP Top 10 training
- [ ] Secure coding practices
- [ ] Phishing awareness
- [ ] Incident response procedures

**Verification**:
- [ ] Training attendance documented
- [ ] Knowledge assessment quiz
- [ ] Practical exercises completed

### 5.3 Automated Security Testing

**Pre-commit Hooks**:
```bash
#!/bin/bash
# .git/hooks/pre-commit
# Scan for secrets
trufflehog filesystem --directory ./
if [ $? -ne 0 ]; then
  echo "Secrets detected! Aborting commit."
  exit 1
fi
```

- [ ] TruffleHog in pre-commit
- [ ] Gitleaks in pre-commit
- [ ] Security linting in CI/CD

---

## Validation Test Cases

### Test Case 1: Credential Security

**Objective**: Verify no credentials exposed

**Steps**:
1. Run gitleaks scan on repository
2. Check /root/.claude.json permissions
3. Check .env files permissions
4. Search for credentials in docs

**Expected Results**:
- [ ] No secrets in git
- [ ] File permissions: 600
- [ ] No credentials in documentation
- [ ] No hardcoded secrets in code

**Pass/Fail**: [ ]

### Test Case 2: Vault Operations

**Objective**: Verify Vault stores and serves secrets

**Steps**:
1. Write test secret to Vault
2. Read test secret from Vault
3. Access secret from application
4. Rotate secret
5. Test application with new secret

**Expected Results**:
- [ ] Secret written successfully
- [ ] Secret read successfully
- [ ] Application can access secret
- [ ] Rotation completed
- [ ] Audit log of access

**Pass/Fail**: [ ]

### Test Case 3: MCP Authentication

**Objective**: Verify MCP servers require authentication

**Steps**:
1. Call MCP without auth → expect 401/403
2. Call MCP with invalid auth → expect 403
3. Call MCP with valid auth → expect 200
4. Test rate limiting (exceed limit)

**Expected Results**:
- [ ] Unauthenticated requests blocked
- [ ] Invalid credentials rejected
- [ ] Valid credentials accepted
- [ ] Rate limiting enforced

**Pass/Fail**: [ ]

### Test Case 4: Network Segmentation

**Objective**: Verify VLAN isolation

**Steps**:
1. Attempt DMZ → Application (should block)
2. Attempt Application → Database (should allow)
3. Attempt Management from non-VPN (should block)
4. Attempt inter-VLAN access (should respect rules)

**Expected Results**:
- [ ] Unexpected traffic blocked
- [ ] Allowed traffic permitted
- [ ] Firewall rules active
- [ ] VPN-only access enforced

**Pass/Fail**: [ ]

### Test Case 5: Security Scanning

**Objective**: Verify vulnerability scanning

**Steps**:
1. Trigger security scan in CI/CD
2. Intentional vulnerable dependency
3. Verify scan catches vulnerability
4. Fix and re-scan
5. Verify clean result

**Expected Results**:
- [ ] Trivy scan runs
- [ ] Vulnerabilities detected
- [ ] Blocks on CRITICAL
- [ ] Clean build passes

**Pass/Fail**: [ ]

---

## Security Score Calculation

### Pre-Implementation Score: 70/100 (C-)

| Category | Weight | Score | Weighted Score |
|----------|--------|-------|---------------|
| MCP Security | 20% | 40% | 8.0 |
| Secrets Management | 25% | 30% | 7.5 |
| Network Security | 15% | 65% | 9.75 |
| RBAC | 10% | 80% | 8.0 |
| Vulnerability Scanning | 15% | 75% | 11.25 |
| Backup Security | 10% | 60% | 6.0 |
| Compliance | 5% | 55% | 2.75 |
| **Total** | **100%** | **-** | **70.25** |

### Post-Implementation Target: 90/100 (A-)

| Category | Weight | Target | Weighted Score |
|----------|--------|--------|---------------|
| MCP Security | 20% | 95% | 19.0 |
| Secrets Management | 25% | 95% | 23.75 |
| Network Security | 15% | 85% | 12.75 |
| RBAC | 10% | 85% | 8.5 |
| Vulnerability Scanning | 15% | 90% | 13.5 |
| Backup Security | 10% | 85% | 8.5 |
| Compliance | 5% | 85% | 4.25 |
| **Total** | **100%** | **-** | **90.25** |

---

## Sign-off Criteria

### Minimum Viable Product (MVP)

For AGL-20 to be marked as MVP complete:

**Critical Issues Resolved**:
- [ ] All exposed credentials rotated
- [ ] Vault deployed and operational
- [ ] MCP servers have authentication
- [ ] HTTPS enabled on internal services
- [ ] Configuration files secured (chmod 600)

**Security Improvements**:
- [ ] Security Grade: C- → B+
- [ ] OWASP Compliance: 70% → 80%
- [ ] No critical vulnerabilities (CVSS 9.0+)
- [ ] Basic network segmentation

**Validation**:
- [ ] Test Cases 1-3 pass
- [ ] Team trained on Vault
- [ ] Security documentation updated

### Full Implementation

For AGL-20 to be marked as fully complete:

**All MVP Criteria** plus:
- [ ] Network segmentation implemented
- [ ] Zero trust foundation
- [ ] OWASP Compliance: 90%+
- [ ] SOC2 Readiness: 80%+
- [ ] Automated security scanning
- [ ] Complete security runbooks
- [ ] Team security training complete
- [ ] Security Grade: A (90%+)

---

## Issue Tracking

### Blockers & Dependencies

| Issue | Description | Impact | Resolution |
|-------|-------------|---------|------------|
| | | | |

### Notes & Observations

| Date | Note | Author |
|------|-------|--------|
| | | |

---

## Appendix

### Appendix A: Security Tools Reference

| Tool | Purpose | Documentation |
|------|---------|---------------|
| HashiCorp Vault | Secrets management | https://vaultproject.io/docs |
| Trivy | Container scanning | https://aquasecurity.github.io/trivy |
| Grype | Vulnerability scanning | https://github.com/anchore/grype |
| Gitleaks | Secret detection | https://github.com/gitleaks/gitleaks |
| TruffleHog | Secret detection | https://github.com/trufflesecurity/trufflehog |

### Appendix B: OWASP Resources

- [OWASP Top 10 2021](https://owasp.org/Top10/)
- [OWASP Security Verification Standard](https://owasp.org/www-project-application-security-verification-standard/)
- [OWASP Cheat Sheet Series](https://cheatsheetseries.owasp.org/)

### Appendix C: Sample Vault Commands

```bash
# Write secret
vault kv put agl/mcp/dokploy/api-key-1 \
  key="value" \
  ttl="90d" \
  description="Dokploy API key #1"

# Read secret
vault kv get -field=key agl/mcp/dokploy/api-key-1

# List secrets
vault kv list agl/mcp

# Delete secret
vault kv delete agl/mcp/dokploy/api-key-1

# Rotate secret
vault kv patch agl/mcp/dokploy/api-key-1 \
  key="new-value" \
  ttl="90d"

# Audit log
vault audit list
vault audit list file
```

---

**Checklist Completed By**: _________________
**Date**: ___________________
**Security Review By**: _________________
**Sign-off Date**: ___________________
**Status**: [ ] MVP Complete [ ] Fully Complete [ ] Security Audit Passed

**END OF AGL-20 VALIDATION CHECKLIST**
