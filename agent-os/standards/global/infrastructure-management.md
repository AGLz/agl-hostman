## Infrastructure Management Standards

### Network Architecture
- **Multi-Network Stack**: All infrastructure uses triple-stack networking (LAN + WireGuard + Tailscale)
- **Connection Priority**: WireGuard (10.6.0.0/24) > LAN (192.168.0.0/24) > Tailscale (100.x.x.x)
- **Environment-Aware Routing**: Commands must detect current environment (WSL2/CT179/CT108) and use appropriate network stack
- **WireGuard Mesh**: Hub-and-spoke topology with FGSRV6 (10.6.0.5:51823) as central hub

### Container Standards
- **LXC Containers**: Primary deployment method for services on Proxmox
- **Docker in LXC**: Requires `features: keyctl=1,nesting=1` in container config
- **Resource Allocation**: Development containers get 48GB RAM minimum, service containers 8-16GB
- **Network Interfaces**: Containers can have multiple interfaces (eth0/eth1 for dual LAN, wg0 for WireGuard)

### Documentation Requirements
- **ALWAYS Read First**: `docs/INFRA.md` (infrastructure map) and `docs/ARCHON.md` (Archon integration) before any infrastructure task
- **Update Immediately**: Documentation must be updated immediately after infrastructure changes
- **Version Control**: All infrastructure changes must be documented with clear commit messages
- **Cross-Reference**: Documents must cross-reference related files (CLAUDE.md → INFRA.md → ARCHON.md)

### Storage Management
- **WireGuard-First**: All remote storage should use WireGuard mesh (10.6.0.0/24) for performance
- **NFS over WireGuard**: Primary method for shared storage (fgsrv6-wg, ct111-shares, ct111-sistema)
- **SSHFS Backup**: Use only when NFS not available (aglsrv6-bb, aglsrv6-usb4tb)
- **Mount Points**: Standardized at `/mnt/pve/{storage-name}-{protocol}`

### Service Deployment
- **MCP Servers**: Deploy MCP servers in dedicated containers (e.g., CT183 for Archon)
- **Multi-Access**: Services must be accessible via LAN, WireGuard, and Tailscale
- **Authentication**: Public services require Basic Auth or equivalent; VPN-only services can be unauthenticated
- **Port Standardization**: UI on 3xxx, API on 8xxx, MCP on 805x, nginx proxy on 8080

### Archon Integration
- **MCP Priority**: WireGuard endpoint (10.6.0.21:8051) is PRIMARY, Tailscale (100.80.30.59:8051) is BACKUP
- **Authentication**: Basic Auth (admin / ArchonPass2025) for public HTTPS and nginx:8080
- **No Auth**: MCP endpoints 8051/8052 on LAN/VPN trusted networks
- **Task Management**: Use Archon MCP tools for infrastructure project/task tracking

### Security Standards
- **Network Segmentation**: Public (HTTPS) → nginx proxy → internal services
- **VPN Encryption**: WireGuard and Tailscale provide transport encryption
- **Credentials Management**: Store in MCP memory or environment files, never in git
- **Firewall Rules**: LAN and VPN networks are trusted; public requires authentication

### Monitoring and Health Checks
- **Service Health**: All services must expose /health or equivalent endpoint
- **Connection Verification**: Test all network paths (LAN/WG/TS) after deployment
- **Performance Metrics**: Monitor WireGuard latency (target <30ms), NFS throughput (target >100MB/s)
- **Backup Verification**: Test backup/restore procedures for critical services

### Troubleshooting Standards
- **Document Root Cause**: All infrastructure issues must be documented with root cause analysis
- **Configuration Standards**: LXC containers: NO PresharedKey, AllowedIPs=10.6.0.0/24
- **Network Debugging**: Use tcpdump, wg show, ip route for diagnostics
- **Rollback Plan**: Always have rollback procedure before infrastructure changes
