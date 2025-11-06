# AGLSRV1 Remote Storage Architecture Design

**Document Version:** 1.0
**Date:** 2025-10-14
**Architect:** System Architect Agent
**Project:** Multi-Host Storage Consolidation via Tailscale VPN

---

## Executive Summary

This document defines the storage architecture for connecting 4 remote Proxmox hosts to AGLSRV1 storage server over a Tailscale VPN mesh network. The design prioritizes performance, security, and resilience while supporting multiple use cases including file sharing, backup operations, and container migration.

### Key Design Principles
1. **Multi-Protocol Approach**: Leverage optimal protocol per use case
2. **Zero-Trust Security**: Tailscale mesh + protocol-level encryption
3. **High Availability**: Failover mechanisms and redundancy
4. **Performance Optimization**: Protocol tuning for VPN constraints
5. **Operational Simplicity**: Standardized mount structures and automation

---

## 1. Network Topology Architecture

### 1.1 Tailscale Overlay Network

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Tailscale Mesh Network (100.x.x.x/10)          │
│                                                                     │
│  ┌──────────────┐                                                  │
│  │   AGLSRV1    │ ◄──── Primary Storage Server                     │
│  │ (100.x.x.x)  │                                                  │
│  └──────┬───────┘                                                  │
│         │                                                           │
│         │ Encrypted Mesh Connections                               │
│    ┌────┴────┬────────┬────────┬────────┐                         │
│    │         │        │        │        │                          │
│ ┌──▼───┐ ┌──▼───┐ ┌──▼───┐ ┌──▼───┐                              │
│ │AGLSRV6│ │AGLSRV6b│FGSRV5│ │FGSRV6│                               │
│ │100.98 │ │100.98 │100.71│ │100.83│                               │
│ │.108.66│ │.119.51│.107.26│.51.9 │                                │
│ │+PBS   │ │+PBS   │      │ │      │                                │
│ └───────┘ └───────┘ └──────┘└──────┘                              │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.2 Storage Protocol Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           AGLSRV1 Storage Services                      │
│  ┌──────────────┬──────────────┬──────────────┬──────────────────┐    │
│  │  NFS v4.2    │   iSCSI      │   PBS API    │   SSH/SFTP       │    │
│  │  Port: 2049  │   Port: 3260 │   Port: 8007 │   Port: 22       │    │
│  └──────┬───────┴──────┬───────┴──────┬───────┴──────┬───────────┘    │
└─────────┼──────────────┼──────────────┼──────────────┼────────────────┘
          │              │              │              │
          │ Tailscale VPN (WireGuard Encrypted Tunnel) │
          │              │              │              │
┌─────────▼──────────────▼──────────────▼──────────────▼────────────────┐
│                        Remote Hosts                                    │
│                                                                         │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐      │
│  │  AGLSRV6   │  │  AGLSRV6b  │  │   FGSRV5   │  │   FGSRV6   │      │
│  │            │  │            │  │            │  │            │      │
│  │ NFS Mount  │  │ NFS Mount  │  │ NFS Mount  │  │ NFS Mount  │      │
│  │ iSCSI Init │  │ iSCSI Init │  │ iSCSI Init │  │ iSCSI Init │      │
│  │ PBS Client │  │ PBS Client │  │            │  │            │      │
│  └────────────┘  └────────────┘  └────────────┘  └────────────┘      │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1.3 Data Flow Patterns

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Use Case Routing                            │
└─────────────────────────────────────────────────────────────────────┘

Use Case                    Protocol        Port    Path
═══════════════════════════════════════════════════════════════════════
General File Sharing        NFS v4.2        2049    /mnt/remote/{host}/data
VM/CT Disk Images           iSCSI           3260    /dev/disk/by-path/...
Proxmox Backups (PBS)       PBS Native      8007    datastore: remote-{host}
Container Migration         SSH/rsync       22      /mnt/remote/{host}/containers
ISO/Template Storage        NFS v4.2        2049    /mnt/remote/shared/iso
Configuration Sync          NFS v4.2        2049    /mnt/remote/{host}/config
───────────────────────────────────────────────────────────────────────
```

---

## 2. Storage Hierarchy Design

### 2.1 AGLSRV1 Directory Structure

```
/mnt/storage/                           # Primary storage pool
│
├── remote/                             # Remote host storage root
│   ├── aglsrv6/
│   │   ├── data/                       # General file shares
│   │   │   ├── vms/                    # VM disk images
│   │   │   ├── containers/             # Container rootfs
│   │   │   └── shared/                 # User/application data
│   │   ├── backups/                    # PBS datastore
│   │   │   ├── .chunks/                # Deduplication chunks
│   │   │   ├── vm/                     # VM backups
│   │   │   └── ct/                     # Container backups
│   │   ├── iso/                        # ISO images
│   │   ├── templates/                  # VM/CT templates
│   │   └── staging/                    # Migration staging area
│   │
│   ├── aglsrv6b/
│   │   └── [same structure as aglsrv6]
│   │
│   ├── fgsrv5/
│   │   └── [same structure]
│   │
│   └── fgsrv6/
│       └── [same structure]
│
├── shared/                             # Cross-host shared resources
│   ├── iso/                            # Common ISO library
│   ├── templates/                      # Shared templates
│   └── tools/                          # Management scripts
│
└── iscsi/                              # iSCSI LUN storage
    ├── lun-aglsrv6-001.img
    ├── lun-aglsrv6b-001.img
    ├── lun-fgsrv5-001.img
    └── lun-fgsrv6-001.img
```

### 2.2 Remote Host Mount Points

```
Remote Host Perspective:
/mnt/aglsrv1/                           # Central mount root
├── data/                               # NFS: /mnt/storage/remote/{hostname}/data
├── backups/                            # PBS datastore (not mounted, PBS handles)
├── iso/                                # NFS: /mnt/storage/shared/iso
├── templates/                          # NFS: /mnt/storage/shared/templates
└── staging/                            # NFS: /mnt/storage/remote/{hostname}/staging

/dev/disk/by-path/                      # iSCSI block devices
└── ip-100.x.x.x:3260-iscsi-iqn...-lun-1
```

---

## 3. Protocol Selection Matrix

### 3.1 Protocol Comparison

| Protocol | Use Case | Latency Sensitivity | Bandwidth | Complexity | Security |
|----------|----------|---------------------|-----------|------------|----------|
| **NFS v4.2** | File sharing, ISOs, templates | Low | Medium | Low | Kerberos/sec=krb5p |
| **iSCSI** | VM disk images, databases | High | High | Medium | CHAP + IPSec |
| **PBS Native** | Backups, deduplication | Low | Medium | Low | TLS + token auth |
| **SSH/SFTP** | Ad-hoc transfers, migrations | Medium | Low | Very Low | Public key |

### 3.2 Recommended Protocol per Use Case

```yaml
storage_protocol_mapping:
  vm_disk_images:
    primary: iSCSI
    fallback: NFS v4.2
    rationale: "Block-level performance for live VMs"

  container_rootfs:
    primary: NFS v4.2
    fallback: Local with rsync
    rationale: "File-level access, lower overhead"

  backup_storage:
    primary: PBS Native
    fallback: NFS v4.2 + PBS local
    rationale: "Deduplication, encryption, compression"

  iso_templates:
    primary: NFS v4.2 (read-only)
    fallback: HTTP/rsync
    rationale: "Shared read-only resources"

  migration_staging:
    primary: NFS v4.2
    fallback: SSH/rsync
    rationale: "Temporary storage, good performance"
```

---

## 4. Multi-Protocol Architecture

### 4.1 NFS v4.2 Configuration

**Server Configuration (AGLSRV1):**

```bash
# /etc/exports
/mnt/storage/remote/aglsrv6/data    100.98.108.66(rw,sync,no_subtree_check,no_root_squash,sec=sys)
/mnt/storage/remote/aglsrv6b/data   100.98.119.51(rw,sync,no_subtree_check,no_root_squash,sec=sys)
/mnt/storage/remote/fgsrv5/data     100.71.107.26(rw,sync,no_subtree_check,no_root_squash,sec=sys)
/mnt/storage/remote/fgsrv6/data     100.83.51.9(rw,sync,no_subtree_check,no_root_squash,sec=sys)
/mnt/storage/shared/iso             100.0.0.0/8(ro,sync,no_subtree_check,sec=sys)
/mnt/storage/shared/templates       100.0.0.0/8(ro,sync,no_subtree_check,sec=sys)

# Performance tuning in /etc/nfs.conf
[nfsd]
threads=64
tcp=y
udp=n
vers4=y
vers4.2=y

[mountd]
manage-gids=y
```

**Client Mount Options:**

```bash
# /etc/fstab on remote hosts
100.x.x.x:/mnt/storage/remote/$(hostname)/data  /mnt/aglsrv1/data  nfs4  \
  rw,hard,intr,rsize=1048576,wsize=1048576,timeo=600,retrans=2,_netdev  0  0

100.x.x.x:/mnt/storage/shared/iso  /mnt/aglsrv1/iso  nfs4  \
  ro,hard,intr,rsize=1048576,timeo=600,_netdev  0  0
```

**Performance Optimizations:**
- `rsize/wsize=1048576` (1MB): Maximizes throughput over Tailscale
- `hard,intr`: Ensures data integrity with ability to interrupt
- `timeo=600`: 60-second timeout for VPN latency
- `async` for non-critical data, `sync` for VM storage

### 4.2 iSCSI Configuration

**Target Configuration (AGLSRV1):**

```bash
# Using targetcli
targetcli <<EOF
cd /backstores/fileio
create lun-aglsrv6-001 /mnt/storage/iscsi/lun-aglsrv6-001.img 500G
create lun-aglsrv6b-001 /mnt/storage/iscsi/lun-aglsrv6b-001.img 500G
create lun-fgsrv5-001 /mnt/storage/iscsi/lun-fgsrv5-001.img 500G
create lun-fgsrv6-001 /mnt/storage/iscsi/lun-fgsrv6-001.img 500G

cd /iscsi
create iqn.2025-01.local.aglsrv1:storage
cd iqn.2025-01.local.aglsrv1:storage/tpg1/luns
create /backstores/fileio/lun-aglsrv6-001
create /backstores/fileio/lun-aglsrv6b-001
create /backstores/fileio/lun-fgsrv5-001
create /backstores/fileio/lun-fgsrv6-001

cd ../acls
create iqn.2025-01.local.aglsrv6:initiator
create iqn.2025-01.local.aglsrv6b:initiator
create iqn.2025-01.local.fgsrv5:initiator
create iqn.2025-01.local.fgsrv6:initiator

cd iqn.2025-01.local.aglsrv6:initiator
set auth userid=aglsrv6 password=STRONG_PASSWORD_HERE

cd ../portals
create 100.x.x.x 3260
delete 0.0.0.0 3260
saveconfig
exit
EOF
```

**Initiator Configuration (Remote Hosts):**

```bash
# /etc/iscsi/initiatorname.iscsi
InitiatorName=iqn.2025-01.local.$(hostname):initiator

# /etc/iscsi/iscsid.conf
node.session.auth.authmethod = CHAP
node.session.auth.username = $(hostname)
node.session.auth.password = STRONG_PASSWORD_HERE
node.session.timeo.replacement_timeout = 120
node.conn[0].timeo.noop_out_interval = 5
node.conn[0].timeo.noop_out_timeout = 10

# Discovery and login
iscsiadm -m discovery -t st -p 100.x.x.x:3260
iscsiadm -m node --targetname iqn.2025-01.local.aglsrv1:storage --portal 100.x.x.x:3260 --login
```

### 4.3 Proxmox Backup Server (PBS) Integration

**AGLSRV1 PBS Configuration:**

```bash
# Create PBS datastores
pvesh create /config/datastore --name remote-aglsrv6 \
  --path /mnt/storage/remote/aglsrv6/backups \
  --gc-schedule "daily 02:00" \
  --prune-schedule "daily 03:00"

pvesh create /config/datastore --name remote-aglsrv6b \
  --path /mnt/storage/remote/aglsrv6b/backups \
  --gc-schedule "daily 02:15" \
  --prune-schedule "daily 03:15"

pvesh create /config/datastore --name remote-fgsrv5 \
  --path /mnt/storage/remote/fgsrv5/backups \
  --gc-schedule "daily 02:30" \
  --prune-schedule "daily 03:30"

pvesh create /config/datastore --name remote-fgsrv6 \
  --path /mnt/storage/remote/fgsrv6/backups \
  --gc-schedule "daily 02:45" \
  --prune-schedule "daily 03:45"
```

**Remote Host PBS Client Configuration:**

```bash
# On AGLSRV6/AGLSRV6b (containers)
pct exec <PBS_CTID> -- proxmox-backup-client \
  backup-group create \
  --repository backup@pbs@100.x.x.x:remote-$(hostname)

# Add to Proxmox storage config
pvesm add pbs remote-pbs-aglsrv1 \
  --server 100.x.x.x \
  --datastore remote-$(hostname) \
  --username backup@pbs \
  --password $(cat /etc/pve/priv/pbs-token) \
  --fingerprint $(ssh root@100.x.x.x proxmox-backup-manager cert info | grep Fingerprint)
```

---

## 5. Security Architecture

### 5.1 Multi-Layer Security Model

```
┌─────────────────────────────────────────────────────────────────┐
│                    Security Layer Stack                         │
├─────────────────────────────────────────────────────────────────┤
│ Layer 5: Application   │ PBS Token Auth, SSH Keys             │
├────────────────────────┼──────────────────────────────────────┤
│ Layer 4: Protocol      │ iSCSI CHAP, NFS sec=sys/krb5p        │
├────────────────────────┼──────────────────────────────────────┤
│ Layer 3: Transport     │ TLS 1.3, IPSec (optional)            │
├────────────────────────┼──────────────────────────────────────┤
│ Layer 2: Network       │ Tailscale WireGuard Encryption       │
├────────────────────────┼──────────────────────────────────────┤
│ Layer 1: Host          │ Firewall (ufw), ACLs, SELinux        │
└────────────────────────┴──────────────────────────────────────┘
```

### 5.2 Authentication Mechanisms

**Tailscale ACLs (Zero-Trust Network):**

```json
{
  "acls": [
    {
      "action": "accept",
      "src": ["tag:storage-client"],
      "dst": ["tag:storage-server:2049,3260,8007,22"]
    },
    {
      "action": "accept",
      "src": ["tag:storage-server"],
      "dst": ["tag:storage-client:*"]
    }
  ],
  "tagOwners": {
    "tag:storage-server": ["admin@example.com"],
    "tag:storage-client": ["admin@example.com"]
  },
  "hosts": {
    "aglsrv1": "100.x.x.x",
    "aglsrv6": "100.98.108.66",
    "aglsrv6b": "100.98.119.51",
    "fgsrv5": "100.71.107.26",
    "fgsrv6": "100.83.51.9"
  }
}
```

**Host-Level Firewall (ufw on AGLSRV1):**

```bash
# Default deny
ufw default deny incoming
ufw default allow outgoing

# Tailscale interface
ufw allow in on tailscale0

# NFS
ufw allow from 100.0.0.0/8 to any port 2049 proto tcp
ufw allow from 100.0.0.0/8 to any port 111 proto tcp

# iSCSI
ufw allow from 100.0.0.0/8 to any port 3260 proto tcp

# PBS
ufw allow from 100.0.0.0/8 to any port 8007 proto tcp

# SSH
ufw allow from 100.0.0.0/8 to any port 22 proto tcp

ufw enable
```

### 5.3 Encryption Strategy

| Layer | Encryption Method | Key Management | Performance Impact |
|-------|-------------------|----------------|-------------------|
| Tailscale VPN | WireGuard (ChaCha20-Poly1305) | Tailscale-managed | ~5-10% overhead |
| NFS | sec=krb5p (optional) | Kerberos KDC | ~15-20% overhead |
| iSCSI | IPSec (optional) | Manual PSK/certs | ~10-15% overhead |
| PBS | TLS 1.3 + AES-256-GCM | PBS built-in | Minimal |

**Recommendation:** Rely on Tailscale encryption for VPN layer. Add protocol-level encryption only for highly sensitive data.

### 5.4 Access Control Matrix

```yaml
access_control:
  aglsrv6:
    nfs:
      - /mnt/storage/remote/aglsrv6/data: rw
      - /mnt/storage/shared/iso: ro
      - /mnt/storage/shared/templates: ro
    iscsi:
      - lun-aglsrv6-001: rw
    pbs:
      - datastore: remote-aglsrv6
        permissions: ["Datastore.Backup", "Datastore.Verify"]

  aglsrv6b:
    # Same structure

  fgsrv5:
    nfs:
      - /mnt/storage/remote/fgsrv5/data: rw
      - /mnt/storage/shared/iso: ro
    iscsi:
      - lun-fgsrv5-001: rw
    pbs:
      - datastore: remote-fgsrv5
        permissions: ["Datastore.Backup"]
```

---

## 6. High Availability & Failover Strategy

### 6.1 Redundancy Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   AGLSRV1 HA Configuration                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐          ┌─────────────┐                      │
│  │  Primary    │          │  Secondary  │                      │
│  │  Storage    │◄────────►│  Storage    │                      │
│  │  RAID-6/ZFS │  Mirror  │  RAID-6/ZFS │                      │
│  └──────┬──────┘          └──────┬──────┘                      │
│         │                        │                              │
│         │  Automatic Failover    │                              │
│         │  (via Pacemaker/DRBD)  │                              │
│         └────────┬───────────────┘                              │
│                  │                                               │
│         ┌────────▼────────┐                                     │
│         │  Virtual IP     │                                     │
│         │  100.x.x.x      │                                     │
│         └─────────────────┘                                     │
└─────────────────────────────────────────────────────────────────┘
```

### 6.2 Failure Scenarios & Recovery

| Failure Type | Detection Method | Recovery Action | RTO | RPO |
|--------------|------------------|-----------------|-----|-----|
| AGLSRV1 server down | Tailscale ping, service monitoring | Manual failover to secondary | 15 min | 0 (sync replication) |
| Tailscale VPN disruption | Connection timeout | Auto-reconnect, alerting | 2 min | 0 |
| NFS service crash | systemd watchdog | Auto-restart nfs-server | 30 sec | 0 |
| iSCSI target failure | Initiator timeout | Reconnect, switch to NFS | 2 min | 0 |
| Disk failure | SMART monitoring, RAID | Hot spare rebuild | 0 | 0 |
| Network partition | Split-brain detection | Fence secondary, alert admin | 5 min | 0 |

### 6.3 Automated Health Monitoring

```bash
#!/bin/bash
# /usr/local/bin/storage-health-check.sh

REMOTE_HOSTS=(
  "100.98.108.66:aglsrv6"
  "100.98.119.51:aglsrv6b"
  "100.71.107.26:fgsrv5"
  "100.83.51.9:fgsrv6"
)

check_service() {
  local host=$1
  local service=$2
  local port=$3

  if timeout 5 nc -zv "$host" "$port" &>/dev/null; then
    echo "✓ $service on $host:$port is reachable"
    return 0
  else
    echo "✗ $service on $host:$port is DOWN"
    return 1
  fi
}

# Check each remote host connectivity
for entry in "${REMOTE_HOSTS[@]}"; do
  IFS=':' read -r ip hostname <<< "$entry"

  # Tailscale connectivity
  if ! ping -c 3 -W 2 "$ip" &>/dev/null; then
    logger -t storage-health "CRITICAL: Cannot reach $hostname ($ip) via Tailscale"
    continue
  fi

  # NFS mount check
  if ! findmnt "/mnt/storage/remote/$hostname/data" &>/dev/null; then
    logger -t storage-health "WARNING: NFS export for $hostname not mounted"
  fi

  # iSCSI session check
  if ! iscsiadm -m session | grep -q "$ip"; then
    logger -t storage-health "INFO: No active iSCSI session for $hostname"
  fi
done

# Check local services
check_service localhost "NFS" 2049
check_service localhost "iSCSI" 3260
check_service localhost "PBS" 8007
```

### 6.4 Backup Strategy for Backup Server

**3-2-1 Backup Rule Implementation:**
- **3 copies**: Original + AGLSRV1 + offsite
- **2 different media**: Local disk + cloud (S3/Backblaze B2)
- **1 offsite**: Encrypted cloud backup

```bash
# PBS datastore to S3 sync (daily)
proxmox-backup-client backup \
  --repository backup@pbs@localhost:remote-aglsrv6 \
  --remote s3://backup-bucket/aglsrv6/ \
  --encrypt true \
  --compress zstd \
  --schedule "daily 04:00"
```

---

## 7. Performance Optimization

### 7.1 Network Tuning for Tailscale

```bash
# /etc/sysctl.d/99-tailscale-storage.conf
# TCP tuning for high-latency VPN
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.ipv4.tcp_rmem = 4096 87380 33554432
net.ipv4.tcp_wmem = 4096 65536 33554432
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq

# NFS optimization
sunrpc.tcp_slot_table_entries = 128
sunrpc.max_resvport = 1023
sunrpc.min_resvport = 650

# Apply changes
sysctl -p /etc/sysctl.d/99-tailscale-storage.conf
```

### 7.2 Storage Backend Optimization

**ZFS Configuration (if using ZFS):**

```bash
# Create optimized pool for network storage
zpool create -o ashift=12 \
  -O compression=lz4 \
  -O atime=off \
  -O xattr=sa \
  -O acltype=posixacl \
  storage mirror /dev/sda /dev/sdb

# Create datasets per remote host
zfs create -o recordsize=1M storage/remote
zfs create -o recordsize=1M storage/remote/aglsrv6
zfs create -o recordsize=128K storage/remote/aglsrv6/backups
zfs create -o recordsize=1M storage/iscsi

# Enable deduplication for PBS datastores only
zfs set dedup=on storage/remote/aglsrv6/backups
```

### 7.3 Expected Performance Benchmarks

| Protocol | Sequential Read | Sequential Write | Random Read | Random Write | Latency |
|----------|----------------|------------------|-------------|--------------|---------|
| NFS v4.2 | 250-400 MB/s | 200-350 MB/s | 15k-25k IOPS | 10k-20k IOPS | 5-15ms |
| iSCSI | 300-500 MB/s | 250-400 MB/s | 20k-35k IOPS | 15k-25k IOPS | 3-10ms |
| Local Disk | 500-1000 MB/s | 400-800 MB/s | 50k-100k IOPS | 30k-60k IOPS | 1-3ms |

*Note: Tailscale VPN adds 2-5ms latency overhead*

---

## 8. Implementation Phases

### Phase 1: Foundation (Week 1)
**Objective:** Establish base infrastructure

- [ ] Configure Tailscale on all hosts with ACLs
- [ ] Create directory structure on AGLSRV1
- [ ] Install and configure NFS server
- [ ] Set up host-level firewalls
- [ ] Deploy monitoring scripts
- [ ] Test basic connectivity

**Deliverables:**
- Tailscale mesh operational
- NFS exports configured and tested
- Monitoring framework in place

### Phase 2: Multi-Protocol Deployment (Week 2)
**Objective:** Deploy all storage protocols

- [ ] Configure iSCSI target and initiators
- [ ] Set up PBS datastores on AGLSRV1
- [ ] Configure PBS clients on remote hosts (AGLSRV6/6b)
- [ ] Implement authentication (CHAP, PBS tokens)
- [ ] Performance tuning and testing
- [ ] Document mount procedures

**Deliverables:**
- All protocols operational
- Performance benchmarks completed
- Client configuration templates

### Phase 3: Migration & Integration (Week 3)
**Objective:** Migrate existing data and integrate with Proxmox

- [ ] Migrate existing VM images to iSCSI/NFS
- [ ] Configure Proxmox storage backends
- [ ] Set up automated backup schedules
- [ ] Implement health monitoring alerts
- [ ] Create runbooks for common operations
- [ ] Train operations team

**Deliverables:**
- Data migration complete
- Proxmox integration tested
- Operations documentation

### Phase 4: Hardening & Optimization (Week 4)
**Objective:** Production readiness

- [ ] Security audit and hardening
- [ ] Load testing and optimization
- [ ] Implement failover procedures
- [ ] Set up alerting and dashboards
- [ ] Create disaster recovery plan
- [ ] Final acceptance testing

**Deliverables:**
- Production-ready system
- DR plan documented
- Acceptance sign-off

---

## 9. Operational Procedures

### 9.1 Daily Operations Checklist

```bash
#!/bin/bash
# /usr/local/bin/daily-storage-check.sh

echo "=== Daily Storage Health Check ==="
date

# 1. Check Tailscale connectivity
echo "Checking Tailscale status..."
tailscale status | grep -E "aglsrv6|fgsrv"

# 2. Verify NFS exports
echo "Verifying NFS exports..."
showmount -e localhost

# 3. Check iSCSI sessions
echo "Active iSCSI sessions:"
iscsiadm -m session

# 4. PBS datastore status
echo "PBS datastore usage:"
proxmox-backup-manager datastore list

# 5. Disk space
echo "Storage capacity:"
df -h /mnt/storage

# 6. Network throughput test
echo "Testing network performance to remote hosts..."
for host in 100.98.108.66 100.98.119.51; do
  iperf3 -c "$host" -t 10 -P 4 2>/dev/null | grep receiver
done

# 7. Check for errors in logs
echo "Recent storage errors:"
journalctl -u nfs-server -u iscsid -u proxmox-backup --since "24 hours ago" | grep -i error | tail -20
```

### 9.2 Emergency Procedures

**Scenario: AGLSRV1 Storage Server Failure**

```bash
# 1. Verify server is down
ping -c 3 100.x.x.x
ssh root@100.x.x.x "uptime" || echo "Server unreachable"

# 2. Notify all remote hosts
for host in aglsrv6 aglsrv6b fgsrv5 fgsrv6; do
  ssh root@$host "systemctl stop nfs-client.target; iscsiadm -m session -u"
done

# 3. Failover to secondary storage (if available)
# OR: Enable local storage mode on remote hosts
ssh root@aglsrv6 "pvesm set local-lvm --disable 0"

# 4. Investigate and repair AGLSRV1
# 5. Restore services in reverse order: disk -> network -> protocols
# 6. Reconnect remote hosts
```

---

## 10. Migration Patterns

### 10.1 VM Migration to Remote Storage

```bash
#!/bin/bash
# Migrate VM from local to remote NFS storage

VMID=$1
SOURCE_STORAGE="local-lvm"
TARGET_STORAGE="remote-nfs-aglsrv1"

# 1. Stop VM
qm stop $VMID

# 2. Move disk
qm move_disk $VMID scsi0 $TARGET_STORAGE --delete

# 3. Update VM config
qm set $VMID --scsi0 $TARGET_STORAGE:vm-$VMID-disk-0

# 4. Start VM
qm start $VMID

# 5. Verify
qm status $VMID
```

### 10.2 Live Migration with Storage Motion

```bash
# For running VMs (requires shared storage already mounted)
qm migrate $VMID $TARGET_NODE --online --with-local-disks --targetstorage $TARGET_STORAGE
```

---

## 11. Monitoring & Alerting

### 11.1 Key Metrics to Monitor

```yaml
monitoring_metrics:
  availability:
    - tailscale_connection_status
    - nfs_server_uptime
    - iscsi_target_availability
    - pbs_api_responsiveness

  performance:
    - nfs_throughput (MB/s)
    - iscsi_latency (ms)
    - disk_io_utilization (%)
    - network_bandwidth_usage (%)

  capacity:
    - filesystem_usage (%)
    - iscsi_lun_utilization (%)
    - pbs_datastore_usage (%)
    - inode_usage (%)

  security:
    - failed_authentication_attempts
    - unauthorized_access_attempts
    - iscsi_chap_failures

  reliability:
    - disk_smart_errors
    - raid_degradation_events
    - network_packet_loss (%)
    - service_restart_count
```

### 11.2 Alert Thresholds

```yaml
alert_rules:
  critical:
    - condition: "tailscale_connection_down > 5min"
      action: "Page on-call engineer"
    - condition: "filesystem_usage > 90%"
      action: "Page storage admin"
    - condition: "raid_array_degraded == true"
      action: "Page on-call engineer"

  warning:
    - condition: "filesystem_usage > 80%"
      action: "Email storage admin"
    - condition: "iscsi_latency > 50ms"
      action: "Email network team"
    - condition: "nfs_throughput < 100MB/s"
      action: "Ticket for investigation"

  info:
    - condition: "pbs_backup_completed"
      action: "Log to dashboard"
```

---

## 12. Cost & Resource Analysis

### 12.1 Resource Requirements

**AGLSRV1 Server Specifications:**
- **CPU**: 8+ cores (for NFS, iSCSI, PBS)
- **RAM**: 32GB minimum (16GB for OS/services, 16GB for ZFS ARC)
- **Storage**:
  - Boot: 2x 500GB SSD (RAID-1)
  - Data: 8x 4TB HDD (RAID-6 or ZFS RAIDZ2) = ~24TB usable
  - Cache: 2x 500GB NVMe (ZFS L2ARC/SLOG)
- **Network**:
  - 10GbE NIC for local network
  - Tailscale VPN (uses existing interface)

**Bandwidth Requirements:**
- Per remote host: 100-500 Mbps sustained
- Total aggregate: 1-2 Gbps peak
- Tailscale overhead: ~5-10%

### 12.2 Estimated Costs

| Component | Annual Cost | Notes |
|-----------|-------------|-------|
| Tailscale Business | $120/user | Zero-config VPN mesh |
| AGLSRV1 Hardware | $0 (existing) | One-time capital expense |
| Power/Cooling | $500-800 | 300W 24/7 @ $0.12/kWh |
| Internet Bandwidth | $0 | Included in existing plan |
| **Total Annual** | **$620-920** | Operational costs only |

**Cost Savings vs. Alternatives:**
- Traditional site-to-site VPN: -$2,400/year (hardware, licensing)
- Cloud storage equivalent: -$4,800/year (24TB S3 Standard)
- Managed backup service: -$3,600/year (PBS features)

**ROI Timeline:** 3-6 months

---

## 13. Disaster Recovery Plan

### 13.1 Backup of Backup Server

```bash
# Weekly full PBS metadata backup
proxmox-backup-manager backup \
  --target /mnt/offsite-usb/pbs-metadata/ \
  --compress zstd

# Daily incremental to cloud
rclone sync /mnt/storage/remote/ \
  remote-s3:backup-bucket/aglsrv1/ \
  --transfers 8 \
  --fast-list \
  --exclude "*.tmp" \
  --log-file /var/log/rclone-backup.log
```

### 13.2 Recovery Scenarios

**Scenario 1: Complete AGLSRV1 Loss**

1. Provision new server
2. Install Proxmox Backup Server
3. Restore from offsite backup
4. Reconfigure Tailscale
5. Mount remote exports
6. Reconnect clients (1-2 hours RTO)

**Scenario 2: Data Corruption**

1. Identify affected datastore
2. Stop all backup jobs to that datastore
3. Restore from ZFS snapshot or PBS verify
4. Resume operations (15-30 min RTO)

---

## 14. Security Compliance

### 14.1 Compliance Checklist

- [x] **Encryption in transit**: Tailscale WireGuard
- [x] **Encryption at rest**: Optional LUKS on AGLSRV1
- [x] **Access control**: Tailscale ACLs + protocol-level auth
- [x] **Audit logging**: systemd journal + PBS audit logs
- [x] **Network segmentation**: Tailscale subnet router isolation
- [x] **Patch management**: Automated security updates
- [x] **Backup verification**: PBS verify jobs
- [x] **Disaster recovery testing**: Quarterly DR drills

### 14.2 Audit Logging

```bash
# Enable comprehensive audit logging
auditctl -w /mnt/storage/remote -p wa -k remote-storage-access
auditctl -w /etc/exports -p wa -k nfs-config-change
auditctl -w /etc/iscsi/ -p wa -k iscsi-config-change

# PBS audit log
tail -f /var/log/proxmox-backup/api/access.log
```

---

## 15. Future Enhancements

### 15.1 Planned Improvements (6-12 months)

1. **Active-Active HA**: Deploy second AGLSRV1 with Pacemaker cluster
2. **NVMe-oF**: Migrate from iSCSI to NVMe over Fabrics for lower latency
3. **S3 Gateway**: Expose PBS datastores via S3-compatible API
4. **AI-Powered Optimization**: Machine learning for workload prediction
5. **Edge Caching**: Deploy local cache on remote hosts for frequently accessed data
6. **Global Load Balancing**: GeoDNS for multi-region Tailscale mesh

### 15.2 Technology Roadmap

```
Q1 2025: Phase 1-4 Implementation
Q2 2025: Production stabilization, monitoring refinement
Q3 2025: HA implementation, NVMe-oF pilot
Q4 2025: S3 gateway, edge caching deployment
Q1 2026: Multi-region expansion
```

---

## Appendix A: Configuration Templates

See `/root/host-admin/config/templates/` for:
- `nfs-exports.conf.template`
- `iscsi-target.conf.template`
- `pbs-datastore.conf.template`
- `tailscale-acl.json.template`
- `fstab.template`
- `monitoring-dashboard.json.template`

---

## Appendix B: Troubleshooting Guide

### Common Issues

**Issue: NFS mount hangs**
```bash
# Check network connectivity
ping 100.x.x.x
# Check NFS service
systemctl status nfs-server
# Force unmount
umount -f -l /mnt/aglsrv1/data
# Remount
mount -a
```

**Issue: iSCSI session drops**
```bash
# Check initiator logs
journalctl -u iscsid -f
# Reconnect
iscsiadm -m node --login
# Verify multipath
multipath -ll
```

**Issue: PBS backup fails**
```bash
# Check datastore status
proxmox-backup-manager datastore status
# Verify disk space
df -h /mnt/storage/remote/*/backups
# Check garbage collection
proxmox-backup-manager garbage-collect --datastore remote-aglsrv6
```

---

## Document Change Log

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-14 | System Architect Agent | Initial architecture design |

---

## Approval & Sign-off

**Architecture Review Board:**
- [ ] System Architect: _________________ Date: _______
- [ ] Network Engineer: _________________ Date: _______
- [ ] Security Officer: _________________ Date: _______
- [ ] Operations Manager: _______________ Date: _______

---

**END OF ARCHITECTURE DOCUMENT**
