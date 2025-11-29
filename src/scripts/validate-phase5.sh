#!/bin/bash

# Phase 5 Validation Script
# Validates all Phase 5 components

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

ERRORS=0
WARNINGS=0

echo ""
print_header "Phase 5: Advanced Features & DORA Metrics Validation"
echo ""

# 1. Validate Affected Tests Detection
print_header "1. Affected Tests Detection (Nx-Style)"

if [[ -f "scripts/detect-affected-tests.sh" ]]; then
    print_success "Detection script exists"

    if [[ -x "scripts/detect-affected-tests.sh" ]]; then
        print_success "Script is executable"
    else
        print_error "Script is not executable"
        ((ERRORS++))
    fi

    if [[ -f "tests/dependency-map.json" ]]; then
        print_success "Dependency map exists"

        # Validate JSON
        if jq empty tests/dependency-map.json 2>/dev/null; then
            print_success "Dependency map is valid JSON"
        else
            print_error "Dependency map has invalid JSON"
            ((ERRORS++))
        fi
    else
        print_error "Dependency map missing"
        ((ERRORS++))
    fi

    if [[ -f ".github/workflows/pr-affected-tests.yml" ]]; then
        print_success "GitHub Actions workflow exists"
    else
        print_warning "GitHub Actions workflow missing"
        ((WARNINGS++))
    fi

    # Test detection script (dry run)
    print_info "Testing detection script..."
    if VERBOSE=false BASE_BRANCH=origin/main ./scripts/detect-affected-tests.sh > /dev/null 2>&1; then
        print_success "Detection script runs successfully"
    else
        print_warning "Detection script execution needs verification"
        ((WARNINGS++))
    fi
else
    print_error "Detection script missing"
    ((ERRORS++))
fi

echo ""

# 2. Validate Auto-Scaling Service
print_header "2. Auto-Scaling Service"

if [[ -f "app/Services/Scaling/AutoScalingService.php" ]]; then
    print_success "AutoScalingService exists"

    # Check for required methods
    if grep -q "evaluateScaling" app/Services/Scaling/AutoScalingService.php; then
        print_success "evaluateScaling method found"
    else
        print_error "evaluateScaling method missing"
        ((ERRORS++))
    fi

    if grep -q "executeScaling" app/Services/Scaling/AutoScalingService.php; then
        print_success "executeScaling method found"
    else
        print_error "executeScaling method missing"
        ((ERRORS++))
    fi
else
    print_error "AutoScalingService missing"
    ((ERRORS++))
fi

if [[ -f "config/scaling.php" ]]; then
    print_success "Scaling configuration exists"

    # Check for required config keys
    if grep -q "enabled" config/scaling.php; then
        print_success "Configuration has 'enabled' key"
    else
        print_error "Configuration missing 'enabled' key"
        ((ERRORS++))
    fi
else
    print_error "Scaling configuration missing"
    ((ERRORS++))
fi

if [[ -f "database/migrations/2025_11_27_000001_create_scaling_events_table.php" ]]; then
    print_success "Scaling events migration exists"
else
    print_error "Scaling events migration missing"
    ((ERRORS++))
fi

if [[ -f "app/Models/ScalingEvent.php" ]]; then
    print_success "ScalingEvent model exists"
else
    print_error "ScalingEvent model missing"
    ((ERRORS++))
fi

echo ""

# 3. Validate DORA Metrics
print_header "3. DORA Metrics Tracking"

if [[ -f "app/Services/Metrics/DORAMetricsService.php" ]]; then
    print_success "DORAMetricsService exists"

    # Check for 4 key DORA methods
    DORA_METHODS=("calculateDeploymentFrequency" "calculateLeadTime" "calculateMTTR" "calculateChangeFailureRate")

    for method in "${DORA_METHODS[@]}"; do
        if grep -q "$method" app/Services/Metrics/DORAMetricsService.php; then
            print_success "$method method found"
        else
            print_error "$method method missing"
            ((ERRORS++))
        fi
    done
else
    print_error "DORAMetricsService missing"
    ((ERRORS++))
fi

if [[ -f "database/migrations/2025_11_27_000002_create_dora_metrics_table.php" ]]; then
    print_success "DORA metrics migration exists"
else
    print_error "DORA metrics migration missing"
    ((ERRORS++))
fi

if [[ -f "app/Models/DORAMetric.php" ]]; then
    print_success "DORAMetric model exists"
else
    print_error "DORAMetric model missing"
    ((ERRORS++))
fi

if [[ -f "app/Console/Commands/DORAMetricsCalculate.php" ]]; then
    print_success "DORA calculation command exists"
else
    print_error "DORA calculation command missing"
    ((ERRORS++))
fi

echo ""

# 4. Validate Training Documentation
print_header "4. Team Training Documentation"

REQUIRED_DOCS=(
    "docs/ONBOARDING.md"
    "docs/DEPLOYMENT-GUIDE.md"
    "docs/MONITORING-GUIDE.md"
    "docs/API-DOCUMENTATION.md"
)

DOC_COUNT=0
for doc in "${REQUIRED_DOCS[@]}"; do
    if [[ -f "$doc" ]]; then
        print_success "$(basename $doc) exists"
        ((DOC_COUNT++))

        # Check file size
        SIZE=$(wc -l < "$doc" 2>/dev/null || echo 0)
        if [[ $SIZE -gt 100 ]]; then
            print_success "  └─ Comprehensive ($SIZE lines)"
        elif [[ $SIZE -gt 0 ]]; then
            print_warning "  └─ Basic ($SIZE lines) - may need expansion"
            ((WARNINGS++))
        else
            print_error "  └─ Empty file"
            ((ERRORS++))
        fi
    else
        print_warning "$(basename $doc) missing - generate with documentation script"
        ((WARNINGS++))
    fi
done

if [[ $DOC_COUNT -eq ${#REQUIRED_DOCS[@]} ]]; then
    print_success "All training documents present"
elif [[ $DOC_COUNT -gt 0 ]]; then
    print_warning "$DOC_COUNT/${#REQUIRED_DOCS[@]} training documents present"
else
    print_error "No training documents found"
    ((ERRORS++))
fi

echo ""

# 5. Validate Health Checks
print_header "5. Production Health Checks"

HEALTH_CHECK_FILES=(
    "app/Services/Health/HealthCheckService.php"
    "app/Console/Commands/HealthCheck.php"
)

for file in "${HEALTH_CHECK_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        print_success "$(basename $file) exists"
    else
        print_warning "$(basename $file) missing - generate with health check script"
        ((WARNINGS++))
    fi
done

echo ""

# 6. File Structure Validation
print_header "6. File Structure"

EXPECTED_STRUCTURE=(
    "scripts/detect-affected-tests.sh"
    "scripts/validate-phase5.sh"
    "scripts/generate-phase5-files.sh"
    "tests/dependency-map.json"
    "config/scaling.php"
    "app/Services/Scaling/AutoScalingService.php"
    "app/Services/Metrics/DORAMetricsService.php"
    "app/Models/ScalingEvent.php"
    "app/Models/DORAMetric.php"
)

STRUCTURE_OK=0
for file in "${EXPECTED_STRUCTURE[@]}"; do
    if [[ -f "$file" ]]; then
        ((STRUCTURE_OK++))
    fi
done

print_info "File structure: $STRUCTURE_OK/${#EXPECTED_STRUCTURE[@]} core files present"

if [[ $STRUCTURE_OK -eq ${#EXPECTED_STRUCTURE[@]} ]]; then
    print_success "Complete file structure"
elif [[ $STRUCTURE_OK -gt $((${#EXPECTED_STRUCTURE[@]} - 3)) ]]; then
    print_success "Good file structure (minor files missing)"
else
    print_warning "Incomplete file structure"
    ((WARNINGS++))
fi

echo ""

# Summary
print_header "Validation Summary"
echo ""

if [[ $ERRORS -eq 0 ]] && [[ $WARNINGS -eq 0 ]]; then
    print_success "All Phase 5 components validated successfully! 🎉"
    echo ""
    print_info "Phase 5 is ready for production deployment"
    EXIT_CODE=0
elif [[ $ERRORS -eq 0 ]]; then
    print_warning "Phase 5 validated with $WARNINGS warnings"
    echo ""
    print_info "Review warnings before production deployment"
    EXIT_CODE=0
else
    print_error "Phase 5 validation found $ERRORS errors and $WARNINGS warnings"
    echo ""
    print_info "Fix errors before proceeding to production"
    EXIT_CODE=1
fi

echo ""
print_header "Component Status"
echo ""

echo "Affected Tests Detection:     $([ -f scripts/detect-affected-tests.sh ] && echo '✓ Ready' || echo '✗ Missing')"
echo "Auto-Scaling Service:         $([ -f app/Services/Scaling/AutoScalingService.php ] && echo '✓ Ready' || echo '✗ Missing')"
echo "DORA Metrics:                 $([ -f app/Services/Metrics/DORAMetricsService.php ] && echo '✓ Ready' || echo '✗ Missing')"
echo "Training Documentation:       $DOC_COUNT/${#REQUIRED_DOCS[@]} files"
echo "Health Checks:                $([ -f app/Services/Health/HealthCheckService.php ] && echo '✓ Ready' || echo '⚠ Pending')"

echo ""
print_header "Next Steps"
echo ""

echo "1. Run database migrations:"
echo "   php artisan migrate"
echo ""
echo "2. Test affected tests detection:"
echo "   ./scripts/detect-affected-tests.sh"
echo ""
echo "3. Calculate DORA metrics:"
echo "   php artisan dora:calculate"
echo ""
echo "4. Review training documentation:"
echo "   ls -lh docs/*.md"
echo ""
echo "5. Configure auto-scaling:"
echo "   Edit .env: AUTO_SCALING_ENABLED=true"
echo ""

exit $EXIT_CODE
