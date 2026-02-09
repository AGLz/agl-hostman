# Runbooks - AGL Hostman Incident Response

## Overview

This directory contains runbooks for common incidents in the AGL Hostman platform. Each runbook provides step-by-step procedures for diagnosing and resolving incidents.

## Using These Runbooks

### Before an Incident

1. **Familiarize yourself** with the structure and procedures
2. **Bookmark critical runbooks** in your browser
3. **Practice scenarios** during on-call training
4. **Update runbooks** after incidents

### During an Incident

1. **Identify the issue** using monitoring dashboards
2. **Find the relevant runbook** from the index below
3. **Follow the procedures** step by step
4. **Document actions** in the incident timeline
5. **Communicate progress** to stakeholders

### After an Incident

1. **Complete the postmortem**
2. **Update the runbook** with lessons learned
3. **Share improvements** with the team

## Runbook Index

### Application Incidents

| Runbook | Severity | Scenario | Est. Resolution Time |
|---------|----------|----------|---------------------|
| [Service Down](./service-down.md) | Critical | Service completely unavailable | 15-30 min |
| [High Error Rate](./high-error-rate.md) | Warning/Critical | Elevated 5xx errors | 10-20 min |
| [High Latency](./high-latency.md) | Warning/Critical | Slow response times | 20-40 min |
| [Database Slow Queries](./slow-queries.md) | Warning | Database performance degradation | 30-60 min |
| [Queue Backlog](./queue-backlog.md) | Warning/Critical | Unprocessed jobs accumulating | 20-40 min |

### Infrastructure Incidents

| Runbook | Severity | Scenario | Est. Resolution Time |
|---------|----------|----------|---------------------|
| [Host Down](./host-down.md) | Critical | Server unavailable | 30-60 min |
| [High CPU](./high-cpu.md) | Warning/Critical | CPU utilization > 80% | 20-40 min |
| [High Memory](./high-memory.md) | Warning/Critical | Memory utilization > 80% | 20-40 min |
| [Disk Space Low](./disk-space.md) | Warning/Critical | Disk > 80% full | 30-60 min |
| [Network Issues](./network-issues.md) | Warning | High latency or packet loss | 40-60 min |

### Database Incidents

| Runbook | Severity | Scenario | Est. Resolution Time |
|---------|----------|----------|---------------------|
| [Database Down](./database-down.md) | Critical | Database unavailable | 20-40 min |
| [High DB Connections](./high-db-connections.md) | Warning/Critical | Connection pool exhausted | 15-30 min |
| [Replication Lag](./replication-lag.md) | Warning | Replication delay > 30s | 20-40 min |
| [Lock Contention](./lock-contention.md) | Warning | Database locks blocking queries | 30-60 min |

### Cache Incidents

| Runbook | Severity | Scenario | Est. Resolution Time |
|---------|----------|----------|---------------------|
| [Redis Down](./redis-down.md) | Critical | Cache unavailable | 15-30 min |
| [Low Hit Rate](./low-hit-rate.md) | Warning | Cache hit ratio < 70% | 20-40 min |
| [High Redis Memory](./high-redis-memory.md) | Warning/Critical | Memory > 80% | 15-30 min |

### Security Incidents

| Runbook | Severity | Scenario | Est. Resolution Time |
|---------|----------|----------|---------------------|
| [DDoS Attack](./ddos.md) | Critical | Massive request volume | 30-60 min |
| [Auth Failures](./auth-failures.md) | Warning | High failed login rate | 15-30 min |
| [Suspicious Activity](./suspicious-activity.md) | Warning | Anomalous behavior detected | 20-40 min |

## Incident Severity Levels

### P1 - Critical (Severe Impact)

- **Definition**: Service completely down or severe degradation
- **Impact**: All users affected
- **Response Time**: Immediate (< 5 min)
- **Resolution Target**: < 1 hour
- **Escalation**: On-call → Engineering Manager → VP Engineering

### P2 - High (Significant Impact)

- **Definition**: Major feature degradation or partial outage
- **Impact**: Many users affected
- **Response Time**: < 15 min
- **Resolution Target**: < 4 hours
- **Escalation**: On-call → Engineering Manager

### P3 - Medium (Moderate Impact)

- **Definition**: Minor feature issues or performance degradation
- **Impact**: Some users affected
- **Response Time**: < 1 hour
- **Resolution Target**: < 24 hours
- **Escalation**: On-call (if needed)

### P4 - Low (Minimal Impact)

- **Definition**: Cosmetic issues or edge cases
- **Impact**: Few users affected
- **Response Time**: < 4 hours
- **Resolution Target**: Next release
- **Escalation**: None (unless user-impacting)

## Quick Reference Commands

### Service Health

```bash
# Check service status
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Check service logs
docker logs -f --tail=100 agl-hostman-app

# Restart a service
docker restart agl-hostman-app

# Scale a service
docker-compose up -d --scale app=3
```

### Database

```bash
# Connect to database
docker exec -it agl-hostman-db psql -U agl_user -d agl_hostman

# Check active connections
docker exec agl-hostman-db psql -U agl_user -d agl_hostman -c "SELECT count(*) FROM pg_stat_activity;"

# Check long-running queries
docker exec agl-hostman-db psql -U agl_user -d agl_hostman -c "SELECT pid, now() - pg_stat_activity.query_start AS duration, query FROM pg_stat_activity WHERE (now() - pg_stat_activity.query_start) > interval '5 minutes';"

# Kill a query
docker exec agl-hostman-db psql -U agl_user -d agl_hostman -c "SELECT pg_cancel_backend(<pid>);"
```

### Cache (Redis)

```bash
# Connect to Redis
docker exec -it agl-hostman-redis redis-cli

# Check memory usage
docker exec agl-hostman-redis redis-cli INFO memory

# Check hit rate
docker exec agl-hostman-redis redis-cli INFO stats | grep keyspace

# Flush cache (use with caution!)
docker exec agl-hostman-redis redis-cli FLUSHALL
```

### Monitoring

```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'

# Query Prometheus
curl 'http://localhost:9090/api/v1/query?query=up' | jq .

# Check Alertmanager alerts
curl http://localhost:9093/api/v2/alerts | jq .

# View Grafana dashboards
open http://localhost:3000
```

### Queue (Horizon)

```bash
# Check Horizon status
docker exec agl-hostman-app php artisan horizon:status

# Restart Horizon
docker exec agl-hostman-app php artisan horizon:terminate

# Clear failed jobs
docker exec agl-hostman-app php artisan horizon:clear

# Retry failed jobs
docker exec agl-hostman-app php artisan horizon:retry --all
```

## Escalation Contacts

### On-Call Rotation

- **Primary On-Call**: [Phone/Slack]
- **Secondary On-Call**: [Phone/Slack]
- **On-Call Manager**: [Phone/Slack]

### Engineering Leadership

- **Engineering Manager**: [Phone/Slack]
- **VP Engineering**: [Phone/Slack]
- **CTO**: [Phone/Slack] ( emergencies only)

### Stakeholder Communication

- **Product Team**: #product-alerts Slack channel
- **Support Team**: #support-alerts Slack channel
- **Status Page**: https://status.agl-hostman.com

## Incident Communication Template

### Initial Announcement (T+0)

```
🚨 INCIDENT DECLARED

Title: [Brief incident description]
Severity: P[1-4]
Impact: [Affected services and users]

Investigation in progress. Next update in 30 minutes.
#incident-<id>
```

### Update Template (T+30min)

```
📊 INCIDENT UPDATE

Incident: [Brief description]
Status: [Investigating|Identified|Monitoring|Resolved]

Current State:
- [What we know]
- [What we're doing]
- [Impact assessment]

Next update in 30 minutes.
#incident-<id>
```

### Resolution Template (T+End)

```
✅ INCIDENT RESOLVED

Incident: [Brief description]
Duration: [X hours Y minutes]
Root Cause: [Summary]

Resolution Actions:
- [Action 1]
- [Action 2]

Postmortem scheduled: [Date/Time]
#incident-<id>
```

## Post-Incident Procedures

### Postmortem Template

1. **Summary**
   - What happened?
   - What was the impact?
   - When did it occur?

2. **Timeline**
   - Key events and timestamps
   - Detection and response times
   - Resolution actions

3. **Root Cause**
   - Primary cause
   - Contributing factors
   - Prevention measures

4. **Lessons Learned**
   - What went well?
   - What could be improved?
   - Action items

5. **Action Items**
   - Owner
   - Due date
   - Status

## Runbook Maintenance

### Review Schedule

- **Monthly**: Review accuracy and relevance
- **Quarterly**: Comprehensive update and testing
- **Post-Incident**: Update with lessons learned

### Contribution Guidelines

1. Follow the existing template
2. Include diagnostic commands
3. Provide resolution steps
4. Add prevention measures
5. Test procedures before publishing

### Version Control

All runbooks are version-controlled in Git. Submit changes via pull request with:

- Clear description of changes
- Testing results
- Reviewer assignment

## Additional Resources

- [Monitoring Dashboard](http://localhost:3000)
- [Alertmanager](http://localhost:9093)
- [Prometheus](http://localhost:9090)
- [Grafana Dashboards](http://localhost:3000/dashboards)
- [Service Documentation](../../docs/)
- [Architecture Diagrams](../../docs/architecture/)

## Training and Simulation

### On-Call Training

New on-call engineers should:

1. Complete runbook review (4 hours)
2. Practice common scenarios (2 hours)
3. Shadow experienced on-call (1 week)
4. Lead incident response (supervised) (2 weeks)

### Simulation Exercises

Quarterly incident simulations:

1. Select a realistic scenario
2. Assign roles (incident commander, communication lead, etc.)
3. Practice response procedures
4. Debrief and document improvements

## Contact

For questions or suggestions about these runbooks:

- **Maintainer**: SRE Team
- **Slack**: #runbooks
- **Email**: sre@agl-hostman.com
