# High Error Rate - Runbook

## Overview

**Symptom**: Service is responding but with elevated error rates (4xx, 5xx).

**Severity**: P2 - Warning / P1 - Critical (if > 15%)

**Estimated Resolution Time**: 10-20 minutes

## Initial Diagnosis

### Step 1: Confirm Error Rate

```bash
# Query error rate from Prometheus
curl 'http://localhost:9090/api/v1/query?query=job:http_error_percentage:rate5m' | jq .

# Or check in Grafana
open http://localhost:3000/d/service-health
```

**Thresholds**:
- Warning: > 5% error rate
- Critical: > 15% error rate

### Step 2: Identify Error Types

```bash
# Check error breakdown
curl 'http://localhost:9090/api/v1/query?query=sum(rate(http_requests_total[5m]))+by+(status)' | jq .

# Check recent errors in logs
docker logs --since=5m agl-hostman-app | grep -E "ERROR|CRITICAL|FATAL"

# Check Laravel logs
docker exec agl-hostman-app tail -f storage/logs/laravel.log | grep -i error
```

**Error Categories**:
- **4xx Errors**: Client errors (bad requests, authentication)
- **5xx Errors**: Server errors (application failures)

### Step 3: Check External Dependencies

```bash
# Database errors
docker logs --since=5m agl-hostman-app | grep -i "database\|sql\|connection"

# Redis errors
docker logs --since=5m agl-hostman-app | grep -i "redis\|cache"

# External API errors
docker logs --since=5m agl-hostman-app | grep -i "curl\|http\|api"
```

## Resolution Procedures

### Procedure A: Database Errors (5xx)

**If**: Logs show database connection/query errors

```bash
# Check database health
docker exec agl-hostman-db pg_isready
docker exec agl-hostman-db psql -U agl_user -d agl_hostman -c "SELECT 1;"

# Check connection pool
docker exec agl-hostman-db psql -U agl_user -d agl_hostman -c "
  SELECT count(*), state
  FROM pg_stat_activity
  WHERE datname = 'agl_hostman'
  GROUP BY state;
"

# Check for long-running queries
docker exec agl-hostman-db psql -U agl_user -d agl_hostman -c "
  SELECT pid, now() - pg_stat_activity.query_start AS duration, query
  FROM pg_stat_activity
  WHERE (now() - pg_stat_activity.query_start) > interval '5 minutes';
"

# If needed, restart database
docker-compose restart db
```

### Procedure B: Cache Errors (5xx)

**If**: Logs show Redis/cache errors

```bash
# Check Redis health
docker exec agl-hostman-redis redis-cli PING

# Check Redis memory
docker exec agl-hostman-redis redis-cli INFO memory | grep used_memory_human

# Check connection count
docker exec agl-hostman-redis redis-cli CLIENT LIST | wc -l

# If Redis is down, restart it
docker-compose restart redis

# Clear cache if needed
docker exec agl-hostman-app php artisan cache:clear
```

### Procedure C: Application Errors (5xx)

**If**: Logs show application exceptions

```bash
# Check for specific error patterns
docker logs --since=10m agl-hostman-app | grep -i "exception\|fatal" | tail -20

# Check for out of memory
docker stats agl-hostman-app --no-stream

# Restart application service
docker-compose restart app

# Monitor logs during restart
docker logs -f --tail=100 agl-hostman-app
```

**Common Application Errors**:
- PHP Fatal errors
- Out of memory
- Timeout errors
- Uncaught exceptions

### Procedure D: Client Errors (4xx)

**If**: High 4xx error rate (bad requests)

```bash
# Check authentication failures
docker logs --since=10m agl-hostman-app | grep -i "401\|403\|unauthorized\|forbidden"

# Check validation errors
docker logs --since=10m agl-hostman-app | grep -i "validation\|400"

# Analyze top error endpoints
curl 'http://localhost:9090/api/v1/query?query=topk(10,+sum(rate(http_requests_total{status=~"4.."}[5m]))+by+(path))' | jq .
```

**Common 4xx Causes**:
- Authentication/authorization failures
- Invalid input data
- Deprecated API endpoints
- Rate limiting

**Actions**:
- Check for authentication service issues
- Review recent API changes
- Check rate limiter configuration
- Analyze request patterns for abuse

### Procedure E: External API Failures (5xx)

**If**: Errors from external service calls

```bash
# Check external API connectivity
curl -I https://api.external-service.com/health

# Check API key/configuration
docker exec agl-hostman-app cat .env | grep API_KEY

# Test external API from container
docker exec agl-hostman-app curl -I https://api.external-service.com
```

**Actions**:
- Verify external API status
- Check API credentials
- Implement circuit breaker pattern
- Add fallback responses

## Immediate Mitigation

### If Error Rate Continues

```bash
# Enable maintenance mode
docker exec agl-hostman-app php artisan down --message="Under maintenance, back soon"

# Or enable read-only mode
docker exec agl-hostman-app php artisan maintenance:enable-read-only

# Scale up if resource issue
docker-compose up -d --scale app=3
```

### Rollback Recent Deployments

```bash
# Check recent deployments
git log --oneline -10

# Rollback to previous version
git checkout HEAD~1

# Rebuild and restart
docker-compose up -d --build app

# Verify recovery
curl -I http://localhost:8080/health
```

## Verification

### Confirm Error Rate Decreased

```bash
# Monitor error rate
watch -n 5 'curl -s http://localhost:9090/api/v1/query?query=job:http_error_percentage:rate5m | jq .'

# Check logs for new errors
docker logs -f --tail=50 agl-hostman-app | grep -i error
```

### Verify Service Functionality

```bash
# Test critical endpoints
curl http://localhost:8080/api/health
curl http://localhost:8080/api/v1/users
curl -X POST http://localhost:8080/api/v1/login -d '{"email":"test@example.com","password":"test"}'

# Check dashboard
open http://localhost:3000/d/service-errors
```

## Communication

### Update Stakeholders

If error rate impacts users:

```
📊 High Error Rate Incident

Status: Investigating
Impact: Degraded service performance
Current Error Rate: X%
Normal Error Rate: <0.1%

Working on resolution. Next update in 15 minutes.
```

## Root Cause Analysis

### Data Collection

```bash
# Export metrics for analysis
curl 'http://localhost:9090/api/v1/query_range?query=job:http_error_percentage:rate5m&start=$(date -d '1 hour ago' +%s)&end=$(date +%s)&step=60' > error-rate-analysis.json

# Save relevant logs
docker logs --since=1h agl-hostman-app > error-rate-logs-$(date +%Y%m%d-%H%M%S).log
```

### Common Root Causes

1. **Database Issues** (40% of cases)
   - Slow queries
   - Connection exhaustion
   - Lock contention

2. **Cache Issues** (25% of cases)
   - Redis failure
   - Cache stampede
   - Eviction storms

3. **Application Bugs** (20% of cases)
   - Recent deployment
   - Edge case handling
   - Memory leaks

4. **External Dependencies** (10% of cases)
   - API failures
   - Network issues
   - Rate limiting

5. **Traffic Spikes** (5% of cases)
   - DDoS attacks
   - Viral content
   - legitimate load

## Prevention

### Monitoring Enhancements

```yaml
# Add to Prometheus alerts
- alert: HighErrorRate
  expr: job:http_error_percentage:rate5m > 5
  for: 2m
  labels:
    severity: warning
  annotations:
    summary: "High error rate detected"
```

### Code Improvements

1. **Error Handling**
   - Implement circuit breakers
   - Add retry logic with exponential backoff
   - Graceful degradation

2. **Monitoring**
   - Add error tracking (Sentry)
   - Implement distributed tracing (Jaeger)
   - Real user monitoring (RUM)

3. **Testing**
   - Load testing for error scenarios
   - Chaos engineering
   - Failure injection testing

### Infrastructure

1. **Database**
   - Query optimization
   - Connection pooling
   - Read replicas

2. **Cache**
   - Redis cluster
   - Cache warming
   - Multi-level caching

3. **Application**
   - Auto-scaling
   - Health checks
   - Graceful shutdown

## Related Runbooks

- [Service Down](./service-down.md)
- [Database Slow Queries](./slow-queries.md)
- [Redis Down](./redis-down.md)
- [DDoS Attack](./ddos.md)

## Post-Incident Actions

1. **Immediate**
   - Verify error rate normalized
   - Monitor for 1 hour
   - Document timeline

2. **Short-term** (24-48 hours)
   - Conduct postmortem
   - Implement quick fixes
   - Update monitoring

3. **Long-term** (1-2 weeks)
   - Implement prevention measures
   - Update runbooks
   - Team training

## Metrics to Track

- Error rate by service
- Error rate by endpoint
- Error rate by status code
- Time to detection
- Time to resolution
- Root cause distribution
