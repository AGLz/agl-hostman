# Infrastructure Workflows

**Agent OS Specifications for AGL Infrastructure Management**

This directory contains comprehensive, repeatable workflows for common infrastructure operations in the AGL environment.

## Available Workflows

### Network Configuration
- **[WireGuard Peer Setup](./wireguard-peer-setup.md)** - Add new peers to WireGuard mesh with proper hub registration
  - Configuration templates for LXC vs Proxmox hosts
  - Common pitfalls and troubleshooting
  - Verification procedures

### Storage Management
- **[NFS Storage Mount](./nfs-storage-mount.md)** - Mount NFS shares over WireGuard mesh
  - Performance benchmarking
  - Proxmox storage integration
  - NFS vs SSHFS comparison

### Container Management
- **[LXC Container Deployment](./container-deployment.md)** - Deploy containers with Docker support
  - Multi-network configuration (LAN/WireGuard/Tailscale)
  - Resource allocation guidelines
  - GPU passthrough setup

### Service Integration
- **[Archon MCP Integration](./archon-integration.md)** - Connect Archon AI Command Center to Claude Code
  - Multiple endpoint configuration
  - MCP tools reference
  - Task management workflows

## Usage with Agent OS

These specifications are designed to work with Agent OS commands in Claude Code:

### Read a Specification
```
Read the WireGuard peer setup workflow
```

### Create Tasks from Spec
```
/create-tasks

Use the specification in agent-os/specs/infrastructure/wireguard-peer-setup.md
to create a task list for setting up a new WireGuard peer.
```

### Implement a Workflow
```
/implement-tasks

Implement the tasks for WireGuard peer setup on CT184 with IP 10.6.0.22
```

## Workflow Structure

Each workflow follows a consistent structure:

1. **Overview** - Brief description and estimated time
2. **Prerequisites** - Requirements checklist
3. **Specification** - Step-by-step instructions
4. **Troubleshooting** - Common issues and fixes
5. **Success Criteria** - Verification checklist
6. **Related Workflows** - Cross-references to related specs

## Environment-Aware Workflows

All workflows include environment-specific instructions for:

- **WSL2 (AGLHQ11)** - Tailscale-only access
- **CT179 (agldv03)** - Full network stack (LAN/WireGuard/Tailscale)
- **CT108 (agldv06)** - Tailscale-only access

## Integration with Standards

These workflows implement the standards defined in:
- `agent-os/standards/global/infrastructure-management.md`

And complement the documentation in:
- `docs/INFRA.md` - Infrastructure map
- `docs/ARCHON.md` - Archon integration guide
- `CLAUDE.md` - Claude Code configuration

## Adding New Workflows

To add a new infrastructure workflow:

1. Create a new `.md` file in this directory
2. Follow the established structure (see existing workflows)
3. Include environment-specific instructions
4. Add troubleshooting section
5. Cross-reference related workflows
6. Update this README with the new workflow

## Quick Reference

| Task | Workflow | Time |
|------|----------|------|
| Add WireGuard peer | [wireguard-peer-setup.md](./wireguard-peer-setup.md) | 15-20 min |
| Mount NFS storage | [nfs-storage-mount.md](./nfs-storage-mount.md) | 10-15 min |
| Deploy LXC container | [container-deployment.md](./container-deployment.md) | 20-30 min |
| Connect Archon MCP | [archon-integration.md](./archon-integration.md) | 15-20 min |

## Best Practices

✅ **Always read prerequisites** before starting a workflow
✅ **Test in development environment first** (CT179) when possible
✅ **Update documentation** after completing infrastructure changes
✅ **Commit changes to git** with clear messages
✅ **Verify success criteria** before marking tasks complete
✅ **Use environment detection** to select appropriate network paths

## Support

For questions or improvements to these workflows:
- Reference the infrastructure-management Skill in Claude Code
- Consult `docs/INFRA.md` for infrastructure details
- Use Archon MCP for task tracking and knowledge base search
