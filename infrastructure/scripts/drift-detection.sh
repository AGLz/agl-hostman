#!/bin/bash
# Infrastructure Drift Detection Script
# Checks for configuration drift between Terraform state and actual infrastructure

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"
ENVIRONMENTS=("dev" "staging" "production")
DRIFT_REPORT_DIR="${INFRA_DIR}/reports/drift"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
ALERT_WEBHOOK="${DRIFT_ALERT_WEBHOOK:-}"

# Create reports directory
mkdir -p "$DRIFT_REPORT_DIR"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_drift() {
    local env=$1
    local report_file="${DRIFT_REPORT_DIR}/drift-${env}-${TIMESTAMP}.txt"

    log_info "Checking for drift in ${env} environment..."

    cd "${INFRA_DIR}/terraform/environments/${env}"

    # Initialize Terraform
    terraform init \
        -backend-config="bucket=agl-terraform-state" \
        -backend-config="key=proxmox-${env}/terraform.tfstate" \
        -backend-config="region=us-east-1" \
        >/dev/null 2>&1

    # Run plan with detailed exit code
    if terraform plan -detailed-exitcode -out=tfplan "${report_file}" 2>&1; then
        log_success "No drift detected in ${env} environment"
        rm -f tfplan
        return 0
    else
        exit_code=$?

        # Exit code 1 = error, 2 = drift
        if [ $exit_code -eq 2 ]; then
            log_warning "Drift detected in ${env} environment!"

            # Show drift summary
            terraform show -no-color tfplan | tee "$report_file"

            # Count changes
            local additions=$(grep -c " +" "$report_file" || echo "0")
            local modifications=$(grep -c "~" "$report_file" || echo "0")
            local deletions=$(grep -c " -" "$report_file" || echo "0")

            log_warning "Summary for ${env}:"
            log_warning "  - Additions: ${additions}"
            log_warning "  - Modifications: ${modifications}"
            log_warning "  - Deletions: ${deletions}"

            rm -f tfplan
            return 1
        else
            log_error "Error checking drift in ${env} environment"
            cat "$report_file"
            rm -f tfplan
            return 2
        fi
    fi
}

send_alert() {
    local drift_envs=$1

    if [ -z "$ALERT_WEBHOOK" ]; then
        log_warning "No alert webhook configured"
        return
    fi

    log_info "Sending drift alert..."

    local message="Infrastructure drift detected in the following environments: ${drift_envs}"

    curl -s -X POST "$ALERT_WEBHOOK" \
        -H "Content-Type: application/json" \
        -d "{\"text\": \"${message}\"}" \
        >/dev/null

    log_success "Alert sent"
}

main() {
    log_info "Starting infrastructure drift detection..."
    log_info "Timestamp: ${TIMESTAMP}"

    local drift_detected=()
    local drift_envs=""

    for env in "${ENVIRONMENTS[@]}"; do
        if check_drift "$env"; then
            : # No drift
        else
            if [ $? -eq 1 ]; then
                drift_detected+=("$env")
                drift_envs="${drift_envs}${env}, "
            fi
        fi
    done

    # Remove trailing comma
    drift_envs=${drift_envs%, }

    # Generate summary report
    local summary_file="${DRIFT_REPORT_DIR}/summary-${TIMESTAMP}.txt"
    {
        echo "Infrastructure Drift Detection Summary"
        echo "======================================"
        echo "Timestamp: ${TIMESTAMP}"
        echo ""

        if [ ${#drift_detected[@]} -eq 0 ]; then
            echo "Status: No drift detected"
            echo "All environments are in sync."
        else
            echo "Status: DRIFT DETECTED"
            echo ""
            echo "Affected environments:"
            for env in "${drift_detected[@]}"; do
                echo "  - ${env}"
            done
            echo ""
            echo "Please review the detailed reports:"
            for env in "${drift_detected[@]}"; do
                echo "  - ${DRIFT_REPORT_DIR}/drift-${env}-${TIMESTAMP}.txt"
            done
        fi
    } | tee "$summary_file"

    # Send alert if drift detected
    if [ ${#drift_detected[@]} -gt 0 ]; then
        send_alert "$drift_envs"
        log_warning "Drift detection completed with issues"
        exit 1
    else
        log_success "Drift detection completed successfully"
        exit 0
    fi
}

# Run main function
main "$@"
