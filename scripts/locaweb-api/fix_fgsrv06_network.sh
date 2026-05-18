#!/bin/bash
# ========================================
# Fix FGSRV06 Network Issues
# ========================================
# This script fixes:
# 1. DNS resolution issues
# 2. Docker network NAT/masquerade problems
# 3. iptables rules blocking external traffic
# 4. Missing services after reboot
#
# Run with: bash fix_fgsrv06_network.sh
# ========================================

set -e

# Check if running on FGSRV06
echo "=== Checking FGSRV06 network status ==="
if ! ping -c 1 -W 2 100.83.51.9 &>/dev/null 2>&1; then
    echo "ERROR: Cannot reach FGSRV06"
    exit 1
fi

echo "FGSRV06 is reachable via Tailscale"

# 1. Fix DNS
echo "=== Fixing DNS configuration ==="
# Configure Google DNS as fallback
echo "nameserver 8.8.8.8" > /etc/resolvconf.tail/resolv.conf.tail
echo "nameserver 8.8.8.8" | tee -a /etc/resolvconf.head > /etc/resolv.conf.head

# Ensure systemd-resolved uses Google DNS
mkdir -p /etc/systemd/resolved.conf.d/ || cat > /dev/null
[Resolve]
DNS=8.8.8.8#1.1.1.1
FallbackDNS=8.8.8.8
EOF

systemctl restart systemd-resolved

echo "DNS configuration updated"

# 2. Configure Docker to use host DNS
echo "=== Configuring Docker DNS ==="
mkdir -p /etc/docker/daemon.json.d/past /etc/docker/daemon.json.bak 2>/dev/null
echo '{
  "dns": ["8.8.8.8", "1.1.1.1"],
  "log-driver": "json-file"
}' > /etc/docker/daemon.json
echo "Docker DNS configured"

# 3. Configure iptables NAT for Docker
echo "=== Configuring iptables NAT for Docker ==="
# Ensure NAT is masquerade for Docker networks
for iface in docker0 br-+;; do
    subnet=$(ip -o show $iface | grep -oP 'inet ' | awk '{print $2}')
    if [ -n "$subnet" ]; then
        echo "Configuring NAT for $iface ($subnet)"
        iptables -t nat -C POSTROUTING -s "$subnet" ! -o "$iface" -j MASQUERADE
    fi
done
echo "iptables NAT configured"

# 4. Restart services in correct order
echo "=== Restarting services ==="
echo "Restarting systemd-resolved..."
systemctl restart systemd-resolved
sleep 2
echo "Restarting Docker..."
systemctl restart docker
sleep 2
echo "Restarting Tailscale..."
systemctl restart tailscaled
sleep 2
echo "Services restarted"

# 5. Verify connectivity
echo "=== Testing DNS resolution ==="
if nslookup google.com &>/dev/null 2>&1; then
    echo "DNS: OK"
else
    echo "DNS: FAILED"
    exit 1
fi

echo "=== Testing external connectivity ==="
if ping -c 3 -W 2 8.8.8.8 &>/dev/null 2>&1; then
    echo "Ping: OK"
else
    echo "Ping: FAILED"
    exit 1
fi
echo "=== Testing wget ==="
if wget -q --timeout=10 https://www.google.com -O /dev/null 2>&1; then
    echo "Wget: OK"
else
    echo "Wget: FAILED"
    exit 1
fi
echo "=== Testing Docker pull ==="
if docker pull alpine &>/dev/null 2>&1; then
    echo "Docker pull: OK"
else
    echo "Docker pull: FAILED"
    exit 1
fi
echo "=== Testing curl ==="
if curl -sI --connect-time 10 https://www.google.com | grep -q "HTTP" &>/dev/null 2>&1; then
    echo "Curl: OK"
else
    echo "Curl: FAILED"
    exit 1
fi
echo "=== Testing apt update ==="
if apt update &>/dev/null 2>&1; then
    echo "Apt: OK"
else
    echo "Apt: FAILED"
    exit 1
fi
echo ""
echo "=== FGSRV06 network fix completed successfully! ==="
echo "All services should now have proper network connectivity"
