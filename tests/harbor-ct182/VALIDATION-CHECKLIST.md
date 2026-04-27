# Harbor CT182 Deployment Validation Checklist

**Version**: 1.0.0
**Date**: 2025-10-22
**Purpose**: Step-by-step validation checklist for Harbor deployment on CT182

---

## ☑️ Pre-Deployment Checklist

### System Prerequisites
- [ ] Proxmox host accessible and operational
- [ ] Container CT182 created with correct ID
- [ ] Network configuration: VLAN 100, IP 192.168.100.182/24
- [ ] Gateway configured: 192.168.100.1
- [ ] ZFS storage pool healthy
- [ ] Minimum resources allocated: 2 CPU cores, 4GB RAM, 100GB storage

### Network Prerequisites
- [ ] VLAN 100 configured and accessible
- [ ] IP address 192.168.100.182 not in use
- [ ] DNS resolution working (test: `nslookup google.com`)
- [ ] External connectivity available (test: `ping 8.8.8.8`)
- [ ] Firewall rules allow HTTP (80) and HTTPS (443)

### Security Prerequisites
- [ ] SSL/TLS certificates prepared or plan for self-signed
- [ ] Admin credentials decided (change from default!)
- [ ] Network security policies reviewed
- [ ] Backup strategy planned

### Tools Required
- [ ] `jq` installed on Proxmox host: `apt-get install jq`
- [ ] `curl` available in container
- [ ] `openssl` available for SSL testing

---

## ☑️ Pre-Installation Validation

**Script**: `./pre-installation-validation.sh`

### Execution
```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman/tests/harbor-ct182
chmod +x pre-installation-validation.sh
./pre-installation-validation.sh
```

### Expected Results
- [ ] ✅ T-PRE-001: Container resources validated (CPU ≥2, RAM ≥4GB)
- [ ] ✅ T-PRE-002: Network configuration verified (IP, gateway, connectivity)
- [ ] ✅ T-PRE-003: Storage space adequate (50GB+ available)
- [ ] ✅ T-PRE-004: DNS resolution working (google.com, github.com, docker.io)
- [ ] ✅ T-PRE-005: Firewall rules accessible
- [ ] ✅ T-PRE-006: SSL/TLS tools available

### On Failure
- [ ] Review log file: `/tmp/harbor-ct182-pre-validation-*.log`
- [ ] Fix identified issues
- [ ] Re-run validation
- [ ] Do NOT proceed to installation until all pass

---

## ☑️ Harbor Installation

**Reference**: Use deployment scripts from Coder agent

### Installation Steps
- [ ] Container started: `pct start 182`
- [ ] Docker Engine installed
- [ ] Docker Compose installed
- [ ] Harbor downloaded (correct version)
- [ ] Harbor configuration file created (`harbor.yml`)
- [ ] SSL certificates configured
- [ ] Harbor installation script executed: `./install.sh`

### Installation Checklist
- [ ] No errors during Docker installation
- [ ] Docker daemon running: `systemctl status docker`
- [ ] Docker Compose version ≥2.0
- [ ] Harbor files extracted to `/opt/harbor`
- [ ] `harbor.yml` configured with correct hostname
- [ ] Admin password changed from default
- [ ] SSL certificates in place (or self-signed generated)

---

## ☑️ Post-Installation Verification

**Script**: `./installation-verification.sh`

### Execution
```bash
./installation-verification.sh
```

### Expected Results
- [ ] ✅ T-INST-001: Docker Engine functional (hello-world test passes)
- [ ] ✅ T-INST-002: Docker Compose functional
- [ ] ✅ T-INST-003: Harbor files present and extracted
- [ ] ✅ T-INST-004: Harbor configuration valid
- [ ] ✅ T-INST-005: All Harbor services running
- [ ] ✅ T-INST-006: Harbor API healthy, Web UI accessible

### Service Health Check
```bash
pct exec 182 -- docker-compose -f /opt/harbor/docker-compose.yml ps
```

**Expected**: All services showing "Up" status
- [ ] harbor-core
- [ ] harbor-portal
- [ ] harbor-db
- [ ] registry
- [ ] registryctl
- [ ] harbor-jobservice

### On Failure
- [ ] Review Docker logs: `docker-compose logs`
- [ ] Check service status individually
- [ ] Verify configuration in `harbor.yml`
- [ ] Restart services: `docker-compose down && docker-compose up -d`

---

## ☑️ Functionality Validation

**Script**: `./functionality-tests.sh`

### Execution
```bash
./functionality-tests.sh
```

### Expected Results
- [ ] ✅ T-FUNC-001: Admin can log in via Web UI
- [ ] ✅ T-FUNC-002: Projects can be created
- [ ] ✅ T-FUNC-004: Docker images can be pushed
- [ ] ✅ T-FUNC-005: Docker images can be pulled
- [ ] ✅ T-FUNC-010: API endpoints accessible

### Manual Validation
**Web UI Access** (https://192.168.100.182):
- [ ] Web UI loads without errors
- [ ] Login page displayed
- [ ] Admin can authenticate
- [ ] Dashboard visible after login
- [ ] Projects page accessible
- [ ] Repositories page functional

**Docker Registry**:
```bash
# Login
docker login 192.168.100.182 -u admin

# Tag test image
docker tag alpine:latest 192.168.100.182/library/alpine:test

# Push
docker push 192.168.100.182/library/alpine:test

# Pull
docker pull 192.168.100.182/library/alpine:test
```

- [ ] Docker login succeeds
- [ ] Image push completes
- [ ] Image visible in Harbor UI
- [ ] Image pull succeeds

---

## ☑️ Performance Validation

**Script**: `./performance-benchmarks.sh`

### Execution
```bash
./performance-benchmarks.sh
```

### Expected Results
- [ ] ✅ T-PERF-001: Web UI response <3s
- [ ] ✅ T-PERF-002: Small image push <30s
- [ ] ✅ T-PERF-004: Image pull completes
- [ ] ✅ T-PERF-005: Concurrent operations stable
- [ ] ✅ T-PERF-007: Resource utilization acceptable

### Performance Metrics Review
**Review JSON**: `/tmp/harbor-ct182-perf-results.json`

- [ ] All benchmarks within thresholds
- [ ] CPU usage <80% during operations
- [ ] Memory usage <90%
- [ ] Disk I/O not saturated
- [ ] No performance anomalies

### Performance Tuning (if needed)
- [ ] Increase container RAM if memory >80%
- [ ] Add CPU cores if CPU >80%
- [ ] Optimize ZFS settings for storage performance
- [ ] Review Harbor configuration for tuning opportunities

---

## ☑️ Security Validation

**Script**: `./security-validation.sh`

### Execution
```bash
./security-validation.sh
```

### Expected Results
- [ ] ✅ T-SEC-001: Valid SSL/TLS certificate, TLS 1.2+ only
- [ ] ✅ T-SEC-002: Authentication working, invalid creds rejected
- [ ] ✅ T-SEC-003: RBAC configured and functional
- [ ] ✅ T-SEC-007: Network security controls in place
- [ ] ✅ T-SEC-008: Secrets properly managed

### Security Hardening Checklist
- [ ] Default admin password CHANGED
- [ ] Self-signed certificate replaced with trusted CA cert (production)
- [ ] HTTP redirects to HTTPS
- [ ] TLS 1.0 and 1.1 disabled
- [ ] Strong cipher suites only
- [ ] Firewall rules restrict access to known IPs (if applicable)
- [ ] Regular security updates scheduled
- [ ] Audit logging enabled
- [ ] Backup encryption configured

### SSL/TLS Validation
```bash
# Check certificate
openssl s_client -connect 192.168.100.182:443 -showcerts

# Test TLS versions
openssl s_client -connect 192.168.100.182:443 -tls1_2
```

- [ ] Certificate valid and trusted
- [ ] TLS 1.2 supported
- [ ] TLS 1.3 supported (recommended)
- [ ] SSLv3 NOT supported
- [ ] TLS 1.0/1.1 NOT supported

---

## ☑️ Production Readiness

### Documentation
- [ ] Network diagram updated
- [ ] Configuration documented
- [ ] Admin credentials stored securely
- [ ] Backup procedures documented
- [ ] Disaster recovery plan created
- [ ] Monitoring alerts configured

### Operational Readiness
- [ ] Team trained on Harbor usage
- [ ] Docker CLI configured on developer workstations
- [ ] CI/CD pipelines updated with Harbor registry
- [ ] Image retention policies configured
- [ ] Garbage collection scheduled
- [ ] Vulnerability scanning configured

### Monitoring & Alerts
- [ ] Harbor health endpoint monitored
- [ ] Disk space alerts configured (>80% threshold)
- [ ] Service availability monitoring
- [ ] Performance baseline documented
- [ ] Log aggregation configured
- [ ] Backup verification scheduled

### Compliance & Governance
- [ ] Security policies documented
- [ ] Access control policies defined
- [ ] Audit logging reviewed
- [ ] Compliance requirements met
- [ ] Change management process defined

---

## ☑️ Acceptance Criteria

### Critical (All Must Pass)
- [ ] All pre-installation validations PASS
- [ ] All installation verification tests PASS
- [ ] Admin authentication functional
- [ ] Docker push/pull operations working
- [ ] SSL/TLS configured securely
- [ ] No critical security vulnerabilities

### High Priority (Should Pass)
- [ ] Web UI responsive (<3s load time)
- [ ] Performance benchmarks meet thresholds
- [ ] All API endpoints functional
- [ ] Network security validated
- [ ] Backup and restore tested

### Sign-Off
- [ ] **Deployment Team**: Installation verified _______________
- [ ] **QA Team**: Testing completed _______________
- [ ] **Security Team**: Security validated _______________
- [ ] **Operations Team**: Ready for production _______________

---

## 📊 Test Results Summary

**Pre-Installation**: _____ Passed, _____ Failed, _____ Warnings
**Installation**: _____ Passed, _____ Failed, _____ Warnings
**Functionality**: _____ Passed, _____ Failed, _____ Warnings
**Performance**: _____ Passed, _____ Failed, _____ Warnings
**Security**: _____ Passed, _____ Failed, _____ Warnings

**Overall Status**: ⬜ PASS ⬜ FAIL ⬜ PASS WITH WARNINGS

**Deployment Date**: _______________
**Go-Live Date**: _______________
**Validated By**: _______________

---

## 🚀 Post-Deployment Tasks

### Week 1
- [ ] Daily health checks
- [ ] Monitor performance metrics
- [ ] Review logs for errors
- [ ] Test backup/restore
- [ ] Gather user feedback

### Week 2-4
- [ ] Weekly security scans
- [ ] Performance trend analysis
- [ ] Capacity planning review
- [ ] Documentation updates
- [ ] Training completion verification

### Monthly
- [ ] Security patch review
- [ ] Certificate expiration check (90 days)
- [ ] Access control audit
- [ ] Backup verification test
- [ ] Disaster recovery drill

---

**Checklist Version**: 1.0.0
**Last Updated**: 2025-10-22
**Maintained By**: QA/DevOps Team
