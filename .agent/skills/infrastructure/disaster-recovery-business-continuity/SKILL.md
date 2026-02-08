---
name: disaster-recovery-business-continuity
description: "Comprehensive disaster recovery planning including RTO/RPO targets, DR drills, runbooks, failover procedures, and business continuity documentation. Use when planning for disasters, implementing DR strategies, or ensuring business resilience."
category: infrastructure
priority: P2
tags: [disaster-recovery, dr, business-continuity, failover]
---

# Disaster Recovery & Business Continuity

**CRITICAL INFRASTRUCTURE SKILL** - Complete disaster recovery and business continuity framework.

This skill provides comprehensive disaster recovery planning, including RTO/RPO target definition, DR strategy implementation, automated failover procedures, runbooks, DR drills, communication plans, and business continuity documentation. Essential for ensuring business resilience and minimizing downtime during catastrophic events.

## When to use this skill

- Planning disaster recovery strategies for critical infrastructure
- Defining RTO/RPO targets for business applications
- Creating DR runbooks and failover procedures
- Implementing automated failover systems
- Conducting DR drills and testing procedures
- Developing business continuity plans
- Creating stakeholder communication protocols
- Validating DR readiness and recovery capabilities
- Post-incident analysis and documentation
- Multi-region deployment strategies
- High availability architecture design
- Compliance and audit preparation for DR capabilities

## Overview

### Disaster Recovery Framework

Disaster Recovery (DR) is the coordinated process of restoring systems, data, and infrastructure after a catastrophic event. It encompasses:

- **Preparation**: Planning, documentation, and proactive measures
- **Response**: Immediate actions during an incident
- **Recovery**: System restoration and validation
- **Continuity**: Business operations during disruption

### Key Metrics

| Metric | Definition | Typical Target |
|--------|------------|----------------|
| **RTO** | Recovery Time Objective - max acceptable downtime | 1-4 hours |
| **RPO** | Recovery Point Objective - max acceptable data loss | 15 min - 1 hour |
| **MTTD** | Mean Time To Detect - time to identify incident | < 5 minutes |
| **MTTR** | Mean Time To Resolve - time to restore service | Within RTO |

### DR Maturity Levels

| Level | Description | RTO | RPO |
|-------|-------------|-----|-----|
| **1 - Basic** | Manual backups, no automation | Days | Days |
| **2 - Reactive** | Automated backups, manual recovery | Hours | Hours |
| **3 - Proactive** | Automated failover, warm standby | Minutes | Minutes |
| **4 - Resilient** | Active-active, zero downtime | Seconds | Zero |

## Contents

### Scripts (scripts/)

| Script | Purpose |
|--------|---------|
| `dr-failover.sh` | Execute automated DR failover to backup site |
| `dr-validate.sh` | Validate DR readiness (backups, configs, connectivity) |
| `dr-drill.sh` | Run controlled DR drill with simulated failover |
| `dr-notify.sh` | Send DR notifications to stakeholders |
| `dr-report.sh` | Generate DR post-drill/incident reports |

### Templates (templates/)

| Template | Purpose |
|----------|---------|
| `dr-runbook.md` | Complete DR runbook template |
| `incident-response.md` | Incident response procedures |
| `communication-plan.md` | Stakeholder notification templates |
| `rto-rpo-calculator.md` | Recovery objective calculator |

### References (references/)

| Reference | Purpose |
|-----------|---------|
| `dr-runbook.md` | Detailed DR procedures and checklists |
| `rto-rpo-calculator.md` | Interactive calculator for recovery targets |

## RTO/RPO Definition

### Recovery Objectives by System

| System Component | RTO | RPO | Priority | Failover Method |
|------------------|-----|-----|----------|-----------------|
| **Database (Primary)** | 15 min | 5 min | P0 | Automatic failover to replica |
| **Application Servers** | 30 min | Instant | P0 | Auto-scaling group replacement |
| **Load Balancer** | 5 min | Instant | P0 | Multi-AZ deployment |
| **File Storage** | 1 hour | 15 min | P1 | Cross-region replication |
| **Cache Layer** | 15 min | Instant | P1 | Auto-rebuild from primary |
| **Message Queue** | 30 min | 0 | P1 | Clustered deployment |
| **External APIs** | 2 hours | N/A | P2 | Manual reconfiguration |
| **Analytics** | 4 hours | 1 day | P3 | Batch restore from backup |

### RTO/RPO Calculation Formula

```
RTO = Time to detect + Time to decide + Time to execute + Time to validate
RPO = Backup frequency + Replication lag

Example:
RTO = 5 min (detect) + 10 min (decide) + 30 min (execute) + 10 min (validate) = 55 min
RPO = 5 min (backup frequency) + 2 min (replication lag) = 7 min
```

### Business Impact Analysis

| Impact Level | Revenue Impact | User Impact | Reputation Impact | RTO Target |
|--------------|----------------|-------------|-------------------|------------|
| **Critical** | >$10K/hour | All users | Severe damage | < 15 min |
| **High** | $1K-$10K/hour | Most users | Significant | < 1 hour |
| **Medium** | $100-$1K/hour | Some users | Moderate | < 4 hours |
| **Low** | <$100/hour | Few users | Minimal | < 24 hours |

## DR Strategy

### Active-Active Architecture

**Best for**: Critical systems requiring zero downtime

```
                    ┌─────────────────┐
                    │   Global DNS    │
                    │   (Round Robin) │
                    └────────┬────────┘
                             │
              ┌──────────────┴──────────────┐
              │                             │
        ┌─────▼─────┐                 ┌─────▼─────┐
        │  Region A │                 │  Region B │
        │  Primary  │                 │  Primary  │
        │           │                 │           │
        │ ┌─────────┴─────────┐     │ ┌─────────┴─────────┐
        │ │  Load Balancer    │     │ │  Load Balancer    │
        │ └─────────┬─────────┘     │ └─────────┬─────────┘
        │           │                │           │
        │     ┌─────┴─────┐         │     ┌─────┴─────┐
        │     │  App      │         │     │  App      │
        │     │  Servers  │         │     │  Servers  │
        │     └─────┬─────┘         │     └─────┬─────┘
        │           │                │           │
        │     ┌─────┴─────┐         │     ┌─────┴─────┐
        │     │ Database  │◄────────┼─────┤ Database  │
        │     │ Primary   │  Sync   │     │ Primary   │
        │     └───────────┘         │     └───────────┘
        └───────────────────────────┴───────────────────┘
```

**Pros**:
- Zero RPO (synchronous replication)
- Instant failover (automatic)
- Full resource utilization

**Cons**:
- Higher cost (2x infrastructure)
- Complex conflict resolution
- Geographic latency requirements

### Active-Passive Architecture

**Best for**: Most production systems

```
                    ┌─────────────────┐
                    │   Route 53      │
                    │   Health Check  │
                    └────────┬────────┘
                             │
              ┌──────────────┴──────────────┐
              │                             │
        ┌─────▼─────┐                 ┌─────▼─────┐
        │  Region A │                 │  Region B │
        │  ACTIVE   │                 │  STANDBY  │
        │           │                 │           │
        │ ┌─────────┴─────────┐       │ ┌─────────┴─────────┐
        │ │  Load Balancer    │       │ │  Load Balancer    │
        │ │    (Active)       │       │ │    (Standby)      │
        │ └─────────┬─────────┘       │ └─────────┬─────────┘
        │           │                  │           │
        │     ┌─────┴─────┐            │     ┌─────┴─────┐
        │     │  App      │            │     │  App      │
        │     │  Servers  │            │     │  Servers  │
        │     └─────┬─────┘            │     └─────┬─────┘
        │           │                  │           │
        │     ┌─────┴─────┐            │     ┌─────┴─────┐
        │     │ Database  │───────────┼─────┤ Database  │
        │     │ Primary   │  Async    │     │ Replica   │
        │     └───────────┘  Replicate│     └───────────┘
        └───────────────────────────┴───────────────────┘
```

**Pros**:
- Lower cost (passive site can be smaller)
- Simpler failover logic
- Clear primary/secondary roles

**Cons**:
- RPO > 0 (async replication lag)
- Failover time required
- Passive resources idle

### Pilot Light Architecture

**Best for**: Cost-optimized DR with acceptable RTO

```
                    ┌─────────────────┐
                    │   Route 53      │
                    │   Health Check  │
                    └────────┬────────┘
                             │
        ┌────────────────────┴────────────────────┐
        │                                         │
  ┌─────▼─────┐                           ┌─────▼─────┐
  │  Region A │                           │  Region B │
  │  ACTIVE   │                           │  PILOT    │
  │           │                           │   LIGHT   │
  │ ┌─────────┴─────────┐                 │ ┌─────────┴─────────┐
  │ │  Load Balancer    │                 │ │  Load Balancer    │
  │ │    (Active)       │                 │ │    (Stopped)      │
  │ └─────────┬─────────┘                 │ └─────────┬─────────┘
  │           │                           │           │
  │     ┌─────┴─────┐                     │     ┌─────┴─────┐
  │     │  App      │                     │     │  App      │
  │     │  Servers  │                     │     │  Servers  │
  │     │ (Scaled)  │                     │     │ (Min-Size) │
  │     └─────┬─────┘                     │     └─────┬─────┘
  │           │                           │           │
  │     ┌─────┴─────┐                     │     ┌─────┴─────┐
  │     │ Database  │─────────────────────┼─────┤ Database  │
  │     │ Primary   │  Backup Replication │     │ Replica   │
  │     └───────────┘                     │     └───────────┘
  └───────────────────────────────────────┴───────────────────┘
```

**Pros**:
- Lowest cost (minimal standby resources)
- Faster recovery than cold start
- Good RTO (1-2 hours)

**Cons**:
- Longer RTO than active-passive
- Scaling time adds to RTO
- Complex recovery automation

## Runbooks

### Standard DR Runbook Structure

```markdown
# Disaster Recovery Runbook - [System Name]

## 1. Incident Detection
- [ ] Alert received from monitoring system
- [ ] Verify incident scope and severity
- [ ] Determine affected systems and users

## 2. Initial Assessment
- [ ] Identify root cause (if known)
- [ ] Estimate time to resolution
- [ ] Declare incident severity level (P0-P3)

## 3. Activation Decision
- [ ] If RTO cannot be met in primary region:
  - [ ] Initiate DR failover
  - [ ] Notify stakeholders
  - [ ] Begin failover checklist

## 4. Failover Execution
- [ ] Pre-flight checks
- [ ] Database promotion
- [ ] Application startup
- [ ] DNS cutover
- [ ] Verification tests

## 5. Post-Failover
- [ ] Monitor system health
- [ ] Validate all services
- [ ] Update documentation

## 6. Return to Normal
- [ ] Root cause analysis
- [ ] Primary region repair
- [ ] Failback planning
- [ ] Post-incident review
```

### Runbook Categories

| Category | Examples | Update Frequency |
|----------|----------|------------------|
| **System-Specific** | Database failover, app recovery | Quarterly |
| **Process-Based** | Incident response, communication | Annually |
| **Role-Based** | On-call procedures, escalation | As needed |
| **Scenario-Based** | Region failure, data center outage | After each drill |

### Runbook Maintenance

```bash
# Schedule quarterly runbook reviews
0 9 1 */3 * /path/to/scripts/dr-validate.sh --review-runbooks

# Runbook validation checklist
- [ ] All contact information current
- [ ] All commands tested and working
- [ ] All dependencies documented
- [ ] All RTO/RPO targets valid
- [ ] All screenshots/outputs updated
- [ ] All lessons learned incorporated
```

## Failover Procedures

### Automated Failover Decision Tree

```
                    ┌─────────────────┐
                    │  Incident       │
                    │  Detected       │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │ Is Primary      │
                    │ Region Healthy? │
                    └────────┬────────┘
                             │
              ┌──────────────┴──────────────┐
              │ YES                         │ NO
              │                             │
        ┌─────▼─────┐               ┌───────▼──────┐
        │ Attempt   │               │ Check RTO    │
        │ Local     │               │ Timer        │
        │ Recovery  │               └───────┬──────┘
        └─────┬─────┘                       │
              │                    ┌────────▼────────┐
        ┌─────┴─────┐              │ Can we meet RTO │
        │ Recovered │              │ locally?        │
        │           │              └────────┬────────┘
        │           │                       │
        │           │           ┌───────────┴───────────┐
        │           │           │ YES                  │ NO
        │           │           │                      │
        │           │     ┌─────▼─────┐         ┌─────▼─────┐
        │           │     │ Continue  │         │ Trigger   │
        │           │     │ Local     │         │ DR        │
        │           │     │ Recovery  │         │ Failover  │
        │           │     └───────────┘         └───────────┘
```

### Failover Checklist

```bash
#!/bin/bash
# Pre-Failover Checklist

echo "=== Pre-Failover Validation ==="

# 1. Health check backup region
echo "[1/10] Checking backup region health..."
curl -f https://backup-region.example.com/health || exit 1

# 2. Verify database replication status
echo "[2/10] Verifying database replication..."
mysql -h backup-db -e "SHOW SLAVE STATUS\G" | grep "Seconds_Behind_Master: [0-9]"

# 3. Check backup capacity
echo "[3/10] Checking backup region capacity..."
curl -f https://backup-region.example.com/api/capacity || exit 1

# 4. Verify DNS health checks
echo "[4/10] Verifying DNS configuration..."
aws route53 list-health-checks --query "HealthChecks[?Id=='DR-FAILOVER']"

# 5. Validate configuration sync
echo "[5/10] Validating configuration synchronization..."
diff /etc/app/config.yml <(ssh backup-region "cat /etc/app/config.yml")

# 6. Test authentication systems
echo "[6/10] Testing authentication..."
curl -f https://backup-region.example.com/auth/test || exit 1

# 7. Verify external dependencies
echo "[7/10] Checking external dependencies..."
./scripts/check-external-deps.sh

# 8. Alert stakeholders (pre-failover notification)
echo "[8/10] Sending pre-failover notifications..."
./scripts/dr-notify.sh --type pre-failover --severity high

# 9. Enable monitoring on backup
echo "[9/10] Enabling backup monitoring..."
./scripts/enable-monitoring.sh backup-region

# 10. Final confirmation
echo "[10/10] Awaiting final confirmation..."
read -p "Execute failover? (yes/no): " confirm
[[ "$confirm" == "yes" ]] || exit 1

echo "=== Pre-Failover Validation Complete ==="
```

### DNS Failover Strategy

```bash
# Route 53 DNS failover configuration
aws route53 change-resource-record-sets \
  --hosted-zone-id Z123EXAMPLE \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "app.example.com",
        "Type": "A",
        "SetIdentifier": "primary-failover",
        "Failover": "PRIMARY",
        "AliasTarget": {
          "HostedZoneId": "ZONE1",
          "DNSName": "primary-lb.example.com",
          "EvaluateTargetHealth": true
        }
      }
    }, {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "app.example.com",
        "Type": "A",
        "SetIdentifier": "dr-failover",
        "Failover": "SECONDARY",
        "AliasTarget": {
          "HostedZoneId": "ZONE2",
          "DNSName": "dr-lb.example.com",
          "EvaluateTargetHealth": true
        }
      }
    }]
  }'
```

## DR Drills

### Drill Types

| Drill Type | Frequency | Duration | Scope | Purpose |
|------------|-----------|----------|-------|---------|
| **Tabletop** | Monthly | 1-2 hours | Discussion | Process validation |
| **Simulation** | Quarterly | 2-4 hours | Technical | Procedure testing |
| **Partial Failover** | Semi-annually | 4-8 hours | System | Component testing |
| **Full Failover** | Annually | 8-24 hours | Complete | End-to-end validation |

### Tabletop Drill Format

```markdown
# Tabletop DR Drill - [Date]

## Scenario
[Describe hypothetical disaster scenario]

## Participants
- Incident Commander: [Name]
- Database Lead: [Name]
- Application Lead: [Name]
- DevOps Lead: [Name]
- Communications: [Name]

## Timeline

### T+0: Incident Detection
- [ ] Alert received
- [ ] Severity assessment
- [ ] Team notification

### T+15min: Initial Response
- [ ] Incident declaration
- [ ] Stakeholder notification
- [ ] Documentation start

### T+30min: Assessment Complete
- [ ] Root cause identified
- [ ] RTO evaluation
- [ ] Failover decision

### T+1hour: Recovery Actions
- [ ] Failover initiated
- [ ] Systems restored
- [ ] Validation complete

### T+2hours: Post-Incident
- [ ] Monitoring established
- [ ] Communication sent
- [ ] Documentation complete

## Action Items
- [ ] Item 1
- [ ] Item 2

## Lessons Learned
- Learning 1
- Learning 2
```

### Simulation Drill Script

```bash
#!/bin/bash
# DR Simulation Drill - Controlled environment test

DRILL_ID="drill-$(date +%Y%m%d-%H%M%S)"
LOG_FILE="/var/log/dr/drill-${DRILL_ID}.log"

echo "=== DR Drill Started: ${DRILL_ID} ===" | tee -a "$LOG_FILE"

# Phase 1: Pre-drill validation
echo "[Phase 1] Pre-drill validation" | tee -a "$LOG_FILE"
./scripts/dr-validate.sh --drill-mode | tee -a "$LOG_FILE"

# Phase 2: Simulated incident
echo "[Phase 2] Simulating incident..." | tee -a "$LOG_FILE"
# Inject failure without actual impact
./scripts/simulate-failure.sh --type region --target primary | tee -a "$LOG_FILE"

# Phase 3: Automated response
echo "[Phase 3] Testing automated response..." | tee -a "$LOG_FILE"
./scripts/test-auto-failover.sh --dry-run | tee -a "$LOG_FILE"

# Phase 4: Manual failover (dry-run)
echo "[Phase 4] Testing manual failover procedure..." | tee -a "$LOG_FILE"
./scripts/dr-failover.sh --dry-run --validate-only | tee -a "$LOG_FILE"

# Phase 5: Verification
echo "[Phase 5] Verifying backup readiness..." | tee -a "$LOG_FILE"
./scripts/dr-validate.sh --region backup | tee -a "$LOG_FILE"

# Phase 6: Rollback
echo "[Phase 6] Rolling back simulation..." | tee -a "$LOG_FILE"
./scripts/rollback-simulation.sh | tee -a "$LOG_FILE"

# Phase 7: Report
echo "[Phase 7] Generating drill report..." | tee -a "$LOG_FILE"
./scripts/dr-report.sh --drill-id "${DRILL_ID}" | tee -a "$LOG_FILE"

echo "=== DR Drill Completed: ${DRILL_ID} ===" | tee -a "$LOG_FILE"
```

### Drill Success Criteria

```yaml
Drill Success Criteria:
  Simulation:
    - All steps completed without errors
    - Documentation updated
    - Lessons learned documented

  Partial Failover:
    - Failed-over systems functional
    - RTO target met
    - Data integrity verified
    - No production impact

  Full Failover:
    - Complete cutover successful
    - All RTO/RPO targets met
    - No data loss
    - All services validated
    - Users notified
    - Failback plan confirmed

  Overall:
    - Runbook accuracy: 100%
    - Team familiarity: Improved
    - Process gaps identified
    - Action items created
```

## Communication Plan

### Stakeholder Matrix

| Stakeholder | Notification Trigger | Method | Frequency | Content |
|-------------|---------------------|--------|-----------|---------|
| **Executive Team** | P0 incidents | SMS + Call | Immediate | Impact, timeline, actions |
| **Engineering** | All incidents | Slack + Email | Immediate | Technical details, runbooks |
| **Support Team** | User-facing issues | Slack + Email | Immediate | User impact, workaround |
| **Customers** | P0/P1 outages | Email + Status Page | 15 min | Impact, ETA, next update |
| **Public** | Extended outages | Status Page + Twitter | 30 min | High-level status only |

### Communication Timeline

```bash
# T+0: Initial Detection
./scripts/dr-notify.sh --type detection \
  --severity P0 \
  --channels engineering,executive \
  --message "Incident detected: [service] unavailable"

# T+15min: Incident Declaration
./scripts/dr-notify.sh --type declaration \
  --severity P0 \
  --channels all \
  --message "P0 declared: DR failover initiated"

# T+30min: Progress Update
./scripts/dr-notify.sh --type update \
  --severity P0 \
  --channels all \
  --message "Failover in progress: ETA 45 min"

# T+1hour: Resolution
./scripts/dr-notify.sh --type resolved \
  --severity P0 \
  --channels all \
  --message "Service restored: DR failover complete"

# T+24hours: Post-Mortem
./scripts/dr-notify.sh --type postmortem \
  --channels engineering,executive \
  --message "Post-mortem published: [link]"
```

### Status Page Templates

```markdown
## Incident Template

### [INCIDENT-001] - [Service] Degradation

**Status:** [Investigating | Identified | Monitoring | Resolved]
**Started:** [Timestamp]
**Duration:** [X hours Y minutes]

---

#### [Latest Update - Timestamp]
[Description of current status and next steps]

#### [Previous Update - Timestamp]
[Earlier updates]

#### [Initial Update - Timestamp]
We are currently investigating issues with [service].
Users may experience [symptoms]. Next update in 15 minutes.

---

**Affected Services:**
- [Service 1]
- [Service 2]

**Alternative Workaround:**
[If available]

**Next Update:** [Timestamp]
```

## Recovery Validation

### Validation Checklist

```bash
#!/bin/bash
# Post-failover validation script

VALIDATION_LOG="/var/log/dr/validation-$(date +%Y%m%d-%H%M%S).log"

echo "=== Post-Failover Validation ===" | tee "$VALIDATION_LOG"

# System health checks
checks=(
  "dns-resolution:Check DNS propagation"
  "load-balancer:Verify load balancer health"
  "application:Test application endpoints"
  "database:Verify database connectivity"
  "cache:Check cache layer"
  "queue:Verify message queue"
  "storage:Test file storage"
  "external:Check external dependencies"
)

passed=0
failed=0
total=${#checks[@]}

for check in "${checks[@]}"; do
  IFS=':' read -r name description <<< "$check"
  echo -n "Checking $description... "

  if "./scripts/check-$name.sh" >> "$VALIDATION_LOG" 2>&1; then
    echo "PASS"
    ((passed++))
  else
    echo "FAIL"
    ((failed++))
  fi
done

echo "" | tee -a "$VALIDATION_LOG"
echo "Validation Summary:" | tee -a "$VALIDATION_LOG"
echo "  Passed: $passed/$total" | tee -a "$VALIDATION_LOG"
echo "  Failed: $failed/$total" | tee -a "$VALIDATION_LOG"

if [ $failed -eq 0 ]; then
  echo "FAILOVER VALIDATED SUCCESSFULLY" | tee -a "$VALIDATION_LOG"
  exit 0
else
  echo "FAILOVER VALIDATION FAILED" | tee -a "$VALIDATION_LOG"
  exit 1
fi
```

### Health Check Endpoints

```yaml
# Required health check endpoints
health_checks:
  application:
    endpoint: /health
    method: GET
    response:
      status: 200
      body:
        status: healthy
        version: "1.0.0"
        dependencies:
          database: ok
          cache: ok
          queue: ok

  database:
    endpoint: /health/database
    method: GET
    response:
      status: 200
      body:
        status: ok
        latency: <100ms
        replication_lag: <5s

  deep:
    endpoint: /health/deep
    method: GET
    response:
      status: 200
      body:
        status: ok
        checks:
          database: ok
          cache: ok
          queue: ok
          storage: ok
          external_api: ok
```

### Rollback Criteria

| Criteria | Trigger Condition | Action |
|----------|-------------------|--------|
| **Validation Failures** | > 20% health checks fail | Rollback immediately |
| **Data Inconsistency** | Replication lag > 5 min | Rollback immediately |
| **Performance** | Response time > 3x baseline | Evaluate rollback |
| **Error Rate** | Error rate > 10% | Rollback immediately |
| **User Reports** | > 100 critical user reports | Evaluate rollback |

## Documentation

### Living Documentation Policy

```yaml
Documentation Requirements:
  Runbooks:
    update_frequency: Quarterly
    review_frequency: Monthly
    owner: SRE Team
    location: /docs/runbooks/

  RTO/RPO Targets:
    update_frequency: Annually
    review_frequency: Quarterly
    owner: Product + Engineering
    location: /docs/dr/targets.yml

  Communication Plans:
    update_frequency: Semi-annually
    review_frequency: Quarterly
    owner: Communications Team
    location: /docs/dr/communication/

  Drill Reports:
    update_frequency: After each drill
    review_frequency: At next drill
    owner: SRE Team
    location: /docs/dr/reports/

  Post-Incident Reviews:
    update_frequency: After each incident
    review_frequency: Quarterly summary
    owner: Incident Commander
    location: /docs/incidents/
```

### Documentation Template

```markdown
# [Document Title]

**Document ID:** [UNIQUE-ID]
**Version:** [X.Y]
**Last Updated:** [DATE]
**Owner:** [TEAM]
**Review Date:** [DATE]

## Purpose
[Why this document exists]

## Scope
[What this document covers]

## Prerequisites
[Required knowledge or access]

## Procedures
[Step-by-step procedures]

## Validation
[How to verify correctness]

## Related Documents
- [Link 1]
- [Link 2]

## Change History
| Date | Version | Changes | Author |
|------|---------|---------|--------|
| YYYY-MM-DD | 1.0 | Initial | [Name] |
```

## Post-Mortem

### Post-Incident Analysis Format

```markdown
# Post-Incident Review: [INCIDENT-ID]

## Executive Summary
[Brief overview for stakeholders]

## Timeline

| Time | Event | Duration | Owner |
|------|-------|----------|-------|
| 00:00 | Incident detected | - | System |
| 00:05 | On-call notified | 5 min | PagerDuty |
| 00:10 | Incident declared | 5 min | Lead |
| 01:00 | Failover initiated | 50 min | Lead |
| 01:30 | Service restored | 30 min | Team |

## Impact Assessment
- **Downtime:** X hours Y minutes
- **Affected Users:** N users
- **Revenue Impact:** $X (if applicable)
- **Data Loss:** None / X records

## Root Cause Analysis
[5 Whys or Fishbone diagram]

### What happened
[Factual description]

### Why it happened
[Root cause identification]

### How it happened
[Technical details]

## Resolution Steps
1. [Action taken]
2. [Action taken]
3. [Action taken]

## Action Items

### Immediate (Completed)
- [x] [Item] - [Owner] - [Date]

### Short-term (In Progress)
- [ ] [Item] - [Owner] - [Date]

### Long-term (Planned)
- [ ] [Item] - [Owner] - [Date]

## Lessons Learned
1. [What went well]
2. [What could be improved]
3. [Surprises discovered]

## Follow-up Review
**Date:** [Scheduled review date]
**Attendees:** [Required attendees]

## References
- [Runbook used]
- [Monitoring dashboards]
- [Related incidents]
```

### Continuous Improvement Process

```bash
#!/bin/bash
# Post-incident action item tracker

# Extract action items from post-mortems
grep -r "^\- \[ \]" /docs/incidents/ | \
  sed 's/.*\[ \] //' | \
  sort | uniq -c | sort -rn

# Categorize action items
echo "Action Item Categories:"
echo "  Process: $(grep -c 'process' /docs/incidents/*)"
echo "  Documentation: $(grep -c 'documentation' /docs/incidents/*)"
echo "  Monitoring: $(grep -c 'monitoring' /docs/incidents/*)"
echo "  Automation: $(grep -c 'automation' /docs/incidents/*)"

# Track completion rate
echo "Completion Rate: $(grep -c '^\- \[x\]' /docs/incidents/*) / $(grep -c '^\- \[.\]' /docs/incidents/*)"
```

## Best Practices

1. **Test regularly** - Untested DR plans fail when needed
2. **Automate failover** - Manual processes fail under pressure
3. **Document everything** - Runbooks must be step-by-step
4. **Communicate proactively** - Stakeholders hate surprises
5. **Learn from drills** - Treat drills like real incidents
6. **Update continuously** - DR docs are living documents
7. **Define clear RTO/RPO** - Metrics drive all decisions
8. **Practice failback** - Returning to normal is also risky
9. **Review dependencies** - External systems can fail too
10. **Plan for people** - Staff availability during disasters

## Quick Start

```bash
# Validate DR readiness
./scripts/dr-validate.sh

# Run a simulation drill
./scripts/dr-drill.sh --type simulation

# Test failover (dry-run)
./scripts/dr-failover.sh --dry-run

# Generate DR readiness report
./scripts/dr-report.sh --type readiness
```

## References

- [Backup Automation](../backup-automation-verification/SKILL.md)
- [Alert Management](../../monitoring/alert-management/SKILL.md)
- [Performance Monitoring](../../monitoring/performance-monitoring/SKILL.md)
- [Proxmox Infrastructure](../proxmox-infrastructure-management/SKILL.md)
