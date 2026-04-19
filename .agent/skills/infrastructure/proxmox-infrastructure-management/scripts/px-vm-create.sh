#!/bin/bash
# Proxmox VM Creation Script
# Creates VM with optimal settings for AGL infrastructure
# Usage: ./px-vm-create.sh <vmid> <name> <cores> <memory> <disk> [ip] [gw]

set -euo pipefail

# Configuration
PROXMOX_HOST="${PROXMOX_HOST:-192.168.0.245}"
PROXMOX_API_HOST="${PROXMOX_API_HOST:-root@pam}"
TEMPLATE_STORAGE="${TEMPLATE_STORAGE:-local}"
VM_STORAGE="${VM_STORAGE:-local-lvm}"
BRIDGE="${BRIDGE:-vmbr0}"
SSH_KEY="${SSH_KEY:-/root/.ssh/authorized_keys}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

validate_inputs() {
    local vmid="$1"
    local name="$2"
    local cores="$3"
    local memory="$4"
    local disk="$5"

    if [[ ! "$vmid" =~ ^[0-9]+$ ]]; then
        log_error "VMID must be a number"
        exit 1
    fi

    if [[ ! "$cores" =~ ^[0-9]+$ ]] || [ "$cores" -lt 1 ] || [ "$cores" -gt 16 ]; then
        log_error "Cores must be between 1 and 16"
        exit 1
    fi

    if [[ ! "$memory" =~ ^[0-9]+$ ]] || [ "$memory" -lt 512 ]; then
        log_error "Memory must be at least 512 MB"
        exit 1
    fi

    if [[ ! "$disk" =~ ^[0-9]+$ ]] || [ "$disk" -lt 8 ]; then
        log_error "Disk must be at least 8 GB"
        exit 1
    fi

    # Check if VMID already exists
    if qm config "$vmid" &>/dev/null; then
        log_error "VMID $vmid already exists"
        exit 1
    fi
}

create_vm() {
    local vmid="$1"
    local name="$2"
    local cores="$3"
    local memory="$4"
    local disk="$5"
    local ip="${6:-dhcp}"
    local gw="${7:-}"

    log_info "Creating VM $name (ID: $vmid)"

    # Create VM with optimal settings
    qm create "$vmid" \
        --name "$name" \
        --memory "$memory" \
        --cores "$cores" \
        --cpu host \
        --numa 1 \
        --net0 "virtio,bridge=$BRIDGE,firewall=1" \
        --scsihw "virtio-scsi-pci" \
        --scsi0 "$VM_STORAGE:$disk,ssd=1,iothread=1" \
        --ostype l26 \
        --agent 1 \
        --bios ovmf \
        --machine q35 \
        --onboot 1

    log_info "VM created successfully"

    # Configure cloud-init if IP provided
    if [[ "$ip" != "dhcp" ]]; then
        log_info "Configuring cloud-init with static IP: $ip"

        # Add cloud-init drive
        qm set "$vmid" \
            --ide2 "$TEMPLATE_STORAGE:cloudinit" \
            --boot order=scsi0 \
            --ipconfig0 "ip=$ip,gw=$gw"

        # Add SSH keys if available
        if [[ -f "$SSH_KEY" ]]; then
            log_info "Adding SSH keys"
            qm set "$vmid" --sshkey "$SSH_KEY"
        fi

        # Set DNS
        qm set "$vmid" --nameserver "192.168.1.1,8.8.8.8"
    else
        log_info "Configuring DHCP network"
        qm set "$vmid" --ipconfig0 ip=dhcp
    fi

    log_info "VM configuration complete"
    log_info "Start VM with: qm start $vmid"
    log_info "Console: qm terminal $vmid"
}

print_usage() {
    cat << EOF
Usage: $0 <vmid> <name> <cores> <memory> <disk> [ip] [gw]

Arguments:
  vmid        VM ID number (100-999999)
  name        VM hostname/label
  cores       Number of CPU cores (1-16)
  memory      Memory in MB (min 512)
  disk        Disk size in GB (min 8)
  ip          IP address (optional, default: dhcp)
  gw          Gateway IP (required if ip is set)

Environment Variables:
  PROXMOX_HOST       Proxmox host IP
  VM_STORAGE         Storage backend (default: local-lvm)
  BRIDGE             Network bridge (default: vmbr0)
  SSH_KEY            Path to SSH public key

Examples:
  # Create VM with DHCP
  $0 200 webserver 2 4096 32

  # Create VM with static IP
  $0 201 database 4 8192 64 192.168.1.50 192.168.1.1

  # Create minimal VM
  $0 202 test-vm 1 2048 16
EOF
}

main() {
    if [ "$#" -lt 5 ]; then
        print_usage
        exit 1
    fi

    validate_inputs "$@"

    log_info "Starting VM creation..."
    log_info "VMID: $1"
    log_info "Name: $2"
    log_info "Cores: $3"
    log_info "Memory: ${4}MB"
    log_info "Disk: ${5}GB"

    create_vm "$@"

    log_info "VM creation completed successfully"
}

main "$@"
