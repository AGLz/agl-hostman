#!/bin/bash
# Documentation Validation Script
# Validates documentation completeness, accuracy, and quality

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_DIR="${SCRIPT_DIR}/../reports"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT_FILE="${REPORT_DIR}/02-documentation-${TIMESTAMP}.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

mkdir -p "$REPORT_DIR"

log() {
    echo -e "$1" | tee -a "$REPORT_FILE"
}

check() {
    local description=$1
    local command=$2

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    log "\n[CHECK $TOTAL_CHECKS] $description"

    if eval "$command" &>/dev/null; then
        log "${GREEN}✓ PASS${NC}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        log "${RED}✗ FAIL${NC}"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi
}

log "=========================================="
log "Documentation Validation"
log "=========================================="
log "Started: $(date)"
log "=========================================="

# Define target project (can be overridden)
TARGET_PROJECT="${TARGET_PROJECT:-/mnt/overpower/apps/dev/agl/crowbar}"

log "\nTarget Project: $TARGET_PROJECT"

# Section 1: File Existence
log "\n=== SECTION 1: Documentation Files Existence ==="

check "CLAUDE.md exists" \
    "[ -f $TARGET_PROJECT/CLAUDE.md ]"

check "docs directory exists" \
    "[ -d $TARGET_PROJECT/docs ]"

check "docs/INFRA.md exists" \
    "[ -f $TARGET_PROJECT/docs/INFRA.md ]"

check "docs/ARCHON.md exists" \
    "[ -f $TARGET_PROJECT/docs/ARCHON.md ]"

check "docs/WORKFLOWS.md exists" \
    "[ -f $TARGET_PROJECT/docs/WORKFLOWS.md ]"

check "docs/RULES.md exists" \
    "[ -f $TARGET_PROJECT/docs/RULES.md ]"

check "docs/QUICK-START.md exists" \
    "[ -f $TARGET_PROJECT/docs/QUICK-START.md ]"

check "docs/DOKPLOY.md exists" \
    "[ -f $TARGET_PROJECT/docs/DOKPLOY.md ]"

# Section 2: Path Replacement Verification
log "\n=== SECTION 2: Path Replacement Verification ==="

if [ -f "$TARGET_PROJECT/CLAUDE.md" ]; then
    # Check for hardcoded agl-hostman paths
    if grep -q "agl-hostman" "$TARGET_PROJECT/CLAUDE.md"; then
        log "${RED}✗ FAIL${NC} - Found hardcoded 'agl-hostman' paths in CLAUDE.md"
        log "$(grep -n 'agl-hostman' $TARGET_PROJECT/CLAUDE.md | head -5)"
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    else
        log "${GREEN}✓ PASS${NC} - No hardcoded 'agl-hostman' paths found"
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    fi

    # Check working directory is updated
    if grep -q "Working Directory.*crowbar" "$TARGET_PROJECT/CLAUDE.md"; then
        log "${GREEN}✓ PASS${NC} - Working directory correctly references crowbar"
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        log "${RED}✗ FAIL${NC} - Working directory not updated"
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
fi

# Section 3: Link Validation
log "\n=== SECTION 3: Internal Link Validation ==="

if [ -f "$TARGET_PROJECT/CLAUDE.md" ]; then
    # Extract all @docs/ references
    DOCS_REFS=$(grep -o '@docs/[^)]*\.md' "$TARGET_PROJECT/CLAUDE.md" | sed 's/@//' | sort -u)

    if [ -n "$DOCS_REFS" ]; then
        log "Found $(echo "$DOCS_REFS" | wc -l) unique @docs/ references"

        while IFS= read -r doc_ref; do
            if [ -f "$TARGET_PROJECT/$doc_ref" ]; then
                log "${GREEN}✓${NC} $doc_ref exists"
                TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
                PASSED_CHECKS=$((PASSED_CHECKS + 1))
            else
                log "${RED}✗${NC} $doc_ref MISSING"
                TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
                FAILED_CHECKS=$((FAILED_CHECKS + 1))
            fi
        done <<< "$DOCS_REFS"
    else
        log "${YELLOW}⚠${NC} No @docs/ references found"
    fi
fi

# Section 4: Markdown Syntax Validation
log "\n=== SECTION 4: Markdown Syntax Validation ==="

if command -v markdownlint &>/dev/null; then
    for md_file in "$TARGET_PROJECT/CLAUDE.md" "$TARGET_PROJECT"/docs/*.md; do
        if [ -f "$md_file" ]; then
            filename=$(basename "$md_file")
            if markdownlint "$md_file" 2>/dev/null; then
                log "${GREEN}✓${NC} $filename - Valid markdown syntax"
                TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
                PASSED_CHECKS=$((PASSED_CHECKS + 1))
            else
                log "${RED}✗${NC} $filename - Markdown syntax errors"
                TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
                FAILED_CHECKS=$((FAILED_CHECKS + 1))
            fi
        fi
    done
else
    log "${YELLOW}⚠ markdownlint not installed - skipping syntax validation${NC}"
fi

# Section 5: External Link Validation (optional)
log "\n=== SECTION 5: External Link Validation (URLs) ==="

if command -v markdown-link-check &>/dev/null; then
    for md_file in "$TARGET_PROJECT/CLAUDE.md" "$TARGET_PROJECT"/docs/*.md; do
        if [ -f "$md_file" ]; then
            filename=$(basename "$md_file")
            log "Checking external links in $filename..."

            if markdown-link-check "$md_file" 2>/dev/null | grep -q "ERROR"; then
                log "${RED}✗${NC} $filename - Broken external links found"
                TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
                FAILED_CHECKS=$((FAILED_CHECKS + 1))
            else
                log "${GREEN}✓${NC} $filename - All external links valid"
                TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
                PASSED_CHECKS=$((PASSED_CHECKS + 1))
            fi
        fi
    done
else
    log "${YELLOW}⚠ markdown-link-check not installed - skipping external link validation${NC}"
fi

# Section 6: Documentation Coverage
log "\n=== SECTION 6: Documentation Coverage Assessment ==="

# Count total lines in documentation
TOTAL_LINES=0
for md_file in "$TARGET_PROJECT/CLAUDE.md" "$TARGET_PROJECT"/docs/*.md; do
    if [ -f "$md_file" ]; then
        lines=$(wc -l < "$md_file")
        TOTAL_LINES=$((TOTAL_LINES + lines))
        log "$(basename $md_file): $lines lines"
    fi
done

log "Total documentation: $TOTAL_LINES lines"

# Check for key sections
if grep -q "## Infrastructure" "$TARGET_PROJECT/docs/INFRA.md" 2>/dev/null; then
    log "${GREEN}✓${NC} Infrastructure section present"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    log "${RED}✗${NC} Infrastructure section missing"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

if grep -q "## Archon" "$TARGET_PROJECT/docs/ARCHON.md" 2>/dev/null; then
    log "${GREEN}✓${NC} Archon section present"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    log "${RED}✗${NC} Archon section missing"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

if grep -q "## Workflows" "$TARGET_PROJECT/docs/WORKFLOWS.md" 2>/dev/null; then
    log "${GREEN}✓${NC} Workflows section present"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    log "${RED}✗${NC} Workflows section missing"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# Section 7: Version Information
log "\n=== SECTION 7: Version Information ==="

if grep -q "Last Updated" "$TARGET_PROJECT/CLAUDE.md" 2>/dev/null; then
    LAST_UPDATED=$(grep "Last Updated" "$TARGET_PROJECT/CLAUDE.md" | head -1)
    log "${GREEN}✓${NC} Last Updated date found: $LAST_UPDATED"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    log "${RED}✗${NC} Last Updated date missing in CLAUDE.md"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

if grep -q "Version" "$TARGET_PROJECT/CLAUDE.md" 2>/dev/null; then
    VERSION=$(grep "Version" "$TARGET_PROJECT/CLAUDE.md" | head -1)
    log "${GREEN}✓${NC} Version information found: $VERSION"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    log "${RED}✗${NC} Version information missing in CLAUDE.md"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# Summary
log "\n=========================================="
log "Documentation Validation Summary"
log "=========================================="
log "Total Checks: $TOTAL_CHECKS"
log "${GREEN}Passed: $PASSED_CHECKS${NC}"
log "${RED}Failed: $FAILED_CHECKS${NC}"

if [ $TOTAL_CHECKS -gt 0 ]; then
    PASS_RATE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
    log "Pass Rate: ${PASS_RATE}%"

    if [ $PASS_RATE -ge 90 ]; then
        log "${GREEN}✓ Documentation quality: EXCELLENT${NC}"
    elif [ $PASS_RATE -ge 70 ]; then
        log "${YELLOW}⚠ Documentation quality: GOOD${NC}"
    else
        log "${RED}✗ Documentation quality: NEEDS IMPROVEMENT${NC}"
    fi
fi

log "=========================================="
log "Report saved to: $REPORT_FILE"
log "Completed: $(date)"
log "=========================================="

# Exit with appropriate code
if [ $FAILED_CHECKS -gt 0 ]; then
    log "\n${RED}⚠ DOCUMENTATION VALIDATION FAILED${NC}"
    exit 1
else
    log "\n${GREEN}✓ DOCUMENTATION VALIDATION PASSED${NC}"
    exit 0
fi
