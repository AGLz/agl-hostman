#!/bin/bash
# Harbor Registry Deployment Script
# Deploys Harbor container registry with Trivy scanner and Notary
#
# Usage: ./harbor-setup.sh [options]
#   --host HARBOR_HOST         Harbor hostname (default: harbor.local)
#   --admin-password PASS      Admin password (required)
#   --data-volume PATH         Data volume path (default: /data/harbor)
#   --ssl-cert PATH            SSL certificate path
#   --ssl-key PATH             SSL key path
#   --with-notary              Enable Notary content trust
#   --with-trivy               Enable Trivy scanner (default: true)
#   --version VERSION          Harbor version (default: v2.10.0)
#   --help                     Show this help

set -euo pipefail

# Default values
HARBOR_HOST="${HARBOR_HOST:-harbor.local}"
ADMIN_PASSWORD=""
DATA_VOLUME="${DATA_VOLUME:-/data/harbor}"
SSL_CERT=""
SSL_KEY=""
WITH_NOTARY=false
WITH_TRIVY=true
HARBOR_VERSION="${HARBOR_VERSION:-v2.10.0}"
INSTALL_DIR="/opt/harbor"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
fatal() { log_error "$1"; exit 1; }

# Help
usage() {
    grep '^#' "$0" | sed 's/^#/ /' | sed '1d; $d'
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --host) HARBOR_HOST="$2"; shift 2 ;;
        --admin-password) ADMIN_PASSWORD="$2"; shift 2 ;;
        --data-volume) DATA_VOLUME="$2"; shift 2 ;;
        --ssl-cert) SSL_CERT="$2"; shift 2 ;;
        --ssl-key) SSL_KEY="$2"; shift 2 ;;
        --with-notary) WITH_NOTARY=true; shift ;;
        --without-trivy) WITH_TRIVY=false; shift ;;
        --version) HARBOR_VERSION="$2"; shift 2 ;;
        --help) usage ;;
        *) fatal "Unknown option: $1" ;;
    esac
done

# Validation
[[ -z "$ADMIN_PASSWORD" ]] && fatal "Admin password required (--admin-password)"

# Prerequisites check
log_info "Checking prerequisites..."

# Check Docker
if ! command -v docker &> /dev/null; then
    fatal "Docker not found. Install Docker first."
fi

# Check Docker Compose
if ! command -v docker-compose &> /dev/null; then
    fatal "Docker Compose not found. Install Docker Compose first."
fi

# Check disk space
AVAILABLE_SPACE=$(df -BG "$DATA_VOLUME" 2>/dev/null | awk 'NR==2 {print $4}' | sed 's/G//')
if [[ $AVAILABLE_SPACE -lt 100 ]]; then
    log_warn "Less than 100GB available disk space. Recommended: 100GB+"
fi

# Check ports
for port in 80 443 8080; do
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        fatal "Port $port is already in use"
    fi
done

log_info "Prerequisites check passed"

# Download Harbor
log_info "Downloading Harbor $HARBOR_VERSION..."

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

HARBOR_INSTALLER="harbor-online-installer-${HARBOR_VERSION}.tgz"

if [[ ! -f "$HARBOR_INSTALLER" ]]; then
    curl -sSL "https://github.com/goharbor/harbor/releases/download/${HARBOR_VERSION}/${HARBOR_INSTALLER}" -o "$HARBOR_INSTALLER"
    tar -xzf "$HARBOR_INSTALLER"
    cd harbor
else
    cd harbor
fi

# Generate harbor.yml
log_info "Generating harbor.yml..."

cat > harbor.yml <<EOF
# Harbor configuration generated at $(date)

hostname: ${HARBOR_HOST}

# HTTP/HTTPS
http:
  port: 80
https:
  port: 443
  certificate: ${SSL_CERT:-/data/harbor/ssl/harbor.crt}
  private_key: ${SSL_KEY:-/data/harbor/ssl/harbor.key}

# Admin password
harbor_admin_password: ${ADMIN_PASSWORD}

# Database
database:
  password: "${HARBOR_DB_PASSWORD:-changeit}"
  max_idle_conns: 100
  max_open_conns: 900

# Data volume
data_volume: ${DATA_VOLUME}

# Trivy scanner
trivy:
  enabled: ${WITH_TRIVY}
  ignore_unfixed: false
  skip_update: false
  offline_scan: false
  security_check: vuln
  insecure: false

# Notary
notary:
  enabled: ${WITH_NOTARY}

# Log level
log_level: info

# Proxy
# proxy:
#   http_proxy:
#   https_proxy:
#   no_proxy:
#   components:
#     - core
#     - jobservice
#     - trivy
EOF

# Generate self-signed certificate if not provided
if [[ -z "$SSL_CERT" || -z "$SSL_KEY" ]]; then
    log_info "Generating self-signed SSL certificate..."

    SSL_DIR="${DATA_VOLUME}/ssl"
    mkdir -p "$SSL_DIR"

    openssl req -newkey rsa:4096 -nodes -sha256 \
        -keyout "${SSL_DIR}/harbor.key" \
        -x509 -days 365 \
        -out "${SSL_DIR}/harbor.crt" \
        -subj "/CN=${HARBOR_HOST}" \
        -addext "subjectAltName=DNS:${HARBOR_HOST},DNS:*.${HARBOR_HOST}"

    log_info "Self-signed certificate generated at ${SSL_DIR}"
fi

# Prepare data volume
log_info "Preparing data volume at ${DATA_VOLUME}..."
mkdir -p "${DATA_VOLUME}/{registry,database,redis,logs}"

# Install Harbor
log_info "Installing Harbor..."

INSTALL_ARGS=""
if [[ "$WITH_TRIVY" == true ]]; then
    INSTALL_ARGS="$INSTALL_ARGS --with-trivy"
fi
if [[ "$WITH_NOTARY" == true ]]; then
    INSTALL_ARGS="$INSTALL_ARGS --with-notary"
fi

./install.sh $INSTALL_ARGS

# Wait for Harbor to start
log_info "Waiting for Harbor to start..."
MAX_WAIT=300
WAIT_TIME=0

while [[ $WAIT_TIME -lt $MAX_WAIT ]]; do
    if curl -sfk "https://${HARBOR_HOST}/api/v2.0/systeminfo" > /dev/null 2>&1; then
        log_info "Harbor is ready!"
        break
    fi

    WAIT_TIME=$((WAIT_TIME + 10))
    sleep 10
    echo -n "."
done

if [[ $WAIT_TIME -ge $MAX_WAIT ]]; then
    fatal "Harbor failed to start within ${MAX_WAIT}s"
fi

# Post-installation configuration
log_info "Running post-installation configuration..."

# Create default projects
log_info "Creating default projects..."

# Production project
curl -skX POST "https://${HARBOR_HOST}/api/v2.0/projects" \
    -u "admin:${ADMIN_PASSWORD}" \
    -H "Content-Type: application/json" \
    -d '{
        "project_name": "production",
        "public": false,
        "metadata": {
            "public": "false",
            "enable_content_trust": "true",
            "prevent_vul": "true"
        }
    }' > /dev/null 2>&1

# Staging project
curl -skX POST "https://${HARBOR_HOST}/api/v2.0/projects" \
    -u "admin:${ADMIN_PASSWORD}" \
    -H "Content-Type: application/json" \
    -d '{
        "project_name": "staging",
        "public": false,
        "metadata": {
            "public": "false",
            "enable_content_trust": "true",
            "prevent_vul": "false"
        }
    }' > /dev/null 2>&1

# Development project
curl -skX POST "https://${HARBOR_HOST}/api/v2.0/projects" \
    -u "admin:${ADMIN_PASSWORD}" \
    -H "Content-Type: application/json" \
    -d '{
        "project_name": "development",
        "public": true,
        "metadata": {
            "public": "true",
            "enable_content_trust": "false",
            "prevent_vul": "false"
        }
    }' > /dev/null 2>&1

# Summary
log_info "Harbor installation complete!"
echo ""
echo "Harbor URL: https://${HARBOR_HOST}"
echo "Admin username: admin"
echo "Admin password: ${ADMIN_PASSWORD}"
echo "Data volume: ${DATA_VOLUME}"
echo "Install directory: ${INSTALL_DIR}/harbor"
echo ""
echo "Next steps:"
echo "  1. Login to Harbor: docker login ${HARBOR_HOST} -u admin -p ${ADMIN_PASSWORD}"
echo "  2. Create robot accounts for CI/CD"
echo "  3. Configure retention policies"
echo "  4. Enable vulnerability scanning"
echo ""
echo "Useful commands:"
echo "  Start Harbor:   cd ${INSTALL_DIR}/harbor && docker-compose up -d"
echo "  Stop Harbor:    cd ${INSTALL_DIR}/harbor && docker-compose down"
echo "  View logs:      cd ${INSTALL_DIR}/harbor && docker-compose logs -f"
echo "  Reconfigure:    ./prepare && docker-compose up -d"
