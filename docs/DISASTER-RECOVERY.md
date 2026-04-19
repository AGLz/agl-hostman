# Disaster Recovery Plan

**Version**: 1.0.0
**Last Updated**: 2025-01-20
**Phase**: 3.3 - Production DR

---

## Table of Contents

1. [Overview](#overview)
2. [Recovery Objectives](#recovery-objectives)
3. [Backup Strategy](#backup-strategy)
4. [Disaster Scenarios](#disaster-scenarios)
5. [Recovery Procedures](#recovery-procedures)
6. [Testing and Validation](#testing-and-validation)
7. [Business Continuity](#business-continuity)

---

## Overview

### Purpose

This Disaster Recovery (DR) plan ensures business continuity in the event of catastrophic infrastructure failures, data loss, or regional outages.

### Scope

**Covered Systems**:
- Production application (agl-hostman)
- PostgreSQL database (primary + replica)
- Redis cache/queue
- File storage and backups
- Monitoring and alerting

**Not Covered**:
- Development/QA environments (can be rebuilt)
- Third-party SaaS services (managed by vendors)
- Local workstations

### Definitions

- **RTO (Recovery Time Objective)**: Maximum acceptable downtime
- **RPO (Recovery Point Objective)**: Maximum acceptable data loss
- **MTTR (Mean Time To Recover)**: Average time to restore service
- **Disaster**: Event causing complete service unavailability

---

## Recovery Objectives

### Production SLAs

| Metric | Target | Notes |
|--------|--------|-------|
| **RTO** | 1 hour | Time to restore service from disaster |
| **RPO** | 1 hour | Maximum data loss (last hourly backup) |
| **MTTR** | 30 minutes | Average recovery time for common scenarios |
| **Uptime SLA** | 99.9% | Allows ~43 minutes downtime/month |

### Recovery Priority Matrix

| System | Priority | RTO | RPO | Recovery Order |
|--------|----------|-----|-----|----------------|
| Database | Critical | 15 min | 1 hour | 1 |
| Application | Critical | 30 min | N/A | 2 |
| Redis Cache | High | 15 min | N/A | 3 |
| Monitoring | Medium | 1 hour | N/A | 4 |
| Backups | Medium | 2 hours | 24 hours | 5 |

---

## Backup Strategy

### Backup Types

**1. Database Backups** (PostgreSQL):
```bash
# Daily Full Backup (02:00 UTC)
0 2 * * * /app/backup-full.sh

# Hourly Incremental Backup
0 * * * * /app/backup-incremental.sh

# Monthly Archive (1st of month, 01:00 UTC)
0 1 1 * * /app/backup-archive.sh
```

**2. File Storage Backups**:
```bash
# Daily rsync to offsite storage
0 3 * * * rsync -avz /var/lib/docker/volumes/storage/ s3://agl-hostman-backups/storage/
```

**3. Configuration Backups**:
```bash
# Daily backup of docker-compose files, nginx configs
0 4 * * * tar -czf /backups/config-$(date +%Y%m%d).tar.gz /app/docker/production/
```

**4. Application Code**:
- Git repository (GitHub) - automatic backup
- Harbor Docker images - retained for 90 days

### Backup Locations

**Primary** (On-Site):
- Local disk: `/var/lib/docker/volumes/backups/`
- Retention: 7 days full, 3 days incremental

**Secondary** (Off-Site):
- S3 bucket: `s3://agl-hostman-backups/`
- Region: us-east-1
- Retention: 30 days full, 7 days incremental, 1 year monthly archives

**Tertiary** (Disaster Recovery):
- S3 Cross-Region Replication: us-west-2
- Glacier Deep Archive: Monthly backups (7 years)

### Backup Verification

**Automated Verification**:
```bash
# Daily integrity check
php artisan production:backup:verify --all

# Monthly test restore
php artisan production:backup:test-restore --backup-id=[latest-monthly]
```

**Manual Verification** (Quarterly):
1. Download backup from S3
2. Restore to staging environment
3. Verify data integrity
4. Test application functionality
5. Document results

---

## Disaster Scenarios

### Scenario 1: Complete Server Failure (CT182)

**Trigger**:
- Hardware failure (disk, CPU, motherboard)
- Hypervisor crash (Proxmox)
- Power outage without UPS

**Impact**:
- Production site completely offline
- All containers down
- Database unavailable

**Detection**:
- Monitoring alerts (5 consecutive failed health checks)
- PagerDuty incident created
- Status page automatically updated

**Recovery Time**:
- RTO: 1 hour (full rebuild)
- RPO: 1 hour (last hourly backup)

**Recovery Procedure**: See [Complete Infrastructure Rebuild](#complete-infrastructure-rebuild)

---

### Scenario 2: Database Corruption

**Trigger**:
- Disk corruption
- Failed migration
- Data integrity violation
- Malicious deletion

**Impact**:
- Application errors (500s)
- Data inconsistencies
- Potential data loss

**Detection**:
- Database error logs
- Application error rate spike
- Failed integrity checks

**Recovery Time**:
- RTO: 30 minutes (restore from backup)
- RPO: 1 hour (last hourly backup)

**Recovery Procedure**: See [Database Recovery](#database-recovery)

---

### Scenario 3: Accidental Deployment/Rollback Failure

**Trigger**:
- Bad deployment pushed to production
- Rollback window expired (> 1 hour)
- Data migration gone wrong

**Impact**:
- Application broken
- Previous version unavailable
- Database schema incompatible

**Recovery Time**:
- RTO: 15 minutes (if within rollback window)
- RTO: 1 hour (if requires rebuild)
- RPO: 0 (no data loss)

**Recovery Procedure**: See [Application Recovery](#application-recovery)

---

### Scenario 4: Regional Outage (AWS us-east-1)

**Trigger**:
- AWS region outage
- S3 unavailable
- Harbor registry down

**Impact**:
- Backups unavailable
- Cannot deploy new versions
- Monitoring may be degraded

**Recovery Time**:
- RTO: 2 hours (failover to DR region)
- RPO: 1 hour

**Recovery Procedure**: See [Regional Failover](#regional-failover)

---

### Scenario 5: Ransomware Attack

**Trigger**:
- Files encrypted
- Database tables locked
- Backup deletion attempted

**Impact**:
- Production site down
- Data encrypted/inaccessible
- Backups may be compromised

**Recovery Time**:
- RTO: 4 hours (full rebuild + verification)
- RPO: 24 hours (last verified clean backup)

**Recovery Procedure**: See [Security Incident Recovery](#security-incident-recovery)

---

## Recovery Procedures

### Complete Infrastructure Rebuild

**Prerequisites**:
- Access to GitHub repository
- Access to S3 backups
- Access to Harbor registry
- New server/container provisioned

**Step 1: Provision New Infrastructure** (15 minutes)

```bash
# 1. Create new LXC container (CT183 or similar)
# On Proxmox host (AGLSRV1):
pct create 183 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  --hostname agldv05 \
  --memory 16384 \
  --swap 4096 \
  --cores 8 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.0.183/24,gw=192.168.0.1 \
  --storage local-lvm \
  --rootfs local-lvm:100

# 2. Start container
pct start 183

# 3. Install Docker
pct exec 183 -- bash -c "
  apt update && apt install -y docker.io docker-compose-v2 git postgresql-client-16
  systemctl enable docker
  systemctl start docker
"

# 4. Configure networking
# Add WireGuard, Tailscale if needed
```

**Step 2: Restore Application Code** (5 minutes)

```bash
# SSH into new container
ssh root@192.168.0.183

# Clone repository
git clone git@github.com:your-org/agl-hostman.git /root/agl-hostman
cd /root/agl-hostman

# Checkout production branch
git checkout main
git pull origin main
```

**Step 3: Restore Database** (20 minutes)

```bash
# Download latest backup from S3
aws s3 cp s3://agl-hostman-backups/backups/production/production_full_$(date +%Y-%m-%d)_*.sql.gz /tmp/

# Extract backup
gunzip /tmp/production_full_*.sql.gz

# Start PostgreSQL container
cd docker/production/
docker compose -f docker-compose.blue.yml up -d postgres-primary

# Wait for startup
sleep 10

# Restore database
docker exec -i agl-hostman-postgres-primary psql -U postgres -d postgres < /tmp/production_full_*.sql

# Verify data
docker exec agl-hostman-postgres-primary psql -U postgres -d agl_hostman_prod -c "SELECT COUNT(*) FROM users;"
```

**Step 4: Restore Configuration** (5 minutes)

```bash
# Download .env.production from secure storage
# OR recreate from password manager

# Copy to src/ directory
cp .env.production.backup /root/agl-hostman/src/.env

# Download SSL certificates
aws s3 cp s3://agl-hostman-backups/ssl/fullchain.pem /etc/ssl/certs/
aws s3 cp s3://agl-hostman-backups/ssl/privkey.pem /etc/ssl/private/
```

**Step 5: Deploy Application** (10 minutes)

```bash
# Pull latest image from Harbor
docker login harbor.aglz.io:5000
docker pull harbor.aglz.io:5000/agl-hostman-prod:latest

# Start blue environment
docker compose -f docker-compose.blue.yml up -d

# Wait for health checks
sleep 30

# Verify application
curl http://localhost:3000/health

# Start load balancer
docker compose -f docker-compose.lb.yml up -d

# Verify
curl http://localhost:80/health
```

**Step 6: Update DNS** (5 minutes)

```bash
# Update DNS A records to point to new IP
# prod-agl.aglz.io → 192.168.0.183

# Verify DNS propagation
dig prod-agl.aglz.io +short
```

**Step 7: Verify and Monitor** (5 minutes)

```bash
# Run smoke tests
docker exec agl-hostman-app-blue-1 php artisan test --testsuite=Production

# Check monitoring
# Verify Prometheus targets: http://[new-ip]:9090/targets

# Update status page
# "System restored. All services operational."

# Total RTO: ~60 minutes
```

---

### Database Recovery

**Scenario**: Database corruption detected

**Step 1: Stop Application** (2 minutes)

```bash
# Put application in maintenance mode
docker exec agl-hostman-app-blue-1 php artisan down --message="Database maintenance in progress"

# Stop application containers (to prevent writes)
docker compose -f docker-compose.blue.yml stop app-blue-1 app-blue-2
```

**Step 2: Backup Corrupted Database** (5 minutes)

```bash
# Even if corrupted, create backup for forensics
docker exec agl-hostman-postgres-primary pg_dump -U postgres -F c agl_hostman_prod > /tmp/corrupted_backup.dump
```

**Step 3: Drop and Recreate Database** (2 minutes)

```bash
# Drop corrupted database
docker exec agl-hostman-postgres-primary psql -U postgres -c "DROP DATABASE agl_hostman_prod;"

# Recreate database
docker exec agl-hostman-postgres-primary psql -U postgres -c "CREATE DATABASE agl_hostman_prod OWNER postgres;"
```

**Step 4: Restore from Backup** (15 minutes)

```bash
# Download latest hourly backup
aws s3 cp s3://agl-hostman-backups/backups/production/production_incremental_$(date +%Y-%m-%d_%H)00.sql.gz /tmp/

# Extract
gunzip /tmp/production_incremental_*.sql.gz

# Restore
docker exec -i agl-hostman-postgres-primary psql -U postgres -d agl_hostman_prod < /tmp/production_incremental_*.sql

# Verify row counts
docker exec agl-hostman-postgres-primary psql -U postgres -d agl_hostman_prod -c "
  SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
    (SELECT COUNT(*) FROM information_schema.columns WHERE table_name=tablename) AS columns
  FROM pg_tables
  WHERE schemaname='public'
  ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
"
```

**Step 5: Restart Application** (5 minutes)

```bash
# Start application
docker compose -f docker-compose.blue.yml start app-blue-1 app-blue-2

# Wait for health checks
sleep 15

# Exit maintenance mode
docker exec agl-hostman-app-blue-1 php artisan up

# Run smoke tests
docker exec agl-hostman-app-blue-1 php artisan test --testsuite=Production

# Total RTO: ~30 minutes
# Total RPO: ~1 hour (time since last backup)
```

---

### Application Recovery

**Scenario**: Bad deployment, rollback window expired

**Step 1: Assess Situation** (2 minutes)

```bash
# Check current deployment status
curl https://prod-agl.aglz.io/api/deployment/production/status

# Check if previous version still available
docker compose -f docker-compose.blue.yml ps
docker compose -f docker-compose.green.yml ps

# If both slots broken, need to redeploy known-good version
```

**Step 2: Identify Last Known Good Version** (3 minutes)

```bash
# Check Harbor for recent images
curl -u admin:[password] https://harbor.aglz.io:5000/v2/agl-hostman-prod/tags/list

# Check deployment logs for last successful deployment
grep "DEPLOYMENT_SUCCESS" storage/logs/audit.log | tail -5

# Example output:
# [2025-01-19 10:00:00] DEPLOYMENT_SUCCESS: v1.0.5
# [2025-01-20 09:00:00] DEPLOYMENT_FAILED: v1.1.0
# Last known good: v1.0.5
```

**Step 3: Deploy Last Known Good** (10 minutes)

```bash
# Pull known-good image
docker pull harbor.aglz.io:5000/agl-hostman-prod:v1.0.5

# Update docker-compose.blue.yml
sed -i 's|image:.*|image: harbor.aglz.io:5000/agl-hostman-prod:v1.0.5|g' docker-compose.blue.yml

# Deploy
docker compose -f docker-compose.blue.yml up -d

# Wait for health checks
sleep 30

# Verify
curl http://localhost:3000/health
docker exec agl-hostman-app-blue-1 php artisan --version
```

**Step 4: Switch Traffic** (2 minutes)

```bash
# If green is currently broken, switch to blue
curl -X POST https://prod-agl.aglz.io/api/deployment/production/switch-traffic \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"target_slot":"blue","percentage":100,"immediate":true}'
```

**Step 5: Verify Restoration** (3 minutes)

```bash
# Run smoke tests
docker exec agl-hostman-app-blue-1 php artisan test --testsuite=Production

# Check error rate
curl http://localhost:9090/api/v1/query?query=rate(http_requests_total{status=~\"5..\"}[5m])

# Update status page
# "Incident resolved. Service restored."

# Total RTO: ~20 minutes
# Total RPO: 0 (no data loss)
```

---

### Regional Failover

**Scenario**: AWS us-east-1 outage (S3, Harbor registry down)

**Step 1: Activate DR Region** (30 minutes)

```bash
# 1. Verify DR backups in us-west-2
aws s3 ls s3://agl-hostman-backups-dr/ --region us-west-2

# 2. Provision infrastructure in DR region
# (Same steps as Complete Infrastructure Rebuild, but in us-west-2)

# 3. Restore from us-west-2 backups
aws s3 cp s3://agl-hostman-backups-dr/backups/production/latest.sql.gz /tmp/ --region us-west-2
```

**Step 2: Update DNS** (5 minutes)

```bash
# Update DNS to point to DR region IP
# prod-agl.aglz.io → [DR-IP]

# Use Route53 health checks for automatic failover (if configured)
```

**Step 3: Monitor and Communicate** (ongoing)

```bash
# Update status page
# "Failover to DR region complete. Service operational."

# Monitor AWS status for primary region recovery
# https://status.aws.amazon.com/

# Plan failback when primary region restored
```

---

### Security Incident Recovery

**Scenario**: Ransomware attack detected

**Step 1: Isolate (Immediate)**

```bash
# 1. Disconnect from network
docker network disconnect production_network agl-hostman-app-blue-1
docker network disconnect production_network agl-hostman-app-blue-2

# 2. Block all external traffic
iptables -A INPUT -j DROP
iptables -A OUTPUT -j DROP

# 3. Put site in maintenance mode
# (May not be accessible, update status page from secure location)
```

**Step 2: Assess Damage** (30 minutes)

```bash
# 1. Check file integrity
find /var/lib/docker/volumes -name "*.encrypted" -o -name "*.locked"

# 2. Check database for suspicious activity
docker exec agl-hostman-postgres-primary psql -U postgres -c "
  SELECT * FROM pg_stat_activity WHERE state != 'idle';
"

# 3. Review logs for attack vector
grep -i "ransom\|encrypt\|locked" /var/log/syslog
docker logs agl-hostman-load-balancer | grep -E "(POST|PUT|DELETE)" | tail -1000

# 4. Identify last known clean state
# Check backup integrity
aws s3 ls s3://agl-hostman-backups/backups/production/ | grep "$(date -d '3 days ago' +%Y-%m-%d)"
```

**Step 3: Notify** (15 minutes)

```bash
# 1. Notify security team
# Email: security@agl.com
# Subject: "CRITICAL: Ransomware attack detected - Production environment"

# 2. Notify legal/compliance
# GDPR/data breach notification may be required

# 3. Update status page
# "Security incident detected. Investigation in progress."

# 4. Do NOT pay ransom (company policy)
```

**Step 4: Rebuild Clean Environment** (2 hours)

```bash
# 1. Provision completely new infrastructure
# New container, new IP, new credentials

# 2. Restore from verified clean backup (minimum 3 days old)
# Use backup from before attack started

# 3. Change all credentials
# Database passwords, API keys, SSH keys, certificates

# 4. Apply security patches
# Ensure vulnerability that allowed attack is fixed

# 5. Enhanced monitoring
# Add additional security alerts, WAF rules
```

**Step 5: Forensics and Prevention** (Ongoing)

```bash
# 1. Preserve evidence
# Keep compromised system for forensic analysis
# Take disk snapshots before destruction

# 2. Root cause analysis
# How did attacker gain access?
# What vulnerability was exploited?

# 3. Implement preventions
# Patch vulnerabilities
# Update security policies
# Additional monitoring

# 4. Report to authorities (if required)
```

---

## Testing and Validation

### DR Test Schedule

**Monthly** (1st Sunday, 02:00 UTC):
- Database backup restore test
- Verify backup integrity
- Test application startup from backup

**Quarterly** (1st day of Q):
- Full DR simulation (complete rebuild)
- Measure actual RTO/RPO
- Update DR documentation

**Annually** (January):
- Tabletop exercise with full team
- Regional failover test
- Security incident simulation

### DR Test Procedure

**1. Pre-Test**:
```bash
# Create test environment
# Use separate container/server for testing
# Do NOT test on production

# Schedule notification
# Email team 7 days in advance
# "DR test scheduled for [date]"
```

**2. Execute Test**:
```bash
# Follow recovery procedure for scenario being tested
# Document start time, each step, end time
# Take screenshots/logs as evidence

# Example: Database Recovery Test
# 1. Download production backup
# 2. Create test PostgreSQL instance
# 3. Restore backup
# 4. Verify data integrity
# 5. Measure time taken
```

**3. Post-Test**:
```bash
# Calculate metrics
echo "RTO: [actual time to recover]"
echo "RPO: [actual data loss]"

# Document issues encountered
# What went wrong?
# What can be improved?

# Update DR documentation
# Fix any gaps or errors found

# Send test report to team
# Include: results, issues, action items
```

### Success Criteria

**Metrics**:
- [ ] RTO < 1 hour
- [ ] RPO < 1 hour
- [ ] All smoke tests pass
- [ ] Zero data corruption
- [ ] All services restored

**Documentation**:
- [ ] All steps documented
- [ ] Screenshots captured
- [ ] Logs preserved
- [ ] Metrics recorded
- [ ] Report published

---

## Business Continuity

### Communication Plan

**Internal**:
- **Slack**: #production-incidents (real-time updates)
- **Email**: ops@agl.com (formal notifications)
- **PagerDuty**: On-call escalation

**External**:
- **Status Page**: https://status.agl.com (public updates)
- **Email**: All customers with production subscriptions
- **Twitter/Social**: @AGLStatus (major incidents only)

**Update Frequency**:
- First 15 minutes: Every 5 minutes
- Next 45 minutes: Every 15 minutes
- After 1 hour: Every 30 minutes
- After resolution: Final summary within 24 hours

### Roles and Responsibilities

| Role | Name | Responsibilities |
|------|------|------------------|
| **Incident Commander** | [Name] | Overall coordination, decisions |
| **Technical Lead** | [Name] | Execute recovery procedures |
| **Communications** | [Name] | Status page, customer emails |
| **Security** | [Name] | Security assessments, forensics |
| **Executive Sponsor** | [Name] | Business decisions, escalation |

### Vendor Contacts

| Vendor | Service | Contact | SLA |
|--------|---------|---------|-----|
| AWS | S3 Storage | Support ticket | 1 hour (Enterprise) |
| Proxmox | Hypervisor | Community forum | Best effort |
| Harbor | Registry | GitHub issues | Best effort |
| PostgreSQL | Database | Community support | Best effort |

### Insurance and Legal

**Cyber Insurance**:
- Policy Number: [REDACTED]
- Coverage: $5M
- Deductible: $25K
- Contact: [Insurance Agent]

**Legal Compliance**:
- GDPR: 72-hour breach notification requirement
- HIPAA: N/A (not applicable)
- SOC2: Annual audit required

---

## Appendix

### Backup Inventory

Current backup locations and retention:

```bash
# List all production backups
aws s3 ls s3://agl-hostman-backups/backups/production/ | sort -r

# Check backup sizes
aws s3 ls s3://agl-hostman-backups/backups/production/ --recursive --human-readable | grep "$(date +%Y-%m)"

# Verify Cross-Region Replication
aws s3 ls s3://agl-hostman-backups-dr/ --region us-west-2
```

### Recovery Contacts

**24/7 Emergency Contacts**:
- On-Call Engineer: [Phone]
- DevOps Lead: [Phone]
- CTO: [Phone]

**Vendor Emergency Contacts**:
- AWS Support: 1-800-xxx-xxxx (Enterprise Support)
- PagerDuty: help@pagerduty.com

### Document Maintenance

**Review Schedule**:
- **Monthly**: Update backup inventory
- **Quarterly**: Review and test procedures
- **Annually**: Full DR plan review

**Change Log**:
| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2025-01-20 | 1.0.0 | DevOps Team | Initial release |

---

**Document Version**: 1.0.0
**Classification**: CONFIDENTIAL
**Last Review**: 2025-01-20
**Next Review**: 2025-04-20
**Owner**: DevOps Lead
