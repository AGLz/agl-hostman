#!/bin/bash
# GPU Configuration Migration Script for AGLSRV1 Containers
# Based on successful CT200 (ollama-gpu) configuration
# Version: 1.0
# Date: 2025-10-27

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
HOST="192.168.0.245"
LOG_FILE="/var/log/gpu-migration-$(date +%Y%m%d-%H%M%S).log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a ${LOG_FILE}
}

error_exit() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    log "ERROR: $1"
    exit 1
}

# CT200 reference configuration (working)
CT200_GPU_CONFIG='# NVIDIA GPU Configuration (CT200 Reference)
lxc.cgroup2.devices.allow: c 195:* rwm
lxc.cgroup2.devices.allow: c 509:* rwm
lxc.cgroup2.devices.allow: c 226:* rwm
lxc.cgroup2.devices.allow: c 234:* rwm
lxc.cgroup2.devices.allow: c 10:200 rwm

# NVIDIA device bind mounts
lxc.mount.entry: /dev/nvidia0 dev/nvidia0 none bind,optional,create=file
lxc.mount.entry: /dev/nvidiactl dev/nvidiactl none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-uvm dev/nvidia-uvm none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-uvm-tools dev/nvidia-uvm-tools none bind,optional,create=file
lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir
lxc.mount.entry: /dev/nvidia-caps dev/nvidia-caps none bind,optional,create=dir
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file'

# Function to backup CT config
backup_config() {
    local CT_ID=$1
    local BACKUP_DIR="/etc/pve/lxc/backups"

    log "Creating backup of CT${CT_ID} configuration..."
    ssh root@${HOST} "mkdir -p ${BACKUP_DIR}"
    ssh root@${HOST} "cp /etc/pve/lxc/${CT_ID}.conf ${BACKUP_DIR}/${CT_ID}.conf.$(date +%Y%m%d-%H%M%S).bak"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Backup created successfully${NC}"
        log "Backup created: ${BACKUP_DIR}/${CT_ID}.conf.$(date +%Y%m%d-%H%M%S).bak"
    else
        error_exit "Failed to create backup for CT${CT_ID}"
    fi
}

# Function to update CT features
update_features() {
    local CT_ID=$1

    log "Updating features for CT${CT_ID}..."

    # Read current features
    CURRENT_FEATURES=$(ssh root@${HOST} "grep '^features:' /etc/pve/lxc/${CT_ID}.conf" || echo "")

    if [[ $CURRENT_FEATURES == *"keyctl=1"* ]]; then
        echo -e "${BLUE}ℹ keyctl=1 already present${NC}"
    else
        echo -e "${YELLOW}⚠ Adding keyctl=1 to features${NC}"

        if [[ -n "$CURRENT_FEATURES" ]]; then
            # Update existing features line
            ssh root@${HOST} "sed -i 's/^features: .*/&,keyctl=1/' /etc/pve/lxc/${CT_ID}.conf"
        else
            # Add features line after arch
            ssh root@${HOST} "sed -i '/^arch:/a features: nesting=1,keyctl=1' /etc/pve/lxc/${CT_ID}.conf"
        fi

        log "Added keyctl=1 to features"
        echo -e "${GREEN}✓ Features updated${NC}"
    fi
}

# Function to remove old GPU config
remove_old_gpu_config() {
    local CT_ID=$1

    log "Removing old GPU configuration from CT${CT_ID}..."

    ssh root@${HOST} "sed -i '/lxc.cgroup2.devices.allow.*195/d' /etc/pve/lxc/${CT_ID}.conf"
    ssh root@${HOST} "sed -i '/lxc.cgroup2.devices.allow.*234/d' /etc/pve/lxc/${CT_ID}.conf"
    ssh root@${HOST} "sed -i '/lxc.cgroup2.devices.allow.*236/d' /etc/pve/lxc/${CT_ID}.conf"
    ssh root@${HOST} "sed -i '/lxc.cgroup2.devices.allow.*509/d' /etc/pve/lxc/${CT_ID}.conf"
    ssh root@${HOST} "sed -i '/lxc.cgroup2.devices.allow.*226/d' /etc/pve/lxc/${CT_ID}.conf"
    ssh root@${HOST} "sed -i '/lxc.cgroup2.devices.allow.*10:200/d' /etc/pve/lxc/${CT_ID}.conf"
    ssh root@${HOST} "sed -i '/lxc.mount.entry:.*nvidia/d' /etc/pve/lxc/${CT_ID}.conf"
    ssh root@${HOST} "sed -i '/lxc.mount.entry:.*dri/d' /etc/pve/lxc/${CT_ID}.conf"
    ssh root@${HOST} "sed -i '/lxc.mount.entry:.*vfio/d' /etc/pve/lxc/${CT_ID}.conf"
    ssh root@${HOST} "sed -i '/lxc.mount.entry:.*tun/d' /etc/pve/lxc/${CT_ID}.conf"
    ssh root@${HOST} "sed -i '/usr\/local\/nvidia/d' /etc/pve/lxc/${CT_ID}.conf"
    ssh root@${HOST} "sed -i '/lxc.cap.drop:/d' /etc/pve/lxc/${CT_ID}.conf"
    ssh root@${HOST} "sed -i '/lxc.cgroup2.devices.allow: a$/d' /etc/pve/lxc/${CT_ID}.conf"

    echo -e "${GREEN}✓ Old GPU config removed${NC}"
    log "Old GPU configuration removed from CT${CT_ID}"
}

# Function to add new GPU config
add_new_gpu_config() {
    local CT_ID=$1

    log "Adding new GPU configuration to CT${CT_ID}..."

    # Add GPU config at the end of the file
    ssh root@${HOST} "cat >> /etc/pve/lxc/${CT_ID}.conf << 'EOF'

# NVIDIA GPU Configuration (migrated $(date +%Y-%m-%d))
lxc.cgroup2.devices.allow: c 195:* rwm
lxc.cgroup2.devices.allow: c 509:* rwm
lxc.cgroup2.devices.allow: c 226:* rwm
lxc.cgroup2.devices.allow: c 234:* rwm
lxc.cgroup2.devices.allow: c 10:200 rwm

# NVIDIA device bind mounts
lxc.mount.entry: /dev/nvidia0 dev/nvidia0 none bind,optional,create=file
lxc.mount.entry: /dev/nvidiactl dev/nvidiactl none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-uvm dev/nvidia-uvm none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-uvm-tools dev/nvidia-uvm-tools none bind,optional,create=file
lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir
lxc.mount.entry: /dev/nvidia-caps dev/nvidia-caps none bind,optional,create=dir
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
EOF
"

    echo -e "${GREEN}✓ New GPU config added${NC}"
    log "New GPU configuration added to CT${CT_ID}"
}

# Function to restart container
restart_container() {
    local CT_ID=$1

    echo ""
    read -p "Restart CT${CT_ID} now to apply changes? (y/N): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Restarting CT${CT_ID}..."
        ssh root@${HOST} "pct stop ${CT_ID} && sleep 2 && pct start ${CT_ID}"

        echo -e "${GREEN}✓ CT${CT_ID} restarted${NC}"
        log "CT${CT_ID} restarted successfully"

        sleep 5
        return 0
    else
        echo -e "${YELLOW}⚠ Restart skipped - changes will apply on next start${NC}"
        log "Restart skipped for CT${CT_ID}"
        return 1
    fi
}

# Function to install NVIDIA drivers in container
install_nvidia_drivers() {
    local CT_ID=$1

    log "Installing NVIDIA drivers in CT${CT_ID}..."
    echo -e "${BLUE}Installing NVIDIA drivers (matching host version 550.127.05)...${NC}"

    # Check if container is running
    STATUS=$(ssh root@${HOST} "pct status ${CT_ID}" | grep -oP 'status: \K\w+')

    if [[ "$STATUS" != "running" ]]; then
        echo -e "${YELLOW}⚠ CT${CT_ID} is not running, skipping driver installation${NC}"
        log "CT${CT_ID} not running, skipped driver installation"
        return 1
    fi

    # Install drivers
    ssh root@${HOST} "pct exec ${CT_ID} -- bash -c '
apt-get update -qq
apt-get install -y --allow-downgrades nvidia-utils-550=550.127.05-0ubuntu1 libnvidia-compute-550:amd64=550.127.05-0ubuntu1 2>&1 | grep -v \"^Get:\"
ldconfig
'"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ NVIDIA drivers installed${NC}"
        log "NVIDIA drivers installed in CT${CT_ID}"
        return 0
    else
        echo -e "${RED}✗ Failed to install drivers${NC}"
        log "ERROR: Failed to install drivers in CT${CT_ID}"
        return 1
    fi
}

# Function to test nvidia-smi
test_nvidia_smi() {
    local CT_ID=$1

    log "Testing nvidia-smi in CT${CT_ID}..."
    echo -e "${BLUE}Testing nvidia-smi...${NC}"

    # Check if container is running
    STATUS=$(ssh root@${HOST} "pct status ${CT_ID}" | grep -oP 'status: \K\w+')

    if [[ "$STATUS" != "running" ]]; then
        echo -e "${YELLOW}⚠ CT${CT_ID} is not running, cannot test${NC}"
        return 1
    fi

    # Test nvidia-smi
    RESULT=$(ssh root@${HOST} "pct exec ${CT_ID} -- nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null" || echo "FAILED")

    if [[ "$RESULT" != "FAILED" ]]; then
        echo -e "${GREEN}✓ nvidia-smi working!${NC}"
        echo -e "${GREEN}  GPU: $RESULT${NC}"
        log "nvidia-smi working in CT${CT_ID}: $RESULT"
        return 0
    else
        echo -e "${RED}✗ nvidia-smi failed${NC}"
        log "ERROR: nvidia-smi failed in CT${CT_ID}"
        return 1
    fi
}

# Function to migrate a single container
migrate_container() {
    local CT_ID=$1
    local CT_NAME=$2

    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Migrating CT${CT_ID} (${CT_NAME})${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo ""

    # Step 1: Backup
    backup_config ${CT_ID}

    # Step 2: Update features
    update_features ${CT_ID}

    # Step 3: Remove old GPU config
    remove_old_gpu_config ${CT_ID}

    # Step 4: Add new GPU config
    add_new_gpu_config ${CT_ID}

    # Step 5: Restart container
    if restart_container ${CT_ID}; then
        # Step 6: Install drivers
        install_nvidia_drivers ${CT_ID}

        # Step 7: Test nvidia-smi
        test_nvidia_smi ${CT_ID}
    fi

    echo ""
    echo -e "${GREEN}✓ Migration completed for CT${CT_ID}${NC}"
    log "Migration completed for CT${CT_ID}"
}

# Main menu
show_menu() {
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  GPU Configuration Migration Tool${NC}"
    echo -e "${GREEN}  Based on CT200 (ollama-gpu) - Working Configuration${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Containers with GPU configuration:"
    echo "  1) CT179 - agldv03 (CRITICAL - dev container) - running"
    echo "  2) CT161 - gameserver - running"
    echo "  3) CT178 - aglfs1 - running"
    echo "  4) CT174 - agldv02 - stopped"
    echo "  5) CT181 - agldv4 - stopped"
    echo ""
    echo "  A) Migrate ALL running containers (179, 161, 178)"
    echo "  Q) Quit"
    echo ""
}

# Main execution
main() {
    log "GPU Migration Tool started"

    while true; do
        show_menu
        read -p "Select option: " choice

        case $choice in
            1)
                migrate_container 179 "agldv03"
                ;;
            2)
                migrate_container 161 "gameserver"
                ;;
            3)
                migrate_container 178 "aglfs1"
                ;;
            4)
                migrate_container 174 "agldv02"
                ;;
            5)
                migrate_container 181 "agldv4"
                ;;
            [Aa])
                echo -e "${YELLOW}Migrating all running containers...${NC}"
                migrate_container 179 "agldv03"
                migrate_container 161 "gameserver"
                migrate_container 178 "aglfs1"
                echo ""
                echo -e "${GREEN}✓ All migrations completed!${NC}"
                ;;
            [Qq])
                echo "Exiting..."
                log "GPU Migration Tool exited"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                ;;
        esac

        echo ""
        read -p "Press ENTER to continue..."
    done
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error_exit "This script must be run as root"
fi

# Run main
main
