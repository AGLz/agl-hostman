# AGL Hostman HA Infrastructure - Quick Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying the AGL Hostman High Availability infrastructure.

## Prerequisites

- Proxmox VE 7.x or higher
- Terraform 1.0+
- Docker & Docker Compose
- At least 3 servers with 8GB+ RAM each
- Network: 10.0.0.0/16 subnet available

## Quick Start (Docker Compose)

### 1. Clone Repository

```bash
git clone <repository-url>
cd agl-hostman
```

### 2. Configure Environment

```bash
cp .env.example .env

# Edit .env with your values:
# - Database credentials
# - Redis password
# - HAProxy stats password
# - SSL certificates
```

### 3. Generate SSL Certificates

```bash
# Self-signed (for testing)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout infrastructure/haproxy/ssl/key.pem \
  -out infrastructure/haproxy/ssl/cert.pem

# Or use Let's Encrypt
certbot certonly --standalone -d agl.example.com
```

### 4. Deploy Infrastructure

```bash
cd infrastructure/docker

# Start all services
docker-compose -f docker-compose.ha.yml up -d

# Verify all containers are running
docker-compose -f docker-compose.ha.yml ps
```

### 5. Verify Health

```bash
# Check HAProxy stats (login with admin:password)
curl http://localhost:8404/stats

# Check application health
curl http://localhost/health

# Check MySQL replication
docker exec agl-hostman-mysql-slave-1 mysql -e "SHOW SLAVE STATUS\G"

# Check Redis Sentinel
docker exec agl-hostman-redis-sentinel-1 redis-cli -p 26379 SENTINEL masters
```

## Terraform Deployment (Proxmox)

### 1. Configure Terraform

```bash
cd infrastructure/terraform/environments/production

# Edit variables
cp terraform.tfvars.example terraform.tfvars
# Edit with your Proxmox credentials and network settings
```

### 2. Initialize Terraform

```bash
terraform init
terraform fmt
terraform validate
```

### 3. Plan Deployment

```bash
terraform plan -out=tfplan
# Review the plan carefully
```

### 4. Deploy Infrastructure

```bash
terraform apply tfplan
```

### 5. Configure DNS

```bash
# Add A records for:
# - agl.example.com -> LB VIP (10.0.0.10)
# - api.agl.example.com -> LB VIP (10.0.0.10)
# - db.agl.example.com -> MySQL master (10.0.2.10)
# - redis.agl.example.com -> Redis master (10.0.3.10)
```

## Configuration Files

### HAProxy

Location: `/infrastructure/haproxy/haproxy.cfg`

Key settings:
- Backend servers: 10.0.1.10-12 (app nodes)
- MySQL servers: 10.0.2.20-21 (read replicas)
- Redis servers: 10.0.3.10-13 (cache cluster)

### MySQL Master

Location: `/infrastructure/mysql-replication/my-master.cnf`

Key settings:
- Server ID: 1
- GTID mode: ON
- Binlog format: ROW
- Semi-sync replication: enabled

### MySQL Slave

Location: `/infrastructure/mysql-replication/my-slave.cnf`

Key settings:
- Server ID: 2/3 (each slave unique)
- Read-only: ON
- Parallel workers: 4

### Redis Sentinel

Location: `/infrastructure/redis-sentinel/sentinel.conf`

Key settings:
- Quorum: 2
- Down-after: 5000ms
- Failover-timeout: 10000ms

## Health Checks

### Automated Health Check

```bash
# Run comprehensive health check
./infrastructure/monitoring/health-check.sh

# Expected output:
# {
#   "app": "healthy",
#   "api": "healthy",
#   "mysql": "healthy",
#   "redis": "healthy",
#   "haproxy": "healthy",
#   "overall_status": "healthy"
# }
```

### Service-Specific Checks

```bash
# HAProxy
curl http://localhost:8404/stats; csv

# MySQL
mysqladmin -h 10.0.2.10 ping

# Redis
redis-cli -h 10.0.3.10 ping

# Application
curl http://localhost/api/health
```

## Failover Testing

### Test Application Failover

```bash
# Stop one app node
docker stop agl-hostman-app-blue-1

# Verify traffic redirects to other nodes
curl http://localhost/health

# Check HAProxy stats (node marked as DOWN)
curl http://localhost:8404/stats; csv | grep app-blue-1
```

### Test Database Failover

```bash
# Trigger manual failover
./infrastructure/scripts/mysql-failover.sh failover

# Verify new master
mysql -h 10.0.2.20 -e "SHOW MASTER STATUS;"

# Update application config
# Script handles automatically
```

### Test Redis Failover

```bash
# Stop Redis master
docker stop agl-hostman-redis-master

# Verify Sentinel promotes slave (should take < 10s)
docker exec agl-hostman-redis-sentinel-1 redis-cli -p 26379 \
  SENTINEL get-master-addr-by-name mymaster
```

## Monitoring

### Access Grafana

```
URL: http://localhost:3000
Username: admin
Password: [from .env]
```

### Key Dashboards

1. **HA Overview**: Overall system health
2. **Application Performance**: Response times, error rates
3. **Database Replication**: Lag, status
4. **Cache Performance**: Hit rates, memory usage

### Prometheus Metrics

```
http://localhost:9090
```

Key queries:
- `up`: Service availability
- `mysql_slave_status`: Replication status
- `redis_up`: Redis health
- `haproxy_backend_status`: LB backend status

## Scaling

### Add Application Node

```bash
# Edit docker-compose.ha.yml
# Add new app-blue-3 service

# Or use Terraform
terraform apply -var='app_node_count=4'

# LB automatically includes new node
```

### Add MySQL Slave

```bash
# Add new slave to Terraform config
# Apply changes

# Configure replication on new slave
mysql -h [new_slave] -e "CHANGE MASTER TO ..."
```

### Add Redis Slave

```bash
# Add new redis-slave-4 to docker-compose
# Update Sentinel config
# Restart Sentinel
```

## Backup and Recovery

### Database Backup

```bash
# Daily backup (configured in cron)
0 2 * * * /usr/local/bin/mysql-backup.sh

# Manual backup
mysqldump -h 10.0.2.10 -u root -p \
  --single-transaction --routines --triggers \
  agl_hostman > backup.sql
```

### Restore Database

```bash
# Stop application
docker-compose -f docker-compose.ha.yml stop app

# Restore from backup
mysql -h 10.0.2.10 -u root -p agl_hostman < backup.sql

# Restart application
docker-compose -f docker-compose.ha.yml start app
```

## Troubleshooting

### HAProxy Not Starting

```bash
# Check configuration
haproxy -c -f /etc/haproxy/haproxy.cfg

# Check logs
tail -f /var/log/haproxy.log
```

### MySQL Replication Broken

```bash
# Check slave status
mysql -h 10.0.2.20 -e "SHOW SLAVE STATUS\G"

# Common issues:
# - Connection errors: Check network
# - Authentication: Verify replication user
# - Duplicate keys: Skip error (if safe)
```

### Redis Sentinel Not Failing Over

```bash
# Check Sentinel configuration
redis-cli -p 26379 SENTINEL masters

# Check quorum
redis-cli -p 26379 SENTINEL ckquorum mymaster

# Manual failover
redis-cli -p 26379 SENTINEL failover mymaster
```

## Security

### Firewall Rules

```bash
# Allow traffic only on necessary ports
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow from 10.0.0.0/16 to any port 3306
ufw allow from 10.0.0.0/16 to any port 6379
```

### SSL/TLS

```bash
# Enable SSL on HAProxy
# Edit haproxy.cfg
# Add SSL certificates
# Redirect HTTP to HTTPS
```

### Secrets Management

```bash
# Use Docker secrets
echo "password" | docker secret create mysql_password -

# Or use environment file
chmod 600 .env
```

## Maintenance

### Rolling Updates

```bash
# Update application
1. Deploy to green environment
2. Test green environment
3. Shift 10% traffic to green
4. Monitor for errors
5. Gradually increase to 100%
6. Keep blue for rollback
7. Decommission blue
```

### Database Maintenance

```bash
# Optimize tables
mysql -h 10.0.2.10 -e "OPTIMIZE TABLE agl_hostman.*;"

# Check for errors
mysqlcheck -h 10.0.2.10 --all-databases

# Update statistics
mysql -h 10.0.2.10 -e "ANALYZE TABLE agl_hostman.*;"
```

## Support

### Documentation

- Architecture: `/docs/ha-infrastructure/HA-ARCHITECTURE.md`
- Failover: `/docs/ha-infrastructure/FAILOVER-RUNBOOK.md`
- This guide: `/docs/ha-infrastructure/DEPLOYMENT-GUIDE.md`

### Logs

- HAProxy: `/var/log/haproxy.log`
- MySQL: `/var/log/mysql/error.log`
- Redis: `/var/log/redis/redis-server.log`
- Application: `/var/log/agl-hostman/app.log`

### Contacts

- DevOps Lead: [email]
- On-Call: [phone/slack]

## Checklist

Before going to production:

- [ ] All environment variables configured
- [ ] SSL certificates installed
- [ ] Firewall rules configured
- [ ] DNS records created
- [ ] Backup jobs configured
- [ ] Monitoring dashboards created
- [ ] Alert rules configured
- [ ] Failover tested
- [ ] Documentation reviewed
- [ ] Team trained on runbook

---

**Deployment Time**: ~30 minutes
**Complexity**: Medium
**Requirements**: Docker Compose or Terraform
