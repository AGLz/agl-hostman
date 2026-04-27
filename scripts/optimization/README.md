# Infrastructure Optimization Scripts

Comprehensive performance optimization tools for AGL infrastructure.

## 📋 Table of Contents

1. [Overview](#overview)
2. [Scripts](#scripts)
3. [Usage](#usage)
4. [Configuration Templates](#configuration-templates)
5. [Monitoring](#monitoring)
6. [Best Practices](#best-practices)

---

## 🎯 Overview

This directory contains optimization scripts for:
- **Docker containers** (CT179, CT183, CT202)
- **WireGuard mesh network** (14 active nodes)
- **NFS/SSHFS storage** (6.0TB over WireGuard)
- **Performance benchmarking** and monitoring

### Target Infrastructure

- **AGLSRV1**: Main Proxmox host (68 containers)
- **AGLSRV6**: Secondary Proxmox host (11 containers)
- **WireGuard Mesh**: 14 nodes (10.6.0.0/24)
- **Storage**: NFS (1.2TB) + SSHFS (4.8TB)

---

## 📜 Scripts

### 1. Docker Container Optimization

**File**: `optimize-docker-containers.sh`

**Purpose**: Optimize Docker daemon and container configurations

**Features**:
- Docker daemon settings optimization
- Resource limits for containers
- Network optimization
- Storage driver tuning
- Cleanup of unused resources

**Usage**:
```bash
# Run on CT179, CT183, or any host with Docker
sudo ./optimize-docker-containers.sh
```

**What it does**:
1. Optimizes `/etc/docker/daemon.json`
2. Configures resource limits for Archon containers
3. Tunes Docker networks for WireGuard (MTU 1420)
4. Cleans up unused images, containers, volumes
5. Restarts Docker daemon to apply changes

**Recommendations**:
- Run monthly for cleanup
- Review logs after optimization
- Monitor container performance with `docker stats`

---

### 2. WireGuard Mesh Optimization

**File**: `optimize-wireguard-mesh.sh`

**Purpose**: Optimize WireGuard configuration for maximum performance

**Features**:
- Kernel network parameter tuning
- MTU optimization (1420 bytes)
- TCP BBR congestion control
- Connection tracking optimization
- DNS caching configuration

**Usage**:
```bash
# Run on any WireGuard node
sudo ./optimize-wireguard-mesh.sh
```

**What it does**:
1. Creates `/etc/sysctl.d/99-wireguard-optimization.conf`
2. Sets MTU to 1420 (optimal for WireGuard)
3. Enables TCP Fast Open and BBR
4. Increases network buffer sizes
5. Configures DNS caching
6. Tests peer connectivity and latency

**Expected improvements**:
- **Latency**: 5-15% reduction
- **Throughput**: 10-20% increase
- **Stability**: Fewer handshake failures

---

### 3. NFS/SSHFS Storage Optimization

**File**: `optimize-nfs-storage.sh`

**Purpose**: Optimize network storage mount performance

**Features**:
- NFS mount options tuning
- SSHFS compression and caching
- Read-ahead optimization
- RPC slot table expansion
- Performance testing

**Usage**:
```bash
# Run on AGLSRV1 (Proxmox host)
sudo ./optimize-nfs-storage.sh
```

**What it does**:
1. Backs up `/etc/fstab`
2. Updates NFS mount options (rsize=131072, wsize=131072)
3. Optimizes SSHFS with caching and compression
4. Configures NFS RPC parameters
5. Tests storage I/O performance

**Mount optimizations**:

**NFS**:
```
rw,sync,hard,intr,rsize=131072,wsize=131072,timeo=600,retrans=2,noresvport,_netdev,vers=4.2,nordirplus
```

**SSHFS**:
```
allow_other,compression=yes,cache=yes,cache_timeout=115200,kernel_cache,large_read,max_read=131072,Ciphers=aes128-gcm@openssh.com,reconnect
```

**Note**: Script updates `/etc/fstab` but does NOT remount automatically. Manual remount or reboot required.

---

## 📁 Configuration Templates

### Docker Compose (Optimized)

**File**: `../../config/optimization/docker-compose.optimized.yml`

**Features**:
- Resource limits and reservations
- Health checks with proper timeouts
- Optimized logging (10MB, 3 files)
- Network MTU for WireGuard (1420)
- Restart policies

**Usage**:
```bash
# Use as override for existing compose file
cp ../../config/optimization/docker-compose.optimized.yml /root/Archon/docker-compose.override.yml
cd /root/Archon && docker compose up -d
```

---

### WireGuard Configuration (Optimized)

**File**: `../../config/optimization/wireguard-optimized.conf`

**Features**:
- MTU 1420 (optimal for WireGuard)
- PersistentKeepalive 25 seconds
- No PresharedKey (LXC compatibility)
- DNS configuration

**Usage**:
```bash
# Use as template for new WireGuard nodes
cp ../../config/optimization/wireguard-optimized.conf /etc/wireguard/wg0.conf

# Edit with your keys and IP
nano /etc/wireguard/wg0.conf

# Enable and start
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0
```

---

### NFS/SSHFS Mounts (Optimized)

**File**: `../../config/optimization/nfs-fstab.conf`

**Features**:
- NFSv4.2 with optimal buffer sizes
- SSHFS with compression and caching
- Proper timeout and retry settings
- Automount support

**Usage**:
```bash
# Backup existing fstab
cp /etc/fstab /etc/fstab.backup

# Append optimized mounts
cat ../../config/optimization/nfs-fstab.conf >> /etc/fstab

# Mount all
mount -a
```

---

## 📊 Monitoring

### Infrastructure Monitor

**File**: `../../src/monitoring/InfrastructureMonitor.js`

**Usage**:
```javascript
const InfrastructureMonitor = require('./src/monitoring/InfrastructureMonitor');

const monitor = new InfrastructureMonitor({
  enableRealtime: true,
  metricsInterval: 5000,
  healthCheckInterval: 30000
});

monitor.start();

// Get dashboard
monitor.on('metrics:collected', () => {
  const dashboard = monitor.getDashboard();
  console.log(dashboard);
});

// Get recommendations
const recommendations = monitor.getOptimizationRecommendations();
console.log(recommendations);
```

**Metrics collected**:
- WireGuard peer status and latency
- NFS/SSHFS mount health and I/O latency
- Docker container CPU/memory usage
- Service health (Archon, Dokploy, Ollama)
- Network throughput and errors

---

### Performance Benchmark

**File**: `../../src/utils/PerformanceBenchmark.js`

**Usage**:
```javascript
const PerformanceBenchmark = require('./src/utils/PerformanceBenchmark');

const benchmark = new PerformanceBenchmark({
  outputDir: '/tmp/performance-benchmarks',
  iterations: 3
});

// Run all benchmarks
const results = await benchmark.runAll();

// Compare with baseline
const baseline = '/tmp/performance-benchmarks/baseline.json';
await benchmark.compareWithBaseline(baseline);
```

**Benchmarks**:
- Network latency and bandwidth
- Storage read/write performance
- Docker container resource usage
- WireGuard handshake and transfer stats
- Service response times

---

## 🎯 Best Practices

### 1. Pre-Optimization Checklist

- [ ] Backup configurations (`/etc/fstab`, `/etc/wireguard/*.conf`)
- [ ] Document current performance metrics
- [ ] Schedule during maintenance window
- [ ] Test on non-critical system first

### 2. Optimization Sequence

1. **Kernel parameters** (requires reboot)
2. **WireGuard configuration** (minimal downtime)
3. **Storage mounts** (may cause brief interruption)
4. **Docker containers** (service restart required)

### 3. Verification Steps

After each optimization:
```bash
# WireGuard
wg show wg0
ping -c 10 10.6.0.5

# Storage
df -h | grep -E "wg|sshfs"
mount | grep -E "nfs|fuse"

# Docker
docker stats
docker compose ps

# Services
curl http://192.168.0.183:8051/mcp
```

### 4. Rollback Procedures

**WireGuard**:
```bash
# Restore original config
cp /etc/wireguard/wg0.conf.backup /etc/wireguard/wg0.conf
systemctl restart wg-quick@wg0
```

**Storage**:
```bash
# Restore fstab
cp /etc/fstab.backup-YYYYMMDD /etc/fstab
umount /mnt/pve/<storage>
mount -a
```

**Docker**:
```bash
# Restore daemon config
cp /etc/docker/daemon.json.backup-YYYYMMDD /etc/docker/daemon.json
systemctl restart docker
```

### 5. Monitoring After Optimization

**First 24 hours**:
- Monitor system logs: `journalctl -f`
- Check WireGuard handshakes: `wg show wg0 latest-handshakes`
- Verify mount health: `df -h && mount | grep -E "nfs|fuse"`
- Watch Docker stats: `docker stats`

**First week**:
- Run performance benchmarks daily
- Compare with baseline metrics
- Monitor for errors or degradation
- Document improvements

**Ongoing**:
- Monthly performance reviews
- Quarterly optimization tune-ups
- Regular cleanup of Docker resources
- Keep configurations in version control

---

## 🔧 Troubleshooting

### WireGuard Issues

**High Latency**:
```bash
# Check MTU
ip link show wg0 | grep mtu

# Test path MTU
ping -M do -s 1400 10.6.0.5

# Verify kernel params
sysctl net.core.rmem_max
```

**Handshake Failures**:
```bash
# Check config (no PresharedKey in LXC!)
cat /etc/wireguard/wg0.conf

# Test connectivity
wg show wg0 latest-handshakes
ping 10.6.0.5
```

### Storage Issues

**Stale Mounts**:
```bash
# Force unmount
umount -f /mnt/pve/<storage>

# Remount
mount -a

# Verify
mountpoint /mnt/pve/<storage>
```

**Slow I/O**:
```bash
# Test performance
dd if=/dev/zero of=/mnt/pve/<storage>/test bs=1M count=100

# Check mount options
mount | grep <storage>

# Verify network path
ping 10.6.0.X
```

### Docker Issues

**High Resource Usage**:
```bash
# Check stats
docker stats

# Review logs
docker compose logs -f

# Restart services
docker compose restart
```

**Network Issues**:
```bash
# Check networks
docker network ls
docker network inspect <network>

# Verify MTU
ip link show br-<network>
```

---

## 📖 References

- [WireGuard Performance](https://www.wireguard.com/performance/)
- [Docker Performance](https://docs.docker.com/config/containers/resource_constraints/)
- [NFS Best Practices](https://wiki.archlinux.org/title/NFS)
- [SSHFS Performance](https://github.com/libfuse/sshfs)

---

**Last Updated**: 2025-11-02
**Maintained By**: CODER Agent (Hive Mind Swarm)
**Infrastructure**: AGL-HOSTMAN Project
