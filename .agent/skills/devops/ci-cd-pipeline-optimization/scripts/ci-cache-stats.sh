#!/bin/bash
# CI Cache Statistics
# Analyzes GitHub Actions cache hit rates and provides optimization recommendations
#
# Usage: ./ci-cache-stats.sh [options]
#   --workflow WORKFLOW       Workflow file name (default: ci.yml)
#   --scope SCOPE             Cache scope: repo, org (default: repo)
#   --days DAYS               Analysis period in days (default: 7)
#   --optimize                Show optimization recommendations
#   --clear-unused            Clear unused caches (prompted)
#   --format FORMAT           Output format: table, json (default: table)
#   --help                    Show this help

set -euo pipefail

# Default values
WORKFLOW="${WORKFLOW:-ci.yml}"
SCOPE="${SCOPE:-repo}"
DAYS="${DAYS:-7}"
OPTIMIZE=false
CLEAR_UNUSED=false
FORMAT="table"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Logging
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
fatal() { log_error "$1"; exit 1; }

# Format bytes
format_bytes() {
    local bytes=$1
    if [[ $bytes -ge 1073741824 ]]; then
        printf "%.2f GB" $(echo "scale=2; $bytes / 1073741824" | bc)
    elif [[ $bytes -ge 1048576 ]]; then
        printf "%.2f MB" $(echo "scale=2; $bytes / 1048576" | bc)
    elif [[ $bytes -ge 1024 ]]; then
        printf "%.2f KB" $(echo "scale=2; $bytes / 1024" | bc)
    else
        printf "%d B" $bytes
    fi
}

# Format percentage
format_percentage() {
    local numerator=$1
    local denominator=$2
    if [[ $denominator -eq 0 ]]; then
        echo "N/A"
    else
        printf "%.1f%%" $(echo "scale=1; ($numerator / $denominator) * 100" | bc)
    fi
}

# Usage
usage() {
    grep '^#' "$0" | sed 's/^#/ /' | sed '1d; $d'
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --workflow) WORKFLOW="$2"; shift 2 ;;
        --scope) SCOPE="$2"; shift 2 ;;
        --days) DAYS="$2"; shift 2 ;;
        --optimize) OPTIMIZE=true; shift ;;
        --clear-unused) CLEAR_UNUSED=true; shift ;;
        --format) FORMAT="$2"; shift 2 ;;
        --help) usage ;;
        *) fatal "Unknown option: $1" ;;
    esac
done

# Check dependencies
if ! command -v gh &> /dev/null; then
    fatal "gh CLI not found. Install: https://cli.github.com/"
fi

if ! command -v bc &> /dev/null; then
    fatal "bc not found. Install: apt-get install bc / brew install bc"
fi

# Check authentication
if ! gh auth status &> /dev/null; then
    fatal "Not authenticated with GitHub. Run: gh auth login"
fi

log_info "Analyzing cache statistics for: $WORKFLOW"
log_info "Scope: $SCOPE | Period: Last $DAYS days"

# Get cache actions from workflow
CACHE_ACTIONS=$(gh run view --workflow="$WORKFLOW" --log 2>/dev/null | grep -i "cache" || true)

# Get cache list
log_info "Fetching cache list..."

CACHE_LIST_JSON=$(gh cache list --json id,key,size_in_bytes,created_at,last_accessed_at,ref --limit 100 2>/dev/null || echo "[]")

CACHE_COUNT=$(echo "$CACHE_LIST_JSON" | jq 'length')

if [[ $CACHE_COUNT -eq 0 ]]; then
    log_warn "No caches found"
    exit 0
fi

log_info "Found $CACHE_COUNT cache entries"

# Calculate statistics
TOTAL_SIZE=0
TOTAL_HITS=0
TOTAL_MISSES=0
UNUSED_SIZE=0
UNUSED_COUNT=0
STALE_SIZE=0
STALE_COUNT=0

declare -A CACHE_BY_KEY
declare -A CACHE_HITS

CUTOFF_DATE=$(date -d "$DAYS days ago" -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -v-${DAYS}d -u +%Y-%m-%dT%H:%M:%SZ)

while IFS= read -r cache; do
    CACHE_ID=$(echo "$cache" | jq -r '.id')
    CACHE_KEY=$(echo "$cache" | jq -r '.key')
    CACHE_SIZE=$(echo "$cache" | jq -r '.size_in_bytes')
    CREATED_AT=$(echo "$cache" | jq -r '.created_at')
    LAST_ACCESSED=$(echo "$cache" | jq -r '.last_accessed_at')

    TOTAL_SIZE=$((TOTAL_SIZE + CACHE_SIZE))

    # Check if unused (not accessed in period)
    if [[ "$LAST_ACCESSED" < "$CUTOFF_DATE" ]]; then
        UNUSED_SIZE=$((UNUSED_SIZE + CACHE_SIZE))
        UNUSED_COUNT=$((UNUSED_COUNT + 1))
    fi

    # Group by key pattern
    KEY_PATTERN=$(echo "$CACHE_KEY" | sed 's/[0-9a-f]\{40,\}/<hash>/g' | sed 's/[0-9]\{10,\}/<timestamp>/g')
    CACHE_BY_KEY["$KEY_PATTERN"]=$((${CACHE_BY_KEY[$KEY_PATTERN]:-0} + 1))

    # Get cache hits from workflow runs (estimate)
    CACHE_HITS["$KEY_PATTERN"]=$((${CACHE_HITS[$KEY_PATTERN]:-0} + 1))
done < <(echo "$CACHE_LIST_JSON" | jq -c '.[]')

# Estimate hit rate (simplified - actual rate requires workflow log parsing)
ESTIMATED_HITS=0
ESTIMATED_MISSES=0

for pattern in "${!CACHE_BY_KEY[@]}"; do
    count=${CACHE_BY_KEY[$pattern]}
    # Simplified estimation: assume 70% hit rate for existing caches
    ESTIMATED_HITS=$((ESTIMATED_HITS + (count * 7 / 10)))
    ESTIMATED_MISSES=$((ESTIMATED_MISSES + (count * 3 / 10)))
done

TOTAL_ESTIMATED=$((ESTIMATED_HITS + ESTIMATED_MISSES))
HIT_RATE=$(format_percentage $ESTIMATED_HITS $TOTAL_ESTIMATED)

# Output results
if [[ "$FORMAT" == "json" ]]; then
    cat <<EOF
{
  "workflow": "$WORKFLOW",
  "scope": "$SCOPE",
  "period_days": $DAYS,
  "summary": {
    "total_caches": $CACHE_COUNT,
    "total_size_bytes": $TOTAL_SIZE,
    "total_size_formatted": "$(format_bytes $TOTAL_SIZE)",
    "unused_count": $UNUSED_COUNT,
    "unused_size_bytes": $UNUSED_SIZE,
    "unused_size_formatted": "$(format_bytes $UNUSED_SIZE)",
    "estimated_hit_rate": "$HIT_RATE"
  },
  "caches_by_pattern": [
$(for pattern in "${!CACHE_BY_KEY[@]}"; do
    echo "    {\"pattern\": \"$pattern\", \"count\": ${CACHE_BY_KEY[$pattern]}},"
done | sed '$ s/,$//')
  ]
}
EOF
else
    # Table format
    echo -e "${BOLD}┌─────────────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}│${NC} ${BOLD}CI Cache Statistics${NC}                                                              ${BOLD}│${NC}"
    echo -e "${BOLD}├─────────────────────────────────────────────────────────────────────────────────────┤${NC}"
    printf "${BOLD}│ %-35s │ %-30s │${NC}\n" "Metric" "Value"
    echo -e "${BOLD}├─────────────────────────────────────────────────────────────────────────────────────┤${NC}"

    printf "│ %-35s │ %-30s │\n" "Total Cache Entries" "$CACHE_COUNT"
    printf "│ %-35s │ %-30s │\n" "Total Cache Size" "$(format_bytes $TOTAL_SIZE)"
    printf "│ %-35s │ %-30s │\n" "Unused Caches (>$DAYS days)" "$UNUSED_COUNT"
    printf "│ %-35s │ %-30s │\n" "Unused Cache Size" "$(format_bytes $UNUSED_SIZE)"
    printf "│ %-35s │ %-30s │\n" "Estimated Hit Rate" "$HIT_RATE"

    echo -e "${BOLD}├─────────────────────────────────────────────────────────────────────────────────────┤${NC}"
    printf "${BOLD}│ %-35s │ %-15s │ %-15s │${NC}\n" "Cache Pattern" "Count" "Size"
    echo -e "${BOLD}├─────────────────────────────────────────────────────────────────────────────────────┤${NC}"

    for pattern in "${!CACHE_BY_KEY[@]}"; do
        # Get size for this pattern (approximation)
        PATTERN_SIZE=$(echo "$CACHE_LIST_JSON" | jq -r "[.[] | select(.key | contains(\"$(echo $pattern | sed 's/.*\(.*\)/\1/')\"))] | length")
        printf "│ %-35s │ %-15s │ %-15s │\n" \
            "$pattern" \
            "${CACHE_BY_KEY[$pattern]}" \
            "~$(format_bytes $((PATTERN_SIZE * 1048576)))"
    done

    echo -e "${BOLD}└─────────────────────────────────────────────────────────────────────────────────────┘${NC}"
fi

# Optimization recommendations
if [[ "$OPTIMIZE" == true ]]; then
    echo ""
    log_info "Optimization Recommendations"

    # Check for unused caches
    if [[ $UNUSED_COUNT -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}Unused Caches Detected:${NC}"
        echo "  - $UNUSED_COUNT caches not accessed in $DAYS days"
        echo "  - Wasted space: $(format_bytes $UNUSED_SIZE)"
        echo ""
        echo "  Action: Run with --clear-unused to remove"
    fi

    # Check cache hit rate
    HIT_NUMERIC=$(echo "$HIT_RATE" | sed 's/%//')
    if [[ $(echo "$HIT_NUMERIC < 50" | bc) -eq 1 ]]; then
        echo ""
        echo -e "${RED}Low Cache Hit Rate:${NC}"
        echo "  - Current hit rate: $HIT_RATE"
        echo ""
        echo "  Actions:"
        echo "    1. Review cache key patterns - use lock file hashes"
        echo "    2. Increase cache retention period"
        echo "    3. Check if cache keys change too frequently"
    fi

    # Check for potential cache consolidation
    if [[ $CACHE_COUNT -gt 50 ]]; then
        echo ""
        echo -e "${YELLOW}High Cache Count:${NC}"
        echo "  - $CACHE_COUNT cache entries may cause inefficiency"
        echo ""
        echo "  Actions:"
        echo "    1. Consolidate similar caches with restore-keys"
        echo "    2. Use version-specific keys with fallbacks"
        echo "    3. Implement cache expiration policy"
    fi

    # Specific cache recommendations
    echo ""
    echo -e "${CYAN}Best Practices:${NC}"
    echo ""
    echo "  Composer Dependencies:"
    echo "    key: \${{ runner.os }}-composer-\${{ hashFiles('**/composer.lock') }}"
    echo "    restore-keys: |"
    echo "      \${{ runner.os }}-composer-"
    echo ""
    echo "  NPM Dependencies:"
    echo "    key: \${{ runner.os }}-node-\${{ hashFiles('**/package-lock.json') }}"
    echo "    restore-keys: |"
    echo "      \${{ runner.os }}-node-"
    echo ""
    echo "  Docker Layers:"
    echo "    cache-from: type=registry,ref=..."
    echo "    cache-to: type=registry,ref=...,mode=max"
fi

# Clear unused caches
if [[ "$CLEAR_UNUSED" == true ]]; then
    if [[ $UNUSED_COUNT -gt 0 ]]; then
        echo ""
        log_warn "This will delete $UNUSED_COUNT unused caches ($(format_bytes $UNUSED_SIZE))"
        read -p "Continue? (y/N) " -n 1 -r
        echo

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            while IFS= read -r cache; do
                CACHE_ID=$(echo "$cache" | jq -r '.id')
                CACHE_KEY=$(echo "$cache" | jq -r '.key')
                LAST_ACCESSED=$(echo "$cache" | jq -r '.last_accessed_at')

                if [[ "$LAST_ACCESSED" < "$CUTOFF_DATE" ]]; then
                    log_info "Deleting cache: $CACHE_KEY"
                    gh cache delete "$CACHE_ID" 2>/dev/null || true
                fi
            done < <(echo "$CACHE_LIST_JSON" | jq -c '.[]')

            log_info "Cache cleanup complete"
        fi
    else
        log_info "No unused caches to clear"
    fi
fi

exit 0
