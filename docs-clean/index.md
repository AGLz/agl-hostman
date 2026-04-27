# AGL Hostman Documentation

Welcome to AGL Hostman - the comprehensive multi-host storage management system.

## 🚀 Quick Start

AGL Hostman is a centralized management platform for Proxmox hosts, providing seamless storage access via NFS, iSCSI, and PBS across a secure Tailscale VPN network.

### Key Features

- **Multi-Host Storage Management**: Consolidated storage access across 4+ Proxmox hosts
- **Secure VPN Network**: Powered by Tailscale for encrypted, mesh networking
- **Multiple Storage Protocols**: NFS, iSCSI, and Proxmox Backup Server (PBS)
- **Real-time Monitoring**: Comprehensive observability stack with Prometheus, Grafana, and Loki
- **Automated Backups**: Robust backup strategy with offsite replication
- **High Availability**: Redundant architecture with automatic failover

### Architecture Overview

```
                   ┌─────────────────┐
                   │    AGLSRV1      │
                   │  Storage Server │
                   │  (100.x.x.x)    │
                   └────────┬────────┘
                            │
              Tailscale Mesh VPN
                            │
       ┌────────────┬───────┴───────┬────────────┐
       │            │               │            │
  ┌────▼───┐  ┌────▼───┐     ┌─────▼────┐ ┌────▼───┐
  │AGLSRV6 │  │AGLSRV6b│     │ FGSRV5   │ │FGSRV6  │
  │100.98. │  │100.98. │     │  100.71.  │ │100.83. │
  │108.66  │  │119.51  │     │  107.26   │ │51.9    │
  │+PBS    │  │+PBS    │     │           │ │        │
  └────────┘  └────────┘     └──────────┘ └────────┘
```

## 📚 Documentation Navigation

### Getting Started
- [Installation Guide](getting-started/installation.md) - Step-by-step installation
- [Configuration](getting-started/configuration.md) - System configuration
- [Initial Setup](getting-started/initial-setup.md) - Post-installation setup

### Architecture
- [Architecture Overview](architecture/overview.md) - System architecture
- [Storage Protocols](architecture/storage-protocols.md) - NFS, iSCSI, PBS details
- [Network Topology](architecture/network-topology.md) - Tailscale VPN setup
- [Security Architecture](architecture/security.md) - Security implementation
- [High Availability](architecture/ha.md) - HA and failover

### Storage Management
- [NFS Configuration](storage/nfs.md) - NFS mount configuration
- [iSCSI Configuration](storage/iscsi.md) - iSCSI setup and management
- [PBS Integration](storage/pbs.md) - Proxmox Backup Server integration
- [Performance Optimization](storage/performance.md) - Storage performance tuning

### Monitoring & Observability
- [Monitoring Stack](monitoring/stack.md) - Prometheus, Grafana, Loki setup
- [Metrics Collection](monitoring/metrics.md) - Performance metrics
- [Alerting](monitoring/alerting.md) - Alert configuration and management
- [Logging](monitoring/logging.md) - Log aggregation and analysis
- [Distributed Tracing](monitoring/tracing.md) - Jaeger tracing setup

### Backup & Recovery
- [Backup Strategy](backup/strategy.md) - Overall backup strategy
- [Configuration](backup/configuration.md) - Backup configuration
- [Disaster Recovery](backup/disaster-recovery.md) - DR procedures
- [Testing & Validation](backup/testing.md) - Backup testing

### API Reference
- [API Overview](api/overview.md) - API documentation
- [REST API](api/rest.md) - REST API endpoints
- [Authentication](api/authentication.md) - Auth methods
- [Error Handling](api/errors.md) - Error codes and handling

### Infrastructure
- [Terraform Modules](infrastructure/terraform.md) - Infrastructure as Code
- [Ansible Playbooks](infrastructure/ansible.md) - Configuration management
- [Docker Configuration](infrastructure/docker.md) - Docker setup
- [CI/CD Pipeline](infrastructure/ci-cd.md) - Continuous integration/Deployment

### Development
- [Development Environment](development/environment.md) - Setup dev environment
- [Code Standards](development/code-standards.md) - Coding guidelines
- [Testing](development/testing.md) - Testing strategies
- [Contributing](development/contributing.md) - Contribution guidelines

### Troubleshooting
- [Common Issues](troubleshooting/common.md) - Frequently encountered issues
- [Performance Issues](troubleshooting/performance.md) - Performance troubleshooting
- [Connectivity Issues](troubleshooting/connectivity.md) - Network connectivity issues
- [Backup Issues](troubleshooting/backup.md) - Backup troubleshooting

## 🎯 Quick Links

### Performance Metrics
[![Performance Dashboard](https://img.shields.io/badge/Performance-Dashboard-blue.svg)](monitoring/metrics.md)

### API Documentation
[![API Reference](https://img.shields.io/badge/API-Reference-green.svg)](api/overview.md)

### Architecture Diagrams
[![Architecture](https://img.shields.io/badge/Architecture-purple.svg)](architecture/overview.md)

## 📊 System Status

| Component | Status | Last Updated |
|-----------|--------|-------------|
| Storage Services | ✅ Active | 2025-10-14 |
| VPN Network | ✅ Healthy | 2025-10-14 |
| Monitoring Stack | ✅ Running | 2025-10-14 |
| Backup System | ✅ Operational | 2025-10-14 |
| API Services | ✅ Available | 2025-10-14 |

## 🔗 Quick Reference

### Command Line Interface

```bash
# View system status
agl-hostman status

# List all storage mounts
agl-hostman storage list

# Check backup status
agl-hostman backup status

# View metrics
agl-hostman metrics

# Run diagnostics
agl-hostman diagnose
```

### API Examples

```bash
# Get NFS mounts
curl -H "Authorization: Bearer $TOKEN" \
     https://api.aglhostman.local/storage/nfs

# Create backup
curl -X POST \
     -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"schedule": "daily", "retention": 30}' \
     https://api.aglhostman.local/backups
```

## 📝 Release Notes

### v1.0.0 (2025-10-14)
- Initial release with multi-host storage management
- Tailscale VPN integration
- NFS, iSCSI, and PBS support
- Comprehensive monitoring stack
- Automated backup system

---

*Last updated: October 14, 2025*

[Edit on GitHub](https://github.com/aglhostman/agl-hostman/edit/main/docs/index.md)