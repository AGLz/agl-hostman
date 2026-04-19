# Disaster Recovery Runbook

**Version:** 2.0
**Last Updated:** 2025-01-07
**Owner:** SRE Team
**Review Date:** 2025-04-07

## Table of Contents

1. [Purpose](#purpose)
2. [Scope](#scope)
3. [Roles and Responsibilities](#roles-and-responsibilities)
4. [Incident Detection](#incident-detection)
5. [Severity Classification](#severity-classification)
6. [Failover Procedures](#failover-procedures)
7. [Recovery Validation](#recovery-validation)
8. [Return to Normal Operations](#return-to-normal-operations)
9. [Communication Plan](#communication-plan)
10. [Post-Incident Procedures](#post-incident-procedures)

## Purpose

This runbook provides step-by-step procedures for responding to catastrophic infrastructure events and executing disaster recovery failover. It ensures minimal downtime and data loss during disaster scenarios.

## Scope

This runbook covers:

- Complete region failure scenarios
- Database corruption and recovery
- Network connectivity outages
- Application-level disasters
- Data center evacuations

**Out of scope:**
- Single server failures (handled by auto-scaling)
- Individual service restarts (handled by monitoring)
- Routine maintenance procedures

## Roles and Responsibilities

### Incident Commander (IC)

**Responsibilities:**
- Declare incidents and severity level
- Coordinate all DR activities
- Make final failover decisions
- Communicate with executives

**Authority:**
- Can initiate DR failover
- Can allocate emergency resources
- Can declare incident resolved

### Database Lead

**Responsibilities:**
- Assess database status and health
- Execute database failover procedures
- Validate data integrity post-recovery
- Estimate RPO compliance

**Authority:**
- Can promote replica to primary
- Can stop/start replication

### Application Lead

**Responsibilities:**
- Verify application health
- Coordinate application deployment
- Test critical user flows
- Validate feature completeness

**Authority:**
- Can restart application services
- Can change feature flags

### DevOps Lead

**Responsibilities:**
- Execute infrastructure failover
- Manage DNS changes
- Monitor system metrics
- Coordinate with cloud providers

**Authority:**
- Can execute DR failover script
- Can change DNS records

### Communications Lead

**Responsibilities:**
- Notify stakeholders
- Update status pages
- Draft customer communications
- Manage media inquiries (if needed)

**Authority:**
- Can send notifications to all channels
- Can update public status pages

## Incident Detection

### Automated Detection

Incidents are detected by monitoring systems when:

1. **Primary Region Unreachable** (> 2 minutes)
   - Health checks fail for all services in primary region
   - Network connectivity lost

2. **Database Primary Down** (> 1 minute)
   - Primary database not responding
   - Replication lag exceeds 5 minutes

3. **Application-Wide Outage** (> 2 minutes)
   - Error rate > 50% across all instances
   - No healthy application instances

### Manual Detection

Team members can declare incidents by:

1. On-call engineer: Create alert in monitoring system
2. Any engineer: Contact on-call engineer directly
3. Executive request: Notify on-call immediately

### Initial Assessment Checklist

```
[ ] Confirm incident scope (how many systems affected)
[ ] Determine user impact (how many users affected)
[ ] Identify potential root cause (if known)
[ ] Estimate time to resolution (initial guess)
[ ] Check for ongoing maintenance/changes
[ ] Review recent deployments
```

## Severity Classification

### P0 - Critical

**Definition:** Complete service outage affecting all users

**Examples:**
- Primary region failure
- Database corruption
- Complete application outage

**Response Time:** < 5 minutes
**Notification Required:** All stakeholders
**DR Activation:** Automatic

### P1 - High

**Definition:** Major functionality broken affecting most users

**Examples:**
- Multiple services down
- Severe performance degradation
- Data integrity issues

**Response Time:** < 15 minutes
**Notification Required:** Engineering + Executives
**DR Activation:** Consider if RTO at risk

### P2 - Medium

**Definition:** Significant issues affecting some users

**Examples:**
- Single service outage
- Regional issues
- Feature-level failures

**Response Time:** < 1 hour
**Notification Required:** Engineering team
**DR Activation:** Manual evaluation

### P3 - Low

**Definition:** Minor issues with limited impact

**Examples:**
- Single endpoint failure
- Non-critical features down
- UI issues

**Response Time:** < 4 hours
**Notification Required:** On rotation
**DR Activation:** Not required

## Failover Procedures

### Pre-Failover Checklist

```
[ ] Incident declared with appropriate severity
[ ] Primary region confirmed unrecoverable within RTO
[ ] Backup region validated and ready
[ ] Stakeholders notified of pending failover
[ ] Runbook reviewed by all team members
[ ] Rollback plan confirmed
[ ] Communication plan activated
```

### Automated Failover Execution

**Step 1: Execute Failover Script**

```bash
# SSH to DR jump host
ssh dr-jump.example.com

# Execute failover
./scripts/dr-failover.sh --region backup
```

**Step 2: Monitor Failover Progress**

```bash
# Watch failover log
tail -f /var/log/dr/failover-*.log

# Monitor health checks
watch -n 5 './scripts/health-check.sh'
```

**Step 3: Verify Systems**

```bash
# Run validation
./scripts/dr-validate.sh --region backup
```

### Manual Failover (If Automation Fails)

**Step 1: Database Failover**

```bash
# Connect to backup database
mysql -h db-backup.example.com

# Stop replication
STOP SLAVE;

# Reset slave status
RESET SLAVE ALL;

# Set read-write mode
SET GLOBAL read_only = OFF;
```

**Step 2: Application Failover**

```bash
# SSH to backup application servers
ssh app-backup-01.example.com

# Start application services
systemctl start application.service
systemctl start nginx.service

# Verify health
curl -f http://localhost:8080/health
```

**Step 3: DNS Failover**

```bash
# Update Route 53
aws route53 change-resource-record-sets \
  --hosted-zone-id Z123EXAMPLE \
  --change-batch file://failover-change.json
```

**Change batch file:**
```json
{
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "app.example.com",
      "Type": "CNAME",
      "SetIdentifier": "dr-failover",
      "Failover": "SECONDARY",
      "TTL": 60,
      "ResourceRecords": [{"Value": "lb-backup.example.com"}]
    }
  }]
}
```

### Failover Rollback

**If failover fails or issues discovered:**

```bash
# Execute rollback
./scripts/dr-failover.sh --region primary --rollback

# Manual rollback DNS
aws route53 change-resource-record-sets \
  --hosted-zone-id Z123EXAMPLE \
  --change-batch file://rollback-change.json
```

## Recovery Validation

### System Health Checks

```bash
# Run comprehensive validation
./scripts/health-check.sh --comprehensive
```

**Required Checks:**

| Check | Command | Expected Result |
|-------|---------|-----------------|
| DNS Resolution | `host app.example.com` | Backup LB address |
| Load Balancer | `curl https://app.example.com/health` | 200 OK |
| Application | `curl https://app.example.com/api/status` | All systems operational |
| Database | `mysql -h db-backup -e "SELECT 1"` | Connected |
| Cache | `redis-cli -h cache-backup PING` | PONG |
| External APIs | `./scripts/check-external-apis.sh` | All pass |

### Data Integrity Validation

```sql
-- Row count verification
SELECT COUNT(*) FROM critical_table;
-- Compare with expected count

-- Checksum validation
CHECKSUM TABLE critical_table;

-- Recent data verification
SELECT MAX(created_at) FROM critical_table;
-- Should be within RPO target
```

### User Journey Validation

**Critical User Flows to Test:**

1. User login and authentication
2. Data creation and persistence
3. Data retrieval and display
4. File upload/download
5. API endpoint access
6. Background job processing

### Performance Validation

```bash
# Run load tests
./scripts/load-test.sh --region backup --users 1000

# Check response times
./scripts/performance-check.sh --threshold 500ms
```

**Acceptance Criteria:**

- P50 response time < 200ms
- P95 response time < 500ms
- P99 response time < 1000ms
- Error rate < 0.1%

## Return to Normal Operations

### Failback Decision Tree

```
Is primary region repaired?
├─ YES
│  ├─ Is backup region stable for > 2 hours?
│  │  ├─ YES → Schedule failback
│  │  └─ NO  → Continue monitoring
│  └─ Is failback during business hours preferred?
│     ├─ YES → Schedule for maintenance window
│     └─ NO  → Immediate failback
└─ NO → Continue in backup region
```

### Failback Procedures

**Step 1: Preparation**

```bash
# Verify primary region health
./scripts/dr-validate.sh --region primary

# Sync any data created during failover
./scripts/sync-region-data.sh --from backup --to primary
```

**Step 2: Database Failback**

```bash
# Promote primary back to primary
mysql -h db-primary.example.com
SET GLOBAL read_only = OFF;

# Setup replication from backup to primary
CHANGE MASTER TO MASTER_HOST='db-backup.example.com';
START SLAVE;
```

**Step 3: Application Failback**

```bash
# Start services in primary
ssh app-primary-01.example.com
systemctl start application.service

# Verify health
curl http://localhost:8080/health
```

**Step 4: DNS Failback**

```bash
# Update DNS to point to primary
aws route53 change-resource-record-sets \
  --hosted-zone-id Z123EXAMPLE \
  --change-batch file://failback-change.json
```

**Step 5: Final Validation**

```bash
# Run full validation
./scripts/dr-validate.sh --region primary

# Monitor for 1 hour before standing down
```

## Communication Plan

### Notification Timeline

| Time | Action | Channel | Audience |
|------|--------|---------|----------|
| T+0 | Incident declared | Slack, Email | Engineering |
| T+15min | Severity P0/P1 | Slack, Email, SMS | All stakeholders |
| T+30min | Failover initiated | Slack, Email, Status Page | All stakeholders |
| T+1hour | Progress update | Slack, Email, Status Page | All stakeholders |
| T+2hours | Resolution | Slack, Email, Status Page | All stakeholders |
| T+24hours | Post-mortem | Email | Engineering |

### Status Page Templates

**Initial Incident:**
```markdown
## Investigating - Service Degradation

We are currently investigating issues with our service. Users may experience intermittent errors. Next update in 15 minutes.

**Started:** 2025-01-07 14:30 UTC
**Affected:** All services
```

**Failover In Progress:**
```markdown
## Identified - DR Failover Initiated

We are failing over to our backup region. Some users may experience brief disruptions. We expect to restore service within 1 hour.

**Started:** 2025-01-07 14:30 UTC
**ETA:** 2025-01-07 15:30 UTC
```

**Service Restored:**
```markdown
## Resolved - Service Restored

DR failover completed successfully. All services are now operational. We are monitoring for any issues.

**Resolved:** 2025-01-07 15:15 UTC
**Duration:** 45 minutes
```

### Stakeholder Communication

**Executive Team:**
- Immediate notification for P0/P1
- Business impact assessment
- Revenue impact (if applicable)
- ETA for resolution
- Progress updates every 30 minutes

**Engineering Team:**
- All incidents (P0-P3)
- Technical details and logs
- Runbook steps in progress
- Request for assistance if needed

**Support Team:**
- P0/P1 incidents only
- Customer impact summary
- Workarounds if available
- Expected resolution time

**Customers:**
- P0/P1 incidents affecting core functionality
- High-level status only
- ETA for resolution
- Status page link

## Post-Incident Procedures

### Immediate Actions (T+0 to T+24hours)

```
[ ] Document incident timeline
[ ] Collect all logs and metrics
[ ] Schedule post-mortem meeting
[ ] Identify action items
[ ] Update runbook if needed
```

### Post-Mortem Meeting (T+24 to T+72 hours)

**Attendees Required:**
- Incident Commander
- All technical leads involved
- Communications lead
- Engineering manager

**Agenda:**

1. Timeline review
2. Root cause analysis (5 Whys)
3. Response effectiveness assessment
4. What went well
5. What could be improved
6. Action items assignment
7. Runbook updates needed

### Post-Mortem Report Template

```markdown
# Post-Incident Review: [INCIDENT-ID]

## Executive Summary
[2-3 sentence overview for executives]

## Timeline
| Time | Event | Duration |
|------|-------|----------|
| ... | ... | ... |

## Impact Assessment
- **Downtime:** X hours Y minutes
- **Affected Users:** N
- **Revenue Impact:** $X (if applicable)
- **Data Loss:** None / X records

## Root Cause Analysis
### What happened
[Factual description]

### Why it happened (5 Whys)
1. Why?
2. Why?
3. Why?
4. Why?
5. Why?

### How to prevent
[Preventive measures]

## Action Items

### Immediate (Completed)
- [ ] [Item] - [Owner] - [Date]

### Short-term (In Progress)
- [ ] [Item] - [Owner] - [Date]

### Long-term (Planned)
- [ ] [Item] - [Owner] - [Date]

## Lessons Learned
1. What went well
2. What could be improved
3. Surprises discovered
```

### Continuous Improvement

**Quarterly Review Tasks:**

```
[ ] Review all incidents from past quarter
[ ] Identify recurring themes
[ ] Update RTO/RPO targets if needed
[ ] Schedule next DR drill
[ ] Review and update runbooks
[ ] Update training materials
```

## Appendix

### Quick Reference Commands

```bash
# Failover
./scripts/dr-failover.sh

# Validation
./scripts/dr-validate.sh --region backup

# Health check
./scripts/health-check.sh

# Notifications
./scripts/dr-notify.sh --type detection --severity P0 --message "Incident detected"

# Report generation
./scripts/dr-report.sh --type readiness
```

### Contact Information

| Role | Name | Phone | Email |
|------|------|-------|-------|
| Incident Commander | [Name] | [Phone] | [Email] |
| Database Lead | [Name] | [Phone] | [Email] |
| Application Lead | [Name] | [Phone] | [Email] |
| DevOps Lead | [Name] | [Phone] | [Email] |
| Communications Lead | [Name] | [Phone] | [Email] |

### Related Documents

- [Backup Automation](../backup-automation-verification/SKILL.md)
- [Alert Management](../../monitoring/alert-management/SKILL.md)
- [Performance Monitoring](../../monitoring/performance-monitoring/SKILL.md)

## Change History

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2025-01-07 | 2.0 | Complete restructure, added failback procedures | SRE Team |
| 2024-10-15 | 1.1 | Added post-mortem template | SRE Team |
| 2024-07-01 | 1.0 | Initial version | SRE Team |
