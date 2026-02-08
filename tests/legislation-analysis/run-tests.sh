#!/bin/bash

# Legislation Analysis Test Suite Runner
# Executes comprehensive tests and generates validation reports

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=========================================="
echo "Legislation Analysis Test Suite"
echo "=========================================="
echo ""

# Check if PHPUnit is available
if ! command -v php &> /dev/null; then
    echo -e "${RED}Error: PHP is not installed${NC}"
    exit 1
fi

if [ ! -f "$PROJECT_ROOT/vendor/bin/phpunit" ]; then
    echo -e "${YELLOW}Warning: PHPUnit not found in vendor/bin${NC}"
    echo "Installing dependencies..."
    cd "$PROJECT_ROOT"
    composer install --dev
fi

# Change to test directory
cd "$SCRIPT_DIR"

echo -e "${GREEN}Running PHPUnit tests...${NC}"
echo ""

# Run PHPUnit tests
if "$PROJECT_ROOT/vendor/bin/phpunit" \
    --configuration="$SCRIPT_DIR/phpunit.xml" \
    --colors=always \
    --verbose \
    LegislationAnalysisTestSuite.php; then

    echo ""
    echo -e "${GREEN}=========================================="
    echo "All tests passed successfully!"
    echo "==========================================${NC}"
    echo ""

    # Display validation report summary
    if [ -f "$SCRIPT_DIR/validation-report.json" ]; then
        echo -e "${GREEN}Validation Report Summary:${NC}"
        echo ""

        # Extract overall score using jq or basic parsing
        if command -v jq &> /dev/null; then
            jq '.summary' "$SCRIPT_DIR/validation-report.json"
        else
            # Basic parsing without jq
            echo "Overall Score: $(grep -o '"overall_score": [0-9.]*' "$SCRIPT_DIR/validation-report.json" | cut -d' ' -f2)"
            echo "Total Tests: $(grep -o '"total_tests": [0-9]*' "$SCRIPT_DIR/validation-report.json" | cut -d' ' -f2)"
            echo "Passed Tests: $(grep -o '"passed_tests": [0-9]*' "$SCRIPT_DIR/validation-report.json" | cut -d' ' -f2)"
            echo "Failed Tests: $(grep -o '"failed_tests": [0-9]*' "$SCRIPT_DIR/validation-report.json" | cut -d' ' -f2)"
        fi

        echo ""
        echo "Full validation report saved to: $SCRIPT_DIR/validation-report.json"
    fi

    echo ""
    echo -e "${GREEN}Test execution completed successfully${NC}"
    exit 0

else
    echo ""
    echo -e "${RED}=========================================="
    echo "Tests failed!"
    echo "==========================================${NC}"
    echo ""
    echo "Please review the error messages above."
    echo ""
    echo "Common issues:"
    echo "1. Missing dependencies - Run: composer install"
    echo "2. PHP version requirement - Requires PHP 8.1+"
    echo "3. Missing test files - Verify all files are present"
    echo ""
    exit 1
fi
