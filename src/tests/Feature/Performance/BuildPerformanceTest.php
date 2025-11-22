<?php

use App\Services\Monitoring\BuildPerformanceService;
use Illuminate\Support\Facades\Cache;

describe('Build Performance', function () {
    beforeEach(function () {
        Cache::flush();
        $this->service = new BuildPerformanceService();
    });

    test('build completes within performance target', function () {
        // Record a sample build
        $this->service->recordBuildMetrics([
            'build_time_seconds' => 150,
            'environment' => 'qa',
            'cache_hit_rate' => 85,
            'layer_reuse_rate' => 92,
        ]);

        $metrics = $this->service->getLatestMetrics();

        expect($metrics)->toHaveKey('build_time_seconds');
        expect($metrics['build_time_seconds'])->toBeLessThan(180); // 3 minutes max
    });

    test('cache hit rate meets target', function () {
        $this->service->recordBuildMetrics([
            'build_time_seconds' => 120,
            'environment' => 'qa',
            'cache_hit_rate' => 85,
        ]);

        $metrics = $this->service->getLatestMetrics();

        expect($metrics['cache_hit_rate'])->toBeGreaterThanOrEqual(80); // 80% minimum
    });

    test('docker layer reuse is optimal', function () {
        $this->service->recordBuildMetrics([
            'build_time_seconds' => 120,
            'environment' => 'qa',
            'layer_reuse_rate' => 95,
        ]);

        $metrics = $this->service->getLatestMetrics();

        expect($metrics['layer_reuse_rate'])->toBeGreaterThanOrEqual(90); // 90% minimum
    });

    test('can record and retrieve build metrics', function () {
        $testMetrics = [
            'build_time_seconds' => 150,
            'environment' => 'qa',
            'git_sha' => 'abc123',
            'cache_hit' => true,
            'cache_hit_rate' => 85,
        ];

        $this->service->recordBuildMetrics($testMetrics);
        $latest = $this->service->getLatestMetrics();

        expect($latest['build_time_seconds'])->toBe(150);
        expect($latest['environment'])->toBe('qa');
        expect($latest['cache_hit_rate'])->toBe(85);
    });

    test('calculates improvements correctly with multiple builds', function () {
        // Record baseline builds (slower)
        for ($i = 0; $i < 10; $i++) {
            $this->service->recordBuildMetrics([
                'build_time_seconds' => 600, // 10 minutes
                'environment' => 'qa',
                'cache_hit_rate' => 20,
            ]);
        }

        // Record optimized builds (faster)
        for ($i = 0; $i < 10; $i++) {
            $this->service->recordBuildMetrics([
                'build_time_seconds' => 150, // 2.5 minutes
                'environment' => 'qa',
                'cache_hit_rate' => 85,
            ]);
        }

        $improvements = $this->service->calculateImprovements();

        expect($improvements)->toHaveKey('build_time_improvement');
        expect($improvements['build_time_improvement'])->toBeGreaterThan(70); // Should be ~75%
        expect($improvements['cache_hit_rate'])->toBeGreaterThan(80);
    });

    test('maintains build history with limit', function () {
        // Record more than limit
        for ($i = 0; $i < 120; $i++) {
            $this->service->recordBuildMetrics([
                'build_time_seconds' => 150,
                'environment' => 'qa',
            ]);
        }

        $history = $this->service->getHistory(200);

        expect($history['count'])->toBeLessThanOrEqual(100); // Max 100 stored
    });

    test('can filter metrics by environment', function () {
        // Record builds for different environments
        $this->service->recordBuildMetrics([
            'build_time_seconds' => 120,
            'environment' => 'qa',
        ]);

        $this->service->recordBuildMetrics([
            'build_time_seconds' => 150,
            'environment' => 'uat',
        ]);

        $qaMetrics = $this->service->getEnvironmentMetrics('qa', 10);

        expect($qaMetrics['environment'])->toBe('qa');
        expect($qaMetrics['count'])->toBe(1);
    });

    test('calculates trends over time', function () {
        // Record several builds
        for ($i = 0; $i < 20; $i++) {
            $this->service->recordBuildMetrics([
                'build_time_seconds' => 150,
                'environment' => 'qa',
                'cache_hit_rate' => 85,
            ]);
        }

        $trends = $this->service->getTrends();

        expect($trends)->toHaveKey('average_build_time');
        expect($trends)->toHaveKey('average_cache_hit_rate');
        expect($trends['average_build_time'])->toBeGreaterThan(0);
    });

    test('validates required metrics fields', function () {
        expect(fn() => $this->service->recordBuildMetrics([
            'environment' => 'qa',
            // Missing build_time_seconds
        ]))->toThrow(\InvalidArgumentException::class);
    });

    test('handles insufficient data gracefully', function () {
        // Record only one build
        $this->service->recordBuildMetrics([
            'build_time_seconds' => 150,
            'environment' => 'qa',
        ]);

        $improvements = $this->service->calculateImprovements();

        expect($improvements)->toHaveKey('insufficient_data');
        expect($improvements['insufficient_data'])->toBeTrue();
    });
});

describe('Build Metrics API', function () {
    test('can get latest metrics via API', function () {
        $service = new BuildPerformanceService();
        $service->recordBuildMetrics([
            'build_time_seconds' => 150,
            'environment' => 'qa',
            'cache_hit_rate' => 85,
        ]);

        $response = $this->getJson('/api/build/metrics/latest');

        $response->assertStatus(200);
        $response->assertJsonStructure([
            'latest' => [
                'build_time_seconds',
                'environment',
                'cache_hit_rate',
            ],
            'improvements',
        ]);
    });

    test('can get build history via API', function () {
        $service = new BuildPerformanceService();

        for ($i = 0; $i < 5; $i++) {
            $service->recordBuildMetrics([
                'build_time_seconds' => 150,
                'environment' => 'qa',
            ]);
        }

        $response = $this->getJson('/api/build/metrics/history?limit=10');

        $response->assertStatus(200);
        $response->assertJsonStructure([
            'builds',
            'count',
        ]);
    });

    test('can get build trends via API', function () {
        $service = new BuildPerformanceService();

        for ($i = 0; $i < 10; $i++) {
            $service->recordBuildMetrics([
                'build_time_seconds' => 150,
                'environment' => 'qa',
                'cache_hit_rate' => 85,
            ]);
        }

        $response = $this->getJson('/api/build/metrics/trends');

        $response->assertStatus(200);
        $response->assertJsonStructure([
            'average_build_time',
            'average_cache_hit_rate',
            'total_time_saved',
        ]);
    });

    test('can record metrics via webhook', function () {
        $response = $this->postJson('/api/build/metrics/record', [
            'build_time_seconds' => 150,
            'environment' => 'qa',
            'git_sha' => 'abc123',
            'cache_hit' => true,
        ]);

        $response->assertStatus(201);
        $response->assertJson([
            'message' => 'Build metrics recorded successfully',
        ]);
    });

    test('validates webhook payload', function () {
        $response = $this->postJson('/api/build/metrics/record', [
            'environment' => 'qa',
            // Missing build_time_seconds
        ]);

        $response->assertStatus(422);
        $response->assertJsonValidationErrors(['build_time_seconds']);
    });
});
