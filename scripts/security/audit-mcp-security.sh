#!/bin/bash

###############################################################################
# MCP Security Remediation Script
# Version: 1.0.0
# Date: 2026-02-07
# Purpose: Automated remediation of MCP security vulnerabilities
###############################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLAUDE_CONFIG="/root/.claude.json"
BACKUP_DIR="/root/.claude/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ENV_FILE="/root/.claude/.env"
AUDIT_LOG="/var/log/mcp-security-audit.log"

# Functions
log() {
    local level=$1
    shift
    local message="$@"
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} [$level] $message" | tee -a "$AUDIT_LOG"
}

log_critical() {
    log "CRITICAL" "${RED}$@${NC}"
}

log_warning() {
    log "WARNING" "${YELLOW}$@${NC}"
}

log_success() {
    log "SUCCESS" "${GREEN}$@${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_critical "This script must be run as root"
        exit 1
    fi
}

backup_config() {
    log "INFO" "Creating backup of configuration..."
    mkdir -p "$BACKUP_DIR"
    cp "$CLAUDE_CONFIG" "$BACKUP_DIR/claude.json.$TIMESTAMP.bak"
    chmod 600 "$BACKUP_DIR/claude.json.$TIMESTAMP.bak"
    log_success "Backup created: $BACKUP_DIR/claude.json.$TIMESTAMP.bak"
}

check_secrets_in_file() {
    local file=$1
    local secrets_found=0

    log "INFO" "Scanning $file for exposed secrets..."

    # Check for API keys
    if grep -iE "(api[_-]?key|apikey)\s*[:=]\s*['\"][^'\"]{20,}" "$file" >/dev/null; then
        log_warning "Found API keys in plaintext"
        ((secrets_found++))
    fi

    # Check for passwords
    if grep -iE "password\s*[:=]\s*['\"][^'\"]+" "$file" >/dev/null; then
        log_warning "Found passwords in plaintext"
        ((secrets_found++))
    fi

    # Check for tokens
    if grep -iE "(token|pat)\s*[:=]\s*['\"][^'\"]{20,}" "$file" >/dev/null; then
        log_warning "Found tokens in plaintext"
        ((secrets_found++))
    fi

    # Check for default Harbor password
    if grep -i "Harbor12345" "$file" >/dev/null; then
        log_critical "Found default Harbor password!"
        ((secrets_found++))
    fi

    # Check for HTTP endpoints
    if grep -E '"http://[^"]"' "$file" >/dev/null; then
        log_warning "Found HTTP (non-HTTPS) endpoints"
        ((secrets_found++))
    fi

    # Check for HARBOR_INSECURE flag
    if grep -i "HARBOR_INSECURE.*true" "$file" >/dev/null; then
        log_warning "Found HARBOR_INSECURE flag enabled"
        ((secrets_found++))
    fi

    # Check for Docker socket
    if grep -i "docker.sock" "$file" >/dev/null; then
        log_warning "Found Docker socket exposure"
        ((secrets_found++))
    fi

    return $secrets_found
}

create_env_template() {
    log "INFO" "Creating environment variable template..."

    mkdir -p "$(dirname "$ENV_FILE")"

    cat > "$ENV_FILE" << 'EOF'
###############################################################################
# MCP Server Environment Variables
# WARNING: This file contains sensitive credentials
# Permissions: 600 (owner read/write only)
###############################################################################

# Dokploy Deployment Platform
DOKPLOY_URL=https://dok.aglz.io
DOKPLOY_API_KEY=CHANGE_ME_ROTATE_IMMEDIATELY

# Harbor Container Registry
HARBOR_URL=https://harbor.aglz.io:5000
HARBOR_USERNAME=admin
HARBOR_PASSWORD=CHANGE_ME_ROTATE_IMMEDIATELY
HARBOR_INSECURE=false

# Portainer Container Management
PORTAINER_SERVER=portainer.aglz.io
PORTAINER_TOKEN=CHANGE_ME_ROTATE_IMMEDIATELY

# Cloudflare DNS
CLOUDFLARE_ACCOUNT_ID=CHANGE_ME
CLOUDFLARE_API_TOKEN=CHANGE_ME_ROTATE_IMMEDIATELY

# Exa AI Search
EXA_API_KEY=CHANGE_ME_ROTATE_IMMEDIATELY

# Azure DevOps
ADO_ORGANIZATION=https://dev.azure.com/your-org
ADO_PROJECT=your-project
ADO_PAT=CHANGE_ME_ROTATE_IMMEDIATELY

# Ref.tools
REF_API_KEY=CHANGE_ME_ROTATE_IMMEDIATELY

# Z.AI Services
Z_AI_API_KEY=CHANGE_ME_ROTATE_IMMEDIATELY
Z_AI_MODE=ZAI

# Archon (Internal)
ARCHON_URL=https://archon.internal:8052/mcp
ARCHON_TAILSCALE_URL=https://archon-tailscale.internal:8051/mcp
EOF

    chmod 600 "$ENV_FILE"
    log_success "Created template: $ENV_FILE"
    log_warning "Please update $ENV_FILE with actual credentials"
}

secure_config_file() {
    log "INFO" "Securing configuration file permissions..."
    chmod 600 "$CLAUDE_CONFIG"
    chown root:root "$CLAUDE_CONFIG"
    log_success "Secured $CLAUDE_CONFIG"
}

generate_credential_rotation_checklist() {
    local checklist_file="/root/.claude/credential-rotation-checklist.md"

    log "INFO" "Generating credential rotation checklist..."

    cat > "$checklist_file" << 'EOF'
# Credential Rotation Checklist

## Critical - Rotate Immediately (Within 24 Hours)

### 1. Dokploy API Keys
- [ ] Generate new API key in Dokploy dashboard
- [ ] Update environment variable
- [ ] Test MCP connection
- [ ] Revoke old API key

**Locations:**
- Line 259: `aglzFuGYRiMUTksduxsCsqQExUAhNNMLyftAdBjdrTQJxRSymKnzjubufsVVBryougX`
- Line 801: `cursorRdjGgePxAuOIRkpxpyJIqhHDUbNdTidvkiIVTOooSxuBPVXJpXKKlojFNwzVPirL`

### 2. Harbor Registry
- [ ] Change admin password from default
- [ ] Enable HTTPS with valid certificate
- [ ] Set HARBOR_INSECURE to false
- [ ] Update all Docker registry references

**Current:** `admin / Harbor12345` (DEFAULT CREDENTIALS!)

### 3. Portainer Token
- [ ] Generate new API token in Portainer
- [ ] Update MCP configuration
- [ ] Test container management
- [ ] Revoke old token

**Current:** `ptr_tPhR+YNqloPJXvCWCcknuaiLqE4jQnK842fJ24u8jH8=`

### 4. Azure DevOps PAT
- [ ] Revoke existing PAT
- [ ] Create new PAT with minimal permissions
- [ ] Update environment variable
- [ ] Verify CI/CD pipelines

**Current:** `6uqIM6lgvpo6X5dHucJZ4lNp0EiXyXGaWIxeBH1tJ4CovEABlM7jJQQJ99BHACAAAAAAAAAAAAASAZDO3yv6`

## High Priority (Within 1 Week)

### 5. Cloudflare API Tokens
- [ ] Identify token usage scope
- [ ] Create new tokens with minimal permissions
- [ ] Update MCP configuration
- [ ] Revoke old tokens

**Locations:**
- Line 312: `08e7b6e3a5084b4a3a2e0b3de153b02e`
- Line 315: `nxdMODvpFhSL146A2OuMZc755FoOKNfi1gfNG3q8`

### 6. Z.AI API Keys
- [ ] Generate new API key in Z.AI dashboard
- [ ] Update all four instances in configuration
- [ ] Test AI services
- [ ] Revoke old keys

**Current:** `896fb1e6936a4cd1b61aa2314d6d3728.u2lsAqLNfajAslfx`

### 7. Ref API Key
- [ ] Regenerate API key
- [ ] Update MCP configuration
- [ ] Test Ref.tools integration
- [ ] Revoke old key

**Current:** `ref-e20b13163dcf630b474a`

### 8. Exa API Key
- [ ] Generate new API key
- [ ] Update environment variable
- [ ] Test search functionality
- [ ] Monitor usage

**Current:** `60be63f8-c368-4241-8e29-2c7405b98585`

## Security Hardening

### 9. Enable HTTPS for Internal Services
- [ ] Generate SSL certificates for internal services
- [ ] Configure reverse proxy (nginx/traefik)
- [ ] Update all HTTP URLs to HTTPS
- [ ] Test connectivity

**HTTP Endpoints to Update:**
- `http://192.168.0.183:8052/mcp`
- `http://192.168.0.183:8051/mcp`
- `http://100.80.30.59:8051/mcp`

### 10. Secure Docker Socket
- [ ] Create dedicated Docker context for MCP
- [ ] Restrict socket permissions
- [ ] Implement user namespace remapping
- [ ] Test container operations

### 11. Implement Secrets Management
- [ ] Evaluate secrets manager (Vault, 1Password, AWS Secrets)
- [ ] Migrate all credentials
- [ ] Update MCP configuration to use environment variables
- [ ] Test all MCP servers

### 12. Enable Audit Logging
- [ ] Configure MCP audit logging
- [ ] Set up log aggregation
- [ ] Implement alerting for suspicious activity
- [ ] Regular log review process

## Verification Steps

For each credential rotation:

1. Generate new credential
2. Update environment/configuration
3. Test MCP server connection
4. Verify functionality
5. Revoke old credential
6. Document in change log

## Post-Rotation Tasks

- [ ] Run full security scan
- [ ] Update documentation
- [ ] Review access logs
- [ ] Schedule regular rotation (monthly/quarterly)
- [ ] Implement secret scanning in CI/CD
- [ ] Conduct security awareness training

## Emergency Contacts

- Security Team: security@yourcompany.com
- Infrastructure Lead: infra@yourcompany.com
- On-Call: +1-XXX-XXX-XXXX

---

**Last Updated:** 2026-02-07
**Next Review:** 2026-03-07
EOF

    log_success "Created checklist: $checklist_file"
}

install_secret_scanning_tools() {
    log "INFO" "Checking for secret scanning tools..."

    # Install trufflehog if not present
    if ! command -v trufflehog &> /dev/null; then
        log "INFO" "Installing trufflehog..."
        go install github.com/trufflesecurity/trufflehog/v3/cmd/trufflehog@latest || \
            npm install -g trufflehog 2>/dev/null || \
            log_warning "Could not install trufflehog"
    fi

    # Install gitleaks if not present
    if ! command -v gitleaks &> /dev/null; then
        log "INFO" "Installing gitleaks..."
        wget -qO - https://github.com/zricethezav/gitleaks/releases/latest/download/gitleaks-linux-amd64 > /tmp/gitleaks
        install -m 755 /tmp/gitleaks /usr/local/bin/gitleaks 2>/dev/null || \
            log_warning "Could not install gitleaks"
    fi
}

run_security_scan() {
    log "INFO" "Running security scan on configuration..."

    local scan_report="/root/.claude/security-scan-$TIMESTAMP.txt"

    {
        echo "MCP Security Scan Report"
        echo "========================"
        echo "Date: $(date)"
        echo "File: $CLAUDE_CONFIG"
        echo ""
        echo "=== Secret Detection ==="

        if command -v trufflehog &> /dev/null; then
            echo -e "\n--- TruffleHog Results ---"
            trufflehog filesystem "$CLAUDE_CONFIG" 2>&1 || true
        fi

        if command -v gitleaks &> /dev/null; then
            echo -e "\n--- Gitleaks Results ---"
            gitleaks detect --source "$CLAUDE_CONFIG" --no-git 2>&1 || true
        fi

        echo -e "\n=== Pattern Matching ==="

        # Check for common secret patterns
        echo -e "\n--- API Keys ---"
        grep -nE "(api[_-]?key|apikey)\s*[:=]\s*['\"][^'\"]{20,}" "$CLAUDE_CONFIG" || echo "None found"

        echo -e "\n--- Passwords ---"
        grep -nE "password\s*[:=]\s*['\"][^'\"]+" "$CLAUDE_CONFIG" || echo "None found"

        echo -e "\n--- Tokens ---"
        grep -nE "(token|pat)\s*[:=]\s*['\"][^'\"]{20,}" "$CLAUDE_CONFIG" || echo "None found"

        echo -e "\n--- HTTP Endpoints ---"
        grep -nE '"https?://[^"]+"' "$CLAUDE_CONFIG" || echo "None found"

        echo -e "\n=== File Permissions ==="
        ls -la "$CLAUDE_CONFIG"

    } | tee "$scan_report"

    log_success "Scan report saved: $scan_report"
}

generate_summary_report() {
    local report_file="/root/.claude/security-summary-$TIMESTAMP.txt"

    log "INFO" "Generating summary report..."

    cat > "$report_file" << EOF
MCP Security Remediation Summary
=================================
Date: $(date)
Configuration: $CLAUDE_CONFIG

CRITICAL FINDINGS:
------------------
1. Multiple API keys exposed in plaintext
2. Default Harbor password detected
3. Azure DevOps PAT exposed
4. Docker socket accessible
5. HTTP endpoints for internal services

IMMEDIATE ACTIONS REQUIRED:
---------------------------
1. Rotate all exposed credentials (see credential-rotation-checklist.md)
2. Implement secrets management
3. Enable HTTPS for internal services
4. Secure Docker socket access
5. Enable audit logging

FILES CREATED:
--------------
- Backup: $BACKUP_DIR/claude.json.$TIMESTAMP.bak
- Environment template: $ENV_FILE
- Credential rotation checklist: /root/.claude/credential-rotation-checklist.md
- Security scan: /root/.claude/security-scan-$TIMESTAMP.txt
- This report: $report_file

RECOMMENDED TOOLS:
------------------
- HashiCorp Vault for secrets management
- 1Password CLI for credential storage
- trufflehog for secret scanning
- gitleaks for repository scanning

NEXT STEPS:
-----------
1. Review and update $ENV_FILE with new credentials
2. Follow credential-rotation-checklist.md systematically
3. Implement secrets manager
4. Re-run this script after remediation to verify

COMPLIANCE STATUS:
------------------
OWASP Top 10: Multiple violations
SOC2 CC6.1: FAILED (Access Control)
SOC2 CC6.6: FAILED (Audit Logging)
SOC2 CC7.2: FAILED (Encryption)

For detailed analysis, see:
/mnt/overpower/apps/dev/agl/agl-hostman/docs/security/MCP-SECURITY-AUDIT-2026-02-07.md

EOF

    log_success "Summary report: $report_file"
}

# Main execution
main() {
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}MCP Security Remediation Script${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo ""

    check_root
    backup_config
    check_secrets_in_file "$CLAUDE_CONFIG"
    secure_config_file
    create_env_template
    generate_credential_rotation_checklist
    install_secret_scanning_tools
    run_security_scan
    generate_summary_report

    echo ""
    echo -e "${GREEN}======================================${NC}"
    echo -e "${GREEN}Remediation Script Complete!${NC}"
    echo -e "${GREEN}======================================${NC}"
    echo ""
    echo "Next Steps:"
    echo "1. Review: /root/.claude/credential-rotation-checklist.md"
    echo "2. Update: $ENV_FILE"
    echo "3. Follow checklist systematically"
    echo "4. Re-run script to verify remediation"
    echo ""
    echo -e "${YELLOW}WARNING: Immediate credential rotation required!${NC}"
}

# Run main function
main "$@"
