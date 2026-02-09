# Monitoring and Observability Stack

## Overview

This directory contains the complete monitoring and observability infrastructure for AGL Hostman, including Prometheus, Grafana, Alertmanager, Loki, Promtail, and Jaeger.

## Quick Start

### Start the Monitoring Stack

```bash
# Copy environment file and configure
cp .env.example .env
# Edit .env with your configuration

# Start all services
./scripts/monitoring/start-monitoring.sh
```

### Access the Services

- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000 (admin/admin - change in .env)
- **Alertmanager**: http://localhost:9093
- **Loki**: http://localhost:3100
- **Jaeger**: http://localhost:16686

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                       Applications                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │ Laravel  │  │   Vue    │  │PostgreSQL│  │  Redis   │  │
│  │   API    │  │ Frontend │  │          │  │          │  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘  │
│       │             │             │             │          │
│       └─────────────┴─────────────┴─────────────┘          │
│                             │                               │
└─────────────────────────────┼───────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│   Prometheus │◄───│  Exporters   │◄───│ Node Exporter│
│   (9090)     │    │              │    │   (9100)      │
└──────┬───────┘    └──────────────┘    └──────────────┘
       │
       ├──────────────────────────────────┐
       │                                  │
       ▼                                  ▼
┌──────────────┐                  ┌──────────────┐
│ Alertmanager │                  │    Grafana   │
│   (9093)     │                  │   (3000)     │
└──────────────┘                  └──────┬───────┘
                                         │
        ┌────────────────────────────────┴────────────────────┐
        │                                                 │
        ▼                                                 ▼
┌──────────────┐                                  ┌──────────────┐
│     Loki     │◄─────────────────────────────────│  Promtail    │
│   (3100)     │                                  │   (9080)     │
└──────────────┘                                  └──────────────┘
        │
        ▼
┌──────────────┐
│    Jaeger    │
│  (16686)     │
└──────────────┘
```

## Components

### Prometheus (Metrics Collection)

- **Port**: 9090
- **Purpose**: Collects and stores metrics from all services
- **Configuration**: `prometheus/prometheus.yml`
- **Retention**: 30 days, 50GB
- **Scrape Interval**: 15 seconds

Key Features:
- Multi-target metrics collection
- Alert evaluation engine
- Recording rules for SLIs/SLOs
- Service discovery

### Grafana (Visualization)

- **Port**: 3000
- **Purpose**: Data visualization and dashboards
- **Configuration**: `grafana/provisioning/`
- **Default Credentials**: admin/admin (change in .env)

Key Features:
- Pre-configured datasources
- Automated dashboard provisioning
- User authentication
- Alert notifications

### Alertmanager (Alert Routing)

- **Port**: 9093
- **Purpose**: Manages and routes alerts
- **Configuration**: `alertmanager/alertmanager.yml`

Key Features:
- Alert grouping and deduplication
- Multiple notification channels
- Inhibition rules
- Silence management

### Loki (Log Aggregation)

- **Port**: 3100
- **Purpose**: Centralized log storage
- **Configuration**: `loki/loki-config.yml`
- **Retention**: 30 days

Key Features:
- Horizontally scalable
- Label-based indexing
- Full-text search
- Log query language (LogQL)

### Promtail (Log Collection)

- **Port**: 9080 (metrics)
- **Purpose**: Collects logs from containers
- **Configuration**: `promtail/promtail-config.yml`

Key Features:
- Docker log discovery
- Log parsing and enrichment
- Label extraction
- Multiple pipeline stages

### Jaeger (Distributed Tracing)

- **Port**: 16686 (UI), 4317/4318 (OTLP)
- **Purpose**: Distributed tracing for microservices
- **Configuration**: Built-in (all-in-one)

Key Features:
- End-to-end tracing
- Service dependency graphs
- Performance analysis
- Trace search and filtering

## Metrics and Targets

### Application Services

| Service | Endpoint | Metrics |
|---------|----------|---------|
| Laravel API | app:8080/metrics | HTTP requests, latency, errors |
| Vue Frontend | frontend:3000/metrics | Page views, performance |
| PostgreSQL | postgres-exporter:9187/metrics | Connections, queries, performance |
| Redis | redis-exporter:9121/metrics | Memory, hit rate, operations |

### Infrastructure Services

| Service | Endpoint | Metrics |
|---------|----------|---------|
| Node Exporter | node-exporter:9100/metrics | CPU, memory, disk, network |
| cAdvisor | cadvisor:8080/metrics | Container stats |
| Docker | dockerhost:9323/metrics | Daemon metrics |

## Alerting Rules

### Severity Levels

- **Critical**: Immediate action required (P1)
- **Warning**: Attention needed (P2/P3)
- **Info**: Informational (P4)

### Alert Categories

1. **Application Health**
   - Service down
   - High error rate
   - High latency

2. **Database**
   - Connection failures
   - Slow queries
   - Replication lag

3. **Infrastructure**
   - High CPU/memory
   - Disk space low
   - Network issues

4. **SLO Compliance**
   - Availability breaches
   - Error budget burn
   - Latency SLI breaches

## Dashboards

### Available Dashboards

- **AGL Hostman Overview**: System-wide metrics
- **Service Health**: Individual service monitoring
- **SLO Compliance**: SLI/SLO tracking
- **Database Performance**: PostgreSQL metrics
- **Cache Performance**: Redis metrics
- **Queue Metrics**: Laravel Horizon stats

### Custom Dashboards

Create custom dashboards in Grafana UI. Export to `grafana/dashboards/` for persistence.

## Runbooks

Located in `/ops/runbooks/`:

- `service-down.md` - Complete service outage
- `high-error-rate.md` - Elevated error rates
- `database-down.md` - Database failures
- `redis-down.md` - Cache failures
- `queue-backlog.md` - Queue processing issues

## SLOs

Service Level Objectives are defined in `/ops/slos/slo-definitions.md`:

- **API**: 99.9% availability, P95 < 500ms
- **Frontend**: 99.5% availability
- **Database**: 99.95% availability
- **Cache**: 99.9% availability, >85% hit rate

## Maintenance

### Daily Tasks

- Check Grafana dashboards
- Review Alertmanager alerts
- Verify log ingestion

### Weekly Tasks

- Review SLO compliance
- Check error budget status
- Analyze trends

### Monthly Tasks

- Review and update alert rules
- Optimize recording rules
- Clean up old dashboards

## Troubleshooting

### Services Not Starting

```bash
# Check logs
docker-compose -f docker-compose.monitoring.yml logs

# Check port conflicts
lsof -i :9090 -i :3000 -i :9093
```

### Missing Metrics

```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets | jq .

# Check scrape errors
docker logs agl-prometheus | grep error
```

### Alertmanager Not Sending Alerts

```bash
# Test webhook configuration
curl -X POST http://localhost:9093/api/v2/alerts -d '[{
  "labels": {"alertname": "Test", "severity": "warning"}
}]'

# Check configuration
docker exec agl-alertmanager amtool config validate
```

## Backup and Restore

### Backup Data

```bash
# Create backup directory
mkdir -p backups/$(date +%Y%m%d)

# Backup volumes
docker run --rm \
  -v agl_prometheus-data:/data \
  -v $(pwd)/backups/$(date +%Y%m%d):/backup \
  alpine tar czf /backup/prometheus.tar.gz -C /data .

# Repeat for other volumes
```

### Restore Data

```bash
# Stop services
./scripts/monitoring/stop-monitoring.sh

# Restore volume
docker run --rm \
  -v agl_prometheus-data:/data \
  -v $(pwd)/backups/20250101:/backup \
  alpine tar xzf /backup/prometheus.tar.gz -C /data

# Start services
./scripts/monitoring/start-monitoring.sh
```

## Scaling

### High Availability

For production, deploy with:

1. **Prometheus**: Multiple replicas with Thanos for long-term storage
2. **Grafana**: Multiple instances with load balancer
3. **Alertmanager**: Clustered deployment
4. **Loki**: Distributed mode with Consul

### Performance Tuning

- Adjust scrape intervals based on needs
- Use recording rules for complex queries
- Implement metric relabeling to reduce cardinality
- Tune retention periods

## Security

### Best Practices

1. **Authentication**
   - Change default passwords
   - Enable Grafana authentication
   - Use API tokens for automation

2. **Network Security**
   - Use internal networks for inter-service communication
   - Expose only necessary ports
   - Implement TLS/SSL

3. **Data Protection**
   - Encrypt sensitive data
   - Regular security updates
   - Access logging

## Support

- **Documentation**: `/ops/runbooks/`
- **Issues**: https://github.com/your-org/agl-hostman/issues
- **Slack**: #monitoring

## References

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [Jaeger Documentation](https://www.jaegertracing.io/docs/)
- [SRE Book](https://sre.google/sre-book/table-of-contents/)
