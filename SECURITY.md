# Security Guidelines - AGL Infrastructure

**Last Updated**: 2025-11-01
**Status**: 🔴 CRITICAL - Immediate action required

---

## 🚨 Critical Security Issues

### 1. Hardcoded Credentials in Documentation

**PROBLEM**: Multiple documentation files contain hardcoded credentials:

- **Archon Basic Auth**: `admin/ArchonPass2025` appears in 20+ files
- **Harbor Passwords**: Default and example passwords in deployment docs
- **API Keys**: Placeholder values in configuration examples

**AFFECTED FILES**:
- `CLAUDE.md:109`
- `docs/QUICK-START.md:275`
- `docs/ARCHON-DNS-FIX.md:114`
- `agent-os/specs/infrastructure/archon-integration.md` (multiple)
- `docs/archon-deployment-summary.md` (multiple)
- `docs/claude-md-v2.4.0-changes.md` (multiple)

**STATUS**: 🔴 **HIGH RISK** - These are REAL production credentials

---

## ✅ Immediate Actions Required

### 1. Rotate All Credentials (DO THIS NOW)

```bash
# Change Archon password immediately
ssh root@192.168.0.183
cd /root/archon
# Edit nginx/.htpasswd with new password
htpasswd -c nginx/.htpasswd admin
# Restart nginx container
docker restart archon-nginx-proxy

# Change Harbor admin password
# Login to https://harbor.aglz.io and change password via UI

# Generate new strong passwords
openssl rand -base64 32  # Use this for each service
```

### 2. Use Environment Variables

**Never hardcode credentials**. Always use `.env` files:

```bash
# Copy template
cp .env.example .env

# Edit with your actual credentials
nano .env

# Verify .env is in .gitignore
grep "^\.env$" .gitignore || echo ".env" >> .gitignore
```

### 3. Update Documentation References

When writing docs, use environment variable placeholders:

❌ **BAD**:
```bash
curl -u admin:ArchonPass2025 https://archon.aglz.io
```

✅ **GOOD**:
```bash
# Load credentials from .env
source .env
curl -u "$ARCHON_USERNAME:$ARCHON_PASSWORD" https://archon.aglz.io
```

Or reference the .env.example:
```bash
# See .env.example for credential configuration
curl -u admin:$ARCHON_PASSWORD https://archon.aglz.io
```

---

## 📋 Security Checklist

### Production Deployment

- [ ] All default passwords changed
- [ ] `.env` file created with production credentials
- [ ] `.env` added to `.gitignore`
- [ ] Credentials stored in secure vault (1Password, Bitwarden, etc.)
- [ ] No credentials in git history (if found, use `git filter-repo` to remove)
- [ ] Firewall rules configured (WireGuard/Tailscale only for sensitive services)
- [ ] SSL/TLS enabled for all public endpoints
- [ ] Regular credential rotation schedule established (90 days)

### Documentation

- [ ] Review all `.md` files for hardcoded credentials
- [ ] Replace with environment variable references
- [ ] Add security warnings to relevant docs
- [ ] Include `.env.example` references

### Code

- [ ] Use `dotenv` package to load environment variables
- [ ] Never log credentials (even in debug mode)
- [ ] Use secrets management service for sensitive data
- [ ] Encrypt credentials in configuration files
- [ ] Add pre-commit hooks to prevent credential commits

---

## 🔐 Password Requirements

**All passwords MUST meet these requirements**:

- **Minimum 16 characters**
- Mix of uppercase, lowercase, numbers, symbols
- No dictionary words
- No personal information
- Unique per service (never reuse passwords)

**Generate strong passwords**:
```bash
# Using openssl
openssl rand -base64 32

# Using pwgen
pwgen -s 32 1

# Using 1password CLI
op generate --length 32 --symbols
```

---

## 🛡️ Secrets Management

### Recommended Tools

**Personal/Homelab**:
- 1Password (best UX, $2.99/month)
- Bitwarden (open source, free)
- KeePassXC (offline, free)

**Team/Enterprise**:
- HashiCorp Vault
- AWS Secrets Manager
- Azure Key Vault
- Google Cloud Secret Manager

### Using 1Password CLI

```bash
# Install 1Password CLI
brew install --cask 1password-cli

# Store credential
op item create --category=password \
  --title="Archon Admin" \
  --vault="Infrastructure" \
  password="$(openssl rand -base64 32)"

# Retrieve credential
ARCHON_PASSWORD=$(op read "op://Infrastructure/Archon Admin/password")
curl -u "admin:$ARCHON_PASSWORD" https://archon.aglz.io
```

---

## 📝 Credential Rotation Schedule

| Service | Frequency | Last Rotated | Next Rotation |
|---------|-----------|--------------|---------------|
| Archon Basic Auth | 90 days | 2025-11-01 | 2026-02-01 |
| Harbor Admin | 90 days | TBD | TBD |
| Supabase Keys | 180 days | TBD | TBD |
| OpenAI API | Never (unless compromised) | N/A | N/A |
| GitHub Tokens | 90 days | TBD | TBD |

---

## 🔍 Detecting Credential Leaks

### Check Git History

```bash
# Scan for potential credentials
git log -p | grep -i -E "(password|secret|api_key|token)" | less

# Use automated tools
pip install truffleHog
truffleHog --regex --entropy=False .
```

### GitHub Secret Scanning

GitHub automatically scans for known credential patterns. If credentials are detected:

1. Rotate compromised credentials immediately
2. Remove from git history:
   ```bash
   git filter-repo --path-glob '**/*.env' --invert-paths
   ```
3. Force push (only if safe):
   ```bash
   git push --force-with-lease origin develop
   ```

---

## 📞 Incident Response

### If Credentials Are Compromised

1. **Immediate**:
   - Rotate all affected credentials
   - Revoke compromised keys/tokens
   - Review access logs for unauthorized access

2. **Within 24 hours**:
   - Investigate breach source
   - Document incident
   - Notify affected parties

3. **Within 1 week**:
   - Implement additional security controls
   - Update documentation
   - Review security practices

### Emergency Contacts

- Infrastructure Admin: [Your contact info]
- Security Team: [Your security contact]

---

## 📚 Resources

- [OWASP Password Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)
- [NIST Password Guidelines](https://pages.nist.gov/800-63-3/sp800-63b.html)
- [GitHub Secret Scanning](https://docs.github.com/en/code-security/secret-scanning)
- [1Password Security](https://1password.com/security/)

---

**Remember**: Security is not a one-time task, it's an ongoing process. Review and update these guidelines regularly.
