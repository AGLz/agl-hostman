#!/bin/bash

###############################################################################
# Security Check Script - Local Security Scanning
#
# Purpose: Run comprehensive security checks locally before committing
# Usage: ./scripts/security-check.sh [--fix]
#
# Features:
# - Trivy filesystem and config scanning
# - Secret detection with TruffleHog
# - npm audit for dependency vulnerabilities
# - Docker image scanning (if built)
# - Configuration validation
#
# Exit Codes:
# 0 - All checks passed
# 1 - Critical vulnerabilities found
# 2 - High severity issues found
# 3 - Scan errors
###############################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPORTS_DIR="${PROJECT_ROOT}/.security-reports"
FIX_MODE=false

# Parse arguments
if [[ "${1:-}" == "--fix" ]]; then
    FIX_MODE=true
    echo -e "${BLUE}🔧 Fix mode enabled - will attempt to remediate issues${NC}"
fi

# Counters
CRITICAL_COUNT=0
HIGH_COUNT=0
MEDIUM_COUNT=0
FAILED_CHECKS=0

###############################################################################
# Helper Functions
###############################################################################

print_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        print_error "$1 is not installed"
        return 1
    fi
    return 0
}

###############################################################################
# Setup
###############################################################################

setup_reports_dir() {
    print_header "Setting up reports directory"

    mkdir -p "${REPORTS_DIR}"
    chmod 700 "${REPORTS_DIR}"

    # Add to .gitignore if not already there
    if ! grep -q ".security-reports" "${PROJECT_ROOT}/.gitignore" 2>/dev/null; then
        echo ".security-reports/" >> "${PROJECT_ROOT}/.gitignore"
        print_success "Added .security-reports to .gitignore"
    fi

    print_success "Reports directory: ${REPORTS_DIR}"
}

###############################################################################
# Security Checks
###############################################################################

check_trivy_filesystem() {
    print_header "Trivy Filesystem Scan"

    if ! check_command docker; then
        print_warning "Docker not available, skipping Trivy scan"
        return 0
    fi

    echo "Scanning filesystem for vulnerabilities..."

    docker run --rm \
        -v "${PROJECT_ROOT}:/src:ro" \
        aquasec/trivy:latest \
        fs \
        --exit-code 0 \
        --severity CRITICAL,HIGH,MEDIUM \
        --skip-dirs node_modules \
        --format json \
        --output /src/.security-reports/trivy-fs.json \
        /src

    # Parse results
    if [ -f "${REPORTS_DIR}/trivy-fs.json" ]; then
        CRITICAL=$(cat "${REPORTS_DIR}/trivy-fs.json" | jq '[.Results[].Vulnerabilities[]? | select(.Severity == "CRITICAL")] | length')
        HIGH=$(cat "${REPORTS_DIR}/trivy-fs.json" | jq '[.Results[].Vulnerabilities[]? | select(.Severity == "HIGH")] | length')
        MEDIUM=$(cat "${REPORTS_DIR}/trivy-fs.json" | jq '[.Results[].Vulnerabilities[]? | select(.Severity == "MEDIUM")] | length')

        CRITICAL_COUNT=$((CRITICAL_COUNT + CRITICAL))
        HIGH_COUNT=$((HIGH_COUNT + HIGH))
        MEDIUM_COUNT=$((MEDIUM_COUNT + MEDIUM))

        echo ""
        echo "Results:"
        echo "  CRITICAL: ${CRITICAL}"
        echo "  HIGH: ${HIGH}"
        echo "  MEDIUM: ${MEDIUM}"

        if [ "${CRITICAL}" -gt 0 ]; then
            print_error "CRITICAL vulnerabilities found in filesystem"
            cat "${REPORTS_DIR}/trivy-fs.json" | jq -r '.Results[].Vulnerabilities[]? | select(.Severity == "CRITICAL") | "  - \(.VulnerabilityID): \(.PkgName) \(.InstalledVersion) -> \(.FixedVersion // "no fix")"'
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        elif [ "${HIGH}" -gt 0 ]; then
            print_warning "HIGH severity vulnerabilities found"
        else
            print_success "No critical vulnerabilities found"
        fi
    fi
}

check_trivy_config() {
    print_header "Trivy Configuration Scan"

    if ! check_command docker; then
        print_warning "Docker not available, skipping Trivy config scan"
        return 0
    fi

    echo "Scanning configurations for issues..."

    docker run --rm \
        -v "${PROJECT_ROOT}:/src:ro" \
        aquasec/trivy:latest \
        config \
        --exit-code 0 \
        --severity CRITICAL,HIGH \
        --format json \
        --output /src/.security-reports/trivy-config.json \
        /src

    if [ -f "${REPORTS_DIR}/trivy-config.json" ]; then
        CRITICAL_CONFIG=$(cat "${REPORTS_DIR}/trivy-config.json" | jq '[.Results[].Misconfigurations[]? | select(.Severity == "CRITICAL")] | length')
        HIGH_CONFIG=$(cat "${REPORTS_DIR}/trivy-config.json" | jq '[.Results[].Misconfigurations[]? | select(.Severity == "HIGH")] | length')

        echo ""
        echo "Configuration issues:"
        echo "  CRITICAL: ${CRITICAL_CONFIG}"
        echo "  HIGH: ${HIGH_CONFIG}"

        if [ "${CRITICAL_CONFIG}" -gt 0 ]; then
            print_error "CRITICAL misconfigurations found"
            cat "${REPORTS_DIR}/trivy-config.json" | jq -r '.Results[].Misconfigurations[]? | select(.Severity == "CRITICAL") | "  - \(.ID): \(.Title)"'
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        elif [ "${HIGH_CONFIG}" -gt 0 ]; then
            print_warning "HIGH severity configuration issues found"
        else
            print_success "No critical misconfigurations found"
        fi
    fi
}

check_secrets() {
    print_header "Secret Detection"

    echo "Scanning for secrets with TruffleHog..."

    # Check if TruffleHog is available
    if command -v trufflehog &> /dev/null; then
        if trufflehog git "file://${PROJECT_ROOT}" \
            --since-commit HEAD \
            --only-verified \
            --json > "${REPORTS_DIR}/trufflehog.json" 2>&1; then
            print_success "No verified secrets found"
        else
            print_error "SECRETS DETECTED!"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))

            if [ -f "${REPORTS_DIR}/trufflehog.json" ]; then
                cat "${REPORTS_DIR}/trufflehog.json" | jq -r '. | "  - \(.DetectorName): \(.Raw[:50])..."'
            fi
        fi
    else
        # Fallback to Trivy secret scanning
        if check_command docker; then
            docker run --rm \
                -v "${PROJECT_ROOT}:/src:ro" \
                aquasec/trivy:latest \
                fs \
                --scanners secret \
                --exit-code 0 \
                --format json \
                --output /src/.security-reports/trivy-secrets.json \
                /src

            if [ -f "${REPORTS_DIR}/trivy-secrets.json" ]; then
                SECRETS_FOUND=$(cat "${REPORTS_DIR}/trivy-secrets.json" | jq '[.Results[].Secrets[]?] | length')

                if [ "${SECRETS_FOUND}" -gt 0 ]; then
                    print_error "Potential secrets found: ${SECRETS_FOUND}"
                    FAILED_CHECKS=$((FAILED_CHECKS + 1))
                else
                    print_success "No secrets detected"
                fi
            fi
        else
            print_warning "No secret detection tools available"
        fi
    fi
}

check_dependencies() {
    print_header "Dependency Vulnerabilities"

    if [ ! -f "${PROJECT_ROOT}/package.json" ]; then
        print_warning "No package.json found, skipping npm audit"
        return 0
    fi

    cd "${PROJECT_ROOT}"

    echo "Running npm audit..."

    if npm audit --json > "${REPORTS_DIR}/npm-audit.json" 2>&1; then
        print_success "No dependency vulnerabilities found"
    else
        CRITICAL_DEPS=$(cat "${REPORTS_DIR}/npm-audit.json" | jq '.metadata.vulnerabilities.critical // 0')
        HIGH_DEPS=$(cat "${REPORTS_DIR}/npm-audit.json" | jq '.metadata.vulnerabilities.high // 0')
        MODERATE_DEPS=$(cat "${REPORTS_DIR}/npm-audit.json" | jq '.metadata.vulnerabilities.moderate // 0')

        echo ""
        echo "Dependency vulnerabilities:"
        echo "  CRITICAL: ${CRITICAL_DEPS}"
        echo "  HIGH: ${HIGH_DEPS}"
        echo "  MODERATE: ${MODERATE_DEPS}"

        if [ "${CRITICAL_DEPS}" -gt 0 ]; then
            print_error "CRITICAL dependency vulnerabilities found"
            cat "${REPORTS_DIR}/npm-audit.json" | jq -r '.vulnerabilities | to_entries[] | select(.value.severity == "critical") | "  - \(.key): \(.value.via[0].title // .value.via[0])"'
            FAILED_CHECKS=$((FAILED_CHECKS + 1))

            if [ "${FIX_MODE}" = true ]; then
                echo ""
                print_warning "Attempting to fix vulnerabilities..."
                npm audit fix --force
            fi
        elif [ "${HIGH_DEPS}" -gt 0 ]; then
            print_warning "HIGH severity dependency vulnerabilities found"

            if [ "${FIX_MODE}" = true ]; then
                echo ""
                print_warning "Attempting to fix vulnerabilities..."
                npm audit fix
            fi
        else
            print_success "Only moderate/low severity vulnerabilities"
        fi
    fi
}

check_docker_image() {
    print_header "Docker Image Scan"

    if ! check_command docker; then
        print_warning "Docker not available, skipping image scan"
        return 0
    fi

    # Check if Dockerfile exists
    if [ ! -f "${PROJECT_ROOT}/docker/production/Dockerfile" ]; then
        print_warning "No Dockerfile found, skipping image scan"
        return 0
    fi

    echo "Looking for local Docker images..."

    # Find images matching project name
    IMAGE_NAME="agl-hostman"
    IMAGES=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "${IMAGE_NAME}" || true)

    if [ -z "${IMAGES}" ]; then
        print_warning "No local images found. Build an image first to scan it."
        return 0
    fi

    # Scan the first matching image
    IMAGE=$(echo "${IMAGES}" | head -1)
    echo "Scanning image: ${IMAGE}"

    docker run --rm \
        -v /var/run/docker.sock:/var/run/docker.sock \
        aquasec/trivy:latest \
        image \
        --exit-code 0 \
        --severity CRITICAL,HIGH \
        --format json \
        --output /tmp/trivy-image.json \
        "${IMAGE}"

    if [ -f /tmp/trivy-image.json ]; then
        cp /tmp/trivy-image.json "${REPORTS_DIR}/trivy-image.json"
        rm /tmp/trivy-image.json

        CRITICAL_IMG=$(cat "${REPORTS_DIR}/trivy-image.json" | jq '[.Results[].Vulnerabilities[]? | select(.Severity == "CRITICAL")] | length')
        HIGH_IMG=$(cat "${REPORTS_DIR}/trivy-image.json" | jq '[.Results[].Vulnerabilities[]? | select(.Severity == "HIGH")] | length')

        echo ""
        echo "Image vulnerabilities:"
        echo "  CRITICAL: ${CRITICAL_IMG}"
        echo "  HIGH: ${HIGH_IMG}"

        if [ "${CRITICAL_IMG}" -gt 0 ]; then
            print_error "CRITICAL vulnerabilities in Docker image"
            cat "${REPORTS_DIR}/trivy-image.json" | jq -r '.Results[].Vulnerabilities[]? | select(.Severity == "CRITICAL") | "  - \(.VulnerabilityID): \(.PkgName) \(.InstalledVersion)"'
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        elif [ "${HIGH_IMG}" -gt 0 ]; then
            print_warning "HIGH severity vulnerabilities in image"
        else
            print_success "No critical vulnerabilities in image"
        fi
    fi
}

###############################################################################
# Summary and Report
###############################################################################

generate_summary() {
    print_header "Security Scan Summary"

    echo "Report Location: ${REPORTS_DIR}"
    echo ""
    echo "Vulnerability Counts:"
    echo "  CRITICAL: ${CRITICAL_COUNT}"
    echo "  HIGH: ${HIGH_COUNT}"
    echo "  MEDIUM: ${MEDIUM_COUNT}"
    echo "  Failed Checks: ${FAILED_CHECKS}"
    echo ""

    # Generate summary file
    cat > "${REPORTS_DIR}/summary.txt" <<EOF
Security Scan Summary
Generated: $(date)

Vulnerability Counts:
  CRITICAL: ${CRITICAL_COUNT}
  HIGH: ${HIGH_COUNT}
  MEDIUM: ${MEDIUM_COUNT}
  Failed Checks: ${FAILED_CHECKS}

Status: $([ ${FAILED_CHECKS} -eq 0 ] && echo "PASSED" || echo "FAILED")

Reports:
$(ls -1 ${REPORTS_DIR}/*.json 2>/dev/null || echo "  No reports generated")
EOF

    if [ ${FAILED_CHECKS} -gt 0 ]; then
        print_error "Security checks FAILED"
        echo ""
        echo "Next Steps:"
        echo "1. Review detailed reports in ${REPORTS_DIR}"
        echo "2. Address CRITICAL vulnerabilities before committing"
        echo "3. Run with --fix flag to attempt automatic remediation"
        echo "4. Check SECURITY.md for remediation guidance"
        return 1
    elif [ ${CRITICAL_COUNT} -gt 0 ] || [ ${HIGH_COUNT} -gt 0 ]; then
        print_warning "Security issues found but not blocking"
        echo ""
        echo "Consider addressing vulnerabilities before deployment"
        return 2
    else
        print_success "All security checks passed!"
        return 0
    fi
}

###############################################################################
# Main Execution
###############################################################################

main() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║           AGL Infrastructure Security Scanner                 ║"
    echo "║           Comprehensive Local Security Checks                 ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    setup_reports_dir
    check_trivy_filesystem
    check_trivy_config
    check_secrets
    check_dependencies
    check_docker_image
    generate_summary
}

# Run main function and capture exit code
main
EXIT_CODE=$?

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

exit ${EXIT_CODE}
