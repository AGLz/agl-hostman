# OMAY OM-S107C-62TS Switch Discovery - Test Plan

## Executive Summary

This test plan outlines the comprehensive verification strategy for discovered OMAY OM-S107C-62TS network switches in the AGL infrastructure. The testing is coordinated through the Hive Mind swarm system with researcher, tester, and analyst agents.

## Objectives

### Primary Goals

1. **Verify discovered switches** against OMAY OM-S107C-62TS specifications
2. **Validate connectivity** and accessibility from infrastructure nodes
3. **Identify access methods** for switch management
4. **Assess security posture** of discovered devices
5. **Document findings** for infrastructure integration

### Success Criteria

- ✅ Confirm switch model with ≥80% confidence
- ✅ Identify viable access method (HTTP/HTTPS)
- ✅ Document MAC address and network location
- ✅ Assess security concerns (default credentials, open ports)
- ✅ Provide actionable recommendations for each candidate

## Test Strategy

### Phase-Based Approach

```
┌─────────────────────────────────────────────────────────────┐
│                    Discovery Process Flow                    │
└─────────────────────────────────────────────────────────────┘

Phase 1: Research (Researcher Agent)
  ↓ Discovers candidate IPs through:
  ↓ - Network scans
  ↓ - DHCP logs
  ↓ - ARP tables
  ↓ - Router configurations
  ↓
Phase 2: Verification (Tester Agent) ← YOU ARE HERE
  ↓ Tests each candidate:
  ↓ - Connectivity (ping, TCP ports)
  ↓ - Service identification (web, SNMP)
  ↓ - Model verification (web UI, MAC OUI)
  ↓ - Security assessment
  ↓
Phase 3: Analysis (Analyst Agent)
  ↓ Reviews test results:
  ↓ - Confirms model match
  ↓ - Validates access methods
  ↓ - Prioritizes findings
  ↓ - Generates final report
  ↓
Phase 4: Documentation
  ↓ Updates infrastructure docs:
  ↓ - Network topology
  ↓ - Device inventory
  ↓ - Access procedures

```

### Test Levels

1. **Unit Tests** - Individual test functions
   - Ping connectivity
   - Port scanning
   - Banner grabbing
   - MAC lookup

2. **Integration Tests** - Combined test sequences
   - Full candidate verification
   - Multi-phase testing
   - Result aggregation

3. **System Tests** - End-to-end validation
   - Complete discovery workflow
   - Swarm coordination
   - Documentation updates

## Test Environment

### Source Locations

Tests can be executed from:

| Source | Networks | Best For | Limitations |
|--------|----------|----------|-------------|
| **CT179** | LAN + WG + TS | Full infrastructure access | None |
| **WSL2** | TS only | Remote testing | No LAN/WG access |
| **CT108** | TS only | AGLALD local testing | No LAN at other sites |
| **AGLSRV1** | LAN + WG + TS | Direct host testing | Requires host access |

### Target Networks

| Network | CIDR | Locations | Priority |
|---------|------|-----------|----------|
| LAN AGLHQ | 192.168.0.0/24 | AGLHQ, AGLALD | High |
| LAN AGLFG | 192.168.15.0/24 | AGLFG | Medium |
| LAN AGLALD Alt | 192.168.1.0/24 | AGLALD inter-host | Medium |
| WireGuard | 10.6.0.0/24 | All sites | Low (switches unlikely) |

### Tools Required

```bash
# Network tools
ping           # ICMP connectivity
curl           # HTTP/HTTPS testing
arp            # MAC address lookup
nmap           # Port scanning (optional)
snmpget        # SNMP queries (if managed)

# Node.js dependencies
node-fetch     # HTTP requests
ping (npm)     # Programmatic ping
dns            # DNS resolution
net            # TCP connections
```

## Test Cases

### TC-001: Basic Connectivity Test

**Objective**: Verify IP is reachable and responsive

**Prerequisites**:
- Candidate IP from researcher agent
- Network access to target segment

**Steps**:
1. Execute ICMP ping to candidate IP
2. Measure response time and packet loss
3. Verify consistent responses (3 attempts)

**Expected Results**:
- ✅ Ping successful (0% packet loss)
- ✅ Latency < 10ms (local network)
- ✅ Consistent responses

**Acceptance Criteria**:
- Ping success rate ≥ 90%
- Average latency < 50ms

---

### TC-002: MAC Address Discovery

**Objective**: Identify device MAC address for OUI lookup

**Prerequisites**:
- TC-001 passed (device reachable)
- ARP functionality available

**Steps**:
1. Check ARP table for existing entry
2. If not present, ping device first
3. Query ARP table for MAC address
4. Extract MAC address from results

**Expected Results**:
- ✅ MAC address discovered
- ✅ Valid MAC format (XX:XX:XX:XX:XX:XX)
- ✅ Consistent across multiple queries

**Acceptance Criteria**:
- MAC address retrieved successfully
- Format validation passes

---

### TC-003: Port Scanning

**Objective**: Identify open TCP ports for service detection

**Prerequisites**:
- TC-001 passed (device reachable)

**Steps**:
1. Scan common management ports: 80, 443, 23, 22, 161, 8080, 8443
2. Test TCP connectivity to each port (3-second timeout)
3. Record open ports
4. Categorize by service type

**Expected Results**:
- ✅ At least one port open (80 or 443 for web interface)
- ✅ Port 23 (telnet) closed (unmanaged switch)
- ✅ Port 161 (SNMP) closed (unmanaged switch)

**Acceptance Criteria**:
- HTTP (80) or HTTPS (443) port open
- Telnet and SNMP ports closed (confirms unmanaged)

---

### TC-004: Web Interface Detection

**Objective**: Verify web management interface accessibility

**Prerequisites**:
- TC-003 passed with port 80 or 443 open

**Steps**:
1. Attempt HTTP connection to port 80
2. Attempt HTTPS connection to port 443
3. Retrieve HTTP headers
4. Record server type and response

**Expected Results**:
- ✅ Web interface accessible
- ✅ Valid HTTP response (200 OK or redirect)
- ✅ Server header present

**Acceptance Criteria**:
- At least one protocol (HTTP/HTTPS) responds
- No authentication required for detection

---

### TC-005: Banner Grabbing

**Objective**: Extract service banners for identification

**Prerequisites**:
- TC-003 passed with open ports identified

**Steps**:
1. For each open port, establish TCP connection
2. Send generic probe (CRLF)
3. Capture response banner
4. Parse banner for identifying information

**Expected Results**:
- ✅ Banner retrieved from at least one port
- ✅ Banner contains useful identification info

**Acceptance Criteria**:
- Banner successfully captured
- No connection errors

---

### TC-006: MAC Vendor Verification

**Objective**: Confirm device manufacturer via OUI lookup

**Prerequisites**:
- TC-002 passed (MAC address discovered)

**Steps**:
1. Extract OUI (first 6 hex digits) from MAC
2. Query MAC vendor API (macvendors.com)
3. Compare result with "OMAY" manufacturer
4. Record vendor information

**Expected Results**:
- ✅ OUI lookup successful
- ✅ Vendor name contains "OMAY" (if genuine OMAY switch)

**Acceptance Criteria**:
- OUI lookup completes successfully
- Vendor information retrieved

---

### TC-007: Model Verification from Web UI

**Objective**: Extract model information from web interface

**Prerequisites**:
- TC-004 passed (web interface accessible)

**Steps**:
1. Fetch web interface HTML content
2. Search for model indicators:
   - "OMAY" brand name
   - "OM-S107C-62TS" model number
   - "S107C" model variant
   - "switch" device type
3. Calculate confidence score based on matches
4. Determine if model confirmed

**Expected Results**:
- ✅ Model indicators found in web content
- ✅ Confidence score ≥ 50%

**Acceptance Criteria**:
- Confidence score ≥ 80% for "verified" status
- At least 2 of 4 indicators present for "likely" status

---

### TC-008: Default Credential Testing

**Objective**: Identify security vulnerabilities (default passwords)

**Prerequisites**:
- TC-004 passed (web interface accessible)

**Steps**:
1. Test common default credentials:
   - admin/admin
   - admin/(blank)
   - admin/password
   - root/admin
   - (blank)/(blank)
2. Send HTTP Basic Auth for each combination
3. Check for successful authentication
4. Record vulnerable credentials

**Expected Results**:
- ⚠️  No default credentials accepted (secure configuration)
- 🚨 If default credentials work, flag as security concern

**Acceptance Criteria**:
- All credential tests attempted
- Results clearly documented
- Security concerns escalated if vulnerable

---

### TC-009: Management Port Security Check

**Objective**: Assess exposure of management interfaces

**Prerequisites**:
- TC-003 passed (port scan complete)

**Steps**:
1. Review open ports from scan results
2. Categorize ports by risk:
   - Low: 80, 443 (expected)
   - Medium: 8080, 8443 (alternative web)
   - High: 23, 22, 161 (management protocols)
3. Calculate security concern level
4. Generate recommendations

**Expected Results**:
- ✅ Only web ports (80, 443) open = LOW concern
- ⚠️  Additional ports open = MEDIUM concern
- 🚨 Management protocols open = HIGH concern

**Acceptance Criteria**:
- All open ports evaluated
- Concern level assigned
- Recommendations provided

---

### TC-010: Full Candidate Verification

**Objective**: Complete end-to-end verification workflow

**Prerequisites**:
- All previous test cases defined
- Candidate IP provided by researcher

**Steps**:
1. Execute connectivity tests (TC-001, TC-002, TC-003)
2. Execute service identification (TC-004, TC-005)
3. Execute model verification (TC-006, TC-007)
4. Execute security assessment (TC-008, TC-009)
5. Generate comprehensive report
6. Provide recommendation

**Expected Results**:
- ✅ All test phases complete
- ✅ Results aggregated in structured format
- ✅ Recommendation generated

**Acceptance Criteria**:
- Report includes all test results
- Verification status determined (verified/likely/unlikely)
- Access method identified (if available)
- Security concerns documented
- Next steps provided

## Test Data

### Sample Candidate IPs

```javascript
// High-priority candidates (AGLHQ)
{ ip: '192.168.0.???', network: 'LAN', location: 'AGLHQ', priority: 'high' }

// Medium-priority candidates (AGLALD)
{ ip: '192.168.0.???', network: 'LAN', location: 'AGLALD', priority: 'medium' }
{ ip: '192.168.1.???', network: 'LAN-Alt', location: 'AGLALD', priority: 'medium' }

// Low-priority candidates (AGLFG)
{ ip: '192.168.15.???', network: 'LAN', location: 'AGLFG', priority: 'low' }
```

**NOTE**: Actual IPs to be provided by researcher agent after discovery phase.

### Expected Switch Characteristics

Based on OMAY OM-S107C-62TS specifications:

```javascript
{
  model: 'OMAY OM-S107C-62TS',
  type: 'unmanaged',
  ports: {
    ethernet: 7,
    fiber: 1,
    total: 8
  },
  management: {
    web: true,          // Has web interface
    telnet: false,      // No telnet (unmanaged)
    ssh: false,         // No SSH (unmanaged)
    snmp: false         // No SNMP (unmanaged)
  },
  protocols: {
    http: true,
    https: true         // May support HTTPS
  }
}
```

## Risk Assessment

### Testing Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| **Network disruption** | Low | Read-only tests, no config changes |
| **False positives** | Medium | Multiple verification methods, confidence scoring |
| **Timeout issues** | Low | Configurable timeouts, retry logic |
| **Permission denied** | Medium | Test from authorized sources, document access |
| **Default creds discovered** | High | Immediate escalation, security team notification |

### Security Considerations

- **Authorization**: All testing authorized by network administrators
- **Non-invasive**: No configuration changes attempted
- **Read-only**: All tests are passive or read-only
- **Secure reporting**: Security findings reported through proper channels
- **Credential testing**: Limited to publicly known defaults only

## Test Execution

### Execution Order

1. **Pre-execution** (5 minutes)
   - Load candidate IPs from researcher
   - Verify test environment
   - Confirm network connectivity

2. **Test execution** (10-15 minutes per candidate)
   - Run full test suite
   - Capture all results
   - Handle errors gracefully

3. **Post-execution** (10 minutes)
   - Aggregate results
   - Generate reports
   - Store in coordination memory
   - Notify analyst agent

### Parallel Testing

For multiple candidates, tests can be parallelized:

```javascript
const candidates = [...]; // From researcher
const results = await Promise.all(
  candidates.map(c => runner.testCandidate(c))
);
```

**Caution**: Limit parallelism to avoid network flooding (max 5 concurrent).

## Reporting

### Test Report Format

```json
{
  "timestamp": "2025-01-12T10:30:00.000Z",
  "tester": "tester-agent",
  "coordinator": "hive-mind-swarm",
  "totalCandidates": 5,
  "summary": {
    "total": 5,
    "verified": 3,
    "likely": 1,
    "unlikely": 1,
    "reachable": 5,
    "webAccessible": 4,
    "securityConcerns": 2
  },
  "verifiedSwitches": [
    {
      "ip": "192.168.0.1",
      "location": "AGLHQ",
      "confidence": 95,
      "accessMethod": "HTTPS (Port 443)",
      "mac": "00:11:22:33:44:55",
      "vendor": "OMAY Technologies"
    }
  ],
  "securityFindings": [
    {
      "ip": "192.168.0.2",
      "concern": "DEFAULT_CREDENTIALS",
      "severity": "HIGH",
      "details": "Accepts admin/admin login"
    }
  ]
}
```

### Coordination with Swarm

```javascript
// Store results for analyst consumption
mcp__claude-flow__memory_usage({
  action: "store",
  key: "swarm/tester/switch-verification",
  namespace: "coordination",
  value: JSON.stringify({
    agent: "tester",
    status: "completed",
    timestamp: Date.now(),
    verifiedCount: results.summary.verified,
    securityConcerns: results.summary.securityConcerns,
    reportPath: "/mnt/overpower/apps/dev/agl/agl-hostman/tests/integration/switch-discovery/verification-results.json"
  })
});

// Notify analyst agent
mcp__claude-flow__memory_usage({
  action: "store",
  key: "swarm/analyst/pending-review",
  namespace: "coordination",
  value: JSON.stringify({
    from: "tester",
    action: "review_switch_verification",
    priority: "high",
    resultsReady: true
  })
});
```

## Acceptance Criteria

### Test Suite Acceptance

- ✅ All 10 test cases implemented
- ✅ Error handling in place
- ✅ Timeout configuration validated
- ✅ Results format documented
- ✅ Coordination protocol defined

### Verification Acceptance

For each candidate switch:

- ✅ **VERIFIED** (80-100% confidence)
  - Model confirmed through multiple indicators
  - Web interface accessible
  - MAC vendor matches OMAY (if applicable)
  - Access method documented

- ⚠️  **LIKELY** (50-79% confidence)
  - Some model indicators present
  - Web interface accessible
  - Manual verification recommended

- ❌ **UNLIKELY** (0-49% confidence)
  - Few or no model indicators
  - May not be target switch
  - Consider for researcher re-evaluation

## Schedule

### Test Development

- [x] Test plan created
- [x] Test suite implemented
- [ ] Unit tests validated (pending candidate IPs)
- [ ] Integration tests validated (pending execution)
- [ ] Documentation complete

### Test Execution

- [ ] Receive candidate IPs from researcher (pending)
- [ ] Execute test suite (15-20 min per candidate)
- [ ] Generate reports (5 min)
- [ ] Coordinate with analyst (10 min)

**Total estimated time**: 30-60 minutes (depending on candidate count)

## Deliverables

1. **Test Suite** (`switch-verification-tests.js`)
   - Complete implementation
   - All test categories
   - Error handling
   - Result aggregation

2. **Test Documentation**
   - README.md (usage guide)
   - Test plan (this document)
   - Configuration examples

3. **Test Results** (`verification-results.json`)
   - JSON format
   - Structured results
   - Recommendations
   - Security findings

4. **Coordination Reports**
   - Hive Mind memory updates
   - Analyst handoff documentation
   - Security escalations (if needed)

## References

### Infrastructure Documentation

- INFRA.md - Infrastructure map
- TOPOLOGY.md - Physical locations and networks
- HOSTS.md - Host configurations
- CONNECTIONS.md - Connection matrix

### External Resources

- OMAY OM-S107C-62TS Datasheet
- MAC Vendor API: https://api.macvendors.com/
- Testing Standards: IEEE 802.3 Ethernet

### Related Test Plans

- Harbor CT182 Test Plan: `/mnt/overpower/apps/dev/agl/agl-hostman/tests/harbor-ct182-test-plan.md`
- Testing Architecture: `/mnt/overpower/apps/dev/agl/agl-hostman/docs/TESTING-ARCHITECTURE.md`

---

**Document Version**: 1.0.0
**Last Updated**: 2025-01-12
**Author**: Tester Agent (Hive Mind Swarm)
**Status**: Ready for execution
**Next Step**: Await candidate IPs from researcher agent
