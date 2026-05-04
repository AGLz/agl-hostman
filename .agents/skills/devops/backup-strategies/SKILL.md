---
name: Backup Strategies
description: Comprehensive backup and disaster recovery strategies for Laravel applications covering database backups, file storage backups, backup retention policies, automated backup scheduling, restoration procedures, and recovery time objectives (RTO/RPO). Use this skill when implementing database backup strategies for MySQL/PostgreSQL, setting up automated file storage backups, configuring backup retention and archival policies, scheduling automated backup jobs with Laravel commands, implementing database dump and export procedures, setting up remote backup storage (S3, Azure Blob, GCS), creating backup encryption and security measures, implementing incremental and full backup strategies, setting up backup monitoring and alerting, creating disaster recovery procedures, testing backup restoration processes, implementing point-in-time recovery, setting up backup verification and integrity checks, managing backup storage costs and cleanup, creating documentation for restore procedures, implementing multi-region backup replication, setting up backup compliance and auditing, or handling emergency recovery scenarios. Essential for data protection and business continuity, preventing catastrophic data loss, meeting compliance and regulatory requirements, ensuring rapid recovery from failures, protecting against ransomware and data corruption, maintaining customer trust and service availability, and implementing comprehensive disaster recovery plans.
---

# Backup Strategies

This Skill provides Codex with specific guidance on backup and disaster recovery for Laravel.

## When to use this skill:

- Implementing database backup automation
- Setting up file storage and media backups
- Configuring backup retention and cleanup policies
- Creating scheduled backup commands and jobs
- Implementing database dump and export procedures
- Setting up cloud storage for remote backups (S3, Azure)
- Implementing backup encryption and security measures
- Creating incremental vs full backup strategies
- Setting up backup failure monitoring and alerts
- Creating disaster recovery runbooks
- Testing backup restoration procedures
- Implementing point-in-time recovery (PITR)
- Setting up backup verification and integrity checks
- Managing backup storage costs and lifecycle
- Documenting restore procedures for teams
- Implementing multi-region backup replication
- Setting up backup compliance and audit logging
- Handling emergency recovery scenarios

## Instructions

For details, refer to the information provided in this file:
[assets/backup-guide.md](assets/backup-guide.md)

## Key Templates

- **BackupCommand.php**: Database backup Laravel command
- **StorageBackupCommand.php**: File storage backup command
- **RestoreCommand.php**: Database restoration command
- **backup-config.php**: Backup configuration settings
- **disaster-recovery.md**: Recovery runbook documentation
