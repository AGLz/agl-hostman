# FGSRV07 Best Practices & Optimization Guide

**Host**: FGSRV07 (191.252.93.227)
**Type**: VPS Locaweb
**OS**: Debian 13
**Role**: Proxmox VE Host with Tailscale
**Last Updated**: 2026-02-09

---

## Table of Contents

1. [Security Hardening](#security-hardening)
2. [Performance Tuning](#performance-tuning)
3. [Backup Strategies](#backup-strategies)
4. [Monitoring & Alerting](#monitoring--alerting)
5. [Network Optimization](#network-optimization)
6. [Update & Maintenance](#update--maintenance)
7. [Disaster Recovery](#disaster-recovery)
8. [Regular Maintenance Schedule](#regular-maintenance-schedule)

---

## Security Hardening

### SSH Configuration

**File**: `/etc/ssh/sshd_config`

```bash
# Disable password authentication
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM no

# Key-based only
PubkeyAuthentication yes
AuthenticationMethods publickey

# Restrict access
PermitRootLogin prohibit-password
AllowUsers your-user proxmox-admin

# Hardening
Protocol 2
X11Forwarding no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2

# Change default port (recommended)
Port 2222
```

**Apply changes**:
```bash
systemctl restart sshd
```

### Firewall Configuration (UFW)

**Install and configure**:
```bash
# Install UFW
apt install ufw

# Default policies
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (on custom port)
ufw allow 2222/tcp comment 'SSH'

# Allow Proxmox web interface
ufw allow 8006/tcp comment 'Proxmox VE'

# Allow Tailscale
ufw allow 41641/udp comment 'Tailscale'

# Enable
ufw enable
ufw status verbose
```

### Fail2Ban Configuration

**Install**:
```bash
apt install fail2ban
```

**File**: `/etc/fail2ban/jail.local`
```ini
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5
destemail = admin@example.com
sendername = Fail2Ban@FGSRV07
action = %(action_mwl)s

[sshd]
enabled = true
port = 2222
logpath = /var/log/auth.log
maxretry = 3

[proxmox]
enabled = true
port = 8006
logpath = /var/log/daemon.log
maxretry = 5
```

**Enable and start**:
```bash
systemctl enable fail2ban
systemctl start fail2ban
fail2ban-client status
```

### System Hardening Checklist

```bash
# 1. Remove unnecessary packages
apt autoremove --purge

# 2. Disable unused services
systemctl disable bluetooth
systemctl disable cups

# 3. Secure shared memory
echo "tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0" >> /etc/fstab

# 4. Restrict core dumps
echo "* hard core 0" >> /etc/security/limits.conf

# 5. Install security updates automatically
apt install unattended-upgrades
dpkg-reconfigure --priority=low unattended-upgrades

# 6. Enable AppArmor
systemctl enable apparmor
systemctl start apparmor

# 7. Install auditd
apt install auditd
systemctl enable auditd
```

---

## Performance Tuning

### Kernel Parameters

**File**: `/etc/sysctl.d/99-proxmox-tuning.conf`

```bash
# Network performance
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_congestion_control = bbr

# Memory management
vm.swappiness = 10
vm.vfs_cache_pressure = 50
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5

# File system
fs.file-max = 2097152
fs.inotify.max_user_watches = 524288

# Security
net.ipv4.conf.all.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.conf.all.send_redirects = 0
```

**Apply changes**:
```bash
sysctl -p /etc/sysctl.d/99-proxmox-tuning.conf
```

### Proxmox Storage Optimization

**ZFS (if used)**:
```bash
# Disable atime for better performance
zfs set atime=off rpool/data

# Enable compression
zfs set compression=lz4 rpool/data

# Adjust ARC size (50% of RAM for systems with >16GB)
echo "options zfs zfs_arc_max=8589934592" >> /etc/modprobe.d/zfs.conf
```

**LVM Optimization**:
```bash
# Use SSD-aware scheduler
echo 'ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"' > /etc/udev/rules.d/60-schedulers.rules
```

### CPU Governor Settings

```bash
# Install cpupower
apt install linux-cpupower

# Set to performance mode
cpupower frequency-set -g performance

# Make persistent
echo 'GOVERNOR="performance"' > /etc/default/cpupower
systemctl enable cpupower
```

### Resource Limits

**File**: `/etc/pve/labs/rlab.conf` (Proxmox resource limits)

```bash
# VM defaults
memory: 4096
cores: 2
cpuunits: 1024

# Container defaults
memory: 2048
swap: 2048
cores: 2
cpuunits: 1024
```

---

## Backup Strategies

### Proxmox Built-in Backup

**Create backup job** via Proxmox UI or CLI:

```bash
# Backup all VMs and containers daily at 2 AM
vzdump --all --mode snapshot --compress zstd --storage local --mailnotification always --mailto admin@example.com

# Specific VM backup
vzdump 100 --mode snapshot --compress zstd --storage local --retain 7

# Specific container backup
vzdump 101 --mode snapshot --compress zstd --storage local --retain 7
```

### Off-Site Backup with Restic/Borg

**Install Restic**:
```bash
apt install restic

# Initialize repository (backblaze b2, s3, or local)
export RESTIC_REPOSITORY="b2:bucket-name"
export RESTIC_PASSWORD="secure-password"
restic init

# Backup Proxmox config
restic backup /etc/pve

# Backup VM storage
restic backup /var/lib/vz
```

**Automate with cron**:
```bash
# /etc/cron.daily/proxmox-backup
#!/bin/bash
export RESTIC_REPOSITORY="b2:bucket-name"
export RESTIC_PASSWORD="secure-password"
restic backup /etc/pve /var/lib/vz
restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6
```

### Backup Best Practices

1. **3-2-1 Rule**:
   - 3 copies of data
   - 2 different storage types
   - 1 off-site copy

2. **Retention Policy**:
   - Daily backups: Keep 7 days
   - Weekly backups: Keep 4 weeks
   - Monthly backups: Keep 6 months

3. **Test Restores**:
   ```bash
   # Monthly test restore
   vzdump --restore /path/to/backup.vma.zst 999 --storage local
   ```

4. **Verification**:
   ```bash
   # Verify backup integrity
   vma verify /backup/dump/vzdump-lxc-101-*.vma.zst
   ```

---

## Monitoring & Alerting

### Proxmox Built-in Monitoring

Enable in Proxmox UI: Datacenter > Metrics > Setup

### Install Prometheus Node Exporter

```bash
apt install prometheus-node-exporter
systemctl enable node-exporter
systemctl start node-exporter

# Add custom collectors
wget https://raw.githubusercontent.com/prometheus/node_exporter/master/text_collector_examples/smartmon.sh -O /usr/local/bin/smartmon.sh
chmod +x /usr/local/bin/smartmon.sh
```

### Grafana Dashboard Setup

**docker-compose.yml** for monitoring stack:
```yaml
version: '3.8'
services:
  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    ports:
      - "9090:9090"

  grafana:
    image: grafana/grafana:latest
    volumes:
      - grafana_data:/var/lib/grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=changeme

volumes:
  prometheus_data:
  grafana_data:
```

**prometheus.yml**:
```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'proxmox'
    static_configs:
      - targets: ['localhost:9100']
    params:
      'collect[]':
        - cpu
        - meminfo
        - diskstats
        - filefd
        - filesystem
        - netdev
        - time
```

### Critical Alerts (Prometheus)

**alerts.yml**:
```yaml
groups:
  - name: proxmox
    rules:
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        annotations:
          summary: "High CPU usage on {{ $labels.instance }}"

      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
        for: 5m
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"

      - alert: DiskSpaceLow
        expr: (node_filesystem_avail_bytes{fstype!="tmpfs"} / node_filesystem_size_bytes) * 100 < 15
        for: 5m
        annotations:
          summary: "Disk space low on {{ $labels.instance }}"

      - alert: ZFSHealth
        expr: node_zfs_zstate_state != 0
        annotations:
          summary: "ZFS pool degraded on {{ $labels.instance }}"
```

### Alert Notifications

Set up alerts to:
- Email (Postfix/Sendmail)
- Telegram/Mattermost webhook
- PagerDuty (for critical)

---

## Network Optimization

### Tailscale Configuration

**Enable subnet routing**:
```bash
# On FGSRV07
tailscale up --advertise-routes=192.168.1.0/24,10.0.0.0/24

# On Tailscale admin console, approve routes
```

**Exit node configuration**:
```bash
# Make FGSRV07 an exit node
tailscale up --advertise-exit-node

# Use exit node from client
tailscale up --exit-node=fgsrv07-node-name
```

### Proxmox Network Bridge

**File**: `/etc/network/interfaces`

```bash
# Bridge for VMs
auto vmbr0
iface vmbr0 inet static
    address 192.168.1.10/24
    gateway 192.168.1.1
    bridge-ports enp1s0
    bridge-stp off
    bridge-fd 0

# Bridge for Tailscale
auto vmbr1
iface vmbr1 inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0
```

### Traffic Control (QoS)

```bash
# Install wondershaper for easy traffic shaping
apt install wondershaper

# Set download/upload limits (in kbps)
wondershaper enp1s0 100000 100000
```

### DNS Optimization

**File**: `/etc/systemd/resolved.conf`

```ini
[Resolve]
DNS=1.1.1.1 1.0.0.1 8.8.8.8
FallbackDNS=9.9.9.9
Cache=yes
DNSStubListener=yes
```

**Apply**:
```bash
systemctl restart systemd-resolved
```

---

## Update & Maintenance

### Regular Update Procedure

**Monthly security updates**:
```bash
#!/bin/bash
# /usr/local/bin/update-proxmox.sh

# 1. Check for updates
apt update

# 2. List available updates
apt list --upgradable

# 3. Create backup before major updates
vzdump --all --mode snapshot --storage local

# 4. Update system
apt upgrade -y
apt dist-upgrade -y

# 5. Update Proxmox
pveupdate

# 6. Reboot if kernel updated
if [ -f /var/run/reboot-required ]; then
    echo "Reboot required. Schedule maintenance window."
    cat /var/run/reboot-required.pkgs
fi
```

### Pre-Update Checklist

1. [ ] Create full backup
2. [ ] Check release notes
3. [ ] Test in staging environment
4. [ ] Schedule maintenance window
5. [ ] Notify users
6. [ ] Verify rollback plan

### Post-Update Verification

```bash
# Check Proxmox services
systemctl status pve-cluster pvedaemon pve-proxy pvestatd

# Check cluster status
pvesh get /cluster/status

# Verify network
ip a
ping -c 3 8.8.8.8

# Check storage
pvesm status
```

---

## Disaster Recovery

### Recovery Procedures

**Proxmox config restore**:
```bash
# Restore from backup
pveum user token add <username> <token-id>
pveum acl modify / -user <username>@pve -role Administrator
```

**VM restore from backup**:
```bash
qmrestore /path/to/backup.vma.zst <new-vm-id> --storage local
```

**Container restore**:
```bash
pct restore <new-ct-id> /path/to/backup.tar.gz --storage local
```

### Boot Recovery

**If system won't boot**:
1. Boot from Debian Live USB
2. Chroot into system:
   ```bash
   mount /dev/sda2 /mnt
   mount --bind /dev /mnt/dev
   mount --bind /proc /mnt/proc
   mount --bind /sys /mnt/sys
   chroot /mnt
   ```
3. Restore grub:
   ```bash
   grub-install /dev/sda
   update-grub
   ```

### Emergency Recovery Plan

1. **Identify failure type**:
   - Hardware failure (contact Locaweb)
   - Software failure (restore from backup)
   - Network failure (check Tailscale, firewall)

2. **Restore priorities**:
   1. Proxmox host
   2. Critical VMs
   3. Non-critical containers
   4. Configuration files

3. **Documentation**:
   - Keep runbook updated
   - Document all changes
   - Maintain change log

---

## Regular Maintenance Schedule

### Daily (Automated)
- [ ] Backup verification (check logs)
- [ ] Disk space monitoring
- [ ] Check fail2ban bans
- [ ] Review system logs

### Weekly
- [ ] Review security logs
- [ ] Check for security advisories
- [ ] Verify backup completion
- [ ] Monitor resource usage trends

### Monthly
- [ ] Security updates
- [ ] Review backup retention
- [ ] Test restore procedure
- [ ] Audit user access
- [ ] Review and rotate logs

### Quarterly
- [ ] Major version updates
- [ ] Security audit
- [ ] Performance review
- [ ] Capacity planning
- [ ] Update documentation

### Annually
- [ ] Full disaster recovery test
- [ ] Hardware assessment
- [ ] Architecture review
- [ ] Cost optimization review

---

## Quick Reference Commands

```bash
# System info
pveversion                    # Proxmox version
uname -a                      # Kernel version
free -h                       # Memory usage
df -h                         # Disk usage
top                           # CPU usage

# Proxmox management
pvesh get /nodes              # List nodes
pvesh get /cluster/resources  # All resources
qm list                       # List VMs
pct list                      # List containers

# Network
tailscale status              # Tailscale status
tailscale ping <host>         # Test connectivity
ip a                          # Network interfaces

# Logs
journalctl -xe                # Systemd logs
tail -f /var/log/syslog       # System logs
tail -f /var/log/auth.log     # Auth logs
```

---

## Support & Documentation

- **Proxmox Documentation**: https://pve.proxmox.com/wiki/Main_Page
- **Tailscale Documentation**: https://tailscale.com/kb/
- **Debian Administration**: https://www.debian.org/doc/
- **Locaweb Support**: https://www.locaweb.com.br/suporte/

---

**Document Version**: 1.0
**Maintainer**: AGL System Administration
**Review Date**: 2026-05-09 (Quarterly)
