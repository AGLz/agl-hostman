# Production Environment Setup Guide

**Version**: 1.0.0
**Last Updated**: 2025-01-20
**Phase**: 3.3 - Production Deployment with High Availability

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Infrastructure Setup](#infrastructure-setup)
4. [Application Deployment](#application-deployment)
5. [Monitoring Setup](#monitoring-setup)
6. [Backup Configuration](#backup-configuration)
7. [Security Hardening](#security-hardening)
8. [Testing and Validation](#testing-and-validation)
9. [Rollout Checklist](#rollout-checklist)

---

## Overview

### Architecture

The production environment implements a **blue-green deployment strategy** with high availability:

- **2 Application Replicas** (blue-1, blue-2 or green-1, green-2)
- **PostgreSQL 16 Replication** (primary + replica)
- **Redis Sentinel** for cache/queue HA
- **Nginx Load Balancer** with least-connection algorithm
- **Prometheus + Grafana** for observability
- **Automated Backups** to S3/Backblaze

### Deployment Targets

- **Primary**: CT182 (192.168.0.182) or CT181 with HA configuration
- **Harbor Registry**: harbor.aglz.io:5000/agl-hostman-prod
- **Git Branch**: main (protected)
- **Domains**:
  - prod-agl.aglz.io (primary)
  - agl-hostman.aglz.io (canonical)

### Resource Requirements

**Per Application Replica**:
- CPU: 2-4 cores (reserved: 2, limit: 4)
- Memory: 4-8GB (reserved: 4GB, limit: 8GB)
- Disk: 100GB SSD

**Total Production Stack**:
- CPU: 8-16 cores
- Memory: 16-32GB
- Disk: 500GB SSD (including backups)

---

## Prerequisites

### Required Software

```bash
# Verify installations
docker --version          # Docker 24.0+
docker compose version    # Docker Compose v2.20+
git --version            # Git 2.40+
psql --version           # PostgreSQL client 16+

# Install if missing (Debian/Ubuntu)
sudo apt update
sudo apt install -y docker.io docker-compose-v2 git postgresql-client-16
```

### Harbor Registry Access

```bash
# Configure Harbor credentials
docker login harbor.aglz.io:5000
# Username: admin
# Password: [from password manager]

# Test access
docker pull harbor.aglz.io:5000/library/nginx:alpine
```

### GitHub Repository Access

```bash
# Clone repository
git clone git@github.com:your-org/agl-hostman.git
cd agl-hostman

# Verify main branch
git checkout main
git pull origin main
```

### SSL Certificates

```bash
# Generate self-signed (development) or use Let's Encrypt (production)
# For production, use certbot:

sudo certbot certonly --standalone \
  -d prod-agl.aglz.io \
  -d agl-hostman.aglz.io

# Certificates will be in:
# /etc/letsencrypt/live/prod-agl.aglz.io/fullchain.pem
# /etc/letsencrypt/live/prod-agl.aglz.io/privkey.pem
```

---

## Infrastructure Setup

### Step 1: Run Setup Command

```bash
cd src/
php artisan production:setup
```

**What This Does**:
1. Verifies prerequisites
2. Creates production environment record
3. Creates production deployment configuration
4. Generates production secrets
5. Configures monitoring
6. Configures automated backups
7. Displays next steps

**Expected Output**:
```
✅ Production environment setup completed!

Environment ID: [UUID]
Environment Name: Production

Next steps:
1. Review and update .env.production with generated secrets
2. Deploy infrastructure: docker compose -f docker/production/docker-compose.blue.yml up -d
3. Run database migrations: docker exec agl-hostman-app-blue-1 php artisan migrate --force
4. Deploy load balancer: docker compose -f docker/production/docker-compose.lb.yml up -d
5. Run production smoke tests: docker exec agl-hostman-app-blue-1 php artisan test --testsuite=Production
```

### Step 2: Configure Environment Variables

```bash
# Copy generated .env.production
cp .env.production.example .env.production

# Update with production values
nano .env.production
```

**Critical Variables to Set**:
```bash
# Application
APP_ENV=production
APP_DEBUG=false
APP_KEY=[generated]

# Database
PRODUCTION_DB_PASSWORD=[secure-password]
PRODUCTION_REPLICATION_PASSWORD=[secure-password]

# Redis
PRODUCTION_REDIS_PASSWORD=[secure-password]

# Dokploy
PRODUCTION_DOKPLOY_TOKEN=[from-dokploy-dashboard]

# Harbor
HARBOR_PASSWORD=[from-password-manager]

# Monitoring
GRAFANA_PASSWORD=[secure-password]
ALERT_EMAIL=ops@agl.com
ALERT_SLACK_WEBHOOK=[slack-webhook-url]

# Backup
BACKUP_S3_BUCKET=agl-hostman-backups
AWS_ACCESS_KEY_ID=[aws-key]
AWS_SECRET_ACCESS_KEY=[aws-secret]

# Notifications
DEPLOYMENT_EMAIL_RECIPIENTS=ops@agl.com,team@agl.com
DEPLOYMENT_SLACK_CHANNEL=#deployments
```

### Step 3: Deploy Blue Environment

```bash
# Navigate to production directory
cd docker/production/

# Start blue environment
docker compose -f docker-compose.blue.yml up -d

# Verify all containers are running
docker compose -f docker-compose.blue.yml ps

# Check logs
docker compose -f docker-compose.blue.yml logs -f
```

**Expected Containers**:
- agl-hostman-app-blue-1
- agl-hostman-app-blue-2
- agl-hostman-postgres-primary
- agl-hostman-postgres-replica
- agl-hostman-redis-master
- agl-hostman-redis-sentinel

### Step 4: Run Database Migrations

```bash
# Run migrations on blue-1
docker exec agl-hostman-app-blue-1 php artisan migrate --force

# Verify migrations
docker exec agl-hostman-app-blue-1 php artisan migrate:status
```

### Step 5: Deploy Load Balancer and Monitoring

```bash
# Start load balancer stack
docker compose -f docker-compose.lb.yml up -d

# Verify
docker compose -f docker-compose.lb.yml ps

# Check nginx configuration
docker exec agl-hostman-load-balancer nginx -t
docker exec agl-hostman-load-balancer nginx -s reload
```

**Expected Containers**:
- agl-hostman-load-balancer
- agl-hostman-prometheus
- agl-hostman-grafana
- agl-hostman-backup

### Step 6: Configure DNS

```bash
# Add A records for production domains
# prod-agl.aglz.io      → [CT182-IP]
# agl-hostman.aglz.io   → [CT182-IP]

# Verify DNS propagation
dig prod-agl.aglz.io +short
dig agl-hostman.aglz.io +short
```

---

## Application Deployment

### Initial Deployment (Blue Environment)

```bash
# Build and push image to Harbor
docker build -t harbor.aglz.io:5000/agl-hostman-prod:v1.0.0 .
docker push harbor.aglz.io:5000/agl-hostman-prod:v1.0.0

# Update docker-compose.blue.yml with new image version
sed -i 's|image:.*|image: harbor.aglz.io:5000/agl-hostman-prod:v1.0.0|g' docker-compose.blue.yml

# Restart blue environment
docker compose -f docker-compose.blue.yml up -d

# Wait for health checks
sleep 30

# Verify application is healthy
curl -f http://localhost:3000/health
```

### Blue-Green Deployment Process

See [BLUE-GREEN-DEPLOYMENT.md](BLUE-GREEN-DEPLOYMENT.md) for detailed deployment procedures.

**Quick Reference**:
1. Deploy to inactive environment (green)
2. Run smoke tests on green
3. Switch traffic gradually (10% → 50% → 100%)
4. Monitor for issues
5. Rollback if needed (< 2 minutes)

---

## Monitoring Setup

### Prometheus Configuration

```bash
# Access Prometheus
http://[CT182-IP]:9090

# Verify targets are up
# Navigate to: Status → Targets

# Should show:
# - app-blue-1:9100 (node exporter)
# - app-blue-2:9100 (node exporter)
# - postgres-primary:9187 (postgres exporter)
# - redis-master:9121 (redis exporter)
```

**Key Metrics to Monitor**:
```promql
# HTTP Request Rate
rate(http_requests_total[5m])

# Error Rate
rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m])

# Response Time (P95)
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Database Connections
pg_stat_database_numbackends

# Redis Memory Usage
redis_memory_used_bytes
```

### Grafana Dashboards

```bash
# Access Grafana
http://[CT182-IP]:3001
# Username: admin
# Password: [from .env.production]

# Import dashboards
# Navigate to: Dashboards → Import
# Use dashboard IDs:
# - 1860 (Node Exporter Full)
# - 9628 (PostgreSQL Database)
# - 11835 (Redis Dashboard)
```

**Custom Dashboard**: The production monitoring service automatically creates:
- Application Overview Dashboard
- Database Performance Dashboard
- Cache Performance Dashboard
- Deployment Status Dashboard

### Alert Configuration

```bash
# Edit Prometheus alert rules
nano docker/production/prometheus/alerts.yml
```

**Alert Thresholds** (from .env.production):
- Error Rate > 1%
- P95 Response Time > 500ms
- Database Pool > 80%
- Disk Space < 20%
- Memory Usage > 85%

**Alert Channels**:
- Email: ops@agl.com
- Slack: #production-alerts

---

## Backup Configuration

### Automated Backups

```bash
# Verify backup cron is running
docker exec agl-hostman-backup crontab -l

# Should show:
# 0 2 * * * /app/backup-full.sh      # Daily at 2 AM
# 0 * * * * /app/backup-incremental.sh  # Hourly
```

### Manual Backup

```bash
# Trigger manual backup
php artisan production:backup --type=full --verify --upload

# Check backup status
php artisan production:backup:status

# List backups
php artisan production:backup:list
```

### Backup Verification

```bash
# Backups are automatically verified on creation
# Manual verification:
php artisan production:backup:verify [backup-id]

# Test restore (monthly)
php artisan production:backup:test-restore [backup-id]
```

### Offsite Storage

**S3 Configuration**:
```bash
# Verify S3 bucket access
aws s3 ls s3://agl-hostman-backups/

# List production backups
aws s3 ls s3://agl-hostman-backups/backups/production/
```

**Retention Policy**:
- Daily full backups: 30 days
- Hourly incremental: 7 days
- Monthly full backups: 1 year (archived)

---

## Security Hardening

### Network Security

```bash
# Configure firewall (UFW)
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw enable

# Verify
sudo ufw status verbose
```

### Application Security

**Rate Limiting**:
```nginx
# Already configured in nginx.conf
limit_req_zone $binary_remote_addr zone=api:10m rate=100r/s;
limit_conn_zone $binary_remote_addr zone=addr:10m;
```

**Security Headers**:
```nginx
# Already configured in nginx.conf
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline';" always;
```

### Database Security

```bash
# Enable SSL for PostgreSQL connections
# Edit postgresql.conf
ssl = on
ssl_cert_file = '/etc/ssl/certs/server.crt'
ssl_key_file = '/etc/ssl/private/server.key'

# Restart PostgreSQL
docker compose -f docker-compose.blue.yml restart postgres-primary
```

### Secret Rotation

```bash
# Rotate secrets every 90 days (PRODUCTION_SECRETS_ROTATION_DAYS=90)

# Generate new secrets
php artisan production:rotate-secrets

# This will:
# 1. Generate new APP_KEY, DB_PASSWORD, REDIS_PASSWORD
# 2. Update .env.production
# 3. Trigger rolling restart of services
# 4. Verify connectivity after rotation
```

### Audit Logging

```bash
# Enable audit logging
PRODUCTION_AUDIT_LOG_ENABLED=true

# View audit logs
tail -f storage/logs/audit.log

# Search for specific actions
grep "PRODUCTION_DEPLOYMENT" storage/logs/audit.log
grep "APPROVAL" storage/logs/audit.log
grep "ROLLBACK" storage/logs/audit.log
```

---

## Testing and Validation

### Production Smoke Tests

```bash
# Run smoke tests (< 3 minutes)
docker exec agl-hostman-app-blue-1 php artisan test --testsuite=Production

# Expected output: All tests passing
# ✓ application_health_endpoint_returns_healthy
# ✓ database_connection_is_working
# ✓ redis_cache_is_accessible
# ✓ queue_system_is_operational
# ✓ session_storage_is_working
# ✓ environment_is_production
# ✓ ssl_certificate_is_valid
# ✓ load_balancer_is_healthy
# ✓ backup_system_is_configured
# ✓ monitoring_endpoints_are_accessible
# ✓ external_api_integrations_are_working
# ✓ scheduled_jobs_are_configured
# ✓ production_deployment_is_configured
# ✓ error_handling_is_configured
# ✓ security_headers_are_set
# ✓ rate_limiting_is_enabled
```

### Blue-Green Deployment Tests

```bash
# Run integration tests
docker exec agl-hostman-app-blue-1 php artisan test tests/Feature/Production/BlueGreenDeploymentTest.php

# Expected output: All tests passing (15 tests)
```

### Load Testing

```bash
# Install Apache Bench
sudo apt install apache2-utils

# Test with 1000 requests, 10 concurrent
ab -n 1000 -c 10 https://prod-agl.aglz.io/

# Expected:
# Requests per second: > 500
# Time per request: < 20ms (mean)
# Failed requests: 0
```

### Security Scanning

```bash
# Run Trivy vulnerability scan
trivy image harbor.aglz.io:5000/agl-hostman-prod:latest

# Expected: 0 HIGH or CRITICAL vulnerabilities
```

---

## Rollout Checklist

### Pre-Deployment

- [ ] All smoke tests passing
- [ ] Harbor image built and pushed
- [ ] .env.production configured
- [ ] SSL certificates installed
- [ ] DNS records configured
- [ ] Monitoring dashboards configured
- [ ] Backup system tested
- [ ] Disaster recovery plan reviewed
- [ ] Team notified of deployment window

### Deployment

- [ ] Blue environment deployed and healthy
- [ ] Database migrations completed
- [ ] Load balancer configured
- [ ] Monitoring active
- [ ] Alerts configured
- [ ] Smoke tests passing on blue
- [ ] Traffic switched to blue
- [ ] Performance metrics within thresholds

### Post-Deployment

- [ ] Monitor error rates for 1 hour
- [ ] Verify all integrations working
- [ ] Check backup completed successfully
- [ ] Update documentation with actual IPs/domains
- [ ] Send deployment success notification
- [ ] Schedule post-mortem meeting (if issues)

### 30-Day Review

- [ ] Review performance metrics
- [ ] Review error logs
- [ ] Review backup success rate
- [ ] Review security alerts
- [ ] Update runbook with lessons learned
- [ ] Plan capacity upgrades if needed

---

## Troubleshooting

### Common Issues

**Issue**: Load balancer shows 502 Bad Gateway

```bash
# Check application health
curl http://app-blue-1:3000/health
curl http://app-blue-2:3000/health

# Check nginx error log
docker logs agl-hostman-load-balancer

# Restart application if needed
docker compose -f docker-compose.blue.yml restart app-blue-1 app-blue-2
```

**Issue**: Database connection errors

```bash
# Check PostgreSQL is running
docker exec agl-hostman-postgres-primary psql -U postgres -c "SELECT version();"

# Check replication status
docker exec agl-hostman-postgres-primary psql -U postgres -c "SELECT * FROM pg_stat_replication;"

# Restart database if needed
docker compose -f docker-compose.blue.yml restart postgres-primary postgres-replica
```

**Issue**: Redis connection errors

```bash
# Check Redis Sentinel
docker exec agl-hostman-redis-sentinel redis-cli -p 26379 SENTINEL masters

# Check Redis master
docker exec agl-hostman-redis-master redis-cli -a [password] PING

# Restart Redis if needed
docker compose -f docker-compose.blue.yml restart redis-master redis-sentinel
```

**Issue**: Monitoring metrics not showing

```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# Restart Prometheus
docker compose -f docker-compose.lb.yml restart prometheus

# Check exporters
docker ps | grep exporter
```

---

## Support

For production incidents, follow the [PRODUCTION-RUNBOOK.md](PRODUCTION-RUNBOOK.md) escalation procedures.

**Contacts**:
- **On-Call Engineer**: [pagerduty-link]
- **DevOps Team**: ops@agl.com
- **Slack Channel**: #production-support

---

**Document Version**: 1.0.0
**Last Review**: 2025-01-20
**Next Review**: 2025-02-20
