# AGL Host Management System

Infrastructure management tools and documentation for AGL server infrastructure.

## Overview

This repository consolidates infrastructure management tools, scripts, and documentation from multiple sources:
- Local WSL development environment
- CT179 (agldv3) on AGLSRV1
- Overpower storage projects

## Structure

```
agl-hostman/
├── config/              # Infrastructure configuration templates
├── src/                 # Source code (hive-mind integration, performance tools)
├── tests/               # Test suites
├── docs/                # Comprehensive documentation (77 documents)
├── examples/            # Usage examples
├── projects/            # Subprojects
│   └── hive-migration/  # Hive/Migration specific project
├── scripts/             # Utility and automation scripts
└── zfs-protection/      # ZFS protection suite
```

## Key Components

### Infrastructure Tools
- **Disk Diagnostics**: Comprehensive disk health and forensic analysis tools
- **Backup Management**: Automated backup optimization and monitoring
- **Storage Configuration**: ZFS, NFS, iSCSI, PBS setup templates
- **Performance Monitoring**: Worker pools, cluster management

### Projects
- **Hive Migration**: PHP/Laravel migration tools and analysis
  - Analysis reports and code migration strategies
  - Backup synchronization scripts
  - Testing frameworks and plans

### Documentation
Extensive documentation covering:
- AGLSRV1 infrastructure analysis
- CT migration guides
- Performance optimization reports
- Troubleshooting procedures
- Storage architecture

## Quick Start

### Prerequisites
- Proxmox VE environment
- SSH access to target hosts
- Required: `jq`, `curl`, `rsync`

### Basic Usage

**Disk Diagnostics**:
```bash
./scripts/disk-diagnostic-suite.sh
```

**Backup Optimization**:
```bash
./scripts/cleanup-old-backups.sh
```

**Performance Monitoring**:
```bash
node src/performance/worker-pool/WorkerPool.js
```

## Documentation

Primary documentation is in the `docs/` directory:
- [Quick Start Guide](docs/quick-start-guide.md)
- [Architecture Summary](docs/ARCHITECTURE_SUMMARY.md)
- [Storage Architecture](docs/storage-architecture.md)
- [Implementation Checklist](docs/IMPLEMENTATION_CHECKLIST.md)

## Configuration

Configuration templates are in `config/`:
- NFS exports: `config/templates/nfs-exports.conf.template`
- iSCSI targets: `config/templates/iscsi-target-setup.sh`
- PBS datastores: `config/templates/pbs-datastore-setup.sh`
- System mounts: `config/fstab.example`

## Testing

Run test suites:
```bash
# Hive-mind integration tests
node tests/hive-mind/test-hive-mind-integration.js

# Performance tests
node tests/performance/test-worker-pool.js
```

## Projects

### Hive Migration
Located in `projects/hive-migration/`:
- Migration strategy and compatibility analysis
- Backup synchronization tools
- Comprehensive testing framework

See [Hive Migration README](projects/hive-migration/hive/code/README.md) for details.

## Contributing

This is an internal infrastructure management repository.

## License

Internal use only - AGL Infrastructure Team

## History

**Merged**: 2025-10-21
- Source 1: WSL local development (8.5M)
- Source 2: CT179 /root/host-admin (5.3M)
- Source 3: CT179 /mnt/overpower/apps/dev/agl/hostman (811K)

**Final**: Consolidated into `agl-hostman` (9.6M)

---

*Last Updated*: 2025-10-21
*Maintained by*: AGL Infrastructure Team
