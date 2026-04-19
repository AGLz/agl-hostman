---
name: Infrastructure Management
description: Manage and configure AGL infrastructure including multi-network stacks (LAN/WireGuard/Tailscale), Proxmox hosts, LXC containers, Docker deployments, storage systems, and Archon MCP integration. Use this skill when deploying or configuring services on Proxmox hosts (AGLSRV1, AGLSRV6, FGSRV6), setting up LXC containers with Docker support (keyctl=1, nesting=1 features), configuring WireGuard mesh network or Tailscale VPN connections, mounting NFS or SSHFS storage over WireGuard, implementing environment-aware connection routing (WSL2 vs CT179 vs CT108), integrating with Archon MCP server for task management, writing or updating infrastructure documentation files (INFRA.md, ARCHON.md, CLAUDE.md), configuring multi-network access patterns for services (LAN + WireGuard + Tailscale), setting up authentication for public services (Basic Auth, VPN-only), implementing monitoring and health checks, troubleshooting network connectivity or container issues, allocating resources for development or service containers, managing WireGuard hub-and-spoke topology, configuring nginx proxy for public service access, setting up port standardization (UI on 3xxx, API on 8xxx, MCP on 805x), or implementing security policies and firewall rules. Apply when working with container configuration files, WireGuard peer configurations, NFS mount definitions, service deployment scripts, network routing tables, or any infrastructure-related tasks requiring knowledge of the AGL multi-network architecture.
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
