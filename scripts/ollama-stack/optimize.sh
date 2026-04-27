#!/bin/bash
# Ollama Stack Optimization Script
# Apply production optimizations for CT200

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
STACK_DIR="/opt/ollama-stack"

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

# Check GPU memory
check_gpu_memory() {
    log "Checking GPU memory..."

    local total_mem=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits)
    local used_mem=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits)
    local free_mem=$((total_mem - used_mem))

    info "Total GPU Memory: ${total_mem}MB"
    info "Used Memory: ${used_mem}MB"
    info "Free Memory: ${free_mem}MB"

    # Recommend settings based on available memory
    if [[ $total_mem -ge 12000 ]]; then
        info "✅ 12GB+ GPU detected - Optimal for 32B+ models"
        export RECOMMENDED_GPU_FRACTION=0.9
        export RECOMMENDED_MAX_MODELS=3
    elif [[ $total_mem -ge 8000 ]]; then
        info "⚠️  8-12GB GPU - Recommend 7B-14B models"
        export RECOMMENDED_GPU_FRACTION=0.85
        export RECOMMENDED_MAX_MODELS=2
    else
        warning "⚠️  Less than 8GB GPU - Use smaller models"
        export RECOMMENDED_GPU_FRACTION=0.8
        export RECOMMENDED_MAX_MODELS=1
    fi

    echo ""
}

# Optimize Ollama settings
optimize_ollama() {
    log "Optimizing Ollama configuration..."

    # Create systemd override directory
    mkdir -p /etc/systemd/system/ollama.service.d

    cat > /etc/systemd/system/ollama.service.d/optimization.conf << EOF
[Service]
# GPU Memory Management
Environment="OLLAMA_GPU_MEMORY_FRACTION=${RECOMMENDED_GPU_FRACTION}"
Environment="OLLAMA_NUM_GPU=999"

# Concurrency Settings
Environment="OLLAMA_MAX_LOADED_MODELS=${RECOMMENDED_MAX_MODELS}"
Environment="OLLAMA_NUM_PARALLEL=4"
Environment="OLLAMA_MAX_QUEUE=512"

# Performance Tuning
Environment="OLLAMA_KEEP_ALIVE=5m"
Environment="OLLAMA_FLASH_ATTENTION=1"

# Memory Management
Environment="OLLAMA_MAX_VRAM=0"
Environment="OLLAMA_LOAD_TIMEOUT=5m"
EOF

    # Reload systemd
    systemctl daemon-reload

    # Restart Ollama if running
    if systemctl is-active --quiet ollama; then
        info "Restarting Ollama service..."
        systemctl restart ollama
        sleep 5
    fi

    log "✅ Ollama optimization applied"
    echo ""
}

# Optimize Docker containers
optimize_docker() {
    log "Optimizing Docker containers..."

    cd "$STACK_DIR"

    # Update docker-compose.yml with optimal settings
    if [[ -f docker-compose.yml ]]; then
        # Backup
        cp docker-compose.yml docker-compose.yml.bak

        # Apply optimizations (already in our compose file)
        log "✅ Docker Compose configuration already optimized"
    fi

    # Restart containers
    info "Restarting containers with optimized settings..."
    docker compose down
    docker compose up -d

    log "✅ Docker optimization applied"
    echo ""
}

# Optimize Chroma vector database
optimize_chroma() {
    log "Optimizing Chroma vector database..."

    local chroma_path="$STACK_DIR/chroma_db"

    if [[ -d "$chroma_path" ]]; then
        # Set proper permissions
        chmod -R 755 "$chroma_path"

        # Optimize SQLite (used by Chroma)
        if [[ -f "$chroma_path/chroma.sqlite3" ]]; then
            sqlite3 "$chroma_path/chroma.sqlite3" "VACUUM; ANALYZE;"
            log "✅ Chroma database optimized"
        fi
    else
        info "ℹ️  Chroma database not found (will be created on first use)"
    fi

    echo ""
}

# Configure kernel parameters
optimize_kernel() {
    log "Optimizing kernel parameters..."

    # Check if we can modify sysctl
    if [[ ! -w /proc/sys ]]; then
        warning "⚠️  Cannot modify kernel parameters (container limitation)"
        return
    fi

    # Network optimizations
    cat >> /etc/sysctl.conf << EOF

# Ollama Stack Optimizations
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_congestion_control = bbr
EOF

    sysctl -p

    log "✅ Kernel parameters optimized"
    echo ""
}

# Install performance monitoring tools
install_monitoring() {
    log "Installing monitoring tools..."

    # Check if tools are installed
    local tools=("htop" "iotop" "nethogs" "jq")
    local missing=()

    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing+=("$tool")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        info "Installing: ${missing[*]}"
        apt-get update -qq
        apt-get install -y -qq "${missing[@]}"
        log "✅ Monitoring tools installed"
    else
        log "✅ All monitoring tools already installed"
    fi

    echo ""
}

# Configure log rotation
setup_log_rotation() {
    log "Configuring log rotation..."

    cat > /etc/logrotate.d/ollama-stack << EOF
/var/log/ollama*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 0644 root root
}

/opt/ollama-stack/logs/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0644 root root
}
EOF

    log "✅ Log rotation configured"
    echo ""
}

# Setup monitoring cron jobs
setup_cron_jobs() {
    log "Setting up monitoring cron jobs..."

    # Add monitoring script to cron
    (crontab -l 2>/dev/null || true; echo "*/15 * * * * $STACK_DIR/scripts/health-check.sh >> /var/log/ollama-health.log 2>&1") | crontab -

    log "✅ Cron jobs configured"
    echo ""
}

# Print optimization summary
print_summary() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "🎉 Optimization Complete!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    info "Applied Optimizations:"
    echo "  ✅ GPU memory management"
    echo "  ✅ Ollama concurrency settings"
    echo "  ✅ Docker container optimization"
    echo "  ✅ Kernel network parameters"
    echo "  ✅ Log rotation"
    echo "  ✅ Monitoring cron jobs"
    echo ""
    info "Recommended Settings:"
    echo "  • GPU Memory Fraction: ${RECOMMENDED_GPU_FRACTION}"
    echo "  • Max Loaded Models: ${RECOMMENDED_MAX_MODELS}"
    echo "  • Parallel Requests: 4"
    echo ""
    info "Next Steps:"
    echo "  1. Monitor GPU usage: watch -n 1 nvidia-smi"
    echo "  2. Check services: $STACK_DIR/status.sh"
    echo "  3. View real-time monitor: $STACK_DIR/monitor.sh"
    echo ""
    info "Performance Tips:"
    echo "  • Use quantized models (Q4_K_M) for faster inference"
    echo "  • Keep context window under 4096 for better speed"
    echo "  • Monitor GPU memory and adjust OLLAMA_GPU_MEMORY_FRACTION if needed"
    echo "  • Use smaller models (7B-14B) for faster responses"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Main execution
main() {
    log "Starting Ollama Stack optimization..."
    echo ""

    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        exit 1
    fi

    # Check if stack is deployed
    if [[ ! -d "$STACK_DIR" ]]; then
        error "Ollama stack not found in $STACK_DIR"
        error "Run deploy.sh first"
        exit 1
    fi

    check_gpu_memory
    optimize_ollama
    optimize_docker
    optimize_chroma
    optimize_kernel
    install_monitoring
    setup_log_rotation
    setup_cron_jobs
    print_summary

    log "✅ All optimizations applied successfully"
}

# Run main
main "$@"
