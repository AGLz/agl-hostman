#!/bin/bash

################################################################################
# Hive Mind Runner - Universal Script
# Runs Hive Mind Worker Pool locally or in Docker
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

################################################################################
# Helper Functions
################################################################################

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

detect_environment() {
    log_info "Detecting environment..."

    # Check if running in Docker
    if [ -f /.dockerenv ]; then
        echo "docker"
        return
    fi

    # Check if Docker is available
    if command -v docker &> /dev/null && docker info &> /dev/null 2>&1; then
        echo "docker-available"
        return
    fi

    # Check if Node.js is available
    if command -v node &> /dev/null; then
        echo "node"
        return
    fi

    echo "unknown"
}

check_node() {
    if ! command -v node &> /dev/null; then
        log_error "Node.js is not installed. Please install Node.js 18 or higher."
        exit 1
    fi

    local node_version
    node_version=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)

    if [ "${node_version}" -lt 18 ]; then
        log_error "Node.js version 18 or higher is required. Current version: $(node -v)"
        exit 1
    fi

    log_success "Node.js $(node -v) detected"
}

install_dependencies() {
    log_info "Installing dependencies..."

    cd "${PROJECT_ROOT}"

    if [ -f "pnpm-lock.yaml" ] && command -v pnpm &> /dev/null; then
        pnpm install
    elif [ -f "package-lock.json" ]; then
        npm ci
    else
        npm install
    fi

    log_success "Dependencies installed"
}

################################################################################
# Run Functions
################################################################################

run_local_interactive() {
    log_info "Starting Hive Mind in local interactive mode..."

    cd "${PROJECT_ROOT}"

    # Create a Node.js REPL with Hive Mind preloaded
    node -i -e "
const { HiveMindWorkerPool, AgentTemplates, PerformanceMonitor } = require('./src/hive-mind-integration');

console.log('\n╔════════════════════════════════════════════════════════════════╗');
console.log('║         Hive Mind Worker Pool - Interactive Mode              ║');
console.log('╚════════════════════════════════════════════════════════════════╝\n');

console.log('Available objects:');
console.log('  • HiveMindWorkerPool - Main worker pool class');
console.log('  • AgentTemplates     - Agent template definitions');
console.log('  • PerformanceMonitor - Performance monitoring utilities\n');

console.log('Quick start:');
console.log('  const pool = new HiveMindWorkerPool();');
console.log('  pool.getAvailableAgentTypes();');
console.log('  const agents = await pool.spawnAgentsParallel([');
console.log('    { type: \"researcher\", name: \"R1\" },');
console.log('    { type: \"coder\", name: \"C1\" }');
console.log('  ], \"test-swarm\");\n');

console.log('Type .help for Node.js REPL help\n');
"
}

run_local_script() {
    local script_file="$1"

    log_info "Running script: ${script_file}..."

    cd "${PROJECT_ROOT}"

    if [ ! -f "${script_file}" ]; then
        log_error "Script file not found: ${script_file}"
        exit 1
    fi

    node "${script_file}"
}

run_tests() {
    log_info "Running Hive Mind test suite..."

    cd "${PROJECT_ROOT}"

    # Run basic integration tests
    log_info "Running basic integration tests..."
    node tests/hive-mind/test-hive-mind-integration.js

    echo ""

    # Run extended features tests
    log_info "Running extended features tests..."
    node tests/hive-mind/test-extended-features.js

    log_success "All tests completed"
}

run_example() {
    local example_name="$1"

    log_info "Running example: ${example_name}..."

    cd "${PROJECT_ROOT}"

    local example_file="examples/${example_name}"

    if [ ! -f "${example_file}" ]; then
        # Try with .js extension
        example_file="examples/${example_name}.js"

        if [ ! -f "${example_file}" ]; then
            log_error "Example file not found: ${example_name}"
            exit 1
        fi
    fi

    node "${example_file}"
}

list_examples() {
    log_info "Available examples:"

    cd "${PROJECT_ROOT}"

    if [ -d "examples" ]; then
        ls -1 examples/hive-mind-*.js 2>/dev/null | while read -r file; do
            echo "  • $(basename "${file}")"
        done
    else
        log_warning "No examples directory found"
    fi
}

run_quick_demo() {
    log_info "Running quick Hive Mind demo..."

    cd "${PROJECT_ROOT}"

    node << 'EOF'
const { HiveMindWorkerPool } = require('./src/hive-mind-integration');

(async () => {
  console.log('\n═══════════════════════════════════════════════════════════');
  console.log('           Hive Mind Quick Demo');
  console.log('═══════════════════════════════════════════════════════════\n');

  const pool = new HiveMindWorkerPool();

  // Show available agent types
  console.log('📋 Available Agent Types:');
  const types = pool.getAvailableAgentTypes();
  types.forEach(type => console.log(`  • ${type}`));

  console.log('\n⚡ Spawning 4 agents in parallel...\n');

  const startTime = Date.now();

  try {
    const agents = await pool.spawnAgentsParallel([
      { type: 'researcher', name: 'R1' },
      { type: 'coder', name: 'C1' },
      { type: 'analyst', name: 'A1' },
      { type: 'tester', name: 'T1' }
    ], 'demo-swarm');

    const duration = Date.now() - startTime;

    console.log('✅ Agents spawned successfully!');
    console.log(`   Time: ${duration}ms`);
    console.log(`   Count: ${agents.length} agents\n`);

    // Show dashboard
    console.log('📊 Dashboard Status:');
    const dashboard = pool.getDashboard();
    console.log(`   Active agents: ${dashboard.agents.active}`);
    console.log(`   Total agents: ${dashboard.agents.total}`);
    console.log(`   Workers: ${dashboard.workers.active}/${dashboard.workers.total}`);

    // Get monitoring summary
    console.log('\n🔍 System Summary:');
    const summary = pool.getMonitoringSummary();
    console.log(`   Status: ${summary.status}`);
    console.log(`   Uptime: ${Math.floor(summary.uptime / 1000)}s`);

  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    await pool.terminate();
    console.log('\n✅ Demo completed\n');
  }
})();
EOF
}

################################################################################
# Usage
################################################################################

show_usage() {
    cat << 'EOF'
Usage: ./scripts/run-hive-mind.sh <command> [options]

Commands:
  interactive   Start interactive Node.js REPL with Hive Mind loaded
  demo          Run quick demonstration
  test          Run test suite
  example NAME  Run example file (e.g., hive-mind-parallel-agents)
  script FILE   Run custom script file
  list          List available examples
  install       Install dependencies

Environment:
  The script auto-detects the environment and runs:
  • Locally with Node.js (if Docker not available)
  • In Docker container (if Docker is running)

Examples:
  ./scripts/run-hive-mind.sh interactive
  ./scripts/run-hive-mind.sh demo
  ./scripts/run-hive-mind.sh test
  ./scripts/run-hive-mind.sh example hive-mind-parallel-agents
  ./scripts/run-hive-mind.sh script my-custom-script.js

EOF
}

################################################################################
# Main Script
################################################################################

main() {
    if [ $# -eq 0 ]; then
        show_usage
        exit 0
    fi

    local command="$1"
    shift

    # Detect environment
    local env
    env=$(detect_environment)

    if [ "${env}" = "unknown" ]; then
        log_error "Neither Docker nor Node.js is available. Please install Node.js 18+."
        exit 1
    fi

    if [ "${env}" = "node" ] || [ "${env}" = "docker" ]; then
        log_info "Running in local Node.js mode"
        check_node
    fi

    case "${command}" in
        interactive|repl)
            run_local_interactive
            ;;
        demo)
            run_quick_demo
            ;;
        test)
            run_tests
            ;;
        example)
            if [ $# -eq 0 ]; then
                log_error "Please specify an example name"
                list_examples
                exit 1
            fi
            run_example "$1"
            ;;
        script)
            if [ $# -eq 0 ]; then
                log_error "Please specify a script file"
                exit 1
            fi
            run_local_script "$1"
            ;;
        list)
            list_examples
            ;;
        install)
            install_dependencies
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            log_error "Unknown command: ${command}"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
EOF
