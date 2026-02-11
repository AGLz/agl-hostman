# FGSRV07 Proxmox Host Quick Reference Card

**Host**: FGSRV07 (Proxmox Hypervisor)
**Type**: VPS Locaweb
**OS**: Debian 13 (Trixie)
**IP**: 191.252.93.227
**Tailscale**: Enabled
**Generated**: 2026-02-09

---

## Emergency Response (Under 2 Minutes)

### The "Big 5" Critical Commands
```bash
# 1. Host & Proxmox Status
systemctl status pve-manager pvedaemon pveproxy pvestatd --no-pager

# 2. Resource Check (Host Level)
free -m && df -h && df -h /var/lib/vz

# 3. Container/VM Status
pct list && qm list

# 4. Recent Errors (Host)
journalctl -n 50 --no-pager -p err

# 5. Network & Tailscale Status
ip addr show tailscale0 && tailscale status --peers
```

---

## Host Information & Access

### Quick Host Facts
```bash
# System Info
hostnamectl
uname -a

# Proxmox Version
pveversion

# CPU & Memory
lscpu | grep "^Model name\|^CPU(s)"
free -h

# Disk Layout
lsblk
df -h

# Network
ip addr show
ip route show
```

### SSH Access
```bash
# Direct SSH (Public IP)
ssh root@191.252.93.227

# Via Tailscale (Preferred)
ssh root@fgsrv07

# With specific key
ssh -i ~/.ssh/your_key root@191.252.93.227
```

---

## Proxmox Commands

### Container Management (LXC)
```bash
# List all containers
pct list

# Container status
pct status <CTID>

# Start/Stop/Restart
pct start <CTID>
pct stop <CTID>
pct shutdown <CTID>
pct reboot <CTID>

# Enter container
pct enter <CTID>

# Execute command in container
pct exec <CTID> -- <command>

# Container config
pct config <CTID>

# Resource usage
pct status <CTID>
```

### VM Management (KVM)
```bash
# List all VMs
qm list

# VM status
qm status <VMID>

# Start/Stop/Restart
qm start <VMID>
qm stop <VMID>
qm shutdown <VMID>
qm reboot <VMID>

# VM config
qm config <VMID>

# Console access
qm terminal <VMID>

# Monitor via VNC
qm monitor <VMID>
```

### Storage Management
```bash
# List storage
pvesm status

# Storage content
pvesm list <storage>

# Disk usage by VM/CT
pct list
qm list

# Check ZFS (if applicable)
zpool status
zfs list

# Check LVM (if applicable)
lvs
vgs
```

---

## Tailscale Commands

### Status & Information
```bash
# Status overview
tailscale status

# Show peers
tailscale status --peers

# Show current machine
tailscale status --self

# Check IP
tailscale ip -4
tailscale ip -6

# Tailscale service
systemctl status tailscaled
```

### Connectivity & Troubleshooting
```bash
# Ping via Tailscale
tailscale ping <peer-name>

# Check connection
tailscale netcheck

# View logs
journalctl -u tailscaled -n 50 --no-pager

# Restart Tailscale
systemctl restart tailscaled

# Exit node status
tailscale status --peers | grep -i "exit node"

# Enable/disable (use with caution)
tailscale up
tailscale down
```

### Common Tailscale Operations
```bash
# Accept route (when prompted)
tailscale up --accept-routes

# advertise subnet
tailscale up --advertise-routes=192.168.1.0/24

# Set as exit node
tailscale up --advertise-exit-node

# Check advertised routes
tailscale status --json | jq -r '.Peer[] | select(.ExitNodeOption) | .HostName'
```

---

## Health Status Thresholds

### Resource Health Matrix
| Metric | Healthy | Warning | Critical |
|--------|---------|---------|----------|
| Host CPU Usage | < 60% | 60-85% | > 85% |
| Host Memory | < 75% | 75-90% | > 90% |
| Root Disk (/) | < 80% | 80-90% | > 90% |
| Proxmox Storage | < 80% | 80-90% | > 90% |
| I/O Wait | < 10% | 10-30% | > 30% |
| Swap Used | 0% | < 20% | > 20% |
| Load Average (1m) | < #CPU | < #CPU*2 | > #CPU*2 |

### Quick Health Check
```bash
# CPU Load average
uptime | awk -F'load average:' '{print $2}'

# Memory percentage
free -m | grep Mem | awk '{printf "Memory: %.1f%%\n", ($3/$2)*100}'

# Disk percentage
df -h / | tail -1 | awk '{print "Root Disk: " $5}'

# Proxmox storage
pvesm status | awk 'NR>1 {print $2, $5}'

# Service status
systemctl is-active pve-manager pvedaemon pveproxy
```

---

## Common Issues Fast Track

### Issue: Proxmox Web UI Unreachable
```bash
# Check Proxmox services
systemctl status pve-proxy pve-daemon pve-stat pve-firewall

# Check ports
netstat -tlnp | grep -E "8006|3128"

# Check host firewall
iptables -L -n -v
ufw status (if using ufw)

# Restart proxy
systemctl restart pveproxy

# Check logs
journalctl -u pveproxy -n 50 --no-pager
```

### Issue: Container/VM Won't Start
```bash
# Check container status
pct status <CTID>
pct config <CTID>

# Check for lock files
ls -la /var/lib/lxc/<CTID>/lock

# Check CT config for errors
pct config <CTID> | grep -i error

# Check resources
free -m
df -h /var/lib/vz

# Verify template/storage
pvesm status

# Check logs
journalctl -xe | grep -i lxc
tail -f /var/log/lxc/<CTID>.log
```

### Issue: High CPU Usage
```bash
# Identify CPU hogs
top -b -n 1 | head -20

# Per-container/VM CPU
pct list
qm list

# Host process CPU
ps aux --sort=-%cpu | head -10

# Check container/VM from inside
pct exec <CTID> -- top -b -n 1
```

### Issue: High Memory Usage
```bash
# Check OOM events
dmesg | grep -i "out of memory"
journalctl -k | grep -i oom

# Memory breakdown
ps aux --sort=-%mem | head -10

# Per-container memory
pct list
for ct in $(pct list | awk 'NR>1 {print $1}'); do
  echo "CT $ct:"
  pct exec $ct -- free -m 2>/dev/null
done

# Check swap
free -m
swapon --show
```

### Issue: Disk Full
```bash
# Space hogs (host)
du -sh /* 2>/dev/null | sort -h | tail -10

# Proxmox storage
pvesm status
du -sh /var/lib/vz/* 2>/dev/null | sort -h

# Large files
find / -type f -size +500M -exec ls -lh {} \; 2>/dev/null | head -20

# Container disk usage
pct exec <CTID> -- df -h
```

### Issue: Network Problems
```bash
# Host connectivity
ping -c 4 8.8.8.8
ping -c 4 cloudflare.com

# DNS check
nslookup google.com
cat /etc/resolv.conf

# Network config
ip addr show
ip route show

# Tailscale connectivity
tailscale ping <peer>
tailscale netcheck

# Container network
pct exec <CTID> -- ping -c 4 8.8.8.8
pct exec <CTID> -- ip addr show
```

### Issue: Tailscale Not Connected
```bash
# Service status
systemctl status tailscaled

# Connection status
tailscale status

# Check if daemon running
ps aux | grep tailscale

# View logs
journalctl -u tailscaled -n 100 --no-pager

# Restart
systemctl restart tailscaled

# Re-auth (if needed)
tailscale up --reset
```

---

## Log Analysis Shortcuts

### Proxmox Logs
```bash
# Proxmox tasks log
tail -f /var/log/pve/tasks/index

# Container logs
tail -f /var/log/lxc/<CTID>.log

# VM logs
tail -f /var/log/qemu-server/<VMID>.log

# Cluster log
tail -f /var/log/pve-cluster/corosync.log
```

### Host System Logs
```bash
# All errors (last hour)
journalctl -p err --since "1 hour ago" --no-pager

# System messages
tail -f /var/log/syslog

# Kernel messages
dmesg -T | tail -50

# Authentication
journalctl -u ssh -n 50 --no-pager
```

### Error Pattern Frequency
```bash
# All error counts
journalctl -n 1000 --no-pager | \
  grep -oE "(ERROR|WARN|FATAL)" | sort | uniq -c | sort -rn

# Proxmox errors
tail -1000 /var/log/pve/tasks/index | \
  grep -oE "ERROR|WARN" | sort | uniq -c | sort -rn
```

### Service Restart History
```bash
# Proxmox services
journalctl --since "7 days ago" --no-pager | \
  grep -E "Started.*pve|Stopped.*pve"

# Tailscale
journalctl -u tailscaled --since "7 days ago" --no-pager | \
  grep -E "Started|Stopped"
```

---

## Real-Time Monitoring

### Live Resource Monitor
```bash
watch -n 5 'echo "=== HOST ==="; uptime; echo ""; \
free -m | grep -E "Mem|Swap"; echo ""; \
df -h / | tail -1; echo ""; \
echo "=== CONTAINERS ==="; pct list; echo ""; \
echo "=== VMS ==="; qm list'
```

### Live Host Logs
```bash
# System logs
journalctl -f

# Proxmox tasks
tail -f /var/log/pve/tasks/index

# Tailscale
journalctl -u tailscaled -f
```

### Live Process Monitor
```bash
# Interactive
htop

# Command line
watch -n 2 'ps aux | head -20'
```

---

## Backup & Recovery

### Proxmox Backup
```bash
# List backups
vzdump-list

# Backup container
vzdump <CTID> --storage <storage> --mode snapshot

# Backup VM
vzdump <VMID> --storage <storage> --mode snapshot

# Schedule backup (add to /etc/pve/vzdump.cron)
# Example: Daily backup of CT 100 at 2 AM
# 0 2 * * * root vzdump 100 --storage backup --mode snapshot --mailnotification always
```

### Restore Operations
```bash
# Restore container
pct restore <NEW_CTID> /path/to/backup.vma.gz --storage <storage>

# Restore VM
qmrestore /path/to/backup.vma.gz <NEW_VMID> --storage <storage>

# List available backups
ls -lh /var/lib/vz/dump/
```

### Tailscale Configuration Backup
```bash
# Export ACLs (if using)
tailscale acl export

# View current config
tailscale status --json

# Backup state file
cp /var/lib/tailscale/tailscaled.state /var/lib/tailscale/tailscaled.state.bak
```

---

## Escalation Contacts

### Level 1: Routine (1-2 hours)
- High resource usage
- Container/VM restart required
- Minor network issues
- **Action**: Check logs, restart services, monitor

### Level 2: Service Down (2-6 hours)
- Proxmox UI inaccessible
- Multiple containers/VMs down
- Tailscale disconnect
- **Action**: Root cause analysis, service recovery

### Level 3: Infrastructure (6-24 hours)
- Host disk full
- Storage issues
- Network connectivity loss
- **Action**: Storage cleanup, ISP coordination

### Level 4: Emergency (24+ hours)
- Data loss
- Host unreachable
- Complete failure
- **Action**: Disaster recovery, restore from backup

---

## Key File Locations

### Proxmox Configuration
- Host config: `/etc/pve/`
- Container configs: `/etc/pve/lxc/<CTID>.conf`
- VM configs: `/etc/pve/qemu-server/<VMID>.conf`
- Storage config: `/etc/pve/storage.cfg`

### Storage Paths
- Container rootfs: `/var/lib/lxc/<CTID>/rootfs/`
- VM disks: `/var/lib/vz/images/<VMID>/`
- Templates: `/var/lib/vz/template/`
- Backups: `/var/lib/vz/dump/`
- ISOs: `/var/lib/vz/template/iso/`

### Logs
- System logs: `/var/log/syslog`
- Proxmox tasks: `/var/log/pve/tasks/`
- Container logs: `/var/log/lxc/<CTID>.log`
- VM logs: `/var/log/qemu-server/<VMID>.log`
- Kernel: `dmesg` or `/var/log/kern.log`

### Tailscale
- State file: `/var/lib/tailscale/tailscaled.state`
- Config: `/etc/tailscale/`
- Logs: `journalctl -u tailscaled`

---

## Useful Command Aliases

Add to ~/.bashrc for quick access:

```bash
# FGSRV07 Quick Commands
alias pve-status='systemctl status pve-manager pvedaemon pveproxy pvestatd --no-pager'
alias pve-ct='pct list'
alias pve-vm='qm list'
alias pve-storage='pvesm status'
alias ts-status='tailscale status --peers'
alias ts-ping='tailscale netcheck'
alias host-health='free -m && df -h && uptime'
alias pve-errors='journalctl -p err -n 50 --no-pager'
alias pve-tasks='tail -f /var/log/pve/tasks/index'
alias host-disks='lsblk && echo "" && df -h'
```

---

## Decision Tree Summary

```
Issue Reported
├─ Host Unreachable?
│  ├─ YES → Check IP connectivity → Check SSH access → ISP issue?
│  └─ NO → Check Proxmox services
│     ├─ Web UI Down → Check pveproxy → Check firewall
│     └─ Web UI Up → Check containers/VMs
│        ├─ Multiple Down → Host resource issue
│        └─ Single Down → Container/VM issue
│           ├─ Check config → Check storage
│           ├─ Check logs → Network issue
│           └─ Resource limit → Resize needed
└─ Tailscale Issue?
   ├─ Not Connected → Check service → Restart
   └─ Connected No Peers → Check auth → Check ACLs
```

---

## Preventive Maintenance

### Daily (Automated)
- Host resource check
- Proxmox service health
- Storage capacity monitoring
- Backup verification
- Tailscale connectivity

### Weekly (Manual)
- Review container/VM performance
- Check log sizes
- Update packages (apt list --upgradable)
- Review security advisories

### Monthly (Scheduled)
- Full backup verification
- Storage cleanup
- Security updates (apt upgrade)
- Capacity planning
- Disaster recovery test

---

## Security Considerations

### Firewall Rules
```bash
# Check current rules
iptables -L -n -v

# Proxmox firewall
pvesh get /cluster/firewall/options

# Essential ports:
# - 22 (SSH) - Restrict to known IPs
# - 8006 (Proxmox Web UI) - VPN only recommended
# - Tailscale (41641) - Managed by tailscale
```

### SSH Hardening
```bash
# /etc/ssh/sshd_config recommendations:
# PermitRootLogin prohibit-password
# PasswordAuthentication no
# PubkeyAuthentication yes
# Port 22 (or change to non-standard)

# Restart after changes
systemctl restart sshd
```

### Update Management
```bash
# Check for updates
apt update
apt list --upgradable

# Upgrade (carefully on production)
apt upgrade

# Check Proxmox version
pveversion

# Check for security advisories
pveversion -v
```

---

## Documentation Reference

**Generated**: 2026-02-09
**Version**: 1.0
**Maintained By**: Hive Mind Documentation Worker
