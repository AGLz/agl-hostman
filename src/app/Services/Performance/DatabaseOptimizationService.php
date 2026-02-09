<?php

declare(strict_types=1);

namespace App\Services\Performance;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Database\Schema\Blueprint;

/**
 * Database Optimization Service
 *
 * Handles database query optimization, index management,
 * and query analysis.
 */
class DatabaseOptimizationService
{
    private array $indexRecommendations = [];

    /**
     * Analyze query performance and suggest optimizations
     */
    public function analyzeQuery(string $query, array $bindings = []): array
    {
        $results = [
            'query' => $query,
            'execution_time' => 0,
            'rows_examined' => 0,
            'recommendations' => [],
        ];

        $start = microtime(true);

        try {
            $result = DB::select(DB::raw("EXPLAIN " . $query), $bindings);
            $results['explain'] = $result;
            $results['execution_time'] = (microtime(true) - $start) * 1000;

            // Analyze EXPLAIN output
            foreach ($result as $row) {
                $rowArray = (array)$row;

                // Check for full table scans
                if (isset($rowArray['type']) && $rowArray['type'] === 'ALL') {
                    $results['recommendations'][] = [
                        'type' => 'index_missing',
                        'message' => 'Full table scan detected. Consider adding an index.',
                        'table' => $rowArray['table'] ?? 'unknown',
                    ];
                }

                // Check for filesort
                if (isset($rowArray['Extra']) && str_contains($rowArray['Extra'], 'filesort')) {
                    $results['recommendations'][] = [
                        'type' => 'filesort',
                        'message' => 'Filesort detected. Consider adding an index on ORDER BY columns.',
                        'table' => $rowArray['table'] ?? 'unknown',
                    ];
                }

                // Check for temporary table
                if (isset($rowArray['Extra']) && str_contains($rowArray['Extra'], 'Using temporary')) {
                    $results['recommendations'][] = [
                        'type' => 'temporary_table',
                        'message' => 'Temporary table created. Consider optimizing GROUP BY or DISTINCT.',
                        'table' => $rowArray['table'] ?? 'unknown',
                    ];
                }

                $results['rows_examined'] += $rowArray['rows'] ?? 0;
            }
        } catch (\Exception $e) {
            $results['error'] = $e->getMessage();
        }

        return $results;
    }

    /**
     * Get recommended indexes for tables
     */
    public function recommendIndexes(string $table): array
    {
        if (!Schema::hasTable($table)) {
            return [];
        }

        $columns = Schema::getColumnListing($table);
        $recommendations = [];

        // Get foreign key columns
        $foreignKeys = $this->getForeignKeys($table);

        foreach ($foreignKeys as $column) {
            $recommendations[] = [
                'type' => 'foreign_key',
                'column' => $column,
                'reason' => 'Foreign key column',
                'priority' => 'high',
                'sql' => "CREATE INDEX idx_{$table}_{$column} ON {$table}({$column});",
            ];
        }

        // Check for commonly used columns in WHERE clauses
        $commonWhereColumns = ['status', 'type', 'severity', 'created_at', 'updated_at', 'active', 'is_resolved'];

        foreach ($commonWhereColumns as $column) {
            if (in_array($column, $columns)) {
                $recommendations[] = [
                    'type' => 'where_clause',
                    'column' => $column,
                    'reason' => 'Commonly used in WHERE clauses',
                    'priority' => 'medium',
                    'sql' => "CREATE INDEX idx_{$table}_{$column} ON {$table}({$column});",
                ];
            }
        }

        // Check for timestamp columns (often used for sorting)
        $timestampColumns = ['created_at', 'updated_at', 'resolved_at', 'acknowledged_at', 'last_executed_at'];

        foreach ($timestampColumns as $column) {
            if (in_array($column, $columns)) {
                $recommendations[] = [
                    'type' => 'sorting',
                    'column' => $column,
                    'reason' => 'Used for ORDER BY',
                    'priority' => 'medium',
                    'sql' => "CREATE INDEX idx_{$table}_{$column} ON {$table}({$column} DESC);",
                ];
            }
        }

        return $recommendations;
    }

    /**
     * Get foreign key columns for a table
     */
    protected function getForeignKeys(string $table): array
    {
        try {
            $keys = DB::select("
                SELECT COLUMN_NAME
                FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
                WHERE TABLE_SCHEMA = DATABASE()
                AND TABLE_NAME = ?
                AND REFERENCED_TABLE_NAME IS NOT NULL
            ", [$table]);

            return array_column($keys, 'COLUMN_NAME');
        } catch (\Exception $e) {
            return [];
        }
    }

    /**
     * Check for missing indexes on queries
     */
    public function findSlowQueries(): array
    {
        $slowQueries = [];

        // Check alerts table
        if (Schema::hasTable('alerts')) {
            $slowQueries['alerts'] = $this->analyzeQuery(
                "SELECT * FROM alerts WHERE status = ? AND resolved_at IS NULL ORDER BY created_at DESC LIMIT 100",
                ['active']
            );
        }

        // Check users table
        if (Schema::hasTable('users')) {
            $slowQueries['users'] = $this->analyzeQuery(
                "SELECT * FROM users WHERE is_active = ? ORDER BY last_login_at DESC",
                [true]
            );
        }

        // Check n8n_workflows table
        if (Schema::hasTable('n8n_workflows')) {
            $slowQueries['n8n_workflows'] = $this->analyzeQuery(
                "SELECT * FROM n8n_workflows WHERE active = ? AND category = ? ORDER BY last_executed_at DESC",
                [true, 'automation']
            );
        }

        return $slowQueries;
    }

    /**
     * Optimize table
     */
    public function optimizeTable(string $table): array
    {
        try {
            DB::statement("OPTIMIZE TABLE {$table}");

            return [
                'success' => true,
                'message' => "Table {$table} optimized successfully",
            ];
        } catch (\Exception $e) {
            return [
                'success' => false,
                'error' => $e->getMessage(),
            ];
        }
    }

    /**
     * Analyze table for optimization opportunities
     */
    public function analyzeTable(string $table): array
    {
        if (!Schema::hasTable($table)) {
            return ['error' => 'Table does not exist'];
        }

        $columns = Schema::getColumnListing($table);
        $columnInfo = [];

        foreach ($columns as $column) {
            $type = DB::selectOne("
                SELECT DATA_TYPE, COLUMN_TYPE, IS_NULLABLE, COLUMN_KEY, EXTRA
                FROM INFORMATION_SCHEMA.COLUMNS
                WHERE TABLE_SCHEMA = DATABASE()
                AND TABLE_NAME = ?
                AND COLUMN_NAME = ?
            ", [$table, $column]);

            if ($type) {
                $columnInfo[$column] = [
                    'type' => $type->DATA_TYPE,
                    'full_type' => $type->COLUMN_TYPE,
                    'nullable' => $type->IS_NULLABLE === 'YES',
                    'key' => $type->COLUMN_KEY,
                    'extra' => $type->EXTRA,
                ];
            }
        }

        // Get table size
        $size = DB::selectOne("
            SELECT
                ROUND(((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024), 2) AS 'size_mb',
                TABLE_ROWS AS 'rows'
            FROM information_schema.TABLES
            WHERE TABLE_SCHEMA = DATABASE()
            AND TABLE_NAME = ?
        ", [$table]);

        return [
            'table' => $table,
            'size_mb' => $size->size_mb ?? 0,
            'rows' => $size->rows ?? 0,
            'columns' => $columnInfo,
            'indexes' => $this->getTableIndexes($table),
            'recommendations' => $this->recommendIndexes($table),
        ];
    }

    /**
     * Get indexes for a table
     */
    protected function getTableIndexes(string $table): array
    {
        try {
            $indexes = DB::select("
                SELECT
                    INDEX_NAME as 'name',
                    GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) as 'columns',
                    NON_UNIQUE as 'non_unique',
                    INDEX_TYPE as 'type'
                FROM INFORMATION_SCHEMA.STATISTICS
                WHERE TABLE_SCHEMA = DATABASE()
                AND TABLE_NAME = ?
                GROUP BY INDEX_NAME, NON_UNIQUE, INDEX_TYPE
            ", [$table]);

            return array_map(function ($index) {
                return [
                    'name' => $index->name,
                    'columns' => explode(',', $index->columns),
                    'unique' => $index->non_unique == 0,
                    'type' => $index->type,
                ];
            }, $indexes);
        } catch (\Exception $e) {
            return [];
        }
    }

    /**
     * Get all database metrics
     */
    public function getDatabaseMetrics(): array
    {
        return [
            'connection' => config('database.default'),
            'connections_count' => DB::select("SHOW STATUS LIKE 'Threads_connected'")[0]->Value ?? 0,
            'queries_per_second' => $this->getQueriesPerSecond(),
            'slow_queries' => DB::select("SHOW STATUS LIKE 'Slow_queries'")[0]->Value ?? 0,
            'table_stats' => $this->getAllTableStats(),
        ];
    }

    /**
     * Get queries per second
     */
    protected function getQueriesPerSecond(): float
    {
        try {
            $questions = DB::select("SHOW STATUS LIKE 'Questions'")[0]->Value ?? 0;
            $uptime = DB::select("SHOW STATUS LIKE 'Uptime'")[0]->Value ?? 1;

            return round($questions / $uptime, 2);
        } catch (\Exception $e) {
            return 0;
        }
    }

    /**
     * Get statistics for all tables
     */
    protected function getAllTableStats(): array
    {
        try {
            $tables = DB::select("
                SELECT
                    TABLE_NAME as 'name',
                    ROUND(((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024), 2) AS 'size_mb',
                    TABLE_ROWS AS 'rows',
                    ROUND((DATA_LENGTH / 1024 / 1024), 2) AS 'data_mb',
                    ROUND((INDEX_LENGTH / 1024 / 1024), 2) AS 'index_mb'
                FROM information_schema.TABLES
                WHERE TABLE_SCHEMA = DATABASE()
                AND TABLE_TYPE = 'BASE TABLE'
                ORDER BY (DATA_LENGTH + INDEX_LENGTH) DESC
            ");

            return array_map(fn($t) => (array)$t, $tables);
        } catch (\Exception $e) {
            return [];
        }
    }

    /**
     * Create composite index recommendation
     */
    public function recommendCompositeIndex(string $table, array $columns): array
    {
        $indexName = 'idx_' . $table . '_' . implode('_', $columns);

        return [
            'type' => 'composite',
            'table' => $table,
            'columns' => $columns,
            'name' => $indexName,
            'sql' => "CREATE INDEX {$indexName} ON {$table}(" . implode(', ', $columns) . ");",
            'priority' => 'high',
        ];
    }

    /**
     * Generate migration for recommended indexes
     */
    public function generateIndexMigration(string $table): string
    {
        $recommendations = $this->recommendIndexes($table);
        $upStatements = [];
        $downStatements = [];

        foreach ($recommendations as $rec) {
            if (isset($rec['sql'])) {
                $upStatements[] = $rec['sql'];

                // Generate DROP statement
                if (preg_match('/CREATE INDEX (\w+) ON/', $rec['sql'], $matches)) {
                    $indexName = $matches[1];
                    $downStatements[] = "DROP INDEX {$indexName} ON {$table};";
                }
            }
        }

        return sprintf(
            "// Up\n%s\n\n// Down\n%s",
            implode("\n", $upStatements),
            implode("\n", $downStatements)
        );
    }
}
