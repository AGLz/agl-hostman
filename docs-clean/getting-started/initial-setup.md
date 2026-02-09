# Initial Setup

This guide covers the initial setup steps after installing AGL Hostman, including user configuration, network setup, and basic system configuration.

## System Initialization

### 1. Run Initial Setup Wizard

```bash
# Run the initial setup wizard
agl-hostman setup

# This will prompt you for:
# - Administrator email
# - Password
# - Timezone
# - Storage paths
# - Network configuration
```

### 2. Administrator Account Setup

```bash
# Create administrator account
agl-hostman admin create

# Specify account details:
# - Email: admin@aglhostman.local
# - Password: [secure-password]
# - Role: administrator
# - Permissions: full access
```

### 3. System Configuration

```bash
# Configure system settings
agl-hostman system configure

# Key settings:
# - Hostname: agl-hostman-01
# - Domain: aglhostman.local
# - Timezone: America/Los_Angeles
# - NTP servers: pool.ntp.org
```

## User Management

### Create Users

```bash
# Create regular user
agl-hostman user create

# Specify user details:
# - Username: storage-admin
# - Email: storage-admin@aglhostman.local
# - Role: storage-admin
# - Permissions: read/write storage
```

### User Roles

AGL Hostman supports the following roles:

| Role | Permissions | Description |
|------|-------------|-------------|
| **administrator** | Full system access | Can manage all aspects of the system |
| **storage-admin** | Storage management | Can manage storage configurations and operations |
| **monitoring-admin** | Monitoring access | Can access monitoring dashboards and configure alerts |
| **backup-admin** | Backup management | Can manage backup operations and recovery |
| **viewer** | Read-only access | Can view system status and metrics |

### Role Permissions

```json
{
  "administrator": [
    "system:*",
    "storage:*",
    "monitoring:*",
    "backup:*",
    "user:*",
    "api:*"
  ],
  "storage-admin": [
    "storage:nfs:*",
    "storage:iscsi:*",
    "storage:pbs:*",
    "monitoring:storage:*"
  ],
  "monitoring-admin": [
    "monitoring:*",
    "system:status"
  ],
  "backup-admin": [
    "backup:*",
    "storage:nfs:read",
    "storage:pbs:read"
  ],
  "viewer": [
    "system:status",
    "monitoring:read",
    "storage:read",
    "backup:read"
  ]
}
```

## Network Configuration

### 1. Verify Tailscale Status

```bash
# Check Tailscale status
tailscale status

# Expected output:
# advertises=true: subnet=100.64.0.1/32
# machines=4
# peers=3
```

### 2. Configure Hosts

```bash
# Add all hosts to configuration
agl-hostman hosts add aglsrv1.local
agl-hostman hosts add aglsrv6.local
agl-hostman hosts add aglsrv6b.local
agl-hostman hosts add fgserver5.local
agl-hostman hosts add fgserver6.local
```

### 3. Verify Connectivity

```bash
# Test connectivity to all hosts
agl-hostman connectivity test

# Expected output:
# aglsrv1.local: ✓
# aglsrv6.local: ✓
# aglsrv6b.local: ✓
# fgserver5.local: ✓
# fgserver6.local: ✓
```

## Storage Configuration

### 1. Configure Storage Pools

```bash
# Create storage pool configuration
agl-hostman storage configure

# Select storage type:
# 1. NFS
# 2. iSCSI
# 3. PBS
# 4. Custom
```

### 2. Configure NFS Mounts

```bash
# Add NFS mount
agl-hostman storage nfs add

# Configuration:
# - Mount point: /mnt/aglsrv1/data
# - Server: aglsrv1.local
# - Export: /export
# - Options: defaults,hard,intr,tcp,nfsvers=4.2
# - Auto-mount: true
```

### 3. Configure iSCSI Targets

```bash
# Add iSCSI target
agl-hostman storage iscsi add

# Configuration:
# - Target: iqn.2025-10.com.aglhostman:storage
# - Portal: aglsrv1.local:3260
# - LUN: 0
# - Size: 500GB
# - Authentication: none
```

### 4. Configure PBS Repositories

```bash
# Add PBS repository
agl-hostman storage pbs add

# Configuration:
# - Server: aglsrv1.local
# - Repository: agl-backups
# - Username: agl-hostman
# - SSH Key: /home/agl-hostman/.ssh/pbs_backup
# - Schedule: daily
```

## Monitoring Setup

### 1. Initialize Monitoring Stack

```bash
# Start monitoring services
agl-hostman monitoring start

# Verify services
agl-hostman monitoring status

# Expected output:
# Prometheus: ✓
# Grafana: ✓
# Loki: ✓
```

### 2. Configure Dashboards

```bash
# Import default dashboards
agl-hostman dashboards import

# Import dashboards:
# 1. System Overview
# 2. Storage Performance
# 3. Network Traffic
# 4. Backup Status
# 5. Host Metrics
```

### 3. Configure Alerting

```bash
# Configure alerts
agl-hostman alerts configure

# Default alerts:
# 1. Disk Usage > 80%
# 2. CPU Usage > 90%
# 3. Memory Usage > 85%
# 4. Network Latency > 100ms
# 5. Backup Failure
```

## Backup Configuration

### 1. Configure Backup Strategy

```bash
# Set up backup strategy
agl-hostman backup configure

# Configuration:
# - Schedule: daily at 2:00 AM
# - Retention: 7 days
# - Compression: true
# - Encryption: true
# - Verification: daily
```

### 2. Configure Offsite Replication

```bash
# Set up offsite replication
agl-hostman backup offsite configure

# Configuration:
# - Remote Server: backup-server.local
# - Path: /backups/aglhostman
# - Schedule: daily at 4:00 AM
# - Bandwidth Limit: 100 Mbps
```

### 3. Test Backup

```bash
# Run test backup
agl-hostman backup test

# Expected output:
# Backup started: ✓
# Backup completed: ✓
# Backup verified: ✓
# Offsite replicated: ✓
```

## API Configuration

### 1. Enable API

```bash
# Enable API services
agl-hostman api enable

# Configure API:
# - Port: 8080
# - SSL: true
# - Rate Limit: 100 requests/minute
# - CORS: enabled
```

### 2. Generate API Token

```bash
# Generate API token
agl-hostman token generate

# Configuration:
# - User: admin@aglhostman.local
# - Permissions: full access
# - Expiry: 365 days
# - Name: admin-token
```

### 3. Test API

```bash
# Test API connectivity
curl -H "Authorization: Bearer $TOKEN" \
     https://api.aglhostman.local/status

# Expected output:
{"status": "active", "version": "1.0.0", "timestamp": "2025-10-14T12:00:00Z"}
```

## System Verification

### 1. Complete System Check

```bash
# Run comprehensive system check
agl-hostman system check

# This will verify:
# - Services status
# - Network connectivity
# - Storage mounts
# - Monitoring stack
# - Backup system
# - API connectivity
```

### 2. Generate Health Report

```bash
# Generate health report
agl-hostman health report

# Report includes:
# - System status
# - Performance metrics
# - Storage utilization
# - Network status
# - Alert status
# - Recommendations
```

### 3. Performance Baseline

```bash
# Establish performance baseline
agl-hostman baseline create

# Baseline includes:
# - CPU usage
# - Memory usage
# - Network throughput
# - I/O performance
# - Response times
```

## Documentation

### 1. Generate Documentation

```bash
# Generate documentation
agl-hostman docs generate

# This creates:
# - API documentation
# - Configuration guide
# - Troubleshooting guide
# - Architecture diagrams
```

### 2. Setup Documentation Site

```bash
# Start documentation site
agl-hostman docs serve

# Access at:
# http://localhost:8000
```

## Next Steps

1. [Architecture Overview](../architecture/overview.md) - Learn about system architecture
2. [Storage Management](../storage/nfs.md) - Configure storage protocols
3. [Monitoring Stack](../monitoring/stack.md) - Configure monitoring
4. [Backup Strategy](../backup/strategy.md) - Configure backup systems

---

*Need help? Check the [troubleshooting guide](../troubleshooting/common.md) or create an issue on [GitHub](https://github.com/aglhostman/agl-hostman/issues).*