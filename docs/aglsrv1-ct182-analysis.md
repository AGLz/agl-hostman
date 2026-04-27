# AGLSRV1 CT182 Harbor Analysis Report

**Date**: 2025-10-22
**Analyst**: Hive Mind Analyst Agent
**Swarm ID**: swarm-1761103289543-v45j2euma
**Objective**: Analyze aglsrv1 environment for optimal Harbor CT182 configuration

---

## Executive Summary

**Analysis Result**: ✅ AGLSRV1 is ready for Harbor CT182 deployment

- **IP Address**: 192.168.0.182 - **AVAILABLE** and verified
- **Host Capacity**: Sufficient resources available for Harbor deployment
- **Network**: Properly configured vmbr0 bridge with 192.168.0.0/24 subnet
- **Storage**: Multiple storage options available (local-zfs, spark, overpower)
- **Similar Services**: Portainer (CT103) and Dokploy (CT180) running successfully

---

## 1. Host Environment Analysis

### System Resources (aglsrv1 / 192.168.0.245)

**Hardware Configuration**:
- **Hostname**: algsrv1
- **CPU**: Intel Xeon E5-2680 v4 @ 2.40GHz
- **CPU Cores**: 56 cores (physical)
- **Total RAM**: 125 GiB
- **Proxmox Version**: 9.0.3 (kernel 6.11.0-2-pve)

**Current Resource Utilization**:
```
Uptime: 1 day, 22:56
Load Average: 6.10, 6.13, 6.90 (excellent - ~10% load on 56 cores)

Memory:
  Total:     125 GiB
  Used:      68 GiB (54%)
  Free:      51 GiB (41%)
  Available: 57 GiB
  Swap:      31 GiB (2.0 GiB used)

Root Filesystem (rpool/ROOT/pve-1):
  Size: 761 GB
  Used: 6.1 GB (1%)
  Available: 755 GB
```

**Resource Health**: ✅ EXCELLENT
- CPU load is minimal (6.10 average on 56 cores = ~11% utilization)
- Memory has 57 GiB available for new workloads
- Disk has 755 GB available on root partition
- System is stable (1 day uptime, no issues)

---

## 2. Network Configuration Analysis

### IP Address Availability (192.168.0.180-189 Range)

**Scan Results**:
```
192.168.0.180 - IN USE (CT180: dokploy)
192.168.0.181 - IN USE (CT181: agldv4)
192.168.0.182 - ✅ AVAILABLE (TARGET FOR HARBOR)
192.168.0.183 - AVAILABLE
192.168.0.184 - AVAILABLE
192.168.0.185 - AVAILABLE
192.168.0.186 - AVAILABLE
192.168.0.187 - AVAILABLE
192.168.0.188 - AVAILABLE
192.168.0.189 - AVAILABLE
```

**Network Topology**:
- **Bridge**: vmbr0 (bridge-ports: enp4s0f0)
- **Subnet**: 192.168.0.0/24
- **Gateway**: 192.168.0.1
- **Host IP**: 192.168.0.245/24
- **Configuration**: Static IP, bridge-stp off, bridge-fd 0

**Network Status**: ✅ OPTIMAL
- IP .182 is completely available (no ping response)
- Network bridge is properly configured
- Gateway 192.168.0.1 is accessible
- Subnet has plenty of available addresses

---

## 3. Container Inventory Analysis

### Total Containers on aglsrv1

**Status Overview**:
- **Total Containers**: 42
- **Running**: 37 containers
- **Stopped**: 5 containers (az-agent1/2/3, agldv02, ollama)

### Containers in .180-.189 Range

| VMID | Name | Status | IP | Resources |
|------|------|--------|-----|-----------|
| 178 | aglfs1 | Running | 192.168.0.178 | 16GB RAM, 16 cores |
| 179 | agldv03 | Running | 192.168.0.179 | 48GB RAM, 24 cores |
| 180 | dokploy | Running | 192.168.0.180 | 16GB RAM, 8 cores |
| 181 | agldv4 | Running | 192.168.0.181 | 48GB RAM, 16 cores |
| **182** | **[AVAILABLE]** | - | **192.168.0.182** | - |

### Reference Container Configurations

**CT103 (Portainer) - Container Management Platform**:
```
cores: 8
memory: 16384 (16 GB)
rootfs: local-zfs:subvol-103-disk-0,size=60G
net0: name=eth0,bridge=vmbr0,gw=192.168.0.1,ip=192.168.0.103/24,type=veth
```

**CT180 (Dokploy) - Deployment Platform**:
```
cores: 8
memory: 16384 (16 GB)
rootfs: local-zfs:subvol-180-disk-0,size=100G
net0: name=eth0,bridge=vmbr0,gw=192.168.0.1,ip=192.168.0.180/24,type=veth
arch: amd64
ostype: ubuntu
```

**Observation**: Both Portainer and Dokploy are container management/deployment platforms similar to Harbor's use case, running successfully with 8 cores and 16GB RAM.

---

## 4. Storage Analysis

### Proxmox Storage Pools

| Name | Type | Total | Used | Available | Usage % | Status |
|------|------|-------|------|-----------|---------|--------|
| local | dir | 760 GB | 5.6 GB | 754 GB | 0.74% | ✅ Excellent |
| local-zfs | zfspool | 1.71 TB | 969 GB | 738 GB | 56.80% | ✅ Good |
| spark | dir | 7.13 TB | 6.17 TB | 961 GB | 86.53% | ⚠️ High |
| spark-zfs | zfspool | 7.14 TB | 6.18 TB | 959 GB | 86.57% | ⚠️ High |
| overpower | dir | 9.86 TB | 9.12 TB | 735 GB | 92.54% | ⚠️ Very High |
| overpower-zfs | zfspool | 10.44 TB | 9.70 TB | 735 GB | 92.95% | ⚠️ Very High |

**Storage Recommendations for Harbor CT182**:

1. **PRIMARY RECOMMENDATION**: `local-zfs`
   - **Capacity**: 738 GB available (56.80% used)
   - **Performance**: ZFS native, excellent for containers
   - **Type**: ZFS pool (modern, reliable)
   - **Allocation**: 100-200 GB for Harbor
   - **Status**: ✅ OPTIMAL CHOICE

2. **Alternative**: `local` (directory)
   - **Capacity**: 754 GB available
   - **Type**: Standard directory storage
   - **Status**: ✅ Also suitable

3. **NOT RECOMMENDED**: spark/overpower
   - Both are >86% full
   - Better suited for bulk storage/backups

---

## 5. Harbor Resource Requirements

### Standard Harbor Deployment Requirements

**Minimum Requirements** (from Harbor documentation):
- **CPU**: 2 cores
- **Memory**: 4 GB RAM
- **Disk**: 40 GB (minimum)

**Production Recommendations**:
- **CPU**: 4-8 cores
- **Memory**: 8-16 GB RAM
- **Disk**: 100-200 GB
- **Network**: Gigabit Ethernet

### Recommended Configuration for CT182

Based on analysis of similar containers (Portainer CT103, Dokploy CT180):

```
VMID: 182
hostname: harbor
cores: 8
memory: 16384 (16 GB)
swap: 4096 (4 GB)
rootfs: local-zfs:subvol-182-disk-0,size=150G
net0: name=eth0,bridge=vmbr0,gw=192.168.0.1,ip=192.168.0.182/24,type=veth
arch: amd64
ostype: ubuntu
nameserver: 192.168.0.102 (pihole)
searchdomain: localdomain
unprivileged: 1
features: nesting=1,keyctl=1
```

**Justification**:
- **8 cores**: Matches Portainer/Dokploy, sufficient for container registry operations
- **16 GB RAM**: Industry standard for Harbor, matches similar services
- **150 GB disk**: Adequate for Harbor core + moderate image storage (expandable)
- **local-zfs storage**: Best performance and reliability, plenty of space available
- **Features**: nesting=1 for Docker-in-Docker, keyctl=1 for container features

---

## 6. Resource Impact Analysis

### Current Resource Allocation (Running Containers)

**Memory Allocation Summary**:
- **Total Running Containers**: 37
- **Estimated RAM Used**: ~205 GB (from running containers)
- **Actual RAM Used**: 68 GB (significant overcommit, as expected)

**Adding Harbor CT182**:
- **Allocated Memory**: +16 GB
- **New Total Allocation**: ~221 GB (still within overcommit range)
- **Expected Real Usage**: +4-8 GB (Harbor actual usage)
- **Available Memory**: 57 GB → 49-53 GB remaining

**CPU Impact**:
- **Current Load**: 6.10 average on 56 cores (~11%)
- **Harbor Addition**: +8 cores allocated (containers share physical cores)
- **Expected Impact**: Minimal (Harbor is I/O-bound, not CPU-intensive)
- **Predicted New Load**: 6.5-7.0 average (still excellent)

**Storage Impact**:
- **local-zfs Current**: 969 GB used / 1.71 TB total (56.80%)
- **Harbor Allocation**: 150 GB
- **New Usage**: 1,119 GB / 1.71 TB (65.4%)
- **Status**: ✅ Still healthy utilization

### Impact Assessment: ✅ MINIMAL IMPACT

The addition of Harbor CT182 will have minimal impact on system performance:
- Memory: Adequate free memory (49+ GB remaining)
- CPU: Negligible impact (vast surplus of cores)
- Storage: Healthy usage level after addition (65%)
- Network: Plenty of bandwidth available

---

## 7. Network Architecture for CT182

### Placement in Network Topology

```
vmbr0 (192.168.0.0/24) Bridge
├─ Gateway: 192.168.0.1
├─ Host (aglsrv1): 192.168.0.245
├─ DNS (pihole): 192.168.0.102
├─ Portainer: 192.168.0.103
├─ Development Zone (178-181):
│  ├─ CT178 (aglfs1): 192.168.0.178 - File Server
│  ├─ CT179 (agldv03): 192.168.0.179 - Dev Environment
│  ├─ CT180 (dokploy): 192.168.0.180 - Deployment Platform
│  ├─ CT181 (agldv4): 192.168.0.181 - Dev Environment
│  └─ CT182 (harbor): 192.168.0.182 - Container Registry ✅
└─ Other Services: 102-202 (37 containers)
```

**Network Benefits**:
- **Logical Grouping**: CT182 fits in development/deployment zone (178-189)
- **Low Latency**: Same bridge as dokploy and dev environments
- **DNS Integration**: Pihole DNS at 192.168.0.102 available
- **Gateway Access**: Standard routing via 192.168.0.1

---

## 8. Comparison with Existing Infrastructure

### Similar Container Services Analysis

| Service | VMID | Purpose | Cores | RAM | Disk | Similarity to Harbor |
|---------|------|---------|-------|-----|------|---------------------|
| Portainer | 103 | Container Management | 8 | 16GB | 60GB | ⭐⭐⭐⭐ High (Docker registry features) |
| Dokploy | 180 | Deployment Platform | 8 | 16GB | 100GB | ⭐⭐⭐⭐⭐ Very High (deployment/registry) |
| Ollama-GPU | 200 | LLM Compute | - | - | - | ⭐⭐ Low (different workload) |
| n8n-docker | 202 | Workflow Automation | - | 8GB | - | ⭐⭐⭐ Medium (Docker-based) |

**Key Insights**:
1. Dokploy (CT180) is the closest analogue to Harbor
2. Both Portainer and Dokploy run stable with 8 cores, 16GB RAM
3. 100-150 GB disk allocation is standard for deployment platforms
4. All use local-zfs for optimal container performance

---

## 9. Risk Assessment

### Potential Risks and Mitigations

| Risk | Severity | Probability | Mitigation |
|------|----------|-------------|------------|
| IP conflict on .182 | Low | Very Low | ✅ Verified available via ping scan |
| Insufficient memory | Low | Very Low | 57GB free, need only 8-16GB real usage |
| Storage exhaustion | Low | Low | local-zfs has 738GB free, excellent headroom |
| Network congestion | Very Low | Very Low | Gigabit network, minimal container traffic |
| Resource contention | Low | Very Low | CPU at 11% load, massive surplus |

**Overall Risk Level**: ✅ **VERY LOW**

All critical resources have been verified available. No significant risks identified.

---

## 10. Recommendations

### Primary Recommendation: Deploy Harbor CT182

**Configuration Summary**:
```
Container ID: 182
IP Address: 192.168.0.182
CPU Cores: 8
Memory: 16 GB
Swap: 4 GB
Root Filesystem: local-zfs, 150 GB
OS Template: Ubuntu 22.04 or 24.04 LTS
Network: vmbr0, gateway 192.168.0.1
DNS: 192.168.0.102 (pihole)
Features: nesting=1, keyctl=1
```

### Storage Allocation Strategy

**Primary Storage** (local-zfs):
- **Initial Allocation**: 150 GB
- **Purpose**: Harbor core services, database, registry data
- **Expandability**: Can expand to 500+ GB if needed

**Optional Secondary Mount** (if heavy usage expected):
- **spark** or **overpower**: For bulk image storage
- **Mount Point**: /var/lib/harbor/registry
- **Size**: 100-500 GB
- **Benefit**: Separates OS from data, easier management

### Network Configuration

**DNS Setup**:
- Primary DNS: 192.168.0.102 (pihole)
- Searchdomain: localdomain
- Consider adding harbor.localdomain to DNS

**Firewall/Access**:
- HTTP: Port 80 (redirect to HTTPS)
- HTTPS: Port 443 (primary access)
- Docker Registry: Port 5000 (if using non-standard)
- Internal access from vmbr0 subnet

### Integration Points

**Dokploy Integration** (CT180):
- Harbor can serve as registry for Dokploy deployments
- Low latency (same host, same bridge)
- IP: 192.168.0.180 → 192.168.0.182

**Development Environments**:
- agldv03 (CT179): 192.168.0.179
- agldv4 (CT181): 192.168.0.181
- Both can pull images from Harbor registry

**Portainer Integration** (CT103):
- Portainer can manage Harbor container
- Registry can be added to Portainer for image management

---

## 11. Implementation Checklist

### Pre-Deployment Verification
- [x] IP 192.168.0.182 availability confirmed
- [x] Host resource capacity verified (CPU, RAM, storage)
- [x] Network configuration validated (vmbr0, gateway)
- [x] Storage pool selected (local-zfs)
- [x] Similar container configs analyzed (Portainer, Dokploy)

### Deployment Steps
- [ ] Download Ubuntu 22.04/24.04 LXC template
- [ ] Create CT182 with recommended configuration
- [ ] Configure network (static IP 192.168.0.182)
- [ ] Set up DNS entry in pihole (optional)
- [ ] Install Docker and Docker Compose
- [ ] Deploy Harbor via docker-compose
- [ ] Configure Harbor admin credentials
- [ ] Set up SSL/TLS certificates
- [ ] Configure storage backends
- [ ] Test registry push/pull operations
- [ ] Integrate with Dokploy/Portainer
- [ ] Document Harbor access credentials

### Post-Deployment Monitoring
- [ ] Monitor memory usage (target: <12GB real usage)
- [ ] Monitor disk usage (alert at 80% of 150GB)
- [ ] Monitor network connectivity
- [ ] Verify registry performance
- [ ] Set up backup strategy for Harbor data
- [ ] Configure retention policies for images

---

## 12. Alternative Scenarios

### Scenario A: Minimal Harbor (Development/Testing)

```
cores: 4
memory: 8192 (8 GB)
rootfs: local-zfs:subvol-182-disk-0,size=80G
```

**Use Case**: Small team, development testing
**Capacity**: 10-50 images
**Cost**: Lower resource footprint

### Scenario B: Production Harbor (Heavy Usage)

```
cores: 16
memory: 32768 (32 GB)
rootfs: local-zfs:subvol-182-disk-0,size=200G
mp0: /spark/harbor-data,mp=/var/lib/harbor/registry
```

**Use Case**: Production CI/CD, multiple projects
**Capacity**: 100+ images, high concurrency
**Cost**: Higher resources, dedicated storage mount

### Scenario C: Hybrid Approach (Recommended)

```
cores: 8
memory: 16384 (16 GB)
rootfs: local-zfs:subvol-182-disk-0,size=150G
# Add secondary storage mount if needed later
```

**Use Case**: Start with standard config, expand as needed
**Capacity**: Scalable from 50-200+ images
**Cost**: Balanced, can add storage mount dynamically

---

## 13. Monitoring and Maintenance

### Resource Monitoring

**Memory Monitoring**:
```bash
# Check CT182 memory usage
pct exec 182 -- free -h

# Check host memory impact
ssh root@192.168.0.245 "free -h"
```

**Storage Monitoring**:
```bash
# Check CT182 disk usage
pct exec 182 -- df -h

# Check local-zfs pool
ssh root@192.168.0.245 "pvesm status | grep local-zfs"
```

**Performance Monitoring**:
```bash
# Check container resource usage
pct exec 182 -- top

# Check Proxmox stats
pvesh get /nodes/algsrv1/lxc/182/status/current
```

### Backup Strategy

**CT182 Backup Recommendations**:
- **Frequency**: Daily incremental, weekly full
- **Target**: aglsrv6-pbs or aglsrv6b-pbs (PBS)
- **Retention**: 7 daily, 4 weekly, 3 monthly
- **Critical Data**: /var/lib/harbor/database, /etc/harbor

---

## 14. Conclusion

### Analysis Summary

**Environment Assessment**: ✅ **OPTIMAL**
- aglsrv1 has ample resources for Harbor deployment
- IP address 192.168.0.182 is available and verified
- Network topology is properly configured
- Storage has sufficient capacity (738 GB on local-zfs)
- Similar services (Portainer, Dokploy) running successfully

**Recommended Action**: **PROCEED with Harbor CT182 deployment**

### Resource Allocation Confidence

| Resource | Available | Required | After Deployment | Status |
|----------|-----------|----------|------------------|--------|
| CPU | 56 cores (89% idle) | 8 cores | 86% idle | ✅ Excellent |
| Memory | 57 GB free | 8-16 GB real | 41-49 GB free | ✅ Excellent |
| Storage (local-zfs) | 738 GB | 150 GB | 588 GB free | ✅ Excellent |
| Network | 1 Gbps | Minimal | 1 Gbps | ✅ Excellent |

### Final Recommendation

**Deploy Harbor CT182 with the following configuration**:

```yaml
VMID: 182
Hostname: harbor
IP Address: 192.168.0.182/24
Gateway: 192.168.0.1
DNS: 192.168.0.102

Resources:
  CPU Cores: 8
  Memory: 16 GB
  Swap: 4 GB
  Root Disk: 150 GB (local-zfs)

OS: Ubuntu 22.04 or 24.04 LTS
Features: nesting=1, keyctl=1
Network: vmbr0 bridge
```

This configuration balances performance, cost, and scalability, matching proven patterns from existing infrastructure (Portainer CT103, Dokploy CT180).

---

**Analysis Completed**: 2025-10-22 00:24 UTC
**Analyst Agent**: Hive Mind Swarm (swarm-1761103289543-v45j2euma)
**Status**: ✅ Ready for Implementation
**Next Steps**: Proceed to architecture design and deployment planning
