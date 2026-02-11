# Offsite Storage Evaluation for Backup Replication

**Date**: 2026-02-10
**Purpose**: Evaluate offsite storage options for disaster recovery backup replication
**Status**: Implementation Guide

## Executive Summary

This document evaluates offsite storage options for replicating backups from FGSRV07 and AGLSRV1 to achieve true disaster recovery capability. The evaluation considers cost, performance, security, and operational requirements.

## Current State Assessment

### Backup Volumes

| Source | Location | Daily Backup Size | Retention | Total Storage |
|--------|----------|-------------------|-----------|---------------|
| **AGLSRV1** | 192.168.0.245 | ~5-10 GB | 7-30 days | ~150 GB |
| **FGSRV07** | 191.252.93.227 | ~2-5 GB | 2-7 days | ~50 GB |
| **Proxmox VMs** | spark pool | ~8-12 GB | tiered | ~200 GB |
| **Docker Volumes** | AGLSRV1 | ~1-2 GB | 7 days | ~15 GB |
| **Total** | - | ~15-25 GB | - | **~400 GB** |

### Replication Requirements

- **RTO (Recovery Time Objective)**: < 4 hours
- **RPO (Recovery Point Objective)**: < 24 hours
- **Bandwidth**: Available uplink 100 Mbps (VPS Locaweb)
- **Security**: Encryption at rest and in transit (AES-256/GPG)
- **Compliance**: Data sovereignty considerations

## Storage Options Evaluation

### Option 1: Cloud Object Storage (Recommended)

#### AWS S3 Standard

**Pros:**
- 99.999999999% (11 9's) durability
- S3 Standard-IA for infrequent access
- Cross-region replication available
- Comprehensive IAM security
- S3 Glacier for long-term archival

**Cons:**
- Data transfer costs OUT
- Storage class management complexity
- Potential egress fees during recovery

**Cost Estimate (Monthly):**

| Tier | Storage | GB Cost | Monthly |
|------|---------|---------|---------|
| **Standard** | 100 GB | $0.023/GB | $2.30 |
| **Standard-IA** | 300 GB | $0.0125/GB | $3.75 |
| **Transfer OUT** | 400 GB (recovery) | $0.09/GB | $36.00 (one-time) |
| **Requests** | 10K PUT, 50K GET | per-request | $0.50 |
| **Total Monthly** | - | - | **$6.55** |
| **First-Year Cost** | - | - | **$78.60** |

#### Backblaze B2 (Most Cost-Effective)

**Pros:**
- Lowest cost in the market
- Simple pricing model
- No egress fees (unlimited)
- Compatible with rclone, restic
- 10 GB free storage

**Cons:**
- Fewer integration options
- US-only data centers
- No native redundancy (must configure)

**Cost Estimate (Monthly):**

| Tier | Storage | GB Cost | Monthly |
|------|---------|---------|---------|
| **B2 Storage** | 400 GB | $0.005/GB | $2.00 |
| **Class B Transactions** | 1M operations | $0.004/10K | $0.40 |
| **Transfer OUT** | 400 GB (recovery) | **FREE** | $0.00 |
| **Total Monthly** | - | - | **$2.40** |
| **First-Year Cost** | - | - | **$28.80** |

#### Wasabi Hot Cloud Storage

**Pros:**
- No egress fees
- No API request fees
- 99.999999999% durability
- Simple flat pricing
- Immutable storage option

**Cons:**
- Minimum 90-day retention
- Higher storage cost than B2
- Fewer data center locations

**Cost Estimate (Monthly):**

| Tier | Storage | GB Cost | Monthly |
|------|---------|---------|---------|
| **Wasabi Storage** | 400 GB | $0.00599/GB | $2.40 |
| **Transfer OUT** | 400 GB (recovery) | **FREE** | $0.00 |
| **Total Monthly** | - | - | **$2.40** |
| **First-Year Cost** | - | - | **$28.80** |

### Option 2: Hybrid Cloud + Remote VPS

#### Remote VPS (e.g., Hetzner, DigitalOcean)

**Pros:**
- Fixed monthly cost (predictable)
- Full control over data
- Can run additional services
- No per-GB transfer fees
- GDPR-compliant (EU regions)

**Cons:**
- Higher upfront cost
- Manual redundancy setup
- Hardware failure risk
- Maintenance overhead

**Cost Estimate (Monthly):**

| Provider | Plan | Storage | Transfer | Monthly |
|----------|------|---------|----------|---------|
| **Hetzner CX41** | 4 CPU, 16GB RAM | 500 GB NVMe | 20 TB | **€25.00 ($27)** |
| **DO Premium-8** | 4 CPU, 16GB RAM | 400 GB SSD | 6 TB | **$96.00** |
| **Vultr High Frequency** | 4 CPU, 8GB RAM | 400 GB NVMe | 5 TB | **$80.00** |

**Recommended**: Hetzner Storage Box (dedicated backup storage)

| Plan | Storage | Transfer | Monthly |
|------|---------|----------|---------|
| **Storage Box BX11** | 1 TB | 100 TB | **€5.41 ($5.85)** |

### Option 3: Proxmox Backup Server Remote

#### Remote PBS Instance (VPS)

**Pros:**
- Native Proxmox integration
- Deduplication (saves space)
- Incremental forever backups
- Built-in encryption
- Browser-based restore

**Cons:**
- PBS requires dedicated resources
- Higher memory requirements (2GB+ recommended)
- Network-dependent

**Cost Estimate (Monthly):**

| Component | Spec | Monthly |
|-----------|------|---------|
| **VPS for PBS** | 2 CPU, 4GB RAM, 500GB | $20-40 |
| **Bandwidth** | 1-2 TB transfer | included |
| **Total** | - | **$20-40** |

## Recommended Solution: Hybrid Approach

### Primary Offsite: Backblaze B2
- **Use Case**: Daily incremental backups
- **Tool**: rclone or restic
- **Cost**: $2.40/month for 400 GB
- **Benefit**: Lowest cost, no egress fees

### Secondary Offsite: Hetzner Storage Box
- **Use Case**: Full monthly backups, Proxmox VM replication
- **Tool**: rsync over SSH, Proxmox remote storage
- **Cost**: €5.41/month for 1 TB
- **Benefit**: EU data sovereignty, fast access via WireGuard/Tailscale

### Tiered Storage Strategy

```
[Local] ----rsync/rclone----> [B2 Cloud] ----age----> [B2 Glacier]
   |                              |
   |                              +----rclone----> [Hetzner Storage]
   |
   +----Proxmox sync----> [Remote PBS]
```

## Implementation Comparison

| Criteria | B2 + rclone | B2 + restic | Hetzner rsync | PBS Remote |
|----------|-------------|-------------|---------------|------------|
| **Monthly Cost** | $2.40 | $2.40 | $5.85 | $20-40 |
| **Setup Complexity** | Low | Medium | Low | Medium |
| **Encryption** | GPG | Built-in | GPG | Built-in |
| **Deduplication** | No | Yes | No | Yes |
| **Incremental** | Yes | Yes | Yes (rsync) | Yes |
| **Restore Speed** | Medium | Slow | Fast | Fast |
| **Bandwidth Use** | Medium | Low | Low | Medium |
| **Integration** | rclone | restic | rsync | Proxmox |

**Recommended Configuration**:
1. **Daily**: rclone to B2 (incremental)
2. **Weekly**: restic to B2 (deduplicated snapshots)
3. **Monthly**: rsync to Hetzner (full backup)
4. **VMs**: Proxmox remote sync to PBS

## Cost Summary

| Solution | Monthly | Annual | 3-Year |
|----------|---------|--------|--------|
| **Backblaze B2** | $2.40 | $28.80 | $86.40 |
| **Hetzner Storage** | $5.85 | $70.20 | $210.60 |
| **AWS S3** | $6.55 | $78.60 | $235.80 |
| **Wasabi** | $2.40 | $28.80 | $86.40 |
| **Remote PBS** | $30.00 | $360.00 | $1080.00 |
| **B2 + Hetzner (Recommended)** | **$8.25** | **$99.00** | **$297.00** |

## Bandwidth Analysis

### Daily Transfer Requirements

| Operation | Size | Compressed | Daily (25d) |
|-----------|------|------------|-------------|
| **Incremental backup** | 2-5 GB | 0.5-1 GB | 12.5-25 GB |
| **Full backup (weekly)** | 50 GB | 10-15 GB | 60 GB/month |
| **Metadata/verification** | 10 MB | 10 MB | 250 MB/month |
| **Total** | - | - | **~85-90 GB/month** |

### Network Requirements

- **Current uplink**: 100 Mbps (VPS Locaweb)
- **Daily transfer time**: 15-20 minutes for 5 GB incremental
- **Full backup time**: 2-3 hours for 50 GB compressed

**Bandwidth Optimization**:
- Use compression (zstd, gzip)
- Transfer during off-hours (02:00-06:00)
- Limit bandwidth: `rsync --bwlimit=10240` (10 MB/s)
- Incremental transfers reduce bandwidth by 80-90%

## Security Considerations

### Encryption Requirements

1. **At Rest**: AES-256 encryption
2. **In Transit**: TLS 1.3 for cloud, SSH for VPS
3. **Key Management**: GPG keys stored locally, offline backup
4. **Access Control**: IAM policies with least privilege

### Data Sovereignty

- **Backblaze B2**: US-based (compliant with US laws)
- **Hetzner**: Germany-based (GDPR compliant)
- **AWS**: Regional selection available (sa-east-1 for Brazil)

## Implementation Recommendation

### Phase 1: Immediate (Week 1)
1. Set up Backblaze B2 account and bucket
2. Configure rclone with GPG encryption
3. Create daily replication job (cron)

### Phase 2: Short-term (Week 2-4)
1. Set up Hetzner Storage Box
2. Configure rsync over WireGuard/Tailscale
3. Implement restic for deduplicated backups
4. Set up monitoring and alerts

### Phase 3: Long-term (Month 2-3)
1. Deploy remote Proxmox Backup Server
2. Configure VM replication
3. Implement failover testing
4. Documentation and training

## Monitoring and Verification

### Daily Checks
- Replication job completion status
- Backup file integrity (checksums)
- Storage usage and costs
- Error log review

### Weekly Checks
- Test restore from B2 (random file)
- Verify Hetzner rsync completion
- Review bandwidth usage
- Cost analysis and optimization

### Quarterly Tests
- Full disaster recovery drill
- Complete restoration verification
- RTO/RPO validation
- Documentation update

## Conclusion

**Recommended Solution**: Backblaze B2 + Hetzner Storage Box hybrid

**Monthly Cost**: $8.25 ($99/year)

**Benefits**:
- Low cost with high reliability
- No egress fees (fast recovery)
- EU data sovereignty option
- Redundant offsite copies
- Simple implementation

**Next Steps**:
1. Create B2 account and bucket
2. Generate GPG encryption keys
3. Deploy replication scripts
4. Configure monitoring
5. Document procedures

---

**Document Version**: 1.0
**Last Updated**: 2026-02-10
**Maintained By**: AGL Infrastructure Team
