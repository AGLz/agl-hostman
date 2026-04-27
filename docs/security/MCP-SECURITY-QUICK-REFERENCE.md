# MCP Security Quick Action Guide
**Generated**: 2026-02-07

## CRITICAL STATUS - IMMEDIATE ACTION REQUIRED

Your MCP configuration has **CRITICAL security vulnerabilities**. Multiple API keys, tokens, and credentials are exposed in plaintext.

---

## 5-Minute Immediate Actions

### 1. Rotate Cloudflare Credentials (CRITICAL)
```bash
# Login to Cloudflare Dashboard
# Navigate: My Profile > API Tokens
# Revoke token: nxdMODvpFhSL146A2OuMZc755FoOKNfi1gfNG3q8
# Create new token with minimal permissions
# Update both locations:
#   - /root/.claude.json (lines 312, 315)
#   - /mnt/overpower/apps/dev/agl/agl-hostman/.env
```

### 2. Change Harbor Password (CRITICAL)
```bash
# Current: admin / Harbor12345 (DEFAULT!)
# Login to Harbor at https://harbor.aglz.io:5000
# Change admin password immediately
# Update /root/.claude.json line 283
# Set HARBOR_INSECURE to "false"
```

### 3. Revoke Azure DevOps PAT (CRITICAL)
```bash
# Login to Azure DevOps
# Navigate: User Settings > Personal Access Tokens
# Revoke: 6uqIM6lgvpo6X5dHucJZ4lNp0EiXyXGaWIxeBH1tJ4CovEABlM7jJQQJ99BHACAAAAAAAAAAAAASAZDO3yv6
# Create new PAT with scoped permissions
# Update /root/.claude.json line 762
```

### 4. Secure Configuration Files
```bash
chmod 600 /root/.claude.json
chmod 600 /mnt/overpower/apps/dev/agl/agl-hostman/.env
chown root:root /root/.claude.json
```

---

## All Exposed Credentials Summary

| Service | Credential | Location | Severity |
|---------|-----------|----------|----------|
| Ref.tools | `ref-e20b13163dcf630b474a` | /root/.claude.json:135 | HIGH |
| Dokploy #1 | `aglzFuGYRiMUTksduxs...` | /root/.claude.json:259 | CRITICAL |
| Harbor | `admin / Harbor12345` | /root/.claude.json:283 | CRITICAL |
| Portainer | `ptr_tPhR+YNqloPJX...` | /root/.claude.json:300 | CRITICAL |
| Cloudflare | `nxdMODvpFhSL146A2Ou...` | /root/.claude.json:315 + .env | CRITICAL |
| Exa AI | `60be63f8-c368-4241...` | /root/.claude.json:326 | MEDIUM |
| Azure DevOps | `6uqIM6lgvpo6X5dHuc...` | /root/.claude.json:762 | CRITICAL |
| Dokploy #2 | `cursorRdjGgePxAuOIR...` | /root/.claude.json:801 | CRITICAL |
| Z.AI | `896fb1e6936a4cd1b61...` | /root/.claude.json:812,823,831,838 | HIGH |

---

## Remediation Priority

### Priority 1 (Do NOW - Within 24 hours)
1. Rotate Cloudflare API token (DNS hijacking risk)
2. Change Harbor admin password (container registry risk)
3. Revoke Azure DevOps PAT (code exfiltration risk)
4. Rotate Dokploy API keys (deployment platform risk)
5. Revoke Portainer token (container management risk)

### Priority 2 (Do within 1 week)
6. Rotate Z.AI API keys
7. Rotate Ref API key
8. Rotate Exa API key
9. Enable HTTPS for internal services
10. Remove HARBOR_INSECURE flag

### Priority 3 (Do within 1 month)
11. Implement secrets manager (Vault/1Password)
12. Enable audit logging
13. Implement secret scanning in CI/CD
14. Network segmentation
15. Regular credential rotation schedule

---

## Secret Scanning Commands

```bash
# Run the remediation script
bash /mnt/overpower/apps/dev/agl/agl-hostman/scripts/security/audit-mcp-security.sh

# Install trufflehog
go install github.com/trufflesecurity/trufflehog/v3/cmd/trufflehog@latest

# Scan for secrets
trufflehog filesystem /root/.claude.json
trufflehog filesystem /mnt/overpower/apps/dev/agl/agl-hostman/.env

# Gitleaks scan
wget -qO - https://github.com/zricethezav/gitleaks/releases/latest/download/gitleaks-linux-amd64 > /tmp/gitleaks
install /tmp/gitleaks /usr/local/bin/gitleaks
gitleaks detect --source /root/.claude.json --no-git
```

---

## Secrets Management Options

### Quick Fix (Environment Variables)
```bash
# Create secure .env file
cat > /root/.claude/.env << 'EOF'
DOKPLOY_API_KEY=${DOKPLOY_API_KEY}
HARBOR_PASSWORD=${HARBOR_PASSWORD}
PORTAINER_TOKEN=${PORTAINER_TOKEN}
CLOUDFLARE_API_TOKEN=${CLOUDFLARE_API_TOKEN}
EOF

chmod 600 /root/.claude/.env
```

### Recommended (HashiCorp Vault)
```bash
# Install Vault
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
apt-get update && apt-get install vault

# Store secrets
vault kv put secret/mcp/dokploy api_key="${NEW_API_KEY}"
vault kv put secret/mcp/harbor password="${NEW_PASSWORD}"
```

### Alternative (1Password CLI)
```bash
# Install op CLI
curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
  sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg

# Use secret references
op://Development/Dokploy/api-key
op://Development/Harbor/password
```

---

## Files to Review

1. `/root/.claude.json` - Main MCP configuration with exposed credentials
2. `/mnt/overpower/apps/dev/agl/agl-hostman/.env` - Project environment file with Cloudflare credentials
3. `/root/.claude.json` backup directory - May contain historical credentials

---

## Prevention Measures

### 1. Never Commit Credentials
```bash
# Add to .gitignore
echo ".env" >> .gitignore
echo "*.key" >> .gitignore
echo "*_secret*" >> .gitignore
```

### 2. Pre-commit Hooks
```bash
#!/bin/bash
# .git/hooks/pre-commit
# Scan for secrets before commit
trufflehog filesystem .
if [ $? -ne 0 ]; then
  echo "Secrets detected! Commit aborted."
  exit 1
fi
```

### 3. GitHub Secret Scanning
- Enable secret scanning in repository settings
- Set up push protection for detected secrets
- Configure webhook notifications

---

## Compliance Status

| Standard | Status | Issues |
|----------|--------|--------|
| OWASP A01 (Access Control) | FAILED | Default Harbor credentials |
| OWASP A02 (Crypto) | FAILED | Plaintext secrets, HTTP endpoints |
| OWASP A05 (Misconfig) | FAILED | HARBOR_INSECURE flag |
| OWASP A07 (Auth) | FAILED | Multiple exposed API keys |
| SOC2 CC6.1 | FAILED | Access control violations |
| SOC2 CC6.6 | FAILED | No audit logging |
| SOC2 CC7.2 | FAILED | No encryption at rest |

---

## Monitoring & Detection

```bash
# Enable MCP audit logging
export MCP_AUDIT_LOG=/var/log/mcp/audit.log
export MCP_AUDIT_LEVEL=detailed

# Monitor credential usage
tail -f /var/log/mcp/audit.log | grep -i "api_key\|token\|password"

# Set up alerts for failed authentication
grep -i "failed.*auth\|unauthorized" /var/log/mcp/audit.log
```

---

## Contact Information

- **Security Team**: Create security@yourdomain.com
- **Infrastructure Lead**: infra@yourdomain.com
- **On-Call**: Configure on-call rotation

---

## Resources

- **Full Audit Report**: `/mnt/overpower/apps/dev/agl/agl-hostman/docs/security/MCP-SECURITY-AUDIT-2026-02-07.md`
- **Remediation Script**: `/mnt/overpower/apps/dev/agl/agl-hostman/scripts/security/audit-mcp-security.sh`
- **Credential Checklist**: `/root/.claude/credential-rotation-checklist.md` (generated by script)

---

## Immediate Next Steps

1. Run: `bash /mnt/overpower/apps/dev/agl/agl-hostman/scripts/security/audit-mcp-security.sh`
2. Review: `/root/.claude/credential-rotation-checklist.md`
3. Start rotating credentials in Priority 1 order
4. Document all rotations
5. Re-run security scan after remediation

**Remember: Security is a continuous process. Schedule regular audits and credential rotations.**
