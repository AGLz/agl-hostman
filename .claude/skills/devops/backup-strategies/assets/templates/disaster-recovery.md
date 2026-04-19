# Disaster Recovery Runbook

## Recovery Objectives

| Metric | Target | Current Status |
|--------|--------|----------------|
| **RTO** (Recovery Time Objective) | 4 hours | ✅ Met |
| **RPO** (Recovery Point Objective) | 15 minutes | ✅ Met |
| **Data Retention** | 90 days | ✅ Configured |
| **Backup Frequency** | Hourly (critical), Daily (standard) | ✅ Scheduled |

---

## Emergency Contacts

| Role | Name | Contact | On-Call |
|------|------|---------|---------|
| DevOps Lead | John Doe | +1-555-0101 | ✅ |
| Backend Lead | Jane Smith | +1-555-0102 | ✅ |
| CTO | Admin | admin@example.com | - |

---

## Quick Reference Commands

### Backup Commands
```bash
# Create immediate backup
php artisan db:backup --compress --upload --notify

# List recent backups
php artisan backup:list

# Check backup health
php artisan backup:health-check
```

### Restore Commands
```bash
# Restore from S3 backup
php artisan db:restore backups/database/backup_2024_01_15_143022.sql.gz

# Restore from local backup
php artisan db:restore backup_2024_01_15_143022.sql.gz --local

# Force restore without confirmation
php artisan db:restore backup.sql.gz --force
```

### Maintenance Commands
```bash
# Enable maintenance mode
php artisan down

# Disable maintenance mode
php artisan up

# Check application health
curl https://app.example.com/api/health
```

---

## Disaster Scenarios

### Scenario 1: Database Corruption

**Severity**: HIGH
**Estimated Downtime**: 2-4 hours

**Steps**:
1. **Isolate** (5 min)
   - Enable maintenance mode: `php artisan down`
   - Stop queue workers: `php artisan queue:restart`
   - Document current time for RPO calculation

2. **Assess** (10 min)
   - Identify corruption extent
   - Check last good backup time
   - Calculate data loss window

3. **Restore** (30-60 min)
   - Select appropriate backup (most recent good backup)
   - Run restore: `php artisan db:restore <backup_file>`
   - Monitor restore progress

4. **Validate** (15 min)
   - Run data integrity checks
   - Verify critical tables
   - Test application endpoints

5. **Recover Lost Data** (if needed) (30-60 min)
   - Apply transaction logs if available
   - Re-process from source systems
   - Manual data entry as last resort

6. **Resume** (5 min)
   - Disable maintenance mode: `php artisan up`
   - Restart queue workers
   - Monitor application logs

**Post-Incident**:
- Document root cause
- Update procedures
- Schedule retrospective meeting

---

### Scenario 2: Complete Server Failure

**Severity**: CRITICAL
**Estimated Downtime**: 3-4 hours

**Steps**:
1. **Assess** (5 min)
   - Verify server status
   - Check if data is recoverable from failed server
   - Initiate incident response

2. **Provision New Server** (30-60 min)
   ```bash
   # Using cloud provider CLI
   aws ec2 run-instances \
     --image-id ami-xxxxx \
     --instance-type t3.large \
     --key-name my-key-pair \
     --security-group-ids sg-xxxxx
   ```

3. **Install Dependencies** (15-30 min)
   ```bash
   # Install Docker
   curl -fsSL https://get.docker.com | sh

   # Install Docker Compose
   curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
   chmod +x /usr/local/bin/docker-compose
   ```

4. **Deploy Application** (20-30 min)
   ```bash
   # Clone repository
   git clone https://github.com/yourorg/laravel-app.git
   cd laravel-app

   # Configure environment
   cp .env.production .env
   # Edit .env with production values

   # Start services
   docker-compose up -d
   ```

5. **Restore Database** (30-60 min)
   - Download latest backup from S3
   - Restore database: `php artisan db:restore <backup>`
   - Run migrations: `php artisan migrate --force`

6. **Restore File Storage** (15-30 min)
   - Mount S3 bucket or restore from backup
   - Verify file accessibility
   - Check permissions

7. **Configure SSL** (10 min)
   ```bash
   # Using Certbot
   certbot --nginx -d app.example.com
   ```

8. **Health Checks** (10 min)
   - Test application endpoints
   - Verify database connectivity
   - Check external service integrations
   - Monitor logs for errors

9. **DNS Failover** (if applicable) (5-60 min)
   - Update DNS records
   - Wait for propagation
   - Verify traffic routing

10. **Monitor** (ongoing)
    - Watch application logs
    - Monitor performance metrics
    - Check error rates

---

### Scenario 3: Accidental Data Deletion

**Severity**: MEDIUM-HIGH
**Estimated Downtime**: 1-2 hours

**Steps**:
1. **Stop Application** (Immediate)
   - `php artisan down`
   - Stop all writes to prevent further damage

2. **Identify Scope** (5 min)
   - What was deleted?
   - When was it deleted?
   - Who deleted it? (check logs)

3. **Choose Recovery Strategy**:
   - **Option A**: Restore from backup if deletion > 1 hour ago
   - **Option B**: Apply binary logs to recover to just before deletion
   - **Option C**: Undelete if using soft deletes

4. **Restore** (30-60 min)
   ```bash
   # Point-in-time recovery using binary logs
   mysqlbinlog \
     --start-datetime="2024-01-15 14:00:00" \
     --stop-datetime="2024-01-15 14:30:00" \
     --database=laravel \
     /var/lib/mysql/mysql-bin.000001 | mysql
   ```

5. **Validate** (15 min)
   - Verify deleted data is restored
   - Check referential integrity
   - Test affected features

6. **Resume** (5 min)
   - `php artisan up`
   - Monitor for issues

**Prevention**:
- Implement soft deletes
- Add confirmation prompts for destructive actions
- Regular backups with point-in-time recovery
- Audit logging for data changes

---

### Scenario 4: Ransomware Attack

**Severity**: CRITICAL
**Estimated Downtime**: 8-24 hours

**Steps**:
1. **Isolate** (Immediate)
   - Disconnect affected servers from network
   - Stop all services
   - Preserve forensic evidence

2. **Assess** (30-60 min)
   - Identify affected systems
   - Determine ransomware variant
   - Check if backups are compromised

3. **Report** (If needed)
   - Contact legal counsel
   - Notify authorities (FBI IC3, etc.)
   - Inform stakeholders

4. **Clean and Rebuild** (4-8 hours)
   - Provision clean servers
   - Install from scratch (don't use compromised images)
   - Restore from known-good backups
   - Update all credentials

5. **Validate** (1-2 hours)
   - Scan for malware
   - Verify no backdoors exist
   - Test all functionality

6. **Prevent Future Attacks**
   - Implement 3-2-1 backup rule with offline backups
   - Update security policies
   - Conduct security audit
   - Train staff on phishing awareness

---

## Backup Verification Schedule

| Check Type | Frequency | Owner | Status |
|------------|-----------|-------|--------|
| Automated health check | Hourly | System | ✅ |
| Backup existence check | Daily | DevOps | ✅ |
| Restore test | Weekly | DevOps | ⏳ |
| Full DR drill | Quarterly | All | 📅 Next: Apr 2024 |

---

## Maintenance Windows

| Type | Schedule | Duration | Purpose |
|------|----------|----------|---------|
| System updates | 1st Sunday, 2 AM | 2 hours | OS patches |
| Database maintenance | 3rd Sunday, 2 AM | 4 hours | Optimization |
| Full backup test | Last Friday, 10 PM | 1 hour | Restore verification |

---

## Runbook Maintenance

- **Last Updated**: 2024-01-15
- **Next Review**: 2024-04-15
- **Change Log**:
  - 2024-01-15: Added ransomware scenario
  - 2024-01-10: Updated RTO/RPO targets
  - 2024-01-01: Initial version

---

## Appendix

### Useful URLs
- Application: https://app.example.com
- Monitoring: https://monitor.example.com
- Dashboard: https://grafana.example.com
- S3 Backups: https://s3.console.aws.amazon.com/s3/buckets/backups/

### Server Information
- Production: 10.0.1.10
- Staging: 10.0.2.10
- Database: db.production.internal (3306)
- Redis: redis.production.internal (6379)

---

**Remember**: During a disaster, stay calm, follow procedures, and communicate frequently!
