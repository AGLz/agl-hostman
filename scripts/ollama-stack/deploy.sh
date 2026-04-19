#!/bin/bash
# Ollama Stack Deployment Script for CT200
# Deploys complete AI infrastructure: Ollama + Open WebUI + LiteLLM

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
STACK_DIR="/opt/ollama-stack"
CONFIG_SOURCE="$(dirname "$(dirname "$(readlink -f "$0")")")/config/ollama-stack"
LOG_FILE="/var/log/ollama-stack-deployment.log"

# Functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1" | tee -a "$LOG_FILE"
}

check_requirements() {
    log "Checking requirements..."

    # Check if running on CT200
    if [[ ! -f /.dockerenv ]]; then
        error "This script should run inside CT200 container"
        exit 1
    fi

    # Check Docker
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed"
        exit 1
    fi

    # Check Docker Compose
    if ! command -v docker compose &> /dev/null; then
        error "Docker Compose is not installed"
        exit 1
    fi

    # Check NVIDIA GPU
    if ! command -v nvidia-smi &> /dev/null; then
        error "NVIDIA drivers not found"
        exit 1
    fi

    # Check NVIDIA Docker runtime
    if ! docker run --rm --gpus all nvidia/cuda:12.3.0-base-ubuntu22.04 nvidia-smi &> /dev/null; then
        error "NVIDIA Docker runtime not configured properly"
        exit 1
    fi

    # Check Ollama
    if ! command -v ollama &> /dev/null; then
        error "Ollama is not installed"
        exit 1
    fi

    log "✅ All requirements met"
}

create_directories() {
    log "Creating directory structure..."

    # Create main directory
    mkdir -p "$STACK_DIR"
    cd "$STACK_DIR"

    # Create data directories
    mkdir -p data/{ollama,open-webui,litellm}
    mkdir -p logs
    mkdir -p uploads
    mkdir -p models

    # Set permissions
    chmod -R 755 "$STACK_DIR"

    log "✅ Directories created"
}

copy_configuration() {
    log "Copying configuration files..."

    # Copy docker-compose.yml
    if [[ -f "$CONFIG_SOURCE/docker-compose.yml" ]]; then
        cp "$CONFIG_SOURCE/docker-compose.yml" "$STACK_DIR/"
        log "✅ docker-compose.yml copied"
    else
        error "docker-compose.yml not found in $CONFIG_SOURCE"
        exit 1
    fi

    # Copy LiteLLM config
    if [[ -f "$CONFIG_SOURCE/litellm-config.yaml" ]]; then
        cp "$CONFIG_SOURCE/litellm-config.yaml" "$STACK_DIR/"
        log "✅ litellm-config.yaml copied"
    else
        error "litellm-config.yaml not found in $CONFIG_SOURCE"
        exit 1
    fi

    # Copy .env if doesn't exist
    if [[ ! -f "$STACK_DIR/.env" ]]; then
        if [[ -f "$CONFIG_SOURCE/.env.example" ]]; then
            cp "$CONFIG_SOURCE/.env.example" "$STACK_DIR/.env"
            warning "⚠️  .env created from example - PLEASE UPDATE WITH SECURE KEYS"
        fi
    else
        info "ℹ️  .env already exists, not overwriting"
    fi
}

generate_secure_keys() {
    log "Generating secure keys..."

    if [[ ! -f "$STACK_DIR/.env" ]]; then
        error ".env file not found"
        exit 1
    fi

    # Generate keys if they're still default values
    if grep -q "changeme" "$STACK_DIR/.env"; then
        WEBUI_KEY=$(openssl rand -hex 32)
        LITELLM_KEY="sk-$(openssl rand -hex 24)"
        SALT_KEY="sk-salt-$(openssl rand -hex 24)"

        sed -i "s/changeme-please-use-random-key-here/$WEBUI_KEY/" "$STACK_DIR/.env"
        sed -i "s/sk-1234-change-this-key/$LITELLM_KEY/" "$STACK_DIR/.env"
        sed -i "s/sk-salt-1234-change-this/$SALT_KEY/" "$STACK_DIR/.env"

        log "✅ Secure keys generated"
        info "ℹ️  LiteLLM Master Key: $LITELLM_KEY"
        info "ℹ️  Save this key securely!"
    else
        info "ℹ️  Keys already configured, skipping generation"
    fi
}

verify_ollama() {
    log "Verifying Ollama installation..."

    # Check if Ollama is running
    if ! systemctl is-active --quiet ollama 2>/dev/null; then
        warning "Ollama service not running, attempting to start..."
        systemctl start ollama || true
        sleep 5
    fi

    # Test Ollama API
    if curl -sf http://localhost:11434/api/tags &> /dev/null; then
        log "✅ Ollama API is responsive"

        # Show installed models
        info "📦 Installed models:"
        ollama list | tail -n +2 | while read -r line; do
            info "   - $line"
        done
    else
        error "Ollama API not responding"
        exit 1
    fi
}

pull_docker_images() {
    log "Pulling Docker images..."

    # Pull images
    docker pull ghcr.io/open-webui/open-webui:main
    docker pull ghcr.io/berriai/litellm:main-latest
    docker pull ollama/ollama:latest

    log "✅ Docker images pulled"
}

deploy_stack() {
    log "Deploying Ollama stack..."

    cd "$STACK_DIR"

    # Stop any existing containers
    if docker compose ps -q &> /dev/null; then
        warning "Stopping existing containers..."
        docker compose down
    fi

    # Start stack
    docker compose up -d

    log "✅ Stack deployed"
}

wait_for_services() {
    log "Waiting for services to start..."

    # Wait for Ollama
    info "⏳ Waiting for Ollama..."
    for i in {1..30}; do
        if curl -sf http://localhost:11434/api/tags &> /dev/null; then
            log "✅ Ollama ready"
            break
        fi
        sleep 2
    done

    # Wait for Open WebUI
    info "⏳ Waiting for Open WebUI..."
    for i in {1..30}; do
        if curl -sf http://localhost:3000/health &> /dev/null; then
            log "✅ Open WebUI ready"
            break
        fi
        sleep 2
    done

    # Wait for LiteLLM
    info "⏳ Waiting for LiteLLM..."
    for i in {1..30}; do
        if curl -sf http://localhost:4000/health &> /dev/null; then
            log "✅ LiteLLM ready"
            break
        fi
        sleep 2
    done
}

verify_deployment() {
    log "Verifying deployment..."

    # Check container status
    if docker compose ps | grep -q "Up"; then
        log "✅ All containers running"
    else
        error "Some containers failed to start"
        docker compose ps
        exit 1
    fi

    # Test endpoints
    OLLAMA_STATUS=$(curl -sf http://localhost:11434/api/tags &> /dev/null && echo "✅" || echo "❌")
    WEBUI_STATUS=$(curl -sf http://localhost:3000 &> /dev/null && echo "✅" || echo "❌")
    LITELLM_STATUS=$(curl -sf http://localhost:4000/health &> /dev/null && echo "✅" || echo "❌")

    info "Service Status:"
    info "  Ollama:     $OLLAMA_STATUS http://10.6.0.17:11434"
    info "  Open WebUI: $WEBUI_STATUS http://10.6.0.17:3000"
    info "  LiteLLM:    $LITELLM_STATUS http://10.6.0.17:4000"

    # Check GPU usage
    if nvidia-smi &> /dev/null; then
        log "✅ GPU accessible"
        nvidia-smi --query-gpu=name,memory.total,memory.used --format=csv,noheader
    fi
}

create_management_scripts() {
    log "Creating management scripts..."

    # Status script
    cat > "$STACK_DIR/status.sh" << 'EOF'
#!/bin/bash
cd /opt/ollama-stack
echo "=== Ollama Stack Status ==="
echo ""
echo "Containers:"
docker compose ps
echo ""
echo "Ollama Models:"
ollama list
echo ""
echo "GPU Status:"
nvidia-smi --query-gpu=name,memory.used,memory.total,utilization.gpu --format=csv
echo ""
echo "Service Health:"
curl -sf http://localhost:11434/api/tags &> /dev/null && echo "✅ Ollama: OK" || echo "❌ Ollama: FAILED"
curl -sf http://localhost:3000 &> /dev/null && echo "✅ Open WebUI: OK" || echo "❌ Open WebUI: FAILED"
curl -sf http://localhost:4000/health &> /dev/null && echo "✅ LiteLLM: OK" || echo "❌ LiteLLM: FAILED"
EOF
    chmod +x "$STACK_DIR/status.sh"

    # Restart script
    cat > "$STACK_DIR/restart.sh" << 'EOF'
#!/bin/bash
cd /opt/ollama-stack
echo "Restarting Ollama stack..."
docker compose restart
sleep 10
./status.sh
EOF
    chmod +x "$STACK_DIR/restart.sh"

    # Logs script
    cat > "$STACK_DIR/logs.sh" << 'EOF'
#!/bin/bash
cd /opt/ollama-stack
CONTAINER=${1:-all}
if [[ "$CONTAINER" == "all" ]]; then
    docker compose logs -f
else
    docker compose logs -f "$CONTAINER"
fi
EOF
    chmod +x "$STACK_DIR/logs.sh"

    log "✅ Management scripts created"
}

print_summary() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "🎉 Ollama Stack Deployment Complete!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    info "📍 Access Points:"
    echo "   • Open WebUI:  http://10.6.0.17:3000"
    echo "   • Ollama API:  http://10.6.0.17:11434"
    echo "   • LiteLLM:     http://10.6.0.17:4000"
    echo ""
    info "🔑 Authentication:"
    echo "   • Open WebUI: Create admin account on first access"
    LITELLM_KEY=$(grep LITELLM_MASTER_KEY "$STACK_DIR/.env" | cut -d= -f2)
    echo "   • LiteLLM API Key: $LITELLM_KEY"
    echo ""
    info "📂 Installation Directory:"
    echo "   $STACK_DIR"
    echo ""
    info "🛠️  Management Commands:"
    echo "   • Status:  $STACK_DIR/status.sh"
    echo "   • Restart: $STACK_DIR/restart.sh"
    echo "   • Logs:    $STACK_DIR/logs.sh [container]"
    echo ""
    info "📚 Documentation:"
    echo "   • Setup Guide: docs/CT200-OLLAMA-COMPLETE-SETUP.md"
    echo "   • Quick Start: docs/QUICK-START.md"
    echo ""
    info "🚀 Next Steps:"
    echo "   1. Access Open WebUI and create admin account"
    echo "   2. Test chat with installed models"
    echo "   3. Configure LiteLLM for your applications"
    echo "   4. Review documentation for advanced features"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Main execution
main() {
    log "Starting Ollama Stack deployment..."

    check_requirements
    create_directories
    copy_configuration
    generate_secure_keys
    verify_ollama
    pull_docker_images
    deploy_stack
    wait_for_services
    verify_deployment
    create_management_scripts
    print_summary

    log "✅ Deployment completed successfully"
}

# Run main function
main "$@"
