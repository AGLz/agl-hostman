# OMAY Switch Discovery - Network Analysis Report

> **Generated**: 2025-11-12 | **Analyst Agent**: Hive Mind Swarm
> **Objective**: Locate 2 OMAY OM-S107C-62TS switches in current network
> **Status**: Initial Analysis Phase

---

## 🎯 Executive Summary

**Swarm Objective**: Identify IP addresses of 2 OMAY OM-S107C-62TS managed switches deployed in the AGL infrastructure.

**Current Status**:
- ✅ Infrastructure documentation reviewed
- ✅ Network topology mapped
- ⏳ Awaiting network scan results from coder agent
- ⏳ Awaiting OMAY switch specifications from researcher agent

---

## 📋 OMAY OM-S107C-62TS Switch Profile

### Device Specifications (To Be Confirmed by Researcher)

**Expected Characteristics**:
- **Model**: OMAY OM-S107C-62TS
- **Type**: Managed Layer 2/3 Switch (62 ports)
- **Management Interfaces**: Likely HTTP/HTTPS (80/443), Telnet (23), SSH (22), SNMP (161/162)
- **Default Credentials**: TBD (researcher to provide)
- **MAC Address OUI**: TBD (researcher to identify OMAY vendor prefix)

### Typical Switch Management Ports

Based on standard managed switch configurations:
- **HTTP**: 80/tcp (Web management)
- **HTTPS**: 443/tcp (Secure web management)
- **Telnet**: 23/tcp (Legacy CLI access)
- **SSH**: 22/tcp (Secure CLI access)
- **SNMP**: 161/udp, 162/udp (Network monitoring)
- **TFTP**: 69/udp (Firmware/config transfer)

---

## 🌐 Network Scope Analysis

### Available Networks for Scanning

Based on current infrastructure (from CT179 position):

| Network Segment | CIDR | Location | Priority | Scan Status |
|----------------|------|----------|----------|-------------|
| **192.168.0.0/24** | Primary LAN | AGLHQ/AGLALD | ⭐⭐⭐ High | Pending |
| **192.168.1.0/24** | Inter-host | AGLALD | ⭐⭐ Medium | Pending |
| **10.6.0.0/24** | WireGuard Mesh | All locations | ⭐ Low | N/A (virtual) |
| 192.168.15.0/24 | AGLFG LAN | Remote | ⭐ Low | Remote |
| 172.2.2.0/24 | AGLFG secondary | Remote | ⭐ Low | Remote |

### Most Likely Switch Locations

**Hypothesis 1 - AGLHQ Network (192.168.0.0/24)**:
- Primary production network at headquarters
- AGLSRV1 location (192.168.0.245)
- Most active network with 68 containers
- **Probability**: 70%

**Hypothesis 2 - AGLALD Network (192.168.0.0/24 or 192.168.1.0/24)**:
- AGLSRV6/AGLSRV6C location
- Triple network configuration (vmbr0/1/2)
- 192.168.1.x designated as PRIMARY inter-host network
- **Probability**: 25%

**Hypothesis 3 - AGLFG Network (192.168.15.0/24)**:
- Remote standalone site (AGLSRV5)
- Independent network segment
- **Probability**: 5%

---

## 🔍 Switch Discovery Strategy

### Phase 1: Network Reconnaissance (IN PROGRESS)

**Coder Agent Tasks**:
1. ✅ Ping sweep on 192.168.0.0/24 and 192.168.1.0/24
2. ⏳ Port scanning for common switch management ports (22, 23, 80, 443, 161)
3. ⏳ Service version detection on discovered devices
4. ⏳ MAC address vendor lookup

**Expected Scan Commands**:
```bash
# Network sweep
nmap -sn 192.168.0.0/24 -oN network-sweep.txt

# Switch-specific port scan
nmap -p 22,23,80,443,161,162 -sV 192.168.0.0/24 -oN switch-scan.txt

# MAC address table
arp -n | grep -E "(192.168.0|192.168.1)"
```

### Phase 2: Device Fingerprinting (PENDING)

**Identification Criteria**:
1. **MAC Address Match**: OMAY vendor OUI prefix
2. **Open Ports**: HTTP/HTTPS + SSH/Telnet + SNMP
3. **Service Banners**: OMAY identification in HTTP headers or SSH banners
4. **Device Response**: Web interface with OMAY branding
5. **SNMP Response**: System description containing "OMAY" or "OM-S107C"

### Phase 3: Verification (PENDING)

**Tester Agent Tasks**:
1. Attempt HTTP/HTTPS connection to candidates
2. Check for OMAY web interface
3. SNMP query for system description
4. Document findings with screenshots/responses

---

## 📊 Network Scan Results Analysis

### Waiting for Coder Agent Data

**Expected Data Points**:
- Total live hosts on 192.168.0.0/24
- Total live hosts on 192.168.1.0/24
- Devices with switch management ports open
- MAC address vendor information
- Service version strings

### Known Infrastructure Devices (Exclude from Candidates)

From infrastructure documentation:

**192.168.0.0/24 Network**:
- 192.168.0.245 - AGLSRV1 (Proxmox host)
- 192.168.0.179 - CT179 (current position)
- 192.168.0.183 - CT183 (Archon)
- 192.168.0.102 - CT102 (Pi-hole)
- Multiple other documented containers

**192.168.1.0/24 Network**:
- 192.168.1.202 - AGLSRV6 (vmbr2)
- 192.168.1.233 - AGLSRV6C (vmbr2)
- 192.168.1.179 - CT179 eth1 (current position)

---

## 🎯 High-Confidence Switch Identification Patterns

### Pattern 1: MAC Address Vendor Match
```
Confidence: 95%
Criteria: MAC OUI matches OMAY manufacturer prefix
Action: Immediate high-priority candidate
```

### Pattern 2: Switch Port Profile
```
Confidence: 80%
Criteria: Open ports 80/443 + 22/23 + 161/162
         + No other services (no DNS, DHCP, etc.)
Action: Strong candidate - verify web interface
```

### Pattern 3: HTTP Banner Match
```
Confidence: 90%
Criteria: HTTP response contains "OMAY" or "OM-S107C"
Action: High-priority candidate - manual verification
```

### Pattern 4: SNMP System Description
```
Confidence: 85%
Criteria: SNMP sysDescr.0 contains "OMAY" or switch model
Action: Strong candidate - correlate with other data
```

### Pattern 5: Response Timing Profile
```
Confidence: 40%
Criteria: Very fast ping response (<0.1ms local)
         + Minimal port scan response time
Action: Possible switch - requires additional verification
```

---

## 🔐 Security Considerations

### Access Testing Protocol

**DO NOT**:
- Attempt brute-force attacks on discovered devices
- Perform aggressive port scans that might trigger alerts
- Access production switches without authorization
- Modify switch configurations

**DO**:
- Use passive reconnaissance first (ARP tables, existing logs)
- Perform non-intrusive service identification
- Document all findings for manual review
- Coordinate with network administrators for access testing

### Default Credentials Research

**Researcher Agent Task**:
- Identify OMAY OM-S107C-62TS default credentials
- Check for known CVEs or security advisories
- Document recommended security hardening steps

---

## 📝 Findings Log

### Session: 2025-11-12 22:35 UTC-3

**Environment Detection**:
- Current position: Container with dual network (192.168.0.179, 192.168.1.179)
- Likely CT179 based on IP pattern
- Network scanning tools availability: TBD
- ARP table entries: TBD

**Next Steps**:
1. ⏳ Wait for researcher agent to provide OMAY switch specifications
2. ⏳ Wait for coder agent to complete network scans
3. ⏳ Analyze scan results for switch candidates
4. ⏳ Correlate findings with OMAY-specific characteristics

---

## 🤝 Swarm Coordination Status

### Agent Responsibilities

| Agent | Role | Status | Key Deliverables |
|-------|------|--------|------------------|
| **Researcher** | OMAY switch specs | ⏳ Active | MAC OUI, default creds, mgmt ports |
| **Coder** | Network scanning | ⏳ Active | nmap results, ARP data, port scans |
| **Analyst** | Data correlation | ✅ Active | This analysis document |
| **Tester** | Verification | ⏳ Waiting | Switch access testing, confirmation |

### Collective Memory Keys

**Expected Memory Stores**:
- `omay/specifications` - Device technical specs
- `omay/mac-oui` - Manufacturer MAC prefix
- `omay/default-creds` - Default login credentials
- `network/scan-results` - Raw scan output
- `network/arp-table` - MAC address mappings
- `candidates/high-confidence` - Strong switch matches
- `candidates/medium-confidence` - Possible switches
- `findings/verified` - Confirmed switch IPs

---

## 🎯 Expected Outcomes

### Success Criteria

**Minimum Success**:
- Identify 2 IP addresses with high probability of being OMAY switches (>70% confidence)
- Document clear verification steps for manual confirmation

**Full Success**:
- Positively identify both OMAY OM-S107C-62TS switches with >95% confidence
- Verify access to management interfaces
- Document current configuration state
- Provide security assessment

### Confidence Levels

**High Confidence (>80%)**:
- MAC address vendor match
- HTTP interface shows OMAY branding
- SNMP system description contains model number
- All expected management ports open

**Medium Confidence (50-80%)**:
- Suspicious port profile (22/23/80/443/161 open)
- Fast ping response (likely network device)
- No other identifiable services
- Unknown MAC vendor

**Low Confidence (<50%)**:
- Single indicator match only
- Conflicting evidence
- Unusual port configuration

---

## 📚 References

- **Infrastructure Documentation**: `/mnt/overpower/apps/dev/agl/agl-hostman/docs/INFRA.md`
- **Network Topology**: `/mnt/overpower/apps/dev/agl/agl-hostman/docs/TOPOLOGY.md`
- **Network Tests**: `/mnt/overpower/apps/dev/agl/agl-hostman/docs/NETWORK-TESTS.md`
- **Swarm Session**: `swarm-1762997701184-yo61ppp32`

---

**Document Status**: Initial Analysis - Awaiting Scan Data
**Next Update**: After receiving network scan results from coder agent
**Coordination**: Hive Mind collective intelligence system

---

## 🚨 Critical Notes

1. **Network Scope**: Focusing on 192.168.0.0/24 as highest probability location
2. **Known Devices**: Must filter out documented Proxmox hosts and containers
3. **Verification Required**: All candidates require manual verification before final confirmation
4. **Security**: Non-intrusive scanning only - no unauthorized access attempts

**Analyst Agent Standing By**: Ready to process scan results and correlate findings.
