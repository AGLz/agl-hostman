#!/bin/bash
# Harbor Registry Cleanup Script
# Removes old images based on retention policies and frees storage space
#
# Usage: ./harbor-cleanup.sh [options]
#   --project NAME              Project name (required)
#   --dry-run                   Show what would be deleted without deleting
#   --keep-tags N               Keep last N tags per repository (default: 10)
#   --older-than DAYS           Delete images older than N days (default: 90)
#   --keep-tags-pattern PATTERN Keep tags matching pattern (e.g., "prod-*", "v*")
#   --force                     Bypass confirmation prompt
#   --garbage-collect           Run garbage collection after cleanup
#   --harbor-host HOST          Harbor host (default: from env)
#   --username USER             Harbor username (default: admin)
#   --password PASS             Harbor password (default: from env)

set -euo pipefail

# Configuration
HARBOR_HOST="${HARBOR_HOST:-harbor.local}"
HARBOR_USERNAME="${HARBOR_USERNAME:-admin}"
HARBOR_PASSWORD="${HARBOR_PASSWORD:-}"
PROJECT_NAME=""
DRY_RUN=false
KEEP_TAGS=10
OLDER_THAN_DAYS=90
KEEP_TAGS_PATTERN=""
FORCE=false
GARBAGE_COLLECT=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
fatal() { log_error "$1"; exit 1; }

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --project) PROJECT_NAME="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --keep-tags) KEEP_TAGS="$2"; shift 2 ;;
        --older-than) OLDER_THAN_DAYS="$2"; shift 2 ;;
        --keep-tags-pattern) KEEP_TAGS_PATTERN="$2"; shift 2 ;;
        --force) FORCE=true; shift ;;
        --garbage-collect) GARBAGE_COLLECT=true; shift ;;
        --harbor-host) HARBOR_HOST="$2"; shift 2 ;;
        --username) HARBOR_USERNAME="$2"; shift 2 ;;
        --password) HARBOR_PASSWORD="$2"; shift 2 ;;
        *) fatal "Unknown option: $1" ;;
    esac
done

# Validation
[[ -z "$PROJECT_NAME" ]] && fatal "Project name required (--project)"
[[ -z "$HARBOR_PASSWORD" ]] && fatal "Harbor password required (set HARBOR_PASSWORD or --password)"

log_info "Harbor registry cleanup for project: ${PROJECT_NAME}"
echo ""
echo "Cleanup Configuration:"
echo "  Keep last ${KEEP_TAGS} tags per repository"
echo "  Delete images older than ${OLDER_THAN_DAYS} days"
[[ -n "$KEEP_TAGS_PATTERN" ]] && echo "  Keep tags matching: ${KEEP_TAGS_PATTERN}"
[[ "$DRY_RUN" == true ]] && echo "  DRY RUN MODE - No actual deletions"
echo ""

# Get project ID
PROJECT_ID=$(curl -sk -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" \
    "https://${HARBOR_HOST}/api/v2.0/projects?name=${PROJECT_NAME}" | \
    jq -r '.[0].project_id // empty')

if [[ -z "$PROJECT_ID" ]]; then
    fatal "Project '${PROJECT_NAME}' not found"
fi

# Get repositories
log_info "Fetching repositories..."

REPOSITORIES=($(curl -sk -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" \
    "https://${HARBOR_HOST}/api/v2.0/projects/${PROJECT_ID}/repositories" | \
    jq -r '.[].name'))

if [[ ${#REPOSITORIES[@]} -eq 0 ]]; then
    log_warn "No repositories found in project ${PROJECT_NAME}"
    exit 0
fi

log_info "Found ${#REPOSITORIES[@]} repository(ies)"

# Calculate cutoff date
CUTOFF_DATE=$(date -d "${OLDER_THAN_DAYS} days ago" +%s)

# Track images to delete
declare -a IMAGES_TO_DELETE=()
declare -a IMAGES_TO_KEEP=()
TOTAL_SIZE_TO_DELETE=0

# Process each repository
for REPO in "${REPOSITORIES[@]}"; do
    REPO_NAME="${REPO##*/}"
    log_info "Processing repository: ${REPO_NAME}"

    # Get all artifacts
    ARTIFACTS=$(curl -sk -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" \
        "https://${HARBOR_HOST}/api/v2.0/projects/${PROJECT_ID}/repositories/${REPO}/artifacts?with_tag=true&sort=push_time")

    # Sort by push_time (newest first)
    ARTIFACTS=$(echo "$ARTIFACTS" | jq 'sort_by(.push_time) | reverse')

    # Count and filter artifacts
    ARTIFACT_COUNT=$(echo "$ARTIFACTS" | jq 'length')

    if [[ $ARTIFACT_COUNT -eq 0 ]]; then
        log_warn "No artifacts found for ${REPO_NAME}"
        continue
    fi

    log_info "Found ${ARTIFACT_COUNT} artifact(s) in ${REPO_NAME}"

    # Process each artifact
    INDEX=0
    echo "$ARTIFACTS" | jq -c '.[]' | while read -r ARTIFACT; do
        INDEX=$((INDEX + 1))

        DIGEST=$(echo "$ARTIFACT" | jq -r '.digest')
        TAG=$(echo "$ARTIFACT" | jq -r '.tags[0].name // "unknown"')
        PUSH_TIME=$(echo "$ARTIFACT" | jq -r '.push_time // "1970-01-01T00:00:00Z"')
        SIZE=$(echo "$ARTIFACT" | jq -r '.size // 0')

        # Convert push time to timestamp
        PUSH_TIMESTAMP=$(date -d "${PUSH_TIME}" +%s 2>/dev/null || echo 0)

        # Check if tag matches keep pattern
        KEEP_TAG=false
        if [[ -n "$KEEP_TAGS_PATTERN" ]]; then
            if [[ "$TAG" == $KEEP_TAGS_PATTERN ]]; then
                KEEP_TAG=true
            fi
        fi

        # Determine if we should keep this artifact
        SHOULD_DELETE=false

        if [[ "$KEEP_TAG" == true ]]; then
            # Keep tags matching pattern
            SHOULD_DELETE=false
        elif [[ $INDEX -le $KEEP_TAGS ]]; then
            # Keep last N tags
            SHOULD_DELETE=false
        elif [[ $PUSH_TIMESTAMP -lt $CUTOFF_DATE ]]; then
            # Delete if older than cutoff date
            SHOULD_DELETE=true
        elif [[ $INDEX -gt $KEEP_TAGS ]]; then
            # Delete if beyond keep count
            SHOULD_DELETE=true
        fi

        if [[ "$SHOULD_DELETE" == true ]]; then
            IMAGES_TO_DELETE+=("${REPO}:${TAG} (${DIGEST:0:12}) - Size: $(numfmt --to=iec-i --suffix=B $SIZE 2>/dev/null || echo "${SIZE}B")")
            TOTAL_SIZE_TO_DELETE=$((TOTAL_SIZE_TO_DELETE + SIZE))
        else
            IMAGES_TO_KEEP+=("${REPO}:${TAG}")
        fi
    done
done

# Summary
echo ""
echo "Cleanup Summary:"
echo "================"
echo "Total repositories: ${#REPOSITORIES[@]}"
echo "Images to keep: ${#IMAGES_TO_KEEP[@]}"
echo "Images to delete: ${#IMAGES_TO_DELETE[@]}"
echo "Space to be freed: $(numfmt --to=iec-i --suffix=B $TOTAL_SIZE_TO_DELETE 2>/dev/null || echo "${TOTAL_SIZE_TO_DELETE}B")"
echo ""

if [[ ${#IMAGES_TO_DELETE[@]} -eq 0 ]]; then
    log_info "No images to delete"
    exit 0
fi

# Show images to delete
echo "Images to be deleted:"
echo "======================"
for IMAGE in "${IMAGES_TO_DELETE[@]}"; do
    echo "  - ${IMAGE}"
done
echo ""

# Confirm deletion
if [[ "$FORCE" != true && "$DRY_RUN" != true ]]; then
    read -p "Are you sure you want to delete ${#IMAGES_TO_DELETE[@]} image(s)? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Cleanup cancelled"
        exit 0
    fi
fi

# Delete images
if [[ "$DRY_RUN" == true ]]; then
    log_info "DRY RUN - Would delete ${#IMAGES_TO_DELETE[@]} image(s)"
    exit 0
fi

log_info "Deleting ${#IMAGES_TO_DELETE[@]} image(s)..."

DELETED_COUNT=0
FAILED_COUNT=0

for REPO in "${REPOSITORIES[@]}"; do
    # Get artifacts again (in case something changed)
    ARTIFACTS=$(curl -sk -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" \
        "https://${HARBOR_HOST}/api/v2.0/projects/${PROJECT_ID}/repositories/${REPO}/artifacts?with_tag=true")

    echo "$ARTIFACTS" | jq -c '.[]' | while read -r ARTIFACT; do
        DIGEST=$(echo "$ARTIFACT" | jq -r '.digest')
        TAG=$(echo "$ARTIFACT" | jq -r '.tags[0].name // "unknown"')
        PUSH_TIME=$(echo "$ARTIFACT" | jq -r '.push_time // "1970-01-01T00:00:00Z"')
        PUSH_TIMESTAMP=$(date -d "${PUSH_TIME}" +%s 2>/dev/null || echo 0)

        # Check if this artifact should be deleted
        SHOULD_DELETE=false
        if [[ $PUSH_TIMESTAMP -lt $CUTOFF_DATE ]]; then
            SHOULD_DELETE=true
        fi

        if [[ "$SHOULD_DELETE" == true ]]; then
            log_info "Deleting ${REPO}:${TAG}..."

            DELETE_RESULT=$(curl -skX DELETE \
                "https://${HARBOR_HOST}/api/v2.0/projects/${PROJECT_ID}/repositories/${REPO}/artifacts/${DIGEST}" \
                -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" \
                -w "\n%{http_code}")

            HTTP_CODE=$(echo "$DELETE_RESULT" | tail -n1)

            if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "204" ]]; then
                DELETED_COUNT=$((DELETED_COUNT + 1))
            else
                log_error "Failed to delete ${REPO}:${TAG} (HTTP ${HTTP_CODE})"
                FAILED_COUNT=$((FAILED_COUNT + 1))
            fi
        fi
    done
done

log_info "Deleted ${DELETED_COUNT} image(s)"
[[ $FAILED_COUNT -gt 0 ]] && log_error "Failed to delete ${FAILED_COUNT} image(s)"

# Run garbage collection
if [[ "$GARBAGE_COLLECT" == true ]]; then
    log_info "Running garbage collection..."

    # Try to run garbage collection via API (Harbor 2.0+)
    GC_RESULT=$(curl -skX POST \
        "https://${HARBOR_HOST}/api/v2.0/system/gc/schedule" \
        -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" \
        -H "Content-Type: application/json" \
        -d '{
            "schedule": {
                "type": "Manual"
            },
            "delete_untagged": true
        }' 2>/dev/null)

    # If API fails, try direct docker exec
    if [[ -z "$GC_RESULT" ]]; then
        log_warn "API garbage collection not available, attempting direct execution..."

        # Try to find Harbor registry container
        REGISTRY_CONTAINER=$(docker ps --filter "name=registry" --format "{{.Names}}" | head -n1)

        if [[ -n "$REGISTRY_CONTAINER" ]]; then
            docker exec "$REGISTRY_CONTAINER" \
                bin/registry garbage-collect \
                /etc/registry/config.yml \
                --delete-untagged=true

            log_info "Garbage collection completed"
        else
            log_warn "Could not find registry container for garbage collection"
            log_info "You may need to run garbage collection manually"
        fi
    else
        log_info "Garbage collection scheduled"
    fi
fi

log_info "Cleanup completed!"
