#!/bin/bash
# CI Pipeline Speed Test
# Analyzes GitHub Actions workflow performance and identifies bottlenecks
#
# Usage: ./ci-speed-test.sh [options]
#   --workflow WORKFLOW       Workflow file name (default: ci.yml)
#   --days DAYS               Analysis period in days (default: 7)
#   --limit RUNS              Number of runs to analyze (default: 50)
#   --compare                 Compare with previous period
#   --analyze                 Detailed bottleneck analysis
#   --format FORMAT           Output format: table, json, csv (default: table)
#   --help                    Show this help

set -euo pipefail

# Default values
WORKFLOW="${WORKFLOW:-ci.yml}"
DAYS="${DAYS:-7}"
LIMIT="${LIMIT:-50}"
COMPARE=false
ANALYZE=false
FORMAT="table"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Logging
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_debug() { echo -e "${CYAN}[DEBUG]${NC} $1"; }
fatal() { log_error "$1"; exit 1; }

# Print table header
print_header() {
    if [[ "$FORMAT" == "table" ]]; then
        echo -e "${BOLD}┌─────────────────────────────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${BOLD}│${NC} ${BOLD}CI Pipeline Speed Analysis${NC}                                                      ${BOLD}│${NC}"
        echo -e "${BOLD}├─────────────────────────────────────────────────────────────────────────────────────┤${NC}"
    fi
}

# Print separator
print_separator() {
    if [[ "$FORMAT" == "table" ]]; then
        echo -e "${BOLD}├─────────────────────────────────────────────────────────────────────────────────────┤${NC}"
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
        --days) DAYS="$2"; shift 2 ;;
        --limit) LIMIT="$2"; shift 2 ;;
        --compare) COMPARE=true; shift ;;
        --analyze) ANALYZE=true; shift ;;
        --format) FORMAT="$2"; shift 2 ;;
        --help) usage ;;
        *) fatal "Unknown option: $1" ;;
    esac
done

# Check dependencies
if ! command -v gh &> /dev/null; then
    fatal "gh CLI not found. Install: https://cli.github.com/"
fi

# Check authentication
if ! gh auth status &> /dev/null; then
    fatal "Not authenticated with GitHub. Run: gh auth login"
fi

# Get workflow ID
WORKFLOW_ID=$(gh workflow list --json name,id | jq -r ".[] | select(.name == \"${WORKFLOW%.yml}\") | .id")

if [[ -z "$WORKFLOW_ID" ]]; then
    fatal "Workflow '$WORKFLOW' not found. Available workflows:\n$(gh workflow list --json name | jq -r '.[].name')"
fi

log_info "Analyzing workflow: $WORKFLOW (ID: $WORKFLOW_ID)"
log_info "Analysis period: Last $DAYS days"

# Get current period runs
log_info "Fetching workflow runs..."
SINCE_DATE=$(date -d "$DAYS days ago" -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -v-${DAYS}d -u +%Y-%m-%dT%H:%M:%SZ)

RUNS_JSON=$(gh run list \
    --workflow="$WORKFLOW" \
    --limit "$LIMIT" \
    --json databaseId,conclusion,displayTitle,event,createdAt,updatedAt,workflowDatabaseId \
    --created ">=$SINCE_DATE" 2>/dev/null || echo "[]")

RUN_COUNT=$(echo "$RUNS_JSON" | jq 'length')

if [[ "$RUN_COUNT" -eq 0 ]]; then
    log_warn "No workflow runs found in the specified period"
    exit 0
fi

log_info "Found $RUN_COUNT workflow runs"

# Calculate statistics
TOTAL_DURATION=0
SUCCESS_COUNT=0
FAILURE_COUNT=0
CANCELLED_COUNT=0
JOB_TIMES=()

while IFS= read -r run; do
    RUN_ID=$(echo "$run" | jq -r '.databaseId')
    CONCLUSION=$(echo "$run" | jq -r '.conclusion // "running"')
    CREATED=$(echo "$run" | jq -r '.createdAt')
    UPDATED=$(echo "$run" | jq -r '.updatedAt')

    # Calculate duration in seconds
    if command -v date &> /dev/null; then
        # Linux date
        START_SEC=$(date -d "$CREATED" -u +%s 2>/dev/null)
        END_SEC=$(date -d "$UPDATED" -u +%s 2>/dev/null)
    else
        # macOS date
        START_SEC=$(date -ujf "%Y-%m-%dT%H:%M:%SZ" "$CREATED" +%s 2>/dev/null)
        END_SEC=$(date -ujf "%Y-%m-%dT%H:%M:%SZ" "$UPDATED" +%s 2>/dev/null)
    fi

    DURATION=$((END_SEC - START_SEC))
    TOTAL_DURATION=$((TOTAL_DURATION + DURATION))

    # Count results
    case "$CONCLUSION" in
        success) SUCCESS_COUNT=$((SUCCESS_COUNT + 1)) ;;
        failure) FAILURE_COUNT=$((FAILURE_COUNT + 1)) ;;
        cancelled) CANCELLED_COUNT=$((CANCELLED_COUNT + 1)) ;;
    esac

    # Store individual run data
    JOB_TIMES+=("$RUN_ID|$CONCLUSION|$DURATION|$CREATED")
done < <(echo "$RUNS_JSON" | jq -c '.[]')

# Calculate averages
if [[ $RUN_COUNT -gt 0 ]]; then
    AVG_DURATION=$((TOTAL_DURATION / RUN_COUNT))
else
    AVG_DURATION=0
fi

# Sort by duration for percentile
IFS=$'\n' SORTED_DURATIONS=($(printf "%s\n" "${JOB_TIMES[@]}" | cut -d'|' -f3 | sort -n))
unset IFS

P50_INDEX=$((RUN_COUNT / 2))
P90_INDEX=$((RUN_COUNT * 9 / 10))
P95_INDEX=$((RUN_COUNT * 95 / 100))

P50_DURATION=${SORTED_DURATIONS[$P50_INDEX]:-0}
P90_DURATION=${SORTED_DURATIONS[$P90_INDEX]:-0}
P95_DURATION=${SORTED_DURATIONS[$P95_INDEX]:-0}

# Output results
print_header

if [[ "$FORMAT" == "json" ]]; then
    cat <<EOF
{
  "workflow": "$WORKFLOW",
  "period_days": $DAYS,
  "total_runs": $RUN_COUNT,
  "statistics": {
    "avg_duration_seconds": $AVG_DURATION,
    "p50_duration_seconds": $P50_DURATION,
    "p90_duration_seconds": $P90_DURATION,
    "p95_duration_seconds": $P95_DURATION,
    "total_duration_seconds": $TOTAL_DURATION
  },
  "results": {
    "success": $SUCCESS_COUNT,
    "failure": $FAILURE_COUNT,
    "cancelled": $CANCELLED_COUNT,
    "success_rate": $(awk "BEGIN {printf \"%.1f\", ($SUCCESS_COUNT / $RUN_COUNT) * 100}")
  }
}
EOF
elif [[ "$FORMAT" == "csv" ]]; then
    echo "workflow,period_days,total_runs,avg_duration,p50_duration,p90_duration,p95_duration,success_rate"
    echo "$WORKFLOW,$DAYS,$RUN_COUNT,$AVG_DURATION,$P50_DURATION,$P90_DURATION,$P95_DURATION,$(awk "BEGIN {printf \"%.1f\", ($SUCCESS_COUNT / $RUN_COUNT) * 100}")"
else
    # Table format
    printf "${BOLD}│ %-35s │ %-30s │${NC}\n" "Metric" "Value"
    print_separator

    printf "│ %-35s │ %-30s │\n" "Workflow" "$WORKFLOW"
    printf "│ %-35s │ %-30s │\n" "Analysis Period" "$DAYS days"
    printf "│ %-35s │ %-30s │\n" "Total Runs" "$RUN_COUNT"
    print_separator

    printf "│ %-35s │ %-30s │\n" "Average Duration" "$(format_duration $AVG_DURATION)"
    printf "│ %-35s │ %-30s │\n" "Median (P50) Duration" "$(format_duration $P50_DURATION)"
    printf "│ %-35s │ %-30s │\n" "P90 Duration" "$(format_duration $P90_DURATION)"
    printf "│ %-35s │ %-30s │\n" "P95 Duration" "$(format_duration $P95_DURATION)"
    print_separator

    SUCCESS_RATE=$(awk "BEGIN {printf \"%.1f\", ($SUCCESS_COUNT / $RUN_COUNT) * 100}")
    printf "│ %-35s │ %-30s │\n" "Success Rate" "$SUCCESS_RATE%"
    printf "│ %-35s │ %-30s │\n" "Success Count" "$SUCCESS_COUNT"
    printf "│ %-35s │ %-30s │\n" "Failure Count" "$FAILURE_COUNT"
    printf "│ %-35s │ %-30s │\n" "Cancelled Count" "$CANCELLED_COUNT"

    echo -e "${BOLD}└─────────────────────────────────────────────────────────────────────────────────────┘${NC}"
fi

# Bottleneck analysis
if [[ "$ANALYZE" == true ]]; then
    echo ""
    log_info "Bottleneck Analysis"

    # Find slowest runs
    echo ""
    printf "${CYAN}Top 5 Slowest Runs:${NC}\n"
    printf "%-15s %-20s %-15s %-30s\n" "Run ID" "Status" "Duration" "Timestamp"
    printf "%s\n" "────────────────────────────────────────────────────────────────────"

    for entry in $(printf "%s\n" "${JOB_TIMES[@]}" | sort -t'|' -k3 -rn | head -5); do
        IFS='|' read -r run_id conclusion duration created <<< "$entry"
        printf "%-15s %-20s %-15s %-30s\n" \
            "#$run_id" \
            "$conclusion" \
            "$(format_duration $duration)" \
            "$(date -d "$created" -u +%Y-%m-%d\ %H:%M:%S 2>/dev/null || date -jf "%Y-%m-%dT%H:%M:%SZ" "$created" +%Y-%m-%d\ %H:%M:%S 2>/dev/null)"
    done

    # Get job breakdown for slowest run
    SLOWEST_RUN_ID=$(printf "%s\n" "${JOB_TIMES[@]}" | sort -t'|' -k3 -rn | head -1 | cut -d'|' -f1)

    echo ""
    printf "${CYAN}Job Breakdown for #$SLOWEST_RUN_ID:${NC}\n"

    if gh run view "$SLOWEST_RUN_ID" --json jobs > /dev/null 2>&1; then
        JOBS_JSON=$(gh run view "$SLOWEST_RUN_ID" --json jobs --jq '.jobs')
        echo ""
        printf "%-30s %-15s %-15s\n" "Job Name" "Duration" "Status"
        printf "%s\n" "────────────────────────────────────────────────────"

        echo "$JOBS_JSON" | jq -r '.[] | "\(.name)|\(.conclusion // "running")|\(.startedAt)|\(.completedAt)"' | while IFS='|' read -r name conclusion started completed; do
            if [[ -n "$started" && -n "$completed" && "$completed" != "null" ]]; then
                START_SEC=$(date -d "$started" -u +%s 2>/dev/null || date -ujf "%Y-%m-%dT%H:%M:%SZ" "$started" +%s 2>/dev/null)
                END_SEC=$(date -d "$completed" -u +%s 2>/dev/null || date -ujf "%Y-%m-%dT%H:%M:%SZ" "$completed" +%s 2>/dev/null)
                DURATION=$((END_SEC - START_SEC))
                printf "%-30s %-15s %-15s\n" "$name" "$(format_duration $DURATION)" "$conclusion"
            fi
        done
    fi
fi

# Comparison with previous period
if [[ "$COMPARE" == true ]]; then
    echo ""
    log_info "Comparing with previous $DAYS days period"

    PREV_SINCE_DATE=$(date -d "$((DAYS * 2)) days ago" -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -v-$((DAYS * 2))d -u +%Y-%m-%dT%H:%M:%SZ)
    PREV_UNTIL_DATE="$SINCE_DATE"

    PREV_RUNS_JSON=$(gh run list \
        --workflow="$WORKFLOW" \
        --limit "$LIMIT" \
        --json databaseId,conclusion,createdAt,updatedAt \
        --created ">=$PREV_SINCE_DATE" \
        --created "<$PREV_UNTIL_DATE" 2>/dev/null || echo "[]")

    PREV_COUNT=$(echo "$PREV_RUNS_JSON" | jq 'length')

    if [[ $PREV_COUNT -gt 0 ]]; then
        PREV_TOTAL=0
        while IFS= read -r run; do
            CREATED=$(echo "$run" | jq -r '.createdAt')
            UPDATED=$(echo "$run" | jq -r '.updatedAt')
            START_SEC=$(date -d "$CREATED" -u +%s 2>/dev/null || date -ujf "%Y-%m-%dT%H:%M:%SZ" "$CREATED" +%s 2>/dev/null)
            END_SEC=$(date -d "$UPDATED" -u +%s 2>/dev/null || date -ujf "%Y-%m-%dT%H:%M:%SZ" "$UPDATED" +%s 2>/dev/null)
            PREV_TOTAL=$((PREV_TOTAL + END_SEC - START_SEC))
        done < <(echo "$PREV_RUNS_JSON" | jq -c '.[]')

        PREV_AVG=$((PREV_TOTAL / PREV_COUNT))

        echo ""
        printf "${BOLD}Comparison:${NC}\n"
        printf "  Previous Period: %s avg\n" "$(format_duration $PREV_AVG)"
        printf "  Current Period:  %s avg\n" "$(format_duration $AVG_DURATION)"

        if [[ $AVG_DURATION -lt $PREV_AVG ]]; then
            IMPROVEMENT=$((100 * (PREV_AVG - AVG_DURATION) / PREV_AVG))
            printf "  ${GREEN}Improvement: %d%% faster${NC}\n" "$IMPROVEMENT"
        elif [[ $AVG_DURATION -gt $PREV_AVG ]]; then
            REGRESSION=$((100 * (AVG_DURATION - PREV_AVG) / PREV_AVG))
            printf "  ${RED}Regression: %d%% slower${NC}\n" "$REGRESSION"
        else
            printf "  No change\n"
        fi
    fi
fi

# Recommendations
echo ""
printf "${BOLD}Recommendations:${NC}\n"

if [[ $AVG_DURATION -gt 600 ]]; then
    echo -e "  ${YELLOW}• Average build time exceeds 10 minutes${NC}"
    echo "    - Review caching strategy (use ci-cache-stats.sh)"
    echo "    - Consider parallel job execution"
    echo "    - Optimize Docker layer caching"
fi

if [[ $AVG_DURATION -gt 1200 ]]; then
    echo -e "  ${RED}• Average build time exceeds 20 minutes${NC}"
    echo "    - Critical: Implement workflow optimization"
    echo "    - Split pipeline into smaller jobs"
    echo "    - Use matrix strategy for test parallelization"
fi

SUCCESS_RATE=$(awk "BEGIN {printf \"%.0f\", ($SUCCESS_COUNT / $RUN_COUNT) * 100}")
if [[ $SUCCESS_RATE -lt 90 ]]; then
    echo -e "  ${YELLOW}• Success rate below 90% (${SUCCESS_RATE}%)${NC}"
    echo "    - Investigate flaky tests"
    echo "    - Review infrastructure reliability"
    echo "    - Check for timeout issues"
fi

echo ""
log_info "Use --analyze for detailed breakdown"
log_info "Use --compare for period-over-period comparison"

# Format duration helper
format_duration() {
    local seconds=$1
    if [[ $seconds -ge 3600 ]]; then
        printf "%dh %dm %ds" $((seconds / 3600)) $((seconds % 3600 / 60)) $((seconds % 60))
    elif [[ $seconds -ge 60 ]]; then
        printf "%dm %ds" $((seconds / 60)) $((seconds % 60))
    else
        printf "%ds" $seconds
    fi
}

exit 0
