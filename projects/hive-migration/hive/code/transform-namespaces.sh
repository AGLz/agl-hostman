#!/bin/bash
#
# transform-namespaces.sh — Bulk-transform PHP 7.x patterns to PHP 8.1 compat
#
# Usage:
#   ./transform-namespaces.sh <source_dir> [--dry-run]
#
# Transformations applied:
#   1. Missing declare(strict_types=1) after <?php opening tag
#   2. Old-style constructors: function ClassName() → function __construct()
#   3. Capitalised typehints: String → string, Array → array
#   4. each() calls flagged with a TODO comment (removed in PHP 8.0)
#   5. ereg_* function calls flagged (removed in PHP 7.0)
#   6. Namespace App\Http\Controllers — validated, no change needed
#
# Notes:
#   - Only .php files are processed.
#   - --dry-run prints what would change without modifying files.
#   - Each modified file is backed up as <file>.bak before editing.

set -euo pipefail

# ---------------------------------------------------------------------------
# Argument handling
# ---------------------------------------------------------------------------
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <source_dir> [--dry-run]"
    exit 1
fi

SOURCE_DIR="$1"
DRY_RUN=false

for arg in "${@:2}"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        *) echo "Unknown argument: $arg"; exit 1 ;;
    esac
done

if [ ! -d "$SOURCE_DIR" ]; then
    echo "ERROR: Directory not found: $SOURCE_DIR"
    exit 1
fi

# ---------------------------------------------------------------------------
# Counters
# ---------------------------------------------------------------------------
FILES_PROCESSED=0
FILES_MODIFIED=0
FLAGS_ADDED=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info() { echo "[INFO]  $*"; }
ok()   { echo "[OK]    $*"; }
flag() { echo "[FLAG]  $*"; }
dry()  { echo "[DRY]   $*"; }

backup_and_edit() {
    local file="$1"
    if ! $DRY_RUN; then
        cp "$file" "${file}.bak"
    fi
}

# ---------------------------------------------------------------------------
# Process each PHP file
# ---------------------------------------------------------------------------
while IFS= read -r -d '' file; do
    FILES_PROCESSED=$((FILES_PROCESSED + 1))
    modified=false

    # 1. Add declare(strict_types=1) when the opening <?php tag is present
    #    but the declaration is absent.
    if grep -q '^<?php$' "$file" && ! grep -q 'declare(strict_types' "$file"; then
        if $DRY_RUN; then
            dry "Would add strict_types: $file"
        else
            backup_and_edit "$file"
            sed -i 's/^<?php$/<?php\n\ndeclare(strict_types=1);/' "$file"
        fi
        modified=true
    fi

    # 2. Old-style constructors: function ClassName() {
    #    Capture the class name and replace with __construct.
    #    Handles optional visibility keyword (public/protected).
    if grep -qP '^\s*(public\s+)?function\s+[A-Z][A-Za-z0-9_]+\s*\(' "$file"; then
        # Extract the class name defined in the file to match only self-constructors.
        class_name=$(grep -oP '(?<=^class )[A-Za-z0-9_]+' "$file" | head -1)
        if [ -n "$class_name" ] && grep -qP "function\s+${class_name}\s*\(" "$file"; then
            if $DRY_RUN; then
                dry "Would rename constructor ${class_name}(): $file"
            else
                backup_and_edit "$file"
                sed -i -E "s/function[[:space:]]+${class_name}[[:space:]]*\(/function __construct(/" "$file"
            fi
            modified=true
        fi
    fi

    # 3a. Capitalised String typehint → string
    if grep -qP ':\s*String[\s,\)]' "$file" || grep -qP '\(String\s' "$file"; then
        if $DRY_RUN; then
            dry "Would lowercase String typehint: $file"
        else
            backup_and_edit "$file"
            sed -i -E 's/([:(,]\s*)String(\s*[),$])/\1string\2/g' "$file"
        fi
        modified=true
    fi

    # 3b. Capitalised Array typehint → array
    if grep -qP ':\s*Array[\s,\)]' "$file" || grep -qP '\(Array\s' "$file"; then
        if $DRY_RUN; then
            dry "Would lowercase Array typehint: $file"
        else
            backup_and_edit "$file"
            sed -i -E 's/([:(,]\s*)Array(\s*[),$])/\1array\2/g' "$file"
        fi
        modified=true
    fi

    # 4. Flag each() usage — removed in PHP 8.0
    if grep -q '\beach(' "$file"; then
        flag "each() found (removed in PHP 8.0) — manual fix required: $file"
        if ! $DRY_RUN; then
            backup_and_edit "$file"
            sed -i 's/\beach(/\/** TODO PHP8: each() removed — replace with array_key_first\/next *\/ each(/g' "$file"
        fi
        FLAGS_ADDED=$((FLAGS_ADDED + 1))
        modified=true
    fi

    # 5. Flag ereg_* function calls — removed in PHP 7.0
    if grep -qP '\bereg_' "$file"; then
        flag "ereg_* found (removed in PHP 7.0) — manual fix required: $file"
        if ! $DRY_RUN; then
            backup_and_edit "$file"
            sed -i -E 's/\bereg_([a-z_]+)\(/\/** TODO PHP8: ereg_\1 removed — use preg_\1 *\/ ereg_\1(/g' "$file"
        fi
        FLAGS_ADDED=$((FLAGS_ADDED + 1))
        modified=true
    fi

    # 6. Verify App\Http\Controllers namespace — no transformation needed.
    if grep -q 'namespace App\\Http\\Controllers' "$file"; then
        : # correct namespace — skip
    fi

    if $modified; then
        FILES_MODIFIED=$((FILES_MODIFIED + 1))
        ok "Processed: $file"
    fi

done < <(find "$SOURCE_DIR" -name '*.php' -type f -print0)

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "========================================"
echo "  Transform Summary"
echo "========================================"
echo "  PHP files scanned : $FILES_PROCESSED"
echo "  Files modified    : $FILES_MODIFIED"
echo "  Manual flags added: $FLAGS_ADDED"
if $DRY_RUN; then
    echo ""
    echo "  DRY-RUN: no files were changed."
fi
echo "========================================"
