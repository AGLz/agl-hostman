#!/bin/bash
# Grafana Dashboard Export Script
# Exports Grafana dashboards to JSON for version control
# Part of monitoring-analytics-predictive skill

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_API_KEY="${GRAFANA_API_KEY:-}"
OUTPUT_DIR="${OUTPUT_DIR:-/mnt/overpower/apps/dev/agl/agl-hostman/.agent/skills/monitoring/monitoring-analytics-predictive/templates/grafana-dashboards}"
DASHBOARD_FOLDER="${DASHBOARD_FOLDER:-General}"

# Function to log messages
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_dashboard() {
    echo -e "${BLUE}[DASHBOARD]${NC} $1"
}

# Function to check Grafana connectivity
check_grafana() {
    log_info "Checking Grafana connectivity..."

    if [ -z "${GRAFANA_API_KEY}" ]; then
        log_error "GRAFANA_API_KEY is not set"
        log_info "Create API key in Grafana: Configuration -> API Keys -> Add API Key"
        return 1
    fi

    if curl -sf -H "Authorization: Bearer ${GRAFANA_API_KEY}" "${GRAFANA_URL}/api/health" > /dev/null 2>&1; then
        log_info "Grafana is accessible at ${GRAFANA_URL}"
        return 0
    else
        log_error "Cannot reach Grafana at ${GRAFANA_URL}"
        return 1
    fi
}

# Function to list all dashboards
list_dashboards() {
    log_info "Fetching dashboard list..."

    local response=$(curl -s -H "Authorization: Bearer ${GRAFANA_API_KEY}" \
        -H "Content-Type: application/json" \
        "${GRAFANA_URL}/api/search?query=&type=dash-db")

    echo "${response}"
}

# Function to export a single dashboard
export_dashboard() {
    local uid=$1
    local title=$2
    local output_file=$3

    log_dashboard "Exporting: ${title} (${uid})"

    local response=$(curl -s -H "Authorization: Bearer ${GRAFANA_API_KEY}" \
        -H "Content-Type: application/json" \
        "${GRAFANA_URL}/api/dashboards/uid/${uid}")

    # Extract dashboard JSON
    local dashboard_json=$(echo "${response}" | jq '.dashboard')

    # Add metadata
    local export_json=$(cat << EOF
{
  "version": "1.0",
  "exported_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "grafana_url": "${GRAFANA_URL}",
  "dashboard": ${dashboard_json}
}
EOF
)

    echo "${export_json}" | jq '.' > "${output_file}"

    log_info "Saved to ${output_file}"
}

# Function to export all dashboards
export_all_dashboards() {
    log_info "Exporting all dashboards to ${OUTPUT_DIR}..."

    mkdir -p "${OUTPUT_DIR}"

    local dashboards=$(list_dashboards)
    local count=$(echo "${dashboards}" | jq '. | length')

    if [ "${count}" -eq 0 ]; then
        log_warning "No dashboards found"
        return
    fi

    log_info "Found ${count} dashboard(s)"

    for i in $(seq 0 $((${count} - 1))); do
        local uid=$(echo "${dashboards}" | jq -r ".[$i].uid")
        local title=$(echo "${dashboards}" | jq -r ".[$i].title")
        local folder_title=$(echo "${dashboards}" | jq -r ".[$i].folderTitle // \"General\"")

        # Create folder structure
        local folder_dir="${OUTPUT_DIR}/${folder_title}"
        mkdir -p "${folder_dir}"

        # Sanitize filename
        local safe_title=$(echo "${title}" | sed 's/[^a-zA-Z0-9._-]/_/g')
        local output_file="${folder_dir}/${safe_title}.json"

        export_dashboard "${uid}" "${title}" "${output_file}"
    done

    log_info "Exported ${count} dashboard(s)"
}

# Function to import a dashboard
import_dashboard() {
    local input_file=$1
    local overwrite=${2:-false}

    if [ ! -f "${input_file}" ]; then
        log_error "Dashboard file not found: ${input_file}"
        return 1
    fi

    log_dashboard "Importing: ${input_file}"

    # Extract dashboard JSON
    local dashboard_json=$(cat "${input_file}" | jq '.dashboard')
    local overwrite_flag=$(echo "${overwrite}" && echo true || echo false)

    # Prepare payload
    local payload=$(cat << EOF
{
  "dashboard": ${dashboard_json},
  "overwrite": ${overwrite_flag},
  "message": "Imported via grafana-dashboard-export.sh"
}
EOF
)

    # Import dashboard
    local response=$(curl -s -X POST \
        -H "Authorization: Bearer ${GRAFANA_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "${payload}" \
        "${GRAFANA_URL}/api/dashboards/db")

    local status=$(echo "${response}" | jq -r '.status // "unknown"')
    local url=$(echo "${response}" | jq -r '.url // ""')

    if [ "${status}" = "success" ]; then
        log_info "Import successful: ${GRAFANA_URL}${url}"
    else
        log_error "Import failed"
        echo "${response}" | jq '.'
        return 1
    fi
}

# Function to import all dashboards from directory
import_all_dashboards() {
    local input_dir=$1
    local overwrite=${2:-false}

    log_info "Importing dashboards from ${input_dir}..."

    if [ ! -d "${input_dir}" ]; then
        log_error "Directory not found: ${input_dir}"
        return 1
    fi

    local count=0
    local files=$(find "${input_dir}" -name "*.json" -type f)

    for file in ${files}; do
        if import_dashboard "${file}" "${overwrite}"; then
            ((count++))
        fi
    done

    log_info "Imported ${count} dashboard(s)"
}

# Function to create a new dashboard template
create_dashboard_template() {
    local name=$1
    local output_file="${OUTPUT_DIR}/${name}.json"

    log_info "Creating dashboard template: ${name}"

    # Basic dashboard template
    cat > "${output_file}" << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "Dashboard Title",
    "tags": ["templated"],
    "timezone": "browser",
    "schemaVersion": 16,
    "version": 0,
    "refresh": "1m",
    "panels": [],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "timepicker": {
      "refresh_intervals": ["5s", "10s", "30s", "1m", "5m", "15m", "30m", "1h", "2h", "1d"]
    }
  },
  "overwrite": true,
  "message": "Created via grafana-dashboard-export.sh"
}
EOF

    # Update title
    sed -i "s/Dashboard Title/${name}/g" "${output_file}"

    log_info "Template created at ${output_file}"
}

# Function to validate dashboard JSON
validate_dashboard() {
    local file=$1

    if ! command -v jq &> /dev/null; then
        log_warning "jq not found, skipping validation"
        return 0
    fi

    log_info "Validating ${file}..."

    if ! jq empty "${file}" 2>/dev/null; then
        log_error "Invalid JSON in ${file}"
        return 1
    fi

    # Check for required fields
    local dashboard=$(cat "${file}" | jq -r '.dashboard // empty')
    if [ -z "${dashboard}" ]; then
        log_error "Missing 'dashboard' field in ${file}"
        return 1
    fi

    local title=$(cat "${file}" | jq -r '.dashboard.title // empty')
    if [ -z "${title}" ]; then
        log_error "Missing 'dashboard.title' field in ${file}"
        return 1
    fi

    log_info "Validation passed: ${title}"
    return 0
}

# Function to sync dashboards to git repository
sync_to_git() {
    local repo_path="${OUTPUT_DIR}"

    log_info "Syncing dashboards to git..."

    cd "${repo_path}"

    # Check if this is a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_warning "Not a git repository: ${repo_path}"
        return
    fi

    # Add all dashboard files
    git add ./*.json 2>/dev/null || true
    git add */*.json 2>/dev/null || true

    # Check if there are changes
    if git diff --cached --quiet; then
        log_info "No changes to commit"
        return
    fi

    # Commit changes
    local commit_msg="chore: update Grafana dashboards $(date -u +"%Y-%m-%d %H:%M:%S UTC")"

    git commit -m "${commit_msg}"

    log_info "Changes committed to git"
}

# Function to display usage
usage() {
    cat << EOF
Grafana Dashboard Export/Import Script

Usage: $0 [OPTIONS]

Options:
    --list              List all dashboards in Grafana
    --export            Export all dashboards to files
    --export-uid UID    Export specific dashboard by UID
    --import FILE       Import a dashboard from file
    --import-dir DIR    Import all dashboards from directory
    --create NAME       Create a new dashboard template
    --validate FILE     Validate dashboard JSON file
    --sync              Sync exported dashboards to git
    --output DIR        Output directory for exports
    --overwrite         Overwrite existing dashboards on import
    -h, --help          Show this help message

Environment Variables:
    GRAFANA_URL         Grafana URL (default: http://localhost:3000)
    GRAFANA_API_KEY     Grafana API key (required)
    OUTPUT_DIR          Output directory for exports
    DASHBOARD_FOLDER    Folder to filter dashboards (default: General)

Examples:
    # Export all dashboards
    $0 --export

    # Export specific dashboard
    $0 --export-uid "abc123"

    # Import a dashboard
    $0 --import templates/grafana-dashboards/overview.json

    # Import all dashboards from directory
    $0 --import-dir templates/grafana-dashboards/ --overwrite

    # Create new template
    $0 --create "My Dashboard"

    # Validate dashboard file
    $0 --validate templates/grafana-dashboards/overview.json

    # Sync to git
    $0 --sync

EOF
}

# Main execution
main() {
    local action=""
    local uid=""
    local input_file=""
    local input_dir=""
    local template_name=""
    local validate_file=""
    local do_list=false
    local do_export=false
    local do_import=false
    local do_sync=false
    local overwrite=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --list)
                do_list=true
                shift
                ;;
            --export)
                do_export=true
                shift
                ;;
            --export-uid)
                do_export=true
                uid="$2"
                shift 2
                ;;
            --import)
                do_import=true
                input_file="$2"
                shift 2
                ;;
            --import-dir)
                do_import=true
                input_dir="$2"
                shift 2
                ;;
            --create)
                template_name="$2"
                shift 2
                ;;
            --validate)
                validate_file="$2"
                shift 2
                ;;
            --sync)
                do_sync=true
                shift
                ;;
            --output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            --overwrite)
                overwrite=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    # Check Grafana connectivity for operations that require it
    if [ "$do_list" = true ] || [ "$do_export" = true ] || [ "$do_import" = true ]; then
        check_grafana || exit 1
    fi

    # Execute requested action
    if [ "$do_list" = true ]; then
        local dashboards=$(list_dashboards)
        echo "${dashboards}" | jq -r '.[] | "\(.title) (\(.uid)) - Folder: \(.folderTitle // "General")"'
    elif [ "$do_export" = true ]; then
        if [ -n "${uid}" ]; then
            # Export single dashboard
            local title=$(curl -s -H "Authorization: Bearer ${GRAFANA_API_KEY}" \
                "${GRAFANA_URL}/api/dashboards/uid/${uid}" | jq -r '.dashboard.title')
            local safe_title=$(echo "${title}" | sed 's/[^a-zA-Z0-9._-]/_/g')
            export_dashboard "${uid}" "${title}" "${OUTPUT_DIR}/${safe_title}.json"
        else
            export_all_dashboards
        fi
    elif [ "$do_import" = true ]; then
        if [ -n "${input_file}" ]; then
            import_dashboard "${input_file}" "${overwrite}"
        elif [ -n "${input_dir}" ]; then
            import_all_dashboards "${input_dir}" "${overwrite}"
        else
            log_error "Specify --import FILE or --import-dir DIR"
            exit 1
        fi
    elif [ -n "${template_name}" ]; then
        create_dashboard_template "${template_name}"
    elif [ -n "${validate_file}" ]; then
        validate_dashboard "${validate_file}"
    elif [ "$do_sync" = true ]; then
        sync_to_git
    else
        log_error "No action specified"
        usage
        exit 1
    fi

    log_info "Operation completed successfully"
}

main "$@"
