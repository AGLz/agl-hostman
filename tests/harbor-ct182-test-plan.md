# Harbor CT182 Deployment Test Plan

## Executive Summary

This comprehensive test plan validates the Harbor container registry deployment on Proxmox LXC container CT182. It covers pre-installation validation, installation verification, network connectivity, functionality, performance, and security testing.

## Test Environment

- **Target**: Proxmox LXC Container CT182
- **OS**: Debian 12 (Bookworm)
- **Network**: VLAN 100 (192.168.100.0/24)
- **IP Address**: 192.168.100.182/24
- **Gateway**: 192.168.100.1
- **Storage**: ZFS pool (rpool/data)
- **Memory**: 4GB RAM (recommended minimum)
- **CPU**: 2 cores (recommended minimum)

## Test Phases

### Phase 1: Pre-Installation Validation
**Objective**: Verify system readiness before Harbor installation

**Test Cases**:
1. **T-PRE-001**: Container resource validation
2. **T-PRE-002**: Network configuration verification
3. **T-PRE-003**: Storage space validation
4. **T-PRE-004**: DNS resolution testing
5. **T-PRE-005**: Firewall rules validation
6. **T-PRE-006**: SSL/TLS certificate validation

### Phase 2: Installation Verification
**Objective**: Validate successful Harbor installation and deployment

**Test Cases**:
1. **T-INST-001**: Docker Engine installation
2. **T-INST-002**: Docker Compose installation
3. **T-INST-003**: Harbor download and extraction
4. **T-INST-004**: Harbor configuration validation
5. **T-INST-005**: Harbor service startup
6. **T-INST-006**: Harbor component health check

### Phase 3: Network Connectivity
**Objective**: Verify network accessibility and routing

**Test Cases**:
1. **T-NET-001**: Internal network connectivity
2. **T-NET-002**: External network connectivity
3. **T-NET-003**: DNS resolution from container
4. **T-NET-004**: Harbor web UI accessibility
5. **T-NET-005**: Docker registry API endpoint
6. **T-NET-006**: SSL/TLS handshake validation

### Phase 4: Harbor Functionality
**Objective**: Test core Harbor registry features

**Test Cases**:
1. **T-FUNC-001**: Admin login authentication
2. **T-FUNC-002**: Project creation and management
3. **T-FUNC-003**: User and role management
4. **T-FUNC-004**: Docker image push operation
5. **T-FUNC-005**: Docker image pull operation
6. **T-FUNC-006**: Image scanning functionality
7. **T-FUNC-007**: Replication configuration
8. **T-FUNC-008**: Webhook notifications
9. **T-FUNC-009**: Garbage collection
10. **T-FUNC-010**: API endpoint functionality

### Phase 5: Performance Benchmarks
**Objective**: Measure Harbor performance metrics

**Test Cases**:
1. **T-PERF-001**: Web UI response time
2. **T-PERF-002**: Image push performance (small)
3. **T-PERF-003**: Image push performance (large)
4. **T-PERF-004**: Image pull performance
5. **T-PERF-005**: Concurrent push/pull operations
6. **T-PERF-006**: Database query performance
7. **T-PERF-007**: Resource utilization monitoring

### Phase 6: Security Validation
**Objective**: Verify security controls and compliance

**Test Cases**:
1. **T-SEC-001**: SSL/TLS certificate validation
2. **T-SEC-002**: Authentication mechanism testing
3. **T-SEC-003**: Authorization and RBAC testing
4. **T-SEC-004**: Vulnerability scanning functionality
5. **T-SEC-005**: Image signing and verification
6. **T-SEC-006**: Audit log validation
7. **T-SEC-007**: Network security controls
8. **T-SEC-008**: Secret management validation

## Test Case Details

### T-PRE-001: Container Resource Validation
- **Priority**: High
- **Prerequisites**: Proxmox access
- **Steps**:
  1. Verify CPU allocation (minimum 2 cores)
  2. Verify RAM allocation (minimum 4GB)
  3. Verify storage allocation (minimum 100GB)
  4. Check swap configuration
- **Expected Results**: Resources meet minimum requirements
- **Acceptance Criteria**: All resource checks pass

### T-PRE-002: Network Configuration Verification
- **Priority**: High
- **Prerequisites**: Container created with network configuration
- **Steps**:
  1. Verify IP address assignment (192.168.100.182)
  2. Verify subnet mask (/24)
  3. Verify gateway configuration (192.168.100.1)
  4. Verify VLAN 100 membership
  5. Test ping to gateway
  6. Test ping to external host
- **Expected Results**: Network fully configured and operational
- **Acceptance Criteria**: All connectivity tests pass

### T-INST-001: Docker Engine Installation
- **Priority**: Critical
- **Prerequisites**: Clean Debian 12 container
- **Steps**:
  1. Execute Docker installation script
  2. Verify Docker daemon running
  3. Check Docker version
  4. Validate Docker socket permissions
  5. Run `docker run hello-world` test
- **Expected Results**: Docker Engine 24.0+ installed and functional
- **Acceptance Criteria**: Docker commands execute successfully

### T-FUNC-004: Docker Image Push Operation
- **Priority**: Critical
- **Prerequisites**: Harbor running, authenticated
- **Steps**:
  1. Pull test image (alpine:latest)
  2. Tag image for Harbor registry
  3. Push image to Harbor
  4. Verify image in Harbor UI
  5. Validate image metadata
- **Expected Results**: Image successfully pushed and visible
- **Acceptance Criteria**: Push completes without errors, image accessible

### T-PERF-002: Image Push Performance (Small)
- **Priority**: Medium
- **Prerequisites**: Harbor functional, test images ready
- **Steps**:
  1. Prepare 10MB test image
  2. Measure push operation time
  3. Calculate throughput (MB/s)
  4. Monitor CPU and memory usage
  5. Repeat 5 times for average
- **Expected Results**: Push completes in <30 seconds
- **Acceptance Criteria**: Average push time meets performance baseline

### T-SEC-001: SSL/TLS Certificate Validation
- **Priority**: Critical
- **Prerequisites**: Harbor configured with TLS
- **Steps**:
  1. Verify certificate chain validity
  2. Check certificate expiration date
  3. Validate certificate hostname
  4. Test TLS 1.2/1.3 support
  5. Verify cipher suite configuration
  6. Test with SSL Labs or similar
- **Expected Results**: Valid certificate, secure TLS configuration
- **Acceptance Criteria**: A rating on SSL Labs (if applicable)

## Test Data

### Test Images
- **Small**: alpine:latest (~5MB)
- **Medium**: nginx:latest (~150MB)
- **Large**: Custom image (~1GB)

### Test Credentials
- **Admin User**: admin / Harbor12345 (default, change after testing)
- **Test User**: testuser / TestPass123!
- **Test Project**: test-project

## Success Criteria

### Critical (Must Pass)
- All pre-installation validations pass
- Docker Engine and Compose installed successfully
- Harbor services start and remain healthy
- Admin can log in via web UI
- Docker image push/pull operations succeed
- SSL/TLS configured correctly

### High Priority (Should Pass)
- All network connectivity tests pass
- User and project management functional
- Image scanning operational
- Performance meets baseline metrics
- Security controls validated

### Medium Priority (Nice to Have)
- Advanced features (replication, webhooks) functional
- Garbage collection operational
- API endpoints fully functional
- Comprehensive audit logging

## Test Execution Schedule

1. **Day 1**: Pre-installation validation (Phase 1)
2. **Day 1**: Installation and verification (Phase 2)
3. **Day 2**: Network and functionality testing (Phases 3-4)
4. **Day 2**: Performance benchmarks (Phase 5)
5. **Day 3**: Security validation (Phase 6)
6. **Day 3**: Regression testing and reporting

## Risk Assessment

### High Risk
- **Network connectivity issues**: Mitigate with thorough network pre-checks
- **Storage performance**: Validate ZFS configuration before installation
- **Resource constraints**: Ensure adequate CPU/RAM allocation

### Medium Risk
- **SSL/TLS certificate issues**: Prepare backup certificates
- **DNS resolution problems**: Configure fallback DNS servers
- **Docker version compatibility**: Test with known-good versions

### Low Risk
- **Web UI accessibility**: Alternative CLI access available
- **Image scanning delays**: Can be configured post-deployment

## Rollback Plan

If critical tests fail:
1. **Snapshot rollback**: Revert to pre-installation ZFS snapshot
2. **Service restart**: Restart Harbor services if only service issues
3. **Configuration restore**: Restore known-good configuration
4. **Full rebuild**: Destroy and recreate container if corrupted

## Test Reporting

### Deliverables
- Test execution report (Markdown)
- Performance benchmark results (JSON)
- Security validation report (Markdown)
- Issue log with severity ratings
- Recommendations document

### Metrics Tracked
- Test pass/fail rate
- Performance baselines
- Resource utilization
- Time to complete installation
- Issues discovered and resolved

## Appendices

### A. Network Diagram
```
┌─────────────────────────────────────┐
│     Proxmox Host (fgsrv6)           │
│  ┌───────────────────────────────┐  │
│  │   VLAN 100 (192.168.100.0/24) │  │
│  │  ┌─────────────────────────┐  │  │
│  │  │  CT182 Harbor Registry  │  │  │
│  │  │  192.168.100.182/24     │  │  │
│  │  │  Gateway: .100.1        │  │  │
│  │  └─────────────────────────┘  │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

### B. Required Ports
- **80/tcp**: HTTP (redirect to HTTPS)
- **443/tcp**: HTTPS (web UI and registry API)
- **4443/tcp**: Harbor internal services (optional)

### C. Component Health Check Endpoints
- Harbor Core: `https://192.168.100.182/api/v2.0/systeminfo`
- Harbor Portal: `https://192.168.100.182/`
- Registry: `https://192.168.100.182/v2/`

### D. Performance Baselines
- Web UI load time: <3 seconds
- Small image push (10MB): <30 seconds
- Large image push (1GB): <5 minutes
- Image pull (any size): Network-limited
- Concurrent operations: 5+ simultaneous pushes

---

## Test Automation Suite

Comprehensive automated testing scripts are available in `/tests/harbor-ct182/`:

### Available Test Scripts

1. **pre-installation-validation.sh**
   - System resource validation
   - Network configuration checks
   - LXC feature verification
   - DNS and connectivity tests
   - Usage: `./pre-installation-validation.sh --ctid 182 [--json]`

2. **installation-verification.sh**
   - Docker installation checks
   - Harbor service health
   - Component connectivity
   - API endpoint validation
   - Usage: `./installation-verification.sh --harbor-ip 192.168.1.182 [--json]`

3. **functional-tests.sh**
   - Authentication testing
   - Project management
   - Image push/pull operations
   - Vulnerability scanning
   - API functionality
   - Usage: `./functional-tests.sh --harbor-ip IP --admin-password PASS [--json]`

4. **performance-benchmarks.sh**
   - Web UI response time
   - Image push/pull performance
   - Concurrent operations
   - API response metrics
   - Resource utilization
   - Usage: `./performance-benchmarks.sh --harbor-ip IP --admin-password PASS [--json]`

5. **security-validation.sh**
   - SSL/TLS configuration
   - Certificate validation
   - Authentication enforcement
   - RBAC and authorization
   - Audit logging
   - Usage: `./security-validation.sh --harbor-ip IP --admin-password PASS [--json]`

### Quick Test Execution

```bash
# Complete test workflow
cd /mnt/overpower/apps/dev/agl/agl-hostman/tests/harbor-ct182

# 1. Pre-installation (before Harbor setup)
./pre-installation-validation.sh --ctid 182

# 2. Installation verification (after Harbor installed)
./installation-verification.sh --ctid 182 --harbor-ip 192.168.1.182

# 3. Functional tests (requires admin password)
./functional-tests.sh --harbor-ip 192.168.1.182 --admin-password "YourPassword"

# 4. Performance benchmarks
./performance-benchmarks.sh --harbor-ip 192.168.1.182 --admin-password "YourPassword"

# 5. Security validation
./security-validation.sh --harbor-ip 192.168.1.182 --admin-password "YourPassword"
```

### JSON Output for CI/CD Integration

All scripts support `--json` flag for machine-readable output:

```bash
./functional-tests.sh --harbor-ip 192.168.1.182 --admin-password "PASS" --json > results.json
```

JSON format:
```json
{
  "timestamp": "2025-10-22T12:00:00Z",
  "total_tests": 15,
  "passed": 14,
  "failed": 1,
  "pass_rate": "93%",
  "overall_result": "FAIL",
  "tests": [...]
}
```

---

**Document Version**: 2.0.0
**Last Updated**: 2025-10-22
**Author**: Tester Agent - Hive Mind Swarm (swarm-1761131660305-65la2tiid)
**Status**: Complete with Automated Testing Suite
