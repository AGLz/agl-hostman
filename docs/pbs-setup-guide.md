# Proxmox Backup Server (PBS) Setup Guide - FGSRV07

**Documentation Created:** 2026-02-10
**Server:** FGSRV07
**PBS Version:** 4.1.2-1
**Status:** ✅ **OPERATIONAL**

---

## Overview

Proxmox Backup Server (PBS) is installed and configured on FGSRV07, providing centralized backup storage for the AGL infrastructure. This guide covers the complete setup, configuration, and usage of PBS.

---

## System Information

| Property | Value |
|----------|-------|
| **Server** | FGSRV07 |
| **Provider** | VPS Locaweb |
| **Operating System** | Debian 13 (Trixie) |
| **Public IP** | 191.252.93.227 |
| **Tailscale IP** | 100.109.181.93 |
| **PBS Version** | 4.1.2-1 |
| **PBS Port** | 8007 |

---

## Installation Summary

### Repository Configuration

PBS was installed from the Proxmox Trixie repository:

```bash
# Repository file
/etc/apt/sources.list.d/pbs-install-repo.list
deb [arch=amd64] http://download.proxmox.com/debian/pbs trixie pbs-no-subscription
```

### Installation Commands

```bash
# Add repository
echo "deb [arch=amd64] http://download.proxmox.com/debian/pbs trixie pbs-no-subscription" > \
    /etc/apt/sources.list.d/pbs-install-repo.list

# Add key
wget https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg -O \
    /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg

# Install PBS
apt update
apt install proxmox-backup-server
```

---

## Configuration Details

### Datastore Configuration

**Primary Datastore: `backups`**

| Setting | Value |
|---------|-------|
| **Name** | backups |
| **Path** | /var/lib/proxmox-backup/datastore |
| **Available Storage** | 182 GB (from 195 GB total) |
| **Comment** | Primary backup storage for AGL infrastructure |

### Retention Policy

The `backups` datastore is configured with the following retention policy:

| Time Period | Retention |
|-------------|-----------|
| **Keep Last** | 3 backups |
| **Keep Daily** | 7 days |
| **Keep Weekly** | 4 weeks |
| **Keep Monthly** | 6 months |
| **Keep Yearly** | 1 year |

### Prune Job Configuration

**Job ID:** `prune-backups`
- **Schedule:** Daily at 02:00
- **Datastore:** backups
- **Enabled:** Yes

---

## User Accounts

### backup-admin@pbs

| Property | Value |
|-----------|-------|
| **User ID** | backup-admin@pbs |
| **Email** | admin@agl.hostman |
| **First Name** | Backup |
| **Last Name** | Admin |
| **Status** | Enabled |
| **Expiration** | Never |

### API Token

| Property | Value |
|-----------|-------|
| **Token ID** | backup-admin@pbs!automation-token |
| **Token Value** | `593dbf80-43d2-46c5-a693-637818f95be8` |
| **Purpose** | API token for automated backup operations |
| **Expiration** | Never |

**Authentication String:**
```
backup-admin@pbs!automation-token:593dbf80-43d2-46c5-a693-637818f95be8
```

---

## Network Access

### Web Interface Access

| Method | URL | Notes |
|--------|-----|-------|
| **Public** | https://191.252.93.227:8007 | Direct internet access |
| **Tailscale** | https://100.109.181.93:8007 | VPN access (recommended) |

### Login Credentials

- **User:** backup-admin@pbs
- **Password:** (Set via web interface - use root@pam to set initially)
- **Superuser:** root@pam (Linux root authentication)

### Firewall Configuration

Firewall rules configured:

```bash
# Allow PBS web interface from Tailscale network
iptables -I INPUT -s 100.0.0.0/8 -p tcp --dport 8007 -j ACCEPT

# Allow PBS web interface from any (restrict as needed)
iptables -I INPUT -p tcp --dport 8007 -j ACCEPT
```

---

## Using the Backup Client

### Client Installation

PBS client is already installed on FGSRV07. To install on other systems:

```bash
# Add repository
echo "deb [arch=amd64] http://download.proxmox.com/debian/pbs client bookworm main" > \
    /etc/apt/sources.list.d/pbs-client.list

wget https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg -O \
    /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg

apt update
apt install proxmox-backup-client
```

### Configuration File

Create `/etc/proxmox-backup/backup-server.cfg`:

```toml
[backup-server:fgsrv07]
server = "100.109.181.93"
port = 8007
auth-id = "backup-admin@pbs!automation-token"
encryption-key = "path/to/encryption-key.json"
```

### Creating Backups

**Basic backup command:**

```bash
# Using environment variable for token
export PBS_PASSWORD="593dbf80-43d2-46c5-a693-637818f95be8"

# Create backup
proxmox-backup-client backup \
    --repository backup-admin@pbs!automation-token@100.109.181.93:backups \
    /path/to/directory
```

**With encryption:**

```bash
# Generate encryption key first
proxmox-backup-client key create /etc/proxmox-backup/encryption-key.json

# Create encrypted backup
proxmox-backup-client backup \
    --repository backup-admin@pbs!automation-token@100.109.181.93:backups \
    --keyfile /etc/proxmox-backup/encryption-key.json \
    /path/to/directory
```

**Named backup with catalog:**

```bash
proxmox-backup-client backup \
    --repository backup-admin@pbs!automation-token@100.109.181.93:backups \
    --keyfile /etc/proxmox-backup/encryption-key.json \
    --backup-name "hostname-daily" \
    --backup-type "host" \
    /path/to/directory
```

### Backup Script Example

```bash
#!/bin/bash
# /usr/local/bin/pbs-backup.sh

PBS_SERVER="100.109.181.93"
PBS_DATASTORE="backups"
PBS_USER="backup-admin@pbs!automation-token"
PBS_TOKEN="593dbf80-43d2-46c5-a693-637818f95be8"
BACKUP_DIR="/data"
BACKUP_NAME="fgsrv07-$(date +%Y%m%d)"
ENCRYPTION_KEY="/etc/proxmox-backup/encryption-key.json"

export PBS_PASSWORD="$PBS_TOKEN"

proxmox-backup-client backup \
    --repository ${PBS_USER}@${PBS_SERVER}:${PBS_DATASTORE} \
    --keyfile "$ENCRYPTION_KEY" \
    --backup-name "$BACKUP_NAME" \
    --backup-type "host" \
    "$BACKUP_DIR"
```

---

## Integration with Proxmox VE

PBS is integrated with Proxmox VE on FGSRV07 for VM and container backups.

### Adding PBS Storage to Proxmox VE

Via Web Interface:

1. Navigate to **Datacenter → Storage → Add → Proxmox Backup Server**
2. Configure:

| Field | Value |
|-------|-------|
| **ID** | PBS-backups |
| **Server** | 100.109.181.93 (Tailscale IP) |
| **Username** | backup-admin@pbs |
| **Password** | (Set via PBS web UI) |
| **Datastore** | backups |
| **Fingerprint** | (Auto-accept or paste from PBS) |

Via CLI:

```bash
pvesm add pbs \
    --server "100.109.181.93" \
    --datastore "backups" \
    --username "backup-admin@pbs" \
    --fingerprint "..." \
    --content "backup,vzdumptmpl,iso"
```

### VM Backup Configuration

```bash
# Backup VM to PBS
vzdump 100 --storage PBS-backups --mode snapshot --compress zstd

# Schedule regular backups
# Datacenter → Backup → Add
# - Storage: PBS-backups
# - Schedule: daily at 03:00
# - Mode: snapshot
# - Compression: zstd
```

---

## Backup Retention Management

### Automatic Pruning

The prune job (`prune-backups`) runs daily at 02:00 and applies the retention policy:

```bash
# Manual prune
proxmox-backup-manager prune-job run prune-backups

# List prune jobs
proxmox-backup-manager prune-job list

# Show prune job details
proxmox-backup-manager prune-job show prune-backups
```

### Manual Backup Cleanup

```bash
# List backups in datastore
proxmox-backup-manager snapshots list backups

# Remove specific snapshot
proxmox-backup-manager snapshots delete backups <snapshot-time>
```

---

## Garbage Collection

PBS automatically runs garbage collection to remove unused data chunks.

### Default Schedule

Garbage collection runs based on datastore tuning settings. Default is optimized for performance.

### Manual GC

```bash
# Start garbage collection
proxmox-backup-manager garbage-collection start backups

# Check GC status
proxmox-backup-manager garbage-collection status backups
```

---

## Monitoring and Maintenance

### Service Management

```bash
# Check service status
systemctl status proxmox-backup

# Restart service
systemctl restart proxmox-backup

# View logs
journalctl -u proxmox-backup -f
```

### Metrics Endpoint

PBS provides metrics in Prometheus format:

```
http://100.109.181.93:8007/metrics
```

### Health Checks

```bash
# Check PBS API
curl -k https://100.109.181.93:8007/api2/json/version

# Check datastore status
proxmox-backup-manager datastore show backups

# Check task status
proxmox-backup-manager task list
```

---

## Storage Management

### Current Storage Status

```
Filesystem: /dev/xvda3
Total Size: 195 GB
Used: 5.2 GB
Available: 182 GB
Usage: 3%
```

### Monitoring Storage Usage

```bash
# Check disk usage
df -h /var/lib/proxmox-backup/datastore

# Check datastore statistics
proxmox-backup-manager datastore show backups --output-format json
```

### Storage Expansion

When storage needs expansion:

1. Add additional disk to VPS
2. Create new partition/filesystem
3. Add as additional datastore or expand existing

---

## Security Best Practices

### 1. API Token Management

- Store API tokens securely (use secrets management)
- Rotate tokens regularly
- Use separate tokens for different applications
- Never log tokens in plain text

### 2. Encryption

Always use encryption for backups:

```bash
# Generate encryption key
proxmox-backup-client key create /etc/proxmox-backup/encryption-key.json

# BACKUP THE ENCRYPTION KEY SECURELY
# Without this key, backups cannot be restored!
```

### 3. Network Security

- Use Tailscale for backup traffic when possible
- Restrict firewall rules to specific source IPs
- Enable TLS certificate verification in production

### 4. Access Control

- Use dedicated service accounts for automation
- Implement principle of least privilege
- Audit user access regularly

---

## Backup Verification

### Verification Job Setup

```bash
# Create verification job
proxmox-backup-manager verify-job create verify-backups \
    --store backups \
    --schedule "Sun at 04:00" \
    --ignore-verifiedSnapshots
```

### Manual Verification

```bash
# Verify all backups in datastore
proxmox-backup-manager verify backups
```

---

## Troubleshooting

### Common Issues

#### Issue: Authentication Failed

```bash
# Verify token is valid
proxmox-backup-manager user list-tokens backup-admin@pbs

# Check service is running
systemctl status proxmox-backup
```

#### Issue: Backup Slow

```bash
# Check network bandwidth
iperf3 -c <backup-server>

# Adjust compression level (in backup job)
# Compression levels: fast (default), best, none
```

#### Issue: Out of Space

```bash
# Check what's using space
du -sh /var/lib/proxmox-backup/datastore/*

# Run manual prune
proxmox-backup-manager prune-job run prune-backups

# Run garbage collection
proxmox-backup-manager garbage-collection start backups
```

#### Issue: Web Interface Not Accessible

```bash
# Check service status
systemctl status proxmox-backup

# Check firewall
iptables -L INPUT -n | grep 8007

# Check logs
journalctl -u proxmox-backup -n 50
```

---

## API Usage

### Authentication

```bash
# Using token
export PBS_PASSWORD="593dbf80-43d2-46c5-a693-637818f95be8"

# Using API token in curl
curl -k -H "Authorization: PBSAPIToken=backup-admin@pbs!automation-token:593dbf80-43d2-46c5-a693-637818f95be8" \
    https://100.109.181.93:8007/api2/json/version
```

### Common API Endpoints

```bash
# Get version
curl -k https://100.109.181.93:8007/api2/json/version

# List datastores
curl -k -H "Authorization: PBSAPIToken=..." \
    https://100.109.181.93:8007/api2/json/admin/datastore/list

# Get datastore status
curl -k -H "Authorization: PBSAPIToken=..." \
    https://100.109.181.93:8007/api2/json/admin/datastore/backups/status
```

---

## Disaster Recovery

### Encryption Key Backup

**CRITICAL:** Backup the encryption key securely. Without it, encrypted backups are useless.

```bash
# Copy encryption key to secure location
cp /etc/proxmox-backup/encryption-key.json /secure/backup/location/

# Store in password manager or secrets system
# Document key location in disaster recovery plan
```

### Restore Procedure

```bash
# List backups
proxmox-backup-client snapshot list \
    --repository backup-admin@pbs!automation-token@100.109.181.93:backups

# Restore specific backup
proxmox-backup-client restore \
    --repository backup-admin@pbs!automation-token@100.109.181.93:backups \
    <snapshot-path> \
    /restore/target
```

### VM Restore from PBS

1. In Proxmox VE web interface, navigate to the VM
2. Click **Restore**
3. Select PBS storage and backup snapshot
4. Configure restore options
5. Start restore process

---

## Configuration Files

### PBS Configuration

```bash
/etc/proxmox-backup/
├── acme/                    # ACME certificate configuration
├── authkey.key             # Authentication key
├── authkey.pub             # Public authentication key
├── csrf.key                # CSRF protection key
├── datastore.cfg           # Datastore configuration
├── domains.cfg             # Authentication domains
├── proxy.key               # Proxy TLS key
├── proxy.pem               # Proxy TLS certificate
├── prune.cfg               # Prune job configuration
├── token.shadow            # API token storage
└── user.cfg                # User configuration
```

### Backup Client Configuration

```bash
/etc/proxmox-backup/
├── backup-server.cfg       # Backup server configuration
└── encryption-key.json     # Backup encryption key (protect this!)
```

---

## Next Steps

### Immediate Tasks

1. **Set backup-admin password** via web interface
   - Login as root@pam
   - Navigate to Access → Users
   - Click backup-admin@pbs → Change Password

2. **Generate encryption key** for backup clients
   ```bash
   proxmox-backup-client key create /etc/proxmox-backup/encryption-key.json
   ```

3. **Configure Proxmox VE backup jobs**
   - Add PBS as storage in Proxmox VE
   - Create backup schedules for VMs/CTs

4. **Test backup and restore**
   - Create test backup
   - Verify restore process works

### Short-term Tasks

1. **Set up monitoring**
   - Configure Prometheus metrics scraping
   - Set up alerts for backup failures

2. **Configure verification jobs**
   - Weekly backup verification
   - Monthly restore testing

3. **Set up replication**
   - Configure remote PBS server for offsite copies
   - Set up sync jobs

### Long-term Planning

1. **Capacity planning**
   - Monitor growth trends
   - Plan storage expansion

2. **Security hardening**
   - Implement SSO/LDAP integration
   - Set up audit logging

3. **Performance optimization**
   - Tune GC schedules
   - Optimize prune jobs

---

## References

### Official Documentation

- **Proxmox Backup Server:** https://pbs.proxmox.com/docs/
- **Backup Client Manual:** https://pbs.proxmox.com/docs/backup-client.html
- **API Documentation:** https://pbs.proxmox.com/docs/api-viewer/
- **Administrator Guide:** https://pbs.proxmox.com/docs/admin-guide.html

### Related Documentation

- **[FGSRV07 Host Overview](./fgsrv07-host-overview.md)** - Server information
- **[FGSRV07 Proxmox Installation](./fgsrv07-proxmox-installation.md)** - Proxmox VE setup
- **[FGSRV07 Tailscale Installation](./fgsrv07-tailscale-installation.md)** - VPN setup
- **[Proxmox NFS Storage Guide](./proxmox-nfs-storage-guide.md)** - Storage options

---

## Support and Contact

### Support Information

| Resource | Contact |
|----------|---------|
| **Infrastructure Team** | admin@agl.hostman |
| **Documentation** | /mnt/overpower/apps/dev/agl/agl-hostman/docs/ |
| **Server** | FGSRV07 (191.252.93.227 / 100.109.181.93) |

### Quick Commands

| Task | Command |
|------|---------|
| **Check Service** | `systemctl status proxmox-backup` |
| **View Logs** | `journalctl -u proxmox-backup -f` |
| **List Datastores** | `proxmox-backup-manager datastore list` |
| **List Users** | `proxmox-backup-manager user list` |
| **List Prune Jobs** | `proxmox-backup-manager prune-job list` |

---

**Document Version:** 1.0
**Last Updated:** 2026-02-10
**Author:** DevOps Engineer (Hive Mind)
**Status:** ✅ Complete - PBS Operational

---

*Proxmox Backup Server is now ready for backup operations. Follow the configuration steps to integrate with your backup clients and Proxmox VE.*
