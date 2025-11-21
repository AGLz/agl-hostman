<?php

declare(strict_types=1);

use App\Models\User;
use App\Models\LxcContainer;
use Illuminate\Support\Facades\Http;

describe('API Response Time Performance', function () {
    beforeEach(function () {
        $this->user = User::factory()->create();
        $this->token = $this->user->createToken('test')->plainTextToken;
        $this->threshold = (int) env('TEST_PERFORMANCE_THRESHOLD_MS', 200);
    });

    it('lists containers within performance threshold', function () {
        LxcContainer::factory()->count(50)->create();

        $executionTime = benchmark(function () {
            $this->withToken($this->token)
                ->getJson('/api/v1/infrastructure/containers')
                ->assertOk();
        });

        expect($executionTime)->toBeWithinResponseTime($this->threshold);
    })->group('performance');

    it('retrieves container details within threshold', function () {
        $container = LxcContainer::factory()->create(['vmid' => 100]);

        Http::fake([
            '*/nodes/*/lxc/100/status/current' => Http::response([
                'data' => containerMetrics(),
            ], 200),
        ]);

        $executionTime = benchmark(function () {
            $this->withToken($this->token)
                ->getJson('/api/v1/infrastructure/containers/100')
                ->assertOk();
        });

        expect($executionTime)->toBeWithinResponseTime($this->threshold);
    })->group('performance');

    it('handles pagination efficiently', function () {
        LxcContainer::factory()->count(100)->create();

        $executionTime = benchmark(function () {
            $this->withToken($this->token)
                ->getJson('/api/v1/infrastructure/containers?per_page=25&page=1')
                ->assertOk();
        });

        expect($executionTime)->toBeWithinResponseTime($this->threshold);
    })->group('performance');

    it('filters large datasets efficiently', function () {
        LxcContainer::factory()->count(100)->create(['status' => 'running']);
        LxcContainer::factory()->count(100)->create(['status' => 'stopped']);

        $executionTime = benchmark(function () {
            $this->withToken($this->token)
                ->getJson('/api/v1/infrastructure/containers?status=running')
                ->assertOk();
        });

        expect($executionTime)->toBeWithinResponseTime($this->threshold);
    })->group('performance');

    it('executes concurrent requests efficiently', function () {
        LxcContainer::factory()->count(10)->create();

        $startTime = microtime(true);

        // Simulate 10 concurrent requests
        $responses = [];
        for ($i = 0; $i < 10; $i++) {
            $responses[] = $this->withToken($this->token)
                ->getJson('/api/v1/infrastructure/containers')
                ->assertOk();
        }

        $totalTime = (microtime(true) - $startTime) * 1000;
        $avgTime = $totalTime / 10;

        expect($avgTime)->toBeWithinResponseTime($this->threshold * 1.5);
    })->group('performance', 'concurrent');
});

describe('Database Query Performance', function () {
    it('avoids N+1 queries when loading relationships', function () {
        LxcContainer::factory()->count(20)->create();

        $queryCount = 0;
        \DB::listen(function ($query) use (&$queryCount) {
            $queryCount++;
        });

        LxcContainer::with('server')->get();

        // Should be 2 queries: 1 for containers + 1 for servers
        expect($queryCount)->toBeLessThanOrEqual(3);
    })->group('performance', 'database');

    it('uses indexes for filtered queries', function () {
        LxcContainer::factory()->count(1000)->create();

        $executionTime = benchmark(function () {
            LxcContainer::where('status', 'running')->get();
        });

        expect($executionTime)->toBeWithinResponseTime(50);
    })->group('performance', 'database');

    it('chunks large result sets efficiently', function () {
        LxcContainer::factory()->count(5000)->create();

        $memoryBefore = memory_get_usage();

        LxcContainer::chunk(500, function ($containers) {
            // Process chunk
            expect($containers)->toHaveCount(500);
        });

        $memoryAfter = memory_get_usage();
        $memoryUsed = ($memoryAfter - $memoryBefore) / 1024 / 1024; // MB

        expect($memoryUsed)->toBeLessThan(50); // Less than 50MB
    })->group('performance', 'database', 'slow');
});

describe('Cache Performance', function () {
    it('improves response time with caching', function () {
        LxcContainer::factory()->count(100)->create();

        // First request (no cache)
        $timeWithoutCache = benchmark(function () {
            $this->withToken($this->user->createToken('test')->plainTextToken)
                ->getJson('/api/v1/infrastructure/containers')
                ->assertOk();
        });

        // Second request (with cache)
        $timeWithCache = benchmark(function () {
            $this->withToken($this->user->createToken('test')->plainTextToken)
                ->getJson('/api/v1/infrastructure/containers')
                ->assertOk();
        });

        // Cached response should be at least 2x faster
        expect($timeWithCache)->toBeLessThan($timeWithoutCache / 2);
    })->group('performance', 'cache');
});

describe('Memory Usage Performance', function () {
    it('stays within memory limits', function () {
        $memoryLimit = (int) env('TEST_MEMORY_LIMIT_MB', 128) * 1024 * 1024;

        LxcContainer::factory()->count(1000)->create();

        $memoryBefore = memory_get_usage(true);

        $this->withToken($this->user->createToken('test')->plainTextToken)
            ->getJson('/api/v1/infrastructure/containers')
            ->assertOk();

        $memoryAfter = memory_get_usage(true);
        $memoryUsed = $memoryAfter - $memoryBefore;

        expect($memoryUsed)->toBeLessThan($memoryLimit);
    })->group('performance', 'memory');
});
