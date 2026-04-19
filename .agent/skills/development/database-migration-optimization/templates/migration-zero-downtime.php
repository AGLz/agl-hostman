<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

/**
 * Zero-Downtime Migration Template
 *
 * This template demonstrates safe migration patterns that avoid table locks
 * and allow application to continue functioning during deployment.
 *
 * Key Strategies:
 * 1. Use online DDL (CONCURRENTLY for PostgreSQL, ALGORITHM=INPLACE for MySQL)
 * 2. Add nullable columns first, backfill data later
 * 3. Create indexes before adding foreign keys
 * 4. Use expand-and-contract pattern for renames
 * 5. Chunk data migrations to avoid long-running transactions
 *
 * Usage: Copy this template and modify for your specific migration needs.
 */

return new class extends Migration
{
    /**
     * Configuration - Modify these values for your migration
     */
    private string $tableName = 'users';
    private bool $useOnlineDDL = true;  // Set to false for small tables (<10K rows)
    private int $chunkSize = 1000;      // For data migrations

    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // Step 1: Add new nullable column
        $this->addNullableColumn();

        // Step 2: Backfill data (if needed)
        // Uncomment and modify for your use case
        // $this->backfillData();

        // Step 3: Create index (if needed)
        $this->createIndex();

        // Step 4: Add foreign key constraint (if needed)
        // Uncomment and modify for your use case
        // $this->addForeignKey();
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        // Remove in reverse order
        // $this->removeForeignKey();
        $this->removeIndex();
        $this->removeColumn();
    }

    /**
     * Add a nullable column (safe operation)
     *
     * Adding a nullable column is instant for MySQL 5.7+ and PostgreSQL
     * as it doesn't require table rewrite.
     */
    private function addNullableColumn(): void
    {
        Schema::table($this->tableName, function (Blueprint $table) {
            // Example: Add phone column
            // Check if column exists to make migration idempotent
            if (!Schema::hasColumn($this->tableName, 'phone')) {
                $table->string('phone')->nullable()->after('email');
            }
        });
    }

    /**
     * Backfill data in chunks (for large tables)
     *
     * This processes data in batches to avoid:
     * - Long-running transactions
     * - Table locks
     * - Replication lag
     */
    private function backfillData(): void
    {
        $maxId = DB::table($this->tableName)->max('id');
        $lastId = 0;

        while ($lastId < $maxId) {
            $rows = DB::table($this->tableName)
                ->where('id', '>', $lastId)
                ->orderBy('id')
                ->limit($this->chunkSize)
                ->get();

            foreach ($rows as $row) {
                // Your backfill logic here
                $phone = $this->derivePhoneFromRow($row);

                DB::table($this->tableName)
                    ->where('id', $row->id)
                    ->update(['phone' => $phone]);

                $lastId = $row->id;
            }
        }
    }

    /**
     * Create index using online DDL
     *
     * For large tables, use database-specific syntax to avoid locks:
     * - PostgreSQL: CREATE INDEX CONCURRENTLY
     * - MySQL: ALGORITHM=INPLACE, LOCK=NONE
     */
    private function createIndex(): void
    {
        $indexName = 'idx_' . $this->tableName . '_phone';
        $tableName = $this->tableName;

        // Check if index exists
        $indexExists = collect(DB::select("SHOW INDEX FROM {$tableName}"))->contains('Key_name', $indexName);
        if ($indexExists) {
            return;
        }

        // Get database type
        $databaseType = DB::getDriverName();

        if ($this->useOnlineDDL && $databaseType === 'pgsql') {
            // PostgreSQL: Use CONCURRENTLY to avoid locks
            DB::statement("CREATE INDEX CONCURRENTLY IF NOT EXISTS {$indexName} ON {$tableName}(phone)");
        } elseif ($this->useOnlineDDL && $databaseType === 'mysql') {
            // MySQL: Use ALGORITHM=INPLACE for online DDL
            DB::statement("ALTER TABLE {$tableName} ADD INDEX {$indexName} (phone), ALGORITHM=INPLACE, LOCK=NONE");
        } else {
            // Small table or no online DDL support
            Schema::table($this->tableName, function (Blueprint $table) use ($indexName) {
                $table->index('phone', $indexName);
            });
        }
    }

    /**
     * Add foreign key constraint
     *
     * Prerequisites:
     * 1. Data integrity verified (no orphaned records)
     * 2. Index exists on referenced column
     */
    private function addForeignKey(): void
    {
        Schema::table($this->tableName, function (Blueprint $table) {
            // Example: Add foreign key to organization_id
            // First verify no orphaned records exist
            $orphaned = DB::table($this->tableName)
                ->whereNotNull('organization_id')
                ->whereNotIn('organization_id', function ($query) {
                    $query->select('id')->from('organizations');
                })
                ->count();

            if ($orphaned > 0) {
                throw new Exception("Cannot add foreign key: {$orphaned} orphaned records found");
            }

            $table->foreign('organization_id')->references('id')->on('organizations')->cascadeOnDelete();
        });
    }

    /**
     * Remove foreign key (rollback)
     */
    private function removeForeignKey(): void
    {
        Schema::table($this->tableName, function (Blueprint $table) {
            $table->dropForeign(['organization_id']);
        });
    }

    /**
     * Remove index (rollback)
     */
    private function removeIndex(): void
    {
        Schema::table($this->tableName, function (Blueprint $table) {
            $table->dropIndex('idx_' . $this->tableName . '_phone');
        });
    }

    /**
     * Remove column (rollback)
     *
     * Dropping a column is safe but requires app code to be deployed first
     * that no longer references this column.
     */
    private function removeColumn(): void
    {
        Schema::table($this->tableName, function (Blueprint $table) {
            $table->dropColumn('phone');
        });
    }

    /**
     * Derive phone number from existing row data
     *
     * Example backfill logic - customize for your use case
     */
    private function derivePhoneFromRow($row): ?string
    {
        // Example: Extract phone from metadata JSON
        if (!empty($row->metadata)) {
            $metadata = json_decode($row->metadata, true);
            return $metadata['phone'] ?? null;
        }

        return null;
    }
};

/**
 * ADDITIONAL ZERO-DOWNTIME PATTERNS
 */

/**
 * Pattern 1: Rename Table (Expand-Contract)
 *
 * Step 1: Create new table
 * Step 2: Deploy code writing to both tables
 * Step 3: Backfill data to new table
 * Step 4: Deploy code reading from new table
 * Step 5: Drop old table
 */
// Example:
// public function up(): void
// {
//     Schema::create('users_v2', function (Blueprint $table) {
//         $table->id();
//         $table->string('name');
//         $table->string('email');
//         $table->string('phone')->nullable();
//         $table->timestamps();
//     });
//
//     // Copy data
//     DB::statement('INSERT INTO users_v2 SELECT * FROM users');
// }

/**
 * Pattern 2: Rename Column (Expand-Contract)
 *
 * Step 1: Add new column
 * Step 2: Deploy code writing to both columns
 * Step 3: Backfill data from old to new
 * Step 4: Deploy code reading from new column
 * Step 5: Drop old column
 */
// Example:
// public function up(): void
// {
//     Schema::table('users', function (Blueprint $table) {
//         $table->string('email_address')->nullable()->after('email');
//     });
//
//     // Backfill
//     DB::table('users')->whereNull('email_address')->update([
//         'email_address' => DB::raw('email')
//     ]);
// }

/**
 * Pattern 3: Change Column Type (New Column Migration)
 *
 * Instead of: $table->string('email', 500)->change();
 *
 * Do: Create new column, migrate data, drop old
 */
// Example:
// public function up(): void
// {
//     // Step 1: Add new column with desired type
//     Schema::table('users', function (Blueprint $table) {
//         $table->text('email_long')->nullable()->after('email');
//     });
//
//     // Step 2: Migrate data
//     DB::table('users')->update([
//         'email_long' => DB::raw('email')
//     ]);
//
//     // Step 3: In next deployment, drop old and rename new
// }

/**
 * Pattern 4: Add Non-Nullable Column with Default
 *
 * For instant operation, provide a default value
 */
// Example:
// public function up(): void
// {
//     Schema::table('users', function (Blueprint $table) {
//         // Instant operation - no table rewrite
//         $table->string('status')->default('active');
//     });
//
//     // Then backfill specific values in chunks
// }

/**
 * MONITORING QUERIES
 *
 * During migration, monitor:
 *
 * -- MySQL: Check for long-running operations
 * SELECT * FROM information_schema.processlist
 * WHERE time > 10 AND command != 'Sleep';
 *
 * -- PostgreSQL: Check for blocking locks
 * SELECT pid, usename, pg_blocking_pids(pid) as blocked_by,
 *        query as blocked_query
 * FROM pg_stat_activity
 * WHERE cardinality(pg_blocking_pids(pid)) > 0;
 *
 * -- MySQL: Check replication lag
 * SHOW SLAVE STATUS\G
 * -- Look at Seconds_Behind_Master
 *
 * -- PostgreSQL: Check replication lag
 * SELECT now() - pg_last_xact_replay_timestamp() AS replication_lag;
 */
