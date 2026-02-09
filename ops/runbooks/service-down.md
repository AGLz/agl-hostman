# Service Down - Runbook

## Overview

**Symptom**: Service is completely unavailable and not responding to requests.

**Severity**: P1 - Critical

**Estimated Resolution Time**: 15-30 minutes

## Initial Diagnosis

### Step 1: Verify Service Status

```bash
# Check if service is running
docker ps | grep agl-hostman

# Check service health
curl -I http://localhost:8080/health
curl -I http://localhost:3000/health
```

**Expected**: Service containers are running and health checks pass.

**If Failed**: Service is down. Proceed to Step 2.

### Step 2: Check Service Logs

```bash
# Laravel API logs
docker logs --tail=500 agl-hostman-app | grep -i error

# Vue frontend logs
docker logs --tail=500 agl-hostman-frontend | grep -i error

# Nginx logs
docker logs agl-hostman-nginx
```

**Look For**:
- Application errors
- Database connection failures
- Out of memory errors
- Configuration errors

### Step 3: Check Dependencies

```bash
# Database connectivity
docker exec agl-hostman-app php artisan db:show

# Redis connectivity
docker exec agl-hostman-app php artisan redis:test

# External services
curl -I https://api.external-service.com/health
```

## Resolution Procedures

### Procedure A: Service Crash

**If**: Service crashed and is not running

```bash
# Restart the service
docker-compose restart app

# If restart fails, rebuild
docker-compose up -d --build app

# Monitor logs during startup
docker logs -f agl-hostman-app
```

**Verify**:
```bash
# Wait 30 seconds, then check health
curl -I http://localhost:8080/health
```

### Procedure B: Database Connection Failure

**If**: Logs show database connection errors

```bash
# Check database status
docker ps | grep agl-hostman-db

# Test database connection
docker exec -it agl-hostman-db psql -U agl_user -d agl_hostman -c "SELECT 1;"

# If database is down, restart it
docker-compose restart db

# Check connection string
docker exec agl-hostman-app cat .env | grep DB_
```

**Common Causes**:
- Database service down
- Incorrect connection credentials
- Network issues between containers
- Database overloaded

### Procedure C: Out of Memory

**If**: Logs show OOM (Out Of Memory) errors

```bash
# Check container memory usage
docker stats agl-hostman-app

# Increase memory limit in docker-compose.yml
# services:
#   app:
#     mem_limit: 2g  # Increase from 1g

# Restart with new limits
docker-compose up -d app
```

**Monitor**:
```bash
# Watch memory usage
docker stats --no-stream
```

### Procedure D: Configuration Error

**If**: Service fails to start due to configuration

```bash
# Check for recent config changes
git log --since="2 hours ago" -- .env docker-compose.yml

# Restore previous configuration if needed
git checkout HEAD~1 .env

# Restart service
docker-compose restart app
```

### Procedure E: Lock File Issues

**If**: Laravel specific issues

```bash
# Clear Laravel cache
docker exec agl-hostman-app php artisan cache:clear
docker exec agl-hostman-app php artisan config:clear
docker exec agl-hostman-app php artisan route:clear

# Remove compiled files
docker exec agl-hostman-app rm -f bootstrap/cache/*.php
docker exec agl-hostman-app php artisan optimize

# Restart Horizon
docker exec agl-hostman-app php artisan horizon:terminate
```

## Fallback Procedures

### If All Else Fails

```bash
# Force restart entire stack
docker-compose down
docker-compose up -d

# If issue persists, rebuild from scratch
docker-compose down -v
docker-compose build --no-cache
docker-compose up -d

# Run database migrations
docker exec agl-hostman-app php artisan migrate --force

# Clear and cache config
docker exec agl-hostman-app php artisan config:cache
docker exec agl-hostman-app php artisan route:cache
```

## Verification

### Health Checks

```bash
# Application health
curl http://localhost:8080/api/health
curl http://localhost:8080/api/status

# Frontend health
curl http://localhost:3000

# Database health
docker exec agl-hostman-db pg_isready

# Cache health
docker exec agl-hostman-redis redis-cli PING
```

### Monitoring Dashboard

1. Open Grafana: http://localhost:3000
2. Navigate to "Service Health" dashboard
3. Verify all services show "UP"
4. Check request rates have recovered
5. Verify error rates are normal

## Communication

### Initial Communication

```bash
# Send to Slack
cat << 'EOF' | curl -X POST -H 'Content-type: application/json' \
  --data-binary @- ${SLACK_WEBHOOK_URL}
{
  "text": "🚨 Service Down Incident",
  "blocks": [
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "*Service Down*\n\nService is currently unavailable.\nInvestigation in progress."
      }
    }
  ]
}
EOF
```

### Resolution Communication

Once resolved, update with:

- Root cause summary
- Resolution steps taken
- Estimated time to full recovery
- Any ongoing issues

## Prevention

### Monitoring Improvements

1. **Add Health Check Endpoints**
   - `/health` - Basic health check
   - `/ready` - Readiness probe
   - `/metrics` - Prometheus metrics

2. **Alert Tuning**
   - Reduce alert duration to 30s for critical services
   - Add multiple notification channels

3. **Dashboard Updates**
   - Add service status indicator
   - Show recent restart events

### Process Improvements

1. **Deployment Safety**
   - Use blue-green deployment
   - Implement canary releases
   - Add automated rollback

2. **Resource Planning**
   - Monitor memory trends
   - Set up auto-scaling
   - Plan capacity ahead

3. **Documentation**
   - Document all service dependencies
   - Create startup dependency graph
   - Maintain runbook accuracy

## Related Runbooks

- [High Error Rate](./high-error-rate.md)
- [Database Down](./database-down.md)
- [High Memory](./high-memory.md)
- [Redis Down](./redis-down.md)

## Escalation

**If unresolved after 15 minutes**:

1. Contact Engineering Manager
2. Consider traffic failover
3. Prepare status page update
4. Notify customer support

## Metrics to Track

Post-incident, monitor:

- Time to detection
- Time to resolution
- Root cause category
- Prevention measures deployed

## Post-Incident Actions

1. Schedule postmortem within 48 hours
2. Update runbook with lessons learned
3. Implement prevention measures
4. Train team on new procedures
