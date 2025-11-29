<?php

declare(strict_types=1);

/**
 * Parallel Test Groups Configuration
 *
 * Phase 4.2: Parallel Test Execution
 *
 * This file defines optimal test grouping for parallel execution:
 * - Group 1: Unit tests (fast, isolated, no database)
 * - Group 2: Feature tests (medium, some database operations)
 * - Group 3: Integration tests (slow, full stack with database)
 *
 * Performance Targets:
 * - Sequential baseline: ~45s for 219 tests
 * - Parallel optimized: ~18s (60% reduction)
 * - Process distribution: Auto-detect CPU cores
 *
 * @package Tests
 * @version 1.0.0
 */

return [
    /**
     * Group 1: Unit Tests (Fast Execution)
     *
     * Characteristics:
     * - No database access
     * - Pure logic testing
     * - Mocked dependencies
     * - ~30 tests, ~5-8 seconds
     */
    'unit' => [
        'name' => 'Unit Tests',
        'description' => 'Fast, isolated unit tests with no database',
        'estimated_time_seconds' => 8,
        'process_count' => 'auto', // Auto-detect CPU cores
        'database_required' => false,
        'external_services' => false,

        'test_paths' => [
            'tests/Unit',
            'tests/Helpers',
        ],

        'excludes' => [],

        'environment' => [
            'DB_CONNECTION' => 'sqlite',
            'DB_DATABASE' => ':memory:',
            'CACHE_DRIVER' => 'array',
            'QUEUE_CONNECTION' => 'sync',
        ],

        'coverage_threshold' => 90, // Higher threshold for unit tests
    ],

    /**
     * Group 2: Feature Tests (Medium Execution)
     *
     * Characteristics:
     * - Some database operations
     * - HTTP testing
     * - Mocked external services
     * - ~120 tests, ~15-20 seconds
     */
    'feature' => [
        'name' => 'Feature Tests',
        'description' => 'HTTP and feature tests with database transactions',
        'estimated_time_seconds' => 18,
        'process_count' => 'auto',
        'database_required' => true,
        'external_services' => false, // Mocked

        'test_paths' => [
            'tests/Feature',
        ],

        'excludes' => [
            'tests/Feature/Database', // Heavy database tests in integration group
        ],

        'environment' => [
            'DB_CONNECTION' => 'pgsql',
            'DB_DATABASE' => 'agl_hostman_test', // Will be suffixed with process ID
            'USE_DATABASE_TRANSACTIONS' => true,
            'CACHE_DRIVER' => 'redis',
            'REDIS_DB' => 1, // Separate Redis DB for tests
        ],

        'coverage_threshold' => 85,

        // Test isolation strategy
        'isolation' => [
            'database_transactions' => true,
            'unique_database_per_process' => true,
            'cleanup_after_each_test' => true,
        ],
    ],

    /**
     * Group 3: Integration Tests (Slow Execution)
     *
     * Characteristics:
     * - Full stack testing
     * - Database migrations and seeds
     * - External service integration (mocked)
     * - ~69 tests, ~18-22 seconds
     */
    'integration' => [
        'name' => 'Integration Tests',
        'description' => 'Full stack integration tests with database',
        'estimated_time_seconds' => 20,
        'process_count' => 'auto',
        'database_required' => true,
        'external_services' => true, // Mocked but tested

        'test_paths' => [
            'tests/Integration',
            'tests/Feature/Database',
            'tests/Database',
        ],

        'excludes' => [],

        'environment' => [
            'DB_CONNECTION' => 'pgsql',
            'DB_DATABASE' => 'agl_hostman_test', // Will be suffixed with process ID
            'USE_DATABASE_TRANSACTIONS' => true,
            'CACHE_DRIVER' => 'redis',
            'QUEUE_CONNECTION' => 'database',
            'PROXMOX_MOCK_MODE' => true, // Mock Proxmox API
            'DOCKER_MOCK_MODE' => true,  // Mock Docker API
        ],

        'coverage_threshold' => 80,

        'isolation' => [
            'database_transactions' => true,
            'unique_database_per_process' => true,
            'cleanup_after_each_test' => true,
            'reset_redis_between_tests' => true,
        ],

        // Database setup for integration tests
        'database_setup' => [
            'run_migrations' => true,
            'seed_database' => false, // Use factories instead
            'cleanup_strategy' => 'truncate', // Faster than drop/create
        ],
    ],

    /**
     * Group 4: Architecture Tests (Fast Execution)
     *
     * Characteristics:
     * - Static analysis tests
     * - No database or runtime
     * - Code structure validation
     * - ~15 tests, ~3-5 seconds
     */
    'architecture' => [
        'name' => 'Architecture Tests',
        'description' => 'Static analysis and architecture validation',
        'estimated_time_seconds' => 4,
        'process_count' => 1, // Single process sufficient
        'database_required' => false,
        'external_services' => false,

        'test_paths' => [
            'tests/Architecture',
        ],

        'excludes' => [],

        'environment' => [
            'DB_CONNECTION' => 'sqlite',
            'DB_DATABASE' => ':memory:',
        ],

        'coverage_threshold' => 95, // Architecture tests should be comprehensive
    ],

    /**
     * Group 5: Performance Tests (Variable Execution)
     *
     * Characteristics:
     * - Benchmarking tests
     * - Load testing
     * - Memory profiling
     * - ~10 tests, ~8-12 seconds
     */
    'performance' => [
        'name' => 'Performance Tests',
        'description' => 'Benchmarking and performance validation',
        'estimated_time_seconds' => 10,
        'process_count' => 2, // Limited parallelism for accurate benchmarks
        'database_required' => true,
        'external_services' => false,

        'test_paths' => [
            'tests/Performance',
        ],

        'excludes' => [],

        'environment' => [
            'DB_CONNECTION' => 'pgsql',
            'DB_DATABASE' => 'agl_hostman_test',
            'BENCHMARK_MODE' => true,
            'PERFORMANCE_LOGGING' => true,
        ],

        'coverage_threshold' => 70, // Lower threshold for perf tests

        'benchmarking' => [
            'warmup_iterations' => 3,
            'measurement_iterations' => 10,
            'acceptable_variance_percent' => 15,
        ],
    ],

    /**
     * Global Parallel Execution Settings
     */
    'parallel_settings' => [
        // Process count calculation
        'process_count_strategy' => 'auto', // 'auto', 'fixed', or 'cpu_based'
        'max_processes' => 8, // Cap at 8 processes even on high-core systems
        'min_processes' => 2, // Minimum 2 processes for parallelization benefit

        // Process calculation formula
        'cpu_multiplier' => 1.0, // processes = cpu_cores * multiplier

        // Memory management
        'memory_limit_per_process_mb' => 512,
        'total_memory_limit_mb' => 4096,

        // Test distribution
        'distribution_strategy' => 'balanced', // 'balanced', 'time_based', or 'count_based'
        'rerun_failed_tests' => true,
        'max_rerun_attempts' => 2,

        // Database isolation
        'database_naming_pattern' => 'agl_hostman_test_p{process_id}',
        'database_cleanup_strategy' => 'transaction_rollback', // 'transaction_rollback' or 'truncate'

        // Output and logging
        'collect_coverage_per_process' => true,
        'merge_coverage_reports' => true,
        'verbose_output' => false,
        'show_process_assignment' => true,
    ],

    /**
     * Test Timing Metadata (for optimal distribution)
     *
     * Updated automatically by running:
     * ./scripts/measure-test-performance.sh --update-timings
     */
    'test_timings' => [
        // Format: 'TestClass::testMethod' => execution_time_ms
        // This will be populated after running performance measurements
        // Used for intelligent test distribution across processes
    ],

    /**
     * CI/CD Specific Configuration
     */
    'ci_configuration' => [
        'github_actions' => [
            'enabled' => true,
            'matrix_strategy' => 'group_based', // Run each group as separate job
            'fail_fast' => false, // Complete all groups even if one fails
            'collect_artifacts' => true,
            'artifact_retention_days' => 30,
        ],

        'gitlab_ci' => [
            'enabled' => false,
            'parallel_jobs' => 5,
        ],

        'jenkins' => [
            'enabled' => false,
            'parallel_stages' => true,
        ],
    ],

    /**
     * Test Dependencies and Ordering
     *
     * Define tests that must run in specific order or have dependencies
     */
    'test_dependencies' => [
        // Example: Database migration tests must run before seeder tests
        // 'Tests\Integration\DatabaseMigrationTest' => [],
        // 'Tests\Integration\DatabaseSeederTest' => ['Tests\Integration\DatabaseMigrationTest'],
    ],

    /**
     * Execution Strategy by Environment
     */
    'environment_strategies' => [
        'local_development' => [
            'process_count' => 'auto',
            'verbose_output' => true,
            'code_coverage' => true,
        ],

        'continuous_integration' => [
            'process_count' => 'fixed:3', // Match GitHub Actions matrix
            'verbose_output' => true,
            'code_coverage' => true,
            'fail_fast' => false,
        ],

        'pre_commit_hook' => [
            'process_count' => 'auto',
            'verbose_output' => false,
            'code_coverage' => false, // Skip coverage for speed
            'groups' => ['unit', 'feature'], // Skip integration tests
        ],
    ],
];
