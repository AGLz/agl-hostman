# AGL Security Remediation Guide

**Last Updated**: 2026-02-10
**Audit Reference**: security-audit-report.md

## Overview

This guide provides step-by-step instructions to remediate security vulnerabilities identified in the AGL infrastructure audit.

## Vulnerability Summary

| Severity | Count | Status |
|----------|-------|--------|
| CRITICAL | 1 | Pending |
| HIGH | 2 | Pending |
| MEDIUM | 8 | Partially Fixed |
| LOW | 1 | Pending |

---

## Critical Priority Remediation

### 1. Hardcoded Linear API Token (CRITICAL)

**Issue**: LINEAR_API_TOKEN is hardcoded in `~/.config/claude/mcp.json`

**Remediation Steps**:

```bash
# Option 1: Run automated fix script
./scripts/security/fix-credentials.sh

# Option 2: Manual fix
```

1. Backup current configuration:
```bash
cp ~/.config/claude/mcp.json ~/.config/claude/mcp.json.backup
```

2. Get your Linear API token from: https://linear.app/settings/api

3. Set environment variable (choose one):

**For current session only:**
```bash
export LINEAR_API_TOKEN="lin_api_your_new_token_here"
```

**For persistence (Bash):**
```bash
echo 'export LINEAR_API_TOKEN="lin_api_your_new_token_here"' >> ~/.bashrc
source ~/.bashrc
```

**For persistence (Zsh):**
```bash
echo 'export LINEAR_API_TOKEN="lin_api_your_new_token_here"' >> ~/.zshrc
source ~/.zshrc
```

**For system-wide (requires sudo):**
```bash
echo 'export LINEAR_API_TOKEN="lin_api_your_new_token_here"' | sudo tee -a /etc/environment
```

4. Update MCP configuration:
```json
{
  "mcpServers": {
    "linear": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-linear"],
      "env": {
        "LINEAR_API_TOKEN": "${LINEAR_API_TOKEN}"
      }
    }
  }
}
```

5. Restart Claude Code

6. Verify by testing Linear integration

**Validation:**
```bash
# Check that environment variable is set
echo $LINEAR_API_TOKEN

# Verify MCP config doesn't contain hardcoded token
grep -i "lin_api_" ~/.config/claude/mcp.json || echo "No hardcoded token found"
```

---

## High Priority Remediation

### 2. Insecure Protocol for Archon MCP Server (HIGH)

**Issue**: Archon MCP server uses HTTP instead of HTTPS

**Current Configuration:**
```json
{
  "archon": {
    "type": "sse",
    "url": "http://192.168.0.183:8051/mcp"
  }
}
```

**Remediation Options:**

**Option A: Configure TLS/HTTPS on Archon Server**

1. Install TLS certificate on Archon server (192.168.0.183)

2. Update MCP configuration:
```json
{
  "archon": {
    "type": "sse",
    "url": "https://192.168.0.183:8051/mcp",
    "headers": {
      "Authorization": "Bearer YOUR_AUTH_TOKEN"
    }
  }
}
```

**Option B: Use Self-Signed Certificate (Development Only)**

```bash
# Generate self-signed certificate on Archon server
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes
```

Then update MCP config with HTTPS URL.

**Option C: Keep HTTP with Network Isolation (Not Recommended)**

If HTTP must be used:
- Ensure server is on private network only
- Configure firewall rules
- Use VPN for access
- Document as temporary workaround

---

### 3. Missing Authentication on Archon MCP (HIGH)

**Issue**: SSE MCP server without visible authentication

**Remediation:**

Add authentication headers to MCP configuration:

```json
{
  "archon": {
    "type": "sse",
    "url": "https://192.168.0.183:8051/mcp",
    "headers": {
      "Authorization": "Bearer YOUR_AUTH_TOKEN_HERE",
      "X-API-Key": "your_api_key_here"
    }
  }
}
```

**Token Storage:**
Store auth tokens in environment variables:

```bash
export ARCHON_AUTH_TOKEN="your_token_here"
export ARCHON_API_KEY="your_api_key_here"
```

Then reference in config:
```json
{
  "env": {
    "ARCHON_AUTH_TOKEN": "${ARCHON_AUTH_TOKEN}",
    "ARCHON_API_KEY": "${ARCHON_API_KEY}"
  }
}
```

---

## Medium Priority Remediation

### 4. Insecure File Permissions (MEDIUM) - PARTIALLY FIXED

**Status**: Fixed via `chmod 600` for .env files

**Files Fixed:**
- `/mnt/overpower/apps/dev/agl/agl-hostman/.env` (now 600)
- `/mnt/overpower/apps/dev/agl/agl-hostman/.env.example` (now 600)
- `/mnt/overpower/apps/dev/agl/agl-hostman/.env.example.security` (now 600)
- `/mnt/overpower/apps/dev/agl/agl-hostman/.env.security` (now 600)

**Ongoing:**
- Ensure all new .env files are created with secure permissions
- Add to project documentation

**Preventive Measures:**

Add to `~/.bashrc` or project setup script:
```bash
# Set default umask for secure file creation
umask 077

# Function to create secure .env files
mkenv() {
    touch "$1"
    chmod 600 "$1"
}
```

---

### 5. Docker Root User (LOW)

**Issue**: Containers may be running as root

**Remediation:**

Add user directive to docker-compose.yml:

```yaml
services:
  your-service:
    user: "${UID:-1000}:${GID:-1000}"
    # ... rest of config
```

Or use Dockerfile:
```dockerfile
FROM node:18-alpine
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001
USER nodejs
```

---

## Additional Security Hardening

### Install Security Scanning Tools

```bash
# Install Trivy
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install trivy

# Install Grype
curl -ssL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh

# Install Yamllint
sudo apt-get install yamllint

# Run comprehensive scan
trivy filesystem --security-checks vuln,config /mnt/overpower/apps/dev/agl/agl-hostman
grype dir /mnt/overpower/apps/dev/agl/agl-hostman
```

---

## Verification Checklist

After completing remediation:

- [ ] LINEAR_API_TOKEN stored in environment variable
- [ ] No hardcoded credentials in MCP configs
- [ ] Archon MCP using HTTPS (or documented HTTP exception)
- [ ] Authentication configured for all remote MCP servers
- [ ] All .env files have 600 permissions
- [ ] Docker containers run as non-root user
- [ ] Security scanning tools installed
- [ ] .gitignore includes sensitive files
- [ ] Regular security audits scheduled

---

## Monitoring and Maintenance

### Regular Security Tasks

**Daily:**
- Monitor access logs
- Review security alerts

**Weekly:**
- Run security audit script: `./scripts/security/security-audit.sh`
- Review vulnerability scanner results

**Monthly:**
- Rotate API keys and tokens
- Update dependencies
- Review and update security policies

**Quarterly:**
- Full security audit
- Penetration testing
- Compliance review

---

## Emergency Response

If credentials are leaked:

1. **Immediate Actions:**
   - Rotate all exposed credentials
   - Revoke compromised API tokens
   - Change passwords

2. **Investigation:**
   - Review access logs
   - Identify scope of exposure
   - Document incident

3. **Recovery:**
   - Update all affected systems
   - Notify stakeholders
   - Implement preventive measures

---

## Support and Resources

- Security Audit Script: `./scripts/security/security-audit.sh`
- Credentials Fix: `./scripts/security/fix-credentials.sh`
- Audit Report: `/docs/security-audit-report.md`

**References:**
- OWASP Top 10: https://owasp.org/www-project-top-ten/
- MCP Security: https://modelcontextprotocol.io/security
- Docker Security: https://docs.docker.com/engine/security/

---

**Document Version**: 1.0.0
**Last Modified**: 2026-02-10
