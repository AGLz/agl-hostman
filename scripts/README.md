# Scripts Directory

Organized collection of infrastructure management scripts.

## Structure

### backup/
Backup system management scripts:
- `monitor_backup_progress.sh` - Monitor ongoing backup operations
- `verify_backup_system.sh` - Verify backup system integrity

### forensic/
Forensic analysis and diagnostic tools:
- `forensic_collector.sh` - Collect forensic data from systems
- `disk_forensic_analyzer.sh` - Analyze disk health and issues
- `disk-diagnostic-suite.sh` - Comprehensive disk diagnostics
- `validate_forensic_suite.sh` - Validate forensic tools installation

### monitoring/
System monitoring and health check scripts:
- `dashboard.sh` - System dashboard display
- `monitor-deployment.sh` - Monitor deployment progress
- `smart_health_check.sh` - SMART disk health monitoring

### recovery/
System recovery and repair scripts:
- `recovery_planner.sh` - Plan recovery operations
- `qmp_timeout_recovery.sh` - Recover from QMP timeouts

### zfs/
ZFS filesystem management:
- `zfs_diagnostic.sh` - ZFS diagnostics
- `zfs_pool_analyzer.sh` - Analyze ZFS pool health

### deployment/
Deployment and installation automation:
- `EXECUTE-NOW.sh` - Main deployment execution script
- `auto_execute_when_ready.sh` - Conditional auto-execution
- `phase1_cleanup_surgical.sh` - Phase 1 cleanup operations
- `optimization_plan.sh` - System optimization automation
- `fix_fgsrv06_mono.sh` - FGSRV06 specific fixes
- `vm200-*.ps1` - Windows VM deployment scripts

### macOS/
macOS-specific setup and configuration:
- `macos-agl-setup.sh` - Automated macOS AGL environment setup
- `macos-install-improvements.sh` - macOS installation improvements
- `macos-ssh-config-update.sh` - SSH configuration automation

## Usage

All scripts should be executed from the project root directory unless otherwise specified.
Most scripts require root privileges or specific environment variables.

## Best Practices

1. Always review scripts before execution
2. Check for required dependencies
3. Ensure proper permissions (chmod +x)
4. Test in development before production use
5. Document any modifications

---
**Last Updated**: 2025-10-31
