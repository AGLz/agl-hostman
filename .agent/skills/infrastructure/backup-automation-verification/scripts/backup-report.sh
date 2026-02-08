#!/bin/bash
################################################################################
# Backup Status Report Generator
# Generates backup status and health reports
# Usage: ./backup-report.sh [--output /path/to/report.md] [--email recipient@example.com]
################################################################################

set -euo pipefail

# Configuration
BACKUP_DIR="${BACKUP_DIR:-/var/backups}"
REPORT_OUTPUT="${REPORT_OUTPUT:-}"
REPORT_FORMAT="${REPORT_FORMAT:-markdown}"
SEND_EMAIL="${SEND_EMAIL:-false}"
EMAIL_TO="${EMAIL_TO:-ops@example.com}"
EMAIL_FROM="${EMAIL_FROM:-backup-reports@$(hostname)}"
SMTP_SERVER="${SMTP_SERVER:-localhost}"

# Thresholds
MAX_AGE_HOURS="${MAX_AGE_HOURS:-24}"
MIN_SIZE_MB="${MIN_SIZE_MB:-1}"
WARN_THRESHOLD_DAYS="${WARN_THRESHOLD_DAYS:-3}"

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Report data
declare -A BACKUP_STATS
TOTAL_SIZE=0
TOTAL_COUNT=0
STALE_COUNT=0
MISSING_COUNT=0
FAILED_COUNT=0

# Logging
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Format bytes for display
format_bytes() {
    local bytes=$1
    local units=('B' 'KB' 'MB' 'GB' 'TB')
    local unit=0

    while (( bytes > 1024 && unit < 4 )); do
        bytes=$((bytes / 1024))
        ((unit++))
    done

    echo "${bytes} ${units[$unit]}"
}

# Get file size
get_file_size() {
    local file="$1"
    stat -c %s "$file" 2>/dev/null || stat -f %z "$file"
}

# Get file age in hours
get_file_age_hours() {
    local file="$1"
    local now=$(date +%s)
    local mtime=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file")
    echo $(( (now - mtime) / 3600 ))
}

# Get file modification time
get_file_mtime() {
    local file="$1"
    stat -c %y "$file" 2>/dev/null || stat -f "%Sm" "$file"
}

# Get file type
get_backup_type() {
    local file="$1"
    local basename=$(basename "$file")

    if [[ "$basename" =~ hourly ]] || [[ "$file" =~ /hourly/ ]]; then
        echo "hourly"
    elif [[ "$basename" =~ weekly ]] || [[ "$file" =~ /weekly/ ]]; then
        echo "weekly"
    elif [[ "$basename" =~ monthly ]] || [[ "$file" =~ /monthly/ ]]; then
        echo "monthly"
    elif [[ "$basename" =~ \.sql ]]; then
        echo "database"
    elif [[ "$basename" =~ \.tar ]]; then
        echo "files"
    else
        echo "unknown"
    fi
}

# Check if backup is stale
is_stale() {
    local age_hours=$1
    [[ $age_hours -gt $MAX_AGE_HOURS ]]
}

# Check if backup is too small
is_too_small() {
    local size_bytes=$1
    local min_bytes=$((MIN_SIZE_MB * 1024 * 1024))
    [[ $size_bytes -lt $min_bytes ]]
}

# Scan backup directory
scan_backups() {
    local dir="$1"

    if [[ ! -d "$dir" ]]; then
        log_warn "Directory not found: $dir"
        return 0
    fi

    while IFS= read -r -d '' file; do
        [[ ! -f "$file" ]] && continue

        local size=$(get_file_size "$file")
        local age_hours=$(get_file_age_hours "$file")
        local type=$(get_backup_type "$file")
        local mtime=$(get_file_mtime "$file")
        local basename=$(basename "$file")

        # Update totals
        ((TOTAL_COUNT++))
        ((TOTAL_SIZE += size))

        # Track by type
        local type_key="count_${type}"
        BACKUP_STATS[$type_key]=$((${BACKUP_STATS[$type_key]:-0} + 1))

        local size_key="size_${type}"
        BACKUP_STATS[$size_key]=$((${BACKUP_STATS[$size_key]:-0} + size))

        # Check for issues
        if is_stale $age_hours; then
            ((STALE_COUNT++))
            BACKUP_STATS["stale_${type}"]=$((${BACKUP_STATS["stale_${type}"]:0} + 1))
        fi

        if is_too_small $size; then
            ((FAILED_COUNT++))
            BACKUP_STATS["small_${type}"]=$((${BACKUP_STATS["small_${type}"]:0} + 1))
        fi

    done < <(find "$dir" -type f \( -name "*.sql" -o -name "*.sql.gz" -o -name "*.tar.gz" \) -print0)
}

# Check for missing backups
check_missing_backups() {
    local expected_dirs=(
        "${BACKUP_DIR}/database/hourly"
        "${BACKUP_DIR}/database/daily"
        "${BACKUP_DIR}/database/weekly"
        "${BACKUP_DIR}/files"
    )

    for dir in "${expected_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            ((MISSING_COUNT++))
            log_warn "Expected backup directory missing: $dir"
        fi
    done
}

# Generate markdown report
generate_markdown_report() {
    local timestamp=$(date -Iseconds)
    local hostname=$(hostname)

    cat << EOF
# Backup Status Report

**Generated:** $timestamp
**Host:** $hostname
**Backup Directory:** $BACKUP_DIR

## Executive Summary

| Metric | Value |
|--------|-------|
| Total Backups | $TOTAL_COUNT |
| Total Size | $(format_bytes $TOTAL_SIZE) |
| Stale Backups | $STALE_COUNT |
| Missing Directories | $MISSING_COUNT |
| Failed Backups | $FAILED_COUNT |

## Status Indicator

EOF

    local status="Healthy"
    local emoji=":white_check_mark:"

    if [[ $STALE_COUNT -gt 0 ]] || [[ $FAILED_COUNT -gt 0 ]]; then
        status="Warning"
        emoji=":warning:"
    fi

    if [[ $STALE_COUNT -gt 5 ]] || [[ $FAILED_COUNT -gt 3 ]]; then
        status="Critical"
        emoji=":x:"
    fi

    echo "**Status:** $emoji $status"
    echo ""

    # Backup counts by type
    echo "## Backup Counts by Type"
    echo ""
    echo "| Type | Count | Size |"
    echo "|------|-------|------|"

    for type in hourly daily weekly monthly database files; do
        local count=${BACKUP_STATS["count_${type}"]:0}
        local size=${BACKUP_STATS["size_${type}"]:0}

        if [[ $count -gt 0 ]]; then
            echo "| $type | $count | $(format_bytes $size) |"
        fi
    done

    echo ""

    # Recent backups
    echo "## Recent Backups"
    echo ""
    echo "| File | Type | Size | Age | Modified |
    |------|------|------|-----|----------|"

    find "$BACKUP_DIR" -type f \( -name "*.sql" -o -name "*.sql.gz" -o -name "*.tar.gz" \) \
        -printf '%T@ %p\n' 2>/dev/null | \
        sort -rn | head -10 | while read -r ts file; do
        local basename=$(basename "$file")
        local type=$(get_backup_type "$file")
        local size=$(format_bytes $(get_file_size "$file"))
        local age=$(get_file_age_hours "$file")
        local mtime=$(get_file_mtime "$file")

        echo "| $basename | $type | $size | ${age}h | $mtime |"
    done

    echo ""

    # Issues
    if [[ $STALE_COUNT -gt 0 ]] || [[ $FAILED_COUNT -gt 0 ]]; then
        echo "## Issues Detected"
        echo ""

        if [[ $STALE_COUNT -gt 0 ]]; then
            echo "### Stale Backups ($STALE_COUNT)"
            echo ""
            echo "The following backups are older than ${MAX_AGE_HOURS} hours:"
            echo ""

            find "$BACKUP_DIR" -type f \( -name "*.sql" -o -name "*.sql.gz" -o -name "*.tar.gz" \) \
                -printf '%T@ %p\n' 2>/dev/null | \
                awk -v max_age=$MAX_AGE_HOURS '
                {
                    now = systime();
                    age_hours = (now - $1) / 3600;
                    if (age_hours > max_age) {
                        print $2 " (" int(age_hours) " hours old)";
                    }
                }'
            echo ""
        fi

        if [[ $FAILED_COUNT -gt 0 ]]; then
            echo "### Backup Issues ($FAILED_COUNT)"
            echo ""
            echo "The following backups may have issues:"
            echo ""

            find "$BACKUP_DIR" -type f \( -name "*.sql" -o -name "*.sql.gz" -o -name "*.tar.gz" \) \
                -exec stat -c "%s %n" {} \; 2>/dev/null | \
                awk -v min_bytes=$((MIN_SIZE_MB * 1024 * 1024)) '
                {
                    if ($1 < min_bytes) {
                        print $2 " (" $1 " bytes - too small)";
                    }
                }'
            echo ""
        fi
    fi

    # Recommendations
    echo "## Recommendations"
    echo ""

    if [[ $STALE_COUNT -gt 0 ]]; then
        echo "- [ ] Review and resolve stale backups"
    fi

    if [[ $FAILED_COUNT -gt 0 ]]; then
        echo "- [ ] Investigate small/failed backups"
    fi

    if [[ $MISSING_COUNT -gt 0 ]]; then
        echo "- [ ] Create missing backup directories"
    fi

    if [[ $TOTAL_COUNT -eq 0 ]]; then
        echo "- [ ] **URGENT:** No backups found - backup system may be down"
    else
        echo "- [ ] Continue regular backup schedule"
        echo "- [ ] Run weekly restore tests"
        echo "- [ ] Review retention policy"
    fi

    echo ""
    echo "---"
    echo ""
    echo "*Report generated by backup-report.sh*"
}

# Generate JSON report
generate_json_report() {
    local timestamp=$(date -Iseconds)
    local hostname=$(hostname)

    cat << EOF
{
  "generated_at": "$timestamp",
  "hostname": "$hostname",
  "backup_directory": "$BACKUP_DIR",
  "summary": {
    "total_backups": $TOTAL_COUNT,
    "total_size_bytes": $TOTAL_SIZE,
    "stale_backups": $STALE_COUNT,
    "missing_directories": $MISSING_COUNT,
    "failed_backups": $FAILED_COUNT
  },
  "by_type": {
EOF

    local first=true
    for type in hourly daily weekly monthly database files; do
        local count=${BACKUP_STATS["count_${type}"]:0}
        local size=${BACKUP_STATS["size_${type}"]:0}

        if [[ $count -gt 0 ]]; then
            if [[ "$first" == "true" ]]; then
                first=false
            else
                echo ","
            fi
            printf '    "%s": {"count": %d, "size_bytes": %d}' "$type" $count $size
        fi
    done

    echo ""
    echo "  }"
    echo "}"
}

# Send email report
send_email_report() {
    local report_content="$1"
    local subject="Backup Status Report - $(hostname) - $(date +%Y-%m-%d)"

    if [[ "$SEND_EMAIL" != "true" ]]; then
        return 0
    fi

    log_info "Sending email report to: $EMAIL_TO"

    # Create email headers
    local email_file=$(mktemp)
    cat > "$email_file" << EOF
Subject: $subject
From: $EMAIL_FROM
To: $EMAIL_TO
Content-Type: text/plain; charset=utf-8

$report_content
EOF

    # Send email
    if command -v sendmail &> /dev/null; then
        sendmail -t < "$email_file"
        log_info "Email sent successfully"
    elif command -v mail &> /dev/null; then
        echo "$report_content" | mail -s "$subject" "$EMAIL_TO"
        log_info "Email sent successfully"
    else
        log_warn "No mail utility found, skipping email"
    fi

    rm -f "$email_file"
}

# Main execution
main() {
    log_info "=== Generating Backup Status Report ==="

    # Scan backup directories
    scan_backups "${BACKUP_DIR}/database"
    scan_backups "${BACKUP_DIR}/files"

    # Check for missing directories
    check_missing_backups

    # Generate report
    local report_content=""

    case "$REPORT_FORMAT" in
        json)
            report_content=$(generate_json_report)
            ;;
        markdown|*)
            report_content=$(generate_markdown_report)
            ;;
    esac

    # Output report
    if [[ -n "$REPORT_OUTPUT" ]]; then
        echo "$report_content" > "$REPORT_OUTPUT"
        log_info "Report saved to: $REPORT_OUTPUT"
    else
        echo "$report_content"
    fi

    # Send email if configured
    send_email_report "$report_content"

    # Exit with appropriate code
    if [[ $STALE_COUNT -gt 5 ]] || [[ $FAILED_COUNT -gt 3 ]]; then
        log_error "Backup status: CRITICAL"
        exit 2
    elif [[ $STALE_COUNT -gt 0 ]] || [[ $FAILED_COUNT -gt 0 ]]; then
        log_warn "Backup status: WARNING"
        exit 1
    else
        log_info "Backup status: HEALTHY"
        exit 0
    fi
}

# Run main function
main "$@"
