#!/bin/bash
# Plan and apply Terraform changes with approval
# Usage: ./scripts/tf-plan-apply.sh [environment] [auto-approve]

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default values
ENVIRONMENT="${1:-dev}"
AUTO_APPROVE="${2:-false}"
PLAN_FILE="tfplan-${ENVIRONMENT}"
TFVARS_FILE="environments/${ENVIRONMENT}/terraform.tfvars"

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

log_plan() {
  echo -e "${BLUE}[PLAN]${NC} $1"
}

check_prerequisites() {
  if [[ ! -f "$TFVARS_FILE" ]]; then
    log_error "Terraform variables file not found: $TFVARS_FILE"
    exit 1
  fi

  if [[ ! -d ".terraform" ]]; then
    log_warn "Terraform not initialized. Running init..."
    ./scripts/tf-init.sh "$ENVIRONMENT"
  fi
}

get_changes_count() {
  terraform show -json "$PLAN_FILE" 2>/dev/null | \
    jq -r '[.resource_changes[] | select(.change.actions != ["no-op"])] | length' 2>/dev/null || echo "0"
}

show_plan_summary() {
  log_plan "=== Plan Summary ==="
  terraform show "$PLAN_FILE"

  local count=$(get_changes_count)
  log_plan "Changes to apply: $count resources"

  if [[ "$count" -eq "0" ]]; then
    log_info "No changes to apply"
    exit 0
  fi
}

prompt_approval() {
  if [[ "$AUTO_APPROVE" == "true" ]]; then
    log_warn "Auto-approve enabled, skipping confirmation"
    return 0
  fi

  echo ""
  log_warn "Do you want to apply these changes? (yes/no)"
  read -r response

  if [[ ! "$response" =~ ^[Yy][Ee][Ss]$ ]]; then
    log_info "Apply cancelled"
    exit 0
  fi
}

cleanup() {
  if [[ -f "$PLAN_FILE" ]]; then
    log_info "Cleaning up plan file..."
    rm -f "$PLAN_FILE"
  fi
}

run_security_scans() {
  log_info "Running security scans..."

  if command -v tfsec &> /dev/null; then
    log_info "Running tfsec..."
    if tfsec . --soft-fail; then
      log_info "✅ tfsec passed"
    else
      log_warn "⚠️  tfsec found issues (continuing)"
    fi
  fi

  if command -v checkov &> /dev/null; then
    log_info "Running checkov..."
    if checkov -d . --framework terraform --soft-fail &>/dev/null; then
      log_info "✅ checkov passed"
    else
      log_warn "⚠️  checkov found issues (continuing)"
    fi
  fi
}

run_cost_estimate() {
  if command -v infracost &> /dev/null; then
    log_info "Running cost estimate..."
    infracost breakdown --path . \
      --terraform-plan-file "$PLAN_FILE" \
      --format table || log_warn "Cost estimate failed"
  fi
}

# Plan phase
run_plan() {
  log_info "Running terraform plan for: $ENVIRONMENT"

  terraform plan \
    -var-file="$TFVARS_FILE" \
    -out="$PLAN_FILE" \
    -detailed-exitcode

  local exit_code=$?

  case $exit_code in
    0)
      log_info "No changes to apply"
      exit 0
      ;;
    1)
      log_error "Plan failed"
      exit 1
      ;;
    2)
      log_info "Plan generated with changes"
      ;;
  esac
}

# Apply phase
run_apply() {
  log_info "Applying changes to: $ENVIRONMENT"

  terraform apply \
    -var-file="$TFVARS_FILE" \
    "$PLAN_FILE"

  log_info "✅ Changes applied successfully"
}

# Output phase
show_outputs() {
  log_info "Fetching outputs..."

  if command -v jq &> /dev/null; then
    terraform output -json | jq -r 'to_entries | "\(.key): \(.value.value)"'
  else
    terraform output
  fi
}

# Save outputs to file
save_outputs() {
  local output_file="environments/${ENVIRONMENT}/outputs.json"

  if command -v jq &> /dev/null; then
    terraform output -json > "$output_file"
    log_info "Outputs saved to: $output_file"
  fi
}

# Main execution
main() {
  log_info "=== Terraform Plan & Apply ==="
  log_info "Environment: $ENVIRONMENT"
  log_info "Auto-approve: $AUTO_APPROVE"

  trap cleanup EXIT

  check_prerequisites
  run_plan
  show_plan_summary
  run_security_scans
  run_cost_estimate
  prompt_approval
  run_apply
  show_outputs
  save_outputs

  log_info "✅ Deployment completed successfully"
}

main "$@"
