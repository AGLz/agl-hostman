#!/bin/bash
# Infrastructure Drift Remediation Script
# Automatically fixes detected drift by re-applying Terraform configuration

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"
AUTO_APPLY="${AUTO_APPLY:-false}"
DRIFT_REPORT_DIR="${INFRA_DIR}/reports/drift"

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

remediate_drift() {
    local env=$1
    local auto_apply=$2

    log_info "Remediating drift in ${env} environment..."

    cd "${INFRA_DIR}/terraform/environments/${env}"

    # Show plan first
    log_info "Generating plan for review..."
    terraform plan \
        -var="proxmox_api_token_id=${PROXMOX_TOKEN_ID}" \
        -var="proxmox_api_token_secret=${PROXMOX_TOKEN_SECRET}" \
        -out=tfplan

    log_info "Plan saved to tfplan"
    log_warning "Review the plan carefully before applying!"

    if [ "$auto_apply" = "true" ]; then
        log_warning "AUTO_APPLY is enabled - applying changes in 10 seconds..."
        sleep 10

        log_info "Applying Terraform to fix drift..."
        if terraform apply tfplan; then
            log_success "Drift remediation completed successfully for ${env}"
            rm -f tfplan
            return 0
        else
            log_error "Failed to remediate drift in ${env}"
            rm -f tfplan
            return 1
        fi
    else
        log_info "To apply the remediation, run:"
        echo "  cd ${INFRA_DIR}/terraform/environments/${env}"
        echo "  terraform apply tfplan"
        log_info "Or re-run with AUTO_APPLY=true"
        rm -f tfplan
        return 2
    fi
}

main() {
    if [ -z "${1:-}" ]; then
        log_error "Usage: $0 <environment> [auto_apply]"
        log_error "  environment: dev, staging, or production"
        log_error "  auto_apply: true to automatically apply changes"
        exit 1
    fi

    local env=$1
    local auto_apply=${AUTO_APPLY}

    if [ "$2" = "true" ] || [ "$2" = "false" ]; then
        auto_apply=$2
    fi

    # Check for latest drift report
    local latest_report=$(ls -t ${DRIFT_REPORT_DIR}/drift-${env}-*.txt 2>/dev/null | head -n1)

    if [ -z "$latest_report" ]; then
        log_warning "No drift report found for ${env}"
        log_info "Run drift detection first: ./scripts/drift-detection.sh"
        exit 1
    fi

    log_info "Using drift report: ${latest_report}"
    cat "$latest_report"

    log_warning "This will modify infrastructure to match Terraform state"
    read -p "Continue? (yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        log_info "Remediation cancelled"
        exit 0
    fi

    if remediate_drift "$env" "$auto_apply"; then
        log_success "Remediation completed successfully"
        exit 0
    else
        log_error "Remediation failed"
        exit 1
    fi
}

main "$@"
