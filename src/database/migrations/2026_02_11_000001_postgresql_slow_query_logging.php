<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * PostgreSQL Slow Query Logging Setup
 *
 * Enables comprehensive query performance tracking for AGL-23:
 * - pg_stat_statements tracking
 * - Query execution time logging
 * - Slow query identification
 * - Index usage analysis
 */
return new class extends Migration
{
    public function up(): void
    {
        // Enable pg_stat_statements extension for query logging
        DB::statement('CREATE EXTENSION IF NOT EXISTS pg_stat_statements;');

        // Create slow queries log table
        Schema::create('slow_queries_log', function (Blueprint $table) {
            $table->id();
            $table->string('query_id')->unique()->comment('Unique query identifier (MD5 hash)');
            $table->text('query')->comment('SQL query text (normalized)');
            $table->text('full_query')->nullable()->comment('Original SQL query with bindings');
            $table->string('query_type')->nullable()->comment('SELECT, INSERT, UPDATE, DELETE, etc.');
            $table->integer('calls')->default(0)->comment('Number of times executed');
            $table->decimal('total_exec_time_ms', 12, 2)->default(0)->comment('Total execution time (ms)');
            $table->decimal('mean_exec_time_ms', 12, 2)->default(0)->comment('Mean execution time (ms)');
            $table->decimal('max_exec_time_ms', 12, 2)->default(0)->comment('Max execution time (ms)');
            $table->decimal('min_exec_time_ms', 12, 2)->default(0)->comment('Min execution time (ms)');
            $table->decimal('stddev_exec_time_ms', 12, 2)->default(0)->comment('Std dev of execution time (ms)');
            $table->bigInteger('total_rows')->default(0)->comment('Total rows affected/returned');
            $table->integer('mean_rows')->default(0)->comment('Mean rows per execution');
            $table->integer('max_rows')->default(0)->comment('Max rows in single execution');
            $table->bigInteger('total_blks_read')->default(0)->comment('Total blocks read');
            $table->bigInteger('total_blks_hit')->default(0)->comment('Total blocks cache hit');
            $table->decimal('cache_hit_ratio', 5, 2)->default(0)->comment('Buffer cache hit ratio (%)');
            $table->timestamp('first_seen_at')->nullable()->comment('First execution timestamp');
            $table->timestamp('last_seen_at')->nullable()->comment('Last execution timestamp');
            $table->timestamp('analyzed_at')->nullable()->comment('Last analysis timestamp');
            $table->json('optimization_notes')->nullable()->comment('Index recommendations, etc.');
            $table->boolean('is_optimized')->default(false)->comment('Has query been optimized');
            $table->timestamps();

            // Indexes for analysis queries
            $table->index('query_type', 'slow_queries_log_type_index');
            $table->index('total_exec_time_ms', 'slow_queries_log_exec_time_index');
            $table->index('mean_exec_time_ms', 'slow_queries_log_mean_exec_index');
            $table->index('calls', 'slow_queries_log_calls_index');
            $table->index('is_optimized', 'slow_queries_log_optimized_index');
            $table->index('last_seen_at', 'slow_queries_log_last_seen_index');

            // Composite indexes for filtering
            $table->index(['query_type', 'total_exec_time_ms'], 'slow_queries_log_type_time_index');
            $table->index(['is_optimized', 'total_exec_time_ms'], 'slow_queries_log_optimized_time_index');
        });

        // Create query execution samples table (for detailed analysis)
        Schema::create('query_execution_samples', function (Blueprint $table) {
            $table->id();
            $table->string('query_id')->comment('Reference to slow_queries_log');
            $table->decimal('exec_time_ms', 12, 2)->comment('Execution time in ms');
            $table->integer('rows_affected')->default(0)->comment('Rows affected');
            $table->integer('rows_returned')->default(0)->comment('Rows returned');
            $table->integer('blks_read')->default(0)->comment('Blocks read from disk');
            $table->integer('blks_hit')->default(0)->comment('Blocks hit in cache');
            $table->text('bind_values')->nullable()->comment('Query parameter values');
            $table->string('application_name')->nullable()->comment('Application name');
            $table->string('user_name')->nullable()->comment('Database user');
            $table->string('client_ip')->nullable()->comment('Client IP address');
            $table->timestamp('executed_at')->comment('Execution timestamp');

            // Indexes
            $table->index('query_id', 'query_exec_samples_query_id_index');
            $table->index('exec_time_ms', 'query_exec_samples_exec_time_index');
            $table->index('executed_at', 'query_exec_samples_executed_at_index');
            $table->index(['query_id', 'executed_at'], 'query_exec_samples_query_time_index');
        });

        // Create missing indexes tracking table
        Schema::create('missing_indexes_log', function (Blueprint $table) {
            $table->id();
            $table->string('table_name')->comment('Table requiring index');
            $table->string('column_name')->comment('Column to index');
            $table->string('index_type')->default('btree')->comment('Index type: btree, hash, gist, gin');
            $table->integer('priority')->default(0)->comment('Priority: 1=low, 2=medium, 3=high');
            $table->string('reason')->comment('Reason for index recommendation');
            $table->text('suggested_sql')->comment('Suggested CREATE INDEX statement');
            $table->integer('estimated_benefit')->default(0)->comment('Estimated performance gain %');
            $table->boolean('is_created')->default(false)->comment('Has index been created');
            $table->timestamp('created_at')->comment('When recommendation was made');
            $table->timestamp('applied_at')->nullable()->comment('When index was applied');
            $table->timestamps();

            // Indexes
            $table->index(['table_name', 'is_created'], 'missing_indexes_table_created_index');
            $table->index('priority', 'missing_indexes_priority_index');
            $table->index('estimated_benefit', 'missing_indexes_benefit_index');
        });

        // Create table size tracking table
        Schema::create('table_size_metrics', function (Blueprint $table) {
            $table->id();
            $table->string('table_name')->unique()->comment('Table name');
            $table->bigInteger('table_size_bytes')->default(0)->comment('Table size in bytes');
            $table->bigInteger('index_size_bytes')->default(0)->comment('Index size in bytes');
            $table->bigInteger('total_size_bytes')->default(0)->comment('Total size in bytes');
            $table->integer('row_count')->default(0)->comment('Estimated row count');
            $table->integer('seq_scans')->default(0)->comment('Sequential scans');
            $table->integer('idx_scans')->default(0)->comment('Index scans');
            $table->decimal('scan_ratio', 5, 2)->default(0)->comment('Seq scan ratio %');
            $table->integer('vacuum_count')->default(0)->comment('Number of VACUUM operations');
            $table->integer('analyze_count')->default(0)->comment('Number of ANALYZE operations');
            $table->timestamp('last_vacuum_at')->nullable();
            $table->timestamp('last_analyze_at')->nullable();
            $table->timestamp('last_autovacuum_at')->nullable();
            $table->timestamps();

            $table->index('table_size_bytes', 'table_size_metrics_size_index');
            $table->index('scan_ratio', 'table_size_metrics_scan_ratio_index');
        });

        // Create function to update slow queries log
        DB::unprepared("
            CREATE OR REPLACE FUNCTION update_slow_queries_log()
            RETURNS void AS $$
            BEGIN
                INSERT INTO slow_queries_log (
                    query_id,
                    query,
                    query_type,
                    calls,
                    total_exec_time_ms,
                    mean_exec_time_ms,
                    max_exec_time_ms,
                    min_exec_time_ms,
                    stddev_exec_time_ms,
                    total_rows,
                    mean_rows,
                    max_rows,
                    total_blks_read,
                    total_blks_hit,
                    cache_hit_ratio,
                    first_seen_at,
                    last_seen_at
                )
                SELECT
                    MD5(query),
                    SUBSTRING(query FROM 1 FOR 1000),
                    REGEXP_REPLACE(SUBSTRING(query FROM 1 FOR 50), '^(SELECT|INSERT|UPDATE|DELETE|MERGE).*', '\1', 'unknown'),
                    calls,
                    ROUND(total_exec_time::numeric, 2),
                    ROUND(mean_exec_time::numeric, 2),
                    ROUND(max_exec_time::numeric, 2),
                    ROUND(min_exec_time::numeric, 2),
                    ROUND(stddev_exec_time::numeric, 2),
                    total_rows,
                    ROUND(mean_rows::numeric, 0),
                    max_rows,
                    total_blks_read,
                    total_blks_hit,
                    CASE
                        WHEN (total_blks_read + total_blks_hit) > 0
                        THEN ROUND((total_blks_hit::numeric / (total_blks_read + total_blks_hit)::numeric * 100), 2)
                        ELSE 0
                    END,
                    MIN(calls),
                    MAX(calls)
                FROM pg_stat_statements
                WHERE calls > 10
                ON CONFLICT (query_id) DO UPDATE SET
                    calls = EXCLUDED.calls,
                    total_exec_time_ms = EXCLUDED.total_exec_time_ms,
                    mean_exec_time_ms = EXCLUDED.mean_exec_time_ms,
                    max_exec_time_ms = EXCLUDED.max_exec_time_ms,
                    calls = EXCLUDED.calls,
                    last_seen_at = NOW();
            END;
            $$ LANGUAGE plpgsql;
        ");

        // Create materialized view for top slow queries
        DB::unprepared("
            CREATE MATERIALIZED VIEW mv_slow_queries_top AS
            SELECT
                query_id,
                query,
                query_type,
                calls,
                total_exec_time_ms,
                mean_exec_time_ms,
                max_exec_time_ms,
                cache_hit_ratio,
                CASE
                    WHEN mean_exec_time_ms < 10 THEN 'fast'
                    WHEN mean_exec_time_ms < 50 THEN 'normal'
                    WHEN mean_exec_time_ms < 200 THEN 'slow'
                    ELSE 'critical'
                END as performance_level
            FROM slow_queries_log
            WHERE is_optimized = false
            ORDER BY total_exec_time_ms DESC
            LIMIT 100;
        ");

        // Create index on materialized view
        DB::statement('CREATE UNIQUE INDEX ON mv_slow_queries_top (query_id)');
    }

    public function down(): void
    {
        DB::statement('DROP MATERIALIZED VIEW IF EXISTS mv_slow_queries_top');
        DB::statement('DROP FUNCTION IF EXISTS update_slow_queries_log()');
        Schema::dropIfExists('query_execution_samples');
        Schema::dropIfExists('missing_indexes_log');
        Schema::dropIfExists('table_size_metrics');
        Schema::dropIfExists('slow_queries_log');

        // Note: We don't drop pg_stat_statements extension
        // as it may be used by other parts of the application
    }
};
