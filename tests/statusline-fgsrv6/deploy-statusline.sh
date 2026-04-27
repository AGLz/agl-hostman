#!/bin/bash

# Statusline Deployment Orchestrator - FGSRV6
# This script orchestrates the complete deployment process

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
FGSRV6_HOST="${FGSRV6_HOST:-}"
FGSRV6_USER="${FGSRV6_USER:-}"
STATUSLINE_SOURCE="/mnt/overpower/apps/dev/agl/agl-hostman/.claude/statusline-command.sh"
TEST_DIR="/mnt/overpower/apps/dev/agl/agl-hostman/tests/statusline-fgsrv6"

# Helper functions
log_header() {
    echo
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_usage() {
    cat << 'EOF'
Statusline Deployment Orchestrator - FGSRV6

Usage: deploy-statusline.sh [COMMAND] [OPTIONS]

Commands:
    test            Run all tests locally before deployment
    deploy          Deploy to FGSRV6
    validate        Validate deployment on FGSRV6
    rollback        Rollback to previous configuration
    full            Run full deployment pipeline (test + deploy + validate)
    help            Show this help message

Environment Variables:
    FGSRV6_HOST     FGSRV6 hostname or IP (required for deploy/validate)
    FGSRV6_USER     SSH username for FGSRV6 (default: current user)

Examples:
    # Test locally
    ./deploy-statusline.sh test

    # Deploy to FGSRV6
    FGSRV6_HOST=fgsrv6.example.com ./deploy-statusline.sh deploy

    # Full pipeline
    FGSRV6_HOST=fgsrv6.example.com FGSRV6_USER=admin ./deploy-statusline.sh full

EOF
}

check_dependencies() {
    log_info "Checking dependencies..."

    local missing=0

    # Check required commands
    for cmd in jq ssh scp rsync; do
        if ! command -v "$cmd" > /dev/null 2>&1; then
            log_error "Missing required command: $cmd"
            missing=1
        fi
    done

    # Check if statusline source exists
    if [ ! -f "$STATUSLINE_SOURCE" ]; then
        log_error "Statusline source not found: $STATUSLINE_SOURCE"
        missing=1
    fi

    # Check if test scripts exist
    if [ ! -x "$TEST_DIR/quick-test.sh" ]; then
        log_error "Test script not found or not executable: $TEST_DIR/quick-test.sh"
        missing=1
    fi

    if [ $missing -eq 1 ]; then
        log_error "Missing dependencies. Please install and try again."
        exit 1
    fi

    log_success "All dependencies satisfied"
}

run_tests() {
    log_header "Running Pre-Deployment Tests"

    cd "$TEST_DIR"

    # Make scripts executable
    log_info "Making test scripts executable..."
    chmod +x *.sh

    # Run quick test
    log_info "Running quick validation test..."
    if ./quick-test.sh; then
        log_success "Quick test passed"
    else
        log_error "Quick test failed!"
        return 1
    fi

    # Run full test suite
    log_info "Running comprehensive test suite..."
    if ./test-cases.sh; then
        log_success "Comprehensive test suite passed"
    else
        log_error "Comprehensive test suite failed!"
        return 1
    fi

    # Run deployment test
    log_info "Running deployment simulation test..."
    if ./deployment-test.sh; then
        log_success "Deployment simulation passed"
    else
        log_error "Deployment simulation failed!"
        return 1
    fi

    log_success "All tests passed! Ready for deployment."
    return 0
}

backup_remote() {
    local host="$1"
    local user="$2"
    local timestamp=$(date +%Y%m%d_%H%M%S)

    log_info "Creating backup on $host..."

    ssh "$user@$host" "
        # Backup settings
        cp .claude/settings.json \".claude/settings.json.backup.$timestamp\" 2>/dev/null || echo 'No existing settings'

        # Backup script if exists
        if [ -f .claude/statusline-command.sh ]; then
            cp .claude/statusline-command.sh \".claude/statusline-command.sh.backup.$timestamp\"
        fi

        echo 'Backup completed: .claude/settings.json.backup.$timestamp'
    " | tee -a /tmp/statusline-deploy.log

    log_success "Backup created on $host"
}

deploy_statusline() {
    local host="$1"
    local user="$2"

    log_header "Deploying Statusline to FGSRV6"

    # Check connection
    log_info "Testing SSH connection to $host..."
    if ! ssh "$user@$host" "echo 'Connection OK'" > /dev/null 2>&1; then
        log_error "Cannot connect to $host via SSH"
        log_info "Please check:"
        log_info "  1. Hostname is correct: $host"
        log_info "  2. SSH key is configured"
        log_info "  3. User has access: $user"
        exit 1
    fi
    log_success "SSH connection successful"

    # Create backup
    backup_remote "$host" "$user"

    # Transfer statusline script
    log_info "Transferring statusline script..."
    scp -q "$STATUSLINE_SOURCE" "$user@$host:.claude/statusline-command.sh"

    # Set execute permissions
    log_info "Setting execute permissions..."
    ssh "$user@$host" "chmod +x .claude/statusline-command.sh"

    # Verify deployment
    log_info "Verifying deployment..."
    ssh "$user@$host" "
        if [ -x .claude/statusline-command.sh ]; then
            echo '✓ Script deployed and executable'
        else
            echo '✗ Script deployment failed'
            exit 1
        fi
    "

    log_success "Statusline script deployed successfully"
}

update_config() {
    local host="$1"
    local user="$2"

    log_info "Updating configuration on $host..."

    ssh "$user@$host" "
        # Update settings.json with statusLine configuration
        jq '.statusLine = {
            \"type\": \"command\",
            \"command\": \".claude/statusline-command.sh\"
        }' .claude/settings.json > .claude/settings.json.tmp

        mv .claude/settings.json.tmp .claude/settings.json

        # Verify configuration
        if jq '.' .claude/settings.json > /dev/null 2>&1; then
            echo '✓ Configuration updated successfully'
        else
            echo '✗ Configuration update failed'
            exit 1
        fi
    " | tee -a /tmp/statusline-deploy.log

    log_success "Configuration updated successfully"
}

validate_remote() {
    local host="$1"
    local user="$2"

    log_header "Validating Deployment on FGSRV6"

    # Transfer test script
    log_info "Transferring validation script..."
    scp -q "$TEST_DIR/quick-test.sh" "$user@$host:/tmp/statusline-quick-test.sh"

    # Run validation
    log_info "Running validation tests..."
    ssh "$user@$host" "
        chmod +x /tmp/statusline-quick-test.sh
        cd ~
        /tmp/statusline-quick-test.sh .claude/statusline-command.sh
    " | tee -a /tmp/statusline-deploy.log

    # Test with sample input
    log_info "Testing with sample Claude Code input..."
    ssh "$user@$host" "
        cat << 'INPUT' | .claude/statusline-command.sh
        {
            \"model\": {
                \"display_name\": \"Sonnet 4.5\"
            },
            \"cwd\": \"/home/$user\"
        }
INPUT
    " | tee -a /tmp/statusline-deploy.log

    log_success "Validation completed"
}

rollback_remote() {
    local host="$1"
    local user="$2"

    log_header "Rolling Back Deployment on FGSRV6"

    log_info "Finding most recent backup..."
    local backup_info
    backup_info=$(ssh "$user@$host" "
        ls -t .claude/settings.json.backup.* 2>/dev/null | head -1
    " | tee -a /tmp/statusline-deploy.log)

    if [ -z "$backup_info" ]; then
        log_error "No backup found on $host"
        log_info "Disabling statusline instead..."
        ssh "$user@$host" "
            jq 'del(.statusLine)' .claude/settings.json > .claude/settings.json.tmp
            mv .claude/settings.json.tmp .claude/settings.json
            echo 'Statusline disabled'
        "
    else
        log_info "Rolling back to: $backup_info"
        ssh "$user@$host" "
            cp '$backup_info' .claude/settings.json
            echo 'Configuration restored'
        "
    fi

    log_success "Rollback completed"
    log_info "Please restart Claude Code on $host to see changes"
}

full_pipeline() {
    local host="$1"
    local user="$2"

    log_header "Full Deployment Pipeline"

    # Step 1: Run tests
    log_info "Step 1/3: Running tests..."
    if ! run_tests; then
        log_error "Tests failed! Aborting deployment."
        return 1
    fi

    # Step 2: Deploy
    log_info "Step 2/3: Deploying to $host..."
    deploy_statusline "$host" "$user"
    update_config "$host" "$user"

    # Step 3: Validate
    log_info "Step 3/3: Validating deployment..."
    validate_remote "$host" "$user"

    log_success "Full deployment pipeline completed successfully!"
    log_info "Statusline is now active on $host"
    log_info "Please restart Claude Code to see the statusline"
# Main execution
}

main() {
    local command="${1:-}"

    case "$command" in
        test)
            check_dependencies
            run_tests
            ;;
        deploy)
            check_dependencies

            if [ -z "$FGSRV6_HOST" ]; then
                log_error "FGSRV6_HOST environment variable is required"
                log_info "Usage: FGSRV6_HOST=fgsrv6.example.com $0 deploy"
                exit 1
            fi

            local user="${FGSRV6_USER:-$USER}"
            deploy_statusline "$FGSRV6_HOST" "$user"
            update_config "$FGSRV6_HOST" "$user"
            ;;
        validate)
            if [ -z "$FGSRV6_HOST" ]; then
                log_error "FGSRV6_HOST environment variable is required"
                exit 1
            fi

            local user="${FGSRV6_USER:-$USER}"
            validate_remote "$FGSRV6_HOST" "$user"
            ;;
        rollback)
            if [ -z "$FGSRV6_HOST" ]; then
                log_error "FGSRV6_HOST environment variable is required"
                exit 1
            fi

            local user="${FGSRV6_USER:-$USER}"
            rollback_remote "$FGSRV6_HOST" "$user"
            ;;
        full)
            check_dependencies

            if [ -z "$FGSRV6_HOST" ]; then
                log_error "FGSRV6_HOST environment variable is required"
                log_info "Usage: FGSRV6_HOST=fgsrv6.example.com $0 full"
                exit 1
            fi

            local user="${FGSRV6_USER:-$USER}"
            full_pipeline "$FGSRV6_HOST" "$user"
            ;;
        help|--help|-h)
            print_usage
            ;;
        *)
            log_error "Unknown command: $command"
            print_usage
            exit 1
            ;;
    esac
}

# Run main
main "$@"
