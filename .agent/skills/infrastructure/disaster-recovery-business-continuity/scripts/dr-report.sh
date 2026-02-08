#!/bin/bash
################################################################################
# Disaster Recovery Report Generator
# Generates DR readiness reports, drill reports, and incident summaries
# Usage: ./dr-report.sh [--type readiness|drill|incident] [--output file]
################################################################################

set -euo pipefail

################################################################################
# Configuration
################################################################################

# Report settings
REPORT_TYPE="${REPORT_TYPE:-readiness}"
REPORT_OUTPUT_DIR="${REPORT_OUTPUT_DIR:-/var/log/dr/reports}"
REPORT_FORMAT="${REPORT_FORMAT:-json}"  # json, html, markdown

# Data sources
VALIDATION_DATA_DIR="${VALIDATION_DATA_DIR:-/var/log/dr}"
DRILL_DATA_DIR="${DRILL_DATA_DIR:-/var/log/dr/drills}"
INCIDENT_DATA_DIR="${INCIDENT_DATA_DIR:-/var/log/dr/incidents}"

# Company information
COMPANY_NAME="${COMPANY_NAME:-Example Company}"
REPORT_GENERATOR="DR Report Generator v1.0"

# RTO/RPO targets
RTO_TARGETS="${RTO_TARGETS:-{database:900,application:1800,all:3600}}"
RPO_TARGETS="${RPO_TARGETS:-{database:300,application:0,all:300}}"

# Script options
VERBOSE="${VERBOSE:-false}"
INCLUDE_RECOMMENDATIONS="${INCLUDE_RECOMMENDATIONS:-true}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

################################################################################
# Utility Functions
################################################################################

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# Initialize report directory
setup_report_dir() {
    mkdir -p "$REPORT_OUTPUT_DIR"
}

################################################################################
# Data Collection Functions
################################################################################

# Collect validation results
collect_validation_data() {
    local validation_files=()

    # Find recent validation reports
    if [[ -d "$VALIDATION_DATA_DIR" ]]; then
        validation_files=($(find "$VALIDATION_DATA_DIR" -name "validation-report-*.json" -mtime -30 2>/dev/null | sort -r))
    fi

    local total_checks=0
    local passed=0
    local warned=0
    local failed=0

    for file in "${validation_files[@]}"; do
        if [[ -f "$file" ]]; then
            local data=$(cat "$file" 2>/dev/null)
            total_checks=$((total_checks + $(echo "$data" | jq -r '.summary.total // 0')))
            passed=$((passed + $(echo "$data" | jq -r '.summary.passed // 0')))
            warned=$((warned + $(echo "$data" | jq -r '.summary.warned // 0')))
            failed=$((failed + $(echo "$data" | jq -r '.summary.failed // 0')))
        fi
    done

    echo "{\"total\":$total_checks,\"passed\":$passed,\"warned\":$warned,\"failed\":$failed,\"files\":${#validation_files[@]}}"
}

# Collect drill data
collect_drill_data() {
    local drill_files=()

    if [[ -d "$DRILL_DATA_DIR" ]]; then
        drill_files=($(find "$DRILL_DATA_DIR" -name "*-report.json" -mtime -90 2>/dev/null | sort -r))
    fi

    local total_drills=${#drill_files[@]}
    local completed_drills=0
    local total_duration=0
    local total_action_items=0

    for file in "${drill_files[@]}"; do
        if [[ -f "$file" ]]; then
            local data=$(cat "$file" 2>/dev/null)
            local status=$(echo "$data" | jq -r '.status // ""')
            [[ "$status" == "completed" ]] && ((completed_drills++))
            total_duration=$((total_duration + $(echo "$data" | jq -r '.duration_seconds // 0')))
            total_action_items=$((total_action_items + $(echo "$data" | jq -r '.action_items | length' 2>/dev/null || echo "0")))
        fi
    done

    echo "{\"total\":$total_drills,\"completed\":$completed_drills,\"total_duration\":$total_duration,\"action_items\":$total_action_items}"
}

# Collect backup data
collect_backup_data() {
    local backup_dir="${BACKUP_DIR:-/var/backups}"
    local backup_count=0
    local backup_size=0
    local latest_backup_age=999999

    if [[ -d "$backup_dir" ]]; then
        backup_count=$(find "$backup_dir" -type f -mtime -7 2>/dev/null | wc -l)
        backup_size=$(du -sb "$backup_dir" 2>/dev/null | awk '{print $1}')

        local latest=$(find "$backup_dir" -type f -printf '%T@\n' 2>/dev/null | sort -rn | head -1)
        if [[ -n "$latest" ]]; then
            local now=$(date +%s)
            latest_backup_age=$((now - ${latest%.*}))
        fi
    fi

    echo "{\"count\":$backup_count,\"size\":$backup_size,\"latest_age\":$latest_backup_age}"
}

# Collect replication data
collect_replication_data() {
    local lag_seconds=-1
    local status="unknown"

    if command -v mysql > /dev/null 2>&1 && [[ -n "${DB_BACKUP_HOST:-}" ]]; then
        local slave_status=$(mysql -h "$DB_BACKUP_HOST" -e "SHOW SLAVE STATUS\G" 2>/dev/null || echo "")
        lag_seconds=$(echo "$slave_status" | grep "Seconds_Behind_Master:" | awk '{print $2}')

        if [[ "$lag_seconds" == "NULL" ]]; then
            lag_seconds=-1
            status="stopped"
        else
            status="running"
        fi
    fi

    echo "{\"lag\":$lag_seconds,\"status\":\"$status\"}"
}

################################################################################
# Report Generation Functions
################################################################################

# Generate readiness score
calculate_readiness_score() {
    local validation_data="$1"
    local backup_data="$2"
    local replication_data="$3"
    local drill_data="$4"

    local score=0
    local max_score=100

    # Validation score (40 points)
    local total=$(echo "$validation_data" | jq -r '.total')
    local passed=$(echo "$validation_data" | jq -r '.passed')
    if [[ $total -gt 0 ]]; then
        local validation_score=$((passed * 40 / total))
        score=$((score + validation_score))
    fi

    # Backup score (30 points)
    local backup_count=$(echo "$backup_data" | jq -r '.count')
    local backup_age=$(echo "$backup_data" | jq -r '.latest_age')
    if [[ $backup_count -gt 0 && $backup_age -lt 86400 ]]; then
        score=$((score + 30))
    elif [[ $backup_count -gt 0 && $backup_age -lt 172800 ]]; then
        score=$((score + 15))
    fi

    # Replication score (20 points)
    local replication_lag=$(echo "$replication_data" | jq -r '.lag')
    if [[ "$replication_lag" != "-1" && "$replication_lag" -lt 60 ]]; then
        score=$((score + 20))
    elif [[ "$replication_lag" != "-1" && "$replication_lag" -lt 300 ]]; then
        score=$((score + 10))
    fi

    # Drill score (10 points)
    local drills_completed=$(echo "$drill_data" | jq -r '.completed')
    if [[ $drills_completed -ge 4 ]]; then
        score=$((score + 10))
    elif [[ $drills_completed -ge 2 ]]; then
        score=$((score + 5))
    fi

    echo "$score"
}

# Generate readiness report
generate_readiness_report() {
    local timestamp=$(date -Iseconds)
    local validation_data=$(collect_validation_data)
    local backup_data=$(collect_backup_data)
    local replication_data=$(collect_replication_data)
    local drill_data=$(collect_drill_data)

    local readiness_score=$(calculate_readiness_score "$validation_data" "$backup_data" "$replication_data" "$drill_data")
    local readiness_level="Unknown"

    if [[ $readiness_score -ge 90 ]]; then
        readiness_level="Excellent"
    elif [[ $readiness_score -ge 75 ]]; then
        readiness_level="Good"
    elif [[ $readiness_score -ge 60 ]]; then
        readiness_level="Fair"
    else
        readiness_level="Poor"
    fi

    local report="{
        \"report_type\": \"readiness\",
        \"generated_at\": \"$timestamp\",
        \"company\": \"$COMPANY_NAME\",
        \"readiness_score\": $readiness_score,
        \"readiness_level\": \"$readiness_level\",
        \"validation\": $validation_data,
        \"backups\": $backup_data,
        \"replication\": $replication_data,
        \"drills\": $drill_data,
        \"rto_targets\": $RTO_TARGETS,
        \"rpo_targets\": $RPO_TARGETS
    }"

    # Add recommendations if enabled
    if [[ "$INCLUDE_RECOMMENDATIONS" == "true" ]]; then
        report=$(echo "$report" | jq --argjson recommendations "$(generate_recommendations "$validation_data" "$backup_data" "$replication_data" "$drill_data")" '. + {recommendations: $recommendations}')
    fi

    echo "$report"
}

# Generate recommendations
generate_recommendations() {
    local validation_data="$1"
    local backup_data="$2"
    local replication_data="$3"
    local drill_data="$4"

    local recommendations=()

    # Validation recommendations
    local validation_failed=$(echo "$validation_data" | jq -r '.failed')
    if [[ $validation_failed -gt 0 ]]; then
        recommendations+=("Address $validation_failed validation failures")
    fi

    # Backup recommendations
    local backup_age=$(echo "$backup_data" | jq -r '.latest_age')
    if [[ $backup_age -gt 86400 ]]; then
        recommendations+=("Recent backups missing - verify backup schedule")
    fi

    # Replication recommendations
    local replication_lag=$(echo "$replication_data" | jq -r '.lag')
    if [[ "$replication_lag" == "-1" ]]; then
        recommendations+=("Database replication not running - investigate immediately")
    elif [[ "$replication_lag" -gt 300 ]]; then
        recommendations+=("Replication lag high (${replication_lag}s) - check network and load")
    fi

    # Drill recommendations
    local drills_completed=$(echo "$drill_data" | jq -r '.completed')
    if [[ $drills_completed -lt 2 ]]; then
        recommendations+=("Schedule more frequent DR drills")
    fi

    local action_items=$(echo "$drill_data" | jq -r '.action_items')
    if [[ $action_items -gt 5 ]]; then
        recommendations+=("Address $action_items open drill action items")
    fi

    # Convert to JSON array
    local json="["
    local first=true
    for rec in "${recommendations[@]}"; do
        [[ "$first" == "true" ]] && first=false || json+=","
        json+="\"$rec\""
    done
    json+="]"

    echo "$json"
}

# Generate drill report
generate_drill_report() {
    local drill_id="${1:-latest}"
    local drill_file=""

    if [[ "$drill_id" == "latest" ]]; then
        drill_file=$(find "$DRILL_DATA_DIR" -name "*-report.json" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
    else
        drill_file="${DRILL_DATA_DIR}/${drill_id}-report.json"
    fi

    if [[ ! -f "$drill_file" ]]; then
        log_error "Drill report not found: $drill_file"
        echo "{\"error\": \"Drill report not found\"}"
        return 1
    fi

    cat "$drill_file"
}

# Generate incident report
generate_incident_report() {
    local incident_id="${1:-latest}"
    local incident_file=""

    if [[ "$incident_id" == "latest" ]]; then
        incident_file=$(find "$INCIDENT_DATA_DIR" -name "*-report.json" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
    else
        incident_file="${INCIDENT_DATA_DIR}/${incident_id}-report.json"
    fi

    if [[ ! -f "$incident_file" ]]; then
        log_error "Incident report not found: $incident_file"
        echo "{\"error\": \"Incident report not found\"}"
        return 1
    fi

    cat "$incident_file"
}

# Convert to HTML
convert_to_html() {
    local json="$1"
    local report_type=$(echo "$json" | jq -r '.report_type // "report"')
    local timestamp=$(date -Iseconds)

    cat <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DR Report - $report_type</title>
    <style>
        body { font-family: system-ui, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 3px solid #007bff; padding-bottom: 10px; }
        .score { font-size: 48px; font-weight: bold; text-align: center; padding: 20px; border-radius: 8px; margin: 20px 0; }
        .score.excellent { background: #28a745; color: white; }
        .score.good { background: #5cb85c; color: white; }
        .score.fair { background: #ffc107; color: #333; }
        .score.poor { background: #dc3545; color: white; }
        .section { margin: 30px 0; padding: 20px; background: #f8f9fa; border-radius: 8px; }
        .metric { display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid #dee2e6; }
        .metric:last-child { border-bottom: none; }
        .recommendation { background: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 10px 0; }
        .timestamp { color: #6c757d; font-size: 14px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>DR Report: $report_type</h1>
        <p class="timestamp">Generated: $timestamp</p>

EOF

    # Add readiness score if applicable
    if [[ "$report_type" == "readiness" ]]; then
        local score=$(echo "$json" | jq -r '.readiness_score')
        local level=$(echo "$json" | jq -r '.readiness_level')
        echo "<div class=\"score $level\">$score%</div>"
        echo "<p><strong>Readiness Level:</strong> $level</p>"
    fi

    echo "    </div>
</body>
</html>"
}

# Convert to Markdown
convert_to_markdown() {
    local json="$1"
    local report_type=$(echo "$json" | jq -r '.report_type // "report"')
    local timestamp=$(date -Iseconds)

    cat <<EOF
# DR Report: $report_type

**Generated:** $timestamp
**Company:** $COMPANY_NAME

EOF

    if [[ "$report_type" == "readiness" ]]; then
        local score=$(echo "$json" | jq -r '.readiness_score')
        local level=$(echo "$json" | jq -r '.readiness_level')

        echo "## Readiness Score: **$score%** ($level)"
        echo ""
        echo "### Validation Status"
        echo "- Total Checks: $(echo "$json" | jq -r '.validation.total')"
        echo "- Passed: $(echo "$json" | jq -r '.validation.passed')"
        echo "- Warnings: $(echo "$json" | jq -r '.validation.warned')"
        echo "- Failed: $(echo "$json" | jq -r '.validation.failed')"
        echo ""
    fi

    echo "---"
    echo ""
    echo "*Generated by $REPORT_GENERATOR*"
}

################################################################################
# Main Execution
################################################################################

main() {
    setup_report_dir

    local report_id="${1:-latest}"
    local output_format="${REPORT_FORMAT}"
    local output_file=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --type)
                REPORT_TYPE="$2"
                shift 2
                ;;
            --output)
                output_file="$2"
                shift 2
                ;;
            --format)
                output_format="$2"
                shift 2
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            *)
                report_id="$1"
                shift
                ;;
        esac
    done

    log_info "Generating DR report..."
    log_info "Type: $REPORT_TYPE"
    log_info "Format: $output_format"

    # Generate report based on type
    local report_json=""
    case "$REPORT_TYPE" in
        readiness)
            report_json=$(generate_readiness_report)
            ;;
        drill)
            report_json=$(generate_drill_report "$report_id")
            ;;
        incident)
            report_json=$(generate_incident_report "$report_id")
            ;;
        *)
            log_error "Unknown report type: $REPORT_TYPE"
            exit 1
            ;;
    esac

    # Convert to requested format
    local final_output=""
    case "$output_format" in
        json)
            final_output=$(echo "$report_json" | jq '.')
            ;;
        html)
            final_output=$(convert_to_html "$report_json")
            ;;
        markdown)
            final_output=$(convert_to_markdown "$report_json")
            ;;
        *)
            log_error "Unknown format: $output_format"
            exit 1
            ;;
    esac

    # Output report
    if [[ -n "$output_file" ]]; then
        echo "$final_output" > "$output_file"
        log_info "Report saved to: $output_file"
    else
        echo "$final_output"
    fi

    log_info "DR report generation complete"
}

main "$@"
