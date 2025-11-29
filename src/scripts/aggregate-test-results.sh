#!/usr/bin/env bash

################################################################################
# Test Result Aggregation Script
#
# Phase 4.2: Parallel Test Execution
#
# Merges test results and coverage reports from parallel test execution:
# - Combines multiple Clover XML coverage files
# - Generates unified HTML coverage report
# - Calculates overall coverage percentage
# - Produces test execution summary
#
# Usage:
#   ./scripts/aggregate-test-results.sh [options]
#
# Options:
#   --coverage-dir DIR    Directory containing coverage reports (default: coverage-reports/)
#   --output-dir DIR      Output directory for merged reports (default: merged-coverage/)
#   --format FORMAT       Output format: html, clover, xml, all (default: all)
#   --min-coverage NUM    Minimum coverage threshold percentage (default: 87)
#   --verbose            Enable verbose output
#   --help               Show this help message
#
# Examples:
#   ./scripts/aggregate-test-results.sh
#   ./scripts/aggregate-test-results.sh --coverage-dir ./coverage --min-coverage 90
#
################################################################################

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default configuration
COVERAGE_DIR="${PROJECT_ROOT}/coverage-reports"
OUTPUT_DIR="${PROJECT_ROOT}/merged-coverage"
OUTPUT_FORMAT="all"
MIN_COVERAGE=87
VERBOSE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# Helper Functions
################################################################################

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"
}

success() {
    echo -e "${GREEN}✓${NC} $*"
}

error() {
    echo -e "${RED}✗${NC} $*" >&2
}

warning() {
    echo -e "${YELLOW}⚠${NC} $*"
}

verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[VERBOSE]${NC} $*"
    fi
}

usage() {
    grep '^#' "$0" | tail -n +3 | head -n -1 | cut -c 3-
    exit 0
}

################################################################################
# Parse Arguments
################################################################################

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --coverage-dir)
                COVERAGE_DIR="$2"
                shift 2
                ;;
            --output-dir)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            --format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            --min-coverage)
                MIN_COVERAGE="$2"
                shift 2
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help)
                usage
                ;;
            *)
                error "Unknown option: $1"
                usage
                ;;
        esac
    done
}

################################################################################
# Validation
################################################################################

validate_dependencies() {
    log "Validating dependencies..."

    local missing_deps=0

    # Check for PHP
    if ! command -v php &> /dev/null; then
        error "PHP is not installed"
        ((missing_deps++))
    fi

    # Check for xmllint (for XML validation and parsing)
    if ! command -v xmllint &> /dev/null; then
        warning "xmllint not found (optional, for XML validation)"
    fi

    # Check for Composer
    if ! command -v composer &> /dev/null; then
        warning "Composer not found (optional, for phpcov installation)"
    fi

    if [ $missing_deps -gt 0 ]; then
        error "Missing required dependencies. Please install them and try again."
        exit 1
    fi

    success "All required dependencies are available"
}

validate_coverage_directory() {
    log "Validating coverage directory: $COVERAGE_DIR"

    if [ ! -d "$COVERAGE_DIR" ]; then
        error "Coverage directory does not exist: $COVERAGE_DIR"
        exit 1
    fi

    local coverage_files
    coverage_files=$(find "$COVERAGE_DIR" -name "*.xml" -type f | wc -l)

    if [ "$coverage_files" -eq 0 ]; then
        error "No coverage XML files found in: $COVERAGE_DIR"
        exit 1
    fi

    success "Found $coverage_files coverage file(s)"
}

################################################################################
# Coverage Merging
################################################################################

merge_clover_xml() {
    log "Merging Clover XML coverage reports..."

    mkdir -p "$OUTPUT_DIR"

    local coverage_files=()
    while IFS= read -r file; do
        coverage_files+=("$file")
        verbose "Found coverage file: $file"
    done < <(find "$COVERAGE_DIR" -name "*.xml" -type f)

    if [ ${#coverage_files[@]} -eq 0 ]; then
        error "No coverage files to merge"
        return 1
    fi

    if [ ${#coverage_files[@]} -eq 1 ]; then
        warning "Only one coverage file found, copying directly..."
        cp "${coverage_files[0]}" "$OUTPUT_DIR/coverage.xml"
        success "Coverage file copied"
        return 0
    fi

    # Create PHP script to merge coverage files
    local merge_script="$OUTPUT_DIR/merge-coverage.php"

    cat > "$merge_script" << 'EOF'
<?php

/**
 * Merge multiple Clover XML coverage reports
 */

function mergeCoverageReports(array $files, string $outputFile): array {
    $mergedMetrics = [
        'files' => 0,
        'loc' => 0,
        'ncloc' => 0,
        'classes' => 0,
        'methods' => 0,
        'coveredmethods' => 0,
        'statements' => 0,
        'coveredstatements' => 0,
        'elements' => 0,
        'coveredelements' => 0,
    ];

    $mergedFiles = [];

    foreach ($files as $file) {
        if (!file_exists($file)) {
            fwrite(STDERR, "Warning: File not found: $file\n");
            continue;
        }

        $xml = simplexml_load_file($file);

        if ($xml === false) {
            fwrite(STDERR, "Warning: Failed to parse XML: $file\n");
            continue;
        }

        // Extract metrics from project element
        $project = $xml->project;
        if (isset($project->metrics)) {
            $metrics = $project->metrics->attributes();

            foreach ($mergedMetrics as $key => $value) {
                if (isset($metrics[$key])) {
                    $mergedMetrics[$key] += (int)$metrics[$key];
                }
            }
        }

        // Collect all file elements
        foreach ($xml->xpath('//file') as $fileElement) {
            $fileName = (string)$fileElement['name'];
            $mergedFiles[$fileName] = $fileElement;
        }
    }

    // Create merged XML
    $merged = new SimpleXMLElement('<?xml version="1.0" encoding="UTF-8"?><coverage></coverage>');
    $merged->addAttribute('generated', time());

    $project = $merged->addChild('project');
    $project->addAttribute('timestamp', time());

    // Add metrics
    $metricsElement = $project->addChild('metrics');
    foreach ($mergedMetrics as $key => $value) {
        $metricsElement->addAttribute($key, $value);
    }

    // Add all unique files
    foreach ($mergedFiles as $fileName => $fileElement) {
        $newFile = $project->addChild('file');
        $newFile->addAttribute('name', $fileName);

        // Copy all child elements
        foreach ($fileElement->children() as $child) {
            $newChild = $newFile->addChild($child->getName());
            foreach ($child->attributes() as $attr => $value) {
                $newChild->addAttribute($attr, $value);
            }
        }
    }

    // Save merged XML
    $dom = new DOMDocument('1.0');
    $dom->preserveWhiteSpace = false;
    $dom->formatOutput = true;
    $dom->loadXML($merged->asXML());
    $dom->save($outputFile);

    return $mergedMetrics;
}

// Main execution
$files = array_slice($argv, 1, -1);
$outputFile = end($argv);

if (count($files) < 2) {
    fwrite(STDERR, "Usage: php merge-coverage.php <file1.xml> <file2.xml> ... <output.xml>\n");
    exit(1);
}

echo "Merging " . count($files) . " coverage reports...\n";

$metrics = mergeCoverageReports($files, $outputFile);

echo "Merged coverage saved to: $outputFile\n";
echo "Coverage statistics:\n";
printf("  Files: %d\n", $metrics['files']);
printf("  Lines of Code: %d\n", $metrics['loc']);
printf("  Non-comment Lines: %d\n", $metrics['ncloc']);
printf("  Classes: %d\n", $metrics['classes']);
printf("  Methods: %d (%.2f%% covered)\n",
    $metrics['methods'],
    $metrics['methods'] > 0 ? ($metrics['coveredmethods'] / $metrics['methods'] * 100) : 0
);
printf("  Statements: %d (%.2f%% covered)\n",
    $metrics['statements'],
    $metrics['statements'] > 0 ? ($metrics['coveredstatements'] / $metrics['statements'] * 100) : 0
);
printf("  Elements: %d (%.2f%% covered)\n",
    $metrics['elements'],
    $metrics['elements'] > 0 ? ($metrics['coveredelements'] / $metrics['elements'] * 100) : 0
);

exit(0);
EOF

    # Run merge script
    php "$merge_script" "${coverage_files[@]}" "$OUTPUT_DIR/coverage.xml"

    success "Coverage reports merged to: $OUTPUT_DIR/coverage.xml"
}

################################################################################
# Coverage Analysis
################################################################################

calculate_coverage_percentage() {
    local coverage_file="$OUTPUT_DIR/coverage.xml"

    if [ ! -f "$coverage_file" ]; then
        error "Coverage file not found: $coverage_file"
        return 1
    fi

    log "Calculating coverage percentage..."

    # Extract coverage metrics using xmllint or PHP
    if command -v xmllint &> /dev/null; then
        local statements
        local covered_statements

        statements=$(xmllint --xpath 'string(//metrics/@statements)' "$coverage_file" 2>/dev/null || echo "0")
        covered_statements=$(xmllint --xpath 'string(//metrics/@coveredstatements)' "$coverage_file" 2>/dev/null || echo "0")

        if [ "$statements" -gt 0 ]; then
            local coverage_pct
            coverage_pct=$(awk "BEGIN {printf \"%.2f\", ($covered_statements / $statements) * 100}")

            echo "$coverage_pct"
        else
            echo "0.00"
        fi
    else
        # Fallback to PHP parsing
        php -r "
            \$xml = simplexml_load_file('$coverage_file');
            \$metrics = \$xml->xpath('//metrics')[0];
            \$statements = (int)\$metrics['statements'];
            \$covered = (int)\$metrics['coveredstatements'];
            \$pct = \$statements > 0 ? (\$covered / \$statements) * 100 : 0;
            echo number_format(\$pct, 2);
        "
    fi
}

check_coverage_threshold() {
    local coverage_pct="$1"

    log "Checking coverage threshold (minimum: ${MIN_COVERAGE}%)..."

    if (( $(echo "$coverage_pct >= $MIN_COVERAGE" | bc -l) )); then
        success "Coverage threshold met: ${coverage_pct}% >= ${MIN_COVERAGE}%"
        return 0
    else
        error "Coverage threshold not met: ${coverage_pct}% < ${MIN_COVERAGE}%"
        return 1
    fi
}

################################################################################
# HTML Report Generation
################################################################################

generate_html_report() {
    log "Generating HTML coverage report..."

    local coverage_file="$OUTPUT_DIR/coverage.xml"
    local html_dir="$OUTPUT_DIR/html"

    mkdir -p "$html_dir"

    # Use phpcov if available, otherwise create basic HTML
    if command -v phpcov &> /dev/null; then
        phpcov merge \
            --clover "$coverage_file" \
            --html "$html_dir" \
            "$COVERAGE_DIR"

        success "HTML report generated: $html_dir/index.html"
    else
        warning "phpcov not available, creating basic HTML report..."

        cat > "$html_dir/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Code Coverage Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #333; }
        .summary { background: #f5f5f5; padding: 15px; border-radius: 5px; }
        .metric { margin: 10px 0; }
        .metric-label { font-weight: bold; }
        .coverage-bar {
            width: 100%;
            height: 20px;
            background: #e0e0e0;
            border-radius: 3px;
            overflow: hidden;
        }
        .coverage-fill {
            height: 100%;
            background: #4caf50;
            transition: width 0.3s;
        }
    </style>
</head>
<body>
    <h1>Code Coverage Report</h1>
    <div class="summary">
        <p>Coverage report generated from parallel test execution.</p>
        <p>See coverage.xml for detailed metrics.</p>
    </div>
</body>
</html>
EOF

        success "Basic HTML report created: $html_dir/index.html"
    fi
}

################################################################################
# Summary Generation
################################################################################

generate_summary() {
    local coverage_pct="$1"

    log "Generating test summary..."

    local summary_file="$OUTPUT_DIR/SUMMARY.md"

    cat > "$summary_file" << EOF
# Test Results Summary

**Generated**: $(date +'%Y-%m-%d %H:%M:%S')

## Overall Coverage

**Coverage**: ${coverage_pct}%
**Threshold**: ${MIN_COVERAGE}%
**Status**: $(if (( $(echo "$coverage_pct >= $MIN_COVERAGE" | bc -l) )); then echo "✅ PASSED"; else echo "❌ FAILED"; fi)

## Test Execution

### Parallel Test Groups

1. **Unit Tests**
   - Fast, isolated tests
   - No database dependencies

2. **Feature Tests**
   - HTTP and feature testing
   - Database transactions

3. **Integration Tests**
   - Full stack integration
   - Database + external services

## Coverage Reports

- **Clover XML**: \`coverage.xml\`
- **HTML Report**: \`html/index.html\`

## Performance Metrics

- **Target Reduction**: 60% faster than sequential
- **Parallel Processes**: Auto-detected based on CPU cores
- **Database Isolation**: Separate database per process

## Next Steps

1. Review HTML coverage report for detailed metrics
2. Address any coverage gaps in under-tested areas
3. Monitor test execution performance in CI/CD

---

*Phase 4.2: Parallel Test Execution*
EOF

    success "Summary generated: $summary_file"

    # Display summary
    cat "$summary_file"
}

################################################################################
# Main Execution
################################################################################

main() {
    echo ""
    log "==================================================================="
    log "Test Result Aggregation - Phase 4.2"
    log "==================================================================="
    echo ""

    # Parse arguments
    parse_arguments "$@"

    # Validate
    validate_dependencies
    validate_coverage_directory

    # Merge coverage reports
    merge_clover_xml

    # Calculate coverage
    local coverage_pct
    coverage_pct=$(calculate_coverage_percentage)

    success "Overall coverage: ${coverage_pct}%"

    # Generate reports based on format
    case "$OUTPUT_FORMAT" in
        html)
            generate_html_report
            ;;
        clover|xml)
            success "Clover XML already generated: $OUTPUT_DIR/coverage.xml"
            ;;
        all)
            generate_html_report
            ;;
        *)
            error "Unknown output format: $OUTPUT_FORMAT"
            exit 1
            ;;
    esac

    # Generate summary
    generate_summary "$coverage_pct"

    # Check threshold
    echo ""
    if check_coverage_threshold "$coverage_pct"; then
        echo ""
        success "✅ All checks passed!"
        echo ""
        exit 0
    else
        echo ""
        error "❌ Coverage threshold not met"
        echo ""
        exit 1
    fi
}

# Run main function with all arguments
main "$@"
