# Service Level Objectives (SLOs) - AGL Hostman

## Overview

This document defines the Service Level Objectives (SLOs) for AGL Hostman platform, including Service Level Indicators (SLIs), targets, and error budgets.

## SLO Framework

### SLI Categories

1. **Availability**: Percentage of successful requests
2. **Latency**: Response time percentiles
3. **Error Rate**: Percentage of error responses
4. **Saturation**: Resource utilization levels

## Service-Specific SLOs

### 1. API Service (Laravel)

#### Availability
- **SLI**: Ratio of successful requests (2xx, 3xx) to total requests
- **SLO**: 99.9% monthly uptime (99.95% daily, 99.99% hourly)
- **Measurement**: `service:availability:ratio_30d`
- **Error Budget**: 43.2 minutes/month downtime

#### Latency
- **P50 Latency**: < 100ms
- **P95 Latency**: < 500ms
- **P99 Latency**: < 1000ms
- **Measurement**: `service:latency:p95_5m`, `service:latency:p99_5m`

#### Error Rate
- **5xx Error Rate**: < 0.1% (1 in 1000 requests)
- **4xx Error Rate**: < 5%
- **Measurement**: `service:error_rate:ratio_5m`

#### Throughput
- **Peak**: 10,000 requests/second
- **Sustained**: 1,000 requests/second

### 2. Frontend Service (Vue)

#### Availability
- **SLI**: Ratio of successful page loads
- **SLO**: 99.5% monthly uptime
- **Error Budget**: 3.6 hours/month downtime

#### Performance
- **First Contentful Paint (FCP)**: < 1.5s
- **Largest Contentful Paint (LCP)**: < 2.5s
- **Time to Interactive (TTI)**: < 3.5s
- **Cumulative Layout Shift (CLS)**: < 0.1

#### Error Rate
- **JavaScript Errors**: < 0.1% of sessions
- **Network Errors**: < 1% of requests

### 3. Database Service (PostgreSQL)

#### Availability
- **SLI**: Ratio of successful queries
- **SLO**: 99.95% monthly uptime
- **Error Budget**: 21.6 minutes/month downtime

#### Performance
- **Query Latency P95**: < 100ms
- **Query Latency P99**: < 500ms
- **Connection Pool Usage**: < 80%
- **Measurement**: `database:connection_pool:usage`

#### Data Integrity
- **Transaction Success Rate**: > 99.99%
- **Replication Lag**: < 30 seconds
- **Backup Completion**: 100% daily

### 4. Cache Service (Redis)

#### Availability
- **SLI**: Ratio of successful cache operations
- **SLO**: 99.9% monthly uptime
- **Error Budget**: 43.2 minutes/month downtime

#### Performance
- **Cache Hit Rate**: > 85%
- **Response Time P95**: < 5ms
- **Memory Usage**: < 80%
- **Measurement**: `redis:cache_hit_ratio`, `redis:memory:usage_percentage`

#### Evictions
- **Key Eviction Rate**: < 100/second
- **Measurement**: `redis:key_evictions:rate5m`

### 5. Queue Service (Laravel Horizon)

#### Availability
- **SLI**: Ratio of successful job processing
- **SLO**: 99.9% monthly uptime
- **Error Budget**: 43.2 minutes/month downtime

#### Performance
- **Job Throughput**: > 1000 jobs/minute
- **Job Wait Time P95**: < 30 seconds
- **Job Process Time P95**: < 60 seconds
- **Measurement**: `queue:jobs:wait_time_p95`, `queue:jobs:process_time_p95`

#### Reliability
- **Job Failure Rate**: < 0.1%
- **Worker Availability**: 100% (minimum 1 worker per queue)
- **Measurement**: `queue:jobs:failure_rate5m`

### 6. Monitoring Stack

#### Availability
- **Prometheus**: 99.9% uptime
- **Grafana**: 99.5% uptime
- **Alertmanager**: 99.9% uptime
- **Loki**: 99.5% uptime
- **Jaeger**: 99% uptime

#### Data Freshness
- **Metrics**: < 15s latency
- **Logs**: < 30s latency
- **Traces**: < 60s latency

## Error Budget Calculations

### Monthly Error Budget (30 days)

| Service | SLO | Downtime Budget | Error Rate Budget |
|---------|-----|-----------------|-------------------|
| API | 99.9% | 43.2 minutes | 0.1% |
| Frontend | 99.5% | 3.6 hours | 0.5% |
| Database | 99.95% | 21.6 minutes | 0.05% |
| Cache | 99.9% | 43.2 minutes | 0.1% |
| Queue | 99.9% | 43.2 minutes | 0.1% |

### Error Budget Burn Rates

- **1x burn**: Normal operation (within SLO)
- **2x burn**: Warning (burning error budget 2x faster than allowed)
- **10x burn**: Critical (burning error budget 10x faster than allowed)
- **Measurement**: `service:error_budget:burn_rate`

## SLI Measurement Details

### Availability SLI

```promql
# 5-minute availability
service:availability:ratio_5m =
  sum(rate(http_requests_total{status!~"5.."}[5m])) by (service)
  /
  sum(rate(http_requests_total[5m])) by (service)

# 24-hour availability
service:availability:ratio_24h =
  sum(rate(http_requests_total{status!~"5.."}[24h])) by (service)
  /
  sum(rate(http_requests_total[24h])) by (service)

# 30-day availability (for SLO compliance)
service:availability:ratio_30d =
  sum(rate(http_requests_total{status!~"5.."}[30d])) by (service)
  /
  sum(rate(http_requests_total[30d])) by (service)
```

### Latency SLI

```promql
# P95 latency
service:latency:p95_5m =
  histogram_quantile(0.95,
    sum(rate(http_request_duration_seconds_bucket[5m])) by (service, le)
  )

# Latency success ratio (requests under 500ms threshold)
service:latency_success:ratio_5m =
  sum(rate(http_request_duration_seconds_bucket{le="0.5"}[5m])) by (service)
  /
  sum(rate(http_request_duration_seconds_count[5m])) by (service)
```

### Error Rate SLI

```promql
# 5xx error rate
service:error_rate:ratio_5m =
  sum(rate(http_requests_total{status=~"5.."}[5m])) by (service)
  /
  sum(rate(http_requests_total[5m])) by (service)

# 4xx error rate
service:client_error_rate:ratio_5m =
  sum(rate(http_requests_total{status=~"4.."}[5m])) by (service)
  /
  sum(rate(http_requests_total[5m])) by (service)
```

### Error Budget Remaining

```promql
# Error budget remaining for 99% SLO
service:error_budget:remaining_99pct =
  (
    0.99
    -
    sum(rate(http_requests_total{status=~"5.."}[30d])) by (service)
    /
    sum(rate(http_requests_total[30d])) by (service)
  ) * 100
```

## SLO Time Windows

| Time Window | Target | Purpose |
|-------------|--------|---------|
| Rolling 5 minutes | 99.99% | Real-time monitoring |
| Rolling 1 hour | 99.95% | Hourly health checks |
| Rolling 24 hours | 99.9% | Daily reports |
| Rolling 30 days | 99.9% | Monthly SLO compliance |
| Calendar quarter | 99.9% | Business reporting |

## Alerting Thresholds

### SLO-Based Alerting

**Error Budget Burn Rate Alerts:**

- **Warning**: Burn rate > 2x for 1 hour
- **Critical**: Burn rate > 10x for 5 minutes

**SLI Breach Alerts:**

- **Warning**: SLI below SLO target for 10 minutes
- **Critical**: SLI below SLO target - 5% for 5 minutes

**Error Budget Exhaustion:**

- **Critical**: Error budget remaining < 25%

## SLO Review Process

### Monthly SLO Review

1. Calculate actual SLI performance
2. Compare against SLO targets
3. Analyze error budget consumption
4. Identify performance trends
5. Adjust targets if needed

### Quarterly SLO Planning

1. Review business requirements
2. Assess technical capabilities
3. Define new SLOs for features
4. Update error budgets
5. Communicate to stakeholders

## SLO Governance

### Responsibilities

- **SRE Team**: Define and maintain SLOs
- **Development Team**: Implement features to meet SLOs
- **Product Team**: Provide business requirements
- **Management**: Approve SLO targets

### Escalation

- **SLO Breach**: Automatic alert to on-call
- **Error Budget < 50%**: Escalate to engineering management
- **Error Budget < 25%**: Escalate to VP Engineering
- **Error Budget Exhausted**: Emergency incident response

## Compliance Monitoring

### Dashboards

- **SLO Compliance**: Overall SLO performance
- **Error Budget**: Error budget tracking
- **Service Health**: Individual service SLIs

### Reports

- **Daily**: SLO summary email
- **Weekly**: SLO performance report
- **Monthly**: SLO compliance report
- **Quarterly**: SLO planning document

## References

- [SLI/SLO Documentation](https://sre.google/sre-book/service-level-objectives/)
- [Error Budgets](https://sre.google/workbook/implementing-slos/)
- [Prometheus Recording Rules](../docker/monitoring/prometheus/recording_rules.yml)
- [Grafana SLO Dashboard](../docker/monitoring/grafana/dashboards/slo/compliance.json)
