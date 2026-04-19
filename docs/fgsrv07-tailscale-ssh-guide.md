# Tailscale SSH Setup Guide - FGSRV07

**Host**: FGSRV07
**IP**: 191.252.93.227
**OS**: Debian 13 (Trixie)
**Feature**: Tailscale SSH with `--ssh` flag
**Created**: 2026-02-11

---

## What is Tailscale SSH?

Tailscale SSH replaces traditional SSH key authentication with Tailscale's identity system. This provides:

- **No SSH keys to manage** - Uses your Tailscale identity
- **Centralized access control** - Manage access via Tailscale ACLs
- **Automatic authentication** - No need to distribute keys
- **Ephemeral certificates** - Short-lived SSH certificates instead of static keys
- **Audit trail** - All SSH access logged in Tailscale admin console

---

## Quick Setup

### 1. Run the Setup Script

```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman
./scripts/setup-fgsrv7-tailscale-ssh.sh
```

### 2. Enable Tailscale SSH in Admin Console

1. Go to: https://login.tailscale.com/admin/machines
2. Find FGSRV07 in your devices list
3. Click "Edit" on FGSRV07
4. Enable "Tailscale SSH"
5. Configure ACLs for SSH access (see below)

### 3. Update SSH Config with Tailscale IP

After Tailscale is connected, get the Tailscale IP:
```bash
# From FGSRV07
tailscale ip -4
```

Then update `/root/.ssh/config`:
```ssh-config
Host fgsrv7
  HostName 100.x.x.x  # Replace with actual Tailscale IP
  User root
  StrictHostKeyChecking no
```

---

## ACL Configuration for SSH

In Tailscale Admin Console (ACLs), add SSH access:

```json
{
  "acls": [
    {
      "action": "accept",
      "src": ["tag:admin"],
      "dst": ["autogroup:internet:443", "autogroup:internet:22", "tag:fgsrv:*"]
    }
  ],
  "tagOwners": {
    "tag:fgsrv": ["your-email@example.com"],
    "tag:admin": ["your-email@example.com"]
  },
  "ssh": [
    {
      "action": "accept",
      "src": ["tag:admin"],
      "dst": ["tag:fgsrv"],
      "users": ["root", "ubuntu"]
    }
  ]
}
```

---

## Connection Methods

### Method 1: Tailscale SSH (Recommended)

After enabling in admin console:

```bash
# Direct SSH via Tailscale (no key needed)
ssh root@fgsrv7

# Or use Tailscale hostname
ssh root@fgsrv7.your-tailnet.ts.net
```

### Method 2: Traditional SSH (Fallback)

```bash
# Using SSH key
ssh -i ~/.ssh/fg_srv.pem root@191.252.93.227

# Using SSH alias
ssh FGSRV07
```

---

## Verification

### Check Tailscale SSH Status

```bash
# From FGSRV07
tailscale status

# Check if SSH is enabled
tailscale status --json | grep -i "ssh"

# Check peers
tailscale status --peers
```

### Test Connection

```bash
# Test Tailscale connectivity
tailscale ping fgsrv6

# Test SSH connection
ssh root@fgsrv7 "echo 'Connection successful'"

# Verify user
ssh root@fgsrv7 "whoami && hostname"
```

---

## Troubleshooting

### Issue: "Permission denied" with Tailscale SSH

**Cause**: Tailscale SSH not enabled in ACLs

**Solution**:
```bash
# Check ACL status
tailscale status --json | jq '.SSHS'

# Verify in admin console:
# 1. ACLs include SSH section
# 2. Your user tag has access to destination tag
# 3. SSH users include the target user (root)
```

### Issue: Cannot connect via Tailscale IP

**Cause**: Tailscale not connected or IP not updated

**Solution**:
```bash
# Check Tailscale status
tailscale status

# Restart if needed
systemctl restart tailscaled

# Get current IP
tailscale ip -4

# Update SSH config with correct IP
```

### Issue: Falls back to key-based SSH

**Cause**: SSH client not using Tailscale SSH

**Solution**:
```bash
# Force Tailscale SSH
ssh -o IdentitiesOnly=no root@fgsrv7

# Or temporarily disable keys
ssh -o IdentityFile=/dev/null root@fgsrv7
```

---

## Security Considerations

### Tailscale SSH Benefits

| Feature | Traditional SSH | Tailscale SSH |
|----------|-----------------|----------------|
| Key Distribution | Manual (copy to each host) | Automatic via Tailscale |
| Access Revocation | Manual (remove from authorized_keys) | Instant (remove from ACL) |
| Key Rotation | Manual | Automatic (ephemeral certs) |
| Audit Trail | Local auth logs only | Centralized in Tailscale |
| Multi-factor | Requires additional setup | Built-in with Tailscale |

### Best Practices

1. **Enable Tailscale SSH alongside traditional** - Keep key-based as backup
2. **Use ACL tags for access control** - Tag hosts by role (tag:fgsrv, tag:prod)
3. **Regular ACL audits** - Review who has access to what
4. **Monitor SSH logs** - Check Tailscale admin console for access history
5. **Test key fallback** - Ensure traditional SSH still works for emergency access

---

## Firewall Configuration

### Required Ports for Tailscale SSH

```bash
# UFW rules
ufw allow 22/tcp      # Traditional SSH (fallback)
ufw allow 41641/udp   # Tailscale WireGuard
ufw allow from 100.64.0.0/10  # Tailscale network
```

### Tailscale SSH Uses Port 22

When Tailscale SSH is enabled, it still uses port 22 but:
- Bypasses `~/.ssh/authorized_keys`
- Uses Tailscale-issued certificates
- Validates against Tailscale ACLs

---

## Integration with Existing Infrastructure

### Access from Other FGSRV Hosts

```bash
# From fgsrv3, fgsrv4, fgsrv5, fgsrv6
ssh root@fgsrv7

# Should work without SSH keys if:
# 1. Source host has Tailscale SSH enabled
# 2. ACL allows tag:fgsrv to tag:fgsrv communication
```

### NFS Access via Tailscale

```bash
# Mount NFS from FGSRV06 via Tailscale
mount -t nfs 100.83.51.9:/ /mnt/fgsrv6-nfs

# Better performance through Tailscale vs public internet
# Uses 100.x.x.x network (low latency)
```

---

## Maintenance

### Update Tailscale with SSH

```bash
# Check version
tailscale version

# Update
apt update && apt install --only-upgrade tailscale

# Restart with SSH enabled
systemctl restart tailscaled
tailscale up --ssh
```

### Re-authentication

```bash
# If authentication lost
tailscale down
tailscale up --ssh

# Or reset and re-auth
rm /var/lib/tailscale/tailscaled.state
systemctl restart tailscaled
tailscale up --ssh
```

---

## Quick Reference Card

```bash
# Status commands
tailscale status                # Overall status
tailscale status --peers        # List peers
tailscale ip -4                # Get Tailscale IP

# Connection test
tailscale ping <hostname>       # Test connectivity
tailscale netcheck              # Network diagnostics

# SSH test
ssh root@fgsrv7 "hostname"    # Test SSH via Tailscale

# Service management
systemctl status tailscaled     # Check service
systemctl restart tailscaled    # Restart service

# Admin console
https://login.tailscale.com/admin/machines
https://login.tailscale.com/admin/acls
```

---

**Document Version**: 1.0
**Last Updated**: 2026-02-11
**Related Docs**:
- `docs/fgsrv07-host-overview.md` - Host information
- `docs/fgsrv07-tailscale-installation.md` - Installation guide
- `docs/SSH-CONFIG.md` - SSH configuration reference
