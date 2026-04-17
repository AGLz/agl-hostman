<?php

namespace Tests;

use Illuminate\Contracts\Console\Kernel;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Redis;

/**
 * Base Test Case with Parallel Execution Support
 *
 * Phase 4.2: Parallel Test Execution
 *
 * Features:
 * - Database isolation per parallel process
 * - Automatic database creation and cleanup
 * - Transaction-based test isolation
 * - Redis cleanup between tests
 * - Process-aware test database naming
 *
 * @version 1.0.0
 */
abstract class TestCase extends BaseTestCase
{
    /**
     * Database connection name for this test process
     */
    protected static ?string $testDatabase = null;

    /**
     * Whether database transactions are enabled for this test
     */
    protected bool $useDatabaseTransactions = true;

    /**
     * Creates the application.
     *
     * @return \Illuminate\Foundation\Application
     */
    public function createApplication()
    {
        $app = require __DIR__.'/../bootstrap/app.php';

        $app->make(Kernel::class)->bootstrap();

        return $app;
    }

    /**
     * Nível de output buffering após parent::setUp() (para fechar buffers extra ao fim do teste).
     */
    protected int $outputBufferLevelAfterSetUp = 0;

    /**
     * Setup the test environment before each test.
     *
     * This method is called before each test method and sets up:
     * - Unique test database for parallel process isolation
     * - Database transactions for test isolation
     * - Redis cleanup
     */
    protected function setUp(): void
    {
        parent::setUp();

        $this->outputBufferLevelAfterSetUp = ob_get_level();

        // Setup parallel test database if enabled
        if ($this->shouldUseParallelDatabase()) {
            $this->setupParallelDatabase();
        }

        // Transação manual só quando não há RefreshDatabase (esse trait define beginDatabaseTransaction)
        if ($this->useDatabaseTransactions && $this->shouldUseDatabase() && ! $this->usesRefreshDatabase()) {
            $this->beginLegacyManualDatabaseTransaction();
        }

        // Clear Redis test database
        if ($this->shouldUseRedis()) {
            $this->clearRedisTestData();
        }
    }

    /**
     * Clean up the testing environment after each test.
     */
    protected function tearDown(): void
    {
        if ($this->useDatabaseTransactions && $this->shouldUseDatabase() && ! $this->usesRefreshDatabase()) {
            $this->rollbackDatabaseTransaction();
        }

        // Clear Redis test data
        if ($this->shouldUseRedis()) {
            $this->clearRedisTestData();
        }

        parent::tearDown();

        while (ob_get_level() > $this->outputBufferLevelAfterSetUp) {
            ob_end_clean();
        }
    }

    /**
     * Setup parallel database for this test process.
     *
     * Creates a unique database for each parallel process to avoid conflicts.
     * Database naming pattern: agl_hostman_test_p{process_id}
     */
    protected function setupParallelDatabase(): void
    {
        // Get unique database name for this parallel process
        $processId = $this->getParallelProcessId();
        $testDbName = $this->getTestDatabaseName($processId);

        // Store for later use
        static::$testDatabase = $testDbName;

        // Create test database if it doesn't exist
        $this->createTestDatabaseIfNotExists($testDbName);

        // Update database configuration for this test
        config(['database.connections.pgsql.database' => $testDbName]);
        config(['database.connections.testing.database' => $testDbName]);

        // Reconnect to the test database
        DB::purge('pgsql');
        DB::reconnect('pgsql');

        // Run migrations if needed (only once per process)
        if (! $this->databaseMigrationsRan($testDbName)) {
            $this->runDatabaseMigrations($testDbName);
        }
    }

    /**
     * Get the parallel process ID.
     *
     * Pest PHP sets TEST_TOKEN environment variable for each parallel process.
     * Format: process_id or unique_hash
     *
     * @return string Process ID (defaults to '1' for sequential execution)
     */
    protected function getParallelProcessId(): string
    {
        // Check for Pest parallel test token
        $testToken = getenv('TEST_TOKEN');

        if ($testToken !== false && $testToken !== '') {
            // Extract numeric ID from token (e.g., "1", "2", "3")
            if (is_numeric($testToken)) {
                return (string) $testToken;
            }

            // Hash-based token: use hash modulo to get process ID
            return (string) (crc32($testToken) % 8 + 1);
        }

        // Check for ParaTest token
        $paraTestToken = getenv('PARATEST');
        if ($paraTestToken !== false && $paraTestToken !== '') {
            return (string) $paraTestToken;
        }

        // Default to process 1 for sequential execution
        return '1';
    }

    /**
     * Get the test database name for a given process ID.
     *
     * @param  string  $processId  Process identifier
     * @return string Database name
     */
    protected function getTestDatabaseName(string $processId): string
    {
        $baseDbName = config('database.connections.pgsql.database', 'agl_hostman_test');

        // Remove any existing _p suffix
        $baseDbName = preg_replace('/_p\d+$/', '', $baseDbName);

        return "{$baseDbName}_p{$processId}";
    }

    /**
     * Create test database if it doesn't exist.
     *
     * @param  string  $dbName  Database name to create
     */
    protected function createTestDatabaseIfNotExists(string $dbName): void
    {
        try {
            // Connect to postgres database to create test database
            $connection = config('database.connections.pgsql');
            $masterDbConnection = [
                'host' => $connection['host'],
                'port' => $connection['port'],
                'database' => 'postgres',
                'username' => $connection['username'],
                'password' => $connection['password'],
            ];

            $pdo = new \PDO(
                sprintf(
                    'pgsql:host=%s;port=%s;dbname=%s',
                    $masterDbConnection['host'],
                    $masterDbConnection['port'],
                    $masterDbConnection['database']
                ),
                $masterDbConnection['username'],
                $masterDbConnection['password']
            );

            // Check if database exists
            $stmt = $pdo->query(
                "SELECT 1 FROM pg_database WHERE datname = '{$dbName}'"
            );

            if (! $stmt || $stmt->fetchColumn() === false) {
                // Create database
                $pdo->exec("CREATE DATABASE {$dbName}");
            }
        } catch (\PDOException $e) {
            // Database might already exist or creation failed
            // This is acceptable in parallel testing - another process may have created it
        }
    }

    /**
     * Check if database migrations have been run for this database.
     *
     * @param  string  $dbName  Database name
     * @return bool True if migrations have been run
     */
    protected function databaseMigrationsRan(string $dbName): bool
    {
        try {
            // Check if migrations table exists
            $exists = DB::select(
                "SELECT EXISTS (
                    SELECT FROM information_schema.tables
                    WHERE table_schema = 'public'
                    AND table_name = 'migrations'
                )"
            );

            return $exists[0]->exists ?? false;
        } catch (\Exception $e) {
            return false;
        }
    }

    /**
     * Run database migrations for test database.
     *
     * @param  string  $dbName  Database name
     */
    protected function runDatabaseMigrations(string $dbName): void
    {
        // Use Laravel's migration system
        $this->artisan('migrate', [
            '--database' => 'pgsql',
            '--force' => true,
        ]);
    }

    /**
     * Transação simples para testes sem o trait RefreshDatabase.
     * Não usar o nome beginDatabaseTransaction — o trait RefreshDatabase precisa desse método.
     */
    protected function beginLegacyManualDatabaseTransaction(): void
    {
        try {
            $connection = $this->shouldUseDatabase() ? DB::connection(config('database.default')) : null;
            if ($connection) {
                $connection->beginTransaction();
            }
        } catch (\Exception $e) {
            // Transaction already started or connection issue
        }
    }

    protected function usesRefreshDatabase(): bool
    {
        return in_array(RefreshDatabase::class, class_uses_recursive(static::class), true);
    }

    /**
     * Rollback the database transaction.
     */
    protected function rollbackDatabaseTransaction(): void
    {
        try {
            if (DB::connection('pgsql')->transactionLevel() > 0) {
                DB::connection('pgsql')->rollBack();
            }
        } catch (\Exception $e) {
            // Transaction already rolled back or connection closed
        }
    }

    /**
     * Clear Redis test data.
     *
     * Flushes the test Redis database (DB 1) to ensure clean state.
     */
    protected function clearRedisTestData(): void
    {
        try {
            // Use test Redis database (DB 1)
            Redis::connection('default')->select(1);
            Redis::connection('default')->flushDb();
        } catch (\Exception $e) {
            // Redis not available or already clean
        }
    }

    /**
     * Determine if this test should use parallel database.
     *
     * @return bool True if parallel database isolation should be used
     */
    protected function shouldUseParallelDatabase(): bool
    {
        return env('PARALLEL_TESTS', false) === true
            && config('database.default') === 'pgsql';
    }

    /**
     * Determine if this test should use database.
     *
     * @return bool True if database should be used
     */
    protected function shouldUseDatabase(): bool
    {
        $traits = class_uses_recursive(static::class);

        return in_array(RefreshDatabase::class, $traits, true)
            || config('database.default') !== 'array';
    }

    /**
     * Determine if this test should use Redis.
     *
     * @return bool True if Redis should be used
     */
    protected function shouldUseRedis(): bool
    {
        return config('cache.default') === 'redis'
            || config('queue.default') === 'redis';
    }

    /**
     * Disable database transactions for this test.
     *
     * Useful for tests that need to test actual database commits.
     */
    protected function disableDatabaseTransactions(): void
    {
        $this->useDatabaseTransactions = false;
    }

    /**
     * Get the current test database name.
     *
     * @return string|null Current test database name
     */
    protected function getTestDatabase(): ?string
    {
        return static::$testDatabase;
    }

    /**
     * Truncate a specific database table.
     *
     * Useful when you need to clean a table without rolling back the entire transaction.
     *
     * @param  string  $table  Table name to truncate
     */
    protected function truncateTable(string $table): void
    {
        if ($this->shouldUseDatabase()) {
            DB::table($table)->truncate();
        }
    }

    /**
     * Truncate multiple database tables.
     *
     * @param  array  $tables  Array of table names
     */
    protected function truncateTables(array $tables): void
    {
        foreach ($tables as $table) {
            $this->truncateTable($table);
        }
    }
}
