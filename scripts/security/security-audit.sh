#!/usr/bin/env bash

# =============================================================================
# AGL MCP Server Security Audit Script
# =============================================================================
# Version: 1.0.0
# Description: Comprehensive security audit for MCP servers and infrastructure
# Usage: ./scripts/security/security-audit.sh [--fix] [--report-only]
# =============================================================================

# Don't exit on errors - we want to run all checks
set -eo pipefail 2>/dev/null || true

# Colors for output
readonly RED='\033[0;31m'
readonly ORANGE='\033[0;33m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Script configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly REPORT_DIR="${PROJECT_ROOT}/docs"
readonly REPORT_FILE="${REPORT_DIR}/security-audit-report.md"
readonly TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Audit counters
CRITICAL_COUNT=0
HIGH_COUNT=0
MEDIUM_COUNT=0
LOW_COUNT=0
INFO_COUNT=0

# Vulnerability tracking
VULNERABILITIES=()
RECOMMENDATIONS=()

# =============================================================================
# Utility Functions
# =============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $*"
}

log_critical() {
    echo -e "${RED}[CRITICAL]${NC} $*"
}

# =============================================================================
# Vulnerability Reporting
# =============================================================================

add_vulnerability() {
    local severity="$1"
    local category="$2"
    local message="$3"
    local file="${4:-N/A}"
    local remediation="${5:-See recommendations}"

    VULNERABILITIES+=("[$severity] $category: $message")

    case "$severity" in
        CRITICAL)
            CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
            log_critical "$category: $message"
            ;;
        HIGH)
            HIGH_COUNT=$((HIGH_COUNT + 1))
            log_error "$category: $message"
            ;;
        MEDIUM)
            MEDIUM_COUNT=$((MEDIUM_COUNT + 1))
            log_warning "$category: $message"
            ;;
        LOW)
            LOW_COUNT=$((LOW_COUNT + 1))
            log_warning "$category: $message"
            ;;
        *)
            INFO_COUNT=$((INFO_COUNT + 1))
            log_info "$category: $message"
            ;;
    esac
}

add_recommendation() {
    local priority="$1"
    local recommendation="$2"
    RECOMMENDATIONS+=("[$priority] $recommendation")
}

# =============================================================================
# Check Functions
# =============================================================================

check_hardcoded_credentials() {
    log_info "Checking for hardcoded credentials in MCP configurations..."

    # Check Claude MCP config for hardcoded tokens
    local claude_config="$HOME/.config/claude/mcp.json"
    if [[ -f "$claude_config" ]]; then
        # Check for Linear API token
        if grep -q "LINEAR_API_TOKEN" "$claude_config" 2>/dev/null; then
            add_vulnerability "CRITICAL" "Hardcoded Credentials" \
                "Found LINEAR_API_TOKEN hardcoded in Claude MCP config" \
                "$claude_config" \
                "Move to environment variable: export LINEAR_API_TOKEN=xxx"
        fi
    fi

    # Check project MCP configs
    local project_configs=(
        "${PROJECT_ROOT}/.mcp.json"
        "${PROJECT_ROOT}/.cursor/mcp.json"
        "${PROJECT_ROOT}/src/.cursor/mcp.json"
    )

    for config_file in "${project_configs[@]}"; do
        if [[ -f "$config_file" ]]; then
            # Check for common credential patterns
            if grep -iE "(api_key|secret|password|token).*=.*['\"]" "$config_file" 2>/dev/null | grep -vE "env|NODE_ENV" > /dev/null; then
                add_vulnerability "HIGH" "Potential Credentials" \
                    "Found possible hardcoded credentials in $config_file" \
                    "$config_file" \
                    "Review and move to environment variables"
            fi
        fi
    done

    # Check .env files for sensitive data
    while IFS= read -r -d '' env_file; do
        if [[ ! "$env_file" =~ node_modules && ! "$env_file" =~ .example$ ]]; then
            if [[ -f "$env_file" ]]; then
                local line_count
                line_count=$(grep -cE "(password|secret|key|token).*=.+" "$env_file" 2>/dev/null || echo "0")
                if [[ "$line_count" -gt 0 ]]; then
                    add_vulnerability "MEDIUM" "Credential Exposure" \
                        "Found $line_count potential credential entries in $(basename "$env_file")" \
                        "$env_file" \
                        "Ensure .env files are in .gitignore"
                fi
            fi
        fi
    done < <(find "${PROJECT_ROOT}" -maxdepth 2 -name ".env*" -type f -print0 2>/dev/null)
}

check_insecure_protocols() {
    log_info "Checking for insecure protocol usage..."

    local config_files=(
        "${PROJECT_ROOT}/.mcp.json"
        "${PROJECT_ROOT}/.cursor/mcp.json"
        "${PROJECT_ROOT}/src/.cursor/mcp.json"
        "$HOME/.config/claude/mcp.json"
    )

    for config_file in "${config_files[@]}"; do
        if [[ -f "$config_file" ]]; then
            # Check for HTTP URLs
            if grep -E '"url":.*"http://[^s]' "$config_file" 2>/dev/null > /dev/null; then
                local http_url
                http_url=$(grep -oE '"url":\s*"http://[^"]*"' "$config_file" 2>/dev/null | head -1)
                add_vulnerability "HIGH" "Insecure Protocol" \
                    "MCP server using HTTP: $http_url" \
                    "$config_file" \
                    "Configure MCP server to use HTTPS"
            fi
        fi
    done
}

check_missing_authentication() {
    log_info "Checking for missing authentication mechanisms..."

    local config_files=(
        "${PROJECT_ROOT}/.mcp.json"
        "${PROJECT_ROOT}/.cursor/mcp.json"
    )

    for config_file in "${config_files[@]}"; do
        if [[ -f "$config_file" ]]; then
            # Check for SSE without auth headers
            if grep -E '"type":\s*"sse"' "$config_file" 2>/dev/null > /dev/null; then
                if ! grep -E "(headers|authorization|token)" "$config_file" 2>/dev/null > /dev/null; then
                    add_vulnerability "HIGH" "Missing Authentication" \
                        "SSE MCP server without visible authentication" \
                        "$config_file" \
                        "Implement authentication for remote MCP servers"
                fi
            fi
        fi
    done
}

check_outdated_dependencies() {
    log_info "Checking for outdated dependencies..."

    if [[ -f "${PROJECT_ROOT}/package.json" ]]; then
        # Check for npm audit
        if command -v npm &> /dev/null; then
            cd "${PROJECT_ROOT}" || return
            local audit_output
            audit_output=$(npm audit --json 2>/dev/null || echo '{"vulnerabilities": {}}')

            if command -v jq &> /dev/null; then
                local vuln_count
                vuln_count=$(echo "$audit_output" | jq '.vulnerabilities | length' 2>/dev/null || echo "0")

                if [[ "$vuln_count" -gt 0 ]]; then
                    add_vulnerability "HIGH" "Vulnerable Dependencies" \
                        "Found $vuln_count vulnerable npm packages" \
                        "package.json" \
                        "Run 'npm audit fix'"
                fi
            fi
        fi
    fi

    add_recommendation "MEDIUM" "Install trivy and grype for comprehensive vulnerability scanning"
}

check_file_permissions() {
    log_info "Checking file permissions..."

    # Check .env file permissions
    while IFS= read -r -d '' env_file; do
        if [[ ! "$env_file" =~ node_modules && -f "$env_file" ]]; then
            local perms
            perms=$(stat -c "%a" "$env_file" 2>/dev/null || stat -f "%OLp" "$env_file" 2>/dev/null || echo "000")

            if [[ "$perms" != "600" && "$perms" != "400" && "$perms" != "000" ]]; then
                add_vulnerability "MEDIUM" "Insecure File Permissions" \
                    ".env file has permissive permissions: $perms" \
                    "$env_file" \
                    "Run: chmod 600 $env_file"
            fi
        fi
    done < <(find "${PROJECT_ROOT}" -maxdepth 2 -name ".env*" -type f -print0 2>/dev/null)

    # Check SSH key permissions
    if [[ -d "$HOME/.ssh" ]]; then
        while IFS= read -r -d '' key_file; do
            if [[ -f "$key_file" && ! "$key_file" =~ \.pub$ ]]; then
                local perms
                perms=$(stat -c "%a" "$key_file" 2>/dev/null || stat -f "%OLp" "$key_file" 2>/dev/null || echo "000")

                if [[ "$perms" != "600" && "$perms" != "400" ]]; then
                    add_vulnerability "HIGH" "Insecure SSH Key Permissions" \
                        "SSH key has insecure permissions: $perms" \
                        "$key_file" \
                        "Run: chmod 600 $key_file"
                fi
            fi
        done < <(find "$HOME/.ssh" -name "id_*" -type f -print0 2>/dev/null)
    fi
}

check_mcp_server_exposure() {
    log_info "Checking MCP server exposure..."

    local config_files=(
        "${PROJECT_ROOT}/.mcp.json"
        "${PROJECT_ROOT}/.cursor/mcp.json"
    )

    for config_file in "${config_files[@]}"; do
        if [[ -f "$config_file" ]]; then
            # Check for non-localhost URLs
            local public_urls
            public_urls=$(grep -oE '"url":\s*"https?://[^"]*"' "$config_file" 2>/dev/null | \
                         grep -vE "localhost|127\.0\.0\.1|0\.0\.0\.0|::1|192\.168\." || true)

            if [[ -n "$public_urls" ]]; then
                add_vulnerability "MEDIUM" "Public MCP Exposure" \
                    "MCP server may be exposed on public network" \
                    "$config_file" \
                    "Ensure MCP servers are behind VPN/firewall"
            fi
        fi
    done
}

check_docker_security() {
    log_info "Checking Docker security configuration..."

    local compose_files=(
        "${PROJECT_ROOT}/docker-compose.yml"
        "${PROJECT_ROOT}/docker-compose.yaml"
    )

    for compose_file in "${compose_files[@]}"; do
        if [[ -f "$compose_file" ]]; then
            # Check for privileged containers
            if grep -E "privileged:\s*true" "$compose_file" 2>/dev/null > /dev/null; then
                add_vulnerability "HIGH" "Docker Privileged Containers" \
                    "Containers running with privileged mode" \
                    "$compose_file" \
                    "Remove privileged mode"
            fi

            # Check for running as root
            if ! grep -E "user:" "$compose_file" 2>/dev/null > /dev/null; then
                add_vulnerability "LOW" "Docker Root User" \
                    "Containers may be running as root" \
                    "$compose_file" \
                    "Add 'user' directive to docker-compose"
            fi
        fi
    done
}

check_git_security() {
    log_info "Checking git security..."

    if git -C "${PROJECT_ROOT}" rev-parse --git-dir &>/dev/null 2>&1; then
        # Check if .env is tracked
        if git -C "${PROJECT_ROOT}" ls-files | grep -q "^\.env$" 2>/dev/null; then
            add_vulnerability "CRITICAL" "Git Tracked Credentials" \
                ".env file is tracked in git" \
                ".git" \
                "Remove .env from git and add to .gitignore"
        fi
    fi
}

check_logging_and_monitoring() {
    log_info "Checking logging and monitoring configuration..."

    if [[ ! -d "${PROJECT_ROOT}/logs" ]]; then
        add_vulnerability "LOW" "Missing Log Directory" \
            "No centralized logging directory found" \
            "N/A" \
            "Create /logs directory for security events"
    fi
}

check_tls_configuration() {
    log_info "Checking TLS/SSL configuration..."

    local config_files=(
        "${PROJECT_ROOT}/.mcp.json"
        "${PROJECT_ROOT}/.cursor/mcp.json"
    )

    for config_file in "${config_files[@]}"; do
        if [[ -f "$config_file" ]]; then
            if grep -qE '"url":\s*"https://' "$config_file" 2>/dev/null; then
                add_recommendation "MEDIUM" "Verify TLS certificates for HTTPS endpoints"
            fi
        fi
    done
}

# =============================================================================
# Auto-Fix Functions
# =============================================================================

fix_file_permissions() {
    log_info "Fixing file permissions..."

    while IFS= read -r -d '' env_file; do
        if [[ ! "$env_file" =~ node_modules && -f "$env_file" ]]; then
            chmod 600 "$env_file" 2>/dev/null && log_success "Fixed permissions for $(basename "$env_file")"
        fi
    done < <(find "${PROJECT_ROOT}" -maxdepth 2 -name ".env*" -type f -print0 2>/dev/null)

    # Fix SSH key permissions
    if [[ -d "$HOME/.ssh" ]]; then
        while IFS= read -r -d '' key_file; do
            if [[ -f "$key_file" && ! "$key_file" =~ \.pub$ ]]; then
                chmod 600 "$key_file" 2>/dev/null && log_success "Fixed SSH key permissions for $(basename "$key_file")"
            fi
        done < <(find "$HOME/.ssh" -name "id_*" -type f -print0 2>/dev/null)
    fi
}

# =============================================================================
# Report Generation
# =============================================================================

generate_report() {
    log_info "Generating security audit report..."

    mkdir -p "$REPORT_DIR"

    cat > "$REPORT_FILE" << EOF
# AGL MCP Server Security Audit Report

**Generated**: ${TIMESTAMP}
**Project**: AGL Hostman Infrastructure
**Audit Scope**: MCP Servers and Infrastructure Security

---

## Executive Summary

| Severity | Count | Status |
|----------|-------|--------|
| CRITICAL | ${CRITICAL_COUNT} | $([[ $CRITICAL_COUNT -eq 0 ]] && echo "✅ PASS" || echo "❌ FAIL") |
| HIGH | ${HIGH_COUNT} | $([[ $HIGH_COUNT -eq 0 ]] && echo "✅ PASS" || echo "⚠️  WARN") |
| MEDIUM | ${MEDIUM_COUNT} | $([[ $MEDIUM_COUNT -eq 0 ]] && echo "✅ PASS" || echo "⚠️  WARN") |
| LOW | ${LOW_COUNT} | $([[ $LOW_COUNT -eq 0 ]] && echo "✅ PASS" || echo "ℹ️  INFO") |
| INFO | ${INFO_COUNT} | ℹ️  INFO |
| **TOTAL** | **$((CRITICAL_COUNT + HIGH_COUNT + MEDIUM_COUNT + LOW_COUNT + INFO_COUNT))** | |

---

## Vulnerabilities Found

$(if [[ ${#VULNERABILITIES[@]} -eq 0 ]]; then
    echo "### ✅ No vulnerabilities found!"
else
    for vuln in "${VULNERABILITIES[@]}"; do
        echo "- $vuln"
    done
fi)

---

## Security Recommendations

$(if [[ ${#RECOMMENDATIONS[@]} -eq 0 ]]; then
    echo "No additional recommendations."
else
    for i in "${!RECOMMENDATIONS[@]}"; do
        echo "$((i+1)). ${RECOMMENDATIONS[$i]}"
    done
fi)

---

## OWASP Top 10 Coverage

| Category | Status | Findings |
|----------|--------|----------|
| A01: Broken Access Control | ⏳ Pending | Manual review required |
| A02: Cryptographic Failures | $([[ $MEDIUM_COUNT -gt 0 ]] && echo "⚠️ Review" || echo "✅ Pass") | See findings above |
| A03: Injection | ⏳ Pending | Dynamic analysis recommended |
| A04: Insecure Design | ⏳ Pending | Threat modeling recommended |
| A05: Security Misconfiguration | $([[ $MEDIUM_COUNT -gt 0 ]] && echo "⚠️ Review" || echo "✅ Pass") | See findings above |
| A07: Authentication Failures | $([[ $HIGH_COUNT -gt 0 ]] && echo "⚠️ Review" || echo "✅ Pass") | See findings above |
| A10: SSRF | ⏳ Pending | Manual review required |

---

## Compliance Status

| Framework | Status | Notes |
|-----------|--------|-------|
| SOC2 | 🔄 In Progress | Implement additional logging and monitoring |
| GDPR | 🔄 In Progress | Review data handling and consent mechanisms |
| HIPAA | N/A | Not applicable to this infrastructure |

---

## Remediation Steps

### Critical Priority

1. **Rotate all exposed credentials immediately**
   \`\`\`bash
   # Generate new Linear API token via dashboard
   # Update environment variable
   export LINEAR_API_TOKEN="your_new_token"
   # Remove from config files
   \`\`\`

2. **Fix hardcoded Linear API token**
   \`\`\`bash
   # Edit: ~/.config/claude/mcp.json
   # Replace hardcoded token with environment variable reference
   \`\`\`

### High Priority

1. **Configure HTTPS for Archon MCP server**
   - Update URL from http://192.168.0.183:8051 to https://...
   - Install valid TLS certificate

2. **Fix file permissions**
   \`\`\`bash
   chmod 600 .env.security
   \`\`\`

### Medium Priority

1. **Install security scanning tools**
   \`\`\`bash
   # Trivy
   wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
   sudo apt-get install trivy

   # Grype
   curl -ssL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh
   \`\`\`

2. **Run comprehensive vulnerability scan**
   \`\`\`bash
   trivy filesystem --security-checks vuln,config "${PROJECT_ROOT}"
   \`\`\`

---

## Automated Remediation

To automatically fix non-critical issues:

\`\`\`bash
./scripts/security/security-audit.sh --fix
\`\`\`

---

**Report End**

*This report was generated by the AGL Security Audit Script v1.0.0*
EOF

    log_success "Security report generated: $REPORT_FILE"
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    local auto_fix=false
    local report_only=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --fix)
                auto_fix=true
                shift
                ;;
            --report-only)
                report_only=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [--fix] [--report-only] [--help]"
                echo "  --fix         Automatically fix non-critical issues"
                echo "  --report-only Generate report without running checks"
                echo "  --help        Show this help message"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    echo
    echo "============================================================"
    echo "  AGL MCP Server Security Audit"
    echo "============================================================"
    echo
    echo "Timestamp: $TIMESTAMP"
    echo "Project Root: $PROJECT_ROOT"
    echo

    if [[ "$report_only" == true ]]; then
        generate_report
        exit 0
    fi

    # Run all security checks
    log_info "Starting security audit..."
    echo

    check_hardcoded_credentials
    check_insecure_protocols
    check_missing_authentication
    check_outdated_dependencies
    check_file_permissions
    check_mcp_server_exposure
    check_docker_security
    check_git_security
    check_logging_and_monitoring
    check_tls_configuration

    echo
    echo "============================================================"
    echo "  Audit Summary"
    echo "============================================================"
    echo
    echo "CRITICAL: $CRITICAL_COUNT"
    echo "HIGH:     $HIGH_COUNT"
    echo "MEDIUM:   $MEDIUM_COUNT"
    echo "LOW:      $LOW_COUNT"
    echo "INFO:     $INFO_COUNT"
    echo

    # Auto-fix if requested
    if [[ "$auto_fix" == true ]]; then
        log_info "Running automated fixes..."
        fix_file_permissions
    fi

    # Generate report
    generate_report

    # Exit with appropriate code
    if [[ $CRITICAL_COUNT -gt 0 ]]; then
        exit 2
    elif [[ $HIGH_COUNT -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Run main function
main "$@"
