# Production Operations Runbook

**Version**: 1.0.0
**Last Updated**: 2025-01-20
**Phase**: 3.3 - Production Operations

---

## Table of Contents

1. [Emergency Contacts](#emergency-contacts)
2. [Incident Response](#incident-response)
3. [Common Procedures](#common-procedures)
4. [Troubleshooting Guide](#troubleshooting-guide)
5. [Escalation Procedures](#escalation-procedures)
6. [Maintenance Windows](#maintenance-windows)
7. [Performance Tuning](#performance-tuning)
8. [Security Procedures](#security-procedures)

---

## Emergency Contacts

### On-Call Rotation

| Role | Primary | Backup | Escalation |
|------|---------|--------|------------|
| **On-Call Engineer** | [Name] | [Name] | DevOps Lead |
| **DevOps Lead** | [Name] | [Name] | CTO |
| **Database Admin** | [Name] | [Name] | DevOps Lead |
| **Security Lead** | [Name] | [Name] | CISO |
| **Product Owner** | [Name] | [Name] | VP Engineering |

### Communication Channels

- **PagerDuty**: https://agl.pagerduty.com
- **Slack Emergency**: #production-incidents (@ everyone)
- **Slack Operations**: #production-support
- **Email**: ops@agl.com
- **Phone**: [On-call phone number]

### Severity Definitions

| Severity | Description | Response Time | Examples |
|----------|-------------|---------------|----------|
| **P0** | Complete outage | 15 minutes | Site down, database unavailable |
| **P1** | Severe degradation | 30 minutes | Severe performance issues, partial outage |
| **P2** | Moderate impact | 2 hours | Minor performance degradation, non-critical feature broken |
| **P3** | Low impact | 1 business day | Cosmetic issues, monitoring alerts |

---

## Incident Response

### P0: Complete Outage

**Immediate Actions** (Within 5 Minutes):

```bash
# 1. Verify outage
curl -f https://prod-agl.aglz.io/health
# Expected: Connection refused OR 503

# 2. Check infrastructure
docker compose -f docker/production/docker-compose.blue.yml ps
docker compose -f docker/production/docker-compose.lb.yml ps

# 3. Page on-call engineer
# Automatic via monitoring alerts

# 4. Create incident channel
# Slack: /incident create "Production site down"

# 5. Update status page
# https://status.agl.com
# Set status: "Major Outage - Investigating"
```

**Investigation** (Within 15 Minutes):

```bash
# Check load balancer
docker logs agl-hostman-load-balancer --tail 100

# Check application logs
docker compose -f docker-compose.blue.yml logs --tail 100 app-blue-1
docker compose -f docker-compose.blue.yml logs --tail 100 app-blue-2

# Check database
docker exec agl-hostman-postgres-primary pg_isready

# Check Redis
docker exec agl-hostman-redis-master redis-cli -a [password] PING

# Check disk space
df -h
```

**Common Causes**:

1. **Load Balancer Down**:
```bash
# Restart load balancer
docker compose -f docker-compose.lb.yml restart load-balancer

# Verify
curl -f http://localhost:80/health
```

2. **All Application Replicas Down**:
```bash
# Restart application
docker compose -f docker-compose.blue.yml restart app-blue-1 app-blue-2

# Check logs for crash reason
docker compose -f docker-compose.blue.yml logs app-blue-1
```

3. **Database Connection Exhaustion**:
```bash
# Check connection count
docker exec agl-hostman-postgres-primary psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;"

# Kill idle connections
docker exec agl-hostman-postgres-primary psql -U postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE state = 'idle' AND state_change < now() - interval '5 minutes';"

# Restart application
docker compose -f docker-compose.blue.yml restart app-blue-1 app-blue-2
```

4. **Disk Space Full**:
```bash
# Check disk usage
df -h

# Clear logs if needed
docker system prune -af
journalctl --vacuum-time=1d

# Clean old backups
find /var/lib/docker/volumes/backups/_data -name "*.sql.gz" -mtime +7 -delete
```

**Resolution**:

```bash
# 1. Verify site is up
curl -f https://prod-agl.aglz.io/health

# 2. Run smoke tests
docker exec agl-hostman-app-blue-1 php artisan test --testsuite=Production

# 3. Update status page
# Set status: "Resolved"

# 4. Send all-clear notification
# Slack: #production-incidents
# "Incident resolved. All systems operational."

# 5. Schedule post-mortem within 24 hours
```

### P1: Severe Degradation

**Symptoms**:
- Error rate > 5%
- P95 response time > 2000ms
- Database query latency > 1000ms
- One replica down (50% capacity)

**Investigation**:

```bash
# Check metrics
curl http://localhost:9090/api/v1/query?query=rate(http_requests_total{status=~"5.."}[5m])

# Check slow queries
docker exec agl-hostman-postgres-primary psql -U postgres -c "SELECT query, mean_exec_time FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 10;"

# Check Redis memory
docker exec agl-hostman-redis-master redis-cli -a [password] INFO memory
```

**Common Fixes**:

1. **High Database Load**:
```bash
# Enable query caching
php artisan config:cache

# Scale read replicas (if needed)
# Add more postgres-replica instances

# Optimize slow queries
# Check EXPLAIN ANALYZE output
```

2. **Memory Leak**:
```bash
# Restart affected replica
docker compose -f docker-compose.blue.yml restart app-blue-1

# Monitor memory usage
docker stats agl-hostman-app-blue-1

# If recurring, schedule investigation for memory leak
```

3. **External Service Timeout**:
```bash
# Check circuit breaker status
curl http://localhost:3000/api/circuit-breaker/status

# Temporarily disable affected integration
# Update .env to disable feature flag

# Reload configuration
docker exec agl-hostman-app-blue-1 php artisan config:cache
```

### P2: Moderate Impact

**Symptoms**:
- Error rate 1-5%
- P95 response time 500-2000ms
- Non-critical feature unavailable
- Monitoring alerts

**Response**:
- Create ticket in project management system
- Investigate during business hours
- No immediate action required unless escalates

### P3: Low Impact

**Symptoms**:
- Cosmetic issues
- Documentation errors
- Minor monitoring noise

**Response**:
- Add to backlog
- Address in next sprint
- No incident required

---

## Common Procedures

### Restart Application

```bash
# Graceful restart (zero downtime)
# 1. Restart replica 2
docker compose -f docker-compose.blue.yml restart app-blue-2

# 2. Wait for health check
sleep 15
curl http://app-blue-2:3000/health

# 3. Restart replica 1
docker compose -f docker-compose.blue.yml restart app-blue-1

# 4. Wait for health check
sleep 15
curl http://app-blue-1:3000/health

# Total downtime: 0 seconds
```

### Restart Database

**⚠️ CRITICAL: Database restart causes brief downtime (~30 seconds)**

```bash
# 1. Put site in maintenance mode
docker exec agl-hostman-app-blue-1 php artisan down

# 2. Restart PostgreSQL primary
docker compose -f docker-compose.blue.yml restart postgres-primary

# 3. Wait for startup
sleep 10
docker exec agl-hostman-postgres-primary pg_isready

# 4. Verify replication
docker exec agl-hostman-postgres-primary psql -U postgres -c "SELECT * FROM pg_stat_replication;"

# 5. Restart application
docker compose -f docker-compose.blue.yml restart app-blue-1 app-blue-2

# 6. Exit maintenance mode
docker exec agl-hostman-app-blue-1 php artisan up

# Total downtime: ~30 seconds
```

### Restart Redis

```bash
# Restart Redis master
docker compose -f docker-compose.blue.yml restart redis-master

# Verify Sentinel promoted master
docker exec agl-hostman-redis-sentinel redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster

# Restart Sentinel
docker compose -f docker-compose.blue.yml restart redis-sentinel
```

### Clear Cache

```bash
# Clear application cache
docker exec agl-hostman-app-blue-1 php artisan cache:clear
docker exec agl-hostman-app-blue-1 php artisan config:clear
docker exec agl-hostman-app-blue-1 php artisan route:clear
docker exec agl-hostman-app-blue-1 php artisan view:clear

# Clear Redis cache
docker exec agl-hostman-redis-master redis-cli -a [password] FLUSHDB

# Clear OPcache
docker compose -f docker-compose.blue.yml restart app-blue-1 app-blue-2
```

### Run Database Migrations

```bash
# ⚠️ Only run during maintenance window or with backward-compatible migrations

# 1. Backup database first
php artisan production:backup --type=full --verify --upload

# 2. Run migrations
docker exec agl-hostman-app-blue-1 php artisan migrate --force

# 3. Verify
docker exec agl-hostman-app-blue-1 php artisan migrate:status

# 4. Test application
docker exec agl-hostman-app-blue-1 php artisan test --testsuite=Production
```

### Scale Application

```bash
# Scale up (add replica 3)
docker compose -f docker-compose.blue.yml up -d --scale app-blue=3

# Wait for health check
sleep 15
curl http://app-blue-3:3000/health

# Update load balancer (automatic via service discovery OR manual nginx config)

# Scale down (remove replica 3)
docker compose -f docker-compose.blue.yml up -d --scale app-blue=2
```

### Rotate Secrets

```bash
# 1. Generate new secrets
php artisan production:rotate-secrets

# 2. Update .env.production
nano .env.production

# 3. Restart application (graceful)
docker compose -f docker-compose.blue.yml restart app-blue-2
sleep 15
docker compose -f docker-compose.blue.yml restart app-blue-1

# 4. Verify connectivity
curl -f https://prod-agl.aglz.io/health
```

---

## Troubleshooting Guide

### High CPU Usage

**Diagnosis**:
```bash
# Check CPU usage
docker stats --no-stream

# Check top processes
docker exec agl-hostman-app-blue-1 top -b -n 1

# Check for infinite loops
docker exec agl-hostman-app-blue-1 php artisan horizon:list
```

**Resolution**:
```bash
# 1. Identify expensive operations
# Check slow query log, profiler data

# 2. Optimize code or queries

# 3. Scale horizontally (add replicas)
docker compose -f docker-compose.blue.yml up -d --scale app-blue=3

# 4. Upgrade resources (if needed)
# Edit docker-compose.blue.yml:
# resources.limits.cpus: '8'
```

### High Memory Usage

**Diagnosis**:
```bash
# Check memory usage
docker stats --no-stream | grep app-blue

# Check for memory leaks
docker exec agl-hostman-app-blue-1 php -r "echo memory_get_usage(true)/1024/1024 . ' MB';"

# Check OPcache
docker exec agl-hostman-app-blue-1 php -r "var_dump(opcache_get_status());"
```

**Resolution**:
```bash
# 1. Restart affected replica
docker compose -f docker-compose.blue.yml restart app-blue-1

# 2. Monitor for recurrence
docker stats agl-hostman-app-blue-1

# 3. If recurring:
# - Review code for memory leaks
# - Increase memory limit
# - Add more replicas
```

### Slow Database Queries

**Diagnosis**:
```bash
# Enable slow query log
docker exec agl-hostman-postgres-primary psql -U postgres -c "ALTER SYSTEM SET log_min_duration_statement = 1000;"
docker exec agl-hostman-postgres-primary psql -U postgres -c "SELECT pg_reload_conf();"

# View slow queries
docker exec agl-hostman-postgres-primary psql -U postgres -c "SELECT query, mean_exec_time, calls FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 10;"

# Check for missing indexes
docker exec agl-hostman-postgres-primary psql -U postgres -d agl_hostman_prod -c "SELECT schemaname, tablename, attname, n_distinct, correlation FROM pg_stats WHERE schemaname = 'public' ORDER BY n_distinct DESC;"
```

**Resolution**:
```bash
# 1. Add missing indexes
# Example:
docker exec agl-hostman-postgres-primary psql -U postgres -d agl_hostman_prod -c "CREATE INDEX CONCURRENTLY idx_users_email ON users(email);"

# 2. Optimize query
# Rewrite with EXPLAIN ANALYZE

# 3. Scale read replicas
# Add more postgres-replica instances

# 4. Enable query caching
php artisan config:cache
```

### Redis Connection Issues

**Diagnosis**:
```bash
# Check Redis is running
docker exec agl-hostman-redis-master redis-cli -a [password] PING

# Check connection count
docker exec agl-hostman-redis-master redis-cli -a [password] INFO clients

# Check for blocked clients
docker exec agl-hostman-redis-master redis-cli -a [password] CLIENT LIST
```

**Resolution**:
```bash
# 1. Increase maxclients
docker exec agl-hostman-redis-master redis-cli -a [password] CONFIG SET maxclients 10000

# 2. Restart Redis if needed
docker compose -f docker-compose.blue.yml restart redis-master

# 3. Verify Sentinel
docker exec agl-hostman-redis-sentinel redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster
```

### Load Balancer 502 Errors

**Diagnosis**:
```bash
# Check nginx error log
docker logs agl-hostman-load-balancer --tail 100

# Check upstream health
curl http://app-blue-1:3000/health
curl http://app-blue-2:3000/health

# Check nginx config
docker exec agl-hostman-load-balancer nginx -t
```

**Resolution**:
```bash
# 1. Fix unhealthy upstreams
docker compose -f docker-compose.blue.yml restart app-blue-1 app-blue-2

# 2. Reload nginx
docker exec agl-hostman-load-balancer nginx -s reload

# 3. If config broken, restore from backup
docker cp nginx.conf.backup agl-hostman-load-balancer:/etc/nginx/nginx.conf
docker exec agl-hostman-load-balancer nginx -s reload
```

---

## Escalation Procedures

### When to Escalate

**Immediate Escalation** (P0):
- Complete site outage > 15 minutes
- Data loss detected
- Security breach suspected
- Unable to resolve within SLA

**Standard Escalation** (P1):
- Severe degradation > 1 hour
- Multiple failed resolution attempts
- Requires specialized expertise

**Optional Escalation** (P2/P3):
- Complex technical issues
- Architecture decisions needed
- Resource allocation required

### Escalation Path

```
Tier 1: On-Call Engineer
   ↓ (15 min for P0, 30 min for P1)
Tier 2: DevOps Lead
   ↓ (30 min for P0, 1 hour for P1)
Tier 3: CTO + VP Engineering
   ↓ (1 hour for P0)
Tier 4: CEO (business impact)
```

### Escalation Checklist

Before escalating, gather:
- [ ] Incident description and timeline
- [ ] Steps already taken
- [ ] Current impact (users affected, revenue lost)
- [ ] Logs and screenshots
- [ ] Current hypothesis of root cause
- [ ] Estimated time to resolve

---

## Maintenance Windows

### Scheduled Maintenance

**Preferred Windows**:
- **Weekly**: Sunday 02:00-04:00 UTC (low traffic)
- **Monthly**: First Sunday of month, 02:00-06:00 UTC (extended window)

**Notification Timeline**:
- 7 days: Email to all customers
- 3 days: Status page banner
- 1 day: Slack reminder
- 1 hour: Status page update ("Maintenance in progress")

### Maintenance Procedure

```bash
# 1. Send notifications
# Update status page: "Scheduled Maintenance"

# 2. Create backup
php artisan production:backup --type=full --verify --upload

# 3. Put site in maintenance mode (if needed)
docker exec agl-hostman-app-blue-1 php artisan down --message="Scheduled maintenance in progress. Back online at 04:00 UTC."

# 4. Perform maintenance tasks
# - Database migrations
# - Schema changes
# - Infrastructure upgrades
# - Security patches

# 5. Run tests
docker exec agl-hostman-app-blue-1 php artisan test --testsuite=Production

# 6. Exit maintenance mode
docker exec agl-hostman-app-blue-1 php artisan up

# 7. Verify site is operational
curl -f https://prod-agl.aglz.io/health

# 8. Update status page: "Operational"

# 9. Send completion notification
```

### Emergency Maintenance

**When Required**:
- Security vulnerabilities (CVE patches)
- Critical bug fixes
- Infrastructure failures

**Approval**:
- P0: No approval needed (immediate)
- P1: DevOps Lead approval
- P2: Can wait for scheduled window

**Procedure**:
```bash
# 1. Create incident
# Slack: #production-incidents

# 2. Brief notification
# Status page: "Emergency maintenance in progress"
# Email: "We're performing emergency maintenance. ETA: [time]"

# 3. Perform fix (follow same steps as scheduled)

# 4. Send all-clear
```

---

## Performance Tuning

### Application Performance

**OPcache Tuning**:
```ini
; php.ini
opcache.enable=1
opcache.memory_consumption=256
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=20000
opcache.validate_timestamps=0
opcache.revalidate_freq=0
opcache.fast_shutdown=1
```

**Laravel Optimization**:
```bash
# Production optimizations
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan event:cache

# Queue workers
php artisan horizon:publish
php artisan horizon:install

# Optimize Composer autoloader
composer install --optimize-autoloader --no-dev
```

### Database Performance

**Connection Pooling**:
```env
DB_POOL_MIN=10
DB_POOL_MAX=100
DB_POOL_IDLE_TIMEOUT=60
```

**Query Optimization**:
```sql
-- Add indexes
CREATE INDEX CONCURRENTLY idx_users_email ON users(email);
CREATE INDEX CONCURRENTLY idx_logs_created_at ON logs(created_at);

-- Analyze tables
ANALYZE users;
ANALYZE logs;

-- Vacuum (during maintenance window)
VACUUM ANALYZE;
```

### Redis Performance

**Configuration**:
```conf
maxmemory 4gb
maxmemory-policy allkeys-lru
save ""
appendonly yes
appendfsync everysec
```

**Monitoring**:
```bash
# Hit rate
docker exec agl-hostman-redis-master redis-cli -a [password] INFO stats | grep keyspace_hits
docker exec agl-hostman-redis-master redis-cli -a [password] INFO stats | grep keyspace_misses

# Memory usage
docker exec agl-hostman-redis-master redis-cli -a [password] INFO memory | grep used_memory_human
```

---

## Security Procedures

### Security Incident Response

**Step 1: Contain**
```bash
# If attack in progress:
# 1. Block attacking IP
docker exec agl-hostman-load-balancer iptables -A INPUT -s [ATTACKER-IP] -j DROP

# 2. Enable WAF (if not already)
# Edit nginx.conf, add ModSecurity rules

# 3. Put site in maintenance mode (if severe)
docker exec agl-hostman-app-blue-1 php artisan down
```

**Step 2: Investigate**
```bash
# Review access logs
docker exec agl-hostman-load-balancer tail -n 1000 /var/log/nginx/access.log

# Review error logs
docker exec agl-hostman-app-blue-1 tail -n 1000 storage/logs/laravel.log

# Check for suspicious database activity
docker exec agl-hostman-postgres-primary psql -U postgres -c "SELECT * FROM pg_stat_activity WHERE query LIKE '%DROP%' OR query LIKE '%DELETE%';"
```

**Step 3: Remediate**
```bash
# Rotate all secrets
php artisan production:rotate-secrets

# Patch vulnerability
# Deploy hotfix following deployment process

# Update firewall rules
# Add permanent IP blocks to UFW
```

**Step 4: Report**
```bash
# Notify security team
# Email: security@agl.com

# File incident report
# Include: timeline, impact, root cause, remediation, prevention

# Update security documentation
```

### Vulnerability Scanning

```bash
# Weekly automated scans
trivy image harbor.aglz.io:5000/agl-hostman-prod:latest

# Review and patch HIGH/CRITICAL vulnerabilities within 7 days
```

### Access Review

```bash
# Quarterly review of:
# - SSH keys
# - Database users
# - API tokens
# - Admin accounts

# Revoke unused access immediately
```

---

## Monitoring and Alerting

### Key Metrics

**Application**:
- Request rate (req/s)
- Error rate (%)
- P50, P95, P99 response times (ms)
- Active connections

**Database**:
- Connection count
- Query duration (P50, P95, P99)
- Slow query count
- Replication lag

**Redis**:
- Hit/miss ratio
- Memory usage (%)
- Evicted keys
- Connection count

**System**:
- CPU usage (%)
- Memory usage (%)
- Disk usage (%)
- Network I/O

### Alert Thresholds

See [PRODUCTION-ENVIRONMENT-SETUP.md](PRODUCTION-ENVIRONMENT-SETUP.md) for complete alert configuration.

**Critical Alerts** (immediate response):
- Error rate > 5%
- Database unavailable
- Redis unavailable
- Disk space < 10%

**Warning Alerts** (investigate within 1 hour):
- Error rate > 1%
- P95 response time > 500ms
- Database pool > 80%
- Memory usage > 85%

### Metrics Retention

- **Real-time**: 1 hour (1-second resolution)
- **Short-term**: 7 days (1-minute resolution)
- **Medium-term**: 30 days (5-minute resolution)
- **Long-term**: 1 year (1-hour resolution)

---

## Post-Incident Review

### Post-Mortem Template

```markdown
# Incident Post-Mortem: [Incident Title]

**Date**: [Incident Date]
**Duration**: [Start Time] - [End Time] ([Total Duration])
**Severity**: P0/P1/P2/P3
**Impact**: [Users affected, downtime, revenue impact]

## Timeline

- [HH:MM] - Incident started (first alert)
- [HH:MM] - On-call paged
- [HH:MM] - Diagnosis began
- [HH:MM] - Root cause identified
- [HH:MM] - Fix applied
- [HH:MM] - Incident resolved
- [HH:MM] - All-clear sent

## Root Cause

[Technical description of what caused the incident]

## Resolution

[What was done to resolve the incident]

## Impact

- **Users Affected**: [Number/percentage]
- **Downtime**: [Duration]
- **Revenue Impact**: [Estimated loss]
- **SLA Violation**: Yes/No

## What Went Well

- [Positive observations]

## What Went Poorly

- [Areas for improvement]

## Action Items

1. [ ] [Action item] - Assigned to: [Name] - Due: [Date]
2. [ ] [Action item] - Assigned to: [Name] - Due: [Date]

## Lessons Learned

[Key takeaways for future incidents]
```

### Follow-Up Actions

- Schedule review meeting within 24 hours
- Document all action items
- Track completion in project management system
- Update runbook with new procedures
- Share learnings with team

---

## References

- [PRODUCTION-ENVIRONMENT-SETUP.md](PRODUCTION-ENVIRONMENT-SETUP.md) - Setup guide
- [BLUE-GREEN-DEPLOYMENT.md](BLUE-GREEN-DEPLOYMENT.md) - Deployment procedures
- [DISASTER-RECOVERY.md](DISASTER-RECOVERY.md) - DR procedures

---

**Document Version**: 1.0.0
**Last Review**: 2025-01-20
**Next Review**: 2025-02-20
**On-Call Rotation**: [PagerDuty link]
