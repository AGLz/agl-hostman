#!/bin/bash

#############################################################################
# Statusline Deployment Script - Multi-Host Deployment
#############################################################################
#
# Purpose: Deploy statusline-command.sh to multiple infrastructure hosts
# Template: Based on copy-statusline-to-fgsrv6.sh
# Task ID: 756e6dca-7b1a-4d99-a640-bd6a5568f643
# Project: FGSRV6 Statusline Deployment (e61f909a-bfee-486c-8f11-22a2fd9cbf6f)
#
# Features:
# - Parallel deployment to multiple hosts
# - jq dependency verification and auto-installation
# - Backup and rollback capabilities
# - Comprehensive validation
# - Deployment reporting
#
#############################################################################

set -euo pipefail

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
PROJECT_ROOT="/mnt/overpower/apps/dev/agl/agl-hostman"
SOURCE_FILE="$PROJECT_ROOT/.claude/statusline-command.sh"
IDENTITY_FILE="${IDENTITY_FILE:-$HOME/.ssh/fg_srv.pem}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DEPLOY_LOG="/tmp/statusline-deploy-${TIMESTAMP}.log"
REPORT_FILE="${PROJECT_ROOT}/docs/statusline-deployment-report-${TIMESTAMP}.md"

# Default hosts to deploy (can be overridden via command line or config)
DEFAULT_HOSTS=(
    "aglsrv1:192.168.0.245:/root/.claude"
    "aglsrv6-ts:100.98.108.66:/root/.claude"
    "ct179-ts:100.94.221.87:/root/.claude"
    "ct180-ts:100.80.30.60:/root/.claude"
    "ct183-ts:100.80.30.59:/root/.claude"
    "fgsrv6-ts:100.83.51.9:/root/.claude"
)

# Parse command line arguments
HOSTS_TO_DEPLOY=()
PARALLEL_MODE=false
DRY_RUN=false
SKIP_JQ_CHECK=false
FORCE_DEPLOY=false

#############################################################################
# Helper Functions
#############################################################################

log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case $level in
        INFO)
            echo -e "${BLUE}[INFO]${NC} ${message}" | tee -a "$DEPLOY_LOG"
            ;;
        SUCCESS)
            echo -e "${GREEN}[✓]${NC} ${message}" | tee -a "$DEPLOY_LOG"
            ;;
        WARNING)
            echo -e "${YELLOW}[!]${NC} ${message}" | tee -a "$DEPLOY_LOG"
            ;;
        ERROR)
            echo -e "${RED}[✗]${NC} ${message}" | tee -a "$DEPLOY_LOG"
            ;;
        HEADER)
            echo -e "${CYAN}${message}${NC}" | tee -a "$DEPLOY_LOG"
            ;;
    esac
}

print_usage() {
    cat << 'EOF'
Statusline Deployment Script - Multi-Host Deployment

Usage: deploy-statusline-to-hosts.sh [OPTIONS]

Options:
    --help                  Show this help message
    --hosts HOST1,HOST2     Comma-separated list of hosts to deploy
    --parallel              Enable parallel deployment mode
    --dry-run               Show what would be done without making changes
    --skip-jq-check         Skip jq dependency verification
    --force                 Deploy even if statusline already exists

Host Format:
    hostname:ip:target_dir
    Example: aglsrv1:192.168.0.245:/root/.claude

Available Predefined Hosts:
    - aglsrv1: Main Proxmox Host (192.168.0.245)
    - aglsrv6-ts: Remote Proxmox via Tailscale (100.98.108.66)
    - ct179-ts: agldv03 Dev via Tailscale (100.94.221.87)
    - ct180-ts: Dokploy via Tailscale (100.80.30.60)
    - ct183-ts: Archon MCP via Tailscale (100.80.30.59)
    - fgsrv6-ts: WireGuard Hub via Tailscale (100.83.51.9)

Environment Variables:
    IDENTITY_FILE    SSH private key file (default: ~/.ssh/fg_srv.pem)
    TARGET_USER      SSH user (default: root)

Examples:
    # Deploy to all predefined hosts
    ./deploy-statusline-to-hosts.sh

    # Deploy to specific hosts in parallel
    ./deploy-statusline-to-hosts.sh --hosts aglsrv1,ct179-ts --parallel

    # Dry run to test deployment
    ./deploy-statusline-to-hosts.sh --dry-run

    # Deploy to custom host
    ./deploy-statusline-to-hosts.sh --hosts myhost:192.168.1.100:/root/.claude

EOF
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help)
                print_usage
                exit 0
                ;;
            --hosts)
                IFS=',' read -ra HOSTS_TO_DEPLOY <<< "$2"
                shift 2
                ;;
            --parallel)
                PARALLEL_MODE=true
                log INFO "Parallel deployment mode enabled"
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                log WARNING "DRY RUN MODE - no changes will be made"
                shift
                ;;
            --skip-jq-check)
                SKIP_JQ_CHECK=true
                log WARNING "Skipping jq dependency verification"
                shift
                ;;
            --force)
                FORCE_DEPLOY=true
                log WARNING "Force deploy enabled - will overwrite existing files"
                shift
                ;;
            *)
                log ERROR "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done

    # Use default hosts if none specified
    if [ ${#HOSTS_TO_DEPLOY[@]} -eq 0 ]; then
        HOSTS_TO_DEPLOY=("${DEFAULT_HOSTS[@]}")
    fi
}

#############################################################################
# Validation Functions
#############################################################################

validate_source() {
    log INFO "Validating source file..."

    if [ ! -f "$SOURCE_FILE" ]; then
        log ERROR "Source file not found: $SOURCE_FILE"
        return 1
    fi

    if [ ! -r "$SOURCE_FILE" ]; then
        log ERROR "Source file not readable: $SOURCE_FILE"
        return 1
    fi

    local size=$(stat -c%s "$SOURCE_FILE" 2>/dev/null || stat -f%z "$SOURCE_FILE" 2>/dev/null)
    log SUCCESS "Source file validated: $SOURCE_FILE ($size bytes)"
    return 0
}

parse_host_spec() {
    local host_spec=$1
    local hostname=$(echo "$host_spec" | cut -d: -f1)
    local ip=$(echo "$host_spec" | cut -d: -f2)
    local target_dir=$(echo "$host_spec" | cut -d: -f3)

    echo "$hostname|$ip|$target_dir"
}

test_ssh_connection() {
    local hostname=$1
    local ip=$2
    local user="${TARGET_USER:-root}"

    log INFO "Testing SSH connection to ${user}@${ip}..."

    if [ "$DRY_RUN" = true ]; then
        log WARNING "DRY RUN: Skipping connection test"
        return 0
    fi

    if ssh -i "$IDENTITY_FILE" -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
        "${user}@${ip}" "echo 'Connection OK'" >/dev/null 2>&1; then
        log SUCCESS "SSH connection to ${hostname} successful"
        return 0
    else
        log ERROR "Cannot connect to ${user}@${ip} (${hostname})"
        return 1
    fi
}

verify_jq_dependency() {
    local hostname=$1
    local ip=$2
    local user="${TARGET_USER:-root}"

    if [ "$SKIP_JQ_CHECK" = true ]; then
        log WARNING "Skipping jq check on ${hostname}"
        return 0
    fi

    log INFO "Checking jq dependency on ${hostname}..."

    if [ "$DRY_RUN" = true ]; then
        log WARNING "DRY RUN: Would check jq on ${hostname}"
        return 0
    fi

    local jq_check
    jq_check=$(ssh -i "$IDENTITY_FILE" -o ConnectTimeout=10 "${user}@${ip}" \
        "which jq >/dev/null 2>&1 && echo 'INSTALLED' || echo 'MISSING'" 2>/dev/null)

    if [ "$jq_check" = "INSTALLED" ]; then
        local jq_version=$(ssh -i "$IDENTITY_FILE" "${user}@${ip}" "jq --version" 2>/dev/null)
        log SUCCESS "jq is installed on ${hostname} (${jq_version})"
        return 0
    else
        log WARNING "jq is NOT installed on ${hostname}"
        log INFO "Attempting to install jq on ${hostname}..."

        # Attempt to install jq
        if ssh -i "$IDENTITY_FILE" "${user}@${ip}" \
            "apt-get update -qq && apt-get install -y jq >/dev/null 2>&1"; then
            log SUCCESS "jq installed successfully on ${hostname}"
            return 0
        else
            log ERROR "Failed to install jq on ${hostname}"
            log INFO "Please install jq manually: ssh ${user}@${ip} 'apt-get install -y jq'"
            return 1
        fi
    fi
}

#############################################################################
# Deployment Functions
#############################################################################

create_backup() {
    local hostname=$1
    local ip=$2
    local target_dir=$3
    local user="${TARGET_USER:-root}"
    local timestamp=$(date +%Y%m%d_%H%M%S)

    if [ "$DRY_RUN" = true ]; then
        log WARNING "DRY RUN: Would create backup on ${hostname} with timestamp: ${timestamp}"
        return 0
    fi

    log INFO "Creating backup on ${hostname}..."

    ssh -i "$IDENTITY_FILE" "${user}@${ip}" "
        # Create target directory if it doesn't exist
        mkdir -p ${target_dir}

        # Backup statusline script if exists
        if [ -f ${target_dir}/statusline-command.sh ]; then
            cp ${target_dir}/statusline-command.sh ${target_dir}/statusline-command.sh.backup.${timestamp}
            echo 'Backup created: statusline-command.sh.backup.${timestamp}'
        else
            echo 'No existing statusline script to backup'
        fi

        # List backups
        echo 'Current backups:'
        ls -lh ${target_dir}/*.backup.* 2>/dev/null || echo 'No backups found'
    " 2>&1 | tee -a "$DEPLOY_LOG"

    log SUCCESS "Backup completed on ${hostname}"
    return 0
}

transfer_file() {
    local hostname=$1
    local ip=$2
    local target_dir=$3
    local user="${TARGET_USER:-root}"

    log INFO "Transferring statusline-command.sh to ${hostname}..."

    if [ "$DRY_RUN" = true ]; then
        log WARNING "DRY RUN: Would transfer to ${user}@${ip}:${target_dir}/statusline-command.sh"
        return 0
    fi

    if scp -i "$IDENTITY_FILE" -q "$SOURCE_FILE" "${user}@${ip}:${target_dir}/statusline-command.sh"; then
        log SUCCESS "File transferred successfully to ${hostname}"
        return 0
    else
        log ERROR "File transfer failed to ${hostname}"
        return 1
    fi
}

set_permissions() {
    local hostname=$1
    local ip=$2
    local target_dir=$3
    local user="${TARGET_USER:-root}"

    log INFO "Setting executable permissions on ${hostname}..."

    if [ "$DRY_RUN" = true ]; then
        log WARNING "DRY RUN: Would set permissions on ${hostname}"
        return 0
    fi

    ssh -i "$IDENTITY_FILE" "${user}@${ip}" "chmod +x ${target_dir}/statusline-command.sh"
    log SUCCESS "Permissions set on ${hostname}"
    return 0
}

validate_deployment() {
    local hostname=$1
    local ip=$2
    local target_dir=$3
    local user="${TARGET_USER:-root}"

    log INFO "Validating deployment on ${hostname}..."

    if [ "$DRY_RUN" = true ]; then
        log WARNING "DRY RUN: Skipping validation on ${hostname}"
        return 0
    fi

    local validation_result
    validation_result=$(ssh -i "$IDENTITY_FILE" "${user}@${ip}" "
        echo '=== Validation Checks ==='

        # Check file exists
        if [ -f ${target_dir}/statusline-command.sh ]; then
            echo '✓ File exists'
        else
            echo '✗ File not found'
            exit 1
        fi

        # Check executable
        if [ -x ${target_dir}/statusline-command.sh ]; then
            echo '✓ File is executable'
        else
            echo '✗ File not executable'
            exit 1
        fi

        # Check file size
        SIZE=\$(stat -c%s ${target_dir}/statusline-command.sh 2>/dev/null || stat -f%z ${target_dir}/statusline-command.sh 2>/dev/null)
        echo \"✓ File size: \$SIZE bytes\"

        # Test execution with sample input
        echo '✓ Testing execution with sample input:'
        echo '{\"model\": {\"display_name\": \"Claude Sonnet 4.5\"}, \"workspace\": {\"current_dir\": \"/root\"}}' | ${target_dir}/statusline-command.sh | head -c 100

        echo '=== Validation Complete ==='
    " 2>&1)

    echo "$validation_result" | tee -a "$DEPLOY_LOG"

    if echo "$validation_result" | grep -q "✗"; then
        log ERROR "Validation failed on ${hostname}"
        return 1
    else
        log SUCCESS "Validation passed on ${hostname}"
        return 0
    fi
}

rollback_deployment() {
    local hostname=$1
    local ip=$2
    local target_dir=$3
    local user="${TARGET_USER:-root}"

    log ERROR "Deployment failed on ${hostname}. Attempting rollback..."

    if [ "$DRY_RUN" = true ]; then
        log WARNING "DRY RUN: Would perform rollback on ${hostname}"
        return 1
    fi

    ssh -i "$IDENTITY_FILE" "${user}@${ip}" "
        LATEST_BACKUP=\$(ls -t ${target_dir}/statusline-command.sh.backup.* 2>/dev/null | head -1)
        if [ -n \"\$LATEST_BACKUP\" ]; then
            cp \"\$LATEST_BACKUP\" ${target_dir}/statusline-command.sh
            echo \"Rolled back to: \$LATEST_BACKUP\"
        else
            echo 'No backup available for rollback'
        fi
    " 2>&1 | tee -a "$DEPLOY_LOG"

    return 1
}

#############################################################################
# Deployment Orchestration
#############################################################################

deploy_to_host() {
    local host_spec=$1
    local host_info=$(parse_host_spec "$host_spec")
    local hostname=$(echo "$host_info" | cut -d| -f1)
    local ip=$(echo "$host_info" | cut -d| -f2)
    local target_dir=$(echo "$host_info" | cut -d| -f3)

    log HEADER "=========================================="
    log HEADER "Deploying to ${hostname} (${ip})"
    log HEADER "=========================================="

    # Check if statusline already exists
    if [ "$FORCE_DEPLOY" = false ]; then
        local exists_check
        exists_check=$(ssh -i "$IDENTITY_FILE" -o ConnectTimeout=5 "${TARGET_USER:-root}@${ip}" \
            "test -f ${target_dir}/statusline-command.sh && echo 'EXISTS' || echo 'NEW'" 2>/dev/null || echo "NEW")

        if [ "$exists_check" = "EXISTS" ]; then
            log WARNING "Statusline already exists on ${hostname}. Use --force to overwrite."
            log INFO "Skipping ${hostname}"
            return 0
        fi
    fi

    # Execute deployment steps
    test_ssh_connection "$hostname" "$ip" || return 1
    verify_jq_dependency "$hostname" "$ip" || return 1
    create_backup "$hostname" "$ip" "$target_dir" || return 1
    transfer_file "$hostname" "$ip" "$target_dir" || return 1
    set_permissions "$hostname" "$ip" "$target_dir" || return 1

    if validate_deployment "$hostname" "$ip" "$target_dir"; then
        log SUCCESS "Deployment to ${hostname} completed successfully"
        return 0
    else
        rollback_deployment "$hostname" "$ip" "$target_dir"
        return 1
    fi
}

deploy_parallel() {
    local pids=()
    local host_specs=("$@")

    log INFO "Starting parallel deployment to ${#host_specs[@]} hosts..."

    for host_spec in "${host_specs[@]}"; do
        deploy_to_host "$host_spec" &
        pids+=($!)
    done

    # Wait for all deployments
    local success_count=0
    local fail_count=0
    for pid in "${pids[@]}"; do
        if wait $pid; then
            ((success_count++))
        else
            ((fail_count++))
        fi
    done

    log INFO "Parallel deployment completed: ${success_count} succeeded, ${fail_count} failed"
    return $fail_count
}

deploy_sequential() {
    local host_specs=("$@")
    local success_count=0
    local fail_count=0

    for host_spec in "${host_specs[@]}"; do
        if deploy_to_host "$host_spec"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
        echo ""
    done

    log INFO "Sequential deployment completed: ${success_count} succeeded, ${fail_count} failed"
    return $fail_count
}

#############################################################################
# Reporting
#############################################################################

generate_deployment_report() {
    local success_count=$1
    local fail_count=$2
    local total_hosts=${#HOSTS_TO_DEPLOY[@]}

    cat > "$REPORT_FILE" <<EOF
# Statusline Deployment Report

**Generated**: $(date)
**Task ID**: 756e6dca-7b1a-4d99-a640-bd6a5568f643
**Project**: FGSRV6 Statusline Deployment (e61f909a-bfee-486c-8f11-22a2fd9cbf6f)

---

## Executive Summary

- **Total Hosts**: ${total_hosts}
- **Successful Deployments**: ${success_count}
- **Failed Deployments**: ${fail_count}
- **Success Rate**: $(( success_count * 100 / total_hosts ))%

---

## Deployment Details

EOF

    for host_spec in "${HOSTS_TO_DEPLOY[@]}"; do
        local host_info=$(parse_host_spec "$host_spec")
        local hostname=$(echo "$host_info" | cut -d| -f1)
        local ip=$(echo "$host_info" | cut -d| -f2)
        local target_dir=$(echo "$host_info" | cut -d| -f3)

        echo "### ${hostname}" >> "$REPORT_FILE"
        echo "- **IP**: ${ip}" >> "$REPORT_FILE"
        echo "- **Target Directory**: ${target_dir}" >> "$REPORT_FILE"
        echo "- **Status**: $(
            ssh -i "$IDENTITY_FILE" -o ConnectTimeout=5 "${TARGET_USER:-root}@${ip}" \
                "test -f ${target_dir}/statusline-command.sh && echo '✓ Deployed' || echo '✗ Failed'" 2>/dev/null || echo "Unknown"
        )" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
    done

    cat >> "$REPORT_FILE" <<EOF

---

## Next Steps

### For Each Deployed Host:

1. **Restart Claude Code** to see the statusline in action
2. **Verify settings.json** has the correct configuration:
   \`\`\`json
   {
     "statusLine": {
       "type": "command",
       "command": ".claude/statusline-command.sh"
     }
   }
   \`\`\`

3. **Test manually**:
   \`\`\`bash
   ssh [host] 'echo "{\"model\": {\"display_name\": \"Test\"}, \"workspace\": {\"current_dir\": \"/root\"}}" | .claude/statusline-command.sh'
   \`\`\`

### Rollback (if needed):

\`\`\`bash
ssh [host] 'ls -t .claude/statusline-command.sh.backup.* | head -1 | xargs -I {} cp {} .claude/statusline-command.sh'
\`\`\`

---

## Dependencies Verified

- **jq**: JSON processor (installed on all hosts)
- **bash**: Shell interpreter (required)
- **git**: Version control (optional, for branch display)
- **coreutils**: For file operations (required)

---

**Deployment Log**: ${DEPLOY_LOG}
**Report Generated**: $(date)

EOF

    log SUCCESS "Deployment report generated: ${REPORT_FILE}"
}

#############################################################################
# Main Execution
#############################################################################

main() {
    log HEADER "=========================================="
    log HEADER "  Statusline Multi-Host Deployment"
    log HEADER "=========================================="
    log INFO "Deployment log: ${DEPLOY_LOG}"
    log INFO "Source file: ${SOURCE_FILE}"
    echo ""

    # Parse arguments
    parse_arguments "$@"

    # Validate source
    validate_source || exit 1

    # Display deployment plan
    log INFO "Deployment Plan:"
    log INFO "  Hosts to deploy: ${#HOSTS_TO_DEPLOY[@]}"
    log INFO "  Parallel mode: ${PARALLEL_MODE}"
    log INFO "  Dry run: ${DRY_RUN}"
    echo ""

    for host_spec in "${HOSTS_TO_DEPLOY[@]}"; do
        local host_info=$(parse_host_spec "$host_spec")
        local hostname=$(echo "$host_info" | cut -d| -f1)
        local ip=$(echo "$host_info" | cut -d| -f2)
        log INFO "    - ${hostname} (${ip})"
    done
    echo ""

    # Execute deployment
    local success_count=0
    local fail_count=0

    if [ "$PARALLEL_MODE" = true ]; then
        deploy_parallel "${HOSTS_TO_DEPLOY[@]}" || fail_count=$?
        success_count=$(( ${#HOSTS_TO_DEPLOY[@]} - fail_count ))
    else
        for host_spec in "${HOSTS_TO_DEPLOY[@]}"; do
            if deploy_to_host "$host_spec"; then
                ((success_count++))
            else
                ((fail_count++))
            fi
            echo ""
        done
    fi

    # Generate report
    echo ""
    log HEADER "=========================================="
    log HEADER "  Deployment Summary"
    log HEADER "=========================================="
    log SUCCESS "Successful deployments: ${success_count}"
    if [ $fail_count -gt 0 ]; then
        log ERROR "Failed deployments: ${fail_count}"
    fi
    echo ""

    generate_deployment_report "$success_count" "$fail_count"

    # Exit with appropriate code
    if [ $fail_count -eq 0 ]; then
        log SUCCESS "All deployments completed successfully!"
        exit 0
    else
        log WARNING "Some deployments failed. Review the log and report for details."
        exit 1
    fi
}

# Run main with all arguments
main "$@"
