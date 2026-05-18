#!/bin/bash
# Docker Cleanup Script
# Remove unused Docker resources including images, containers, volumes, and networks
#
# Usage:
#   ./docker-cleanup.sh containers
#   ./docker-cleanup.sh images
#   ./docker-cleanup.sh volumes
#   ./docker-cleanup.sh networks
#   ./docker-cleanup.sh all
#   ./docker-cleanup.sh system

set -euo pipefail

# Configuration
DRY_RUN="${DRY_RUN:-false}"
KEEP_LAST_N="${KEEP_LAST_N:-3}"
KEEP_DAYS="${KEEP_DAYS:-7}"
MIN_DISK_FREE="${MIN_DISK_FREE:-20}"  # Minimum free disk space percentage

# Colors for output
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_dry() {
    echo -e "${CYAN}[DRY RUN]${NC} $1"
}

# Execute or dry run
execute() {
    local cmd="$1"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_dry "Would execute: $cmd"
    else
        eval "$cmd"
    fi
}

# Check disk space
check_disk_space() {
    local disk_used
    disk_used=$(df -h /var/lib/docker | tail -1 | awk '{print $5}' | sed 's/%//')

    log_info "Docker disk usage: ${disk_used}%"

    local disk_free=$((100 - disk_used))

    if [[ $disk_free -lt $MIN_DISK_FREE ]]; then
        log_warning "Disk space is below ${MIN_DISK_FREE}% free (${disk_free}% free, ${disk_used}% used)"
        return 1
    fi

    log_success "Disk space is OK (${disk_free}% free)"
    return 0
}

# Show disk usage
show_disk_usage() {
    log_info "Docker disk usage summary:"

    docker system df

    echo ""
    log_info "Detailed volume usage:"
    docker system df -v | grep -A 100 "VOLUME NAME"
}

# Stop and remove exited containers
cleanup_containers() {
    log_info "Cleaning up containers..."

    local exited_containers
    exited_containers=$(docker ps -a -f status=exited -q)

    if [[ -n "$exited_containers" ]]; then
        log_info "Found $(echo "$exited_containers" | wc -w) exited containers"

        for container in $exited_containers; do
            local container_name
            container_name=$(docker inspect --format='{{.Name}}' "$container" | sed 's/\///')
            execute "docker rm $container"
            log_info "Removed container: $container_name"
        done

        log_success "Exited containers removed"
    else
        log_info "No exited containers found"
    fi
}

# Remove dangling images
cleanup_dangling_images() {
    log_info "Cleaning up dangling images..."

    local dangling_images
    dangling_images=$(docker images -f dangling=true -q)

    if [[ -n "$dangling_images" ]]; then
        log_info "Found $(echo "$dangling_images" | wc -w) dangling images"

        execute "docker rmi $dangling_images"

        log_success "Dangling images removed"
    else
        log_info "No dangling images found"
    fi
}

# Remove old images (keep last N)
cleanup_old_images() {
    log_info "Cleaning up old images (keeping last $KEEP_LAST_N)..."

    # Get all image IDs
    local all_images
    all_images=$(docker images --format "{{.ID}}")

    # Remove images beyond the last N
    local images_to_remove=0
    local total_images
    total_images=$(echo "$all_images" | wc -w)

    if [[ $total_images -gt $KEEP_LAST_N ]]; then
        images_to_remove=$((total_images - KEEP_LAST_N))
        log_info "Found $total_images images, removing $images_to_remove old images"

        # Get images sorted by creation date (oldest first)
        local old_images
        old_images=$(docker images --format "{{.ID}} {{.CreatedAt}}" | sort -k2 -k1n | head -n "$images_to_remove" | awk '{print $1}')

        for image in $old_images; do
            # Check if image is used by any container
            local is_used
            is_used=$(docker ps -a -q -f ancestor="$image")

            if [[ -z "$is_used" ]]; then
                execute "docker rmi $image"
                log_info "Removed old image: $image"
            fi
        done

        log_success "Old images removed"
    else
        log_info "Total images ($total_images) is below keep threshold ($KEEP_LAST_N)"
    fi
}

# Remove unused images
cleanup_unused_images() {
    log_info "Removing unused images..."

    execute "docker image prune -a -f"

    log_success "Unused images removed"
}

# Remove unused volumes
cleanup_volumes() {
    log_info "Cleaning up volumes..."

    # List volumes and their sizes
    log_info "Current volumes:"
    docker volume ls --format "table {{.Name}}\t{{.Driver}}"

    echo ""

    # Remove unused volumes
    local unused_volumes
    unused_volumes=$(docker volume ls -f dangling=true -q)

    if [[ -n "$unused_volumes" ]]; then
        log_warning "Found $(echo "$unused_volumes" | wc -w) unused volumes"
        log_warning "WARNING: This will delete all data in these volumes!"

        if [[ "$DRY_RUN" == "false" ]]; then
            read -p "Continue? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                execute "docker volume prune -f"
                log_success "Unused volumes removed"
            else
                log_info "Volume cleanup cancelled"
            fi
        else
            execute "docker volume prune -f"
        fi
    else
        log_info "No unused volumes found"
    fi
}

# Remove old volumes (older than N days)
cleanup_old_volumes() {
    log_info "Cleaning up volumes older than $KEEP_DAYS days..."

    # Note: Docker doesn't track volume creation date by default
    # This is a best-effort approach using mount point timestamps

    local volumes
    volumes=$(docker volume ls -q)

    for volume in $volumes; do
        local mount_point
        mount_point=$(docker volume inspect "$volume" --format '{{.Mountpoint}}')

        if [[ -d "$mount_point" ]]; then
            local volume_age
            volume_age=$(find "$mount_point" -maxdepth 0 -mtime +$KEEP_DAYS 2>/dev/null)

            if [[ -n "$volume_age" ]]; then
                log_info "Volume $volume is older than $KEEP_DAYS days"
            fi
        fi
    done

    log_warning "Volume age detection is limited. Manual review recommended."
}

# Remove unused networks
cleanup_networks() {
    log_info "Cleaning up networks..."

    local unused_networks
    unused_networks=$(docker network ls -f dangling=true -q)

    if [[ -n "$unused_networks" ]]; then
        log_info "Found $(echo "$unused_networks" | wc -w) unused networks"

        execute "docker network prune -f"

        log_success "Unused networks removed"
    else
        log_info "No unused networks found"
    fi
}

# Clean build cache
cleanup_build_cache() {
    log_info "Cleaning up build cache..."

    execute "docker builder prune -f"

    log_success "Build cache cleaned"
}

# Full system cleanup
cleanup_system() {
    log_info "Running full system cleanup..."

    execute "docker system prune -a -f --volumes"

    log_success "System cleanup complete"
}

# Aggressive cleanup (remove everything)
cleanup_aggressive() {
    log_warning "Running aggressive cleanup..."
    log_warning "This will remove ALL unused data including:"
    log_warning "  - Stopped containers"
    log_warning "  - Unused networks"
    log_warning "  - Dangling images"
    log_warning "  - Unused images"
    log_warning "  - Unused volumes (WARNING: data loss!)"

    if [[ "$DRY_RUN" == "false" ]]; then
        read -p "Continue? (yes/NO): " -r
        echo
        if [[ $REPLY == "yes" ]]; then
            cleanup_containers
            cleanup_dangling_images
            cleanup_unused_images
            cleanup_volumes
            cleanup_networks
            cleanup_build_cache
            log_success "Aggressive cleanup complete"
        else
            log_info "Aggressive cleanup cancelled"
        fi
    else
        execute "docker system prune -a -f --volumes"
    fi
}

# Cleanup by label (remove containers with specific label)
cleanup_by_label() {
    local label="$1"

    log_info "Cleaning up containers with label: $label"

    local containers
    containers=$(docker ps -a -f "label=$label" -q)

    if [[ -n "$containers" ]]; then
        log_info "Found $(echo "$containers" | wc -w) containers with label $label"

        for container in $containers; do
            local container_name
            container_name=$(docker inspect --format='{{.Name}}' "$container" | sed 's/\///')
            execute "docker rm -f $container"
            log_info "Removed container: $container_name"
        done

        log_success "Containers with label $label removed"
    else
        log_info "No containers found with label $label"
    fi
}

# Show cleanup statistics
show_stats() {
    log_info "Docker resource statistics:"

    echo ""
    echo "Containers:"
    local total_containers
    total_containers=$(docker ps -a -q | wc -l)
    local running_containers
    running_containers=$(docker ps -q | wc -l)
    local stopped_containers
    stopped_containers=$((total_containers - running_containers))
    echo "  Total: $total_containers"
    echo "  Running: $running_containers"
    echo "  Stopped: $stopped_containers"

    echo ""
    echo "Images:"
    local total_images
    total_images=$(docker images -q | wc -l)
    local dangling_images
    dangling_images=$(docker images -f dangling=true -q | wc -l)
    echo "  Total: $total_images"
    echo "  Dangling: $dangling_images"

    echo ""
    echo "Volumes:"
    local total_volumes
    total_volumes=$(docker volume ls -q | wc -l)
    local unused_volumes
    unused_volumes=$(docker volume ls -f dangling=true -q | wc -l)
    echo "  Total: $total_volumes"
    echo "  Unused: $unused_volumes"

    echo ""
    echo "Networks:"
    local total_networks
    total_networks=$(docker network ls -q | wc -l)
    echo "  Total: $total_networks"

    show_disk_usage
}

# Schedule automatic cleanup
schedule_cleanup() {
    local cron_expr="${1:-0 3 * * *}"  # Default: Daily at 3 AM

    log_info "Scheduling automatic cleanup with cron: $cron_expr"

    local script_path
    script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

    # Create cron job
    local cron_cmd="$cron_expr $script_path system >> /var/log/docker-cleanup.log 2>&1"

    (crontab -l 2>/dev/null | grep -v "$script_path"; echo "$cron_cmd") | crontab -

    log_success "Cron job added. Current crontab:"
    crontab -l
}

# Display usage
usage() {
    cat << EOF
Docker Cleanup Script

Usage:
  $0 containers               Remove exited containers
  $0 images                   Remove dangling images
  $0 old-images               Remove old images (keep last N)
  $0 unused-images            Remove all unused images
  $0 volumes                  Remove unused volumes
  $0 networks                 Remove unused networks
  $0 cache                    Clean build cache
  $0 system                   Full system cleanup (unsafe volumes)
  $0 all                      Run all safe cleanups
  $0 aggressive               Remove everything (prompts required)
  $0 label <label-key>        Remove containers with specific label
  $0 stats                    Show resource statistics
  $0 schedule [cron-expression] Schedule automatic cleanup
  $0 disk                     Check disk space

Options:
  DRY_RUN=true                Show what would be deleted without deleting
  KEEP_LAST_N=3               Number of images to keep (default: 3)
  KEEP_DAYS=7                 Days threshold for old resources (default: 7)

Examples:
  $0 containers
  $0 images
  $0 all
  $0 aggressive
  DRY_RUN=true $0 all
  $0 schedule "0 3 * * *"    # Daily at 3 AM
  $0 label "com.docker.compose.project=old_project"

Environment Variables:
  DRY_RUN                     Preview deletions without executing (default: false)
  KEEP_LAST_N                 Keep last N images (default: 3)
  KEEP_DAYS                   Age threshold in days (default: 7)
  MIN_DISK_FREE               Minimum free disk % before cleanup (default: 20)
EOF
}

# Main
case "${1:-}" in
    containers)
        check_disk_space
        cleanup_containers
        show_disk_usage
        ;;
    images)
        check_disk_space
        cleanup_dangling_images
        show_disk_usage
        ;;
    old-images)
        check_disk_space
        cleanup_old_images
        show_disk_usage
        ;;
    unused-images)
        check_disk_space
        cleanup_unused_images
        show_disk_usage
        ;;
    volumes)
        check_disk_space
        cleanup_volumes
        show_disk_usage
        ;;
    networks)
        cleanup_networks
        ;;
    cache)
        cleanup_build_cache
        ;;
    system)
        check_disk_space
        cleanup_system
        show_disk_usage
        ;;
    all)
        check_disk_space
        cleanup_containers
        cleanup_dangling_images
        cleanup_networks
        cleanup_build_cache
        show_disk_usage
        log_success "All safe cleanups completed"
        ;;
    aggressive)
        check_disk_space
        cleanup_aggressive
        show_disk_usage
        ;;
    label)
        cleanup_by_label "$2"
        ;;
    stats)
        show_stats
        ;;
    schedule)
        schedule_cleanup "${2:-0 3 * * *}"
        ;;
    disk)
        check_disk_space
        show_disk_usage
        ;;
    *)
        usage
        exit 1
        ;;
esac
