---
name: Infrastructure Management
description: Standards and best practices for managing AGL infrastructure including multi-network stacks (LAN/WireGuard/Tailscale), Proxmox LXC containers, Docker deployments, storage management, Archon MCP integration, and service deployment. Use this skill when working with infrastructure tasks, container configuration, network routing, WireGuard mesh setup, NFS/SSHFS storage mounts, Archon MCP tools, service deployment on Proxmox, or any infrastructure-related documentation. Essential for tasks involving CT containers, host connections, storage configuration, security policies, monitoring setup, or troubleshooting infrastructure issues. Apply when reading/writing infrastructure documentation (CLAUDE.md, INFRA.md, ARCHON.md), configuring WireGuard peers, setting up LXC containers with Docker support, managing multi-access services, or implementing environment-aware routing.
---

# Infrastructure Management

This Skill provides Claude Code with comprehensive guidance on managing the AGL infrastructure ecosystem including network architecture, container standards, documentation requirements, storage management, and Archon integration.

## When to use this skill:

- Working with Proxmox hosts (AGLSRV1, AGLSRV6, FGSRV6) and LXC containers
- Configuring WireGuard mesh network or Tailscale VPN connections
- Setting up Docker in LXC containers with proper features (keyctl=1, nesting=1)
- Managing NFS or SSHFS storage mounts over WireGuard mesh
- Deploying or configuring services with multi-network access (LAN + WireGuard + Tailscale)
- Implementing environment-aware connection routing (WSL2 vs CT179 vs CT108)
- Integrating with Archon MCP server for task management
- Writing or updating infrastructure documentation (INFRA.md, ARCHON.md, CLAUDE.md)
- Configuring authentication for public services (Basic Auth, VPN-only)
- Implementing monitoring, health checks, or service deployment
- Troubleshooting network connectivity or container issues
- Setting up security policies and firewall rules
- Allocating resources for development or service containers

## Instructions

For complete details on infrastructure management standards, best practices, and troubleshooting procedures, refer to:

[Infrastructure Management Standards](../../../agent-os/standards/global/infrastructure-management.md)

This standard covers:
- **Network Architecture**: Multi-stack networking, WireGuard mesh topology, connection priorities
- **Container Standards**: LXC configuration, Docker in LXC, resource allocation
- **Documentation Requirements**: Always read INFRA.md/ARCHON.md before infrastructure tasks
- **Storage Management**: WireGuard-first approach, NFS over WireGuard, mount points
- **Service Deployment**: MCP servers, multi-access patterns, port standardization
- **Archon Integration**: MCP priorities, authentication schemes, task management
- **Security Standards**: Network segmentation, VPN encryption, credentials management
- **Monitoring**: Health checks, connection verification, performance metrics
- **Troubleshooting**: Configuration standards, network debugging, rollback procedures
