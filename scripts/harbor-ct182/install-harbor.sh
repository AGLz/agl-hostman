#!/bin/bash
#
# Harbor Installation Script for CT182
# Automates complete Harbor setup with SSL and configuration
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
HARBOR_VERSION="v2.11.1"  # Latest stable version
HARBOR_HOSTNAME="harbor.agl.local"
HARBOR_IP="192.168.0.182"
HARBOR_ADMIN_PASSWORD=""  # Will prompt if not set
DATA_VOLUME="/var/harbor"
INSTALL_DIR="/opt/harbor"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Harbor Installation Script${NC}"
echo -e "${BLUE}Version: $HARBOR_VERSION${NC}"
echo -e "${BLUE}========================================${NC}"

# Check if running on Proxmox host
if command -v pct &> /dev/null; then
    RUN_PREFIX="pct exec $CTID --"
    echo -e "${GREEN}Running installation on CT$CTID from Proxmox host${NC}"
else
    RUN_PREFIX=""
    echo -e "${GREEN}Running installation directly on container${NC}"
fi

# Function to execute commands
run_cmd() {
    if [ -n "$RUN_PREFIX" ]; then
        $RUN_PREFIX bash -c "$1"
    else
        bash -c "$1"
    fi
}

# Prompt for Harbor admin password
if [ -z "$HARBOR_ADMIN_PASSWORD" ]; then
    read -sp "Enter Harbor admin password: " HARBOR_ADMIN_PASSWORD
    echo
    read -sp "Confirm password: " PASSWORD_CONFIRM
    echo
    if [ "$HARBOR_ADMIN_PASSWORD" != "$PASSWORD_CONFIRM" ]; then
        echo -e "${RED}ERROR: Passwords do not match${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}Step 1: Installing prerequisites...${NC}"
run_cmd "apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl \
    wget \
    gnupg \
    lsb-release \
    ca-certificates \
    openssl \
    tar"

echo -e "${GREEN}Step 2: Installing Docker...${NC}"
run_cmd "curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg"
run_cmd 'echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list'
run_cmd "apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin"
run_cmd "systemctl enable docker && systemctl start docker"

echo -e "${GREEN}Step 3: Installing Docker Compose...${NC}"
run_cmd "curl -SL https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose"
run_cmd "chmod +x /usr/local/bin/docker-compose"
run_cmd "ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose"

echo -e "${GREEN}Step 4: Creating data directories...${NC}"
run_cmd "mkdir -p $DATA_VOLUME/{registry,database,job_logs,redis,ca_download,secret,trivy-adapter/trivy}"
run_cmd "mkdir -p $INSTALL_DIR"

echo -e "${GREEN}Step 5: Downloading Harbor installer...${NC}"
run_cmd "cd /tmp && wget https://github.com/goharbor/harbor/releases/download/$HARBOR_VERSION/harbor-offline-installer-$HARBOR_VERSION.tgz"
run_cmd "cd /tmp && tar xzvf harbor-offline-installer-$HARBOR_VERSION.tgz"
run_cmd "cp -r /tmp/harbor/* $INSTALL_DIR/"

echo -e "${GREEN}Step 6: Generating SSL certificates...${NC}"
run_cmd "mkdir -p $INSTALL_DIR/ssl"
run_cmd "cd $INSTALL_DIR/ssl && openssl req -newkey rsa:4096 -nodes -sha256 -keyout harbor.key -x509 -days 365 -out harbor.crt -subj \"/C=US/ST=State/L=City/O=Organization/CN=$HARBOR_HOSTNAME\""

echo -e "${GREEN}Step 7: Configuring Harbor...${NC}"
cat > /tmp/harbor.yml << EOF
# Harbor Configuration
hostname: $HARBOR_IP

# HTTP settings
http:
  port: 80

# HTTPS settings
https:
  port: 443
  certificate: $INSTALL_DIR/ssl/harbor.crt
  private_key: $INSTALL_DIR/ssl/harbor.key

# Harbor admin password
harbor_admin_password: $HARBOR_ADMIN_PASSWORD

# Database configuration
database:
  password: $(openssl rand -base64 32)
  max_idle_conns: 100
  max_open_conns: 900
  conn_max_lifetime: 5m
  conn_max_idle_time: 0

# Data volume
data_volume: $DATA_VOLUME

# Trivy vulnerability scanner
trivy:
  ignore_unfixed: false
  skip_update: false
  offline_scan: false
  security_check: vuln
  insecure: false

# Clair vulnerability scanner (legacy)
# clair:
#   updaters_interval: 12

# Job service
jobservice:
  max_job_workers: 10

# Notification
notification:
  webhook_job_max_retry: 3

# Chart repository
chart:
  absolute_url: disabled

# Log configuration
log:
  level: info
  local:
    rotate_count: 50
    rotate_size: 200M
    location: /var/log/harbor

# GC configuration
_version: 2.11.0

# Proxy settings (if needed)
# proxy:
#   http_proxy:
#   https_proxy:
#   no_proxy: 127.0.0.1,localhost,.local,.internal,log,db,redis,nginx,core,portal,postgresql,jobservice,registry,registryctl,trivy-adapter,trivy

# Redis external (if using external Redis)
# external_redis:
#   host: redis
#   port: 6379
#   password:
#   registry_db_index: 1
#   jobservice_db_index: 2
#   trivy_db_index: 5

# Database external (if using external PostgreSQL)
# external_database:
#   harbor:
#     host: postgresql
#     port: 5432
#     db_name: registry
#     username: postgres
#     password:
#     ssl_mode: disable
#     max_idle_conns: 2
#     max_open_conns: 0

# UAA (if using UAA authentication)
# uaa:
#   ca_file: /path/to/ca
EOF

run_cmd "cp /tmp/harbor.yml $INSTALL_DIR/harbor.yml"

echo -e "${GREEN}Step 8: Installing Harbor...${NC}"
run_cmd "cd $INSTALL_DIR && ./install.sh --with-trivy --with-chartmuseum"

echo -e "${GREEN}Step 9: Verifying installation...${NC}"
sleep 10
run_cmd "docker ps"

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Harbor Installation Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Harbor URL: ${GREEN}https://$HARBOR_IP${NC}"
echo -e "Username: ${GREEN}admin${NC}"
echo -e "Password: ${YELLOW}[as configured]${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Post-installation steps:${NC}"
echo -e "1. Access Harbor UI at https://$HARBOR_IP"
echo -e "2. Login with admin credentials"
echo -e "3. Create projects and users"
echo -e "4. Configure Docker clients to trust Harbor"
echo -e "5. Run: ${GREEN}./configure-network.sh${NC} to set up networking"
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Docker client configuration:${NC}"
echo -e "sudo mkdir -p /etc/docker/certs.d/$HARBOR_IP"
echo -e "sudo scp root@$HARBOR_IP:$INSTALL_DIR/ssl/harbor.crt /etc/docker/certs.d/$HARBOR_IP/ca.crt"
echo -e "docker login $HARBOR_IP"
echo -e "${BLUE}========================================${NC}"
