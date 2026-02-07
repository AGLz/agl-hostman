#!/bin/bash

# Test Coverage Script for AGL Hostman
# This script runs the test suite and generates a coverage report

cd /mnt/overpower/apps/dev/agl/agl-hostman/src

echo "================================================"
echo "Running Test Suite with Coverage Analysis"
echo "================================================"
echo ""

# Set environment for testing
export APP_ENV=testing
export APP_DEBUG=true
export CACHE_DRIVER=array
export SESSION_DRIVER=array
export DB_CONNECTION=sqlite
export DB_DATABASE=:memory:
export QUEUE_CONNECTION=sync

# Increase PHP memory limit
export PHP_MEMORY_LIMIT=-1

# Run migrations for test database
echo "Step 1: Running migrations..."
php -d memory_limit=-1 artisan migrate --force --seed 2>&1 | head -30
echo ""

# Run tests with coverage using Pest
echo "Step 2: Running tests with coverage..."
php -d memory_limit=-1 ./vendor/bin/pest --coverage --min=80 --colors=never 2>&1 | tee test_coverage_output.log
echo ""

# Extract coverage summary
echo "================================================"
echo "Coverage Summary"
echo "================================================"
grep -A 20 "Coverage:" test_coverage_output.log || grep -A 20 "Lines:" test_coverage_output.log || echo "No coverage report found"
echo ""

# Show final results
echo "================================================"
echo "Test Results Summary"
echo "================================================"
tail -50 test_coverage_output.log
