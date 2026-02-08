---
name: cost-optimization-resource-efficiency
description: "Cloud and infrastructure cost optimization through resource rightsizing, reserved instances, scheduling, and efficiency tracking. Use when reducing infrastructure costs, optimizing resource utilization, or implementing cost controls."
category: infrastructure
priority: P2
tags: [cost, optimization, efficiency, budgeting]
---

# Cost Optimization & Resource Efficiency

Expert in reducing infrastructure costs and maximizing resource utilization through strategic rightsizing, scheduling, reserved instances, storage tiering, network optimization, and comprehensive cost monitoring.

## Overview

Cost optimization is a continuous practice of eliminating waste, optimizing resource allocation, and maximizing the value of infrastructure spend. This skill provides systematic approaches to analyze, optimize, and monitor infrastructure costs across Proxmox VE, containers, and supporting infrastructure.

### AGL Infrastructure Cost Profile

The AGL Hostman infrastructure runs on Proxmox VE with the following cost optimization opportunities:

- **56 CPU cores** across AGLSRV1 - currently at 11% utilization
- **125GB RAM** - 54% utilized with headroom for optimization
- **1.7TB ZFS storage** - 57% used with tiering opportunities
- **Multiple development VMs** - scheduling opportunities for off-hours
- **Container platforms** - Harbor, Dokploy, Portainer can be rightsized

### Cost Optimization Hierarchy

```
1. Resource Rightsizing      → Immediate savings (30-50% reduction)
2. Power Scheduling          → Dev/test env savings (60-80% reduction)
3. Storage Tiering           → Archive cost reduction (70-90% savings)
4. Network Optimization      → Data transfer cost control
5. Reserved/Committed        → Long-term discount (15-40% savings)
6. Monitoring & Alerting     → Prevent overspending
```

## Resource Rightsizing

Resource rightsizing matches allocations to actual utilization patterns, eliminating over-provisioning waste.

### Utilization Analysis

```bash
# Get current resource utilization across all containers
pct list | awk 'NR>1 {print $1}' | while read vmid; do
  echo "CT $vmid:"
  pct exec $vmid -- free -h | grep Mem
  pct exec $vmid -- top -bn1 | grep "Cpu(s)"
done

# Analyze CPU trends over 7 days
for vmid in $(pct list | awk 'NR>1 {print $1}'); do
  echo "Analyzing CT $vmid..."
  # Monitor CPU usage patterns
  pvesh get /nodes/AGLSRV1/lxc/$vmid/status/current --output-format json | jq '.cpu'
done

# Memory utilization analysis
pvesh get /cluster/resources --type lxc --output-format json | \
  jq -r '.[] | "\(.vmid): \(.name) - \(.maxmem) allocated, \(.mem) used"'
```

### Rightsizing Guidelines

| Workload Type | CPU | RAM | Disk | Overcommit |
|--------------|-----|-----|------|------------|
| Development  | 2 cores | 4GB | 32GB | 2:1 vCPU |
| Testing      | 2 cores | 4GB | 32GB | 2:1 vCPU |
| Staging      | 4 cores | 8GB | 64GB | 1.5:1 vCPU |
| Production   | 4+ cores | 16GB | 100GB | 1:1 vCPU |
| Database     | 8+ cores | 32GB | 256GB | 1:1 vCPU |

### Rightsizing Actions

```bash
# Downsize over-provisioned container
pct set <vmid> --cores 2 --memory 4096 --swap 2048

# Resize disk to actual usage
DISK_USAGE=$(pct exec <vmid> -- df -h / | awk 'NR==2 {print $3}')
pct resize <vmid> rootfs ${DISK_USAGE}G

# Set CPU limits for burstable workloads
pct set <vmid> --cpuunits 512 --cores 2

# Enable memory balloon for dynamic allocation
qm set <vmid> --balloon 4096 --memory 8192
```

### Automated Rightsizing Script

See `scripts/cost-rightsizing.sh` for automated analysis and recommendations.

## Power Scheduling

Schedule non-production workloads to power off during off-hours, reducing costs by 60-80%.

### Schedule Strategy

```yaml
development_environments:
  schedule: "Mon-Fri 08:00-20:00"
  timezone: "America/New_York"
  off_hours_action: "shutdown"
  weekend_action: "shutdown"

testing_environments:
  schedule: "Mon-Fri 09:00-18:00"
  timezone: "America/New_York"
  off_hours_action: "shutdown"
  weekend_action: "shutdown"

staging_environments:
  schedule: "24/7"
  timezone: "America/New_York"
  off_hours_action: "none"
  weekend_action: "none"
```

### Scheduling Implementation

```bash
# Power on schedule (cron: 0 8 * * 1-5)
#!/bin/bash
CONTAINERS="179,180,181"
for vmid in ${CONTAINERS//,/ }; do
  pct start $vmid
done

# Power off schedule (cron: 0 20 * * 1-5)
#!/bin/bash
CONTAINERS="179,180,181"
for vmid in ${CONTAINERS//,/ }; do
  pct shutdown $vmid --timeout 60
done

# Weekend shutdown (cron: 0 18 * * 5)
# Same as power off, runs Friday evening
```

### Schedule Configuration

```bash
# Add schedule tags to containers
pct set 179 --tags dev,scheduled,08:00-20:00
pct set 180 --tags dev,scheduled,09:00-19:00
pct set 181 --tags test,scheduled,09:00-18:00

# View scheduled containers
pct list | grep scheduled
```

### Scheduled Automation

See `scripts/cost-schedule.sh` for complete scheduling automation.

## Reserved Instances & Commitments

Commit to longer-term resource allocations for 15-40% discount over on-demand pricing.

### Commitment Tiers

| Commitment | Discount | Best For |
|------------|----------|----------|
| 1 year (partial) | 15% | Stable workloads |
| 1 year (all) | 30% | Production systems |
| 3 years (all) | 40% | Critical infrastructure |

### Commitment Candidates

Based on 30-day utilization analysis:

```bash
# Identify commitment candidates (90%+ uptime, consistent usage)
pvesh get /cluster/resources --type lxc --output-format json | \
  jq -r '.[] | select(.status == "running") |
    select(.uptime > 2592000) | # 30 days
    "\(.vmid): \(.name) - \(.cpu) CPU, \(.maxmem) MB"'
```

### Commitment Strategy

```yaml
production_platforms:
  - portainer_ct103:    # 365 days uptime
      commitment: "3_year"
      savings: "40%"
      rationale: "Critical infrastructure"

  - dokploy_ct180:     # 180 days uptime
      commitment: "1_year"
      savings: "30%"
      rationale: "Primary deployment platform"

development_environments:
  - agldv03_ct179:     # Intermittent usage
      commitment: "on_demand"
      savings: "0%"
      rationale: "Development, scheduled downtime"
```

### Savings Calculator

```bash
# Calculate annual savings for commitments
ON_DEMAND_MONTHLY=100
COMMITMENT_DISCOUNT=0.30
ANNUAL_SAVINGS=$((ON_DEMAND_MONTHLY * 12 * COMMITMENT_DISCOUNT))
echo "Annual savings: $$ANNUAL_SAVINGS"
```

## Storage Optimization

Implement tiered storage strategy to reduce costs by 70-90% for infrequently accessed data.

### Storage Tier Strategy

| Tier | Storage | Cost | Use Case | Retention |
|------|---------|------|----------|-----------|
| Hot | Local ZFS | High | Active VMs/CTs | 7 days |
| Warm | Local-LVM | Medium | Staging, backups | 30 days |
| Cold | NFS/Network | Low | Archives, logs | 90 days |
| Archive | Offline/NAS | Very Low | Compliance, cold | 1+ years |

### Storage Classification

```bash
# Analyze storage by access frequency
find /var/lib/vz -type f -mtime -7 -exec du -sh {} \; | sort -rh | head -20 > hot-storage.txt
find /var/lib/vz -type f -mtime +30 -mtime -90 > warm-storage.txt
find /var/lib/vz -type f -mtime +90 > cold-storage.txt

# Move cold data to NFS
rsync -av --remove-source-files \
  /var/lib/vz/images/backup/ \
  /mnt/nfs-archive/cold-storage/

# Compress archival data
find /mnt/nfs-archive/cold-storage/ -type f -name "*.vma" -exec gzip {} \;
```

### Deduplication & Compression

```bash
# ZFS compression analysis
zfs get compression,compressratio local-zfs

# Enable compression on datasets
zfs set compression=lz4 local-zfs
zfs set compression=zstd local-zfs/backups
zfs set compression=gzip-9 local-zfs/archive

# Verify dedup benefits
zfs get dedup,refcompressratio local-zfs
```

### Automated Tiering

```bash
# Move backups to NFS after 30 days
find /var/lib/vz/dump/ -name "*.vma.zst" -mtime +30 \
  -exec rsync -av --remove-source-files {} /mnt/nfs-backup/ \;

# Archive old backups to cold storage after 90 days
find /mnt/nfs-backup/ -name "*.vma.zst" -mtime +90 \
  -exec gzip {} \;
```

## Network Cost Optimization

Minimize data transfer costs and optimize network efficiency.

### Data Transfer Analysis

```bash
# Monitor network bandwidth by container
for vmid in $(pct list | awk 'NR>1 {print $1}'); do
  echo "CT $vmid network usage:"
  pct exec $vmid -- cat /proc/net/dev
done

# Track transfer volumes
vnstat -l -i eth0 > network-usage.log &
```

### Cost Reduction Strategies

```bash
# Use local registry (Harbor) instead of Docker Hub
# Before: docker pull nginx (from Docker Hub)
# After: docker pull 192.168.0.182/library/nginx:latest

# Cache package updates locally
apt-cache mirror selection in CT templates

# Use internal NFS for inter-VM transfers
# Instead of external download, mount shared storage
pct set <vmid> -mp0 /mnt/shared,mp=/shared-storage
```

### CDN & Caching

```yaml
registry_caching:
  harbor_ct182:
    location: "192.168.0.182"
    caching: "enabled"
    retention: "7 days"
    savings: "95% reduction in external pulls"

package_caching:
  apt_caching_server:
    location: "192.168.0.102"
    services: ["apt", "pip", "npm"]
    savings: "80% reduction in package downloads"
```

## Cost Monitoring & Dashboards

Implement comprehensive cost tracking and visualization.

### Metrics Collection

```php
// Cost metrics collection
class CostCollector
{
    public function collectHourly(): array
    {
        return [
            'timestamp' => now(),
            'resources' => [
                'cpu_allocated' => $this->getAllocatedCpu(),
                'cpu_used' => $this->getUsedCpu(),
                'memory_allocated_gb' => $this->getAllocatedMemory(),
                'memory_used_gb' => $this->getUsedMemory(),
                'storage_allocated_gb' => $this->getAllocatedStorage(),
                'storage_used_gb' => $this->getUsedStorage(),
            ],
            'utilization' => [
                'cpu_utilization_percent' => $this->getCpuUtilization(),
                'memory_utilization_percent' => $this->getMemoryUtilization(),
                'storage_utilization_percent' => $this->getStorageUtilization(),
            ],
            'costs' => [
                'hourly_cost_estimated' => $this->calculateHourlyCost(),
                'monthly_cost_projected' => $this->calculateMonthlyCost(),
            ],
        ];
    }

    private function calculateHourlyCost(): float
    {
        // CPU: $0.01/vCPU/hour
        $cpuCost = $this->getAllocatedCpu() * 0.01;

        // Memory: $0.005/GB/hour
        $memoryCost = $this->getAllocatedMemory() / 1024 * 0.005;

        // Storage: $0.0001/GB/hour
        $storageCost = $this->getAllocatedStorage() * 0.0001;

        return $cpuCost + $memoryCost + $storageCost;
    }
}
```

### Dashboard Metrics

```yaml
cost_dashboard:
  panels:
    - title: "Monthly Cost Trend"
      metric: "cost.monthly_projected"
      period: "30d"

    - title: "Cost by Resource Type"
      metric: "cost.by_resource_type"
      breakdown: ["cpu", "memory", "storage"]

    - title: "Cost per Container"
      metric: "cost.per_container"
      top_n: 10

    - title: "Utilization vs Cost"
      metric: "utilization.cost_efficiency"
      target: "80%"

    - title: "Savings from Optimization"
      metric: "savings.total"
      breakdown: ["rightsizing", "scheduling", "tiering"]
```

### Alert Thresholds

```php
// config/monitoring.php
'cost_alerts' => [
    'monthly_budget_warning' => 100,  // $100
    'monthly_budget_critical' => 150, // $150

    'daily_spike_threshold_percent' => 50,  // 50% over baseline
    'container_cost_threshold' => 20,       // $20/month per container

    'low_utilization_threshold' => 20,  // Rightsize if <20% utilized
    'over_allocation_threshold' => 200,  // Alert if 2x allocated
],
```

## Budget Allocation

Distribute costs across teams, projects, or environments for accountability.

### Cost Allocation Model

```yaml
budget_allocation:
  method: "by_container_tag"

  allocations:
    development:
      containers: [179, 180, 181]
      budget_monthly: 30  # $30
      owner: "Development Team"

    infrastructure:
      containers: [103, 182]
      budget_monthly: 50  # $50
      owner: "DevOps Team"

    production:
      containers: []  # TBD
      budget_monthly: 100  # $100
      owner: "Operations Team"

  total_budget: 180  # $180/month
```

### Tag-Based Allocation

```bash
# Tag containers for cost allocation
pct set 179 --tags cost-center:dev,owner:development-team
pct set 180 --tags cost-center:dev,owner:development-team
pct set 182 --tags cost-center:infra,owner:devops-team
pct set 103 --tags cost-center:infra,owner:devops-team

# Query by cost center
pct list | grep "cost-center:dev"
```

### Cost Allocation Report

```bash
# Generate monthly cost allocation report
# See scripts/cost-report.sh
```

## Alerting & Anomaly Detection

Detect cost anomalies and overspending early to prevent budget overruns.

### Alert Types

```yaml
alerts:
  budget_exceeded:
    severity: "critical"
    trigger: "monthly_cost > monthly_budget"
    action: "notify_team"

  daily_spike:
    severity: "warning"
    trigger: "daily_cost > baseline * 1.5"
    action: "investigate_resource"

  low_utilization:
    severity: "info"
    trigger: "utilization < 20% for 7 days"
    action: "recommend_downsize"

  cost_anomaly:
    severity: "warning"
    trigger: "cost_change > 30% week_over_week"
    action: "investigate_cause"
```

### Alert Configuration

```php
use App\Jobs\SendCostAlert;
use App\Models\Alert;

// Budget exceeded alert
if ($monthlyCost > config('monitoring.cost_alerts.monthly_budget_warning')) {
    Alert::create([
        'type' => 'cost',
        'title' => 'Monthly Budget Exceeded',
        'message' => "Monthly cost \${$monthlyCost} exceeds budget \${$budget}",
        'alert_type' => 'cost',
        'severity' => 80,
        'metadata' => [
            'current_cost' => $monthlyCost,
            'budget' => $budget,
            'overspend_percent' => round(($monthlyCost / $budget - 1) * 100),
        ],
    ]);

    SendCostAlert::dispatch($monthlyCost, $budget);
}
```

### Alert Notification

```bash
# Send cost alert
# See scripts/cost-alert.sh
```

## Best Practices

### Continuous Optimization

1. **Weekly Review**: Check cost dashboard for anomalies
2. **Monthly Rightsizing**: Analyze utilization and adjust allocations
3. **Quarterly Audit**: Review reserved commitments and storage tiering
4. **Annual Strategy**: Plan long-term commitments for stable workloads

### Rightsizing Workflow

```bash
# 1. Collect 30 days of metrics
./scripts/cost-analyze.sh --period 30d

# 2. Generate rightsizing recommendations
./scripts/cost-rightsizing.sh

# 3. Apply changes after review
./scripts/cost-rightsizing.sh --apply

# 4. Monitor for 7 days
./scripts/cost-analyze.sh --period 7d

# 5. Rollback if issues occur
./scripts/cost-rightsizing.sh --rollback <timestamp>
```

### Cost Optimization Checklist

- [ ] Identify over-provisioned resources (<30% utilization)
- [ ] Implement power schedules for dev/test environments
- [ ] Move cold data to tiered storage
- [ ] Use local registry instead of Docker Hub
- [ ] Set up cost monitoring and alerts
- [ ] Allocate budget by team/project
- [ ] Review reserved commitments quarterly
- [ ] Optimize network transfers with caching

## Troubleshooting

### High Costs Unexpectedly

```bash
# Check for runaway containers
pct list | awk '{print $3}' | while read status; do
  [ "$status" != "running" ] && echo "Stopped container still consuming resources"
done

# Check for storage leaks
df -h /var/lib/vz
du -sh /var/lib/vz/images/* | sort -rh | head -10

# Check for network leaks
vnstat -l 1
```

### Utilization Reporting Issues

```bash
# Verify metrics collection
systemctl status prometheus-node-exporter

# Check API connectivity
curl -k https://192.168.0.245:8006/api2/json/version

# Verify metrics in database
sqlite3 /path/to/metrics.db "SELECT * FROM cost_metrics ORDER BY timestamp DESC LIMIT 10"
```

### Schedule Not Working

```bash
# Check cron jobs
crontab -l | grep cost-schedule

# Test schedule manually
./scripts/cost-schedule.sh --action power-off --containers 179,180

# Check logs
journalctl -u cost-schedule -f
```

## Cost Optimization Scripts

The following scripts are provided for automated cost optimization:

### cost-analyze.sh
Analyze infrastructure costs and utilization patterns. Generates detailed cost breakdowns and identifies optimization opportunities.

### cost-rightsizing.sh
Analyze resource utilization and recommend rightsizing actions. Apply changes with approval workflow and rollback capability.

### cost-schedule.sh
Configure power-on/off schedules for dev/test environments. Automated shutdown during off-hours and weekends.

### cost-report.sh
Generate monthly cost reports with breakdowns by resource type, container, and cost center. Export to CSV or JSON.

### cost-alert.sh
Send cost alerts when thresholds are exceeded. Integrates with notification systems for team awareness.

## Related Skills

- `proxmox-infrastructure-management` - VM and container management
- `performance-monitoring` - Metrics collection and utilization tracking
- `alert-management` - Alert configuration and notification
- `harbor-registry` - Local registry for network cost optimization

## Example Workflows

### Weekly Cost Review

```bash
# 1. Generate cost report
./scripts/cost-report.sh --period 7d --format json > weekly-cost.json

# 2. Check for anomalies
./scripts/cost-analyze.sh --anomaly-detection

# 3. Review top costs
cat weekly-cost.json | jq '.top_containers | .[:5]'

# 4. Send to team
./scripts/cost-alert.sh --type report --file weekly-cost.json
```

### Monthly Rightsizing

```bash
# 1. Analyze 30-day utilization
./scripts/cost-rightsizing.sh --analyze --period 30d > recommendations.txt

# 2. Review recommendations
cat recommendations.txt

# 3. Apply approved changes
./scripts/cost-rightsizing.sh --apply --from recommendations.txt

# 4. Monitor impact
./scripts/cost-analyze.sh --period 7d --post-rightsizing
```

### Quarterly Budget Review

```bash
# 1. Generate quarterly report
./scripts/cost-report.sh --period 90d --format csv > quarterly-cost.csv

# 2. Compare against budget
./scripts/cost-report.sh --compare-budget --budget 180

# 3. Identify optimization opportunities
./scripts/cost-analyze.sh --optimization-opportunities

# 4. Update allocations
./scripts/cost-report.sh --reallocate --team development --budget 30
```
