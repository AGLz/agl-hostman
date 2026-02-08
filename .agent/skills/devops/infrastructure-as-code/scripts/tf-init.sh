#!/bin/bash
# Initialize Terraform project with backend configuration
# Usage: ./scripts/tf-init.sh [environment]

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Default values
ENVIRONMENT="${1:-dev}"
WORKSPACE="${2:-}"
BACKEND_CONFIG=""

# Functions
log_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

check_terraform() {
  if ! command -v terraform &> /dev/null; then
    log_error "Terraform is not installed"
    exit 1
  fi
  log_info "Terraform version: $(terraform version -json | jq -r '.terraform_version')"
}

validate_environment() {
  if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    log_error "Invalid environment: $ENVIRONMENT"
    log_info "Valid environments: dev, staging, prod"
    exit 1
  fi
  log_info "Environment: $ENVIRONMENT"
}

configure_backend() {
  local backend_file="environments/${ENVIRONMENT}/backend.tfvars"

  if [[ -f "$backend_file" ]]; then
    BACKEND_CONFIG="-backend-config=$backend_file"
    log_info "Backend config: $backend_file"
  else
    log_warn "Backend config not found: $backend_file"
    log_warn "Using default backend configuration"
  fi
}

create_workspace() {
  if [[ -n "$WORKSPACE" ]]; then
    log_info "Creating workspace: $WORKSPACE"
    if ! terraform workspace list | grep -q "$WORKSPACE"; then
      terraform workspace new "$WORKSPACE"
    else
      terraform workspace select "$WORKSPACE"
    fi
    log_info "Current workspace: $(terraform workspace show)"
  fi
}

download_plugins() {
  log_info "Downloading provider plugins..."
  terraform init -upgrade=true $BACKEND_CONFIG
}

validate_configuration() {
  log_info "Validating configuration..."
  terraform validate
  log_info "Configuration valid"
}

format_code() {
  log_info "Formatting Terraform files..."
  terraform fmt -recursive
}

show_state_info() {
  if [[ -f ".terraform/terraform.tfstate" ]]; then
    log_info "State file location: .terraform/terraform.tfstate (local)"
  else
    log_info "State backend: Remote (configured in backend.tfvars)"
  fi
}

# Main execution
main() {
  log_info "Initializing Terraform project..."
  check_terraform
  validate_environment
  configure_backend
  create_workspace
  download_plugins
  validate_configuration
  format_code
  show_state_info

  log_info "✅ Terraform initialized successfully"
  log_info ""
  log_info "Next steps:"
  log_info "  terraform plan -var-file=environments/${ENVIRONMENT}/terraform.tfvars"
  log_info "  terraform apply -var-file=environments/${ENVIRONMENT}/terraform.tfvars"
}

main "$@"
