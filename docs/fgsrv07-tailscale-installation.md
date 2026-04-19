# Tailscale Installation Guide - FGSRV07

## Host Information

| Property | Value |
|----------|-------|
| **Name** | FGSRV07 |
| **Type** | VPS Locaweb |
| **OS** | Debian 13 (Trixie) |
| **IP Address** | 191.252.93.227 |
| **SSH Access** | Key-based authentication configured |

---

## Table of Contents

1. [Pre-requirements](#pre-requirements)
2. [Installation Steps](#installation-steps)
3. [Authentication & Setup](#authentication--setup)
4. [Verification](#verification)
5. [Integration with Existing Network](#integration-with-existing-network)
6. [Configuration Options](#configuration-options)
7. [Troubleshooting](#troubleshooting)
8. [Security Considerations](#security-considerations)

---

## Pre-requirements

### System Requirements

- Debian 13 (Trixie) with root or sudo access
- Active internet connection
- SSH access with authorized key (already configured)
- Tailscale account with admin privileges

### Verify System Information

```bash
# Check OS version
cat /etc/os-release

# Check kernel version
uname -r

# Verify internet connectivity
ping -c 3 1.1.1.1

# Check if running as root or with sudo
whoami
sudo -v
```

### Update System Packages

```bash
# Update package lists
sudo apt update

# Upgrade existing packages (optional but recommended)
sudo apt upgrade -y

# Install required dependencies
sudo apt install -y curl gnupg
```

---

## Installation Steps

### Method 1: Official Tailscale Repository (Recommended)

This method ensures you get the latest version with automatic updates.

#### Step 1: Add Tailscale GPG Key

```bash
# Download and add Tailscale GPG key
curl -fsSL https://tailscale.com/gpg.key | sudo gpg --dearmor -o /usr/share/keyrings/tailscale-archive-keyring.gpg
```

#### Step 2: Add Tailscale Repository

```bash
# Add repository for Debian
echo "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/debian $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/tailscale.list
```

**Note for Debian 13 (Trixie)**: If the repository doesn't have Trixie packages yet, use Bookworm:

```bash
echo "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/debian bookworm main" | sudo tee /etc/apt/sources.list.d/tailscale.list
```

#### Step 3: Update Package Lists

```bash
sudo apt update
```

#### Step 4: Install Tailscale

```bash
sudo apt install -y tailscale
```

### Method 2: Standalone Script (Alternative)

If the repository method fails, use the install script:

```bash
# Download and run Tailscale install script
curl -fsSL https://tailscale.com/install.sh | sh
```

---

## Authentication & Setup

### Initial Authentication

```bash
# Start Tailscale with authentication
sudo tailscale up
```

This command will:
1. Generate a unique machine key
2. Provide a URL for authentication
3. Open browser (or copy URL to browser on your local machine)
4. Connect to your Tailscale network

### Authentication URL Example

```
https://login.tailscale.com/a/xxxxxxxxx
```

**Instructions:**
1. Copy the provided URL
2. Open it in a web browser on your local machine
3. Log in to your Tailscale account (Google, Microsoft, GitHub, etc.)
4. Click "Connect" to authorize FGSRV07
5. Return to terminal - you should see "Success!"

### Additional Authentication Options

#### Specify Tags (for ACL policies)

```bash
# Add tags to the machine (requires tag owners configured in ACLs)
sudo tailscale up --tags=tag:server,tag:production
```

#### Advertise Exit Node

```bash
# Configure as exit node
sudo tailscale up --advertise-exit-node
```

#### Accept Routes

```bash
# Accept advertised routes from other nodes
sudo tailscale up --accept-routes
```

#### Disable NAT Traversal (if needed)

```bash
# For networks with firewall restrictions
sudo tailscale up --nat=false
```

---

## Verification

### Check Tailscale Status

```bash
# Verify Tailscale is running
sudo tailscale status

# Check connection details
tailscale status --peers

# View IP addresses
tailscale ip -4
tailscale ip -6

# Check if DERP (relay) is being used
tailscale status --json | grep -i derp
```

### Expected Output

```
# tailscale status
192.168.0.1  fgsrv07  user@example.com  linux  -
```

### Test Connectivity

```bash
# Ping another Tailscale node (replace with actual IP)
ping -c 3 100.x.x.x

# Test DNS resolution (if using MagicDNS)
ping fgsrv03.tailnet-name.ts.net

# Test connection to existing nodes
ssh user@100.x.x.x
```

### Check Service Status

```bash
# Verify tailscaled service is active
systemctl status tailscaled

# Check service logs
journalctl -u tailscaled -n 50 --no-pager

# Enable service to start on boot
sudo systemctl enable tailscaled
```

---

## Integration with Existing Network

### Current Network Topology

| Host | Role | Tailscale IP |
|------|------|--------------|
| FGSRV03 | Node | 100.x.x.3 |
| FGSRV04 | Node | 100.x.x.4 |
| FGSRV05 | Node | 100.x.x.5 |
| FGSRV06 | Node | 100.x.x.6 |
| FGSRV07 | New Node | 100.x.x.7 (assigned) |

### Verify Network Discovery

```bash
# List all peers in your tailnet
tailscale status

# Should show FGSRV03, FGSRV04, FGSRV05, FGSRV06
```

### Test Connectivity to Existing Nodes

```bash
# Test connection to each existing server
for host in fgsrv03 fgsrv04 fgsrv05 fgsrv06; do
    echo "Testing connection to $host..."
    ping -c 2 ${host}.your-tailnet.ts.net
done
```

### SSH Integration

If using Tailscale SSH:

```bash
# Enable Tailscale SSH (if configured in admin console)
sudo tailscale set --ssh

# Test SSH to another node
ssh user@fgsrv03
```

### ACL Configuration

Ensure your Tailscale ACLs include FGSRV07. Example ACL tag:

```json
{
  "tagOwners": {
    "tag:fgsrv": ["user@example.com"]
  },
  "acls": [
    {
      "action": "accept",
      "src": ["tag:fgsrv"],
      "dst": ["tag:fgsrv:*"]
    }
  ]
}
```

Apply tags during authentication:

```bash
sudo tailscale up --tags=tag:fgsrv
```

---

## Configuration Options

### Enable IP Forwarding (for subnet router/exit node)

```bash
# Enable IPv4 forwarding
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.d/99-tailscale.conf
echo "net.ipv6.conf.all.forwarding = 1" | sudo tee -a /etc/sysctl.d/99-tailscale.conf
sudo sysctl -p /etc/sysctl.d/99-tailscale.conf
```

### Configure as Subnet Router

```bash
# Advertise subnet route (example: 192.168.1.0/24)
sudo tailscale up --advertise-routes=192.168.1.0/24

# Note: Must approve routes in Tailscale admin console
```

### Configure DNS

Enable MagicDNS and configure nameservers:

```bash
# Reset DNS to Tailscale defaults
sudo tailscale up --reset

# Configure custom DNS
sudo tailscale up --accept-dns=false
```

### Port Configuration

Tailscale requires these ports:
- **UDP 41641**: Primary WireGuard port
- **UDP/TCP 443**: DERP (relay) fallback
- **TCP 80**: HTTP for authentication

Firewall rules:

```bash
# UFW example
sudo ufw allow 41641/udp
sudo ufw allow 443/tcp
sudo ufw allow from 100.64.0.0/10
```

---

## Troubleshooting

### Issue: Cannot Connect to Tailscale Network

**Symptoms**: `tailscale status` shows no peers, connection timeouts

**Solutions**:

```bash
# Check if tailscaled is running
systemctl status tailscaled

# Restart the service
sudo systemctl restart tailscaled

# Check logs for errors
journalctl -u tailscaled -f

# Verify network connectivity
ping -c 3 1.1.1.1

# Check if port 41641 is open
sudo ss -ulnp | grep 41641

# Force re-authentication
sudo tailscale down
sudo tailscale up
```

### Issue: DERP Relay Being Used (Direct Connection Failed)

**Symptoms**: `tailscale status` shows "via DERP"

**Solutions**:

```bash
# Check firewall rules
sudo iptables -L -n -v

# Ensure UDP 41641 is allowed
sudo ufw status verbose

# Test UDP connectivity
nc -uzv 100.x.x.x 41641

# Check NAT traversal
tailscale status --json | grep -i "DERP"
```

### Issue: High CPU Usage

**Symptoms**: tailscaled process using excessive CPU

**Solutions**:

```bash
# Check tailscaled resource usage
top -p $(pgrep tailscaled)

# Restart with debugging
sudo systemctl stop tailscaled
sudo tailscaled --verbose=2

# Check for connection loops
tailscale netcheck
```

### Issue: DNS Resolution Problems

**Symptoms**: Cannot resolve node names like `fgsrv03.ts.net`

**Solutions**:

```bash
# Check DNS configuration
cat /etc/resolv.conf

# Test MagicDNS
nslookup fgsrv03.your-tailnet.ts.net

# Reset DNS to Tailscale
sudo tailscale up --reset

# Configure global nameservers in Tailscale admin console
```

### Issue: Cannot Authenticate

**Symptoms**: Browser shows error, cannot complete auth flow

**Solutions**:

```bash
# Generate new machine key
sudo rm /var/lib/tailscale/tailscaled.state
sudo systemctl restart tailscaled
sudo tailscale up

# Check browser console for errors
# Verify Tailscale account access
# Check if device limit reached in admin console
```

### Issue: Connection Drops Frequently

**Solutions**:

```bash
# Check internet stability
ping -i 1 1.1.1.1

# Enable more aggressive keepalive
sudo tailscale up --port 41641 --reset

# Check for MTU issues
ip link show

# Adjust MTU if needed (e.g., for VPN environments)
sudo ip link set dev tailscale0 mtu 1280
```

### Debug Commands

```bash
# Full network diagnostics
tailscale netcheck

# Detailed status with debugging info
tailscale status --peers --json

# Check DERP connections
tailscale status --json | jq '.DerpRoutes'

# View connection quality
tailscale ping <peer-ip>

# Run diagnostics
sudo tailscale bugreport
```

### Reinstallation

If all else fails, reinstall cleanly:

```bash
# Stop service
sudo systemctl stop tailscaled

# Remove package
sudo apt remove --purge -y tailscale

# Remove configuration and state
sudo rm -rf /var/lib/tailscale
sudo rm -f /etc/systemd/system/tailscale*.service
sudo rm -f /etc/default/tailscaled

# Reinstall
sudo apt update
sudo apt install -y tailscale
sudo tailscale up
```

---

## Security Considerations

### SSH Access

```bash
# Disable password authentication (key-based only)
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart sshd
```

### Firewall Configuration

```bash
# Install and configure UFW
sudo apt install -y ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow from 100.64.0.0/10
sudo ufw enable
```

### Tailscale ACLs

Review and configure ACLs in Tailscale admin console:
- Restrict tag ownership
- Implement least-privilege access
- Regular audit of device access

### Key Management

```bash
# View machine key
sudo cat /var/lib/tailscale/tailscaled.state | grep -i key

# Rotate keys (compromised machine)
sudo tailscale down
sudo rm /var/lib/tailscale/tailscaled.state
sudo tailscale up
```

### Updates

```bash
# Enable automatic updates
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades

# Manual update
sudo apt update && sudo apt install --only-upgrade tailscale
```

---

## Post-Installation Checklist

- [ ] Tailscale installed and authenticated
- [ ] Can ping all existing nodes (FGSRV03-06)
- [ ] Service enabled to start on boot
- [ ] Firewall configured correctly
- [ ] ACLs/tags configured in admin console
- [ ] SSH access verified via Tailscale IP
- [ ] DNS resolution working (MagicDNS)
- [ ] Exit node/subnet routes configured (if needed)
- [ ] Monitoring configured (if applicable)
- [ ] Documentation updated with Tailscale IP

---

## Useful Commands Reference

```bash
# Start Tailscale
sudo tailscale up

# Stop Tailscale
sudo tailscale down

# View status
tailscale status

# View IP addresses
tailscale ip

# List peers with details
tailscale status --peers

# Ping a peer
tailscale ping <peer-ip>

# Network diagnostics
tailscale netcheck

# View logs
journalctl -u tailscaled -f

# Restart service
sudo systemctl restart tailscaled

# Check version
tailscale version

# Bugreport for support
sudo tailscale bugreport

# Exit node status
tailscale status --json | jq -r '.ExitNodeStatus'
```

---

## Support & Resources

- **Tailscale Documentation**: https://tailscale.com/kb/
- **Debian 13 Release Notes**: https://www.debian.org/releases/stable/releasenotes
- **Tailscale GitHub**: https://github.com/tailscale/tailscale
- **Admin Console**: https://login.tailscale.com/admin/

---

## Document Information

**Created**: 2026-02-09
**Host**: FGSRV07
**OS**: Debian 13 (Trixie)
**Tailscale Version**: Latest stable
**Network Integration**: FGSRV03-06 existing nodes

---

**Next Steps**: After installation, verify connectivity with all existing nodes and document the assigned Tailscale IP address in network documentation.
