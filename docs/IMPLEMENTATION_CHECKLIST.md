# AGLSRV1 Remote Storage Implementation Checklist

**Project:** Multi-Host Storage Consolidation via Tailscale VPN
**Timeline:** 4 Weeks (Phased Implementation)
**Status:** Ready for Deployment

---

## Pre-Implementation Verification

### Infrastructure Prerequisites

- [ ] AGLSRV1 server online and accessible
  - [ ] Minimum 32GB RAM available
  - [ ] Minimum 8 CPU cores
  - [ ] Storage pool ~24TB configured
  - [ ] Debian/Ubuntu or Proxmox VE installed
  - [ ] Root access configured

- [ ] Remote hosts verified
  - [ ] AGLSRV6 (100.98.108.66) online
  - [ ] AGLSRV6b (100.98.119.51) online
  - [ ] FGSRV5 (100.71.107.26) online
  - [ ] FGSRV6 (100.83.51.9) online
  - [ ] All running Proxmox VE

- [ ] Tailscale configuration
  - [ ] Tailscale installed on all 5 hosts
  - [ ] All hosts joined to same Tailscale network
  - [ ] Connectivity verified (ping tests pass)
  - [ ] ACLs configured (optional but recommended)

- [ ] Network requirements
  - [ ] Minimum 100 Mbps bandwidth between sites
  - [ ] Latency <50ms between hosts
  - [ ] No restrictive firewalls blocking Tailscale

- [ ] Documentation prepared
  - [ ] Architecture document reviewed
  - [ ] Quick start guide accessible
  - [ ] Emergency contacts list created
  - [ ] Runbooks for common operations

---

## Phase 1: Foundation Setup (Week 1)

### Day 1: Package Installation (AGLSRV1)

- [ ] Update system packages
  ```bash
  apt update && apt upgrade -y
  ```

- [ ] Install NFS server
  ```bash
  apt install -y nfs-kernel-server nfs-common
  ```

- [ ] Install iSCSI target
  ```bash
  apt install -y targetcli-fb
  ```

- [ ] Install Proxmox Backup Server
  ```bash
  # Add PBS repository
  echo "deb http://download.proxmox.com/debian/pbs $(lsb_release -sc) pbs-no-subscription" \
    > /etc/apt/sources.list.d/pbs.list

  # Add GPG key
  wget https://enterprise.proxmox.com/debian/proxmox-release-bullseye.gpg \
    -O /etc/apt/trusted.gpg.d/proxmox-release-bullseye.gpg

  # Install PBS
  apt update
  apt install -y proxmox-backup-server
  ```

- [ ] Install monitoring and utilities
  ```bash
  apt install -y smartmontools iperf3 bc jq mailutils htop iotop
  ```

- [ ] Verify all services installed
  ```bash
  systemctl status nfs-server
  systemctl status target
  systemctl status proxmox-backup
  ```

### Day 2: Directory Structure Creation

- [ ] Create base directories
  ```bash
  mkdir -p /mnt/storage/remote/{aglsrv6,aglsrv6b,fgsrv5,fgsrv6}/{data,backups,iso,templates,staging}
  mkdir -p /mnt/storage/shared/{iso,templates,tools}
  mkdir -p /mnt/storage/iscsi
  ```

- [ ] Set appropriate permissions
  ```bash
  chmod 755 /mnt/storage/remote/*
  chmod 700 /mnt/storage/remote/*/backups
  chmod 755 /mnt/storage/shared/*
  chmod 755 /mnt/storage/iscsi
  ```

- [ ] Verify directory structure
  ```bash
  tree -L 3 /mnt/storage
  ```

### Day 3: Tailscale & Network Configuration

- [ ] Verify Tailscale connectivity
  ```bash
  tailscale status
  ping -c 3 100.98.108.66
  ping -c 3 100.98.119.51
  ping -c 3 100.71.107.26
  ping -c 3 100.83.51.9
  ```

- [ ] Get AGLSRV1 Tailscale IP address
  ```bash
  TAILSCALE_IP=$(ip -4 addr show tailscale0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
  echo $TAILSCALE_IP
  ```

- [ ] Configure UFW firewall
  ```bash
  apt install -y ufw
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow in on tailscale0
  ufw allow from 100.0.0.0/8 to any port 2049 proto tcp comment "NFS"
  ufw allow from 100.0.0.0/8 to any port 111 proto tcp comment "RPC"
  ufw allow from 100.0.0.0/8 to any port 3260 proto tcp comment "iSCSI"
  ufw allow from 100.0.0.0/8 to any port 8007 proto tcp comment "PBS"
  ufw allow from 100.0.0.0/8 to any port 22 proto tcp comment "SSH"
  ufw --force enable
  ufw status verbose
  ```

- [ ] Test firewall rules
  ```bash
  # From remote host, test connectivity:
  nc -zv <AGLSRV1_IP> 2049
  nc -zv <AGLSRV1_IP> 3260
  nc -zv <AGLSRV1_IP> 8007
  ```

### Day 4-5: NFS Server Configuration

- [ ] Create NFS exports configuration
  ```bash
  cat > /etc/exports <<'EOF'
  # AGLSRV6 (100.98.108.66)
  /mnt/storage/remote/aglsrv6/data    100.98.108.66(rw,sync,no_subtree_check,no_root_squash,sec=sys)
  /mnt/storage/remote/aglsrv6/staging 100.98.108.66(rw,async,no_subtree_check,no_root_squash,sec=sys)

  # AGLSRV6b (100.98.119.51)
  /mnt/storage/remote/aglsrv6b/data    100.98.119.51(rw,sync,no_subtree_check,no_root_squash,sec=sys)
  /mnt/storage/remote/aglsrv6b/staging 100.98.119.51(rw,async,no_subtree_check,no_root_squash,sec=sys)

  # FGSRV5 (100.71.107.26)
  /mnt/storage/remote/fgsrv5/data    100.71.107.26(rw,sync,no_subtree_check,no_root_squash,sec=sys)
  /mnt/storage/remote/fgsrv5/staging 100.71.107.26(rw,async,no_subtree_check,no_root_squash,sec=sys)

  # FGSRV6 (100.83.51.9)
  /mnt/storage/remote/fgsrv6/data    100.83.51.9(rw,sync,no_subtree_check,no_root_squash,sec=sys)
  /mnt/storage/remote/fgsrv6/staging 100.83.51.9(rw,async,no_subtree_check,no_root_squash,sec=sys)

  # Shared resources
  /mnt/storage/shared/iso       100.0.0.0/8(ro,sync,no_subtree_check,all_squash,sec=sys)
  /mnt/storage/shared/templates 100.0.0.0/8(ro,sync,no_subtree_check,all_squash,sec=sys)
  EOF
  ```

- [ ] Configure NFS server optimization
  ```bash
  cat > /etc/nfs.conf <<'EOF'
  [nfsd]
  threads=64
  tcp=y
  udp=n
  vers4=y
  vers4.2=y

  [mountd]
  manage-gids=y
  EOF
  ```

- [ ] Apply kernel tuning for VPN performance
  ```bash
  cat > /etc/sysctl.d/99-tailscale-storage.conf <<'EOF'
  # TCP tuning for high-latency VPN
  net.core.rmem_max = 67108864
  net.core.wmem_max = 67108864
  net.ipv4.tcp_rmem = 4096 87380 33554432
  net.ipv4.tcp_wmem = 4096 65536 33554432
  net.ipv4.tcp_congestion_control = bbr
  net.core.default_qdisc = fq

  # NFS optimization
  sunrpc.tcp_slot_table_entries = 128
  EOF

  sysctl -p /etc/sysctl.d/99-tailscale-storage.conf
  ```

- [ ] Apply NFS exports and restart service
  ```bash
  exportfs -arv
  systemctl restart nfs-server
  systemctl enable nfs-server
  systemctl status nfs-server
  ```

- [ ] Verify exports
  ```bash
  showmount -e localhost
  exportfs -v
  ```

### Day 6-7: NFS Client Configuration (Remote Hosts)

**Repeat for each remote host: AGLSRV6, AGLSRV6b, FGSRV5, FGSRV6**

- [ ] Install NFS client packages
  ```bash
  apt install -y nfs-common
  ```

- [ ] Create mount points
  ```bash
  mkdir -p /mnt/aglsrv1/{data,iso,templates,staging}
  ```

- [ ] Test manual mount (replace <AGLSRV1_IP>)
  ```bash
  AGLSRV1_IP="<INSERT_TAILSCALE_IP>"
  mount -t nfs4 -o rw,hard,intr,rsize=1048576,wsize=1048576 \
    $AGLSRV1_IP:/mnt/storage/remote/$(hostname)/data \
    /mnt/aglsrv1/data
  ```

- [ ] Verify mount and test I/O
  ```bash
  df -h /mnt/aglsrv1/data
  touch /mnt/aglsrv1/data/test.txt
  ls -la /mnt/aglsrv1/data/test.txt
  rm /mnt/aglsrv1/data/test.txt
  ```

- [ ] Add to /etc/fstab for persistence
  ```bash
  cat >> /etc/fstab <<EOF
  # AGLSRV1 Remote Storage via Tailscale
  $AGLSRV1_IP:/mnt/storage/remote/$(hostname)/data  /mnt/aglsrv1/data  nfs4  rw,hard,intr,rsize=1048576,wsize=1048576,timeo=600,retrans=2,_netdev  0  0
  $AGLSRV1_IP:/mnt/storage/shared/iso               /mnt/aglsrv1/iso   nfs4  ro,hard,intr,rsize=1048576,timeo=600,_netdev  0  0
  EOF
  ```

- [ ] Test fstab and mount all
  ```bash
  umount /mnt/aglsrv1/data
  mount -a
  df -h | grep aglsrv1
  ```

- [ ] Performance test
  ```bash
  dd if=/dev/zero of=/mnt/aglsrv1/data/test.img bs=1M count=1024 conv=fdatasync
  # Note: Expected 200-400 MB/s write speed
  rm /mnt/aglsrv1/data/test.img
  ```

### Week 1 Completion Checklist

- [ ] All packages installed on AGLSRV1
- [ ] Directory structure created and verified
- [ ] Tailscale connectivity confirmed for all hosts
- [ ] Firewall configured and tested
- [ ] NFS server running and exports configured
- [ ] All 4 remote hosts have NFS mounts active
- [ ] Basic I/O tests pass on all mounts
- [ ] Performance baseline established
- [ ] Week 1 documentation updated

---

## Phase 2: Multi-Protocol Deployment (Week 2)

### Day 8-9: iSCSI Target Configuration

- [ ] Make iSCSI setup script executable
  ```bash
  chmod +x /root/host-admin/config/templates/iscsi-target-setup.sh
  ```

- [ ] Review script configuration (optional: customize LUN sizes)
  ```bash
  cat /root/host-admin/config/templates/iscsi-target-setup.sh
  # Default: 500GB per LUN
  ```

- [ ] Run iSCSI target setup script
  ```bash
  /root/host-admin/config/templates/iscsi-target-setup.sh 2>&1 | tee /var/log/iscsi-setup.log
  ```

- [ ] Verify iSCSI configuration
  ```bash
  targetcli ls
  systemctl status target
  ```

- [ ] Save CHAP credentials securely
  ```bash
  cat /root/iscsi-chap-credentials.txt
  chmod 600 /root/iscsi-chap-credentials.txt
  # Format: hostname:username:password
  ```

- [ ] Test iSCSI target listening
  ```bash
  ss -tln | grep 3260
  ```

### Day 10-11: iSCSI Initiator Configuration (Remote Hosts)

**Repeat for each remote host: AGLSRV6, AGLSRV6b, FGSRV5, FGSRV6**

- [ ] Install iSCSI initiator
  ```bash
  apt install -y open-iscsi
  ```

- [ ] Set initiator name (replace hostname appropriately)
  ```bash
  echo "InitiatorName=iqn.2025-01.local.$(hostname):initiator" > /etc/iscsi/initiatorname.iscsi
  ```

- [ ] Get CHAP credentials from AGLSRV1
  ```bash
  # SSH to AGLSRV1 and get credentials:
  ssh root@<AGLSRV1_IP> "grep '^$(hostname):' /root/iscsi-chap-credentials.txt"
  # Save username and password
  ```

- [ ] Configure CHAP authentication
  ```bash
  CHAP_USER="<from_credentials>"
  CHAP_PASS="<from_credentials>"

  cat >> /etc/iscsi/iscsid.conf <<EOF
  node.session.auth.authmethod = CHAP
  node.session.auth.username = $CHAP_USER
  node.session.auth.password = $CHAP_PASS
  node.session.timeo.replacement_timeout = 120
  node.conn[0].timeo.noop_out_interval = 5
  node.conn[0].timeo.noop_out_timeout = 10
  EOF
  ```

- [ ] Restart iSCSI services
  ```bash
  systemctl restart iscsid open-iscsi
  systemctl enable iscsid open-iscsi
  ```

- [ ] Discover iSCSI targets
  ```bash
  AGLSRV1_IP="<INSERT_TAILSCALE_IP>"
  iscsiadm -m discovery -t st -p $AGLSRV1_IP:3260
  ```

- [ ] Login to target
  ```bash
  iscsiadm -m node --targetname iqn.2025-01.local.aglsrv1:storage \
    --portal $AGLSRV1_IP:3260 --login
  ```

- [ ] Verify iSCSI session
  ```bash
  iscsiadm -m session
  lsblk
  # Look for new 500GB disk (e.g., /dev/sdb)
  ```

- [ ] Optional: Create LVM on iSCSI device
  ```bash
  ISCSI_DEV=$(lsblk -d -n -o NAME,SIZE | grep 500G | awk '{print $1}')
  pvcreate /dev/$ISCSI_DEV
  vgcreate iscsi-remote /dev/$ISCSI_DEV
  pvesm add lvm iscsi-remote --vgname iscsi-remote --content images,rootdir
  ```

- [ ] Performance test
  ```bash
  fio --name=iscsi-test --filename=/dev/$ISCSI_DEV --size=1G \
    --rw=randwrite --bs=4k --direct=1 --numjobs=4 --time_based --runtime=60
  ```

### Day 12-13: PBS Datastore Configuration

- [ ] Make PBS setup script executable
  ```bash
  chmod +x /root/host-admin/config/templates/pbs-datastore-setup.sh
  ```

- [ ] Run PBS datastore setup
  ```bash
  /root/host-admin/config/templates/pbs-datastore-setup.sh 2>&1 | tee /var/log/pbs-setup.log
  ```

- [ ] Verify PBS service
  ```bash
  systemctl status proxmox-backup
  ```

- [ ] Check datastores created
  ```bash
  proxmox-backup-manager datastore list
  ```

- [ ] Save API token
  ```bash
  cat /root/pbs-api-token.txt
  chmod 600 /root/pbs-api-token.txt
  # Format: backup@pbs!remote-backup:TOKEN_SECRET
  ```

- [ ] Get PBS certificate fingerprint
  ```bash
  proxmox-backup-manager cert info | grep Fingerprint
  ```

- [ ] Test PBS web UI access
  ```bash
  # From browser: https://<AGLSRV1_TAILSCALE_IP>:8007
  # Login with root@pam or backup@pbs
  ```

### Day 14: PBS Client Configuration (Remote Hosts)

**For AGLSRV6 and AGLSRV6b (which have PBS containers):**

- [ ] Get configuration values
  ```bash
  # From AGLSRV1:
  AGLSRV1_IP="<TAILSCALE_IP>"
  PBS_TOKEN="<from /root/pbs-api-token.txt>"
  PBS_FINGERPRINT="<from cert info command>"
  ```

- [ ] Add PBS storage to Proxmox
  ```bash
  HOSTNAME=$(hostname)
  pvesm add pbs remote-pbs-aglsrv1 \
    --server $AGLSRV1_IP \
    --datastore remote-$HOSTNAME \
    --username backup@pbs \
    --password $PBS_TOKEN \
    --fingerprint $PBS_FINGERPRINT
  ```

- [ ] Verify PBS storage added
  ```bash
  pvesm status | grep pbs
  ```

- [ ] Create test backup job via web UI
  ```
  Datacenter > Backup > Add
  - Storage: remote-pbs-aglsrv1
  - Schedule: Manual (for testing)
  - Mode: Snapshot
  - Compression: zstd
  ```

- [ ] Run manual backup test
  ```bash
  vzdump <VMID> --storage remote-pbs-aglsrv1 --mode snapshot --compress zstd
  ```

- [ ] Verify backup on PBS server
  ```bash
  # On AGLSRV1:
  proxmox-backup-client list --repository backup@pbs@localhost:remote-$(hostname)
  ```

### Week 2 Completion Checklist

- [ ] iSCSI target configured on AGLSRV1
- [ ] All 4 remote hosts have active iSCSI sessions
- [ ] iSCSI LUNs accessible and tested on remote hosts
- [ ] PBS datastores created for all hosts
- [ ] PBS storage added to AGLSRV6/6b Proxmox instances
- [ ] First successful backup completed
- [ ] Performance benchmarks recorded
- [ ] CHAP credentials and API tokens secured
- [ ] Week 2 documentation updated

---

## Phase 3: Migration & Integration (Week 3)

### Day 15-16: Data Migration Planning

- [ ] Inventory existing VMs and containers
  ```bash
  # On each remote host:
  qm list
  pct list
  ```

- [ ] Identify VMs/CTs for migration
  - [ ] Create migration priority list
  - [ ] Identify dependencies
  - [ ] Plan migration order

- [ ] Calculate storage requirements
  ```bash
  # Check disk usage per VM/CT:
  qm config <VMID> | grep size
  pct config <CTID> | grep rootfs
  ```

- [ ] Create migration plan document
  - [ ] VM/CT inventory spreadsheet
  - [ ] Migration schedule
  - [ ] Rollback procedures

### Day 17-18: VM/CT Migration

**For each VM to migrate:**

- [ ] Stop VM (or live migrate if possible)
  ```bash
  qm stop <VMID>
  ```

- [ ] Move disk to remote NFS storage
  ```bash
  qm move_disk <VMID> scsi0 remote-nfs-aglsrv1 --delete
  ```

- [ ] Update VM configuration
  ```bash
  qm set <VMID> --scsi0 remote-nfs-aglsrv1:vm-<VMID>-disk-0
  ```

- [ ] Start VM and verify
  ```bash
  qm start <VMID>
  qm status <VMID>
  ```

**For containers:**

- [ ] Stop container
  ```bash
  pct stop <CTID>
  ```

- [ ] Migrate rootfs
  ```bash
  pct move_volume <CTID> rootfs remote-nfs-aglsrv1
  ```

- [ ] Start container and verify
  ```bash
  pct start <CTID>
  pct status <CTID>
  ```

- [ ] Migration tracking
  - [ ] VM/CT 1 migrated and verified
  - [ ] VM/CT 2 migrated and verified
  - [ ] VM/CT 3 migrated and verified
  - [ ] (Continue for all VMs/CTs)

### Day 19: Backup Integration

- [ ] Create automated backup schedules
  ```
  Via Proxmox Web UI:
  Datacenter > Backup > Add

  For each host:
  - Storage: remote-pbs-aglsrv1
  - Schedule: Daily at 02:00
  - Selection mode: All
  - Retention: 7 daily, 4 weekly, 6 monthly
  - Mode: Snapshot
  - Compression: zstd
  - Enable: Yes
  ```

- [ ] Verify backup schedules created
  ```bash
  cat /etc/pve/vzdump.cron
  ```

- [ ] Test automated backup
  ```bash
  # Wait for scheduled time or trigger manually:
  vzdump --all --storage remote-pbs-aglsrv1
  ```

- [ ] Verify backups on PBS
  ```bash
  # On AGLSRV1:
  proxmox-backup-manager datastore status
  ```

### Day 20-21: Monitoring Deployment

- [ ] Make health monitor script executable
  ```bash
  chmod +x /root/host-admin/scripts/storage-health-monitor.sh
  ```

- [ ] Run manual health check
  ```bash
  /root/host-admin/scripts/storage-health-monitor.sh
  ```

- [ ] Review health check output
  - [ ] All remote hosts reachable
  - [ ] NFS exports healthy
  - [ ] iSCSI sessions active
  - [ ] PBS datastores accessible
  - [ ] Disk usage within limits

- [ ] Configure email alerts (optional)
  ```bash
  apt install -y mailutils
  echo "ALERT_EMAIL=admin@example.com" >> /etc/environment
  ```

- [ ] Schedule daily health checks
  ```bash
  cat > /etc/cron.d/storage-health <<'EOF'
  # Daily storage health check at 6 AM
  0 6 * * * root /root/host-admin/scripts/storage-health-monitor.sh
  EOF
  ```

- [ ] Test cron job
  ```bash
  # Run manually to test:
  /usr/bin/run-parts --test /etc/cron.d
  ```

### Week 3 Completion Checklist

- [ ] Data migration plan created and approved
- [ ] All critical VMs/CTs migrated to remote storage
- [ ] Automated backup schedules configured
- [ ] First automated backups completed successfully
- [ ] Health monitoring deployed and tested
- [ ] Cron jobs configured for automated checks
- [ ] Migration documentation completed
- [ ] Week 3 sign-off obtained

---

## Phase 4: Hardening & Production Readiness (Week 4)

### Day 22: Security Hardening

- [ ] Enable automatic security updates
  ```bash
  apt install -y unattended-upgrades
  dpkg-reconfigure --priority=low unattended-upgrades
  ```

- [ ] Harden SSH configuration (all hosts)
  ```bash
  sed -i 's/#PermitRootLogin yes/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
  sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
  systemctl restart sshd
  ```

- [ ] Enable audit logging
  ```bash
  apt install -y auditd
  auditctl -w /mnt/storage/remote -p wa -k remote-storage-access
  auditctl -w /etc/exports -p wa -k nfs-config-change
  auditctl -w /etc/iscsi/ -p wa -k iscsi-config-change
  ```

- [ ] Review and tighten firewall rules
  ```bash
  ufw status verbose
  # Verify only Tailscale network has access
  ```

- [ ] Secure credentials
  ```bash
  chmod 600 /root/iscsi-chap-credentials.txt
  chmod 600 /root/pbs-api-token.txt
  ```

### Day 23: Performance Testing

- [ ] NFS performance benchmark
  ```bash
  # On each remote host:
  dd if=/dev/zero of=/mnt/aglsrv1/data/test.img bs=1M count=10240 conv=fdatasync
  # Expected: 200-400 MB/s
  rm /mnt/aglsrv1/data/test.img
  ```

- [ ] iSCSI performance benchmark
  ```bash
  # Install fio if needed:
  apt install -y fio

  # Run benchmark:
  fio --name=iscsi-seq-read --filename=/dev/<ISCSI_DEV> \
    --rw=read --bs=1M --size=5G --direct=1 --runtime=60 --time_based

  fio --name=iscsi-rand-write --filename=/dev/<ISCSI_DEV> \
    --rw=randwrite --bs=4k --size=1G --direct=1 --numjobs=4 --runtime=60 --time_based
  ```

- [ ] Network throughput test
  ```bash
  # Install iperf3 on both AGLSRV1 and remote hosts:
  apt install -y iperf3

  # On AGLSRV1 (server):
  iperf3 -s

  # On remote host (client):
  iperf3 -c <AGLSRV1_IP> -t 30 -P 4
  # Expected: 100-500 Mbps depending on network
  ```

- [ ] PBS backup performance test
  ```bash
  # Run full backup of a large VM:
  time vzdump <LARGE_VMID> --storage remote-pbs-aglsrv1 --mode snapshot --compress zstd
  # Note duration and throughput
  ```

- [ ] Document performance baselines
  - [ ] NFS read/write speeds
  - [ ] iSCSI read/write/latency
  - [ ] Network throughput
  - [ ] Backup speeds
  - [ ] Restore speeds

### Day 24: Failover Testing

- [ ] Test NFS failover
  ```bash
  # On AGLSRV1, stop NFS temporarily:
  systemctl stop nfs-server

  # On remote host, verify graceful handling:
  # (should hang, not crash)

  # Restart NFS:
  systemctl start nfs-server

  # Verify auto-reconnect on remote host:
  df -h | grep aglsrv1
  ```

- [ ] Test iSCSI failover
  ```bash
  # On AGLSRV1, stop target:
  systemctl stop target

  # On remote host, check session status:
  iscsiadm -m session

  # Restart target:
  systemctl start target

  # Verify auto-reconnect:
  iscsiadm -m session
  ```

- [ ] Test Tailscale reconnection
  ```bash
  # On AGLSRV1, restart Tailscale:
  systemctl restart tailscaled

  # Verify all remote hosts reconnect:
  tailscale status
  ```

- [ ] Test service restart procedures
  ```bash
  # Test full service restart sequence:
  systemctl restart nfs-server target proxmox-backup

  # Verify all services come back online:
  systemctl status nfs-server target proxmox-backup
  ```

### Day 25: Disaster Recovery Testing

- [ ] Create disaster recovery documentation
  - [ ] Service restart procedures
  - [ ] Emergency unmount procedures
  - [ ] Backup restoration procedures
  - [ ] Contact escalation matrix

- [ ] Test backup restoration
  ```bash
  # Restore a VM from backup to verify process:
  qmrestore remote-pbs-aglsrv1:backup/vm/<VMID>/... <TEST_VMID> --storage local-lvm

  # Start restored VM and verify:
  qm start <TEST_VMID>
  ```

- [ ] Test offsite backup (if configured)
  ```bash
  # Install rclone:
  curl https://rclone.org/install.sh | bash

  # Configure rclone for S3/B2:
  rclone config

  # Test sync:
  rclone sync /mnt/storage/remote/aglsrv6/backups/ \
    remote-s3:backup-bucket/test/ --dry-run
  ```

- [ ] Document and test emergency procedures
  - [ ] Server failure scenario
  - [ ] Network partition scenario
  - [ ] Disk failure scenario

### Day 26-27: User Acceptance Testing

- [ ] Create test plan
  - [ ] VM creation on remote storage
  - [ ] Container creation on remote storage
  - [ ] Backup and restore workflows
  - [ ] Performance validation
  - [ ] Monitoring alerts

- [ ] Execute test plan
  - [ ] Test case 1: Create VM on NFS storage
  - [ ] Test case 2: Create VM on iSCSI LUN
  - [ ] Test case 3: Migrate running VM
  - [ ] Test case 4: Backup and restore VM
  - [ ] Test case 5: Access shared ISO library
  - [ ] Test case 6: Trigger monitoring alerts

- [ ] Performance acceptance criteria
  - [ ] NFS throughput ≥200 MB/s ✓
  - [ ] iSCSI throughput ≥250 MB/s ✓
  - [ ] Backup completion within 4 hours ✓
  - [ ] Network latency <50ms ✓

- [ ] Obtain UAT sign-off
  - [ ] Operations team approval
  - [ ] Network team approval
  - [ ] Security team approval

### Day 28: Production Go-Live

- [ ] Final pre-production checklist
  - [ ] All systems healthy
  - [ ] All backups successful (last 7 days)
  - [ ] Monitoring operational
  - [ ] Documentation complete
  - [ ] Training completed

- [ ] Create production cutover plan
  - [ ] Communication plan
  - [ ] Rollback procedures
  - [ ] Success criteria

- [ ] Execute production cutover
  - [ ] Announce maintenance window
  - [ ] Final migration of remaining VMs/CTs
  - [ ] Verify all services operational
  - [ ] Update DNS/documentation as needed

- [ ] Post-production validation
  - [ ] All VMs/CTs running from remote storage
  - [ ] All backup jobs executing successfully
  - [ ] Monitoring alerts configured and tested
  - [ ] Performance within expected ranges

- [ ] Production acceptance
  - [ ] Final walkthrough with stakeholders
  - [ ] Obtain production sign-off
  - [ ] Close project

### Week 4 Completion Checklist

- [ ] Security hardening completed
- [ ] Performance benchmarks meet criteria
- [ ] Failover procedures tested
- [ ] Disaster recovery plan documented and tested
- [ ] User acceptance testing passed
- [ ] Production deployment successful
- [ ] All documentation finalized
- [ ] Training materials delivered
- [ ] Project sign-off obtained

---

## Post-Implementation (Ongoing)

### Daily Operations

- [ ] Monitor health check logs
  ```bash
  tail -f /var/log/storage-health.log
  ```

- [ ] Review backup status
  ```bash
  proxmox-backup-manager datastore status
  ```

- [ ] Check disk space
  ```bash
  df -h /mnt/storage
  ```

### Weekly Tasks

- [ ] Review performance metrics
- [ ] Verify backup retention
- [ ] Check for security updates
- [ ] Review audit logs

### Monthly Tasks

- [ ] Test disaster recovery procedures
- [ ] Review capacity planning
- [ ] Update documentation
- [ ] Review and update runbooks

### Quarterly Tasks

- [ ] Full DR drill
- [ ] Performance optimization review
- [ ] Security audit
- [ ] Capacity planning review

---

## Success Metrics

### Availability Targets

- [ ] System uptime: ≥99.5%
- [ ] NFS mount availability: ≥99.9%
- [ ] iSCSI session stability: ≥99%
- [ ] Backup success rate: ≥95%

### Performance Targets

- [ ] NFS throughput: ≥200 MB/s
- [ ] iSCSI throughput: ≥250 MB/s
- [ ] Network latency: <50ms
- [ ] Backup completion: <4 hours

### Operational Targets

- [ ] Mean time to detect (MTTD): <5 minutes
- [ ] Mean time to respond (MTTR): <15 minutes
- [ ] RTO (Recovery Time Objective): <2 hours
- [ ] RPO (Recovery Point Objective): <24 hours

---

## Project Sign-Off

### Architecture Review

- [ ] **System Architect:** _________________ Date: _______
- [ ] **Network Engineer:** _________________ Date: _______
- [ ] **Security Officer:** _________________ Date: _______

### Implementation Approval

- [ ] **Operations Manager:** _________________ Date: _______
- [ ] **IT Director:** _________________ Date: _______

### Production Acceptance

- [ ] **Service Owner:** _________________ Date: _______
- [ ] **Change Manager:** _________________ Date: _______

---

**Document Version:** 1.0
**Created:** 2025-10-14
**Status:** Ready for Implementation
