#!/bin/bash
# Run Ansible playbooks with inventory and vault support
# Usage: ./scripts/ansible-run.sh [playbook] [environment] [options]

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default values
PLAYBOOK="${1:-site.yml}"
ENVIRONMENT="${2:-production}"
LIMIT="${LIMIT:-}"
TAGS="${TAGS:-}"
SKIP_TAGS="${SKIP_TAGS:-}"
VAULT_PASSWORD_FILE="${VAULT_PASSWORD_FILE:-}"
CHECK_MODE="${CHECK_MODE:-false}"
DIFF_MODE="${DIFF_MODE:-false}"
VERBOSITY="${VERBOSITY:-}"

# Files
INVENTORY_FILE="inventory/${ENVIRONMENT}/hosts.yml"
VAULT_FILE="inventory/${ENVIRONMENT}/vault.yml"

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

log_playbook() {
  echo -e "${BLUE}[ANSIBLE]${NC} $1"
}

check_ansible() {
  if ! command -v ansible-playbook &> /dev/null; then
    log_error "Ansible is not installed"
    exit 1
  fi
  log_info "Ansible version: $(ansible --version | head -n1)"
}

check_files() {
  if [[ ! -f "$PLAYBOOK" ]]; then
    log_error "Playbook not found: $PLAYBOOK"
    exit 1
  fi

  if [[ ! -f "$INVENTORY_FILE" ]]; then
    log_error "Inventory not found: $INVENTORY_FILE"
    exit 1
  fi
}

check_vault() {
  if [[ -f "$VAULT_FILE" ]]; then
    log_info "Vault file detected: $VAULT_FILE"

    if [[ -n "$VAULT_PASSWORD_FILE" ]]; then
      VAULT_OPTS="--vault-password-file $VAULT_PASSWORD_FILE"
      log_info "Using vault password file"
    else
      log_warn "No vault password file set. Will prompt for password."
    fi
  else
    log_info "No vault file found"
  fi
}

build_ansible_command() {
  local cmd="ansible-playbook $PLAYBOOK"
  cmd="$cmd -i $INVENTORY_FILE"
  cmd="$cmd $VAULT_OPTS"

  if [[ -n "$LIMIT" ]]; then
    cmd="$cmd --limit $LIMIT"
    log_info "Limiting to: $LIMIT"
  fi

  if [[ -n "$TAGS" ]]; then
    cmd="$cmd --tags $TAGS"
    log_info "Tags: $TAGS"
  fi

  if [[ -n "$SKIP_TAGS" ]]; then
    cmd="$cmd --skip-tags $SKIP_TAGS"
    log_info "Skip tags: $SKIP_TAGS"
  fi

  if [[ "$CHECK_MODE" == "true" ]]; then
    cmd="$cmd --check"
    log_info "Check mode enabled (dry-run)"
  fi

  if [[ "$DIFF_MODE" == "true" ]]; then
    cmd="$cmd --diff"
    log_info "Diff mode enabled"
  fi

  if [[ -n "$VERBOSITY" ]]; then
    cmd="$cmd -$VERBOSITY"
    log_info "Verbosity: -$VERBOSITY"
  fi

  echo "$cmd"
}

run_syntax_check() {
  log_info "Running syntax check..."

  local cmd="ansible-playbook $PLAYBOOK -i $INVENTORY_FILE --syntax-check"
  eval $cmd

  log_info "✅ Syntax check passed"
}

run_playbook() {
  log_info "Running playbook: $PLAYBOOK"
  log_info "Environment: $ENVIRONMENT"
  log_info "Inventory: $INVENTORY_FILE"

  local cmd=$(build_ansible_command)

  log_info "Executing: $cmd"
  echo ""

  eval $cmd

  local exit_code=$?

  echo ""
  if [[ $exit_code -eq 0 ]]; then
    log_info "✅ Playbook completed successfully"
  else
    log_error "❌ Playbook failed with exit code: $exit_code"
    exit $exit_code
  fi
}

show_inventory() {
  log_info "Inventory summary:"
  ansible-inventory -i "$INVENTORY_FILE" --list -y 2>/dev/null || \
    log_warn "Could not display inventory"
}

pre_flight_checks() {
  log_info "Running pre-flight checks..."

  # Check for required Python packages
  log_info "Checking target host connectivity..."
  local cmd="ansible all -i $INVENTORY_FILE $VAULT_OPTS -m ping"
  eval $cmd &>/dev/null || log_warn "Some hosts may not be reachable"

  # Check for required modules
  log_info "Checking required Ansible collections..."
  ansible-galaxy collection list 2>/dev/null | grep -q "community.general" || \
    log_warn "community.general collection not found"
}

# Main execution
main() {
  log_info "=== Ansible Playbook Runner ==="

  check_ansible
  check_files
  check_vault
  run_syntax_check
  show_inventory
  pre_flight_checks
  run_playbook

  log_info "✅ All tasks completed"
}

main "$@"
