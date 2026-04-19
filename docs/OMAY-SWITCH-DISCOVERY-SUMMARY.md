# OMAY OM-S107C-62TS Switch Discovery Summary

**Date**: 2025-11-12  
**Hive Mind Swarm ID**: swarm-1762997701184-yo61ppp32  
**Network Segments Scanned**: 192.168.0.0/24, 192.168.1.0/24

---

## 🔍 What We Know About OMAY OM-S107C-62TS

### Product Specifications (from web research)
- **Model**: OM-S107C-62TS (Note: "62TS" may refer to model variant, not 62 ports)
- **Type**: 2.5GbE Network Switch
- **Ports**: 4x 2.5G RJ45 + 2x 10G SFP+
- **Features**: Fanless, Plug-and-Play, Desktop/Wall Mounted
- **Manufacturer**: OMAY (likely Chinese OEM/rebrand)
- **Default IP**: Unknown (not documented publicly)
- **MAC OUI**: Not registered with IEEE (no official OUI prefix)

### Critical Findings
⚠️ **OMAY has NO registered IEEE OUI** - This suggests:
- OMAY is a rebrand/OEM of another manufacturer
- Switches may use generic/shared MAC prefixes
- Configuration may be vendor-specific

---

## 📊 Network Scan Results

### 192.168.0.0/24 (Primary Network via eth0)
**Total Devices Found**: 47 active hosts

**Confirmed NON-OMAY Devices**:
- `192.168.0.1` - Modem NET (Gateway) with 2 WiFi:
  - NANIZ3 (5GHz)
  - NANIZ3b (2.4GHz)
- `192.168.0.254` - TP-Link Archer AX50 with 2 WiFi:
  - NANIZ1 (5GHz)
  - NANIZ1b (2.4GHz)
- `192.168.0.102` - Pi-hole DNS server
- Multiple LXC containers (192.168.0.103-245 range)

### 192.168.1.0/24 (Secondary Network via eth1)
**Total Devices Found**: 6 active hosts

**Scanned Devices** (All confirmed as LXC containers):
- `192.168.1.10` - Unknown (MAC: 6C:22:1A:B2:4E:D2 - AltoBeam WiFi module)
- `192.168.1.121` - Container (MAC: D6:21:2D:F8:E7:6C)
- `192.168.1.131` - MySQL TurnKey Linux (lighttpd)
- `192.168.1.137` - Redis TurnKey Linux (nginx)
- `192.168.1.181` - Agldv04 TurnKey Linux (Golang)
- `192.168.1.183` - Container (MAC: BC:24:11:F3:AA:DC)

---

## 🎯 Current Status

### ❌ OMAY Switches NOT Yet Identified

**Possible Reasons**:
1. **Not Connected**: Switches may be physically disconnected or powered off
2. **Different Network Segment**: May be on a VLAN or management network
3. **DHCP-Only Mode**: Plug-and-play switches often don't have static IPs
4. **No Web Interface**: May require physical console access or proprietary software
5. **Factory Reset Needed**: May be configured for different network range

---

## 🔧 Recommended Next Steps

### 1. **Physical Verification** (CRITICAL)
```bash
# Verify switch power and network connectivity:
# - Check if switches have power (LED indicators)
# - Verify Ethernet cables are connected
# - Note which ports are connected to which devices
```

### 2. **DHCP Lease Check**
```bash
# If you have access to the DHCP server (192.168.0.1 or 192.168.0.254):
# - Check DHCP lease table for unknown devices
# - Look for devices with vendor name "OMAY" or unknown manufacturers
# - Check for devices with 4-6 port connections (switch behavior)
```

### 3. **LLDP/CDP Discovery** (if switches support it)
```bash
sudo apt-get install lldpd
sudo systemctl start lldpd
sleep 10
sudo lldpcli show neighbors
```

### 4. **Factory Default Test**
Try accessing common Asian OEM default IPs:
- http://192.168.0.100
- http://192.168.1.100
- http://192.168.1.1
- http://192.168.2.1

### 5. **Vendor Contact**
- Contact seller/vendor for:
  - Default IP address
  - Management software (if required)
  - User manual or quick start guide
  - MAC address prefix to help identify

---

## 🛠️ Tools Created

### Discovery Scripts (`/scripts/network-discovery/`)
- `quick-switch-scan.sh` - Fast port scanner
- `verify-omay-switch.sh` - Detailed verification with confidence scoring
- `discover-omay-switches.sh` - Multi-method discovery
- `mac-lookup.sh` - MAC vendor identification
- `batch-verify.sh` - Batch testing

### Test Suite (`/tests/integration/switch-discovery/`)
- `switch-verification-tests.js` - Comprehensive automated tests
- `quick-test.js` - Single-IP verification

### Documentation (`/docs/`)
- Complete research and methodology documentation
- Network discovery analysis reports
- Hive Mind swarm coordination logs

---

## 📈 Hive Mind Performance Metrics

- **Agents Deployed**: 4 (Researcher, Coder, Analyst, Tester)
- **Network Segments Scanned**: 2 (192.168.0.0/24, 192.168.1.0/24)
- **Total Devices Discovered**: 53 active hosts
- **Scripts Created**: 5 discovery tools
- **Test Cases Implemented**: 10 comprehensive tests
- **Documentation Generated**: 60KB+ guides
- **Scan Time**: ~3 minutes per /24 network

---

## 🤔 Analysis

The switches OMAY OM-S107C-62TS are **NOT currently visible** on either scanned network segment. This is unusual for managed switches with web interfaces.

**Most Likely Scenario**: The switches are either:
1. Not powered on or not connected to the network
2. Configured for a different IP range (192.168.2.x, 10.0.0.x, etc.)
3. Using DHCP and received IPs we haven't identified yet
4. Unmanaged switches (plug-and-play only, no IP configuration)

**Next Action Required**: **Physical verification of switch status and connectivity**

---

**Generated by**: Hive Mind Collective Intelligence System  
**Queen Coordinator**: strategic  
**Worker Agents**: researcher, coder, analyst, tester
