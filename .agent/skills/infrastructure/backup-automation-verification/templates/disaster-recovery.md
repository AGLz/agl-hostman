# Disaster Recovery Runbook

**Last Updated:** {DATE}
**Version:** {VERSION}
**Owner:** {OWNER}

---

## Executive Summary

This document outlines the disaster recovery procedures for {APPLICATION_NAME}. It provides step-by-step instructions for recovering from various failure scenarios to minimize downtime and data loss.

### Recovery Objectives

| Metric | Target | Current Status |
|--------|--------|----------------|
| **RTO** (Recovery Time Objective) | 4 hours | {CURRENT_RTO} |
| **RPO** (Recovery Point Objective) | 15 minutes | {CURRENT_RPO} |

---

## Table of Contents

1. [Roles and Responsibilities](#roles-and-responsibilities)
2. [Pre-Recovery Checklist](#pre-recovery-checklist)
3. [Recovery Scenarios](#recovery-scenarios)
4. [Post-Recovery Verification](#post-recovery-verification)
5. [Communication Plan](#communication-plan)
6. [Contact Information](#contact-information)

---

## Roles and Responsibilities

| Role | Name | Contact | Responsibilities |
|------|------|---------|------------------|
| Incident Commander | {INCIDENT_COMMANDER} | {CONTACT} | Overall coordination, decision making |
| Database Lead | {DB_LEAD} | {CONTACT} | Database restoration, data verification |
| DevOps Lead | {DEVOPS_LEAD} | {CONTACT} | Infrastructure recovery, service restoration |
| Application Lead | {APP_LEAD} | {CONTACT} | Application deployment, functionality testing |
| Communications | {COMM Lead} | {CONTACT} | Stakeholder notifications, status updates |

---

## Pre-Recovery Checklist

Before starting any recovery procedure, complete this checklist:

- [ ] Declare incident and notify team
- [ ] Identify failure scope and impact
- [ ] Assign roles and responsibilities
- [ ] Establish communication channels (Slack, phone bridge)
- [ ] Document start time
- [ ] Check available backups (location, age, integrity)
- [ ] Prepare recovery environment
- [ ] Notify stakeholders of expected downtime

---

## Recovery Scenarios

### Scenario 1: Database Corruption

**Severity:** HIGH
**Estimated Recovery Time:** 1-2 hours

#### Detection Symptoms
- Application errors: "Database connection failed"
- Database queries failing or returning errors
- InnoDB corruption errors in logs

#### Recovery Steps

1. **Stop Application Traffic**
   ```bash
   # Enable maintenance mode
   php artisan down

   # Or put load balancer in maintenance
   ```
   - Estimated Time: 2 minutes
   - Responsible: DevOps Lead

2. **Identify Last Good Backup**
   ```bash
   # List available backups
   ls -lht /var/backups/database/ | head -20

   # Verify backup integrity
   /usr/local/bin/backup-verify.sh --path <backup-file>
   ```
   - Estimated Time: 5 minutes
   - Responsible: Database Lead

3. **Stop Database Service**
   ```bash
   systemctl stop mysql
   # or
   systemctl stop postgresql
   ```
   - Estimated Time: 1 minute
   - Responsible: Database Lead

4. **Restore Database**
   ```bash
   # For MySQL
   /usr/local/bin/restore-database.sh /var/backups/database/<backup-file>

   # For PostgreSQL
   pg_restore -h localhost -U postgres -d template1 -j 4 <backup-file>

   # For SQLite
   cp <backup-file> /var/www/html/database/database.sqlite
   ```
   - Estimated Time: 15-30 minutes (depends on size)
   - Responsible: Database Lead

5. **Verify Data Integrity**
   ```bash
   # Run database integrity checks
   mysqlcheck -u root -p --all-databases

   # Check row counts for critical tables
   ```

6. **Start Database Service**
   ```bash
   systemctl start mysql
   ```

7. **Run Migrations**
   ```bash
   php artisan migrate --force
   ```

8. **Disable Maintenance Mode**
   ```bash
   php artisan up
   ```

9. **Verify Application**
   - Smoke tests
   - Critical user flows
   - API health checks

---

### Scenario 2: Complete Server Failure

**Severity:** CRITICAL
**Estimated Recovery Time:** 2-4 hours

#### Detection Symptoms
- Server unreachable (ping fails)
- No response to SSH
- Monitoring alerts: "Host down"

#### Recovery Steps

1. **Assess Failure**
   ```bash
   # Attempt remote access
   ssh admin@{SERVER_IP}

   # Check from monitoring
   # Check with hosting provider
   ```
   - Estimated Time: 5-10 minutes
   - Responsible: DevOps Lead

2. **Provision New Server**
   ```bash
   # Using cloud provider CLI
   aws ec2 run-instances --image-id ami-xxx --instance-type t3.large

   # Using Proxmox
   pct create <vmid> local:vztmpl/ubuntu-template.tar.gz

   # Using Docker
   docker-compose up -d
   ```
   - Estimated Time: 10-20 minutes
   - Responsible: DevOps Lead

3. **Install Dependencies**
   ```bash
   # Install required packages
   apt update
   apt install -y nginx mysql-server php8.2-fpm redis-server

   # Install Docker if needed
   curl -fsSL https://get.docker.com | sh
   ```
   - Estimated Time: 10-15 minutes
   - Responsible: DevOps Lead

4. **Deploy Application Code**
   ```bash
   # Clone repository
   git clone {REPO_URL} /var/www/html

   # Or pull from Docker registry
   docker pull {IMAGE}:latest
   ```
   - Estimated Time: 5 minutes
   - Responsible: Application Lead

5. **Configure Environment**
   ```bash
   # Copy .env from secure storage
   # Or reconstruct from documentation
   cp .env.example .env
   nano .env
   php artisan key:generate
   ```
   - Estimated Time: 5-10 minutes
   - Responsible: Application Lead

6. **Restore Database**
   - Follow database restoration steps from Scenario 1
   - Estimated Time: 30-60 minutes
   - Responsible: Database Lead

7. **Restore File Storage**
   ```bash
   # Download from S3
   aws s3 sync s3://{BUCKET}/files/ /var/www/html/storage/app/

   # Or restore from backup
   tar -xzf /var/backups/files/latest.tar.gz -C /var/www/html/
   ```
   - Estimated Time: 15-30 minutes
   - Responsible: DevOps Lead

8. **Configure SSL**
   ```bash
   # Install Certbot
   apt install certbot python3-certbot-nginx

   # Get certificate
   certbot --nginx -d {DOMAIN}
   ```
   - Estimated Time: 5 minutes
   - Responsible: DevOps Lead

9. **Update DNS** (if IP changed)
   ```bash
   # Update DNS A record
   # Or update load balancer configuration
   ```
   - Estimated Time: 5-30 minutes (propagation time)
   - Responsible: DevOps Lead

10. **Health Checks**
    ```bash
    # Application health
    curl https://{DOMAIN}/health

    # Database connectivity
    php artisan tinker
    >>> DB::connection()->getPdo();

    # Redis connectivity
    redis-cli ping
    ```
    - Estimated Time: 5 minutes
    - Responsible: Application Lead

---

### Scenario 3: Accidental Data Deletion

**Severity:** HIGH
**Estimated Recovery Time:** 1-2 hours

#### Detection Symptoms
- User reports missing data
- Application errors for specific records
- Audit log shows deletion activity

#### Recovery Steps

1. **STOP APPLICATION IMMEDIATELY**
   ```bash
   php artisan down
   ```
   - Estimated Time: 1 minute
   - Responsible: Incident Commander

2. **Identify Deletion Time**
   ```bash
   # Check application logs
   tail -f /var/www/html/storage/logs/laravel.log

   # Check audit logs
   grep "DELETE" /var/log/audit.log

   # Check database binary logs (MySQL)
   mysqlbinlog /var/lib/mysql/mysql-bin.000001 | grep -i delete
   ```
   - Estimated Time: 5-10 minutes
   - Responsible: Database Lead

3. **Select Recovery Point**
   - Choose backup just before deletion
   - Consider using point-in-time recovery
   - Estimated Time: 5 minutes
   - Responsible: Incident Commander

4. **Restore Backup**
   - Follow database restoration steps
   - Estimated Time: 30-60 minutes
   - Responsible: Database Lead

5. **Apply Binary Logs** (for MySQL PITR)
   ```bash
   # Apply changes up to just before deletion
   mysqlbinlog \
     --start-datetime="{BACKUP_TIME}" \
     --stop-datetime="{DELETION_TIME}" \
     /var/lib/mysql/mysql-bin.000001 | mysql
   ```
   - Estimated Time: 10-20 minutes
   - Responsible: Database Lead

6. **Verify Recovered Data**
   - Check for deleted records
   - Verify data integrity
   - Run consistency checks
   - Estimated Time: 10 minutes
   - Responsible: Application Lead

7. **Resume Application**
   ```bash
   php artisan up
   ```
   - Responsible: Incident Commander

---

### Scenario 4: Ransomware Attack

**Severity:** CRITICAL
**Estimated Recovery Time:** 4-8 hours

#### Detection Symptoms
- Files encrypted with strange extensions
- Ransom notes in directories
- Application displaying ransom message

#### Recovery Steps

1. **ISOLATE INFECTED SYSTEMS**
   ```bash
   # Disconnect from network
   ifdown eth0

   # Stop all services
   systemctl stop nginx mysql redis
   ```
   - IMMEDIATE ACTION
   - Responsible: Incident Commander

2. **ASSESS DAMAGE**
   - Identify affected systems
   - Determine encryption scope
   - Check if backups are compromised
   - Estimated Time: 15-30 minutes
   - Responsible: DevOps Lead, Security Team

3. **INCIDENT RESPONSE**
   - Notify security team
   - Contact legal if needed
   - Document everything for forensics
   - Estimated Time: Ongoing
   - Responsible: Incident Commander

4. **PROVISION CLEAN INFRASTRUCTURE**
   - Use fresh servers/images
   - Change all credentials
   - Rotate SSH keys
   - Estimated Time: 30-60 minutes
   - Responsible: DevOps Lead

5. **RESTORE FROM OFFLINE BACKUPS**
   - Use backups not connected during attack
   - Verify backups are clean before restoring
   - Estimated Time: 1-2 hours
   - Responsible: Database Lead

6. **SCAN FOR VULNERABILITIES**
   - Run security scans
   - Patch all vulnerabilities
   - Update all software
   - Estimated Time: 1-2 hours
   - Responsible: Security Team

7. **ENHANCE SECURITY**
   - Implement additional monitoring
   - Add security layers
   - Review access controls
   - Estimated Time: Ongoing
   - Responsible: Security Team

8. **RESUME OPERATIONS**
   - Gradual rollout
   - Monitor for suspicious activity
   - Estimated Time: 1-2 hours
   - Responsible: Incident Commander

---

## Post-Recovery Verification

After any recovery scenario, complete these verification steps:

### Application Verification

```bash
# Health check endpoint
curl https://{DOMAIN}/api/health

# Critical API endpoints
curl https://{DOMAIN}/api/v1/status
curl https://{DOMAIN}/api/v1/users/check

# Database connectivity
php artisan db:show

# Cache connectivity
php artisan cache:clear
redis-cli ping
```

### Data Verification

```bash
# Row counts for critical tables
mysql -e "SELECT COUNT(*) FROM users;"
mysql -e "SELECT COUNT(*) FROM orders;"
mysql -e "SELECT COUNT(*) FROM products;"

# Recent data checks
mysql -e "SELECT COUNT(*) FROM orders WHERE created_at > NOW() - INTERVAL 24 HOUR;"
```

### Performance Verification

```bash
# Response time check
time curl https://{DOMAIN}/api/health

# Load test
ab -n 100 -c 10 https://{DOMAIN}/api/health

# Check resource usage
top -bn1 | head -20
df -h
```

### Security Verification

```bash
# Check for unauthorized users
mysql -e "SELECT * FROM users WHERE role = 'admin' AND created_at > NOW() - INTERVAL 1 DAY;"

# Check for suspicious processes
ps aux

# Check log for suspicious activity
tail -100 /var/www/html/storage/logs/laravel.log | grep -i error
```

---

## Communication Plan

### Internal Communication

| Audience | Channel | Frequency | Content |
|----------|---------|-----------|---------|
| Engineering Team | Slack #incidents | Every 15 min | Status updates, blockers |
| Management | Email/Slack | Every 30 min | Business impact, ETA |
| Support Team | Slack #support | Hourly | Customer impact status |

### External Communication

| Audience | Channel | Trigger | Content |
|----------|---------|---------|---------|
| Customers | Status Page | Immediate | Incident acknowledgment |
| Customers | Status Page | Every hour | Progress update |
| Customers | Status Page | Resolved | Resolution summary |

### Status Page Templates

**Initial Incident:**
```
{TIMESTAMP} - We are currently experiencing issues with {SERVICE_NAME}. Users may experience {SYMPTOMS}. Our team is investigating and we will provide updates shortly.
```

**Update:**
```
{TIMESTAMP} - Update: We are working on {RECOVERY_ACTION}. We expect service to be restored within {TIMEFRAME}. Thank you for your patience.
```

**Resolved:**
```
{TIMESTAMP} - Resolved: The issue has been fixed and {SERVICE_NAME} is operating normally. We apologize for any inconvenience.
```

---

## Contact Information

### Primary Contacts

| Role | Name | Phone | Email |
|------|------|-------|-------|
| On-Call DevOps | {ON_CALL_DEVOPS} | {PHONE} | {EMAIL} |
| Database Lead | {DB_LEAD} | {PHONE} | {EMAIL} |
| Application Lead | {APP_LEAD} | {PHONE} | {EMAIL} |
| Engineering Manager | {ENG_MGR} | {PHONE} | {EMAIL} |

### External Contacts

| Service | Contact | Purpose |
|---------|---------|---------|
| Hosting Provider | {HOSTING_SUPPORT} | Server issues |
| Cloud Provider | {CLOUD_SUPPORT} | Infrastructure issues |
| Security Team | {SECURITY_TEAM} | Security incidents |
| Legal | {LEGAL_CONTACT} | Legal requirements |

### Emergency Services

| Service | Number |
|---------|--------|
| Emergency Phone Bridge | {PHONE_BRIDGE} |
| Incident Response Hotline | {HOTLINE} |

---

## Appendix

### Quick Reference Commands

```bash
# Put application in maintenance mode
php artisan down

# Take application out of maintenance mode
php artisan up

# Check recent backups
ls -lht /var/backups/database/ | head -10

# Restore database
/usr/local/bin/restore-database.sh <backup-file>

# Check service status
systemctl status nginx mysql redis

# View recent logs
tail -f /var/www/html/storage/logs/laravel.log

# Check disk space
df -h

# Check memory usage
free -m

# Check CPU usage
top -bn1 | head -20
```

### Backup Locations

```
Local Database Backups:  /var/backups/database/
Local File Backups:      /var/backups/files/
S3 Database Backups:     s3://{BUCKET}/database/
S3 File Backups:         s3://{BUCKET}/files/
Off-site Backup:         {OFFSITE_LOCATION}
```

### Important Files

```
Application Directory:   /var/www/html
Environment File:        /var/www/html/.env
Database Config:         /var/www/html/config/database.php
Web Server Config:       /etc/nginx/sites-available/
SSL Certificates:        /etc/letsencrypt/live/{DOMAIN}/
```

---

**Document Control:**
- **Author:** {AUTHOR}
- **Approved By:** {APPROVER}
- **Version:** {VERSION}
- **Last Review:** {REVIEW_DATE}
- **Next Review:** {NEXT_REVIEW_DATE}

---

*This document should be reviewed and updated quarterly or after any major incident.*
