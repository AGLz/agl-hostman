# Offsite Backup Replication System

Complete disaster recovery solution for AGL infrastructure with encrypted offsite backup replication.

## Overview

This system provides:
- **Encrypted backup replication** to offsite storage (Backblaze B2, Hetzner Storage)
- **Automated monitoring** with health checks and alerts
- **GPG encryption** for backups at rest and in transit
- **Bandwidth-efficient** incremental transfers
- **Comprehensive testing** procedures for DR validation

## Components

### Scripts

| Script | Purpose |
|--------|---------|
| `backup-replication.sh` | Main replication script for offsite backups |
| `setup-gpg-backup-keys.sh` | GPG key generation and management |
| `monitor-replication.sh` | Health monitoring and alerting |
| `test-dr-restoration.sh` | Automated DR testing procedures |

### Configuration

| File | Purpose |
|------|---------|
| `replication-config.env` | Main configuration file |
| `replication-config.env.example` | Configuration template |

## Quick Start

### 1. Prerequisites

```bash
# Install required packages
apt-get update
apt-get install -y rclone rsync gpg pigz mailutils curl

# For Proxmox systems
apt-get install -y proxmox-backup-client pve-manager

# For database systems
apt-get install -y postgresql-client mariadb-client
```

### 2. Generate GPG Keys

```bash
./setup-gpg-backup-keys.sh

# Or in batch mode
./setup-gpg-backup-keys.sh --batch --export --backup
```

### 3. Configure Replication

```bash
# Copy configuration template
cp replication-config.env.example replication-config.env

# Edit configuration
nano replication-config.env

# Set proper permissions
chmod 600 replication-config.env
```

### 4. Configure Offsite Storage

#### Backblaze B2 (using rclone)

```bash
# Configure rclone
rclone config

# Create new remote named "agl-hostman-backups"
# Select B2 as storage type
# Enter your B2 Account ID and Application Key

# Test connection
rclone lsd agl-hostman-backups:
```

#### Hetzner Storage Box

```bash
# Add SSH key to Hetzner Storage Box
ssh-copy-id -p 23 uXXXXXX@uXXXXXX.your-storagebox.de

# Test connection
ssh -p 23 uXXXXXX@uXXXXXX.your-storagebox.de "ls -lh"
```

### 5. Run Initial Replication

```bash
# Dry run to see what would be replicated
./backup-replication.sh --dry-run

# Run actual replication
./backup-replication.sh

# Verify replication
./backup-replication.sh --verify
```

## Usage

### Manual Replication

```bash
# Full replication
./backup-replication.sh

# Dry run
./backup-replication.sh --dry-run

# Verify only
./backup-replication.sh --verify

# Test restore
./backup-replication.sh --test-restore
```

### Monitoring

```bash
# Health check
./monitor-replication.sh

# JSON output
./monitor-replication.sh --json

# Prometheus metrics
./monitor-replication.sh --prometheus

# Send email report
./monitor-replication.sh --email
```

### Testing

```bash
# Full DR test
./test-dr-restoration.sh

# Quick smoke test
./test-dr-restoration.sh --quick

# Database restore test
./test-dr-restoration.sh --database

# Offsite download test
./test-dr-restoration.sh --offsite
```

## Automation

### Cron Jobs

Add to crontab (`crontab -e`):

```bash
# Daily replication at 3 AM
0 3 * * * /path/to/backup-replication.sh

# Health check every 15 minutes
*/15 * * * * /path/to/monitor-replication.sh

# Full health check every 6 hours with email
0 */6 * * * /path/to/monitor-replication.sh --email

# Weekly restore test (Sunday 5 AM)
0 5 * * 0 /path/to/test-dr-restoration.sh --quick
```

### Systemd Timer (Alternative)

Create `/etc/systemd/system/backup-replication.service`:

```ini
[Unit]
Description=Offsite Backup Replication
After=network.target

[Service]
Type=oneshot
ExecStart=/path/to/backup-replication.sh
Nice=19
IOSchedulingClass=idle
IOSchedulingPriority=7
```

Create `/etc/systemd/system/backup-replication.timer`:

```ini
[Unit]
Description=Daily Backup Replication
Requires=backup-replication.service

[Timer]
OnCalendar=*-*-* 03:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

Enable and start:

```bash
systemctl enable backup-replication.timer
systemctl start backup-replication.timer
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     LOCAL INFRASTRUCTURE                      │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   AGLSRV1    │  │   FGSRV07    │  │   FGSRV06    │      │
│  │  (Proxmox)   │  │  (Proxmox)   │  │  (NFS Store) │      │
│  │              │  │              │  │              │      │
│  │ /spark/base  │  │  /var/lib/vz │  │  /exports    │      │
│  │     /dump    │  │    /backups  │  │              │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                 │                 │                │
│         └─────────┬───────┴─────────────────┘                │
│                   │                                          │
│           ┌───────▼────────┐                                │
│           │   GPG          │                                │
│           │  Encryption    │                                │
│           └───────┬────────┘                                │
└───────────────────┼──────────────────────────────────────────┘
                    │
                    │ Encrypted Transfer
                    │
┌───────────────────┼──────────────────────────────────────────┐
│                   ▼                     OFFSITE STORAGE       │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                   Backblaze B2                         │   │
│  │              (Cloud Object Storage)                    │   │
│  │                    agl-hostman-backups                 │   │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐               │   │
│  │  │ daily/  │  │ weekly/ │  │ monthly/ │               │   │
│  │  └─────────┘  └─────────┘  └─────────┘               │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                Hetzner Storage Box                    │   │
│  │             (Offsite VPS Storage)                     │   │
│  │              uXXXXXX.your-storagebox.de               │   │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐               │   │
│  │  │ daily/  │  │ weekly/ │  │ proxmox/ │               │   │
│  │  └─────────┘  └─────────┘  └─────────┘               │   │
│  └──────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
```

## Security

### Encryption

- **At Rest**: AES-256 via GPG
- **In Transit**: TLS 1.3 for B2, SSH for Hetzner
- **Key Management**: Local GPG keys with offline backup

### Access Control

- Configuration files: 600 permissions
- Backup directories: 750 permissions
- SSH keys: passphrase-protected

### Best Practices

1. Store GPG private key offline (USB drive, safe deposit box)
2. Use different keys for encryption and signing
3. Rotate keys annually
4. Test restore procedures quarterly

## Monitoring

### Metrics

Track these metrics:

| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| Backup Age | < 26 hours | > 26 hours |
| Replication Time | < 2 hours | > 2 hours |
| Disk Space | > 100 GB | < 100 GB |
| Offsite Connectivity | 100% | < 95% |

### Alerts

Configure notifications in `replication-config.env`:

```bash
ALERT_EMAIL="ops@yourcompany.com"
SLACK_WEBHOOK="https://hooks.slack.com/services/..."
```

### Logs

```bash
# View replication logs
tail -f /var/log/backup-replication/replication-*.log

# View monitoring logs
tail -f /var/log/backup-replication/alerts.log

# View DR test logs
tail -f /var/log/dr-tests/test-execution.log
```

## Troubleshooting

### Issue: Replication fails with authentication error

**Solution**:
```bash
# Verify rclone configuration
rclone config show agl-hostman-backups

# Test B2 connection
rclone lsd agl-hostman-backups:

# Update credentials if needed
rclone config
```

### Issue: GPG encryption fails

**Solution**:
```bash
# Check GPG key availability
gpg --list-keys

# Verify key expiration
gpg --list-keys --with-colons | grep -e "^pub"

# Re-import key if needed
./setup-gpg-backup-keys.sh --restore backup-file.tar.gz.gpg
```

### Issue: Offsite storage unreachable

**Solution**:
```bash
# Test B2 connectivity
ping s3.us-west-001.backblazeb2.com

# Test Hetzner connectivity
ssh -p 23 -v uXXXXXX@uXXXXXX.your-storagebox.de

# Check firewall rules
ufw status
```

### Issue: Restore test fails

**Solution**:
```bash
# Verify backup integrity
gzip -t /path/to/backup.gz

# Check GPG decryption
gpg --decrypt /path/to/backup.gz.gpg > /tmp/test.gz

# Test database restore manually
docker run -d --name test-postgres -e POSTGRES_PASSWORD=test postgres:16-alpine
gunzip -c /path/to/backup.gz | docker exec -i test-postgres psql -U postgres
```

## Maintenance

### Daily
- Review replication logs for errors
- Check disk space usage
- Verify monitoring alerts

### Weekly
- Review bandwidth usage
- Check backup retention compliance
- Test restore from offsite (random file)

### Monthly
- Review and rotate logs
- Update documentation if changes occurred
- Review cost analysis

### Quarterly
- Full disaster recovery test
- Restore validation
- Documentation update
- Security audit

## Cost Optimization

### Current Configuration

| Storage | Monthly | Annual |
|---------|---------|--------|
| Backblaze B2 (400 GB) | $2.40 | $28.80 |
| Hetzner Storage (1 TB) | $5.85 | $70.20 |
| **Total** | **$8.25** | **$99.00** |

### Optimization Tips

1. Use lifecycle policies for old backups
2. Enable compression before upload
3. Use incremental transfers
4. Consider B2's "Hot" vs "Cool" storage tiers
5. Monitor and remove duplicate backups

## Support

### Documentation

- [Disaster Recovery Runbook](/docs/disaster-recovery-runbook.md)
- [Offsite Storage Evaluation](/docs/offsite-storage-evaluation.md)
- [Backup Retention Policy](/docs/BACKUP_RETENTION_POLICY.md)

### Getting Help

- Infrastructure: ops@agl.local
- Documentation: /mnt/overpower/apps/dev/agl/agl-hostman/docs/
- Logs: /var/log/backup-replication/

## License

Internal use - AGL Infrastructure Team

---

**Last Updated**: 2026-02-10
**Version**: 1.0
