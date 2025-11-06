# Harbor CT182 Rollback and Recovery Procedures

Comprehensive rollback procedures for Harbor CT182 deployment failures and recovery scenarios.

## Table of Contents

1. [Pre-Rollback Checklist](#pre-rollback-checklist)
2. [Rollback Scenarios](#rollback-scenarios)
3. [Recovery Procedures](#recovery-procedures)
4. [Verification Steps](#verification-steps)
5. [Post-Rollback Actions](#post-rollback-actions)

---

## Pre-Rollback Checklist

Before initiating any rollback procedure:

- [ ] **Document current state** - Capture logs, configurations, and error messages
- [ ] **Identify failure point** - Determine which phase failed (installation, configuration, testing)
- [ ] **Check for data loss risk** - Verify if any critical data needs preservation
- [ ] **Notify stakeholders** - Inform relevant teams of rollback operation
- [ ] **Verify backup availability** - Ensure recent backups exist
- [ ] **Review rollback impact** - Understand what will be lost/changed

### Data Preservation

```bash
# Capture current state before rollback
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="/tmp/harbor-rollback-$TIMESTAMP"

mkdir -p "$BACKUP_DIR"

# Save configuration
pct exec 182 -- bash -c "cp -r /opt/harbor/harbor.yml $BACKUP_DIR/ 2>/dev/null" || true

# Save logs
pct exec 182 -- bash -c "cd /opt/harbor && docker-compose logs > $BACKUP_DIR/harbor-logs.txt 2>/dev/null" || true

# Database dump (if accessible)
pct exec 182 -- docker exec harbor-db pg_dumpall -U postgres > "$BACKUP_DIR/database-backup.sql" 2>/dev/null || true

echo "State captured in: $BACKUP_DIR"
```

---

## Rollback Scenarios

### Scenario 1: Pre-Installation Validation Failure

**Failure Point**: System requirements not met

**Rollback Strategy**: No rollback needed - fix issues before installation

**Actions**:

```bash
# 1. Review validation results
./pre-installation-validation.sh --ctid 182 --json > validation-results.json
cat validation-results.json | jq '.tests[] | select(.result == "FAIL")'

# 2. Fix specific issues:

# CPU/RAM insufficient - increase allocation
pct set 182 -cores 4
pct set 182 -memory 8192

# Storage insufficient - add mount point
pct set 182 -mp0 /mnt/storage/harbor-data,mp=/var/harbor,size=200G

# Network issues - reconfigure
pct set 182 -net0 name=eth0,bridge=vmbr0,ip=192.168.1.182/24,gw=192.168.1.1

# LXC features missing - enable
pct set 182 -features nesting=1,keyctl=1

# Reboot and re-validate
pct reboot 182
sleep 10
./pre-installation-validation.sh --ctid 182
```

**Success Criteria**: All pre-installation tests pass

---

### Scenario 2: Docker Installation Failure

**Failure Point**: Docker or Docker Compose failed to install

**Rollback Strategy**: Remove partial installation, revert to clean state

**Actions**:

```bash
# 1. Access container
pct enter 182

# 2. Remove Docker components
systemctl stop docker 2>/dev/null || true
apt-get remove -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
apt-get autoremove -y
apt-get autoclean

# 3. Clean up Docker data
rm -rf /var/lib/docker
rm -rf /var/lib/containerd
rm -f /usr/local/bin/docker-compose
rm -f /usr/bin/docker-compose

# 4. Clean repository configuration
rm -f /etc/apt/sources.list.d/docker.list
rm -f /etc/apt/keyrings/docker.gpg

# 5. Re-run installation script
cd /mnt/overpower/apps/dev/agl/agl-hostman/scripts/harbor-ct182
./setup-docker.sh

# 6. Verify
docker --version
docker-compose --version
docker run --rm hello-world
```

**Success Criteria**: Docker daemon running, hello-world test passes

---

### Scenario 3: Harbor Installation Failure

**Failure Point**: Harbor download, configuration, or deployment failed

**Rollback Strategy**: Complete removal of Harbor, preserve data volume

**Actions**:

```bash
# 1. Stop all Harbor services
pct exec 182 -- bash -c "cd /opt/harbor && docker-compose down -v" 2>/dev/null || true

# 2. Remove Harbor containers and images
pct exec 182 -- bash -c "docker rm -f \$(docker ps -a --filter 'name=harbor-' -q) 2>/dev/null" || true
pct exec 182 -- bash -c "docker rmi \$(docker images 'goharbor/*' -q) 2>/dev/null" || true

# 3. Preserve data (optional - for retry with same data)
pct exec 182 -- bash -c "cp -r /var/harbor /var/harbor-backup-\$(date +%Y%m%d)" || true

# 4. Remove Harbor installation
pct exec 182 -- rm -rf /opt/harbor

# 5. Clean data volume (or preserve for retry)
# CAUTION: This deletes all Harbor data!
pct exec 182 -- rm -rf /var/harbor/*

# 6. Re-run installation
cd /mnt/overpower/apps/dev/agl/agl-hostman/scripts/harbor-ct182
./install-harbor.sh

# 7. Verify installation
./tests/harbor-ct182/installation-verification.sh --ctid 182 --harbor-ip 192.168.1.182
```

**Success Criteria**: Harbor containers running, health endpoints responding

---

### Scenario 4: Configuration Error After Installation

**Failure Point**: Harbor misconfigured, services failing

**Rollback Strategy**: Restore backup configuration, restart services

**Actions**:

```bash
# 1. Stop Harbor
pct exec 182 -- bash -c "cd /opt/harbor && docker-compose down"

# 2. Restore known-good configuration
# If backup exists:
pct exec 182 -- cp /opt/harbor/harbor.yml /opt/harbor/harbor.yml.broken
pct exec 182 -- cp /root/harbor-backup/harbor.yml /opt/harbor/harbor.yml

# Or regenerate from template:
pct exec 182 -- bash -c "cd /opt/harbor && cp harbor.yml.tmpl harbor.yml"

# Edit critical settings:
pct exec 182 -- bash -c "sed -i 's|^hostname:.*|hostname: 192.168.1.182|' /opt/harbor/harbor.yml"
pct exec 182 -- bash -c "sed -i 's|^data_volume:.*|data_volume: /var/harbor|' /opt/harbor/harbor.yml"

# 3. Regenerate configuration
pct exec 182 -- bash -c "cd /opt/harbor && ./prepare --with-trivy --with-chartmuseum"

# 4. Restart Harbor
pct exec 182 -- bash -c "cd /opt/harbor && docker-compose up -d"

# 5. Wait for stabilization
sleep 30

# 6. Verify
pct exec 182 -- docker ps
curl -k https://192.168.1.182/api/v2.0/health
```

**Success Criteria**: All services healthy, API accessible

---

### Scenario 5: Failed Functional Tests

**Failure Point**: Harbor operational but features not working

**Rollback Strategy**: Identify and fix specific component issues

**Actions**:

```bash
# 1. Run functional tests to identify failures
./tests/harbor-ct182/functional-tests.sh \
  --harbor-ip 192.168.1.182 \
  --admin-password "Password" \
  --json > functional-test-results.json

# 2. Analyze failures
cat functional-test-results.json | jq '.tests[] | select(.result == "FAIL")'

# 3. Fix specific issues:

# Authentication failures
pct exec 182 -- docker-compose logs harbor-core | grep -i auth

# Image push/pull failures
pct exec 182 -- docker-compose logs registry
pct exec 182 -- docker-compose logs nginx

# Vulnerability scanning failures
pct exec 182 -- docker-compose logs trivy-adapter
pct exec 182 -- docker exec trivy-adapter /home/scanner/bin/trivy image --download-db-only

# Database issues
pct exec 182 -- docker exec harbor-db psql -U postgres -c "SELECT version();"

# 4. Restart affected services
pct exec 182 -- docker-compose restart harbor-core
pct exec 182 -- docker-compose restart registry

# 5. Re-test
./tests/harbor-ct182/functional-tests.sh --harbor-ip 192.168.1.182 --admin-password "Password"
```

**Success Criteria**: All functional tests pass

---

### Scenario 6: Complete Container Corruption

**Failure Point**: Container filesystem corrupted or unusable

**Rollback Strategy**: Destroy and recreate container from scratch

**Actions**:

```bash
# 1. Backup data from corrupted container (if accessible)
mkdir -p /tmp/ct182-emergency-backup
pct exec 182 -- tar czf - /var/harbor 2>/dev/null > /tmp/ct182-emergency-backup/harbor-data.tar.gz || true

# 2. Stop container
pct stop 182

# 3. Take snapshot for safety
pct snapshot 182 before-destruction-$(date +%Y%m%d-%H%M%S)

# 4. Destroy container
pct destroy 182

# 5. Recreate container
cd /mnt/overpower/apps/dev/agl/agl-hostman/scripts/harbor-ct182
./create-container.sh

# 6. Restore data (if backup exists)
pct exec 182 -- bash -c "cd / && tar xzf -" < /tmp/ct182-emergency-backup/harbor-data.tar.gz || true

# 7. Complete installation
./setup-docker.sh
./install-harbor.sh

# 8. Full validation
cd /mnt/overpower/apps/dev/agl/agl-hostman/tests/harbor-ct182
./pre-installation-validation.sh --ctid 182
./installation-verification.sh --ctid 182 --harbor-ip 192.168.1.182
```

**Success Criteria**: Fresh working installation

---

## Recovery Procedures

### Database Recovery

**Scenario**: PostgreSQL database corrupted or data loss

```bash
# 1. Stop Harbor
pct exec 182 -- bash -c "cd /opt/harbor && docker-compose down"

# 2. Remove corrupted database
pct exec 182 -- rm -rf /var/harbor/database/*

# 3. Restore from backup
pct exec 182 -- bash -c "cd /opt/harbor && docker-compose up -d harbor-db"
sleep 10

# 4. Import database dump
pct exec 182 -- bash -c "docker exec -i harbor-db psql -U postgres < /backups/harbor-db-backup.sql"

# 5. Start remaining services
pct exec 182 -- bash -c "cd /opt/harbor && docker-compose up -d"
```

### Registry Data Recovery

**Scenario**: Image storage corrupted

```bash
# 1. Stop Harbor
pct exec 182 -- bash -c "cd /opt/harbor && docker-compose down"

# 2. Restore registry data from backup
pct exec 182 -- bash -c "rsync -av /backups/registry/ /var/harbor/registry/"

# 3. Fix permissions
pct exec 182 -- chown -R 10000:10000 /var/harbor/registry

# 4. Restart Harbor
pct exec 182 -- bash -c "cd /opt/harbor && docker-compose up -d"

# 5. Verify images
curl -k -u admin:password https://192.168.1.182/api/v2.0/projects/library/repositories
```

### SSL Certificate Recovery

**Scenario**: Certificate expired or corrupted

```bash
# 1. Generate new self-signed certificate
pct exec 182 -- bash -c "cd /opt/harbor/ssl && openssl req -newkey rsa:4096 -nodes -sha256 -keyout harbor.key -x509 -days 365 -out harbor.crt -subj '/CN=192.168.1.182'"

# 2. Update harbor.yml paths (if needed)
pct exec 182 -- bash -c "sed -i 's|certificate:.*|certificate: /opt/harbor/ssl/harbor.crt|' /opt/harbor/harbor.yml"
pct exec 182 -- bash -c "sed -i 's|private_key:.*|private_key: /opt/harbor/ssl/harbor.key|' /opt/harbor/harbor.yml"

# 3. Restart Harbor
pct exec 182 -- bash -c "cd /opt/harbor && docker-compose down && docker-compose up -d"
```

---

## Verification Steps

After any rollback or recovery:

### 1. System-Level Verification

```bash
# Container status
pct status 182
pct exec 182 -- systemctl status docker

# Resource usage
pct exec 182 -- free -h
pct exec 182 -- df -h
```

### 2. Harbor Service Verification

```bash
# All containers running
pct exec 182 -- docker ps --filter 'name=harbor-'

# Expected count: 7-9 containers
# Expected: harbor-core, harbor-db, harbor-portal, harbor-jobservice, nginx, redis, registry, trivy-adapter, chartmuseum
```

### 3. Functional Verification

```bash
# Run automated tests
cd /mnt/overpower/apps/dev/agl/agl-hostman/tests/harbor-ct182
./installation-verification.sh --ctid 182 --harbor-ip 192.168.1.182
./functional-tests.sh --harbor-ip 192.168.1.182 --admin-password "Password"
```

### 4. Data Integrity Verification

```bash
# Check database
pct exec 182 -- docker exec harbor-db psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;"

# Check registry
pct exec 182 -- ls -lah /var/harbor/registry/docker/registry/v2/repositories/
```

---

## Post-Rollback Actions

### Documentation

- [ ] Document what failed and why
- [ ] Record rollback steps taken
- [ ] Note lessons learned
- [ ] Update runbooks if needed

### Communication

- [ ] Notify stakeholders of status
- [ ] Provide incident timeline
- [ ] Share recovery plan if retry needed

### Prevention

- [ ] Implement automated testing before deployment
- [ ] Improve validation scripts
- [ ] Add monitoring/alerting
- [ ] Schedule regular backups

### Retry Planning

If retrying installation after rollback:

1. **Wait Period**: Allow time for system stabilization
2. **Pre-Flight**: Run all validation tests
3. **Incremental**: Deploy in smaller steps with validation between
4. **Monitoring**: Watch logs in real-time during deployment
5. **Checkpoints**: Create snapshots at each successful phase

---

## Emergency Contacts

| Role | Contact | Purpose |
|------|---------|---------|
| Proxmox Admin | Internal Team | Container/host issues |
| Network Team | Internal Team | Connectivity issues |
| Security Team | Internal Team | Certificate/SSL issues |
| Harbor Support | https://github.com/goharbor/harbor/issues | Upstream bugs |

---

## Testing Rollback Procedures

Periodically test rollback procedures to ensure they work:

```bash
# 1. Create test container
pct clone 182 183 --full

# 2. Intentionally break something
pct exec 183 -- docker stop harbor-core

# 3. Practice rollback
# ... execute rollback procedures ...

# 4. Verify recovery
./tests/harbor-ct182/installation-verification.sh --ctid 183 --harbor-ip 192.168.1.183

# 5. Cleanup test container
pct destroy 183
```

---

**Document Version**: 1.0.0
**Last Updated**: 2025-10-22
**Author**: Tester Agent - Hive Mind Swarm
**Review Schedule**: After each rollback incident
