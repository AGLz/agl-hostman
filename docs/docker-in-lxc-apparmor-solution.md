# Docker-in-LXC AppArmor Solution

> **Date**: 2025-10-27
> **Problem**: Docker BuildKit fails in LXC containers due to AppArmor enforcement
> **Solution**: Disable BuildKit and use legacy Docker builder

---

## 🔍 Problem Summary

### Error Symptoms

When building Docker images inside LXC containers using Docker BuildKit (default in Docker 23.0+), builds fail with:

```
runc run failed: unable to start container process: error during container init:
unable to apply apparmor profile: apparmor failed to apply profile:
write /proc/thread-self/attr/apparmor/exec: no such file or directory
```

### Root Cause

**Docker BuildKit Requirement**: BuildKit requires the ability to manage AppArmor profiles during container initialization, specifically writing to `/proc/thread-self/attr/apparmor/exec`.

**LXC Limitation**: LXC containers do not expose the `/proc/thread-self/attr/apparmor/exec` interface, even when:
- Container is privileged (`--unprivileged 0`)
- AppArmor profile is set to `unconfined`
- Container features include `keyctl=1,nesting=1,fuse=1`

**Why Legacy Builder Works**: The legacy Docker builder (pre-BuildKit) does not require AppArmor profile management during build steps, bypassing this limitation entirely.

---

## ✅ Solution

### Step 1: Disable BuildKit in Docker Daemon

Edit `/etc/docker/daemon.json` inside the LXC container:

```json
{
  "default-address-pools": [
    {"base": "172.17.0.0/16", "size": 24}
  ],
  "features": {
    "buildkit": false
  }
}
```

**Explanation**:
- `"buildkit": false` disables BuildKit globally for this Docker daemon
- Legacy builder will be used for all `docker build` and `docker-compose build` commands

### Step 2: Restart Docker Service

```bash
systemctl restart docker
```

### Step 3: Build with Legacy Builder

**Method A: Using docker-compose (BuildKit disabled globally)**
```bash
cd /root/Archon
docker-compose build
```

**Method B: Explicit BuildKit disable (environment variable)**
```bash
cd /root/Archon
DOCKER_BUILDKIT=0 docker-compose build
```

**Method C: Direct docker build**
```bash
DOCKER_BUILDKIT=0 docker build -t myimage:tag .
```

---

## 📋 Complete Configuration Reference

### LXC Container Configuration (`/etc/pve/lxc/183.conf`)

```ini
arch: amd64
cores: 8
features: keyctl=1,nesting=1,fuse=1
hostname: archon
memory: 16384
ostype: ubuntu
rootfs: local-zfs:subvol-183-disk-0,size=100G
swap: 8192

# Network configuration
net0: name=eth0,bridge=vmbr0,gw=192.168.0.1,hwaddr=BC:24:11:31:6D:34,ip=192.168.0.183/24,type=veth

# DO NOT add lxc.apparmor.profile: unconfined (conflicts with features)
```

**Critical Notes**:
- ✅ **DO** include `features: keyctl=1,nesting=1,fuse=1` (required for Docker)
- ❌ **DO NOT** add `lxc.apparmor.profile: unconfined` (conflicts with `features: fuse`)
- ✅ Container **MUST** be privileged (no `--unprivileged` flag)

### Docker Daemon Configuration (`/etc/docker/daemon.json`)

**Full configuration with BuildKit disabled**:

```json
{
  "default-address-pools": [
    {
      "base": "172.17.0.0/16",
      "size": 24
    }
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "features": {
    "buildkit": false
  }
}
```

---

## ⚠️ Failed Alternatives (Do Not Use)

### ❌ Attempt 1: AppArmor Unconfined in daemon.json

```json
{
  "security-opt": ["apparmor=unconfined"]
}
```

**Result**: BuildKit still attempts to write to `/proc/thread-self/attr/apparmor/exec`, fails with same error.

### ❌ Attempt 2: Adding lxc.apparmor.profile to LXC config

```ini
# In /etc/pve/lxc/183.conf
lxc.apparmor.profile: unconfined
```

**Result**: Container boot failure with error:
```
startup for container '183' failed
explicitly configured lxc.apparmor.profile overrides the following settings:
features:fuse, features:nesting
```

### ❌ Attempt 3: Building on Proxmox Host

**Security Risk**: Installing Docker on the Proxmox host creates a security vulnerability:
- Host compromises affect all VMs/containers
- Violates container isolation principles
- Increases attack surface

**Correct Approach**: Always build inside containers, never on the Proxmox host.

---

## 🔒 Security Considerations

### Why Docker Should NOT Be Installed on Proxmox Host

1. **Attack Surface**: Docker daemon runs with root privileges; compromise exposes entire hypervisor
2. **Container Escape**: Docker containers on host can potentially escape to host system
3. **Resource Conflicts**: Host Docker conflicts with VM/CT resource allocation
4. **Isolation Violation**: Breaks the security boundary between host and guests

### Why Legacy Builder Is Safe

- **No Security Downgrade**: Legacy builder has been production-tested for 10+ years
- **Same Isolation**: Containers built with legacy builder have identical security properties
- **BuildKit Features**: Modern features (cache mounts, secrets) are optional; most projects don't use them

---

## 📊 Performance Comparison

| Builder | Build Time | Cache Efficiency | AppArmor Compatibility |
|---------|------------|------------------|------------------------|
| **BuildKit** | Faster (parallel stages) | Advanced (build cache) | ❌ Fails in LXC |
| **Legacy** | Sequential stages | Basic (layer cache) | ✅ Works in LXC |

**Recommendation**: For LXC containers, use legacy builder. For native Docker hosts, use BuildKit.

---

## 🛠️ Troubleshooting

### Issue: Build still fails with AppArmor error

**Check BuildKit is disabled**:
```bash
docker info | grep -i buildkit
# Should NOT show "buildkit: true"
```

**Verify daemon.json**:
```bash
cat /etc/docker/daemon.json | jq '.features.buildkit'
# Should output: false
```

**Force legacy builder**:
```bash
export DOCKER_BUILDKIT=0
docker-compose build
```

### Issue: Container won't start after adding AppArmor config

**Symptom**: `pct start 183` fails with message about AppArmor profile overriding features

**Fix**: Remove `lxc.apparmor.profile` line from `/etc/pve/lxc/183.conf`
```bash
ssh root@192.168.0.245 "sed -i '/lxc.apparmor.profile/d' /etc/pve/lxc/183.conf"
pct start 183
```

### Issue: Docker daemon won't start

**Check logs**:
```bash
journalctl -u docker -n 50
```

**Validate daemon.json syntax**:
```bash
cat /etc/docker/daemon.json | jq empty
# No output = valid JSON
# Error = fix syntax
```

---

## 📝 Real-World Example: Archon Deployment (CT183)

### Context

- **Container**: CT183 (archon) on AGLSRV1 (192.168.0.183)
- **Project**: Archon AI Command Center (FastAPI + React + Supabase)
- **Dockerfile Stack**: Multi-stage builds with Python 3.12 and Node.js 20

### Initial Failure

```bash
cd /root/Archon
docker-compose build
```

**Error**:
```
=> ERROR [archon-server internal] load metadata for docker.io/library/python:3.12
runc run failed: unable to apply apparmor profile: write /proc/thread-self/attr/apparmor/exec: no such file or directory
```

### Applied Solution

1. **Modified `/etc/docker/daemon.json`**:
```bash
pct exec 183 -- bash -c 'cat > /etc/docker/daemon.json <<EOF
{
  "default-address-pools": [
    {"base": "172.17.0.0/16", "size": 24}
  ],
  "features": {
    "buildkit": false
  }
}
EOF'
```

2. **Restarted Docker**:
```bash
pct exec 183 -- systemctl restart docker
```

3. **Built with legacy builder**:
```bash
pct exec 183 -- bash -c 'cd /root/Archon && DOCKER_BUILDKIT=0 docker-compose build'
```

### Result

✅ **Build succeeded** without AppArmor errors
✅ **All three services** built successfully:
- `archon-server` (FastAPI backend)
- `archon-mcp` (MCP server)
- `archon-ui` (React frontend)

---

## 🔗 Related Documentation

- **Deployment Guide**: `docs/ct183-deployment-guide.md`
- **Deployment Status**: `docs/ct183-deployment-status.md`
- **Quick Start**: `docs/ct183-quickstart.md`
- **Archon Research**: `docs/archon-research/archon-comprehensive-analysis.md`
- **Infrastructure Map**: `CLAUDE.md` (v2.2.0+)

---

## 📚 References

### Official Documentation

- Docker BuildKit: https://docs.docker.com/build/buildkit/
- Docker Legacy Builder: https://docs.docker.com/build/building/
- AppArmor: https://www.kernel.org/doc/html/latest/admin-guide/LSM/apparmor.html
- Proxmox LXC: https://pve.proxmox.com/wiki/Linux_Container

### Community Issues

- Docker BuildKit AppArmor in LXC: https://github.com/moby/buildkit/issues/2402
- Proxmox Docker Nesting: https://forum.proxmox.com/threads/docker-in-lxc-containers.52209/

---

## ✅ Summary

**Problem**: Docker BuildKit requires AppArmor profile management unavailable in LXC containers
**Solution**: Disable BuildKit via `daemon.json` and use legacy Docker builder
**Security**: Never install Docker on Proxmox host; always build inside containers
**Performance**: Legacy builder is slightly slower but functionally equivalent

**Key Configuration**:
```json
{
  "features": {
    "buildkit": false
  }
}
```

**Build Command**:
```bash
DOCKER_BUILDKIT=0 docker-compose build
```

---

**Document Version**: 1.0
**Last Updated**: 2025-10-27
**Tested On**: Proxmox VE 8.x, LXC containers, Docker 28.2.2
