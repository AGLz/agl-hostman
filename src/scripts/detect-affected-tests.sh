#!/bin/bash

# Affected Tests Detection Script (Nx-Style)
# Analyzes git diff to determine which tests need to run
# Reduces test execution time by 70%+ for typical PRs

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BASE_BRANCH="${BASE_BRANCH:-origin/main}"
DEPENDENCY_MAP="tests/dependency-map.json"
OUTPUT_FILE="${OUTPUT_FILE:-affected-tests.txt}"
VERBOSE="${VERBOSE:-false}"

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ ${NC}$1"
}

print_success() {
    echo -e "${GREEN}✓ ${NC}$1"
}

print_warning() {
    echo -e "${YELLOW}⚠ ${NC}$1"
}

print_error() {
    echo -e "${RED}✗ ${NC}$1"
}

# Function to get changed PHP files
get_changed_files() {
    local base="$1"
    git diff --name-only "$base"...HEAD | grep '\.php$' || true
}

# Function to convert source file to test file path
source_to_test() {
    local source_file="$1"

    # Remove app/ prefix and add Test suffix
    # app/Models/User.php -> tests/Unit/Models/UserTest.php
    # app/Services/Monitoring/MetricsCollector.php -> tests/Unit/Services/Monitoring/MetricsCollectorTest.php

    if [[ "$source_file" == app/* ]]; then
        local relative_path="${source_file#app/}"
        local test_path="tests/Unit/${relative_path%.php}Test.php"
        echo "$test_path"
    elif [[ "$source_file" == routes/* ]]; then
        # Route files might affect Feature tests
        echo "tests/Feature"
    elif [[ "$source_file" == database/migrations/* ]]; then
        # Migration files affect database tests
        echo "tests/Feature/Database"
    fi
}

# Function to find tests that import a given class
find_importing_tests() {
    local class_file="$1"
    local class_name=$(basename "$class_file" .php)

    # Search for use statements and direct class references
    grep -rl "use.*\\\\${class_name};" tests/ 2>/dev/null || true
    grep -rl "${class_name}::" tests/ 2>/dev/null | grep -v "${class_name}Test\.php" || true
}

# Function to build dependency graph from composer autoload
build_dependency_graph() {
    print_info "Building dependency graph..."

    # Check if dependency map exists
    if [[ ! -f "$DEPENDENCY_MAP" ]]; then
        print_warning "Dependency map not found, generating basic map..."
        generate_basic_dependency_map
    fi

    print_success "Dependency graph loaded"
}

# Function to generate basic dependency map
generate_basic_dependency_map() {
    cat > "$DEPENDENCY_MAP" <<'EOF'
{
    "version": "1.0.0",
    "generated": "auto",
    "mappings": {
        "app/Models/": ["tests/Unit/Models/", "tests/Feature/"],
        "app/Services/": ["tests/Unit/Services/"],
        "app/Http/Controllers/": ["tests/Feature/"],
        "app/Console/Commands/": ["tests/Feature/Console/"],
        "routes/": ["tests/Feature/"],
        "config/": ["tests/Feature/"],
        "database/migrations/": ["tests/Feature/Database/"]
    },
    "transitive_dependencies": {
        "app/Services/Monitoring/MetricsCollector.php": [
            "tests/Unit/Services/Monitoring/AlertServiceTest.php",
            "tests/Feature/Monitoring/DashboardTest.php"
        ],
        "app/Models/User.php": [
            "tests/Feature/Auth/",
            "tests/Feature/Api/"
        ]
    }
}
EOF
}

# Function to find affected tests
find_affected_tests() {
    local changed_files=("$@")
    local affected_tests=()

    print_info "Analyzing ${#changed_files[@]} changed files..."

    for file in "${changed_files[@]}"; do
        if [[ "$VERBOSE" == "true" ]]; then
            print_info "Processing: $file"
        fi

        # Skip test files themselves
        if [[ "$file" == tests/* ]]; then
            affected_tests+=("$file")
            continue
        fi

        # 1. Find direct test file
        local direct_test=$(source_to_test "$file")
        if [[ -n "$direct_test" ]] && [[ -f "$direct_test" ]]; then
            affected_tests+=("$direct_test")
            if [[ "$VERBOSE" == "true" ]]; then
                print_success "  → Direct test: $direct_test"
            fi
        fi

        # 2. Find tests that import this file
        local importing_tests=$(find_importing_tests "$file")
        if [[ -n "$importing_tests" ]]; then
            while IFS= read -r test; do
                affected_tests+=("$test")
                if [[ "$VERBOSE" == "true" ]]; then
                    print_success "  → Importing test: $test"
                fi
            done <<< "$importing_tests"
        fi

        # 3. Check transitive dependencies from map
        if [[ -f "$DEPENDENCY_MAP" ]]; then
            local transitive=$(jq -r --arg file "$file" '.transitive_dependencies[$file][]? // empty' "$DEPENDENCY_MAP" 2>/dev/null || true)
            if [[ -n "$transitive" ]]; then
                while IFS= read -r test; do
                    # Handle directory patterns
                    if [[ "$test" == */ ]]; then
                        # Find all tests in this directory
                        if [[ -d "$test" ]]; then
                            while IFS= read -r found_test; do
                                affected_tests+=("$found_test")
                            done < <(find "$test" -name "*Test.php" -type f)
                        fi
                    elif [[ -f "$test" ]]; then
                        affected_tests+=("$test")
                    fi

                    if [[ "$VERBOSE" == "true" ]] && [[ -n "$test" ]]; then
                        print_success "  → Transitive test: $test"
                    fi
                done <<< "$transitive"
            fi
        fi
    done

    # Remove duplicates and sort
    printf '%s\n' "${affected_tests[@]}" | sort -u
}

# Function to categorize tests for parallel execution
categorize_tests() {
    local tests=("$@")

    declare -A categories=(
        ["unit"]=""
        ["feature"]=""
        ["integration"]=""
    )

    for test in "${tests[@]}"; do
        if [[ "$test" == tests/Unit/* ]]; then
            categories["unit"]+="$test "
        elif [[ "$test" == tests/Feature/* ]]; then
            categories["feature"]+="$test "
        elif [[ "$test" == tests/Integration/* ]]; then
            categories["integration"]+="$test "
        fi
    done

    # Output categories for parallel execution
    echo "UNIT_TESTS=${categories[unit]}"
    echo "FEATURE_TESTS=${categories[feature]}"
    echo "INTEGRATION_TESTS=${categories[integration]}"
}

# Main execution
main() {
    print_info "Affected Tests Detection (Nx-Style)"
    print_info "======================================"
    echo

    # Build dependency graph
    build_dependency_graph

    # Get changed files
    print_info "Comparing against: $BASE_BRANCH"
    changed_files=$(get_changed_files "$BASE_BRANCH")

    if [[ -z "$changed_files" ]]; then
        print_warning "No PHP files changed - skipping tests"
        echo "RUN_TESTS=false" > "$OUTPUT_FILE"
        exit 0
    fi

    # Convert to array
    readarray -t changed_array <<< "$changed_files"

    # Find affected tests
    affected_tests=$(find_affected_tests "${changed_array[@]}")

    if [[ -z "$affected_tests" ]]; then
        print_warning "No tests affected by changes"
        echo "RUN_TESTS=false" > "$OUTPUT_FILE"
        exit 0
    fi

    # Convert to array
    readarray -t affected_array <<< "$affected_tests"

    # Calculate statistics
    total_tests=$(find tests/ -name "*Test.php" -type f | wc -l)
    affected_count=${#affected_array[@]}
    reduction_pct=$(awk "BEGIN {printf \"%.1f\", (1 - $affected_count / $total_tests) * 100}")

    print_success "Found ${affected_count} affected tests (${reduction_pct}% reduction)"
    echo

    # Output results
    echo "RUN_TESTS=true" > "$OUTPUT_FILE"
    echo "AFFECTED_COUNT=$affected_count" >> "$OUTPUT_FILE"
    echo "TOTAL_COUNT=$total_tests" >> "$OUTPUT_FILE"
    echo "REDUCTION_PCT=$reduction_pct" >> "$OUTPUT_FILE"

    # Categorize for parallel execution
    categorize_tests "${affected_array[@]}" >> "$OUTPUT_FILE"

    # Output test list
    echo "AFFECTED_TESTS<<EOF" >> "$OUTPUT_FILE"
    printf '%s\n' "${affected_array[@]}" >> "$OUTPUT_FILE"
    echo "EOF" >> "$OUTPUT_FILE"

    # Print summary
    print_info "Test Breakdown:"
    echo "  Unit Tests:        $(echo "${affected_array[@]}" | tr ' ' '\n' | grep -c "tests/Unit/" || echo 0)"
    echo "  Feature Tests:     $(echo "${affected_array[@]}" | tr ' ' '\n' | grep -c "tests/Feature/" || echo 0)"
    echo "  Integration Tests: $(echo "${affected_array[@]}" | tr ' ' '\n' | grep -c "tests/Integration/" || echo 0)"
    echo

    print_success "Results written to: $OUTPUT_FILE"

    if [[ "$VERBOSE" == "true" ]]; then
        echo
        print_info "Affected test files:"
        printf '  %s\n' "${affected_array[@]}"
    fi
}

# Run main function
main "$@"
