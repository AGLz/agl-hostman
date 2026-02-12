# AGL-19: Monitoring and Observability Stack - Validation Checklist

**Issue ID**: AGL-19
**Title**: Monitoring and Observability Stack
**Priority**: Medium
**Estimate**: 2-3 weeks
**Current Status**: Partial Implementation (30%)
**Document Version**: 1.0
**Last Updated**: 2026-02-11

---

## Checklist Overview

This validation checklist ensures comprehensive implementation of the monitoring and observability stack. Use this checklist during implementation and for final validation before marking the task as complete.

**Legend**:
- [ ] = Not started
- [~] = In progress
- [x] = Complete
- [!] = Failed/Blocked
- [n/a] = Not applicable

---

## Phase 1: Metrics Collection Infrastructure

### 1.1 Prometheus Server Deployment

**Setup & Configuration**:
- [ ] Prometheus server deployed (Docker/container)
- [ ] Persistent storage configured (50GB+)
- [ ] Configuration file validated (prometheus.yml)
- [ ] Service/Process manager configured (systemd/docker-compose)
- [ ] Log rotation configured
- [ ] Backup/restore procedure documented

**Scrape Targets**:
- [ ] Prometheus self-monitoring enabled
- [ ] Node exporters on all Proxmox hosts (11 hosts)
- [ ] cAdvisor for container metrics (87+ containers)
- [ ] Custom exporters configured (MySQL, Redis, Nginx)

**Data Retention**:
- [ ] Raw data retention: 15 days
- [ ] Compressed data retention: 45 days
- [ ] Evaluation interval: 15s
- [ ] Storage capacity planning documented

### 1.2 Node Exporter (Host Metrics)

**All Hosts**:
- [ ] AGLSRV1 - node_exporter installed
- [ ] AGLSRV3 - node_exporter installed
- [ ] AGLSRV5 - node_exporter installed
- [ ] AGLSRV6 - node_exporter installed
- [ ] AGLSRV6C - node_exporter installed
- [ ] AGLSRV6D - node_exporter installed
- [ ] FGSRV3 - node_exporter installed
- [ ] FGSRV4 - node_exporter installed
- [ ] FGSRV5 - node_exporter installed
- [ ] FGSRV6 - node_exporter installed

**Metrics Validation**:
```bash
# Test each host
curl http://<host-ip>:9100/metrics | grep node_cpu_seconds_total
curl http://<host-ip>:9100/metrics | grep node_memory_MemAvailable_bytes
curl http://<host-ip>:9100/metrics | grep node_filesystem_avail_bytes
```

- [ ] CPU metrics collected
- [ ] Memory metrics collected
- [ ] Disk metrics collected
- [ ] Network metrics collected
- [ ] System load metrics collected

### 1.3 cAdvisor (Container Metrics)

**Deployment**:
- [ ] cAdvisor deployed on all Proxmox hosts
- [ ] Docker socket mounted (read-only)
- [ ] Store all container metrics enabled
- [ ] Housekeeping interval: 1m

**Metrics Validation**:
- [ ] Container CPU usage collected
- [ ] Container memory usage collected
- [ ] Container network I/O collected
- [ ] Container disk I/O collected
- [ ] Container lifecycle events captured

### 1.4 Database Exporters

**MySQL Exporter**:
- [ ] MySQL exporter deployed
- [ ] Connection credentials secured (not in command line)
- [ ] Metrics from all MySQL instances
- [ ] Slow query metrics enabled
- [ ] InnoDB metrics collected

**Redis Exporter**:
- [ ] Redis exporter deployed
- [ ] Connection to Redis instances
- [ ] Key metrics collected
- [ ] Memory usage tracked
- [ ] Command statistics captured

**PostgreSQL Exporter**:
- [ ] PostgreSQL exporter deployed
- [ ] Connection to PostgreSQL databases
- [ ] Query performance metrics
- [ ] Replication lag metrics (if applicable)

### 1.5 Application Metrics

**Laravel Exporter**:
- [ ] Custom Laravel metrics endpoint (/metrics)
- [ ] Request rate metrics (histogram)
- [ ] Response time metrics (histogram)
- [ ] Error rate metrics (counter)
- [ ] Authentication event metrics
- [ ] Database query time metrics

**Business Metrics**:
- [ ] Active user sessions tracked
- [ ] API key usage tracked
- [ ] MCP server calls tracked
- [ ] Background job status tracked

---

## Phase 2: Log Aggregation

### 2.1 Loki Server Deployment

**Setup & Configuration**:
- [ ] Loki server deployed (Docker/container)
- [ ] Persistent storage configured (100GB+)
- [ ] Retention policy: 30 days
- [ ] Index schema configured
- [ ] Compaction configured
- [ ] High availability setup (if needed)

**Storage Backend**:
- [ ] Filesystem storage configured
- [ ] S3/GCS optional (for long-term archival)
- [ ] Storage capacity planning done

### 2.2 Promtail (Log Shipping)

**All Hosts**:
- [ ] Promtail installed on all Proxmox hosts
- [ ] Configuration files created
- [ ] Journal input configured (systemd logs)
- [ ] Docker container logs configured
- [ ] Static log files configured

**Log Sources**:
- [ ] System logs (journald)
- [ ] Container logs (docker)
- [ ] Application logs (Laravel)
- [ ] Nginx/access logs
- [ ] Nginx/error logs
- [ ] Cron logs
- [ ] Backup logs

### 2.3 Log Parsing & Structuring

**Pipeline Stages**:
- [ ] Regex parsing for common log formats
- [ ] JSON parsing for structured logs
- [ ] Label extraction (hostname, service, level)
- [ ] Timestamp normalization
- [ ] Line filtering (drop debug in prod)

**Log Quality**:
- [ ] All logs have timestamp
- [ ] All logs have severity level
- [ ] All logs have service identifier
- [ ] All logs have hostname
- [ ] Structured logging format enforced

### 2.4 Log Retention & Archival

**Retention Policy**:
- [ ] 7 days: All logs
- [ ] 30 days: Warning/Error logs
- [ ] 90 days: Critical/Error logs
- [ ] Archival to S3/GCS (optional)

**Verification**:
- [ ] Log cleanup job automated
- [ ] Archive verification in place
- [ ] Compliance requirements met

---

## Phase 3: Visualization & Dashboards

### 3.1 Grafana Server

**Setup & Configuration**:
- [ ] Grafana server deployed
- [ ] Admin credentials secured
- [ ] Anonymous viewing disabled
- [ ] SMTP/email configured (for alerts)
- [ ] Persistent storage for dashboards

**Data Sources**:
- [ ] Prometheus data source added
- [ ] Loki data source added
- [ ] Test queries successful
- [ ] Default time range: Last 6 hours

### 3.2 Essential Dashboards

**Infrastructure Overview**:
- [ ] Host overview dashboard created
- [ ] Container overview dashboard created
- [ ] Network overview dashboard created
- [ ] Storage overview dashboard created

**Application Performance**:
- [ ] Laravel application dashboard
- [ ] API response time dashboard
- [ ] Error rate dashboard
- [ ] Database performance dashboard

**Security & Compliance**:
- [ ] Authentication events dashboard
- [ ] Failed login attempts dashboard
- [ ] MCP server access dashboard
- [ ] Backup status dashboard

### 3.3 Dashboard Quality Checks

**Each Dashboard Must Have**:
- [ ] Title and description
- [ ] Time range selector
- [ ] Auto-refresh (30s or 1m)
- [ ] Annotations for deployments
- [ ] Meaningful panel titles
- [ ] Unit labels on metrics
- [ ] Threshold indicators (warning/danger)

**Panel Variety**:
- [ ] Graph (time series)
- [ ] Stat (single value)
- [ ] Gauge (percentages)
- [ ] Table (log lists)
- [ ] Heatmap (patterns)

---

## Phase 4: Alerting & Notification

### 4.1 Alertmanager Deployment

**Setup & Configuration**:
- [ ] Alertmanager deployed
- [ ] Prometheus configured to use Alertmanager
- [ ] Configuration validated
- [ ] High availability setup (if needed)

**Silence & Inhibition**:
- [ ] Inhibition rules configured
- [ ] Silence mechanism documented
- [ ] Maintenance mode procedure

### 4.2 Alert Rules

**Critical Alerts (Paging)**:
```yaml
# Example rules to implement
- [ ] InstanceDown (any service down > 1m)
- [ ] API5xxRate (error rate > 5% for 2m)
- [ ] APIResponseTimeHigh (p95 > 500ms for 5m)
- [ ] DatabaseDown (DB unreachable for 1m)
- [ ] BackupFailed (backup job failed)
- [ ] DiskSpaceHigh (> 90% for 5m)
- [ ] MemoryUsageHigh (> 90% for 5m)
```

**Warning Alerts (Email)**:
```yaml
- [ ] APIResponseTimeElevated (p95 > 300ms for 10m)
- [ ] DiskSpaceWarning (> 75% for 15m)
- [ ] MemoryUsageWarning (> 80% for 15m)
- [ ] ContainerRestarted (container restarted)
- [ ] HighErrorRate (error rate > 1% for 10m)
```

**Info Alerts (Log)**:
```yaml
- [ ] SSLCertExpiring (cert expires in 30 days)
- [ ] BackupJobCompleted (backup success)
- [ ] HighCPUUsage (sustained > 70% for 15m)
```

### 4.3 Notification Channels

**Email**:
- [ ] SMTP configured and tested
- [ ] Recipient list configured
- [ ] Email templates validated

**PagerDuty/Opsgenie** (if available):
- [ ] Integration key configured
- [ ] Severity mapping validated
- [ ] Escalation policies configured

**Slack/Teams** (if available):
- [ ] Webhook URL configured
- [ ] Channel routing configured
- [ ] Message format validated

### 4.4 SLI/SLO Tracking

**Service Level Indicators**:
- [ ] API Availability SLI defined
- [ ] API Response Time SLI defined
- [ ] Database Performance SLI defined
- [ ] Backup Success SLI defined

**Service Level Objectives**:
- [ ] API Availability: 99.9% target
- [ ] API Response Time: <200ms (p95) target
- [ ] Database Query: <50ms (p95) target
- [ ] Backup Success: 100% target

**SLO Dashboards**:
- [ ] Error budget calculated
- [ ] Current SLO status displayed
- [ ] Burn rate visualization
- [ ] 28-day rolling window

---

## Phase 5: Distributed Tracing (Optional)

### 5.1 Jaeger Deployment

**Setup**:
- [ ] Jaeger all-in-one deployed
- [ ] Storage backend configured (Elasticsearch/Cassandra)
- [ ] UI accessible and secured
- [ ] Sampling strategy configured

**Instrumentation**:
- [ ] Laravel tracing middleware added
- [ ] Database query tracing enabled
- [ ] HTTP client tracing enabled
- [ ] Background job tracing enabled

### 5.2 Trace Quality

**Validation**:
- [ ] End-to-end traces visible
- [ ] Span context propagated correctly
- [ ] Trace IDs in logs (correlation)
- [ ] Performance bottlenecks identifiable

---

## Phase 6: Operations & Maintenance

### 6.1 Monitoring Operations

**Daily Checks**:
- [ ] Dashboard review (morning)
- [ ] Alert acknowledgment
- [ ] Outstanding investigation review

**Weekly Checks**:
- [ ] Performance trend analysis
- [ ] Storage capacity review
- [ ] Alert rule tuning

**Monthly Tasks**:
- [ ] SLI/SLO review
- [ ] Dashboard optimization
- [ ] Log retention cleanup
- [ ] Retention policy review

### 6.2 Runbooks & Documentation

**Required Documentation**:
- [ ] Monitoring stack architecture diagram
- [ ] Alert runbook (troubleshooting each alert)
- [ ] On-call procedures
- [ ] Escalation procedures
- [ ] Disaster recovery for monitoring

**Training**:
- [ ] Team training on Grafana
- [ ] Team training on alert response
- [ ] Team training on log querying

### 6.3 Backup & Restore

**Monitoring Data Backup**:
- [ ] Prometheus data backup automated
- [ ] Loki data backup automated
- [ ] Grafana dashboard backup automated
- [ ] Alertmanager configuration backup
- [ ] Backup restoration tested quarterly

---

## Validation Test Cases

### Test Case 1: Metrics Collection

**Objective**: Verify all metrics are collected and stored

**Steps**:
1. Generate load on application
2. Check Prometheus targets: All targets UP
3. Query metrics in Prometheus UI
4. Verify data in Grafana dashboards

**Expected Results**:
- [ ] All scrape targets show "UP"
- [ ] Metrics have recent timestamps (< 30s old)
- [ ] No gaps in metric data
- [ ] Grafana dashboards show current data

**Pass/Fail**: [ ]

### Test Case 2: Log Aggregation

**Objective**: Verify logs are centralized and searchable

**Steps**:
1. Generate application event (login, error)
2. Query Loki for event
3. Verify log fields parsed correctly
4. Check Grafana logs panel

**Expected Results**:
- [ ] Event appears in Loki within 30s
- [ ] Log fields parsed correctly
- [ ] Labels (host, service) correct
- [ ] Full stacktrace available

**Pass/Fail**: [ ]

### Test Case 3: Alert Delivery

**Objective**: Verify alerts are sent correctly

**Steps**:
1. Trigger alert (stop a service)
2. Wait for alert notification
3. Verify alert content
4. Resolve alert
5. Verify resolution notification

**Expected Results**:
- [ ] Alert fired within evaluation period
- [ ] Notification sent to correct channel
- [ ] Alert contains useful information
- [ ] Resolution notification sent
- [ ] Alert cleared in UI

**Pass/Fail**: [ ]

### Test Case 4: SLI Tracking

**Objective**: Verify SLI/SLO calculations

**Steps**:
1. Review current SLO dashboard
2. Verify error budget calculation
3. Check SLO compliance over 28-day window
4. Simulate outage (optional)
5. Verify SLO impact calculated

**Expected Results**:
- [ ] SLO calculated correctly
- [ ] Error budget displayed
- [ ] Burn rate accurate
- [ ] 28-day window used

**Pass/Fail**: [ ]

### Test Case 5: Distributed Tracing

**Objective**: Verify end-to-end request tracing

**Steps**:
1. Make API request with trace ID
2. Search Jaeger for trace ID
3. Review trace timeline
4. Identify slowest span

**Expected Results**:
- [ ] Trace found in Jaeger
- [ ] All services in trace
- [ ] Timeline shows request flow
- [ ] Bottlenecks identifiable

**Pass/Fail**: [ ]

---

## Sign-off Criteria

### Minimum Viable Product (MVP)

For AGL-19 to be marked as MVP complete, the following must be achieved:

**Essential Components**:
- [ ] Prometheus deployed and collecting metrics from all hosts
- [ ] Grafana deployed with basic dashboards
- [ ] Alertmanager deployed with email notifications
- [ ] Loki deployed collecting logs from all services
- [ ] Critical alert rules configured and tested
- [ ] Documentation for operating the stack

**Essential Validation**:
- [ ] All Test Cases 1-3 pass
- [ ] At least 3 dashboards created and validated
- [ ] Team trained on basic usage
- [ ] Runbook for common incidents

### Full Implementation

For AGL-19 to be marked as fully complete:

**All Components**:
- [ ] All MVP criteria met
- [ ] Distributed tracing deployed (Jaeger)
- [ ] Advanced alerting (PagerDuty/Slack)
- [ ] SLI/SLO tracking operational
- [ ] Comprehensive runbooks
- [ ] Automated backup of monitoring data

**All Validation**:
- [ ] All Test Cases 1-5 pass
- [ ] 10+ dashboards created
- [ ] Team fully trained
- [ ] Quarterly backup restore tested

---

## Issue Tracking

### Blockers & Dependencies

| Issue | Description | Impact | Resolution |
|-------|-------------|---------|------------|
| | | | |

### Notes & Observations

| Date | Note | Author |
|------|-------|--------|
| | | |

---

## Appendix

### Appendix A: Configuration File Locations

```
/etc/prometheus/
├── prometheus.yml
├── alert_rules/
│   ├── critical.yml
│   ├── warning.yml
│   └── info.yml
└── file_sd/

/etc/loki/
├── local-config.yaml
└── rules/

/etc/alertmanager/
├── alertmanager.yml
├── templates/
└── silence/

/etc/grafana/
├── grafana.ini
├── provisioning/
│   ├── datasources/
│   └── dashboards/
```

### Appendix B: Useful Queries

**Prom Queries**:
```promql
# CPU usage
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage
1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)

# Disk usage
(node_filesystem_avail_bytes{fstype!="tmpfs"} / node_filesystem_size_bytes) < 0.1

# API error rate
(sum(rate(http_requests_total{status=~"5.."}[5m])) / (sum(rate(http_requests_total[5m]))) * 100
```

**LogQL Queries**:
```logql
# Laravel application errors
{job="laravel", level="error"} |= "ERROR"

# Authentication failures
{job="laravel"} |= "Failed"

# Backup errors
{job="backup"} |= "error"
```

### Appendix C: Port Reference

| Service | Port | Protocol |
|---------|-------|----------|
| Prometheus | 9090 | HTTP |
| Alertmanager | 9093 | HTTP |
| Grafana | 3000 | HTTP |
| Loki | 3100 | HTTP |
| Node Exporter | 9100 | HTTP |
| cAdvisor | 8080 | HTTP |
| Jaeger UI | 16686 | HTTP |
| Jaeger Collector | 14268 | HTTP |
| Jaeger Agent | 6831 | UDP/HTTP |

---

**Checklist Completed By**: _________________
**Date**: ___________________
**Reviewed By**: _________________
**Sign-off Date**: ___________________
**Status**: [ ] MVP Complete [ ] Fully Complete

**END OF AGL-19 VALIDATION CHECKLIST**
