# AGL-23 Performance Monitoring - Quick Reference

## Overview

This document provides quick reference information for AGL-23 performance monitoring dashboards, alerting, and reporting.

## Grafana Dashboards

### API Performance Dashboard
- **UID:** `agl-23-api-performance`
- **URL:** `http://grafana.example.com/d/agl-23-api-performance`
- **Refresh Rate:** 30 seconds

**Key Metrics:**
- Request Rate (req/s)
- P95 Response Time (target: <500ms)
- P99 Response Time (target: <1000ms)
- Error Rate (target: <1%)
- Success Rate (target: >99%)

**Panels:**
- Key Performance Indicators (6 stats)
- Latency Analysis (P50, P95, P99)
- Request Analysis (by service, status, method)
- Top Endboards (by request rate, by latency)

### Database Performance Dashboard
- **UID:** `agl-23-database-performance`
- **URL:** `http://grafana.example.com/d/agl-23-database-performance`
- **Refresh Rate:** 30 seconds

**Key Metrics:**
- Active Connections
- P95 Query Latency (target: <1000ms)
- Query Throughput (qps)
- Deadlock Rate
- Conflict Rate

**Panels:**
- Database Health Overview (6 stats)
- Query Performance (latency percentiles, by type)
- Connection Pool & Resources
- Table Performance (top tables)

### Cache Performance Dashboard
- **UID:** `agl-23-cache-performance`
- **URL:** `http://grafana.example.com/d/agl-23-cache-performance`
- **Refresh Rate:** 30 seconds

**Key Metrics:**
- Cache Hit Rate (target: >70%)
- Commands/sec
- Memory Usage (target: <80%)
- Eviction Rate
- Expiration Rate

**Panels:**
- Cache Health Overview (6 gauges)
- Cache Performance (hits vs misses, hit ratio)
- Key Operations (expiration, eviction)
- Connection & Network

## Alerting Rules

### Severity Levels

| Severity | Description | Response Time |
|----------|-------------|---------------|
| **critical** | Immediate action required | <15 minutes |
| **warning** | Investigation needed | <1 hour |
| **info** | Informational | N/A |

### Key Alerts

#### API Performance Alerts
| Alert | Condition | Severity | Response |
|-------|-----------|----------|----------|
| `HighAPIP95Latency` | P95 > 500ms for 5m | warning | Review slow endpoints |
| `CriticalAPIP99Latency` | P99 > 1s for 2m | critical | Immediate investigation |
| `HighAPIErrorRate` | Error rate > 1% for 3m | critical | Check logs, errors |
| `VeryHighAPIErrorRate` | Error rate > 5% for 1m | critical | Service may be down |

#### Database Performance Alerts
| Alert | Condition | Severity | Response |
|-------|-----------|----------|----------|
| `SlowDatabaseQueryP95` | P95 > 1s for 5m | warning | Review slow query log |
| `CriticalSlowDatabaseQueryP99` | P99 > 5s for 2m | critical | Immediate optimization |
| `HighDatabaseConnections` | Connections > 80% for 5m | warning | Review connection limits |
| `HighDeadlockRate` | >0.1 deadlocks/s for 5m | warning | Review isolation levels |

#### Cache Performance Alerts
| Alert | Condition | Severity | Response |
|-------|-----------|----------|----------|
| `LowCacheHitRate` | Hit rate < 70% for 10m | warning | Review cache strategy |
| `CriticalLowCacheHitRate` | Hit rate < 50% for 5m | critical | Investigate immediately |
| `HighCacheEvictionRate` | >100 evictions/s for 5m | warning | Memory pressure |
| `RedisMemoryCritical` | Memory > 95% for 2m | critical | Eviction imminent |

## Performance Reports

### Daily Reports

Generate daily performance report (markdown):
```bash
./scripts/monitoring/performance-report-generator.sh daily markdown
```

Generate daily performance report (JSON):
```bash
./scripts/monitoring/performance-report-generator.sh daily json
```

### Weekly Reports

Generate weekly performance report:
```bash
./scripts/monitoring/performance-report-generator.sh weekly markdown
```

### Report Contents

Each report includes:
- **Executive Summary** with health score
- **API Performance Metrics**
- **Database Performance Metrics**
- **Cache Performance Metrics**
- **Anomalies Detected**
- **Optimization Recommendations**

### Report Location

Reports are saved to: `/var/reports/performance/`

Example filenames:
- `performance_report_2026-02-11.markdown`
- `performance_report_weekly_2026-02-11.json`

## Prometheus Queries

### API Performance

```promql
# Request rate by service
sum(rate(http_requests_total[5m])) by (service)

# P95 latency
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))

# Error rate
sum(rate(http_requests_total{status=~"5.."}[5m])) /
sum(rate(http_requests_total[5m]))

# Top endpoints by request rate
topk(10, sum(rate(http_requests_total[5m])) by (endpoint))
```

### Database Performance

```promql
# P95 query latency
histogram_quantile(0.95, sum(rate(pg_stat_statements_call_seconds_bucket[5m])) by (le))

# Connection pool utilization
pg_stat_database_numbackends / pg_settings_max_connections

# Query throughput
sum(rate(pg_stat_statements_calls[5m]))
```

### Cache Performance

```promql
# Cache hit rate
rate(redis_keyspace_hits[5m]) /
(rate(redis_keyspace_hits[5m]) + rate(redis_keyspace_misses[5m]))

# Memory utilization
redis_memory_used_bytes / redis_memory_max_bytes

# Eviction rate
rate(redis_evicted_keys_total[5m])
```

## Performance Targets

| Metric | Target | Critical |
|--------|--------|-----------|
| **API P95 Latency** | <500ms | >1000ms |
| **API P99 Latency** | <1000ms | >5000ms |
| **API Error Rate** | <1% | >5% |
| **API Success Rate** | >99% | <95% |
| **DB P95 Query Time** | <1000ms | >5000ms |
| **DB Connection Pool** | <80% | >95% |
| **Cache Hit Rate** | >70% | <50% |
| **Cache Memory Usage** | <80% | >95% |

## Troubleshooting

### High API Latency

1. Check **Database Performance** dashboard for slow queries
2. Check **Cache Performance** dashboard for hit rate degradation
3. Review top endpoints in **API Performance** dashboard
4. Check system resources (CPU, memory, disk I/O)

### Low Cache Hit Rate

1. Review cache key patterns and TTL settings
2. Check for cache stamping or thundering herd
3. Consider increasing Redis memory allocation
4. Analyze cache miss patterns

### Database Slow Queries

1. Check `pg_stat_statements` for top slow queries
2. Review missing indexes
3. Analyze query execution plans
4. Check for connection pool exhaustion

### High Error Rate

1. Check application logs for error details
2. Review recent deployments for regressions
3. Check database connection health
4. Verify external dependencies

## Runbooks

Detailed runbooks are available at:
- API Latency: `https://docs.agl-hostman.com/runbooks/api-latency`
- Slow Queries: `https://docs.agl-hostman.com/runbooks/slow-queries`
- Cache Performance: `https://docs.agl-hostman.com/runbooks/cache-performance`

## Contacts

| Role | Contact | Availability |
|------|---------|--------------|
| **On-Call Engineer** | on-call@agl-hostman.com | 24/7 |
| **Performance Team** | performance@agl-hostman.com | Business hours |
| **Database Team** | database@agl-hostman.com | Business hours |

## Related Documentation

- [Prometheus Configuration](/docker/monitoring/prometheus/prometheus.yml)
- [Alerting Rules](/infrastructure/monitoring/rules/agl-23-performance-alerts.yml)
- [Recording Rules](/infrastructure/monitoring/rules/agl-23-recording-rules.yml)
- [Performance Report Generator](/scripts/monitoring/performance-report-generator.sh)

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-02-11 | Initial AGL-23 monitoring setup | Performance Engineer |
