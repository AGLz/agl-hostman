#!/bin/bash
#
# Harbor Network Configuration Script
# Configures network settings, firewall, and DNS for Harbor CT182
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
HARBOR_IP="192.168.0.182"
HARBOR_HOSTNAME="harbor.agl.local"
GATEWAY="192.168.0.1"
DNS_SERVER="192.168.0.102"
SUBNET="192.168.0.0/24"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Harbor Network Configuration${NC}"
echo -e "${BLUE}========================================${NC}"

# Check if running on Proxmox host or container
if command -v pct &> /dev/null; then
    RUN_PREFIX="pct exec $CTID --"
    echo -e "${GREEN}Configuring network on CT$CTID from Proxmox host${NC}"
else
    RUN_PREFIX=""
    echo -e "${GREEN}Configuring network directly on container${NC}"
fi

# Function to execute commands
run_cmd() {
    if [ -n "$RUN_PREFIX" ]; then
        $RUN_PREFIX bash -c "$1"
    else
        bash -c "$1"
    fi
}

echo -e "${GREEN}Step 1: Configuring static IP...${NC}"
cat > /tmp/network-config << 'EOF'
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto eth0
iface eth0 inet static
    address 192.168.0.182/24
    gateway 192.168.0.1
    dns-nameservers 192.168.0.102 1.1.1.1
EOF

run_cmd "cat > /etc/network/interfaces << 'EOFINNER'
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto eth0
iface eth0 inet static
    address 192.168.0.182/24
    gateway 192.168.0.1
    dns-nameservers 192.168.0.102 1.1.1.1
EOFINNER"

echo -e "${GREEN}Step 2: Configuring hostname...${NC}"
run_cmd "echo '$HARBOR_HOSTNAME' > /etc/hostname"
run_cmd "hostname $HARBOR_HOSTNAME"

echo -e "${GREEN}Step 3: Updating /etc/hosts...${NC}"
run_cmd "sed -i '/127.0.1.1/d' /etc/hosts"
run_cmd "echo '127.0.1.1 $HARBOR_HOSTNAME' >> /etc/hosts"
run_cmd "echo '$HARBOR_IP $HARBOR_HOSTNAME' >> /etc/hosts"

echo -e "${GREEN}Step 4: Installing and configuring firewall...${NC}"
run_cmd "apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y iptables iptables-persistent"

# Configure firewall rules
cat > /tmp/firewall-rules.sh << 'EOF'
#!/bin/bash
# Flush existing rules
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X

# Default policies
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow established connections
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow SSH (port 22)
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow HTTP (port 80) - Harbor redirect
iptables -A INPUT -p tcp --dport 80 -j ACCEPT

# Allow HTTPS (port 443) - Harbor main interface
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Allow Docker Registry (port 5000) - alternative access
iptables -A INPUT -p tcp --dport 5000 -j ACCEPT

# Allow ping
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT

# Log dropped packets (optional, for debugging)
# iptables -A INPUT -j LOG --log-prefix "IPTables-Dropped: " --log-level 4

# Save rules
netfilter-persistent save
EOF

run_cmd "chmod +x /tmp/firewall-rules.sh"
run_cmd "/tmp/firewall-rules.sh"

echo -e "${GREEN}Step 5: Configuring DNS resolution...${NC}"
run_cmd "echo 'nameserver 192.168.0.102' > /etc/resolv.conf"
run_cmd "echo 'nameserver 1.1.1.1' >> /etc/resolv.conf"
run_cmd "chattr +i /etc/resolv.conf"  # Make immutable

echo -e "${GREEN}Step 6: Testing network connectivity...${NC}"
echo -e "${YELLOW}Testing DNS resolution...${NC}"
run_cmd "ping -c 3 google.com" || echo -e "${RED}DNS resolution failed${NC}"

echo -e "${YELLOW}Testing gateway connectivity...${NC}"
run_cmd "ping -c 3 $GATEWAY" || echo -e "${RED}Gateway not reachable${NC}"

echo -e "${GREEN}Step 7: Configuring sysctl for Docker...${NC}"
cat > /tmp/sysctl-harbor.conf << EOF
# Harbor/Docker optimizations
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
vm.max_map_count = 262144
fs.file-max = 65536
net.core.somaxconn = 32768
net.ipv4.tcp_max_syn_backlog = 8192
EOF

run_cmd "cat > /etc/sysctl.d/99-harbor.conf << 'EOFINNER'
# Harbor/Docker optimizations
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
vm.max_map_count = 262144
fs.file-max = 65536
net.core.somaxconn = 32768
net.ipv4.tcp_max_syn_backlog = 8192
EOFINNER"

run_cmd "sysctl -p /etc/sysctl.d/99-harbor.conf" || echo -e "${YELLOW}Some sysctl settings may require reboot${NC}"

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Network Configuration Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "IP Address: ${GREEN}$HARBOR_IP${NC}"
echo -e "Hostname: ${GREEN}$HARBOR_HOSTNAME${NC}"
echo -e "Gateway: ${GREEN}$GATEWAY${NC}"
echo -e "DNS Servers: ${GREEN}1.1.1.1, 8.8.8.8${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Firewall Rules:${NC}"
echo -e "Port 22 (SSH): ${GREEN}OPEN${NC}"
echo -e "Port 80 (HTTP): ${GREEN}OPEN${NC}"
echo -e "Port 443 (HTTPS): ${GREEN}OPEN${NC}"
echo -e "Port 5000 (Registry): ${GREEN}OPEN${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Recommended next steps:${NC}"
echo -e "1. Restart container: ${GREEN}pct reboot $CTID${NC}"
echo -e "2. Verify network: ${GREEN}pct exec $CTID -- ip addr show${NC}"
echo -e "3. Test Harbor access: ${GREEN}curl -k https://$HARBOR_IP${NC}"
echo -e "${BLUE}========================================${NC}"
