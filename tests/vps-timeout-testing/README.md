# VPS Timeout Testing & Validation Suite

## Overview

This comprehensive testing suite validates the root cause and remediation of morning timeout issues affecting the VPS hosting environment. The strategy focuses on production-safe, evidence-based testing with clear success criteria.

## Directory Structure

```
tests/vps-timeout-testing/
├── README.md                    # This file
├── test-plan.md                 # Master test plan and strategy
├── backup-tests.md              # Backup process validation (6 tests)
├── stress-tests.md              # Application stress testing (6 tests)
├── db-tests.md                  # Database performance tests (6 tests)
├── network-tests.md             # Network diagnostics tests (6 tests)
├── validation-tests.md          # Post-fix validation (6 tests)
└── results/                     # Test execution results (gitignored)
    ├── backup-tests-YYYYMMDD/
    ├── stress-tests-YYYYMMDD/
    ├── db-tests-YYYYMMDD/
    ├── network-tests-YYYYMMDD/
    └── validation-tests-YYYYMMDD/
```

## Test Categories

### 1. Backup Process Tests (BT-001 to BT-006)
**File:** `backup-tests.md`

Validates backup process impact on system performance:
- Resource monitoring during backups
- Backup window overlap detection
- Database backup I/O impact
- File system lock detection
- Remote backup transfer impact
- Backup-timeout correlation analysis

**Key Tests:**
- BT-003: Database Backup I/O Impact ⭐ (Critical)
- BT-006: Backup Process Timeout Correlation ⭐ (Critical)

### 2. Application Stress Tests (ST-001 to ST-006)
**File:** `stress-tests.md`

Tests PHP-FPM and application-level bottlenecks:
- PHP-FPM pool exhaustion
- Slow script execution detection
- Memory leak detection
- Database connection pool exhaustion
- Concurrent write lock contention
- Integrated peak load simulation

**Key Tests:**
- ST-001: PHP-FPM Pool Exhaustion Test ⭐ (Critical)
- ST-006: Integrated Load Test ⭐ (Critical)

### 3. Database Performance Tests (DT-001 to DT-006)
**File:** `db-tests.md`

MySQL performance and query optimization validation:
- Slow query identification
- Index usage analysis
- Connection pool performance
- Query cache effectiveness
- Lock contention analysis
- Backup impact on queries

**Key Tests:**
- DT-001: Slow Query Identification ⭐ (Critical)
- DT-006: Backup Impact on Query Performance ⭐ (Critical)

### 4. Network Diagnostics Tests (NT-001 to NT-006)
**File:** `network-tests.md`

Network latency and connectivity validation:
- Network latency baseline
- Bandwidth saturation detection
- DNS resolution performance
- Connection timeout detection
- Firewall impact analysis
- Network monitoring during backup

**Key Tests:**
- NT-002: Bandwidth Saturation Detection ⭐ (Critical)
- NT-004: Connection Timeout Detection ⭐ (Critical)

### 5. Post-Fix Validation Tests (VT-001 to VT-006)
**File:** `validation-tests.md`

Comprehensive remediation effectiveness validation:
- Baseline comparison
- Morning window stress test
- Load testing under backup conditions
- Continuous uptime monitoring
- Error log validation
- Performance regression testing

**Key Tests:**
- VT-002: Morning Window Stress Test ⭐ (Critical)
- VT-004: Continuous Uptime Monitoring ⭐ (Critical)

## Quick Start

### Prerequisites

```bash
# Install required testing tools
sudo apt-get update
sudo apt-get install -y \
    apache2-utils \
    dstat \
    iftop \
    iotop \
    mtr \
    nethogs \
    netcat \
    tcpdump \
    sysstat

# Install MySQL performance tools (optional but recommended)
wget https://repo.percona.com/apt/percona-release_latest.generic_all.deb
sudo dpkg -i percona-release_latest.generic_all.deb
sudo apt-get update
sudo apt-get install -y percona-toolkit

# Create results directory
mkdir -p /mnt/overpower/apps/dev/agl/agl-hostman/tests/vps-timeout-testing/results
```

### Phase 1: Baseline Collection (Week 1)

```bash
# Run baseline metrics collection
cd /mnt/overpower/apps/dev/agl/agl-hostman/tests/vps-timeout-testing

# Collect system baseline
dstat -tcmdn --output results/baseline-metrics.csv 3600 24 &

# Collect application baseline
for i in {1..100}; do
    curl -w "Time: %{time_total}s\n" -o /dev/null -s http://localhost/
    sleep 30
done > results/baseline-response-times.txt

# Review test plan
less test-plan.md
```

### Phase 2: Execute Test Suites (Week 2)

```bash
# Run backup process tests (off-peak hours recommended)
# Review backup-tests.md for detailed procedures

# Run stress tests (staging environment recommended)
# Review stress-tests.md for detailed procedures

# Run database tests
# Review db-tests.md for detailed procedures

# Run network tests
# Review network-tests.md for detailed procedures
```

### Phase 3: Implement Remediation (Week 2-3)

Based on test results, implement fixes:
1. Optimize backup schedule and process
2. Tune PHP-FPM pool settings
3. Optimize database queries and indexes
4. Adjust network/firewall configurations
5. Implement monitoring enhancements

### Phase 4: Validation (Week 3-4)

```bash
# Deploy uptime monitoring
sudo cp /tmp/uptime-monitor.sh /usr/local/bin/
sudo systemctl enable uptime-monitor
sudo systemctl start uptime-monitor

# Schedule morning validation tests
crontab -e
# Add: 0 6 * * * /tmp/morning-validation-test.sh

# Run validation test suite
# Review validation-tests.md for procedures

# After 14 days, generate final report
/tmp/uptime-analysis.sh
```

## Test Execution Guidelines

### Safety First
1. **Always test in staging first** when possible
2. **Schedule invasive tests** during low-traffic periods
3. **Have rollback plans** ready before making changes
4. **Monitor continuously** during and after tests
5. **Document everything** for post-mortem analysis

### Best Practices
- Run baseline tests before any changes
- Execute one test category at a time
- Allow system to stabilize between tests (30-60s)
- Capture comprehensive logs and metrics
- Compare results with baseline consistently

### Emergency Procedures
If testing causes production issues:
1. **Stop all test processes immediately**
2. **Restart affected services** (nginx, php-fpm, mysql)
3. **Check error logs** for root cause
4. **Document the incident** in results directory
5. **Adjust test parameters** before retrying

## Success Criteria Summary

### Primary Objectives
- ✅ Zero 504 timeout errors in 14-day validation period
- ✅ 99.9% uptime during validation
- ✅ Response time <500ms (95th percentile)
- ✅ Morning window (6-7 AM) passes without issues

### Secondary Objectives
- ✅ CPU usage <70% during backups
- ✅ Memory usage <80% sustained
- ✅ Database query time <100ms average
- ✅ PHP-FPM pool usage <80%
- ✅ No packet loss or network saturation

## Reporting

### Daily Reports
Create daily status in: `results/daily-report-YYYYMMDD.md`
- Test execution status
- Metrics collected
- Issues encountered
- Next steps

### Weekly Reports
Create weekly summary in: `results/weekly-report-weekNN.md`
- Phase completion status
- Success criteria progress
- Risk assessment
- Remediation roadmap

### Final Validation Report
Create final report in: `results/final-validation-report.md`
- Complete metrics comparison
- Root cause confirmation
- Remediation effectiveness
- Recommendations for ongoing monitoring

## Troubleshooting

### Common Issues

**Issue:** Tests cause system load spikes
- **Solution:** Reduce concurrency in test scripts
- **Prevention:** Run tests during off-peak hours

**Issue:** Monitoring tools consume too many resources
- **Solution:** Reduce sampling frequency
- **Prevention:** Use efficient tools (dstat vs top)

**Issue:** Test results inconsistent
- **Solution:** Ensure system stability between tests
- **Prevention:** Longer cooldown periods

**Issue:** Unable to reproduce timeout
- **Solution:** Check if issue is time-dependent (backup window)
- **Prevention:** Test during actual backup window

## Tools Reference

### Load Testing
- **ab (Apache Bench)**: Simple HTTP load testing
- **wrk**: Modern HTTP benchmarking tool
- **siege**: HTTP regression testing

### Monitoring
- **dstat**: Versatile resource statistics
- **htop**: Interactive process viewer
- **iotop**: I/O monitoring
- **iftop**: Network bandwidth monitoring

### Database
- **mysqldumpslow**: Slow query log analysis
- **pt-query-digest**: Advanced query analysis
- **mysqltuner**: Configuration recommendations

### Network
- **tcpdump**: Packet capture and analysis
- **mtr**: Network diagnostic tool
- **netstat**: Network statistics
- **ss**: Socket statistics

## Contributing

When adding new tests:
1. Follow the existing test format (TEST-NNN)
2. Include clear success criteria
3. Document prerequisites and tools needed
4. Provide remediation actions for failures
5. Update this README with new test descriptions

## Version History

- **v1.0** (2025-10-22): Initial comprehensive test suite
  - 30 total test scenarios
  - 6 test categories
  - Complete validation framework

## Support

For questions or issues:
1. Review test documentation thoroughly
2. Check `results/` directory for previous runs
3. Consult Hive Mind collective memory
4. Escalate to operations team if needed

---

**Remember:** The goal is evidence-based validation, not speculation. Every test should produce measurable, reproducible results that guide remediation decisions.

**Test Philosophy:** "Measure twice, fix once. Monitor forever."
