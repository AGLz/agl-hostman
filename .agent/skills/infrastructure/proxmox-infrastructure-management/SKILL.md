---
name: proxmox-infrastructure-management
description: "Complete Proxmox VE infrastructure management including VM lifecycle, container management, snapshots, clustering, storage operations, and network configuration. Use when managing virtual machines, LXC containers, or Proxmox clusters."
category: infrastructure
priority: P1
tags: [proxmox, vm, lxc, virtualization, cluster]
---

# Proxmox Infrastructure Management

Expert in managing Proxmox VE infrastructure including virtual machines, LXC containers, clustering, storage operations, and network configuration. This skill covers the complete infrastructure lifecycle from provisioning to backup and disaster recovery.

## Proxmox in AGL Infrastructure

The AGL Hostman infrastructure uses Proxmox VE 8.x as the primary virtualization platform with:

- **Multi-node cluster**: AGLSRV1 (primary) and AGLSRV6 (secondary)
- **WireGuard mesh network**: 10.6.0.0/24 for cluster communication
- **Tailscale fallback**: CGNAT for remote management access
- **Storage backends**: Local LVM, ZFS, and NFS
- **API integration**: Laravel-based ProxmoxApiClient with circuit breaker

### Cluster Configuration

```yaml
AGLSRV1 (Primary):
  host: 192.168.0.245
  wireguard_ip: 10.6.0.11
  tailscale_ip: 100.107.113.33
  port: 8006

AGLSRV6 (Secondary):
  host: (environment configured)
  wireguard_ip: 10.6.0.12
  tailscale_ip: (environment configured)
  port: 8006
```

## Cluster Management

### Multi-Node Operations

Proxmox clustering provides high availability and resource pooling across nodes.

#### Check Cluster Status

```bash
# View cluster status
pvecm status

# Output includes:
# - Quorum state
# - Node list
# - Node votes
# - Links

# Check cluster resources
pvesh get /cluster/resources --type node
pvesh get /cluster/resources --type vm
pvesh get /cluster/resources --type storage
```

#### Node Management

```bash
# Add node to cluster (run on new node)
pvecm add <primary-node-ip> --link0 <ip-address>

# Remove node from cluster (run on node to remove)
pvecm expected 1
pvecm delete

# Evacuate node for maintenance
ha-manager migrate-all --node <node-name>
```

#### Quorum Management

```bash
# Check quorum
pvecm status | grep Quorum

# Force quorum (emergency only - risk of split-brain)
pvecm expected 1

# View cluster log
tail -f /var/log/pmxcfs.log
```

### API Client Pattern

```php
use App\Services\ProxmoxApiClient;

// Initialize client from configuration
$config = [
    'host' => env('PROXMOX_HOST', '192.168.0.245'),
    'port' => env('PROXMOX_PORT', 8006),
    'username' => env('PROXMOX_USERNAME', 'root@pam'),
    'password' => env('PROXMOX_PASSWORD'),
    'realm' => env('PROXMOX_REALM', 'pam'),
    'verify_ssl' => env('PROXMOX_VERIFY_SSL', false),
    'log_channel' => 'default'
];

$proxmox = ProxmoxApiClient::fromConfig($config);

// Get cluster resources
$resources = $proxmox->getClusterResources();

// Get nodes
$nodes = $proxmox->getNodes();
```

### Circuit Breaker Integration

```php
// Circuit breaker protects against API failures
$circuitBreaker = [
    'enabled' => env('PROXMOX_CIRCUIT_BREAKER_ENABLED', true),
    'failure_threshold' => env('PROXMOX_CIRCUIT_BREAKER_THRESHOLD', 5),
    'timeout_seconds' => env('PROXMOX_CIRCUIT_BREAKER_TIMEOUT', 300),
];

// Check circuit breaker status
$status = $proxmox->getCircuitBreakerStatus();
// Returns: ['is_open' => bool, 'failures' => int, ...]
```

## VM Lifecycle Management

### Virtual Machine Operations

QEMU virtual machines provide full hardware virtualization for complete OS isolation.

#### Create VM

```bash
# Create VM with optimal settings
qm create <vmid> \
  --name <vmname> \
  --memory 4096 \
  --cores 2 \
  --cpu host \
  --net0 virtio,bridge=vmbr0 \
  --scsihw virtio-scsi-pci \
  --scsi0 local-lvm:32,ssd=1 \
  --ostype l26 \
  --agent 1 \
  --bios ovmf

# Import cloud-init image
qm importdisk <vmid> /path/to/image.qcow2 local-lvm
qm set <vmid} --scsi1 local-lvm:vm-<vmid>-disk-1

# Configure cloud-init
qm set <vmid> \
  --ide2 local-lvm:cloudinit \
  --boot order=scsi1 \
  --ipconfig0 ip=192.168.1.100/24,gw=192.168.1.1 \
  --nameserver 192.168.1.1 \
  --sshkey /path/to/public-key.pub
```

#### VM Power Management

```bash
# Start VM
qm start <vmid>

# Stop VM ( ACPI shutdown)
qm shutdown <vmid>

# Stop VM (force)
qm stop <vmid>

# Restart VM
qm reboot <vmid>

# Suspend/resume
qm suspend <vmid>
qm resume <vmid>
```

#### VM Configuration

```bash
# Resize CPU
qm set <vmid> --cores 4 --cpuunits 1024

# Resize memory
qm set <vmid} --memory 8192 --balloon 4096

# Add disk
qm set <vmid> --scsi2 local-lvm:64,ssd=1

# Resize disk
qm resize <vmid} scsi0 +32G

# Add network interface
qm set <vmid> --net1 virtio,bridge=vmbr1,tag=100

# Add PCI device (e.g., GPU)
qm set <vmid> --hostpci0 01:00.0,pcie=1
```

### Live Migration

Live migration allows moving VMs between nodes without downtime.

```bash
# Migrate VM with storage
qm migrate <vmid> --target <target-node> --with-local-disks --online

# Migrate without storage (shared storage)
qm migrate <vmid> --target <target-node> --online

# Check migration status
tail -f /var/log/pve/tasks/index
```

## LXC Container Management

### Container Lifecycle

LXC containers provide OS-level virtualization with minimal overhead.

#### Create Container

```bash
# Create container from template
pct create <vmid> \
  local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
  --hostname <hostname> \
  --cores 2 \
  --memory 4096 \
  --swap 2048 \
  --storage local-lvm:32 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --password <password> \
  --ssh-public-keys /path/to/keys.pub

# Create with static IP
pct create <vmid> \
  local:vztmpl/debian-12-standard_12.0-1_amd64.tar.zst \
  --hostname <hostname> \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.1.100/24,gw=192.168.1.1 \
  --onboot 1 \
  --start 1
```

#### Container Features

```bash
# Enable nesting (Docker-in-LXC)
pct set <vmid> -features nesting=1

# Enable keyctl
pct set <vmid> -features keyctl=1

# Mount host directory
pct set <vmid> -mp0 /mnt/data,mp=/host-data

# Set resource limits
pct set <vmid> -cores 4 -memory 8192 -swap 4096

# Unprivileged container (default, more secure)
pct set <vmid> -unprivileged 1
```

#### Container Operations

```bash
# Start/stop/restart
pct start <vmid>
pct stop <vmid>
pct restart <vmid>

# Execute command in container
pct exec <vmid> bash

# Enter container
pct enter <vmid>

# Clone container
pct clone <vmid> <new-vmid> --hostname <new-hostname> --storage local-lvm

# Get container status
pct status <vmid>
```

### Container Templates

```bash
# Available templates
# Ubuntu
local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst
local:vztmpl/ubuntu-20.04-standard_20.04-1_amd64.tar.zst

# Debian
local:vztmpl/debian-12-standard_12.0-1_amd64.tar.zst
local:vztmpl/debian-11-standard_11.3-1_amd64.tar.zst

# Alpine
local:vztmpl/alpine-3.19-standard_3.19.1-0_amd64.tar.zst

# Create custom template
pct stop <vmid>
pct template <vmid>
# Template saved to local storage
```

## Snapshot Management

Snapshots provide point-in-time recovery for VMs and containers.

### Create Snapshots

```bash
# VM snapshot
qm snapshot <vmid> <snapshot-name> \
  --description "Pre-upgrade snapshot" \
  --statesnapshot 1  # Include RAM

# Container snapshot
pct snapshot <vmid> <snapshot-name> \
  --description "Pre-update snapshot"

# Automated snapshot naming
SNAPNAME="auto-$(date +%Y%m%d-%H%M%S)"
qm snapshot <vmid> "backup-$SNAPNAME" --description "Automated backup"
```

### List and Restore

```bash
# List VM snapshots
qm listsnapshot <vmid>

# List container snapshots
pct listsnapshot <vmid>

# Restore VM snapshot
qm rollback <vmid> <snapshot-name>

# Restore container snapshot
pct rollback <vmid> <snapshot-name>

# Delete snapshot
qm delsnapshot <vmid> <snapshot-name>
pct delsnapshot <vmid> <snapshot-name>
```

### Snapshot Retention Policy

Implement automated cleanup with retention policies:

```bash
# Keep daily snapshots for 7 days
# Keep weekly snapshots for 4 weeks
# Keep monthly snapshots for 3 months

# See scripts/px-snapshot-cleanup.sh for implementation
```

## Storage Operations

### Storage Backends

Proxmox supports multiple storage backends for different use cases.

#### LVM (Local Volume Manager)

```bash
# Create LVM thin pool
pvcreate /dev/sdb
vgcreate vg0 /dev/sdb
lvcreate -L 100G -T vg0/thinpool

# Add LVM storage to Proxmox
pvesm add lvm <storage-id> --vgname vg0 --content images,rootdir

# Create thin LV
lvcreate -V 32G -T vg0/thinpool -n vm-<vmid>-disk-0
```

#### ZFS (Zettabyte File System)

```bash
# Create ZFS pool
zpool create -o ashift=12 -O compression=lz4 tank /dev/sdb

# Add ZFS storage
pvesm add zfspool <storage-id> --pool tank --content images,rootdir

# Create dataset with compression
zfs create -o compression=zstd tank/vms

# Snapshot dataset
zfs snapshot tank/vms@backup-$(date +%Y%m%d)

# Send/receive for backup
zfs send tank/vms@snapshot | zfs receive backup-tank/vms
```

#### NFS (Network File System)

```bash
# Add NFS storage
pvesm add nfs <storage-id> \
  --server <nfs-server> \
  --export /path/to/export \
  --content images,iso,vztmpl,backup,rootdir

# Mount options
pvesm add nfs <storage-id> \
  --server <nfs-server> \
  --export /export \
  --options vers=4.2,soft,timeo=600,retrans=5
```

#### Ceph RBD (Distributed Storage)

```bash
# Add Ceph storage
pvesm add rbd <storage-id> \
  --pool rbd \
  --monhost <mon1-ip>:6789,<mon2-ip>:6789 \
  --username admin \
  --krbd 1

# Create RBD image
rbd create vm-<vmid>-disk-0 --size 32G --pool rbd --image-format 2
```

### Storage Management

```bash
# List all storage
pvesm status

# Get storage info
pvesm get <storage-id> --output-format json

# Resize disk (VM)
qm resize <vmid> scsi0 +16G

# Resize disk (container)
pct resize <vmid> rootfs +16G

# Move disk between storage
qm move_disk <vmid> scsi0 <target-storage>

# Create backup
vzdump <vmid> --mode snapshot --storage <backup-storage> --compress zstd
```

## Network Configuration

### Network Bridges

Bridges connect VMs/containers to the physical network.

```bash
# View network config
cat /etc/network/interfaces

# Example bridge configuration
auto vmbr0
iface vmbr0 inet static
    address 192.168.1.10/24
    gateway 192.168.1.1
    bridge-ports eno1
    bridge-stp off
    bridge-fd 0

# Apply network changes
ifreload -a
```

### VLAN Configuration

```bash
# VLAN-tagged bridge
auto vmbr0.100
iface vmbr0.100 inet manual
    bridge-ports vmbr0.100
    bridge-stp off
    bridge-fd 0

# VM with VLAN tag
qm set <vmid> --net0 virtio,bridge=vmbr0,tag=100

# Container with VLAN
pct set <vmid> --net0 name=eth0,bridge=vmbr0.100
```

### Bonding (Link Aggregation)

```bash
# LACP bonding
auto bond0
iface bond0 inet manual
    bond-slaves eno1 eno2
    bond-mode 802.3ad
    bond-miimon 100
    bond-lacp-rate fast

auto vmbr0
iface vmbr0 inet static
    address 192.168.1.10/24
    gateway 192.168.1.1
    bridge-ports bond0
    bridge-stp off
    bridge-fd 0
```

### WireGuard VPN

```bash
# WireGuard configuration for cluster mesh
# /etc/wireguard/wg0.conf

[Interface]
PrivateKey = <private-key>
Address = 10.6.0.11/24
ListenPort = 51820

[Peer]
PublicKey = <node2-public-key>
Endpoint = <node2-public-ip>:51820
AllowedIPs = 10.6.0.12/32
PersistentKeepalive = 25

# Start WireGuard
wg-quick up wg0
systemctl enable wg-quick@wg0
```

## Backup and Restore

### Proxmox Backup Server

PBS provides deduplicated, encrypted backups.

#### Configure PBS Storage

```bash
# Add Proxmox Backup Server
pvesm add pbs <storage-id> \
  --server <pbs-server> \
  --username <username>@pbs \
  --password <password> \
  --fingerprint <fingerprint> \
  --datastore <datastore> \
  --content backup

# Create backup with encryption
vzdump <vmid> --mode snapshot --storage <pbs-storage> \
  --notes "Weekly backup" \
  --mailnotification always
```

### Vzdump Backups

Traditional file-based backups.

```bash
# Backup single VM
vzdump 100 --mode snapshot --storage local-bak --compress zstd

# Backup all VMs
vzdump --all 1 --mode snapshot --storage local-bak --compress zstd

# Backup with exclude
vzdump --all 1 --mode snapshot --storage local-bak \
  --exclude 101,102

# Restore from backup
qmrestore /path/to/backup.vma.zst <new-vmid> --storage local-lvm

# Restore container
pctrestore /path/to/backup.tar.zst <new-vmid> --storage local-lvm
```

### Automated Backup Schedule

```bash
# Daily incremental, weekly full
# Add to crontab

# Daily incremental at 2 AM
0 2 * * * vzdump --all 1 --mode snapshot --storage local-bak --compress zstd --mailnotification always

# Weekly full backup on Sunday at 3 AM
0 3 * * 0 vzdump --all 1 --mode snapshot --storage pbs --compress zstd --mailnotification always
```

### Disaster Recovery

```bash
# Backup Proxmox configuration
tar -czf proxmox-config-backup-$(date +%Y%m%d).tar.gz \
  /etc/pve \
  /etc/network/interfaces \
  /etc/hosts \
  /var/lib/vz

# Backup cluster configuration
pvecm status > cluster-status.txt
pvesh get /cluster/backup > cluster-config.txt

# Restore procedure
# 1. Install Proxmox on new hardware
# 2. Restore /etc/pve from backup
# 3. Restore /etc/network/interfaces
# 4. Restore VM/containers from backup
# 5. Verify network connectivity
```

## API Usage Patterns

### ProxmoxApiClient

The Laravel service wraps Proxmox API with retry logic and circuit breaker.

```php
use App\Services\ProxmoxApiClient;

$proxmox = ProxmoxApiClient::fromConfig($config);

// Node operations
$nodes = $proxmox->getNodes();
$nodeStatus = $proxmox->getNodeStatus('AGLSRV1');

// Container operations
$containers = $proxmox->getContainers('AGLSRV1');
$status = $proxmox->getContainerStatus('AGLSRV1', 105);
$proxmox->startContainer('AGLSRV1', 105);

// Cluster operations
$resources = $proxmox->getClusterResources('vm');
```

### Repository Pattern

```php
use App\Repositories\ProxmoxContainerRepository;

$repository = new ProxmoxContainerRepository($proxmox);

// Get containers with metrics
$containers = $repository->getAllContainers('AGLSRV1', withMetrics: true);

// Get unhealthy containers
$unhealthy = $repository->getUnhealthyContainers('AGLSRV1');

// Get aggregate stats
$stats = $repository->getAggregateStats('AGLSRV1');
```

### Response Handling

```php
use App\DTOs\ProxmoxApiResponse;

$response = $proxmox->getContainers('AGLSRV1');

if ($response->isSuccess()) {
    $containers = $response->getData();
} else {
    Log::error('Proxmox API error', [
        'error' => $response->getError(),
        'status' => $response->getStatusCode()
    ]);
}
```

### Metrics Collection

```php
use App\DTOs\ContainerMetrics;

$metrics = $repository->getContainerMetrics('AGLSRV1', 105);

// Check health
if ($metrics->isCpuCritical()) {
    Alert::create([
        'type' => 'critical',
        'title' => 'High CPU Usage',
        'message' => "Container {$metrics->name} CPU at {$metrics->cpuUsagePercent}%",
        'alert_type' => 'performance',
        'severity' => 90,
    ]);
}

// Get resource summary
$summary = $metrics->getResourceSummary();
// Returns: ['cpu' => 45.2, 'memory' => 2048, 'disk' => 32]
```

## Monitoring Integration

### Alert Thresholds

```php
// config/monitoring.php
'proxmox' => [
    'server_cpu_warning' => 70,
    'server_cpu_critical' => 85,
    'server_memory_warning' => 80,
    'server_memory_critical' => 90,
    'container_cpu_warning' => 60,
    'container_cpu_critical' => 80,
    'container_memory_warning' => 75,
    'container_memory_critical' => 90,
    'container_disk_warning' => 80,
    'container_disk_critical' => 90,
],
```

### Metrics Collection Job

```php
use App\Jobs\CollectProxmoxMetrics;

// Dispatch metrics collection
CollectProxmoxMetrics::dispatch();

// Collect and monitor
$monitoring = app(MonitoringService::class);
$alerts = $monitoring->collectAndMonitor();

// Get health status
$health = $monitoring->getHealthStatus();

// Get performance trends
$trends = $monitoring->getPerformanceTrends('container', 105, 24);
```

## Troubleshooting

### Common Issues

#### API Connection Refused

**Error:** `cURL error 7: Failed to connect to port 8006`

**Solutions:**
1. Check Proxmox API service status: `systemctl status pveproxy`
2. Verify network connectivity: `ping <proxmox-host>`
3. Check firewall: `iptables -L -n | grep 8006`
4. Test API: `curl -k https://<host>:8006/api2/json/version`

#### Authentication Failed

**Error:** `401 Permission denied`

**Solutions:**
1. Verify credentials in `.env`
2. Check API token: Datacenter > Permissions > API Tokens
3. Test token manually:
```bash
curl -k \
  -H "Authorization: PVEAPIToken=root@pam!<token-id>=<token-secret>" \
  https://<host>:8006/api2/json/version
```

#### VM Won't Start

**Error:** `VM configuration file missing` or `Lock file exists`

**Solutions:**
1. Check VM config: `cat /etc/pve/qemu-server/<vmid>.conf`
2. Remove lock files: `rm /var/lock/qemu-server/lock-<vmid>`
3. Check disk exists: `lvs | grep vm-<vmid>`
4. Check bridge exists: `brctl show`

#### Container Won't Start

**Error:** `Container configuration file missing`

**Solutions:**
1. Check container config: `cat /etc/pve/lxc/<vmid>.conf`
2. Verify template exists: `pct list | grep <vmid>`
3. Check storage: `df -h /var/lib/vz`
4. Check bridge exists: `ip a show vmbr0`

#### Cluster Quorum Lost

**Error:** `No quorum` in `pvecm status`

**Solutions:**
1. Check node connectivity: `ping <other-nodes>`
2. Check Corosync rings: `corosync-cfgtool -s`
3. Vote manipulation (emergency): `pvecm expected 1`
4. Restart Corosync: `systemctl restart corosync pve-cluster`

#### Live Migration Fails

**Error:** `Migration failed` or `Storage not available`

**Solutions:**
1. Check shared storage: `pvesm status`
2. Verify network connectivity: `iperf between nodes`
3. Check VM configuration: `qm config <vmid>`
4. Use `--with-local-disks` for local storage

### Debug Commands

```bash
# View Proxmox logs
tail -f /var/log/syslog
tail -f /var/log/daemon.log
journalctl -u pvedaemon -f
journalctl -u pveproxy -f

# Check cluster status
pvecm status
pvesh get /cluster/status

# View task history
pvesh get /cluster/tasks
cat /var/log/pve/tasks/index

# Check storage
pvesm status
df -h
lvs

# Check network
ip a show
brctl show
cat /etc/network/interfaces

# Test API
curl -k https://localhost:8006/api2/json/version
pvesh get /version

# Check VM config
cat /etc/pve/qemu-server/<vmid>.conf
qm config <vmid>

# Check container config
cat /etc/pve/lxc/<vmid>.conf
pct config <vmid>
```

## Best Practices

### Resource Allocation

```php
// Overcommit ratio considerations
// CPU: 2:1 (2 vCPUs per physical core)
// Memory: 1.5:1 (1.5GB allocated per 1GB physical)
// Storage: Monitor usage, keep 20% free

// Right-sizing guidelines
// Development: 2 cores, 4GB RAM, 32GB disk
// Production: 4 cores, 8GB RAM, 64GB disk
// Database: 8 cores, 32GB RAM, 256GB disk
```

### Security Hardening

```bash
# Use unprivileged containers
pct set <vmid> -unprivileged 1

# Enable Proxmox firewall
pvesh set /nodes/<node>/lxc/<vmid>/firewall/options --enable 1

# Restrict network access
pvesh set /nodes/<node>/lxc/<vmid>/firewall/rules \
  --action ACCEPT --proto tcp --dport 22 --source 192.168.1.0/24

# Use API tokens with limited scope
# Datacenter > Permissions > API Tokens
# Set privilege separation
```

### Backup Strategy

```bash
# 3-2-1 backup rule
# 3: Copies of data (primary + 2 backups)
# 2: Different storage types (local + NFS/ PBS)
# 1: Off-site backup (PBS remote sync)

# Daily incremental backups
# Weekly full backups
# Monthly off-site sync
```

### Monitoring

```php
// Set up comprehensive monitoring
- CPU usage trends
- Memory utilization
- Disk I/O performance
- Network throughput
- Container health status
- API response times
- Circuit breaker status
```

## Scripts Reference

The following utility scripts are provided:

### px-vm-create.sh
Create VM with optimal settings and cloud-init configuration.

### px-vm-migrate.sh
Live migrate VM to another node with storage migration.

### px-snapshot-cleanup.sh
Remove old snapshots based on retention policy (7 daily, 4 weekly, 3 monthly).

### px-cluster-status.sh
Check cluster health, quorum status, and resource availability.

### px-backup.sh
Backup VMs and containers to Proxmox Backup Server or local storage.

## Related Skills

- `harbor-registry` - Container image management
- `redis-caching` - Cache API responses
- `alert-management` - Alert on thresholds
- `performance-monitoring` - Metrics collection
