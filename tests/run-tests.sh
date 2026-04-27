#!/bin/bash

# Test runner script that bypasses the write-file-atomic issue
# This script runs Jest tests with proper environment setup

set -e

# Clean up any previous test artifacts
rm -rf /tmp/jest_*
rm -rf coverage

# Set environment variables
export NODE_ENV=test
export JEST_PUPPETEER_SKIP_DOWNLOAD=1

# Run Jest with the actual test files, bypassing the cache issue
# We use --no-cache to avoid the transform cache writing issue
# We use --testPathPatterns to run specific tests

if [ -n "$1" ]; then
  # Run specific test file
  echo "Running test: $1"
  ./node_modules/.pnpm/jest-cli@29.7.0_@types+node@18.19.130/node_modules/jest-cli/bin/jest.js \
    "$1" \
    --no-cache \
    --config=jest.config.js \
    --verbose
else
  # Run all tests
  echo "Running all tests..."
  ./node_modules/.pnpm/jest-cli@29.7.0_@types+node@18.19.130/node_modules/jest-cli/bin/jest.js \
    --no-cache \
    --config=jest.config.js \
    --verbose
fi
