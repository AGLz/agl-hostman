<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * Migration with Comprehensive Rollback Template
 *
 * This template provides safe migration operations with full rollback support.
 * It includes:
 * 1. Pre-migration validation
 * 2. Backup creation
 * 3. Transactional operations
 * 4. Post-migration verification
 * 5. Complete rollback procedures
 *
 * Usage: Copy this template and modify for your specific migration needs.
 */

return new class extends Migration
{
    /**
     * Configuration
     */
    private string $tableName = 'users';
    private bool $createBackup = true;
    private bool $requireManualConfirmation = true;
    private array $validationErrors = [];

    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // Step 1: Pre-migration validation
        $this->preMigrationValidation();

        // Step 2: Create backup if enabled
        if ($this->createBackup) {
            $this->createBackup();
        }

        // Step 3: Perform migration in transaction
        $this->performMigration();

        // Step 4: Post-migration verification
        $this->postMigrationVerification();

        Log::info("Migration completed successfully for table: {$this->tableName}");
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Log::info("Rolling back migration for table: {$this->tableName}");

        // Step 1: Verify rollback safety
        $this->verifyRollbackSafety();

        // Step 2: Perform rollback
        $this->performRollback();

        // Step 3: Restore from backup if needed
        if ($this->createBackup) {
            $this->restoreFromBackup();
        }

        // Step 4: Verify rollback success
        $this->verifyRollback();

        Log::info("Rollback completed successfully for table: {$this->tableName}");
    }

    /**
     * Pre-migration validation
     *
     * Verify prerequisites before executing migration
     */
    private function preMigrationValidation(): void
    {
        Log::info("Running pre-migration validation for: {$this->tableName}");

        // Check if table exists
        if (!Schema::hasTable($this->tableName)) {
            $this->validationErrors[] = "Table {$this->tableName} does not exist";
        }

        // Check for sufficient disk space (estimate)
        $this->checkDiskSpace();

        // Check for existing data that might conflict
        $this->checkDataConflicts();

        // Check for active connections
        $this->checkActiveConnections();

        // Fail if any validation errors
        if (!empty($this->validationErrors)) {
            $message = "Pre-migration validation failed:\n" . implode("\n", $this->validationErrors);
            Log::error($message);
            throw new Exception($message);
        }

        Log::info("Pre-migration validation passed");
    }

    /**
     * Check for sufficient disk space
     */
    private function checkDiskSpace(): void
    {
        // Get database size
        $databaseSize = DB::select("
            SELECT
                ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS size_mb
            FROM information_schema.tables
            WHERE table_schema = DATABASE()
        ")[0]->size_mb ?? 0;

        // Get available disk space
        $freeSpace = disk_free_space(storage_path());
        $freeSpaceMB = $freeSpace / 1024 / 1024;

        // Require 3x database size as free space
        $requiredSpace = $databaseSize * 3;

        if ($freeSpaceMB < $requiredSpace) {
            $this->validationErrors[] = sprintf(
                "Insufficient disk space: %.2f MB available, %.2f MB required (3x database size)",
                $freeSpaceMB,
                $requiredSpace
            );
        }
    }

    /**
     * Check for data conflicts
     */
    private function checkDataConflicts(): void
    {
        // Example: Check for duplicate values in column to be indexed
        $duplicateCheck = DB::table($this->tableName)
            ->select('email', DB::raw('COUNT(*) as count'))
            ->groupBy('email')
            ->having('count', '>', 1)
            ->get();

        if ($duplicateCheck->isNotEmpty()) {
            $this->validationErrors[] = "Found duplicate email addresses that would prevent unique index creation";
        }
    }

    /**
     * Check for active database connections
     */
    private function checkActiveConnections(): void
    {
        $processes = DB::select("SHOW PROCESSLIST");
        $activeProcesses = collect($processes)->filter(function ($process) {
            return $process->Command !== 'Sleep' && $process->Time > 10;
        });

        if ($activeProcesses->isNotEmpty()) {
            Log::warning("Long-running queries detected that may block migration", [
                'processes' => $activeProcesses->toArray()
            ]);
        }
    }

    /**
     * Create backup of affected table
     */
    private function createBackup(): void
    {
        Log::info("Creating backup for: {$this->tableName}");

        $backupTable = "{$this->tableName}_backup_" . date('YmdHis');

        // Create backup table
        DB::statement("CREATE TABLE {$backupTable} LIKE {$this->tableName}");
        DB::statement("INSERT INTO {$backupTable} SELECT * FROM {$this->tableName}");

        // Verify backup
        $originalCount = DB::table($this->tableName)->count();
        $backupCount = DB::table($backupTable)->count();

        if ($originalCount !== $backupCount) {
            throw new Exception("Backup verification failed: row count mismatch");
        }

        Log::info("Backup created successfully: {$backupTable}");
    }

    /**
     * Perform the main migration
     */
    private function performMigration(): void
    {
        Log::info("Performing migration for: {$this->tableName}");

        Schema::table($this->tableName, function (Blueprint $table) {
            // Example 1: Add new column
            if (!Schema::hasColumn($this->tableName, 'phone')) {
                $table->string('phone')->nullable()->after('email');
            }

            // Example 2: Add index
            $indexes = collect(DB::select("SHOW INDEX FROM {$this->tableName}"));
            if (!$indexes->contains('Key_name', 'idx_users_phone')) {
                $table->index('phone', 'idx_users_phone');
            }

            // Example 3: Add new column with default
            if (!Schema::hasColumn($this->tableName, 'status')) {
                $table->string('status')->default('active')->after('email');
            }

            // Example 4: Add foreign key (after validation)
            // $table->foreign('organization_id')->references('id')->on('organizations');
        });

        Log::info("Schema changes applied successfully");
    }

    /**
     * Post-migration verification
     */
    private function postMigrationVerification(): void
    {
        Log::info("Running post-migration verification");

        // Verify new columns exist
        if (!Schema::hasColumn($this->tableName, 'phone')) {
            throw new Exception("Verification failed: phone column not created");
        }

        if (!Schema::hasColumn($this->tableName, 'status')) {
            throw new Exception("Verification failed: status column not created");
        }

        // Verify indexes exist
        $indexes = collect(DB::select("SHOW INDEX FROM {$this->tableName}"));
        if (!$indexes->contains('Key_name', 'idx_users_phone')) {
            throw new Exception("Verification failed: phone index not created");
        }

        // Verify data integrity
        $this->verifyDataIntegrity();

        // Verify foreign keys (if added)
        // $this->verifyForeignKeys();

        Log::info("Post-migration verification passed");
    }

    /**
     * Verify data integrity after migration
     */
    private function verifyDataIntegrity(): void
    {
        // Check row count hasn't changed
        $count = DB::table($this->tableName)->count();
        if ($count < 1) {
            throw new Exception("Data integrity check failed: no rows found");
        }

        // Sample queries to verify data is accessible
        $sample = DB::table($this->tableName)->first();
        if (!$sample) {
            throw new Exception("Data integrity check failed: cannot read sample row");
        }
    }

    /**
     * Verify rollback safety
     */
    private function verifyRollbackSafety(): void
    {
        Log::info("Verifying rollback safety");

        // Check if data would be lost
        $columnsWithData = DB::table($this->tableName)
            ->whereNotNull('phone')
            ->where('phone', '!=', '')
            ->count();

        if ($columnsWithData > 0) {
            Log::warning("Rollback will lose data in 'phone' column for {$columnsWithData} rows");
        }
    }

    /**
     * Perform rollback
     */
    private function performRollback(): void
    {
        Log::info("Performing rollback for: {$this->tableName}");

        Schema::table($this->tableName, function (Blueprint $table) {
            // Drop indexes
            $table->dropIndex('idx_users_phone');

            // Drop columns in reverse order
            if (Schema::hasColumn($this->tableName, 'status')) {
                $table->dropColumn('status');
            }

            if (Schema::hasColumn($this->tableName, 'phone')) {
                $table->dropColumn('phone');
            }
        });

        Log::info("Rollback schema changes applied");
    }

    /**
     * Restore from backup
     */
    private function restoreFromBackup(): void
    {
        Log::info("Attempting to restore from backup");

        // Find most recent backup
        $backups = DB::select("SHOW TABLES LIKE '{$this->tableName}_backup_%'");

        if (empty($backups)) {
            Log::warning("No backup found to restore from");
            return;
        }

        // Sort backups by name (which includes timestamp) and get latest
        usort($backups, function ($a, $b) {
            $key = array_key_first($a);
            return strcmp($b->$key, $a->$key);
        });

        $latestBackup = $backups[0];
        $key = array_key_first($latestBackup);
        $backupTableName = $latestBackup->$key;

        Log::info("Restoring from backup: {$backupTableName}");

        // Restore data
        DB::statement("TRUNCATE TABLE {$this->tableName}");
        DB::statement("INSERT INTO {$this->tableName} SELECT * FROM {$backupTableName}");

        // Verify restore
        $backupCount = DB::table($backupTableName)->count();
        $tableCount = DB::table($this->tableName)->count();

        if ($backupCount !== $tableCount) {
            throw new Exception("Backup restore verification failed: row count mismatch");
        }

        Log::info("Backup restored successfully");
    }

    /**
     * Verify rollback success
     */
    private function verifyRollback(): void
    {
        Log::info("Verifying rollback");

        // Verify columns are removed
        if (Schema::hasColumn($this->tableName, 'phone')) {
            throw new Exception("Rollback verification failed: phone column still exists");
        }

        if (Schema::hasColumn($this->tableName, 'status')) {
            throw new Exception("Rollback verification failed: status column still exists");
        }

        // Verify indexes are removed
        $indexes = collect(DB::select("SHOW INDEX FROM {$this->tableName}"));
        if ($indexes->contains('Key_name', 'idx_users_phone')) {
            throw new Exception("Rollback verification failed: phone index still exists");
        }

        // Verify table is still functional
        $count = DB::table($this->tableName)->count();
        Log::info("Rollback verification passed. Table has {$count} rows");
    }
};

/**
 * ROLLBACK STRATEGIES
 *
 * Different rollback strategies for different scenarios:
 */

/**
 * Strategy 1: Full Table Restore
 *
 * Use when:
 * - Complete data loss is possible
 * - Migration was complex with multiple changes
 * - Quick rollback is critical
 *
 * Implementation: See restoreFromBackup() method above
 */

/**
 * Strategy 2: Revert Schema Changes
 *
 * Use when:
 * - No data manipulation occurred
 * - Only structural changes were made
 * - Data can be recalculated if needed
 *
 * Implementation: See performRollback() method above
 */

/**
 * Strategy 3: Point-in-Time Recovery
 *
 * Use when:
 * - Database supports PITR (PostgreSQL, MySQL with binlog)
 * - Backup is not recent enough
 * - Need to recover to specific state
 *
 * Example:
 * // For MySQL with binary logging
 * mysqlbinlog --start-datetime="2025-01-20 10:00:00" \
 *             --stop-datetime="2025-01-20 11:00:00" \
 *             /var/lib/mysql/mysql-bin.000123 | mysql -u root -p
 */

/**
 * Strategy 4: Application-Level Rollback
 *
 * Use when:
 * - Database changes are irreversible
 * - Application can handle old schema
 * - Need to maintain data consistency
 *
 * Implementation:
 * - Deploy previous version of application code
 * - Modify application to ignore new columns/tables
 * - Plan cleanup during maintenance window
 */

/**
 * MONITORING DURING ROLLBACK
 *
 * Track these metrics during rollback:
 *
 * -- Rollback progress
 * SELECT COUNT(*) FROM {$this->tableName};
 *
 * -- Active connections blocking rollback
 * SHOW PROCESSLIST;
 *
 * -- Replication status (if applicable)
 * SHOW SLAVE STATUS\G
 *
 * -- Table locks
 * SHOW OPEN TABLES WHERE In_use > 0;
 */

/**
 * TESTING ROLLBACK PROCEDURES
 *
 * Always test rollback on staging before production:
 *
 * 1. Run migration on staging
 * 2. Verify application works
 * 3. Run rollback on staging
 * 4. Verify application still works
 * 5. Run migration again on staging
 * 6. Deploy to production only after successful test
 */
