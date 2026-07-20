#!/bin/bash

# AGL Hostman Test Suite Runner
# This script runs the comprehensive test suite with coverage reporting

set -e

echo "🚀 AGL Hostman Test Suite Runner"
echo "=================================="

# Check if we're in the right directory
if [ ! -f "composer.json" ] || [ ! -d "src" ]; then
    echo "❌ Error: This script must be run from the project root directory."
    exit 1
fi

# Function to display spinner
spinner() {
    local pid=$!
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b"
}

echo "📦 Installing dependencies..."
composer install --no-interaction --quiet &
spinner

echo -e "\n🔧 Running test suite..."

# Run unit tests
echo "🧪 Running Unit Tests..."
php artisan test --testsuite=Unit --verbose --parallel --processes=8 | tee test-output/unit.log

# Run integration tests
echo "🔗 Running Integration Tests..."
php artisan test --testsuite=Integration --verbose --parallel --processes=4 | tee test-output/integration.log

# Run performance tests
echo "⚡ Running Performance Tests..."
php artisan test --testsuite=Performance --verbose --parallel --processes=2 | tee test-output/performance.log

# Generate coverage report
echo "📊 Generating Coverage Report..."
php artisan test --coverage --min=95 | tee test-output/coverage.log

# Run architecture tests
echo "🏗️ Running Architecture Tests..."
php artisan test --testsuite=Architecture --verbose --parallel --processes=4 | tee test-output/architecture.log

# Generate test summary
echo "📋 Generating Test Summary..."
cat << EOF > test-summary.md
# AGL Hostman Test Suite Summary

## Test Results Summary

- **Unit Tests**: Passed $(grep -c "OK" test-output/unit.log 2>/dev/null || echo "0")
- **Integration Tests**: Passed $(grep -c "OK" test-output/integration.log 2>/dev/null || echo "0")
- **Performance Tests**: Passed $(grep -c "OK" test-output/performance.log 2>/dev/null || echo "0")
- **Architecture Tests**: Passed $(grep -c "OK" test-output/architecture.log 2>/dev/null || echo "0")

## Coverage Results

$(grep -E "^\s*Lines\:" test-output/coverage.log | tail -1 || echo "No coverage data available")

## Performance Metrics

- Unit Tests Execution Time: $(grep "Time:" test-output/unit.log | tail -1 || echo "Not measured")
- Integration Tests Execution Time: $(grep "Time:" test-output/integration.log | tail -1 || echo "Not measured")
- Performance Tests Execution Time: $(grep "Time:" test-output/performance.log | tail -1 || echo "Not measured")

## Test Files Generated

- Coverage HTML: coverage/html/index.html
- Coverage XML: coverage.xml
- Coverage Text: coverage.txt
- Individual Logs: test-output/*.log

## Next Steps

1. Review coverage report at coverage/html/index.html
2. Check individual test logs for failures
3. Address any coverage gaps below 95%
4. Validate performance metrics meet requirements

EOF

echo "✅ Test suite completed!"
echo "📊 Coverage Report: coverage/html/index.html"
echo "📋 Test Summary: test-summary.md"
echo "📁 Test Logs: test-output/"

# Check if all tests passed
if grep -q "ERRORS" test-output/*.log 2>/dev/null || grep -q "FAILURES" test-output/*.log 2>/dev/null; then
    echo "❌ Some tests failed. Check the log files for details."
    exit 1
fi

echo "🎉 All tests passed successfully!"
echo "📈 Coverage report generated and ready for review."

exit 0