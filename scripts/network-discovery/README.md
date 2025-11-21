# Network Discovery Tools - OMAY Switch Detection

## Overview

This directory contains network discovery tools designed to identify OMAY managed switches and other network devices on the local network.

## Tools

### 1. **quick-switch-scan.sh** - Fast Network Scanner
Fast scan for devices with switch management interfaces (ports 22, 23, 80, 443).

**Usage:**
```bash
# Auto-detect subnet and scan
./quick-switch-scan.sh

# Scan specific subnet
./quick-switch-scan.sh 192.168.0.0/24
```

**Output:** List of devices with open management ports

---

### 2. **verify-omay-switch.sh** - Deep Device Verification
Comprehensive verification of suspected OMAY switches using multiple detection methods.

**Usage:**
```bash
# Verify single device
./verify-omay-switch.sh 192.168.0.254

# Verbose mode
VERBOSE=true ./verify-omay-switch.sh 192.168.0.254
```

**Detection Methods:**
- ✅ Connectivity check (ICMP ping)
- ✅ MAC address OUI lookup
- ✅ Port scanning (22, 23, 80, 443, 8080, 161)
- ✅ HTTP/HTTPS interface probing
- ✅ Telnet banner grab
- ✅ SSH banner grab
- ⚠️ SNMP discovery (optional - requires `snmp` package)

**Confidence Scoring:**
- **4-6/6**: High confidence - Likely OMAY switch
- **2-3/6**: Medium confidence - Manual verification needed
- **0-1/6**: Low confidence - Unlikely to be OMAY switch

---

### 3. **discover-omay-switches.sh** - Comprehensive Network Discovery
Full network discovery with multi-method scanning and detailed reporting.

**Usage:**
```bash
# Auto-detect and scan all local subnets
./discover-omay-switches.sh

# Scan specific subnet
./discover-omay-switches.sh 192.168.0.0/24
```

**Features:**
- Multi-method host discovery (ARP, ping sweep, nmap)
- Switch identification via MAC OUI patterns
- Port scanning and service detection
- Web interface probing
- JSON output for programmatic processing

**Output Files:**
- `results/omay_discovery_TIMESTAMP.txt` - Human-readable results
- `results/omay_discovery_TIMESTAMP.json` - Structured JSON data

---

### 4. **mac-lookup.sh** - MAC Address Vendor Lookup
Identifies device manufacturer from MAC address OUI.

**Usage:**
```bash
./mac-lookup.sh 00:31:92:dc:3e:f8
```

**Output:**
- MAC address and OUI
- Manufacturer name (via online API or local database)
- Known switch/router OUI notes

---

## Network Environment

**Current Environment:** CT179 (agldv03)

**Network Interfaces:**
- `eth0`: 192.168.0.179/24 (Primary LAN)
- `eth1`: 192.168.1.179/24 (Secondary LAN)
- `wg0`: 10.6.0.19/24 (WireGuard mesh)
- `tailscale0`: 100.94.221.87/32 (Tailscale VPN)

**Available Tools:**
- ✅ `nmap` - Network scanner
- ✅ `arp-scan` - ARP-based network discovery
- ✅ `fping` - Fast ping sweeps
- ✅ `curl` - HTTP/HTTPS probing
- ✅ `nc` (netcat) - Port checking

---

## OMAY Switch Identification

### Known OMAY MAC OUI Prefixes
⚠️ **Note:** Actual OMAY OUI prefixes need to be confirmed via research or manufacturer documentation.

Placeholder patterns (to be updated):
- `00:0E:C4` - Common Taiwanese manufacturer
- `00:11:22` - Example prefix
- `00:50:C2` - Another potential prefix

### Switch Detection Indicators
1. **Open Ports:**
   - Port 80/443: Web management interface
   - Port 23: Telnet (older models)
   - Port 22: SSH (newer models)
   - Port 161: SNMP (if enabled)

2. **HTTP/HTTPS Headers:**
   - Look for "OMAY" in server headers
   - BusyBox or similar embedded web servers
   - Switch-specific login pages

3. **SSH/Telnet Banners:**
   - May contain "OMAY" or model information
   - Generic "Switch Login" prompts

---

## Quick Start Guide

### Step 1: Quick Scan
```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman/scripts/network-discovery
./quick-switch-scan.sh
```

### Step 2: Verify Candidates
From the quick scan results, verify devices with ports 80+443 open:
```bash
./verify-omay-switch.sh 192.168.0.1
./verify-omay-switch.sh 192.168.0.254
```

### Step 3: Comprehensive Discovery (Optional)
For complete network mapping:
```bash
./discover-omay-switches.sh
cat results/omay_discovery_*.txt
```

---

## Scan Results Summary (2025-11-12)

### Subnet: 192.168.0.0/24

**High-Priority Candidates (HTTP + HTTPS):**
- `192.168.0.1` - Ports 80, 443
- `192.168.0.254` - Ports 22, 80, 443 (TP-Link - verified)
- `192.168.0.131-133` - Ports 22, 80, 443
- `192.168.0.137` - Ports 22, 80, 443
- `192.168.0.139` - Ports 22, 80, 443
- `192.168.0.161-162` - Ports 22, 80, 443
- `192.168.0.174` - Ports 80, 443 (agldv02.lan)
- `192.168.0.178` - Ports 22, 80, 443
- `192.168.0.180-181` - Ports 22, 80, 443

**Medium-Priority Candidates (HTTP only):**
- `192.168.0.102` - Ports 22, 80, 443 (pi.hole - PiHole server)
- `192.168.0.126` - Ports 22, 80
- `192.168.0.148-149` - Ports 22, 80
- `192.168.0.159` - Ports 22, 80, 443
- `192.168.0.235` - Port 80
- `192.168.0.242` - Port 80

**Low-Priority (SSH only):**
- Multiple LXC containers (192.168.0.103-202)
- Proxmox host (192.168.0.245)

---

## Next Steps

1. **Verify High-Priority Candidates:**
   ```bash
   for ip in 192.168.0.1 192.168.0.131 192.168.0.132 192.168.0.133; do
       ./verify-omay-switch.sh $ip
   done
   ```

2. **Check Web Interfaces:**
   - Open browser to `http://192.168.0.1`
   - Look for OMAY branding or switch management UI
   - Check default credentials (admin/admin, admin/password, etc.)

3. **Research MAC OUIs:**
   - Query IEEE OUI database for actual OMAY prefixes
   - Update MAC patterns in scripts

4. **Document Findings:**
   - Record confirmed OMAY switch IPs
   - Note model numbers and firmware versions
   - Update network topology documentation

---

## Troubleshooting

### Permission Denied (ARP Scan)
```bash
# ARP scan requires root/sudo
sudo ./discover-omay-switches.sh
```

### Timeout Issues
```bash
# Increase timeout in script or run on smaller subnets
./quick-switch-scan.sh 192.168.0.0/25
```

### Missing Dependencies
```bash
# Install required packages
apt-get update
apt-get install -y nmap arp-scan fping curl netcat-openbsd
```

### SNMP Not Working
```bash
# Install SNMP tools
apt-get install -y snmp

# Test SNMP manually
snmpwalk -v2c -c public 192.168.0.254 system
```

---

## Script Dependencies

| Tool | Package | Purpose |
|------|---------|---------|
| `nmap` | `nmap` | Port scanning and service detection |
| `arp-scan` | `arp-scan` | ARP-based host discovery |
| `fping` | `fping` | Fast ICMP ping sweeps |
| `curl` | `curl` | HTTP/HTTPS probing |
| `nc` | `netcat-openbsd` | Port connectivity testing |
| `snmpwalk` | `snmp` | SNMP queries (optional) |
| `ip` | `iproute2` | Network interface management |

---

## Security Notes

⚠️ **Important:**
- These tools perform **active scanning** which may trigger IDS/IPS alerts
- Always obtain authorization before scanning networks
- Default credentials should be changed on production switches
- SNMP community strings should be secured (avoid "public"/"private")

---

## License & Maintenance

**Project:** agl-hostman - AGL Infrastructure Management
**Maintainer:** Claude Code (Hive Mind Swarm)
**Last Updated:** 2025-11-12
**Version:** 1.0.0

---

## Additional Resources

- **INFRA.md**: Complete infrastructure documentation
- **HOSTS.md**: Detailed host configuration
- **CONTAINERS.md**: Container inventory
- **CONNECTIONS.md**: Network topology and connection matrix
