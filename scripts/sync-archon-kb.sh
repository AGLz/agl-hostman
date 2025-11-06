#!/bin/bash
# Sync Documentation to Archon Knowledge Base
# Automated script for batch syncing documentation updates

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ARCHON_URL="http://192.168.0.183:8052"
HTTP_PORT=8765
HTTP_BIND="192.168.0.183"
DOCS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/docs"
PID_FILE="/tmp/archon-sync-http.pid"

# Logging
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Start temporary HTTP server
start_http_server() {
    log_step "Starting temporary HTTP server..."

    # Check if already running
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        log_info "HTTP server already running (PID: $(cat $PID_FILE))"
        return 0
    fi

    # Start server
    cd "$DOCS_DIR/.."
    python3 -m http.server $HTTP_PORT --bind $HTTP_BIND > /dev/null 2>&1 &
    echo $! > "$PID_FILE"

    # Wait for server to start
    sleep 2

    # Verify server is running
    if ! curl -s -I "http://$HTTP_BIND:$HTTP_PORT/" > /dev/null; then
        log_error "Failed to start HTTP server"
        rm -f "$PID_FILE"
        return 1
    fi

    log_info "HTTP server running on http://$HTTP_BIND:$HTTP_PORT (PID: $(cat $PID_FILE))"
}

# Stop HTTP server
stop_http_server() {
    log_step "Stopping HTTP server..."

    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            log_info "HTTP server stopped (PID: $pid)"
        fi
        rm -f "$PID_FILE"
    else
        log_warn "No HTTP server PID file found"
    fi
}

# Sync single document to Archon
sync_document() {
    local doc_path="$1"
    local doc_name=$(basename "$doc_path")
    local doc_url="http://$HTTP_BIND:$HTTP_PORT/$doc_path"

    log_step "Syncing: $doc_name"

    # Verify document is accessible
    if ! curl -s -f "$doc_url" > /dev/null; then
        log_error "Document not accessible: $doc_url"
        return 1
    fi

    # Extract title from document
    local title=$(head -1 "$DOCS_DIR/../$doc_path" | sed 's/^# //')

    # Determine tags based on document name
    local tags="technical"
    case "$doc_name" in
        *INFRA*)
            tags="infrastructure,network,wireguard,proxmox,docker,storage"
            ;;
        *ARCHON*)
            tags="archon,mcp,ai,task-management,knowledge-base"
            ;;
        *WORKFLOW*)
            tags="workflows,sparc,agent-os,development,automation"
            ;;
        *RULES*)
            tags="coding-standards,rules,best-practices,guidelines"
            ;;
        *DEPLOY*)
            tags="deployment,harbor,dokploy,ci-cd"
            ;;
        *TROUBLESHOOT*)
            tags="troubleshooting,debugging,diagnostics"
            ;;
        *ROLLBACK*)
            tags="rollback,emergency,recovery"
            ;;
    esac

    log_info "Title: $title"
    log_info "Tags: $tags"
    log_info "URL: $doc_url"

    # Note: Actual MCP call would be made here
    # This script is meant to be called from Claude Code context
    echo "{\"document\": \"$doc_name\", \"url\": \"$doc_url\", \"title\": \"$title\", \"tags\": \"$tags\"}"

    return 0
}

# Main function
main() {
    log_info "=== Archon Knowledge Base Sync ==="
    echo ""

    # Parse arguments
    local changed_only=false
    local docs_to_sync=()

    while [[ $# -gt 0 ]]; do
        case $1 in
            --changed)
                changed_only=true
                shift
                ;;
            --all)
                changed_only=false
                shift
                ;;
            *)
                docs_to_sync+=("$1")
                shift
                ;;
        esac
    done

    # Determine which documents to sync
    if [ "$changed_only" = true ]; then
        log_step "Detecting changed documents..."
        local changed=$(git diff --name-only HEAD~1 HEAD | grep -E "^docs/.*\.md$|^CLAUDE\.md$" || true)

        if [ -z "$changed" ]; then
            log_info "No documentation changes detected"
            exit 0
        fi

        while IFS= read -r doc; do
            docs_to_sync+=("$doc")
        done <<< "$changed"

    elif [ ${#docs_to_sync[@]} -eq 0 ]; then
        # Default: sync priority documents
        docs_to_sync=(
            "docs/INFRA.md"
            "docs/ARCHON.md"
            "docs/WORKFLOWS.md"
            "docs/RULES.md"
            "CLAUDE.md"
        )
    fi

    log_info "Documents to sync: ${#docs_to_sync[@]}"
    echo ""

    # Start HTTP server
    start_http_server || exit 1

    # Sync each document
    local synced=0
    local failed=0

    for doc in "${docs_to_sync[@]}"; do
        if sync_document "$doc"; then
            ((synced++))
        else
            ((failed++))
        fi
        echo ""
    done

    # Stop HTTP server
    stop_http_server

    # Summary
    log_info "=== Sync Complete ==="
    log_info "✅ Synced: $synced"
    if [ $failed -gt 0 ]; then
        log_error "❌ Failed: $failed"
    fi

    echo ""
    log_info "Next steps:"
    log_info "1. Use MCP tools in Claude Code to complete sync"
    log_info "2. Verify: mcp__archon__rag_search_knowledge_base(query=\"test\")"
    log_info "3. Check Archon UI: http://192.168.0.183:3737"
}

# Cleanup on exit
trap 'stop_http_server' EXIT

# Run main
main "$@"
