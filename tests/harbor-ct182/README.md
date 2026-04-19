# Harbor CT182 Test Suite

Comprehensive testing suite for Harbor container registry deployment on Proxmox LXC CT182.

## Test Scripts

### 1. Pre-Installation Validation (`pre-installation-validation.sh`)
**Purpose**: Verify system readiness before Harbor installation
**Tests**: T-PRE-001 through T-PRE-006
**Runtime**: ~2 minutes

```bash
chmod +x pre-installation-validation.sh
./pre-installation-validation.sh
```

**Validates**:
- Container resources (CPU, RAM, storage)
- Network configuration (IP, gateway, connectivity)
- Storage space and ZFS health
- DNS resolution
- Firewall configuration
- SSL/TLS prerequisites

### 2. Installation Verification (`installation-verification.sh`)
**Purpose**: Confirm successful Harbor installation
**Tests**: T-INST-001 through T-INST-006
**Runtime**: ~3 minutes

```bash
chmod +x installation-verification.sh
./installation-verification.sh
```

**Verifies**:
- Docker Engine installation
- Docker Compose installation
- Harbor file extraction
- Harbor configuration
- Service startup
- Component health status

### 3. Functionality Tests (`functionality-tests.sh`)
**Purpose**: Validate core Harbor features
**Tests**: T-FUNC-001, T-FUNC-002, T-FUNC-004, T-FUNC-005, T-FUNC-010
**Runtime**: ~5 minutes

```bash
chmod +x functionality-tests.sh
./functionality-tests.sh
```

**Tests**:
- Admin authentication
- Project creation/management
- Docker image push operations
- Docker image pull operations
- API endpoint functionality

### 4. Performance Benchmarks (`performance-benchmarks.sh`)
**Purpose**: Measure Harbor performance metrics
**Tests**: T-PERF-001, T-PERF-002, T-PERF-004, T-PERF-005, T-PERF-007
**Runtime**: ~10 minutes

```bash
chmod +x performance-benchmarks.sh
./performance-benchmarks.sh
```

**Benchmarks**:
- Web UI response time (<3s threshold)
- Small image push (<30s threshold)
- Image pull performance
- Concurrent operations (3+ simultaneous)
- Resource utilization monitoring

### 5. Security Validation (`security-validation.sh`)
**Purpose**: Verify security controls and compliance
**Tests**: T-SEC-001, T-SEC-002, T-SEC-003, T-SEC-007, T-SEC-008
**Runtime**: ~4 minutes

```bash
chmod +x security-validation.sh
./security-validation.sh
```

**Validates**:
- SSL/TLS certificate and configuration
- Authentication mechanisms
- Authorization and RBAC
- Network security controls
- Secret management

## Running All Tests

### Sequential Execution
```bash
#!/bin/bash
./pre-installation-validation.sh
./installation-verification.sh
./functionality-tests.sh
./performance-benchmarks.sh
./security-validation.sh
```

### Parallel Execution (where safe)
```bash
#!/bin/bash
# Run non-interfering tests in parallel
./performance-benchmarks.sh &
./security-validation.sh &
wait
```

## Test Results

### Output Locations
- **Logs**: `/tmp/harbor-ct182-*-YYYYMMDD-HHMMSS.log`
- **JSON Results**: `/tmp/harbor-ct182-*-results.json`

### Result Format
Each test produces:
1. **Console output**: Color-coded pass/fail/warning messages
2. **Log file**: Detailed timestamped execution log
3. **JSON file**: Structured test results for automation

### JSON Schema
```json
{
  "timestamp": "2025-10-22T10:30:00Z",
  "tests": [
    {
      "id": "T-PRE-001",
      "name": "Container Resource Validation",
      "status": "PASS",
      "details": "CPU: 2, RAM: 4096MB, Storage: 100GB"
    }
  ],
  "summary": {
    "passed": 5,
    "failed": 0,
    "warnings": 1
  }
}
```

## Prerequisites

### System Requirements
- **Proxmox host** with CT182 container
- **Root access** to Proxmox host
- **jq** installed: `apt-get install jq`
- **curl** installed: `apt-get install curl`
- **openssl** installed: `apt-get install openssl`

### Container Requirements
- **Container CT182** must exist
- **Network configured**: 192.168.100.182/24
- **Harbor installed** (for post-installation tests)

## Test Execution Schedule

### Day 1
1. Morning: Pre-installation validation (T-PRE-001 to T-PRE-006)
2. Afternoon: Installation and verification (T-INST-001 to T-INST-006)

### Day 2
1. Morning: Network and functionality (T-FUNC-001 to T-FUNC-010)
2. Afternoon: Performance benchmarks (T-PERF-001 to T-PERF-007)

### Day 3
1. Morning: Security validation (T-SEC-001 to T-SEC-008)
2. Afternoon: Regression testing and reporting

## Success Criteria

### Critical (Must Pass)
- ✅ All pre-installation validations pass
- ✅ Docker and Harbor install successfully
- ✅ Harbor services healthy and accessible
- ✅ Image push/pull operations functional
- ✅ SSL/TLS configured securely
- ✅ Authentication working correctly

### High Priority (Should Pass)
- ✅ Network connectivity tests pass
- ✅ Performance meets baseline thresholds
- ✅ Security controls validated
- ✅ API endpoints fully functional

## Troubleshooting

### Common Issues

**Issue**: Container not running
```bash
pct start 182
pct status 182
```

**Issue**: Network connectivity failed
```bash
pct exec 182 -- ip addr show
pct exec 182 -- ping -c 3 192.168.100.1
pct exec 182 -- ping -c 3 8.8.8.8
```

**Issue**: Docker not running
```bash
pct exec 182 -- systemctl status docker
pct exec 182 -- systemctl restart docker
```

**Issue**: Harbor services not healthy
```bash
pct exec 182 -- docker-compose -f /opt/harbor/docker-compose.yml ps
pct exec 182 -- docker-compose -f /opt/harbor/docker-compose.yml logs
```

## Integration with CI/CD

### Jenkins Example
```groovy
stage('Harbor Tests') {
    steps {
        sh './tests/harbor-ct182/pre-installation-validation.sh'
        sh './tests/harbor-ct182/installation-verification.sh'
        sh './tests/harbor-ct182/functionality-tests.sh'

        archiveArtifacts artifacts: '/tmp/harbor-ct182-*-results.json'
        junit testResults: '/tmp/harbor-ct182-*-results.json'
    }
}
```

### GitHub Actions Example
```yaml
- name: Run Harbor Tests
  run: |
    chmod +x tests/harbor-ct182/*.sh
    ./tests/harbor-ct182/pre-installation-validation.sh
    ./tests/harbor-ct182/installation-verification.sh

- name: Upload Results
  uses: actions/upload-artifact@v3
  with:
    name: test-results
    path: /tmp/harbor-ct182-*-results.json
```

## Maintenance

### Updating Tests
1. Edit test scripts in `/mnt/overpower/apps/dev/agl/agl-hostman/tests/harbor-ct182/`
2. Update thresholds in script configuration sections
3. Test changes in isolated environment first
4. Commit to version control

### Version History
- **v1.0.0** (2025-10-22): Initial release
  - 6 test phases
  - 30+ test cases
  - Full automation support

## Support

**Documentation**: `/mnt/overpower/apps/dev/agl/agl-hostman/tests/harbor-ct182-test-plan.md`
**Author**: Tester Agent - Hive Mind Swarm
**Updated**: 2025-10-22
