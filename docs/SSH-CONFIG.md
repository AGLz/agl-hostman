# SSH Configuration - AGL Infrastructure

> **Last Updated**: 2025-11-08 | **Version**: 1.0.0

## 📍 SSH Config Location

**Primary Config**: `/root/.ssh/config` (CT179/agldv03)
**Keys Directory**: `/root/.ssh/`

---

## 🔑 Available SSH Keys

### Active Keys (Private)

| Key File | Type | Size | Date | Usage |
|----------|------|------|------|-------|
| `id_rsa` | RSA | 3.4k | 2024-05-17 | Primary key - Default for most hosts |
| `id_rsa_man6d` | RSA | 2.6k | 2024-11-08 | Secondary key |
| `FGSRV03.pem` | PEM | - | - | FGSRV03 only |
| `fg_srv.pem` | PEM | - | - | FGSRV04, FGSRV05, FGSRV06, AGLWK07 |
| `AGLWK06.pem` | PEM | - | - | AGLSRV2 |
| `engine.pem` | PEM | - | - | YAPMan (deploy0.yapoli.io) |
| `AGLLX51.pem` | PEM | - | - | AGLLX51 (AWS) |
| `AGLMC01.pem` | PEM | - | - | VS-aping (Visual Studio) |

### Public Keys

| Key File | Size | Date | Notes |
|----------|------|------|-------|
| `id_rsa.pub` | 768 | 2024-05-17 | Primary public key |
| `id_rsa_man6d.pub` | 568 | 2024-11-08 | Secondary public key |
| `fg_srv.pub` | 731 | 2020-07-24 | FGSRV hosts |
| `github_rsa.pub` | 396 | 2015-09-03 | GitHub access |
| `github_ssh.pub` | 404 | 2018-11-28 | GitHub SSH |
| `BitBucket.pub` | 814 | 2015-11-16 | BitBucket access |
| `codecommit_rsa.pub` | 396 | 2017-06-27 | AWS CodeCommit |

---

## 🌐 SSH Host Configurations

### FGSRV Hosts (VPS Locaweb)

> **Naming Convention**: All FGSRV hosts use two aliases for the same physical server:
> - **`FGSRVXX`** (uppercase) → Public IP / hostname
> - **`fgsrvX`** (lowercase) → Tailscale IP (same server, different route)

#### FGSRV03 - Production Server
> **Note**: `fgsrv3` is an alias for `FGSRV03` (same physical server, different access routes)

```ssh-config
Host FGSRV03
  HostName 191.252.201.205
  User root
  IdentityFile ~/.ssh/FGSRV03.pem

Host fgsrv3
  HostName 100.67.99.115  # Tailscale IP
  User root
  StrictHostKeyChecking no
```

**Connection Priority**:
1. `ssh fgsrv3` - Tailscale (✅ working, recommended)
2. `ssh FGSRV03` - Public IP (fallback)

#### FGSRV04 - Production Server
> **Note**: `fgsrv4` is an alias for `FGSRV04` (same physical server, different access routes)

```ssh-config
Host FGSRV04
  HostName vps22826.publiccloud.com.br
  User sysadmin
  IdentityFile ~/.ssh/fg_srv.pem

Host fgsrv4
  HostName 100.111.79.2  # Tailscale IP
  User root
  StrictHostKeyChecking no
```

**Connection Priority**:
1. `ssh fgsrv4` - Tailscale (✅ working, recommended)
2. `ssh FGSRV04` - Public hostname (fallback)

#### FGSRV05 - Production Server
> **Note**: `fgsrv5` is an alias for `FGSRV05` (same physical server, different access routes)

```ssh-config
Host FGSRV05
  HostName 191.252.200.20
  User root
  IdentityFile ~/.ssh/fg_srv.pem

Host fgsrv5
  HostName 100.71.107.26  # Tailscale IP
  User root
  StrictHostKeyChecking no
```

**Physical Server**: vps24136.publiccloud.com.br

**Connection Priority** (as of 2025-11-08):
1. `ssh FGSRV05` - Public IP (✅ **RECOMMENDED** - currently working)
2. `ssh fgsrv5` - Tailscale (❌ timing out - needs troubleshooting)

**Known Issues**:
- ⚠️ Tailscale alias `fgsrv5` (100.71.107.26) timing out as of 2025-11-08
- ⚠️ WireGuard route (10.6.0.11) also timing out
- ✅ Public IP alias `FGSRV05` (191.252.200.20) working correctly
- 💡 Both aliases point to the **same physical server** - only the network route differs

#### FGSRV06 - Production Server
> **Note**: `fgsrv6` is an alias for `FGSRV06` (same physical server, different access routes)

```ssh-config
Host FGSRV06
  HostName 186.202.57.120
  User root
  IdentityFile ~/.ssh/fg_srv.pem

Host fgsrv6
  HostName 100.83.51.9  # Tailscale IP
  User root
  StrictHostKeyChecking no
```

**Connection Priority**:
1. `ssh fgsrv6` - Tailscale (✅ working, recommended)
2. `ssh FGSRV06` - Public IP (fallback)

---

### AGLSRV Hosts (Proxmox)

#### AGLSRV1 - Main Proxmox Host
```ssh-config
Host AGLSRV1
  HostName 192.168.0.245
  User root
  Port 22
  IdentityFile ~/.ssh/id_rsa

Host aglsrv1 (Tailscale - resolves to hostname)
  # Uses default SSH resolution
```

**Connection Options**:
1. `ssh AGLSRV1` - LAN IP (fastest from CT179)
2. `ssh root@192.168.0.245` - Direct LAN IP
3. `ssh root@100.107.113.33` - Tailscale IP
4. `ssh root@10.6.0.19` - WireGuard IP

#### AGLSRV5 - Secondary Proxmox Host
```ssh-config
Host aglsrv5 (Tailscale)
  HostName 100.119.223.113
  User root
  StrictHostKeyChecking no
```

**Connection Options**:
1. `ssh aglsrv5` - Tailscale (recommended, working)
2. `ssh root@192.168.15.222` - LAN IP (local network only)
3. `ssh root@10.6.0.17` - WireGuard IP

---

### Development & Work Hosts

#### AGLDEV01
```ssh-config
Host AGLDEV01
  HostName 192.168.0.147
  User root
  IdentityFile ~/.ssh/id_rsa
```

#### AGLDEV02
```ssh-config
Host AGLDEV02
  HostName 192.168.0.174
  User root
  IdentityFile ~/.ssh/id_rsa
```

#### AGLWK06
```ssh-config
Host AGLWK06
  HostName f.aguileraz.net
  User root
  Port 6022
  IdentityFile ~/.ssh/id_rsa
```

#### AGLWK07
```ssh-config
Host AGLWK07
  HostName man.aguileraz.net
  User fg
  Port 8122
  IdentityFile ~/.ssh/fg_srv.pem
```

---

### External & Cloud Hosts

#### YAPMan (AWS São Paulo)
```ssh-config
Host YAPMan
  HostName deploy0.yapoli.io
  User ubuntu
  IdentityFile ~/.ssh/engine.pem
  IdentitiesOnly yes
  UserKnownHostsFile=/dev/null
  StrictHostKeyChecking no
  LogLevel=info
  RequestTTY force
```

#### AGLLX51 (AWS US-East-1)
```ssh-config
Host AGLLX51
  HostName ec2-54-81-231-106.compute-1.amazonaws.com
  User root
  IdentityFile ~/.ssh/AGLLX51.pem
  UserKnownHostsFile=/dev/null
  StrictHostKeyChecking no
  LogLevel=info
  RequestTTY force
```

---

## 🔧 SSH Connection Best Practices

### Connection Priority Matrix

**From CT179 (agldv03)**:

| Target | Priority 1 | Priority 2 | Notes |
|--------|-----------|-----------|-------|
| FGSRV03 | `ssh fgsrv3` (Tailscale) | `ssh FGSRV03` (Public IP) | ✅ Tailscale working |
| FGSRV04 | `ssh fgsrv4` (Tailscale) | `ssh FGSRV04` (Public) | ✅ Tailscale working |
| FGSRV05 | `ssh FGSRV05` (Public IP) | `ssh fgsrv5` (Tailscale) | ⚠️ Use public IP (Tailscale down) |
| FGSRV06 | `ssh fgsrv6` (Tailscale) | `ssh FGSRV06` (Public) | ✅ Tailscale working |
| AGLSRV1 | `ssh AGLSRV1` (LAN) | `ssh root@10.6.0.19` (WG) | ⚡ LAN fastest from CT179 |
| AGLSRV5 | `ssh aglsrv5` (Tailscale) | `ssh root@10.6.0.17` (WG) | ✅ Tailscale working |

### Quick Commands by Purpose

**Check Proxmox containers** (AGLSRV1):
```bash
ssh AGLSRV1 "pct list"
```

**Access MySQL container** (CT131):
```bash
ssh AGLSRV1 "pct enter 131"
# or execute command:
ssh AGLSRV1 "pct exec 131 -- mysql -e 'SHOW DATABASES'"
```

**Check FGSRV cron jobs**:
```bash
ssh fgsrv3 "crontab -l"
ssh fgsrv4 "crontab -l"
ssh FGSRV05 "crontab -l"  # Use FGSRV05 (public IP) - fgsrv5 (Tailscale) currently down
ssh fgsrv6 "crontab -l"
```

---

## 🛡️ Security Notes

### Key Management

1. **Primary Key** (`id_rsa`):
   - Used for most internal hosts (AGLSRV, AGLDEV)
   - Default fallback for hosts without specific key

2. **FGSRV Key** (`fg_srv.pem`):
   - Shared across FGSRV04, FGSRV05, FGSRV06, AGLWK07
   - ⚠️ Should be rotated if compromised

3. **Dedicated Keys**:
   - `FGSRV03.pem` - FGSRV03 only
   - `AGLWK06.pem` - AGLSRV2 only
   - `engine.pem` - YAPMan (AWS) only
   - `AGLLX51.pem` - AGLLX51 (AWS) only

### StrictHostKeyChecking

**Disabled** for:
- Tailscale hosts (`fgsrv3`, `fgsrv4`, `fgsrv5`, `aglsrv5`)
- Cloud hosts (YAPMan, AGLLX51, AGLSRV1-aping)

**Enabled** (default) for:
- All production FGSRV hosts with public IPs
- Internal LAN hosts (AGLSRV1, AGLSRV2, AGLDEV)

---

## 📝 Adding New Hosts to SSH Config

### Template for New Host

```ssh-config
Host <hostname-alias>
  HostName <ip-or-domain>
  User <username>
  Port <port-number>  # Optional, default 22
  IdentityFile ~/.ssh/<key-file>
  StrictHostKeyChecking <yes|no>
  UserKnownHostsFile=/dev/null  # Optional for testing
```

### Example - Adding FGSRV6 Tailscale Alias

```bash
cat >> ~/.ssh/config << 'EOF'
Host fgsrv6
    HostName 100.83.51.9
    User root
    StrictHostKeyChecking no
EOF
```

---

## 🔍 Troubleshooting SSH Connections

### Test Effective Configuration

```bash
# Show all effective settings for a host
ssh -G FGSRV05

# Test connection with verbose output
ssh -v fgsrv5

# Test connection with specific key
ssh -i ~/.ssh/fg_srv.pem root@191.252.200.20
```

### Common Issues

**1. "Permission denied (publickey)"**
```bash
# Check key permissions (must be 600)
chmod 600 ~/.ssh/id_rsa
chmod 600 ~/.ssh/fg_srv.pem

# Check config permissions (must be 600)
chmod 600 ~/.ssh/config
```

**2. "Connection timed out"**
```bash
# Test network connectivity
ping -c 3 100.71.107.26  # Tailscale IP
ping -c 3 191.252.200.20  # Public IP

# Check Tailscale status
tailscale status | grep fgsrv5

# Check WireGuard status
sudo wg show
```

**3. "Host key verification failed"**
```bash
# Remove old host key
ssh-keygen -R <hostname-or-ip>

# Or use StrictHostKeyChecking=no (less secure)
ssh -o StrictHostKeyChecking=no root@<host>
```

---

## 📊 SSH Config Summary

**Total Configured Hosts**: 21 SSH aliases → **13 physical servers**
**Total SSH Keys**: 12 (10 public + 2 active private)

**Alias Convention**:
- **FGSRV hosts**: Each physical server has 2 aliases (uppercase=public, lowercase=Tailscale)
  - FGSRV03 + fgsrv3 = 1 server
  - FGSRV04 + fgsrv4 = 1 server
  - FGSRV05 + fgsrv5 = 1 server
  - FGSRV06 + fgsrv6 = 1 server

**Network Access**:
- LAN: 5 hosts (AGLSRV1, AGLSRV2, AGLDEV, FGDEV, FGSRV local)
- Tailscale: 8 aliases (fgsrv3, fgsrv4, fgsrv5, fgsrv6, aglsrv1, aglsrv5)
- Public Internet: 7 hosts (FGSRV03-06 public IPs, YAPMan, AGLLX51, AGLWK06/07)
- AWS: 2 hosts (YAPMan, AGLLX51)

---

## 🔄 Recent Changes

**2025-11-08 22:30**:
- **Clarified alias convention**: All FGSRV hosts use dual aliases (uppercase=public, lowercase=Tailscale)
- Updated all FGSRV sections with "Note: fgsrvX is alias for FGSRVXX"
- Corrected SSH Config Summary: 21 aliases → 13 physical servers
- Updated Connection Priority Matrix to reflect same-server aliases
- Added naming convention documentation at FGSRV section header

**2025-11-08 19:00**:
- Identified FGSRV05 Tailscale connectivity issue (`fgsrv5` alias timeout on 100.71.107.26)
- Documented all SSH keys and their usage
- Created connection priority matrix
- Added troubleshooting section
- Verified working connections: FGSRV05 (public IP), fgsrv3, fgsrv4, fgsrv6, aglsrv5

---

**See Also**:
- `docs/INFRA.md` - Complete infrastructure map
- `docs/QUICK-START.md` - Quick connection commands
- `/root/.ssh/config` - Primary SSH configuration file
