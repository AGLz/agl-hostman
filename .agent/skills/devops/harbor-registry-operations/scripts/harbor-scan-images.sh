#!/bin/bash
# Harbor Vulnerability Scanning Script
# Triggers vulnerability scans and reports on Harbor images
#
# Usage: ./harbor-scan-images.sh [options]
#   --project NAME              Project name (required)
#   --repository NAME           Repository name (optional, all if omitted)
#   --tag TAG                   Specific tag to scan (optional)
#   --severity LEVEL            Minimum severity: critical,high,medium,low (default: low)
#   --wait                      Wait for scan completion
#   --report                    Generate detailed report
#   --fixable-only              Show only fixable vulnerabilities
#   --fail-on SEVERITY          Fail exit if vulnerability found (critical,high,medium,low)
#   --harbor-host HOST          Harbor host (default: from env)
#   --username USER             Harbor username (default: admin)
#   --password PASS             Harbor password (default: from env)

set -euo pipefail

# Configuration
HARBOR_HOST="${HARBOR_HOST:-harbor.local}"
HARBOR_USERNAME="${HARBOR_USERNAME:-admin}"
HARBOR_PASSWORD="${HARBOR_PASSWORD:-}"
PROJECT_NAME=""
REPOSITORY_NAME=""
TAG_NAME=""
SEVERITY="low"
WAIT=false
REPORT=false
FIXABLE_ONLY=false
FAIL_ON=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Severity levels
declare -A SEVERITY_ORDER=(
    ["critical"]=4
    ["high"]=3
    ["medium"]=2
    ["low"]=1
    ["none"]=0
)

# Logging
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
fatal() { log_error "$1"; exit 1; }

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --project) PROJECT_NAME="$2"; shift 2 ;;
        --repository) REPOSITORY_NAME="$2"; shift 2 ;;
        --tag) TAG_NAME="$2"; shift 2 ;;
        --severity) SEVERITY="$2"; shift 2 ;;
        --wait) WAIT=true; shift ;;
        --report) REPORT=true; shift ;;
        --fixable-only) FIXABLE_ONLY=true; shift ;;
        --fail-on) FAIL_ON="$2"; shift 2 ;;
        --harbor-host) HARBOR_HOST="$2"; shift 2 ;;
        --username) HARBOR_USERNAME="$2"; shift 2 ;;
        --password) HARBOR_PASSWORD="$2"; shift 2 ;;
        *) fatal "Unknown option: $1" ;;
    esac
done

# Validation
[[ -z "$PROJECT_NAME" ]] && fatal "Project name required (--project)"
[[ -z "$HARBOR_PASSWORD" ]] && fatal "Harbor password required (set HARBOR_PASSWORD or --password)"

log_info "Harbor vulnerability scanning for project: ${PROJECT_NAME}"

# Get project ID
PROJECT_ID=$(curl -sk -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" \
    "https://${HARBOR_HOST}/api/v2.0/projects?name=${PROJECT_NAME}" | \
    jq -r '.[0].project_id // empty')

if [[ -z "$PROJECT_ID" ]]; then
    fatal "Project '${PROJECT_NAME}' not found"
fi

# Get repositories
log_info "Fetching repositories..."

if [[ -n "$REPOSITORY_NAME" ]]; then
    REPOSITORIES=("$REPOSITORY_NAME")
else
    REPOSITORIES=($(curl -sk -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" \
        "https://${HARBOR_HOST}/api/v2.0/projects/${PROJECT_ID}/repositories" | \
        jq -r '.[].name'))
fi

if [[ ${#REPOSITORIES[@]} -eq 0 ]]; then
    log_warn "No repositories found in project ${PROJECT_NAME}"
    exit 0
fi

log_info "Found ${#REPOSITORIES[@]} repository(ies)"

# Track overall status
OVERALL_STATUS="pass"
TOTAL_VULNS=0
declare -A VULN_COUNTS=(
    ["critical"]=0
    ["high"]=0
    ["medium"]=0
    ["low"]=0
    ["none"]=0
)

# Scan each repository
for REPO in "${REPOSITORIES[@]}"; do
    REPO_NAME="${REPO##*/}"
    log_info "Scanning repository: ${REPO_NAME}"

    # Get artifacts (images)
    ARTIFACTS=$(curl -sk -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" \
        "https://${HARBOR_HOST}/api/v2.0/projects/${PROJECT_ID}/repositories/${REPO}/artifacts")

    # Filter by tag if specified
    if [[ -n "$TAG_NAME" ]]; then
        ARTIFACTS=$(echo "$ARTIFACTS" | jq "[.[] | select(.tags[].name == \"${TAG_NAME}\")]")
    fi

    ARTIFACT_COUNT=$(echo "$ARTIFACTS" | jq 'length')

    if [[ $ARTIFACT_COUNT -eq 0 ]]; then
        log_warn "No artifacts found for ${REPO_NAME}"
        continue
    fi

    log_info "Found ${ARTIFACT_COUNT} artifact(s)"

    # Scan each artifact
    echo "$ARTIFACTS" | jq -c '.[]' | while read -r ARTIFACT; do
        DIGEST=$(echo "$ARTIFACT" | jq -r '.digest')
        TAG=$(echo "$ARTIFACT" | jq -r '.tags[0].name // "unknown"')

        log_info "Scanning ${REPO_NAME}:${TAG}"

        # Trigger scan
        SCAN_RESPONSE=$(curl -skX POST \
            "https://${HARBOR_HOST}/api/v2.0/projects/${PROJECT_ID}/repositories/${REPO}/artifacts/${DIGEST}/scan" \
            -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}")

        if [[ "$WAIT" == true ]]; then
            log_info "Waiting for scan to complete..."

            MAX_WAIT=300
            WAIT_TIME=0
            SCAN_STATUS="pending"

            while [[ $WAIT_TIME -lt $MAX_WAIT && "$SCAN_STATUS" == "pending" ]]; do
                sleep 5
                WAIT_TIME=$((WAIT_TIME + 5))

                ARTIFACT_INFO=$(curl -sk -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" \
                    "https://${HARBOR_HOST}/api/v2.0/projects/${PROJECT_ID}/repositories/${REPO}/artifacts/${DIGEST}?with_scan_overview=true")

                SCAN_STATUS=$(echo "$ARTIFACT_INFO" | jq -r '.scan_overview."application/vnd.security.vulnerability.report; version=1.1".scan_status // "pending"')

                echo -n "."
            done
            echo ""

            if [[ "$SCAN_STATUS" != "Success" ]]; then
                log_error "Scan failed or timed out"
                continue
            fi

            log_info "Scan completed"
        fi

        # Get scan results
        ARTIFACT_INFO=$(curl -sk -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" \
            "https://${HARBOR_HOST}/api/v2.0/projects/${PROJECT_ID}/repositories/${REPO}/artifacts/${DIGEST}?with_scan_overview=true")

        # Parse vulnerabilities
        VULNS=$(echo "$ARTIFACT_INFO" | jq -r '.scan_overview."application/vnd.security.vulnerability.report; version=1.1".vulnerabilities // []')

        # Filter by severity and fixable
        if [[ "$FIXABLE_ONLY" == true ]]; then
            VULNS=$(echo "$VULNS" | jq "[.[] | select(.fixable == true)]")
        fi

        # Filter by minimum severity
        MIN_SEV_ORDER=${SEVERITY_ORDER[$SEVERITY]:-0}
        VULNS=$(echo "$VULNS" | jq "[.[] | select(.severity | IN(\"Critical\", \"High\", \"Medium\", \"Low\") | if . == \"Critical\" then 4 elif . == \"High\" then 3 elif . == \"Medium\" then 2 else 1 end >= ${MIN_SEV_ORDER})]")

        VULN_COUNT=$(echo "$VULNS" | jq 'length')
        TOTAL_VULNS=$((TOTAL_VULNS + VULN_COUNT))

        # Count by severity
        for SEV in critical high medium low; do
            COUNT=$(echo "$VULNS" | jq "[.[] | select(.severity == \"$(echo ${SEV^})\")] | length")
            VULN_COUNTS[$SEV]=$((VULN_COUNTS[$SEV] + COUNT))
        done

        if [[ $VULN_COUNT -gt 0 ]]; then
            log_warn "Found ${VULN_COUNT} vulnerability(ies) in ${REPO_NAME}:${TAG}"

            echo ""
            echo "Vulnerabilities for ${REPO_NAME}:${TAG}:"
            echo "=========================================="

            echo "$VULNS" | jq -r '.[] |
                "\(.severity) - \(.id)\n" +
                "  Package: \(.package) (\(.version))\n" +
                "  Description: \(.description // "N/A")\n" +
                "  Fixable: \(.fixable // false)\n" +
                "  Links: \(.links // "N/A")\n" +
                " "'

            # Check if we should fail
            if [[ -n "$FAIL_ON" ]]; then
                FAIL_SEV_ORDER=${SEVERITY_ORDER[$FAIL_ON]:-0}
                HAS_FAILING_VULN=$(echo "$VULNS" | jq "[.[] | select(.severity | IN(\"Critical\", \"High\", \"Medium\", \"Low\") | if . == \"Critical\" then 4 elif . == \"High\" then 3 elif . == \"Medium\" then 2 else 1 end >= ${FAIL_SEV_ORDER})] | length")

                if [[ $HAS_FAILING_VULN -gt 0 ]]; then
                    OVERALL_STATUS="fail"
                fi
            fi
        else
            log_info "No vulnerabilities found in ${REPO_NAME}:${TAG}"
        fi

        # Generate detailed report if requested
        if [[ "$REPORT" == true ]]; then
            REPORT_FILE="scan-report-${PROJECT_NAME}-${REPO_NAME}-${TAG}.json"
            echo "$ARTIFACT_INFO" | jq '.' > "$REPORT_FILE"
            log_info "Report saved to: ${REPORT_FILE}"
        fi
    done
done

# Summary
echo ""
echo "Scan Summary:"
echo "============="
echo "Project: ${PROJECT_NAME}"
echo "Repositories scanned: ${#REPOSITORIES[@]}"
echo "Total vulnerabilities found: ${TOTAL_VULNS}"
echo ""
echo "Vulnerabilities by severity:"
echo "  Critical: ${VULN_COUNTS[critical]}"
echo "  High: ${VULN_COUNTS[high]}"
echo "  Medium: ${VULN_COUNTS[medium]}"
echo "  Low: ${VULN_COUNTS[low]}"
echo ""

if [[ "$OVERALL_STATUS" == "fail" ]]; then
    log_error "Scan failed: Found vulnerabilities matching --fail-on severity: ${FAIL_ON}"
    exit 1
fi

log_info "Scan completed successfully"
