---
name: database-migration-optimization
description: "Safe database migrations with zero-downtime strategies, rollback procedures, and testing for MySQL, PostgreSQL, and SQLite. Use when schema changes, index additions, or data migrations are needed."
category: development
priority: P0
tags: [laravel, database, migration, zero-downtime]
---

# Database Migration Optimization

## Overview

This skill provides comprehensive guidance for executing safe, zero-downtime database migrations in Laravel applications. It covers strategies for MySQL, PostgreSQL, and SQLite with focus on production safety.

### Critical Principles

- **Data Safety First**: Always backup before migration
- **Zero Downtime**: Use online DDL and incremental changes
- **Testable**: Every migration must be tested on staging
- **Rollback Ready**: Have rollback procedure before execution
- **Monitorable**: Track migration progress and performance

## Zero-Downtime Strategies

### Online DDL Operations

**MySQL 5.6+ and PostgreSQL support online DDL:**

```php
// Safe: Uses online DDL (no table lock)
Schema::table('users', function (Blueprint $table) {
    $table->index('email', 'idx_users_email'); // Online index creation
});

// Dangerous: Full table copy on large tables
Schema::table('users', function (Blueprint $table) {
    $table->string('middle_name')->after('first_name'); // May lock table
});
```

### Incremental Schema Changes

**For large tables, use multi-step migrations:**

```php
// Step 1: Add column (nullable)
Schema::table('users', function (Blueprint $table) {
    $table->string('new_field')->nullable();
});

// Step 2: Backfill data (separate migration or job)
// Step 3: Make column non-nullable
Schema::table('users', function (Blueprint $table) {
    $table->string('new_field')->nullable(false)->change();
});
```

### Index Creation Strategies

**For tables >1M rows:**

```php
// Use CONCURRENTLY for PostgreSQL
DB::statement('CREATE INDEX CONCURRENTLY idx_users_email ON users(email)');

// Use ALGORITHM=INPLACE for MySQL
DB::statement('ALTER TABLE users ADD INDEX idx_users_email (email), ALGORITHM=INPLACE, LOCK=NONE');
```

## Migration Planning

### Pre-Migration Checklist

1. **Assess Table Size**
   ```bash
   # MySQL
   mysql -e "SELECT table_name, table_rows, ROUND((data_length + index_length)/1024/1024, 2) AS 'Size (MB)' FROM information_schema.tables WHERE table_schema = 'your_database' ORDER BY data_length DESC;"

   # PostgreSQL
   psql -c "SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size FROM pg_tables WHERE schemaname = 'public' ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;"
   ```

2. **Check for Lock Risks**
   ```bash
   # Identify long-running queries that may block migration
   mysql -e "SHOW PROCESSLIST;" | grep -v "Sleep"
   psql -c "SELECT pid, now() - pg_stat_activity.query_start AS duration, query FROM pg_stat_activity WHERE state = 'active' ORDER BY duration DESC;"
   ```

3. **Analyze Index Impact**
   - Will the migration create/drop indexes on large tables?
   - Are there foreign key dependencies?
   - Will column types change causing table rewrite?

### Risk Assessment Matrix

| Operation | Risk Level | Downtime | Strategy |
|-----------|------------|----------|----------|
| Add nullable column | Low | None | Direct execute |
| Add non-nullable column | High | Possible | 3-step: add, backfill, constrain |
| Add index <1M rows | Low | None | Direct execute |
| Add index >1M rows | Medium | Possible | Online DDL |
| Drop column | Low | None | Direct execute |
| Rename column | High | Possible | Add new, migrate, drop old |
| Change column type | High | Likely | New column + migration |
| Add foreign key | Medium | Possible | Validate data first |

## Safe Migration Patterns

### Pattern 1: Expand and Contract

**For renaming columns/tables:**

```php
// Migration 1: Expand (add new)
public function up(): void
{
    Schema::table('users', function (Blueprint $table) {
        $table->string('email_address')->nullable()->after('email');
    });
}

// Migration 2: Deploy code writing to both columns
// Migration 3: Backfill data
public function up(): void
{
    DB::statement('UPDATE users SET email_address = email WHERE email_address IS NULL');
}

// Migration 4: Deploy code reading from new column
// Migration 5: Contract (remove old)
public function up(): void
{
    Schema::table('users', function (Blueprint $table) {
        $table->dropColumn('email');
    });
}
```

### Pattern 2: Pre-Validate Constraints

**Before adding foreign keys:**

```php
// Step 1: Validate data integrity
public function up(): void
{
    $orphaned = DB::table('posts')
        ->leftJoin('users', 'posts.user_id', '=', 'users.id')
        ->whereNull('users.id')
        ->whereNotNull('posts.user_id')
        ->count();

    if ($orphaned > 0) {
        throw new Exception("Found {$orphaned} orphaned posts. Cannot add foreign key.");
    }
}

// Step 2: Add constraint in separate migration
Schema::table('posts', function (Blueprint $table) {
    $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
});
```

### Pattern 3: Idempotent Migrations

**Always check before creating:**

```php
public function up(): void
{
    Schema::table('users', function (Blueprint $table) {
        // Check if index exists
        if (!collect(DB::select("SHOW INDEX FROM users"))->contains('Key_name', 'idx_users_email')) {
            $table->index('email', 'idx_users_email');
        }

        // Check if column exists
        if (!Schema::hasColumn('users', 'phone')) {
            $table->string('phone')->nullable();
        }
    });
}
```

## Index Operations

### Safe Index Creation

```php
// Laravel's default (may lock on large tables)
Schema::table('users', function (Blueprint $table) {
    $table->index('email', 'idx_users_email');
});

// PostgreSQL: CONCURRENTLY (no locks)
DB::statement('CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_email ON users(email)');

// MySQL: ALGORITHM=INPLACE
DB::statement('CREATE INDEX idx_users_email ON users(email), ALGORITHM=INPLACE, LOCK=NONE');
```

### Index Drop Strategy

```php
// Step 1: Mark index as deprecated (add comment)
// Step 2: Deploy code no longer using the index
// Step 3: Drop index in maintenance window
Schema::table('users', function (Blueprint $table) {
    $table->dropIndex('idx_users_email');
});
```

### Composite Index Guidelines

```php
// GOOD: Covers multiple query patterns
$table->index(['status', 'created_at'], 'idx_status_created');
// Covers: WHERE status = ?, ORDER BY created_at
// Covers: WHERE status = ? AND created_at > ?

// AVOID: Low cardinality first
$table->index(['is_active', 'user_id']); // Bad if is_active is mostly true
// BETTER:
$table->index(['user_id', 'is_active']); // High cardinality first
```

## Data Migrations

### Chunked Data Migration

```php
public function up(): void
{
    // For tables <100K rows
    DB::table('users')->orderBy('id')->chunk(1000, function ($users) {
        foreach ($users as $user) {
            DB::table('users')
                ->where('id', $user->id)
                ->update(['email_domain' => explode('@', $user->email)[1] ?? null]);
        }
    });
}

// For tables >100K rows, use a queued job
public function up(): void
{
    dispatch(new MigrateUserDataJob());
}
```

### Laravel Job for Large Data Migrations

```php
// app/Jobs/MigrateUserDataJob.php
class MigrateUserDataJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public $timeout = 3600; // 1 hour max

    public function handle(): void
    {
        $lastId = 0;
        $chunkSize = 1000;

        do {
            $users = DB::table('users')
                ->where('id', '>', $lastId)
                ->orderBy('id')
                ->limit($chunkSize)
                ->get();

            foreach ($users as $user) {
                // Migrate data
                $lastId = $user->id;
            }
        } while ($users->count() === $chunkSize);
    }
}
```

### Tracking Migration Progress

```php
// Create migration tracking table
Schema::create('migration_progress', function (Blueprint $table) {
    $table->id();
    $table->string('migration_name');
    $table->integer('processed_rows')->default(0);
    $table->integer('total_rows')->default(0);
    $table->string('status')->default('pending');
    $table->timestamps();

    $table->unique('migration_name');
});

// Update progress during migration
DB::table('migration_progress')->updateOrInsert(
    ['migration_name' => 'migrate_user_email_domains'],
    [
        'processed_rows' => $processed,
        'total_rows' => $total,
        'status' => $processed >= $total ? 'completed' : 'running'
    ]
);
```

## Testing Migrations

### Staging Environment Validation

```bash
# 1. Create a staging database snapshot
./scripts/migration-backup.sh staging

# 2. Run migration on staging
php artisan migrate --force --seed

# 3. Run tests
php artisan test --testsuite=Feature

# 4. Validate schema
php artisan schema:dump

# 5. Check for performance regressions
./scripts/migration-test.sh performance
```

### Data Integrity Checks

```php
// tests/Database/MigrationsTest.php
test('migration preserves data integrity', function () {
    $before = DB::table('users')->count();

    Artisan::call('migrate:fresh');
    Artisan::call('migrate');

    $after = DB::table('users')->count();

    expect($after)->toEqual($before);
});

test('foreign key constraints work', function () {
    // Should throw exception
    expect(fn () => DB::table('posts')->insert(['user_id' => 99999]))
        ->toThrow(QueryException::class);
});
```

### Performance Testing

```php
test('query performance after migration', function () {
    $iterations = 100;

    $start = microtime(true);
    for ($i = 0; $i < $iterations; $i++) {
        DB::table('users')->where('email', 'test@example.com')->first();
    }
    $duration = microtime(true) - $start;

    expect($duration)->toBeLessThan(1.0); // Must complete in <1 second
});
```

## Rollback Procedures

### Safe Rollback Strategy

```php
public function up(): void
{
    // Step 1: Create backup table
    Schema::create('users_backup', function (Blueprint $table) {
        $table->id();
        $table->string('name');
        $table->string('email');
        $table->timestamps();
    });

    // Step 2: Copy data
    DB::statement('INSERT INTO users_backup SELECT * FROM users');

    // Step 3: Perform migration
    Schema::table('users', function (Blueprint $table) {
        $table->string('phone')->nullable();
    });
}

public function down(): void
{
    // Step 1: Restore from backup if needed
    // Step 2: Drop new columns
    Schema::table('users', function (Blueprint $table) {
        $table->dropColumn('phone');
    });

    // Step 3: Drop backup table
    Schema::dropIfExists('users_backup');
}
```

### Point-in-Time Recovery

```bash
# For MySQL with binary logging
# 1. Note the migration start time
START_TIME=$(date +%s)

# 2. Run migration
php artisan migrate --force

# 3. If issues occur, restore to point in time
mysqlbinlog --start-datetime="$START_TIME" --stop-datetime="NOW" \
    /var/lib/mysql/mysql-bin.000123 | mysql -u root -p
```

### Rollback Verification

```php
public function down(): void
{
    Schema::table('users', function (Blueprint $table) {
        $table->dropColumn('phone');
    });

    // Verify rollback succeeded
    if (Schema::hasColumn('users', 'phone')) {
        throw new Exception('Rollback failed: Column still exists');
    }

    Log::info('Migration rolled back successfully');
}
```

## Production Checklist

### Pre-Deployment

- [ ] Migration tested on staging environment
- [ ] Database backup created and verified
- [ ] Rollback procedure documented
- [ ] Team notified of maintenance window (if needed)
- [ ] Monitoring alerts configured
- [ ] Migration script reviewed by senior DBA

### During Migration

- [ ] Run migration during low-traffic period
- [ ] Enable verbose logging
- [ ] Monitor database connections
- [ ] Track query execution times
- [ ] Watch for replication lag

### Post-Migration

- [ ] Verify schema changes applied correctly
- [ ] Run data integrity checks
- [ ] Monitor application error rates
- [ ] Check query performance metrics
- [ ] Validate replication health
- [ ] Update documentation

## Monitoring During Migration

### Key Metrics to Watch

```bash
# MySQL: Check for long-running queries
mysql -e "SHOW FULL PROCESSLIST;" | awk '{if ($6 > 10) print}'

# PostgreSQL: Check replication lag
psql -c "SELECT now() - pg_last_xact_replay_timestamp() AS replication_lag;"

# Check table locks
mysql -e "SHOW OPEN TABLES WHERE In_use > 0;"

# Monitor disk I/O
iostat -x 1 5
```

### Alert Thresholds

- Migration duration: >30 minutes = WARNING
- Replication lag: >5 seconds = WARNING, >30 seconds = CRITICAL
- Table locks: >10 seconds = WARNING
- Query time: >5 seconds = WARNING
- Connection count: >80% max = CRITICAL

## Common Pitfalls

### Avoid These Mistakes

1. **Adding non-nullable columns without defaults**
   ```php
   // BAD: Will fail on existing data
   $table->string('phone')->nullable(false);

   // GOOD: Use default or 3-step approach
   $table->string('phone')->default('')->change();
   ```

2. **Changing column types directly on large tables**
   ```php
   // BAD: Full table rewrite
   $table->string('email', 255)->change();

   // GOOD: New column + migration
   ```

3. **Forgetting about foreign keys**
   ```php
   // Before dropping column, check for dependencies
   if (collect(DB::select("SELECT * FROM information_schema.key_column_usage WHERE column_name = 'user_id'"))->isNotEmpty()) {
       throw new Exception('Cannot drop column with foreign key');
   }
   ```

4. **Ignoring indexes during data migration**
   ```php
   // Temporarily disable indexes for bulk inserts
   DB::statement('SET unique_checks=0');
   DB::statement('SET foreign_key_checks=0');
   // ... perform bulk insert ...
   DB::statement('SET unique_checks=1');
   DB::statement('SET foreign_key_checks=1');
   ```

## Quick Reference

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
- Modify enum values

### Database-Specific Notes

**MySQL:**
- Use `ALGORITHM=INPLACE, LOCK=NONE` for online DDL
- Instant ADD COLUMN for MySQL 8.0.12+
- Check `innodb_online_alter_log_max_size` for large migrations

**PostgreSQL:**
- Use `CREATE INDEX CONCURRENTLY` for zero-lock index creation
- Use `ALTER TABLE ... ALTER COLUMN ... TYPE ... USING ...` for type changes
- Check `max_locks_per_transaction` for complex migrations

**SQLite:**
- Limited online DDL support
- Most operations require full table rewrite
- Consider PRAGMA optimization for faster migrations

## Scripts

The following scripts are provided for automated migration operations:

- `scripts/migration-plan.sh` - Analyze and generate migration execution plan
- `scripts/migration-test.sh` - Test migration on staging database
- `scripts/migration-rollback.sh` - Safe rollback procedure
- `scripts/migration-backup.sh` - Pre-migration backup

## Templates

Two migration templates are provided:

- `templates/migration-zero-downtime.php` - Zero-downtime migration template
- `templates/migration-with-rollback.php` - Migration with comprehensive rollback

---

Remember: **Untested backups don't exist.** Always verify backups before migration.
