# Database Migration Optimization

A comprehensive skill for safe, zero-downtime database migrations in Laravel applications.

## Overview

This skill provides tools, templates, and best practices for executing database migrations with minimal risk and downtime. It supports MySQL, PostgreSQL, and SQLite.

## Quick Start

```bash
# 1. Plan your migration
./scripts/migration-plan.sh staging

# 2. Create backup
./scripts/migration-backup.sh staging

# 3. Test on staging
./scripts/migration-test.sh staging

# 4. Deploy to production (with backup)
./scripts/migration-backup.sh production
php artisan migrate --force

# 5. If rollback needed
./scripts/migration-rollback.sh production
```

## Scripts

### migration-plan.sh

Analyzes migrations and generates execution plan with risk assessment.

```bash
./scripts/migration-plan.sh [environment]
```

**Features:**
- Checks for pending migrations
- Analyzes migration files for risks
- Assesses table sizes and lock risks
- Generates execution plan

**Output:** Storage report with risk levels and recommendations

### migration-backup.sh

Creates comprehensive backup before migration operations.

```bash
./scripts/migration-backup.sh [environment]
```

**Features:**
- Full database dump with mysqldump/pg_dump
- Schema backup
- Migration state backup
- Compression and checksums
- Automatic cleanup of old backups

**Configuration:**
- `BACKUP_RETENTION_DAYS`: Days to keep backups (default: 7)
- `SKIP_CLEANUP`: Set to "true" to disable cleanup

### migration-test.sh

Tests migration on staging database and validates results.

```bash
./scripts/migration-test.sh [environment]
```

**Features:**
- Database connection testing
- Migration execution with rollback on failure
- Schema validation
- Foreign key constraint testing
- Data integrity checks
- Optional application tests (set `RUN_APP_TESTS=true`)

### migration-rollback.sh

Safely rolls back migrations with data preservation.

```bash
./scripts/migration-rollback.sh [environment] [steps]
```

**Options:**
- `steps`: Number of migrations to rollback (default: 1, use "all" for all)

**Features:**
- Pre-rollback backup creation
- Data dependency checking
- Orphaned data detection
- Optional application tests (set `RUN_TESTS=true`)

**Configuration:**
- `SKIP_CONFIRM`: Set to "true" to skip confirmation prompt
- `CREATE_BACKUP`: Set to "false" to skip pre-rollback backup

## Templates

### migration-zero-downtime.php

Template for migrations that avoid downtime using online DDL and incremental changes.

**Key patterns:**
- Add nullable columns first
- Use online DDL for large tables
- Chunk data migrations
- Expand-and-contract for renames

### migration-with-rollback.php

Template with comprehensive rollback support including backup and verification.

**Features:**
- Pre-migration validation
- Automatic backup creation
- Post-migration verification
- Complete rollback procedures

## Best Practices

### Safe Operations (Zero Downtime)
- Add nullable column
- Add index on table <1M rows
- Drop column
- Drop index
- Add table

### Risky Operations (May Require Downtime)
- Add non-nullable column
- Add index on table >1M rows
- Rename column/table
- Change column type
- Add foreign key constraint

### Pre-Deployment Checklist
- [ ] Migration tested on staging
- [ ] Database backup created
- [ ] Rollback procedure documented
- [ ] Team notified of maintenance window
- [ ] Monitoring alerts configured

### During Migration
- [ ] Run during low-traffic period
- [ ] Enable verbose logging
- [ ] Monitor database connections
- [ ] Track query execution times
- [ ] Watch for replication lag

### Post-Migration
- [ ] Verify schema changes applied
- [ ] Run data integrity checks
- [ ] Monitor application error rates
- [ ] Check query performance metrics
- [ ] Update documentation

## Database-Specific Notes

### MySQL
- Use `ALGORITHM=INPLACE, LOCK=NONE` for online DDL
- Instant ADD COLUMN for MySQL 8.0.12+
- Check `innodb_online_alter_log_max_size` for large migrations

### PostgreSQL
- Use `CREATE INDEX CONCURRENTLY` for zero-lock index creation
- Use `ALTER TABLE ... ALTER COLUMN ... TYPE ... USING ...` for type changes
- Check `max_locks_per_transaction` for complex migrations

### SQLite
- Limited online DDL support
- Most operations require full table rewrite
- Consider PRAGMA optimization for faster migrations

## Monitoring During Migration

```bash
# MySQL: Check for long-running queries
mysql -e "SHOW FULL PROCESSLIST;" | awk '{if ($6 > 10) print}'

# PostgreSQL: Check replication lag
psql -c "SELECT now() - pg_last_xact_replay_timestamp() AS replication_lag;"

# Check table locks
mysql -e "SHOW OPEN TABLES WHERE In_use > 0;"
```

## Troubleshooting

### Migration Stuck
```bash
# Check for blocking locks
SHOW PROCESSLIST;
KILL <process_id>;
```

### Rollback Failed
```bash
# Restore from backup
mysql -u root -p database_name < backup-file.sql.gz
```

### Data Integrity Issues
```bash
# Check for orphaned records
php artisan tinker --execute="
    \$orphaned = DB::table('table')
        ->whereNotNull('foreign_key')
        ->whereNotIn('foreign_key', function(\$q) {
            \$q->select('id')->from('related_table');
        })
        ->count();
    echo \$orphaned;
"
```

## Examples Directory

The `examples/` directory contains real-world migration examples from the codebase:

- `add-indexes.php` - Adding indexes to existing tables
- `create-table-with-relationships.php` - New table with foreign keys
- `backfill-data.php` - Data migration with chunking

## Related Skills

- `laravel-migrations` - Basic Laravel migration patterns
- `laravel-best-practices` - General Laravel best practices

## Further Reading

- [Laravel Database Migrations](https://laravel.com/docs/migrations)
- [MySQL Online DDL](https://dev.mysql.com/doc/refman/8.0/en/innodb-online-ddl.html)
- [PostgreSQL CREATE INDEX CONCURRENTLY](https://www.postgresql.org/docs/current/sql-createindex.html)

---

Remember: **Untested backups don't exist.** Always verify backups before migration.
