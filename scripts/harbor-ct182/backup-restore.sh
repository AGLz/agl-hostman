#!/bin/bash
#
# Harbor Backup and Restore Script
# Comprehensive backup/restore for Harbor data, database, and configuration
#

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
CTID=182
HARBOR_DIR="/opt/harbor"
DATA_DIR="/var/harbor"
BACKUP_DIR="/var/backups/harbor"
BACKUP_RETENTION_DAYS=30
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Harbor Backup & Restore Script${NC}"
echo -e "${BLUE}========================================${NC}"

# Check if running on Proxmox host or container
if command -v pct &> /dev/null && pct status $CTID &> /dev/null; then
    RUN_PREFIX="pct exec $CTID --"
    echo -e "${GREEN}Running on CT$CTID from Proxmox host${NC}"
else
    RUN_PREFIX=""
    echo -e "${GREEN}Running directly on container${NC}"
fi

# Function to execute commands
run_cmd() {
    if [ -n "$RUN_PREFIX" ]; then
        $RUN_PREFIX bash -c "$1"
    else
        bash -c "$1"
    fi
}

# Display usage
usage() {
    echo -e "${YELLOW}Usage:${NC}"
    echo -e "  $0 backup          - Create full backup"
    echo -e "  $0 restore <file>  - Restore from backup"
    echo -e "  $0 list            - List available backups"
    echo -e "  $0 cleanup         - Remove old backups"
    exit 1
}

# Create backup
backup_harbor() {
    echo -e "${GREEN}Starting Harbor backup...${NC}"

    # Create backup directory
    echo -e "${YELLOW}Creating backup directory...${NC}"
    run_cmd "mkdir -p $BACKUP_DIR"

    BACKUP_FILE="$BACKUP_DIR/harbor-backup-$TIMESTAMP.tar.gz"

    # Stop Harbor (optional, for consistent backup)
    echo -e "${YELLOW}Stopping Harbor for consistent backup...${NC}"
    run_cmd "cd $HARBOR_DIR && docker-compose down"

    echo -e "${GREEN}Step 1: Backing up database...${NC}"
    run_cmd "cd $HARBOR_DIR && docker-compose up -d postgresql"
    sleep 5
    run_cmd "cd $HARBOR_DIR && docker-compose exec -T postgresql pg_dumpall -U postgres > $BACKUP_DIR/harbor-db-$TIMESTAMP.sql"
    run_cmd "cd $HARBOR_DIR && docker-compose down"

    echo -e "${GREEN}Step 2: Backing up configuration...${NC}"
    run_cmd "mkdir -p $BACKUP_DIR/config-$TIMESTAMP"
    run_cmd "cp -r $HARBOR_DIR/*.yml $BACKUP_DIR/config-$TIMESTAMP/ 2>/dev/null || true"
    run_cmd "cp -r $HARBOR_DIR/common $BACKUP_DIR/config-$TIMESTAMP/ 2>/dev/null || true"

    echo -e "${GREEN}Step 3: Backing up SSL certificates...${NC}"
    run_cmd "mkdir -p $BACKUP_DIR/ssl-$TIMESTAMP"
    run_cmd "cp -r $HARBOR_DIR/ssl/* $BACKUP_DIR/ssl-$TIMESTAMP/ 2>/dev/null || true"

    echo -e "${GREEN}Step 4: Backing up data volumes...${NC}"
    run_cmd "tar -czf $BACKUP_DIR/data-$TIMESTAMP.tar.gz -C $DATA_DIR ."

    echo -e "${GREEN}Step 5: Creating manifest...${NC}"
    cat > /tmp/backup-manifest.txt << EOF
Harbor Backup Manifest
=====================
Timestamp: $TIMESTAMP
Date: $(date)
Harbor Directory: $HARBOR_DIR
Data Directory: $DATA_DIR
Database: harbor-db-$TIMESTAMP.sql
Data: data-$TIMESTAMP.tar.gz
Configuration: config-$TIMESTAMP/
SSL: ssl-$TIMESTAMP/

Components:
- PostgreSQL Database
- Harbor Configuration
- SSL Certificates
- Registry Data
- Chart Museum Data
- Trivy Database
- Job Service Logs

Restore Command:
  $0 restore harbor-backup-$TIMESTAMP.tar.gz
EOF

    run_cmd "cat > $BACKUP_DIR/manifest-$TIMESTAMP.txt << 'EOFINNER'
Harbor Backup Manifest
=====================
Timestamp: $TIMESTAMP
Date: $(date)
Harbor Directory: $HARBOR_DIR
Data Directory: $DATA_DIR
Database: harbor-db-$TIMESTAMP.sql
Data: data-$TIMESTAMP.tar.gz
Configuration: config-$TIMESTAMP/
SSL: ssl-$TIMESTAMP/

Components:
- PostgreSQL Database
- Harbor Configuration
- SSL Certificates
- Registry Data
- Chart Museum Data
- Trivy Database
- Job Service Logs

Restore Command:
  $0 restore harbor-backup-$TIMESTAMP.tar.gz
EOFINNER"

    echo -e "${GREEN}Step 6: Creating compressed archive...${NC}"
    run_cmd "cd $BACKUP_DIR && tar -czf harbor-backup-$TIMESTAMP.tar.gz \
        harbor-db-$TIMESTAMP.sql \
        data-$TIMESTAMP.tar.gz \
        config-$TIMESTAMP/ \
        ssl-$TIMESTAMP/ \
        manifest-$TIMESTAMP.txt"

    echo -e "${GREEN}Step 7: Cleaning up temporary files...${NC}"
    run_cmd "cd $BACKUP_DIR && rm -rf \
        harbor-db-$TIMESTAMP.sql \
        data-$TIMESTAMP.tar.gz \
        config-$TIMESTAMP/ \
        ssl-$TIMESTAMP/ \
        manifest-$TIMESTAMP.txt"

    echo -e "${GREEN}Step 8: Restarting Harbor...${NC}"
    run_cmd "cd $HARBOR_DIR && docker-compose up -d"

    # Calculate backup size
    BACKUP_SIZE=$(run_cmd "du -h $BACKUP_FILE | cut -f1")

    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}Backup completed successfully!${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "Backup file: ${GREEN}$BACKUP_FILE${NC}"
    echo -e "Size: ${GREEN}$BACKUP_SIZE${NC}"
    echo -e "Timestamp: ${GREEN}$TIMESTAMP${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Restore backup
restore_harbor() {
    local BACKUP_FILE=$1

    if [ -z "$BACKUP_FILE" ]; then
        echo -e "${RED}ERROR: Backup file not specified${NC}"
        usage
    fi

    if ! run_cmd "test -f $BACKUP_FILE"; then
        echo -e "${RED}ERROR: Backup file not found: $BACKUP_FILE${NC}"
        exit 1
    fi

    echo -e "${RED}WARNING: This will overwrite current Harbor data!${NC}"
    read -p "Are you sure you want to continue? (yes/no): " -r
    if [[ ! $REPLY == "yes" ]]; then
        echo -e "${YELLOW}Restore cancelled${NC}"
        exit 0
    fi

    echo -e "${GREEN}Starting Harbor restore...${NC}"

    # Stop Harbor
    echo -e "${YELLOW}Stopping Harbor...${NC}"
    run_cmd "cd $HARBOR_DIR && docker-compose down -v"

    # Extract backup
    echo -e "${GREEN}Step 1: Extracting backup...${NC}"
    RESTORE_DIR="$BACKUP_DIR/restore-$(date +%Y%m%d_%H%M%S)"
    run_cmd "mkdir -p $RESTORE_DIR"
    run_cmd "tar -xzf $BACKUP_FILE -C $RESTORE_DIR"

    # Restore configuration
    echo -e "${GREEN}Step 2: Restoring configuration...${NC}"
    run_cmd "cp -r $RESTORE_DIR/config-*/* $HARBOR_DIR/"

    # Restore SSL certificates
    echo -e "${GREEN}Step 3: Restoring SSL certificates...${NC}"
    run_cmd "mkdir -p $HARBOR_DIR/ssl"
    run_cmd "cp -r $RESTORE_DIR/ssl-*/* $HARBOR_DIR/ssl/"

    # Restore data
    echo -e "${GREEN}Step 4: Restoring data volumes...${NC}"
    run_cmd "mkdir -p $DATA_DIR"
    run_cmd "tar -xzf $RESTORE_DIR/data-*.tar.gz -C $DATA_DIR"

    # Start Harbor with database only
    echo -e "${GREEN}Step 5: Starting PostgreSQL...${NC}"
    run_cmd "cd $HARBOR_DIR && docker-compose up -d postgresql"
    sleep 10

    # Restore database
    echo -e "${GREEN}Step 6: Restoring database...${NC}"
    run_cmd "cd $HARBOR_DIR && docker-compose exec -T postgresql psql -U postgres < $RESTORE_DIR/harbor-db-*.sql"

    # Start all Harbor services
    echo -e "${GREEN}Step 7: Starting all Harbor services...${NC}"
    run_cmd "cd $HARBOR_DIR && docker-compose down"
    run_cmd "cd $HARBOR_DIR && docker-compose up -d"

    # Cleanup
    echo -e "${GREEN}Step 8: Cleaning up...${NC}"
    run_cmd "rm -rf $RESTORE_DIR"

    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}Restore completed successfully!${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "Harbor should be available in a few minutes"
    echo -e "Check status: ${GREEN}docker-compose ps${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# List backups
list_backups() {
    echo -e "${GREEN}Available Harbor backups:${NC}"
    echo -e "${BLUE}========================================${NC}"

    if run_cmd "test -d $BACKUP_DIR"; then
        run_cmd "ls -lh $BACKUP_DIR/harbor-backup-*.tar.gz 2>/dev/null" || echo -e "${YELLOW}No backups found${NC}"
    else
        echo -e "${YELLOW}Backup directory does not exist${NC}"
    fi

    echo -e "${BLUE}========================================${NC}"
}

# Cleanup old backups
cleanup_backups() {
    echo -e "${GREEN}Cleaning up backups older than $BACKUP_RETENTION_DAYS days...${NC}"

    if run_cmd "test -d $BACKUP_DIR"; then
        run_cmd "find $BACKUP_DIR -name 'harbor-backup-*.tar.gz' -mtime +$BACKUP_RETENTION_DAYS -delete"
        echo -e "${GREEN}Cleanup complete${NC}"
        list_backups
    else
        echo -e "${YELLOW}Backup directory does not exist${NC}"
    fi
}

# Main script logic
case "${1:-}" in
    backup)
        backup_harbor
        ;;
    restore)
        restore_harbor "$2"
        ;;
    list)
        list_backups
        ;;
    cleanup)
        cleanup_backups
        ;;
    *)
        usage
        ;;
esac
