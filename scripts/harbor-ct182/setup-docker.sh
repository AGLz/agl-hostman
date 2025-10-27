#!/bin/bash
#
# Docker/Podman Setup Script for Harbor CT182
# Prepares container runtime environment
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
DOCKER_VERSION="24.0"
COMPOSE_VERSION="v2.24.5"
USE_PODMAN=false  # Set to true if you prefer Podman over Docker

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Docker/Container Runtime Setup${NC}"
echo -e "${BLUE}========================================${NC}"

# Check if running on Proxmox host or container
if command -v pct &> /dev/null; then
    RUN_PREFIX="pct exec $CTID --"
    echo -e "${GREEN}Setting up Docker on CT$CTID from Proxmox host${NC}"
else
    RUN_PREFIX=""
    echo -e "${GREEN}Setting up Docker directly on container${NC}"
fi

# Function to execute commands
run_cmd() {
    if [ -n "$RUN_PREFIX" ]; then
        $RUN_PREFIX bash -c "$1"
    else
        bash -c "$1"
    fi
}

if [ "$USE_PODMAN" = true ]; then
    echo -e "${YELLOW}Installing Podman instead of Docker...${NC}"

    echo -e "${GREEN}Step 1: Installing Podman...${NC}"
    run_cmd "apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        podman \
        podman-compose \
        buildah \
        skopeo"

    echo -e "${GREEN}Step 2: Configuring Podman...${NC}"
    run_cmd "mkdir -p /etc/containers"

    cat > /tmp/registries.conf << EOF
# Registries configuration
unqualified-search-registries = ["docker.io"]

[[registry]]
location = "docker.io"
insecure = false

[[registry]]
location = "192.168.1.182"
insecure = true
EOF

    run_cmd "cat > /etc/containers/registries.conf << 'EOFINNER'
# Registries configuration
unqualified-search-registries = [\"docker.io\"]

[[registry]]
location = \"docker.io\"
insecure = false

[[registry]]
location = \"192.168.1.182\"
insecure = true
EOFINNER"

    echo -e "${GREEN}Podman setup complete!${NC}"
else
    echo -e "${GREEN}Step 1: Removing old Docker versions...${NC}"
    run_cmd "apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true"

    echo -e "${GREEN}Step 2: Installing prerequisites...${NC}"
    run_cmd "apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        apt-transport-https \
        software-properties-common"

    echo -e "${GREEN}Step 3: Adding Docker's official GPG key...${NC}"
    run_cmd "mkdir -p /etc/apt/keyrings"
    run_cmd "curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg"
    run_cmd "chmod a+r /etc/apt/keyrings/docker.gpg"

    echo -e "${GREEN}Step 4: Setting up Docker repository...${NC}"
    run_cmd 'echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list'

    echo -e "${GREEN}Step 5: Installing Docker Engine...${NC}"
    run_cmd "apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin"

    echo -e "${GREEN}Step 6: Configuring Docker daemon...${NC}"
    run_cmd "mkdir -p /etc/docker"

    cat > /tmp/daemon.json << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "live-restore": true,
  "userland-proxy": false,
  "experimental": false,
  "metrics-addr": "127.0.0.1:9323",
  "registry-mirrors": [],
  "insecure-registries": ["192.168.1.182"],
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 64000,
      "Soft": 64000
    }
  }
}
EOF

    run_cmd "cat > /etc/docker/daemon.json << 'EOFINNER'
{
  \"log-driver\": \"json-file\",
  \"log-opts\": {
    \"max-size\": \"10m\",
    \"max-file\": \"3\"
  },
  \"storage-driver\": \"overlay2\",
  \"live-restore\": true,
  \"userland-proxy\": false,
  \"experimental\": false,
  \"metrics-addr\": \"127.0.0.1:9323\",
  \"registry-mirrors\": [],
  \"insecure-registries\": [\"192.168.1.182\"],
  \"default-ulimits\": {
    \"nofile\": {
      \"Name\": \"nofile\",
      \"Hard\": 64000,
      \"Soft\": 64000
    }
  }
}
EOFINNER"

    echo -e "${GREEN}Step 7: Installing Docker Compose standalone...${NC}"
    run_cmd "curl -SL https://github.com/docker/compose/releases/download/$COMPOSE_VERSION/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose"
    run_cmd "chmod +x /usr/local/bin/docker-compose"
    run_cmd "ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose"

    echo -e "${GREEN}Step 8: Starting and enabling Docker...${NC}"
    run_cmd "systemctl daemon-reload"
    run_cmd "systemctl enable docker"
    run_cmd "systemctl restart docker"

    echo -e "${GREEN}Step 9: Verifying Docker installation...${NC}"
    run_cmd "docker --version"
    run_cmd "docker compose version"
    run_cmd "docker run --rm hello-world" || echo -e "${YELLOW}Warning: hello-world test failed${NC}"
fi

echo -e "${GREEN}Step 10: Installing additional tools...${NC}"
run_cmd "apt-get install -y \
    git \
    wget \
    curl \
    jq \
    vim \
    htop \
    net-tools \
    dnsutils \
    tcpdump"

echo -e "${GREEN}Step 11: Creating Docker maintenance scripts...${NC}"
cat > /tmp/docker-cleanup.sh << 'EOF'
#!/bin/bash
# Docker cleanup script
echo "Cleaning Docker system..."
docker system prune -af --volumes
docker image prune -af
docker volume prune -f
echo "Docker cleanup complete!"
EOF

run_cmd "cat > /usr/local/bin/docker-cleanup << 'EOFINNER'
#!/bin/bash
# Docker cleanup script
echo \"Cleaning Docker system...\"
docker system prune -af --volumes
docker image prune -af
docker volume prune -f
echo \"Docker cleanup complete!\"
EOFINNER"

run_cmd "chmod +x /usr/local/bin/docker-cleanup"

echo -e "${GREEN}Step 12: Testing Docker networking...${NC}"
run_cmd "docker network ls"
run_cmd "docker network inspect bridge" || true

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Docker Setup Complete!${NC}"
echo -e "${BLUE}========================================${NC}"

if [ "$USE_PODMAN" = true ]; then
    echo -e "Container Runtime: ${GREEN}Podman${NC}"
    run_cmd "podman --version"
else
    echo -e "Docker Version: ${GREEN}$(run_cmd 'docker --version')${NC}"
    echo -e "Docker Compose: ${GREEN}$(run_cmd 'docker compose version')${NC}"
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Docker configuration:${NC}"
echo -e "Storage Driver: ${GREEN}overlay2${NC}"
echo -e "Log Driver: ${GREEN}json-file${NC}"
echo -e "Insecure Registry: ${GREEN}192.168.1.182${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Install Harbor: ${GREEN}./install-harbor.sh${NC}"
echo -e "2. Check Docker status: ${GREEN}docker ps${NC}"
echo -e "3. Cleanup: ${GREEN}/usr/local/bin/docker-cleanup${NC}"
echo -e "${BLUE}========================================${NC}"
