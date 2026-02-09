# Security Hardening Implementation Guide

**Task ID**: e089f160-fe72-4f86-8b22-7ed8a73939bc
**Project**: AGL Hostman (550e8400-e29b-41d4-a716-446655440000)
**Date**: 2026-02-08
**Status**: Ready for Implementation

---

## Implementation Priority Matrix

| Priority | Task | Effort | Impact | Timeline |
|----------|------|--------|--------|----------|
| P0-CRITICAL | Rotate exposed credentials | 4h | Critical | Week 1 |
| P0-CRITICAL | Implement secrets management | 8h | Critical | Week 1-2 |
| P0-CRITICAL | Secure MCP servers | 6h | Critical | Week 1 |
| P1-HIGH | Enable network segmentation | 12h | High | Week 2 |
| P1-HIGH | Configure firewall rules | 4h | High | Week 2 |
| P1-HIGH | Implement backup encryption | 6h | High | Week 2 |
| P2-MEDIUM | Automated dependency scanning | 4h | Medium | Week 3 |
| P2-MEDIUM | Set up centralized logging | 8h | Medium | Week 3 |
| P3-LOW | Implement 2FA | 12h | Low | Week 4 |
| P3-LOW | Penetration testing | 16h | Low | Week 4 |

---

## Phase 1: Critical Security Fixes (Week 1)

### 1.1 Credential Rotation

**File**: `scripts/security/rotate-credentials.sh`

```bash
# Execute credential rotation
cd /mnt/overpower/apps/dev/agl/agl-hostman
sudo ./scripts/security/rotate-credentials.sh
```

**What it does**:
- Rotates all exposed credentials from documentation
- Generates secure random passwords
- Updates services (Archon, Harbor, Grafana)
- Cleans credentials from documentation
- Installs git pre-commit hooks

**Expected Output**:
- New credentials stored in `/tmp/agl-credentials-YYYYMMDD.txt`
- Services updated with new passwords
- Documentation cleaned
- Pre-commit hook installed

---

### 1.2 MCP Server Security

**Files Created**:
- `config/security/mcp-security.php` - MCP security configuration
- `src/app/Http/Middleware/McpSecurity.php` - MCP security middleware

**Implementation Steps**:

1. **Add environment variables to `.env`**:
```env
# MCP API Keys
MCP_LARAVEL_BOOST_KEY=your_secure_key_here
MCP_SHADCN_KEY=your_secure_key_here
MCP_RUV_SWARM_KEY=your_secure_key_here

# MCP Security Settings
MCP_RATE_LIMITING_ENABLED=true
MCP_RATE_LIMIT_MAX_ATTEMPTS=60
MCP_IP_WHITELIST_ENABLED=false
MCP_AUDIT_LOGGING_ENABLED=true
```

2. **Generate MCP API keys**:
```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman/src
php artisan tinker
>>> \Illuminate\Support\Str::random(64);
```

3. **Register middleware** in `app/Http/Kernel.php`:
```php
protected $middlewareGroups = [
    'web' => [
        // ... existing middleware
        \App\Http\Middleware\McpSecurity::class,
    ],
];
```

4. **Apply to routes** in `routes/api.php`:
```php
Route::prefix('mcp')->middleware(['mcp.security'])->group(function () {
    Route::post('/laravel-boost', 'McpController@laravelBoost');
    Route::post('/shadcn', 'McpController@shadcn');
});
```

---

### 1.3 Secrets Management Setup

**Recommendation**: HashiCorp Vault

**Installation**:
```bash
# Create Vault container
docker run -d \
  --name vault \
  -p 8200:8200 \
  -e 'VAULT_DEV_ROOT_TOKEN_ID=your-root-token' \
  -v vault-data:/vault/data \
  hashicorp/vault:latest server -dev

# Enable KV secrets engine
docker exec vault vault secrets enable -path=agl kv-v2

# Store secrets
docker exec vault vault kv put agl/archon username="admin" password="..."
docker exec vault vault kv put agl/harbor username="admin" password="..."
```

**Integration with Laravel**:
```bash
composer require laravel-vault/vault
```

---

## Phase 2: High Priority Security (Week 2)

### 2.1 Network Segmentation

**Current State**:
- All services on `192.168.0.0/24` network

**Target State**:
```
DMZ (10.6.0.0/24)
├── Archon: 10.6.0.21
└── VPN Gateway

Application (192.168.0.0/24)
├── Harbor: 192.168.0.182
├── Ollama: 192.168.0.200
└── Proxmox Hosts

Data (10.0.0.0/24)
├── Database Servers
└── Backup Storage
```

**Implementation**:
1. Create VLANs in Proxmox
2. Assign containers to appropriate VLANs
3. Configure firewall rules between zones

---

### 2.2 Firewall Configuration

**File**: `config/security/proxmox-firewall.sh`

```bash
# Execute firewall configuration
sudo ./config/security/proxmox-firewall.sh
```

**Rules Applied**:
- SSH from VPN only (TCP/22)
- HTTPS allowed (TCP/443)
- HTTP redirects to HTTPS (TCP/80)
- MCP endpoints with authentication (TCP/8051)
- WireGuard VPN (UDP/51820)
- Drop and log all other traffic

---

### 2.3 Backup Encryption

**Current Backup Script**:
```bash
# Existing backup script location
/mnt/overpower/apps/dev/agl/agl-hostman/scripts/backup/backup.sh
```

**Enhancement Required**:
```bash
# Encrypt backups with GPG
tar czf - /path/to/data | \
  gpg --encrypt --recipient admin@aglz.io | \
  dd of=/backup/agl-backup-$(date +%Y%m%d).tar.gz.gpg

# Decrypt for restoration
gpg --decrypt backup.tar.gz.gpg | tar xzf -
```

---

## Phase 3: Medium Priority Security (Week 3)

### 3.1 Automated Dependency Scanning

**NPM Audit**:
```bash
# Add to package.json scripts
"scripts": {
  "audit:security": "npm audit --audit-level=high",
  "audit:fix": "npm audit fix"
}
```

**Composer Audit**:
```bash
# Add to composer.json scripts
"scripts": {
  "audit": [
    "@composer audit --no-dev"
  ]
}
```

**GitHub Actions Workflow**:
```yaml
name: Security Scan
on: [push, pull_request]
jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: NPM Audit
        run: npm audit --audit-level=high
      - name: Composer Audit
        run: composer audit --no-dev
```

---

### 3.2 Centralized Logging

**Recommendation**: ELK Stack or Loki

**Quick Setup (Loki)**:
```yaml
# docker-compose.logging.yml
version: '3.8'
services:
  loki:
    image: grafana/loki:latest
    ports:
      - "3100:3100"
    volumes:
      - loki-data:/loki

  promtail:
    image: grafana/promtail:latest
    volumes:
      - /var/log:/var/log
      - ./promtail-config.yml:/etc/promtail/config.yml

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3001:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=your_password

volumes:
  loki-data:
```

---

## Phase 4: Low Priority Security (Week 4)

### 4.1 Two-Factor Authentication

**Options**:
1. Google Authenticator (TOTP)
2. Authy
3. Duo Security
4. FortiAuthenticator

**Laravel Package**:
```bash
composer require pragmarx/google2fa-laravel
php artisan vendor:publish --provider="PragmaRX\Google2FALaravel\ServiceProvider"
```

---

### 4.2 Penetration Testing

**Tools**:
- OWASP ZAP
- Burp Suite
- Nikto
- Nmap

**Command Examples**:
```bash
# Network scan
nmap -sV -sC 192.168.0.0/24

# Web vulnerability scan
zap-cli quick-scan --self-contained https://aglz.io

# Nikto scan
nikto -h https://aglz.io
```

---

## Verification Steps

### 1. Credential Rotation Verification
```bash
# Test new credentials
curl -u admin:NEW_PASSWORD https://archon.aglz.io
curl -u admin:NEW_PASSWORD https://harbor.aglz.io/api/v2.0/systeminfo
```

### 2. MCP Security Verification
```bash
# Test without API key (should fail)
curl -X POST https://aglz.io/api/mcp/test
# Expected: 401 Unauthorized

# Test with API key (should succeed)
curl -X POST \
  -H "X-API-Key: YOUR_KEY" \
  https://aglz.io/api/mcp/test
# Expected: 200 OK
```

### 3. Firewall Verification
```bash
# Test SSH from outside VPN (should fail)
ssh root@192.168.0.183
# Expected: Connection timeout

# Test SSH from VPN (should succeed)
ssh root@192.168.0.183
# Expected: Login prompt
```

### 4. Backup Encryption Verification
```bash
# List encrypted backups
ls -lh /backup/*.gpg

# Test decryption
gpg --decrypt /backup/test.tar.gz.gpg | tar tzf -
```

---

## Rollback Procedures

### If Credential Rotation Fails
```bash
# Restore from backup
cp .env.backup .env
git checkout .env

# Restart services
systemctl restart nginx
docker-compose restart
```

### If MCP Security Breaks Services
```bash
# Remove middleware from Kernel.php
# Comment out: \App\Http\Middleware\McpSecurity::class

# Clear cache
php artisan cache:clear
php artisan config:clear
```

### If Firewall Blocks Access
```bash
# Access via Proxmox console
pct enter <CTID>

# Flush iptables rules
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X

# Restore from backup
iptables-restore < /var/backups/iptables-backup.rules
```

---

## Monitoring and Alerts

### Key Metrics to Monitor
- Failed authentication attempts (>5/hour triggers alert)
- Successful logins from unusual locations
- API rate limit violations
- Firewall deny logs
- Backup encryption failures
- Vulnerability scan results

### Alert Configuration
```yaml
# Prometheus alerting rules
groups:
  - name: security
    rules:
      - alert: HighFailedAuth
        expr: rate(auth_failures_total[5m]) > 0.1
        for: 5m
        annotations:
          summary: "High rate of authentication failures"

      - alert: VulnerabilityDetected
        expr: vulnerability_count > 0
        annotations:
          summary: "Security vulnerabilities detected"
```

---

## Documentation Links

- Security Audit Report: `docs/security/SECURITY-AUDIT-REPORT-2026-02-08.md`
- Security Policy: `docs/security/SECURITY-POLICY.md`
- MCP Configuration: `config/security/mcp-security.php`
- Credential Rotation: `scripts/security/rotate-credentials.sh`
- Firewall Configuration: `config/security/proxmox-firewall.sh`

---

## Support and Escalation

| Severity | Contact | Response Time |
|----------|---------|---------------|
| Critical | security@aglz.io | 15 minutes |
| High | security@aglz.io | 1 hour |
| Medium | tech-lead@aglz.io | 4 hours |
| Low | Create GitHub issue | 24 hours |

---

## Next Steps

1. Review and approve this implementation plan
2. Schedule maintenance window for Week 1 changes
3. Assign responsibilities for each phase
4. Set up monitoring and alerting
5. Perform verification after each phase
6. Document any deviations or issues
7. Update security documentation

---

**Implementation Start Date**: TBD
**Planned Completion**: 4 weeks from start
**Assigned To**: Security Team
**Approved By**: _____________ **Date**: ________
