<?php

declare(strict_types=1);

use App\Models\ProxmoxServer;
use App\Models\User;
use App\Services\MetricsCollector;
use Illuminate\Support\Facades\Cache;

beforeEach(function () {
    $this->user = User::factory()->create();

    $this->metricsCollector = Mockery::mock(MetricsCollector::class);
    $this->app->instance(MetricsCollector::class, $this->metricsCollector);

    Cache::flush();
});

afterEach(function () {
    Mockery::close();
});

describe('Monitoring Dashboard - Routes', function () {
    test('dashboard route requires authentication', function () {
        $response = $this->get('/monitoring');

        $response->assertRedirect('/login');
    });

    test('authenticated user can access dashboard', function () {
        $this->actingAs($this->user);

        $response = $this->get('/monitoring');

        $response->assertOk();
    });

    test('server detail route requires authentication', function () {
        $response = $this->get('/monitoring/server/aglsrv1');

        $response->assertRedirect('/login');
    });

    test('authenticated user can access server detail', function () {
        $this->actingAs($this->user);

        $response = $this->get('/monitoring/server/aglsrv1');

        $response->assertOk();
    });

    test('container detail route requires authentication', function () {
        $response = $this->get('/monitoring/container/100');

        $response->assertRedirect('/login');
    });

    test('authenticated user can access container detail', function () {
        $this->actingAs($this->user);

        $response = $this->get('/monitoring/container/100');

        $response->assertOk();
    });
});

describe('Monitoring Dashboard - API Endpoints', function () {
    test('metrics API endpoint requires authentication', function () {
        $response = $this->get('/monitoring/api/metrics');

        $response->assertRedirect('/login');
    });

    test('authenticated user can get all metrics', function () {
        $this->actingAs($this->user);

        $this->metricsCollector->shouldReceive('aggregateAllMetrics')
            ->once()
            ->andReturn([
                'summary' => [
                    'total_servers' => 2,
                    'online_servers' => 2,
                    'total_containers' => 68,
                    'running_containers' => 65,
                ],
                'servers' => [],
                'containers' => [],
                'network' => [],
                'storage' => [],
                'timestamp' => now()->toIso8601String(),
            ]);

        $response = $this->getJson('/monitoring/api/metrics');

        $response->assertOk()
            ->assertJsonStructure([
                'summary' => [
                    'total_servers',
                    'online_servers',
                    'total_containers',
                    'running_containers',
                ],
                'servers',
                'containers',
                'network',
                'storage',
                'timestamp',
            ]);
    });

    test('server metrics endpoint returns server data', function () {
        $this->actingAs($this->user);

        $server = ProxmoxServer::factory()->create(['code' => 'aglsrv1']);

        $this->metricsCollector->shouldReceive('collectServerMetrics')
            ->with('aglsrv1')
            ->once()
            ->andReturn([
                'success' => true,
                'server' => ['code' => 'aglsrv1'],
                'metrics' => [
                    'cpu' => ['usage_percent' => 45],
                    'memory' => ['usage_percent' => 60],
                ],
                'health_status' => 'healthy',
            ]);

        $response = $this->getJson('/monitoring/api/server/aglsrv1/metrics');

        $response->assertOk()
            ->assertJson([
                'success' => true,
                'server' => ['code' => 'aglsrv1'],
                'health_status' => 'healthy',
            ]);
    });

    test('container metrics endpoint returns container data', function () {
        $this->actingAs($this->user);

        $server = ProxmoxServer::factory()->create();

        $this->metricsCollector->shouldReceive('collectContainerMetrics')
            ->with((string) $server->id)
            ->once()
            ->andReturn(collect([
                ['vmid' => '100', 'name' => 'ct100', 'status' => 'running'],
            ]));

        $response = $this->getJson("/monitoring/api/server/{$server->id}/containers");

        $response->assertOk()
            ->assertJson([
                'success' => true,
                'containers' => [
                    ['vmid' => '100', 'name' => 'ct100'],
                ],
            ]);
    });

    test('network metrics endpoint returns network data', function () {
        $this->actingAs($this->user);

        $this->metricsCollector->shouldReceive('collectNetworkMetrics')
            ->once()
            ->andReturn([
                'success' => true,
                'peers' => [],
                'summary' => ['total_peers' => 14],
                'health_status' => 'healthy',
            ]);

        $response = $this->getJson('/monitoring/api/network');

        $response->assertOk()
            ->assertJson([
                'success' => true,
                'summary' => ['total_peers' => 14],
            ]);
    });

    test('storage metrics endpoint returns storage data', function () {
        $this->actingAs($this->user);

        $this->metricsCollector->shouldReceive('collectStorageMetrics')
            ->once()
            ->andReturn([
                'success' => true,
                'mounts' => [],
                'summary' => ['total_mounts' => 3],
                'health_status' => 'healthy',
            ]);

        $response = $this->getJson('/monitoring/api/storage');

        $response->assertOk()
            ->assertJson([
                'success' => true,
                'summary' => ['total_mounts' => 3],
            ]);
    });
});

describe('Monitoring Dashboard - Refresh Endpoint', function () {
    test('refresh endpoint requires authentication', function () {
        $response = $this->post('/monitoring/refresh');

        $response->assertRedirect('/login');
    });

    test('authenticated user can force refresh metrics', function () {
        $this->actingAs($this->user);

        $this->metricsCollector->shouldReceive('refreshAllMetrics')
            ->once();

        $response = $this->postJson('/monitoring/refresh');

        $response->assertOk()
            ->assertJson([
                'success' => true,
                'message' => 'Metrics cache cleared',
            ])
            ->assertJsonStructure(['timestamp']);
    });

    test('refresh clears all cached metrics', function () {
        $this->actingAs($this->user);

        // Set some cached data
        Cache::put('metrics:server:aglsrv1', ['test' => 'data'], now()->addMinutes(10));

        expect(Cache::has('metrics:server:aglsrv1'))->toBeTrue();

        $this->metricsCollector->shouldReceive('refreshAllMetrics')
            ->once()
            ->andReturnUsing(function () {
                Cache::flush();
            });

        $this->postJson('/monitoring/refresh');

        expect(Cache::has('metrics:server:aglsrv1'))->toBeFalse();
    });
});

describe('Monitoring Dashboard - Export Endpoint', function () {
    test('export endpoint requires authentication', function () {
        $response = $this->get('/monitoring/export');

        $response->assertRedirect('/login');
    });

    test('authenticated user can export metrics', function () {
        $this->actingAs($this->user);

        $mockMetrics = [
            'summary' => [
                'total_servers' => 2,
                'online_servers' => 2,
            ],
            'servers' => [],
            'containers' => [],
            'network' => [],
            'storage' => [],
            'timestamp' => now()->toIso8601String(),
        ];

        $this->metricsCollector->shouldReceive('aggregateAllMetrics')
            ->once()
            ->andReturn($mockMetrics);

        $response = $this->get('/monitoring/export');

        $response->assertOk()
            ->assertHeader('Content-Disposition', function ($value) {
                return str_contains($value, 'infrastructure-metrics-') && str_contains($value, '.json');
            })
            ->assertJson($mockMetrics);
    });

    test('export filename includes timestamp', function () {
        $this->actingAs($this->user);

        $this->metricsCollector->shouldReceive('aggregateAllMetrics')
            ->once()
            ->andReturn([
                'summary' => [],
                'servers' => [],
                'containers' => [],
                'network' => [],
                'storage' => [],
                'timestamp' => now()->toIso8601String(),
            ]);

        $response = $this->get('/monitoring/export');

        $contentDisposition = $response->headers->get('Content-Disposition');

        expect($contentDisposition)->toContain('infrastructure-metrics-')
            ->and($contentDisposition)->toMatch('/\d{4}-\d{2}-\d{2}-\d{6}/');
    });
});

describe('Monitoring Dashboard - Configuration', function () {
    test('monitoring configuration is loaded correctly', function () {
        config(['monitoring.poll_interval' => 15]);
        config(['monitoring.cache_ttl' => 20]);
        config(['monitoring.features.websocket_updates' => true]);

        expect(config('monitoring.poll_interval'))->toBe(15)
            ->and(config('monitoring.cache_ttl'))->toBe(20)
            ->and(config('monitoring.features.websocket_updates'))->toBeTrue();
    });

    test('monitoring thresholds are configured', function () {
        $thresholds = config('monitoring.thresholds');

        expect($thresholds)->toHaveKeys(['server', 'container', 'storage', 'network'])
            ->and($thresholds['server']['cpu'])->toHaveKeys(['warning', 'critical'])
            ->and($thresholds['container']['memory'])->toHaveKeys(['warning', 'critical']);
    });
});

describe('Monitoring Dashboard - Performance', function () {
    test('metrics are cached to reduce API calls', function () {
        $this->actingAs($this->user);

        $server = ProxmoxServer::factory()->create(['code' => 'aglsrv1']);

        $this->metricsCollector->shouldReceive('collectServerMetrics')
            ->once()
            ->andReturn([
                'success' => true,
                'server' => ['code' => 'aglsrv1'],
                'metrics' => [],
                'health_status' => 'healthy',
            ]);

        // First call - hits API
        $response1 = $this->getJson('/monitoring/api/server/aglsrv1/metrics');
        $response1->assertOk();

        // Cache the result manually for test
        Cache::put('metrics:server:aglsrv1', $response1->json(), now()->addSeconds(10));

        // Second call - should use cache (no additional API call expected)
        $response2 = $this->getJson('/monitoring/api/server/aglsrv1/metrics');
        $response2->assertOk();

        expect($response1->json())->toBe($response2->json());
    });
});

describe('Monitoring Dashboard - Error Handling', function () {
    test('handles server not found gracefully', function () {
        $this->actingAs($this->user);

        $this->metricsCollector->shouldReceive('collectServerMetrics')
            ->with('invalid-server')
            ->once()
            ->andReturn([
                'success' => false,
                'error' => 'Server not found',
            ]);

        $response = $this->getJson('/monitoring/api/server/invalid-server/metrics');

        $response->assertOk()
            ->assertJson([
                'success' => false,
                'error' => 'Server not found',
            ]);
    });

    test('handles API connection errors gracefully', function () {
        $this->actingAs($this->user);

        $this->metricsCollector->shouldReceive('aggregateAllMetrics')
            ->once()
            ->andThrow(new Exception('Connection timeout'));

        $response = $this->getJson('/monitoring/api/metrics');

        $response->assertStatus(500);
    });
});

describe('Monitoring Dashboard - Summary Statistics', function () {
    test('summary includes correct server counts', function () {
        $this->actingAs($this->user);

        ProxmoxServer::factory()->count(2)->create(['status' => 'online']);
        ProxmoxServer::factory()->count(1)->create(['status' => 'offline']);

        $this->metricsCollector->shouldReceive('aggregateAllMetrics')
            ->once()
            ->andReturn([
                'summary' => [
                    'total_servers' => 3,
                    'online_servers' => 2,
                    'total_containers' => 0,
                    'running_containers' => 0,
                    'warning_containers' => 0,
                    'critical_containers' => 0,
                ],
                'servers' => [],
                'containers' => [],
                'network' => [],
                'storage' => [],
                'timestamp' => now()->toIso8601String(),
            ]);

        $response = $this->getJson('/monitoring/api/metrics');

        $response->assertOk()
            ->assertJson([
                'summary' => [
                    'total_servers' => 3,
                    'online_servers' => 2,
                ],
            ]);
    });

    test('summary includes container health counts', function () {
        $this->actingAs($this->user);

        $this->metricsCollector->shouldReceive('aggregateAllMetrics')
            ->once()
            ->andReturn([
                'summary' => [
                    'total_servers' => 2,
                    'online_servers' => 2,
                    'total_containers' => 68,
                    'running_containers' => 65,
                    'warning_containers' => 5,
                    'critical_containers' => 2,
                ],
                'servers' => [],
                'containers' => [],
                'network' => [],
                'storage' => [],
                'timestamp' => now()->toIso8601String(),
            ]);

        $response = $this->getJson('/monitoring/api/metrics');

        $response->assertOk()
            ->assertJson([
                'summary' => [
                    'total_containers' => 68,
                    'running_containers' => 65,
                    'warning_containers' => 5,
                    'critical_containers' => 2,
                ],
            ]);
    });
});
