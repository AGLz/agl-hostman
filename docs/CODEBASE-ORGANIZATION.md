# Codebase Organization

> **Last Updated**: 2025-10-31

## Directory Structure

The codebase follows a clean, organized structure to maintain clarity and ease of navigation.

### Root Directory

The root directory is kept **minimal** and contains only essential configuration files:

```
agl-hostman/
├── .claude/                  # Claude Code configuration
├── .claude-flow/             # Claude-Flow swarm coordination
├── .github/                  # GitHub workflows and actions
├── .hive-mind/               # Multi-agent coordination
├── .swarm/                   # Swarm configuration
├── agent-os/                 # Agent OS integration
├── archive/                  # Archived legacy files (gitignored)
├── config/                   # Infrastructure configuration templates
├── docker/                   # Docker build context
├── docs/                     # All documentation
├── examples/                 # Usage examples
├── projects/                 # Subprojects
├── scripts/                  # All scripts organized by category
├── src/                      # Source code
├── tests/                    # Test suites
├── .dockerignore             # Docker ignore rules
├── .env.example              # Environment template
├── .gitignore                # Git ignore rules
├── .pre-commit-config.yaml   # Pre-commit hooks
├── CLAUDE.md                 # Project-specific Claude instructions
├── docker-compose.yml        # Docker services
├── package.json              # Node.js dependencies
├── package-lock.json         # Locked dependencies
├── README.md                 # Project overview
├── SECURITY.md               # Security guidelines
└── START-HERE.md             # Quick start guide
```

### Scripts Directory (`/scripts`)

All executable scripts organized by purpose:

- **backup/** - Backup system management
  - `monitor_backup_progress.sh`
  - `verify_backup_system.sh`

- **forensic/** - Diagnostic and forensic tools
  - `forensic_collector.sh`
  - `disk_forensic_analyzer.sh`
  - `disk-diagnostic-suite.sh`
  - `validate_forensic_suite.sh`

- **monitoring/** - System monitoring
  - `dashboard.sh`
  - `monitor-deployment.sh`
  - `smart_health_check.sh`

- **recovery/** - System recovery
  - `recovery_planner.sh`
  - `qmp_timeout_recovery.sh`

- **zfs/** - ZFS management
  - `zfs_diagnostic.sh`
  - `zfs_pool_analyzer.sh`

- **deployment/** - Deployment automation
  - `EXECUTE-NOW.sh`
  - `auto_execute_when_ready.sh`
  - `phase1_cleanup_surgical.sh`
  - `optimization_plan.sh`
  - `fix_fgsrv06_mono.sh`
  - `vm200-*.ps1`

- **macos/** - macOS specific setup
  - `macos-agl-setup.sh`
  - `macos-install-improvements.sh`
  - `macos-ssh-config-update.sh`

### Source Directory (`/src`)

Application source code:

- **utils/** - Utility scripts and configuration
  - `statusline-utilities.py`
  - `statusline-config.yaml`
  - `statusline-templates.yaml`

- **validation/** - Code validation tools
  - `burn-rate-engine.py`
  - `error-handling-validation.py`

### Documentation Directory (`/docs`)

All documentation organized by topic:

- **archive/** - Historical documentation
  - `backup-docs/` - Backup implementation docs
  - `forensic-docs/` - Forensic analysis docs
  - `vm-docs/` - VM configuration docs
  - `zfs-docs/` - ZFS recovery docs
  - `analysis-reports/` - Investigation reports
  - Legacy deployment guides and checklists

- **Active Documentation**
  - `INFRA.md` - Infrastructure map and topology
  - `ARCHON.md` - Archon MCP integration
  - `WORKFLOWS.md` - Development workflows
  - `RULES.md` - Coding standards
  - `QUICK-START.md` - Quick reference
  - `DOKPLOY.md` - Deployment platform docs
  - `MACOS-SETUP.md` - macOS setup guide
  - `MACOS-ADVANCED.md` - Advanced macOS configuration

### Archive Directory (`/archive`)

Legacy files kept for historical reference (gitignored):

- `zfs-protection-suite.tar.gz`
- `zfs-protection/`

## File Organization Rules

### CRITICAL Rules

1. **Root Folder** - Only essential configuration files
   - Never save temporary files to root
   - Never save analysis/reports to root
   - Never save scripts to root

2. **Scripts** - All executable scripts in `/scripts` subdirectories
   - Organize by purpose (backup, monitoring, deployment, etc.)
   - Include category-specific README files

3. **Documentation** - All markdown files in `/docs`
   - Active docs in `/docs` root
   - Historical docs in `/docs/archive`
   - Organize archive by topic

4. **Source Code** - All application code in `/src`
   - Organize by functionality
   - Include module-specific documentation

## Cleanup History

**2025-10-31**: Major repository reorganization
- Moved 60+ markdown files from root to `/docs/archive`
- Moved 20+ shell scripts from root to `/scripts` subdirectories
- Moved Python utilities from root to `/src` subdirectories
- Moved archive files to `/archive` directory
- Created comprehensive README files for all major directories
- Updated `.gitignore` to exclude archive directory

## Maintenance

### Adding New Files

**Documentation**:
```bash
# Active documentation
docs/NEW-FEATURE.md

# Historical/archive documentation
docs/archive/category/old-feature.md
```

**Scripts**:
```bash
# Choose appropriate category
scripts/monitoring/new-monitor.sh
scripts/deployment/new-deploy.sh
```

**Source Code**:
```bash
# Organize by functionality
src/utils/new-utility.py
src/validation/new-validator.py
```

### Regular Cleanup

- **Weekly**: Review root directory for misplaced files
- **Monthly**: Update archive organization
- **Quarterly**: Review and consolidate documentation

## Best Practices

1. **Before Creating Files**
   - Determine correct location based on file type
   - Check if similar files already exist
   - Follow existing naming conventions

2. **Documentation**
   - Update relevant README when adding files
   - Cross-reference related documents
   - Keep active docs separate from archives

3. **Scripts**
   - Add executable permissions (`chmod +x`)
   - Include usage comments in script header
   - Update scripts/README.md with new additions

4. **Source Code**
   - Follow coding standards in `/docs/RULES.md`
   - Include inline documentation
   - Write tests for new functionality

## Related Documentation

- `/docs/RULES.md` - Coding standards and execution patterns
- `/docs/WORKFLOWS.md` - Development workflows and methodologies
- `/scripts/README.md` - Scripts directory organization
- `/src/README.md` - Source code organization
- `/docs/archive/README.md` - Archive documentation index

---

**Maintained by**: Claude Code (agl-hostman project)
**Version**: 1.0.0
