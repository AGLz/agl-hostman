#!/bin/bash
# Sync RuVector Embeddings: agldv03 (primary) -> fgsrv06 (replica)
# Usage: ./sync-ruvector.sh [--dry-run]

set -euo pipefail

# Configuration
SOURCE_HOST="agldv03"
SOURCE_IP="100.94.221.87"
TARGET_HOST="fgsrv06"
TARGET_IP="100.83.51.9"
DB_NAME="agl_ruvector"
DB_USER="admin"
DB_PASS="agl_ruvector_2026"
DB_PORT="5433"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="/var/log/ruvector-sync.log"
DRY_RUN="${1:-}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Create log directory if needed
sudo mkdir -p "$(dirname "$LOG_FILE")"
sudo touch "$LOG_FILE"
sudo chown "$USER:$USER" "$LOG_FILE"

log "Starting RuVector sync: $SOURCE_HOST -> $TARGET_HOST"

if [[ "$DRY_RUN" == "--dry-run" ]]; then
    log "DRY RUN MODE - no changes will be made"
fi

# Export from source (agldv03)
log "Exporting embeddings from $SOURCE_HOST..."
EXPORT_FILE="/tmp/ruvector_export_${TIMESTAMP}.sql"

pg_dump \
    -h localhost \
    -p "$DB_PORT" \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    -t ruvector_embeddings \
    --data-only \
    --column-inserts \
    > "$EXPORT_FILE" 2>/dev/null << EOF
$DB_PASS
EOF

if [[ ! -s "$EXPORT_FILE" ]]; then
    log "ERROR: Export file is empty or failed to create"
    exit 1
fi

log "Exported $(wc -l < "$EXPORT_FILE") lines"

# Transfer to target (fgsrv06)
log "Transferring to $TARGET_HOST..."
rsync -avz "$EXPORT_FILE" "${TARGET_IP}:${EXPORT_FILE}"

# Import on target
log "Importing on $TARGET_HOST..."
ssh "$TARGET_IP" << 'REMOTE_SCRIPT'
DB_NAME="agl_ruvector"
DB_USER="admin"
DB_PASS="agl_ruvector_2026"
DB_PORT="5433"
EXPORT_FILE="/tmp/ruvector_export_*.sql"

# Find the most recent export file
LATEST_EXPORT=$(ls -t $EXPORT_FILE 2>/dev/null | head -1)

if [[ -z "$LATEST_EXPORT" ]]; then
    echo "ERROR: No export file found"
    exit 1
fi

echo "Using export file: $LATEST_EXPORT"

# Clear existing data and import
PGPASSWORD="$DB_PASS" psql \
    -h localhost \
    -p "$DB_PORT" \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    << SQL
-- Temporarily disable triggers
SET session_replication_role = replica;

-- Clear existing data
TRUNCATE TABLE ruvector_embeddings CASCADE;

-- Import new data
\i $LATEST_EXPORT

-- Re-enable triggers
SET session_replication_role = DEFAULT;

-- Verify count
SELECT COUNT(*) as imported_count FROM ruvector_embeddings;
SQL

# Cleanup
rm -f "$LATEST_EXPORT"
echo "Import completed and cleanup done"
REMOTE_SCRIPT

# Cleanup source export
rm -f "$EXPORT_FILE"

log "Sync completed successfully"
