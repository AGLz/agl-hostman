# Discovered Network Switches - Quick Reference

**Last Updated:** 2025-11-12 22:54:00
**Environment:** CT179 (agldv03) on AGLSRV1

## Primary Candidate - NEEDS MANUAL VERIFICATION

### 192.168.0.1 - Gateway Device
- **Status:** 🟡 Medium Confidence (3/6)
- **MAC:** 02:10:18:57:ae:73 (Locally Administered)
- **Open Ports:** 80 (HTTP), 443 (HTTPS)
- **Web UI:** http://192.168.0.1 or https://192.168.0.1
- **SSH:** Port 22 timeout (not accessible)
- **Next Step:** Manual browser verification required

**How to Verify:**
```bash
# 1. Check web interface in browser
firefox http://192.168.0.1

# 2. Look for OMAY branding/login page
# 3. Try default credentials: admin/admin, admin/password

# 4. Re-run verification with verbose mode
VERBOSE=true ./verify-omay-switch.sh 192.168.0.1
```

---

## Verified Non-OMAY Device

### 192.168.0.254 - TP-Link Router/Switch ✅
- **Status:** ✅ Verified (NOT OMAY)
- **MAC:** 00:31:92:dc:3e:f8
- **Vendor:** TP-Link Systems Inc
- **Model:** BusyBox-based embedded device
- **Open Ports:** 22 (Dropbear SSH), 80 (HTTP), 443 (HTTPS)
- **Confidence:** 3/6 (confirmed via MAC OUI)

---

## Additional Candidates - Pending Verification

The following devices have full web management interfaces (HTTP+HTTPS) and should be checked:

| IP Address | MAC Address | Hostname | Priority |
|------------|-------------|----------|----------|
| 192.168.0.131 | TBD | - | Medium |
| 192.168.0.132 | TBD | - | Medium |
| 192.168.0.133 | TBD | - | Medium |
| 192.168.0.137 | TBD | - | Medium |
| 192.168.0.139 | TBD | - | Medium |
| 192.168.0.161 | TBD | - | Medium |
| 192.168.0.162 | bc:24:11:de:51:b0 | - | Medium |
| 192.168.0.174 | TBD | agldv02.lan | Low (container host) |
| 192.168.0.178 | TBD | - | Medium |
| 192.168.0.180 | TBD | - | Low (Dokploy) |
| 192.168.0.181 | TBD | - | Medium |

**Batch Verification:**
```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman/scripts/network-discovery
./batch-verify.sh
```

---

## Excluded Devices (Known Infrastructure)

- **192.168.0.102** - Pi-hole DNS server
- **192.168.0.245** - AGLSRV1 Proxmox host
- **192.168.0.103-202** - LXC containers (SSH only)

---

## Quick Commands

```bash
# Navigate to tools directory
cd /mnt/overpower/apps/dev/agl/agl-hostman/scripts/network-discovery

# Fast scan for new devices
./quick-switch-scan.sh

# Verify specific device
./verify-omay-switch.sh <IP_ADDRESS>

# Batch verify all candidates
./batch-verify.sh

# Check MAC vendor
./mac-lookup.sh <MAC_ADDRESS>
```

---

## OMAY Identification Checklist

When manually verifying via web browser, look for:

- ✅ "OMAY" branding on login page
- ✅ "Managed Switch" or model number in page title
- ✅ Switch-specific management UI (VLAN, ports, trunking)
- ✅ Physical device labels with "OMAY" manufacturer name
- ✅ MAC address matching known OMAY OUI prefix

**Default Credentials to Try:**
- admin / admin
- admin / password
- admin / (blank)
- root / admin

---

## Documentation

- **Full Report:** `/mnt/overpower/apps/dev/agl/agl-hostman/docs/NETWORK-DISCOVERY-RESULTS.md`
- **Tool Guide:** `/mnt/overpower/apps/dev/agl/agl-hostman/scripts/network-discovery/README.md`
- **Infrastructure:** `/mnt/overpower/apps/dev/agl/agl-hostman/docs/INFRA.md`
