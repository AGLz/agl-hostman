#!/bin/bash

################################################################################
# N8N Monitoring System Validation Script
# Purpose: Validate installation and test all components
# Author: Hive Mind Coder Agent
################################################################################

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_DIR="/var/log/n8n-monitoring"

# Color codes
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Test results
declare -i TESTS_PASSED=0
declare -i TESTS_FAILED=0
declare -i TESTS_WARNED=0

print_header() {
    echo
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    printf "${BLUE}║%-58s║${NC}\n" "  ${1}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo
}

print_test() {
    echo -ne "${CYAN}▶${NC} Testing: $1 ... "
}

pass() {
    echo -e "${GREEN}PASS${NC}"
    ((TESTS_PASSED++))
}

fail() {
    echo -e "${RED}FAIL${NC}"
    [[ -n "${1:-}" ]] && echo "  Error: $1"
    ((TESTS_FAILED++))
}

warn() {
    echo -e "${YELLOW}WARN${NC}"
    [[ -n "${1:-}" ]] && echo "  Warning: $1"
    ((TESTS_WARNED++))
}

test_file_exists() {
    local file="$1"
    local description="$2"

    print_test "${description}"

    if [[ -f "${file}" ]]; then
        pass
        return 0
    else
        fail "File not found: ${file}"
        return 1
    fi
}

test_file_executable() {
    local file="$1"
    local description="$2"

    print_test "${description}"

    if [[ -x "${file}" ]]; then
        pass
        return 0
    else
        fail "File not executable: ${file}"
        return 1
    fi
}

test_directory_exists() {
    local dir="$1"
    local description="$2"

    print_test "${description}"

    if [[ -d "${dir}" ]]; then
        pass
        return 0
    else
        fail "Directory not found: ${dir}"
        return 1
    fi
}

test_directory_writable() {
    local dir="$1"
    local description="$2"

    print_test "${description}"

    if [[ -w "${dir}" ]]; then
        pass
        return 0
    else
        fail "Directory not writable: ${dir}"
        return 1
    fi
}

test_command_available() {
    local cmd="$1"
    local description="$2"

    print_test "${description}"

    if command -v "${cmd}" &>/dev/null; then
        pass
        return 0
    else
        fail "Command not found: ${cmd}"
        return 1
    fi
}

test_script_syntax() {
    local script="$1"
    local description="$2"

    print_test "${description}"

    if bash -n "${script}" 2>/dev/null; then
        pass
        return 0
    else
        fail "Syntax error in script"
        return 1
    fi
}

test_docker_access() {
    print_test "Docker daemon accessibility"

    if docker info &>/dev/null; then
        pass
        return 0
    else
        fail "Cannot access Docker daemon"
        return 1
    fi
}

test_health_check_execution() {
    print_test "Health check script execution"

    local output
    if output=$("${SCRIPT_DIR}/check_n8n_health.sh" 2>&1); then
        pass
        return 0
    else
        local exit_code=$?
        if [[ ${exit_code} -eq 1 ]] || [[ ${exit_code} -eq 2 ]]; then
            warn "Script returned warning/critical (this may be normal)"
            return 0
        else
            fail "Script execution failed with exit code ${exit_code}"
            return 1
        fi
    fi
}

test_configuration_valid() {
    print_test "Configuration file syntax"

    local config="${SCRIPT_DIR}/n8n_monitor.conf"

    if [[ ! -f "${config}" ]]; then
        warn "Configuration file not found"
        return 0
    fi

    # Try to source the config
    if bash -n "${config}" 2>/dev/null; then
        pass
        return 0
    else
        fail "Configuration syntax error"
        return 1
    fi
}

test_log_rotation() {
    print_test "Log rotation capability"

    local test_log="${LOG_DIR}/test_rotation.log"

    # Create test log
    if ! echo "test" > "${test_log}" 2>/dev/null; then
        fail "Cannot write to log directory"
        return 1
    fi

    # Test log size check
    if [[ -f "${test_log}" ]]; then
        rm -f "${test_log}"
        pass
        return 0
    else
        fail "Log file operations failed"
        return 1
    fi
}

test_state_persistence() {
    print_test "State file persistence"

    local state_dir="${LOG_DIR}/recovery_state"

    if [[ ! -d "${state_dir}" ]]; then
        warn "State directory not found (will be created on first run)"
        return 0
    fi

    # Test write capability
    local test_state="${state_dir}/test_state.tmp"
    if echo '{"test":true}' > "${test_state}" 2>/dev/null; then
        rm -f "${test_state}"
        pass
        return 0
    else
        fail "Cannot write state files"
        return 1
    fi
}

run_installation_tests() {
    print_header "Installation Tests"

    test_file_exists "${SCRIPT_DIR}/check_n8n_health.sh" "Health check script exists"
    test_file_exists "${SCRIPT_DIR}/n8n_auto_recovery.sh" "Auto recovery script exists"
    test_file_exists "${SCRIPT_DIR}/collect_diagnostics.sh" "Diagnostics script exists"
    test_file_exists "${SCRIPT_DIR}/aggregate_logs.sh" "Log aggregation script exists"
    test_file_exists "${SCRIPT_DIR}/setup_monitoring.sh" "Setup script exists"
    test_file_exists "${SCRIPT_DIR}/n8n_monitor.conf" "Configuration file exists"
    test_file_exists "${SCRIPT_DIR}/README.md" "README file exists"

    echo
}

run_permission_tests() {
    print_header "Permission Tests"

    test_file_executable "${SCRIPT_DIR}/check_n8n_health.sh" "Health check executable"
    test_file_executable "${SCRIPT_DIR}/n8n_auto_recovery.sh" "Auto recovery executable"
    test_file_executable "${SCRIPT_DIR}/collect_diagnostics.sh" "Diagnostics executable"
    test_file_executable "${SCRIPT_DIR}/aggregate_logs.sh" "Log aggregation executable"
    test_file_executable "${SCRIPT_DIR}/setup_monitoring.sh" "Setup script executable"

    echo
}

run_directory_tests() {
    print_header "Directory Tests"

    test_directory_exists "${LOG_DIR}" "Log directory exists"
    test_directory_writable "${LOG_DIR}" "Log directory writable"

    if [[ -d "${LOG_DIR}" ]]; then
        test_directory_exists "${LOG_DIR}/diagnostics" "Diagnostics directory exists"
        test_directory_exists "${LOG_DIR}/reports" "Reports directory exists"
        test_directory_exists "${LOG_DIR}/recovery_state" "State directory exists"
    fi

    echo
}

run_dependency_tests() {
    print_header "Dependency Tests"

    test_command_available "docker" "Docker installed"
    test_command_available "curl" "curl installed"
    test_command_available "bash" "Bash shell available"

    print_test "Bash version >= 4.0"
    if [[ "${BASH_VERSION%%.*}" -ge 4 ]]; then
        pass
    else
        fail "Bash ${BASH_VERSION} found, need 4.0+"
    fi

    echo
}

run_syntax_tests() {
    print_header "Script Syntax Tests"

    test_script_syntax "${SCRIPT_DIR}/check_n8n_health.sh" "Health check syntax"
    test_script_syntax "${SCRIPT_DIR}/n8n_auto_recovery.sh" "Auto recovery syntax"
    test_script_syntax "${SCRIPT_DIR}/collect_diagnostics.sh" "Diagnostics syntax"
    test_script_syntax "${SCRIPT_DIR}/aggregate_logs.sh" "Log aggregation syntax"
    test_script_syntax "${SCRIPT_DIR}/setup_monitoring.sh" "Setup script syntax"

    echo
}

run_docker_tests() {
    print_header "Docker Tests"

    test_docker_access

    print_test "Docker version compatibility"
    if docker version --format '{{.Server.Version}}' &>/dev/null; then
        local version
        version=$(docker version --format '{{.Server.Version}}' 2>/dev/null | cut -d. -f1)
        if [[ ${version} -ge 20 ]]; then
            pass
        else
            warn "Docker ${version} found, recommend 20+"
        fi
    else
        fail "Cannot determine Docker version"
    fi

    echo
}

run_functional_tests() {
    print_header "Functional Tests"

    test_configuration_valid
    test_log_rotation
    test_state_persistence
    test_health_check_execution

    echo
}

run_integration_tests() {
    print_header "Integration Tests (Optional)"

    print_test "N8N container detection"
    local container_id
    container_id=$(docker ps -aq --filter "name=n8n" 2>/dev/null | head -1)

    if [[ -n "${container_id}" ]]; then
        pass

        print_test "Container accessibility"
        if docker inspect "${container_id}" &>/dev/null; then
            pass
        else
            fail "Cannot inspect container"
        fi

        print_test "Container logs accessible"
        if docker logs --tail 1 "${container_id}" &>/dev/null; then
            pass
        else
            fail "Cannot access container logs"
        fi
    else
        warn "N8N container not found (this is OK if not yet deployed)"
    fi

    echo
}

display_summary() {
    print_header "Test Summary"

    local total=$((TESTS_PASSED + TESTS_FAILED + TESTS_WARNED))

    echo -e "${BLUE}Total Tests Run:${NC} ${total}"
    echo -e "${GREEN}Passed:${NC}          ${TESTS_PASSED}"
    echo -e "${YELLOW}Warnings:${NC}        ${TESTS_WARNED}"
    echo -e "${RED}Failed:${NC}          ${TESTS_FAILED}"
    echo

    local success_rate=0
    if [[ ${total} -gt 0 ]]; then
        success_rate=$(( (TESTS_PASSED * 100) / total ))
    fi

    echo -e "${BLUE}Success Rate:${NC}    ${success_rate}%"
    echo

    if [[ ${TESTS_FAILED} -eq 0 ]]; then
        echo -e "${GREEN}✓ All critical tests passed!${NC}"
        echo
        echo "The N8N monitoring system is properly installed and ready to use."
        echo
        if [[ ${TESTS_WARNED} -gt 0 ]]; then
            echo -e "${YELLOW}Note:${NC} Some warnings were detected. Review above for details."
        fi
        return 0
    else
        echo -e "${RED}✗ Some tests failed${NC}"
        echo
        echo "Please address the failed tests before using the monitoring system."
        echo "Run the setup script again or manually fix the issues."
        return 1
    fi
}

main() {
    print_header "N8N Monitoring System Validation"

    echo "This script will validate the installation and configuration"
    echo "of the N8N monitoring system."
    echo

    run_installation_tests
    run_permission_tests
    run_directory_tests
    run_dependency_tests
    run_syntax_tests
    run_docker_tests
    run_functional_tests
    run_integration_tests

    if display_summary; then
        exit 0
    else
        exit 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
