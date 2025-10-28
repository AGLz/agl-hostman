# WireGuard Peer Setup - Tasks Breakdown

**Estimated Total Time**: 15-20 minutes
**Category**: Infrastructure Deployment
**Type**: Network Configuration

---

## Phase 1: Pre-Deployment Validation (5 minutes)

### Prerequisites Check

- [ ] **[P0]** Task 1.1: Verify target accessibility
  - **Acceptance**: Can SSH to target via LAN or Tailscale
  - **Commands**: `ssh root@<target-ip> 'hostname'`
  - **Priority**: CRITICAL - Must complete before proceeding

- [ ] **[P0]** Task 1.2: Verify WireGuard package installed
  - **Acceptance**: `wg --version` returns version info
  - **Commands**: `ssh root@<target-ip> 'wg --version || apt install -y wireguard'`
  - **Priority**: CRITICAL

- [ ] **[P0]** Task 1.3: Reserve IP address and port
  - **Acceptance**: IP (10.6.0.X) and port (518XX) assigned and documented
  - **IP Range**: 10.6.0.0/24 (avoid 1-20, check INFRA.md)
  - **Port Range**: 51800-51899
  - **Priority**: CRITICAL

- [ ] **[P1]** Task 1.4: Verify LXC container configuration (if applicable)
  - **Depends on**: Task 1.1
  - **Acceptance**: Container has `features: keyctl=1,nesting=1` in `/etc/pve/lxc/<VMID>.conf`
  - **Commands**:
    ```bash
    ssh root@<proxmox-host> "grep -E 'keyctl|nesting' /etc/pve/lxc/<VMID>.conf"
    ```
  - **Priority**: IMPORTANT (skip if Proxmox host)
  - **Fix if missing**: Add to container config and restart

---

## Phase 2: Key Generation and Configuration (3 minutes)

### Generate Keys

- [ ] **[P0]** Task 2.1: Generate WireGuard keys on target
  - **Depends on**: Task 1.1, Task 1.2
  - **Acceptance**: Private and public keys exist at `/etc/wireguard/privatekey` and `/etc/wireguard/publickey`
  - **Commands**:
    ```bash
    ssh root@<target-ip> "wg genkey | tee /etc/wireguard/privatekey | wg pubkey > /etc/wireguard/publickey"
    ```
  - **Priority**: CRITICAL

- [ ] **[P0]** Task 2.2: Store keys in variables
  - **Depends on**: Task 2.1
  - **Acceptance**: PRIVATE_KEY and PUBLIC_KEY variables populated
  - **Commands**:
    ```bash
    PRIVATE_KEY=$(ssh root@<target-ip> "cat /etc/wireguard/privatekey")
    PUBLIC_KEY=$(ssh root@<target-ip> "cat /etc/wireguard/publickey")
    echo "Public Key: $PUBLIC_KEY"
    ```
  - **Priority**: CRITICAL
  - **Note**: Save PUBLIC_KEY for hub registration (Task 3.1)

### Create Configuration

- [ ] **[P0]** Task 2.3: Determine configuration template
  - **Depends on**: Task 1.1
  - **Acceptance**: Correct template selected (LXC vs Proxmox host)
  - **Decision Logic**:
    - LXC container → NO PresharedKey template
    - Proxmox host → WITH PresharedKey template
  - **Priority**: CRITICAL
  - **⚠️ WARNING**: Wrong template causes handshake failure!

- [ ] **[P0]** Task 2.4: Create WireGuard configuration file
  - **Depends on**: Task 2.2, Task 2.3, Task 1.3
  - **Acceptance**: `/etc/wireguard/wg0.conf` exists with correct template
  - **Commands**:
    ```bash
    # For LXC Containers (NO PresharedKey)
    ssh root@<target-ip> "cat > /etc/wireguard/wg0.conf <<EOF
    [Interface]
    PrivateKey = $PRIVATE_KEY
    Address = 10.6.0.X/24
    DNS = 1.1.1.1
    MTU = 1420

    [Peer]
    PublicKey = Dj8XsoPeDlgnqA4Ox++yDy+t4xGxYtEevxQh513fSA8=
    AllowedIPs = 10.6.0.0/24
    PersistentKeepalive = 25
    Endpoint = 186.202.57.120:51823
    EOF
    "

    # For Proxmox Hosts (WITH PresharedKey)
    # Add this line after PublicKey:
    # PresharedKey = DDvQ3xJ9Rs5pbEzXLuGCdep66zBuVNcy654+A/vD+Zk=
    ```
  - **Priority**: CRITICAL
  - **⚠️ CRITICAL RULES**:
    - AllowedIPs MUST be `10.6.0.0/24` (NOT `0.0.0.0/0`)
    - MTU MUST be 1420
    - Replace `10.6.0.X` with reserved IP from Task 1.3

- [ ] **[P1]** Task 2.5: Set secure permissions on configuration
  - **Depends on**: Task 2.4
  - **Acceptance**: Config file has 0600 permissions
  - **Commands**:
    ```bash
    ssh root@<target-ip> "chmod 600 /etc/wireguard/wg0.conf"
    ```
  - **Priority**: IMPORTANT (security)

---

## Phase 3: Hub Registration (3 minutes)

### Register on FGSRV6 Hub

- [ ] **[P0]** Task 3.1: Add peer configuration to hub
  - **Depends on**: Task 2.2 (need PUBLIC_KEY)
  - **Acceptance**: Peer entry added to hub's `/etc/wireguard/wg0.conf`
  - **Commands**:
    ```bash
    ssh root@186.202.57.120 "cat >> /etc/wireguard/wg0.conf <<EOF

    [Peer]
    PublicKey = $PUBLIC_KEY
    AllowedIPs = 10.6.0.X/32
    EOF
    "
    ```
  - **Priority**: CRITICAL
  - **Note**: Replace `10.6.0.X` with reserved IP

- [ ] **[P0]** Task 3.2: Reload hub configuration
  - **Depends on**: Task 3.1
  - **Acceptance**: Hub shows new peer in `wg show`
  - **Commands**:
    ```bash
    ssh root@186.202.57.120 "wg syncconf wg0 <(wg-quick strip wg0)"
    ssh root@186.202.57.120 "wg show | grep -A 3 '$PUBLIC_KEY'"
    ```
  - **Priority**: CRITICAL

---

## Phase 4: Peer Activation (2 minutes)

### Start WireGuard Service

- [ ] **[P0]** Task 4.1: Start WireGuard interface on peer
  - **Depends on**: Task 2.4, Task 3.2
  - **Acceptance**: `wg0` interface is up and running
  - **Commands**:
    ```bash
    ssh root@<target-ip> "wg-quick up wg0"
    ```
  - **Priority**: CRITICAL
  - **Expected**: No errors, interface starts successfully

- [ ] **[P0]** Task 4.2: Enable WireGuard on boot
  - **Depends on**: Task 4.1
  - **Acceptance**: WireGuard service enabled via systemd
  - **Commands**:
    ```bash
    ssh root@<target-ip> "systemctl enable wg-quick@wg0"
    ssh root@<target-ip> "systemctl status wg-quick@wg0"
    ```
  - **Priority**: CRITICAL

---

## Phase 5: Verification and Testing (5 minutes)

### Connectivity Tests

- [ ] **[P0]** Task 5.1: Verify WireGuard handshake established
  - **Depends on**: Task 4.1
  - **Acceptance**: `wg show` displays handshake timestamp < 60 seconds ago
  - **Commands**:
    ```bash
    ssh root@<target-ip> "wg show"
    ```
  - **Priority**: CRITICAL
  - **Expected Output**:
    ```
    interface: wg0
      peer: Dj8X... (hub)
        endpoint: 186.202.57.120:51823
        allowed ips: 10.6.0.0/24
        latest handshake: X seconds ago
        transfer: X received, Y sent
    ```

- [ ] **[P0]** Task 5.2: Test connectivity to hub (FGSRV6)
  - **Depends on**: Task 5.1
  - **Acceptance**: Can ping 10.6.0.5 with < 50ms latency
  - **Commands**:
    ```bash
    ssh root@<target-ip> "ping -c 3 10.6.0.5"
    ```
  - **Priority**: CRITICAL

- [ ] **[P0]** Task 5.3: Test connectivity to AGLSRV1
  - **Depends on**: Task 5.1
  - **Acceptance**: Can ping 10.6.0.10 successfully
  - **Commands**:
    ```bash
    ssh root@<target-ip> "ping -c 3 10.6.0.10"
    ```
  - **Priority**: CRITICAL

- [ ] **[P1]** Task 5.4: Test connectivity to AGLSRV6
  - **Depends on**: Task 5.1
  - **Acceptance**: Can ping 10.6.0.12 successfully
  - **Commands**:
    ```bash
    ssh root@<target-ip> "ping -c 3 10.6.0.12"
    ```
  - **Priority**: IMPORTANT

- [ ] **[P1]** Task 5.5: Verify routing table
  - **Depends on**: Task 4.1
  - **Acceptance**: Route to 10.6.0.0/24 via wg0 exists
  - **Commands**:
    ```bash
    ssh root@<target-ip> "ip route | grep wg0"
    ```
  - **Priority**: IMPORTANT

- [ ] **[P1]** Task 5.6: Check transfer statistics
  - **Depends on**: Task 5.2
  - **Acceptance**: `wg show` displays non-zero transfer bytes
  - **Commands**:
    ```bash
    ssh root@<target-ip> "wg show wg0 transfer"
    ```
  - **Priority**: IMPORTANT (confirms bidirectional traffic)

---

## Phase 6: Documentation Update (2 minutes)

### Update Infrastructure Documentation

- [ ] **[P0]** Task 6.1: Update WireGuard Mesh Status in INFRA.md
  - **Depends on**: Task 5.2, Task 5.3
  - **Acceptance**: New peer added to WireGuard Mesh Status table
  - **File**: `docs/INFRA.md`
  - **Changes**:
    - Add row to WireGuard Mesh Status table
    - Include: Node name, IP (10.6.0.X), Port (518XX), Type, Status (✅)
  - **Priority**: CRITICAL (documentation drift prevention)

- [ ] **[P1]** Task 6.2: Update infrastructure map in CLAUDE.md (if major host)
  - **Depends on**: Task 6.1
  - **Acceptance**: New host/container added to infrastructure map
  - **File**: `CLAUDE.md`
  - **Condition**: Only if Proxmox host or critical container
  - **Priority**: IMPORTANT

- [ ] **[P0]** Task 6.3: Commit documentation changes
  - **Depends on**: Task 6.1
  - **Acceptance**: Git commit created with descriptive message
  - **Commands**:
    ```bash
    cd /mnt/overpower/apps/dev/agl/agl-hostman
    git add docs/INFRA.md CLAUDE.md
    git commit -m "docs: add WireGuard peer 10.6.0.X (<peer-name>)

    - Added <peer-name> to WireGuard mesh (10.6.0.X)
    - Port: 518XX
    - Type: <LXC container|Proxmox host>
    - Latency to hub: Xms"
    ```
  - **Priority**: CRITICAL

---

## Phase 7: Troubleshooting (Contingency - As Needed)

### Common Issues Resolution

- [ ] **[P2]** Task 7.1: Fix handshake failure (if occurs)
  - **Trigger**: Task 5.1 fails (no handshake after 60 seconds)
  - **Symptoms**: `wg show` displays no handshake timestamp
  - **Root Causes**:
    1. PresharedKey in LXC container
    2. Wrong AllowedIPs (0.0.0.0/0)
    3. Firewall blocking UDP 51823
  - **Fix Procedure**:
    ```bash
    # Diagnose
    ssh root@<target-ip> "wg show"
    ssh root@<target-ip> "grep -E 'PresharedKey|AllowedIPs' /etc/wireguard/wg0.conf"

    # Fix - Remove PresharedKey (LXC only)
    ssh root@<target-ip> "sed -i '/^PresharedKey =/d' /etc/wireguard/wg0.conf"

    # Fix - Correct AllowedIPs
    ssh root@<target-ip> "sed -i 's/^AllowedIPs = 0\.0\.0\.0\/0/AllowedIPs = 10.6.0.0\/24/' /etc/wireguard/wg0.conf"

    # Restart WireGuard
    ssh root@<target-ip> "wg-quick down wg0 && sleep 2 && wg-quick up wg0"

    # Verify fix
    ssh root@<target-ip> "wg show"
    ```
  - **Priority**: CONTINGENCY

- [ ] **[P2]** Task 7.2: Fix LXC container WireGuard startup failure (if occurs)
  - **Trigger**: Task 4.1 fails
  - **Symptoms**: `wg-quick up wg0` returns error
  - **Root Cause**: Missing LXC features
  - **Fix Procedure**:
    ```bash
    # Stop container
    ssh root@<proxmox-host> "pct stop <VMID>"

    # Edit container config
    ssh root@<proxmox-host> "cat >> /etc/pve/lxc/<VMID>.conf <<EOF
    features: keyctl=1,nesting=1
    lxc.cgroup2.devices.allow: c 10:200 rwm
    lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
    EOF
    "

    # Restart container
    ssh root@<proxmox-host> "pct start <VMID>"

    # Retry WireGuard startup
    ssh root@<target-ip> "wg-quick up wg0"
    ```
  - **Priority**: CONTINGENCY

- [ ] **[P2]** Task 7.3: Debug network routing issues (if occurs)
  - **Trigger**: Task 5.2/5.3 fails (cannot ping peers)
  - **Symptoms**: Handshake OK but ping fails
  - **Diagnostic Commands**:
    ```bash
    # Check routing
    ssh root@<target-ip> "ip route show | grep wg0"

    # Check firewall
    ssh root@<target-ip> "iptables -L -n -v | grep wg0"

    # Check hub routing
    ssh root@186.202.57.120 "wg show | grep -A 3 '$PUBLIC_KEY'"

    # Traceroute
    ssh root@<target-ip> "traceroute -n 10.6.0.5"
    ```
  - **Priority**: CONTINGENCY

---

## Success Criteria Checklist

- [ ] ✅ WireGuard handshake established (< 60 seconds ago)
- [ ] ✅ Can ping hub at 10.6.0.5
- [ ] ✅ Can ping AGLSRV1 at 10.6.0.10
- [ ] ✅ Can ping AGLSRV6 at 10.6.0.12
- [ ] ✅ `wg show` displays correct endpoint (186.202.57.120:51823)
- [ ] ✅ Transfer statistics show bidirectional traffic
- [ ] ✅ WireGuard enabled on boot (systemctl)
- [ ] ✅ Peer registered on hub (FGSRV6)
- [ ] ✅ Documentation updated in git (INFRA.md)
- [ ] ✅ Git commit created

---

## Task Execution Order

**Critical Path** (must be sequential):
1. Phase 1 (Prerequisites) → Phase 2 (Keys & Config)
2. Phase 2 → Phase 3 (Hub Registration)
3. Phase 3 → Phase 4 (Activation)
4. Phase 4 → Phase 5 (Verification)
5. Phase 5 → Phase 6 (Documentation)

**Parallel Opportunities**:
- Task 5.2, 5.3, 5.4 can run concurrently (ping tests)
- Task 6.1 and 6.2 can be prepared while verification runs

**Contingency**:
- Phase 7 tasks only run if verification fails

---

## Quick Reference Commands

### Full Deployment Script (Copy-Paste Ready)
```bash
# Variables (REPLACE THESE)
TARGET_IP="<target-ip>"
NEW_IP="10.6.0.X"
NEW_PORT="518XX"
VMID="<vmid>"  # If LXC container
PEER_TYPE="<lxc|host>"  # lxc or host

# Phase 1: Validation
ssh root@$TARGET_IP 'hostname'
ssh root@$TARGET_IP 'wg --version'

# Phase 2: Keys & Config
ssh root@$TARGET_IP "wg genkey | tee /etc/wireguard/privatekey | wg pubkey > /etc/wireguard/publickey"
PUBLIC_KEY=$(ssh root@$TARGET_IP "cat /etc/wireguard/publickey")
PRIVATE_KEY=$(ssh root@$TARGET_IP "cat /etc/wireguard/privatekey")

# Create config (LXC - no PresharedKey)
if [ "$PEER_TYPE" = "lxc" ]; then
  ssh root@$TARGET_IP "cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
PrivateKey = $PRIVATE_KEY
Address = $NEW_IP/24
DNS = 1.1.1.1
MTU = 1420

[Peer]
PublicKey = Dj8XsoPeDlgnqA4Ox++yDy+t4xGxYtEevxQh513fSA8=
AllowedIPs = 10.6.0.0/24
PersistentKeepalive = 25
Endpoint = 186.202.57.120:51823
EOF
"
fi

# Phase 3: Hub Registration
ssh root@186.202.57.120 "cat >> /etc/wireguard/wg0.conf <<EOF

[Peer]
PublicKey = $PUBLIC_KEY
AllowedIPs = $NEW_IP/32
EOF
"
ssh root@186.202.57.120 "wg syncconf wg0 <(wg-quick strip wg0)"

# Phase 4: Activation
ssh root@$TARGET_IP "wg-quick up wg0"
ssh root@$TARGET_IP "systemctl enable wg-quick@wg0"

# Phase 5: Verification
ssh root@$TARGET_IP "wg show"
ssh root@$TARGET_IP "ping -c 3 10.6.0.5"
ssh root@$TARGET_IP "ping -c 3 10.6.0.10"

echo "Deployment complete! Public key: $PUBLIC_KEY"
```

---

## Notes

- **Estimated time breakdown**:
  - Phase 1: 5 minutes
  - Phase 2: 3 minutes
  - Phase 3: 3 minutes
  - Phase 4: 2 minutes
  - Phase 5: 5 minutes
  - Phase 6: 2 minutes
  - **Total**: 20 minutes (without troubleshooting)

- **Risk areas**:
  - Wrong configuration template (PresharedKey in LXC)
  - AllowedIPs set to 0.0.0.0/0 (breaks local network)
  - Missing LXC features (keyctl, nesting)

- **Best practices**:
  - Always backup existing configs before changes
  - Test connectivity immediately after activation
  - Document changes immediately (prevent drift)
  - Use variables in scripts (reduce copy-paste errors)
