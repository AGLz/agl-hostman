#!/bin/bash
#
# API Test Execution Script
# =========================
#
# Executes all test suites for the Laravel API migration
#
# Usage:
#   ./run-tests.sh [suite]
#
# Suites:
#   all       - Run all tests (default)
#   smoke     - Run smoke tests only
#   feature   - Run feature tests only
#   unit      - Run unit tests only
#   security  - Run security tests only
#   coverage  - Run with code coverage
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PHPUNIT="vendor/bin/phpunit"
TEST_DIR="tests"
COVERAGE_DIR="coverage"

# Print banner
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Laravel API Test Execution Suite   ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check PHPUnit exists
if [ ! -f "$PHPUNIT" ]; then
    echo -e "${YELLOW}Installing PHPUnit...${NC}"
    composer install --dev
fi

# Function to run tests
run_tests() {
    local filter=$1
    local description=$2

    echo -e "${YELLOW}Running: $description${NC}"
    echo ""

    $PHPUNIT --colors=always $filter

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[✓] $description passed${NC}"
    else
        echo -e "${RED}[✗] $description failed${NC}"
        return 1
    fi
    echo ""
}

# Function to run with coverage
run_with_coverage() {
    echo -e "${YELLOW}Running tests with code coverage...${NC}"
    echo ""

    # Check if Xdebug is installed
    if ! php -m | grep -q xdebug; then
        echo -e "${RED}Xdebug not installed. Code coverage requires Xdebug.${NC}"
        echo "Install with: pecl install xdebug"
        exit 1
    fi

    mkdir -p $COVERAGE_DIR

    $PHPUNIT --coverage-html $COVERAGE_DIR --colors=always

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[✓] Tests passed${NC}"
        echo -e "${GREEN}Coverage report: $COVERAGE_DIR/index.html${NC}"
    else
        echo -e "${RED}[✗] Tests failed${NC}"
        return 1
    fi
}

# Parse argument
SUITE=${1:-all}

case $SUITE in
    smoke)
        run_tests "--filter SmokeTest" "Smoke Tests"
        ;;

    unit)
        run_tests "--filter Unit" "Unit Tests"
        ;;

    feature)
        run_tests "--filter Feature" "Feature Tests"
        ;;

    security)
        run_tests "--filter Security" "Security Tests"
        ;;

    recibo)
        run_tests "--filter ReciboTest" "Recibo API Tests"
        ;;

    boleto)
        run_tests "--filter BoletoTest" "Boleto API Tests"
        ;;

    payment)
        run_tests "--filter PaymentTest" "Payment API Tests"
        ;;

    integration)
        run_tests "--filter IntegrationTest" "Integration Tests"
        ;;

    coverage)
        run_with_coverage
        ;;

    all)
        echo -e "${BLUE}Running all test suites...${NC}"
        echo ""

        # Run in order of priority
        run_tests "--filter SmokeTest" "1. Smoke Tests"
        run_tests "--filter Unit" "2. Unit Tests"
        run_tests "--filter ReciboTest" "3. Recibo API Tests"
        run_tests "--filter BoletoTest" "4. Boleto API Tests"
        run_tests "--filter PaymentTest" "5. Payment API Tests"
        run_tests "--filter IntegrationTest" "6. Integration Tests"
        run_tests "--filter Security" "7. Security Tests"

        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}   All test suites completed!          ${NC}"
        echo -e "${GREEN}========================================${NC}"
        ;;

    quick)
        echo -e "${BLUE}Running quick test suite (smoke + unit)...${NC}"
        run_tests "--filter SmokeTest" "Smoke Tests"
        run_tests "--filter Unit" "Unit Tests"
        ;;

    critical)
        echo -e "${BLUE}Running critical path tests...${NC}"
        run_tests "--filter SmokeTest" "Smoke Tests"
        run_tests "--filter ReciboTest" "Recibo Tests"
        run_tests "--filter BoletoTest" "Boleto Tests"
        run_tests "--filter PaymentTest" "Payment Tests"
        ;;

    *)
        echo -e "${RED}Unknown suite: $SUITE${NC}"
        echo ""
        echo "Available suites:"
        echo "  all         - Run all tests (default)"
        echo "  smoke       - Run smoke tests only"
        echo "  unit        - Run unit tests only"
        echo "  feature     - Run feature tests only"
        echo "  security    - Run security tests only"
        echo "  recibo      - Run Recibo API tests"
        echo "  boleto      - Run Boleto API tests"
        echo "  payment     - Run Payment API tests"
        echo "  integration - Run integration tests"
        echo "  coverage    - Run with code coverage"
        echo "  quick       - Run quick suite (smoke + unit)"
        echo "  critical    - Run critical path tests"
        exit 1
        ;;
esac
