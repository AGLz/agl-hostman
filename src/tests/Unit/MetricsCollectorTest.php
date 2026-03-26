<?php

declare(strict_types=1);

use App\Models\LxcContainer;
use App\Models\ProxmoxServer;
use App\Services\MetricsCollector;
use App\Services\ProxmoxApiClient;
use Illuminate\Support\Facades\Cache;

beforeEach(function () {
    $this->apiClient = Mockery::mock(ProxmoxApiClient::class);
    $this->collector = new MetricsCollector($this->apiClient);

    // Clear cache before each test
    Cache::flush();
});

afterEach(function () {
    Mockery::close();
});

describe('MetricsCollector - Server Metrics', function () {
    test('collectServerMetrics returns server metrics successfully', function () {
        // Create mock server
        $server = ProxmoxServer::factory()->create([
            'code' => 'aglsrv1',
            'ip_address' => '192.168.0.245',
            'status' => 'online',
        ]);

        // Mock API response
        $this->apiClient->shouldReceive('get')
            ->with("nodes/{$server->code}/status", Mockery::any())
            ->andReturn([
                'cpu' => 0.45,
                'cpuinfo' => ['cores' => 32],
                'memory' => ['used' => 34359738368, 'total' => 274877906944],
                'uptime' => 8640000,
                'loadavg' => ['0.80', '0.75', '0.70'],
            ]);

        $result = $this->collector->collectServerMetrics('aglsrv1');

        expect($result)->toBeArray()
            ->and($result['success'])->toBeTrue()
            ->and($result['server'])->toHaveKey('code', 'aglsrv1')
            ->and($result['metrics'])->toHaveKeys(['cpu', 'memory', 'load', 'uptime'])
            ->and($result['metrics']['cpu']['usage_percent'])->toBe(45.0)
            ->and($result['metrics']['cpu']['cores'])->toBe(32)
            ->and($result['metrics']['memory']['usage_percent'])->toBeGreaterThan(0)
            ->and($result['health_status'])->toBeIn(['healthy', 'warning', 'critical', 'offline']);
    });

    test('collectServerMetrics returns error when server not found', function () {
        $result = $this->collector->collectServerMetrics('invalid-server');

        expect($result)->toBeArray()
            ->and($result['success'])->toBeFalse()
            ->and($result['error'])->toContain('not found');
    });

    test('collectServerMetrics handles API errors gracefully', function () {
        $server = ProxmoxServer::factory()->create(['code' => 'aglsrv1']);

        $this->apiClient->shouldReceive('get')
            ->andThrow(new Exception('API connection failed'));

        $result = $this->collector->collectServerMetrics('aglsrv1');

        expect($result)->toBeArray()
            ->and($result['success'])->toBeFalse()
            ->and($result['error'])->toContain('Failed to collect');
    });

    test('collectServerMetrics uses cache when available', function () {
        $server = ProxmoxServer::factory()->create(['code' => 'aglsrv1']);

        $cachedData = [
            'success' => true,
            'server' => ['code' => 'aglsrv1'],
            'metrics' => ['cpu' => ['usage_percent' => 50]],
            'health_status' => 'healthy',
        ];

        Cache::put('metrics:server:aglsrv1', $cachedData, now()->addSeconds(10));

        // API should not be called
        $this->apiClient->shouldReceive('get')->never();

        $result = $this->collector->collectServerMetrics('aglsrv1');

        expect($result)->toBe($cachedData);
    });
});

describe('MetricsCollector - Container Metrics', function () {
    test('collectContainerMetrics returns container metrics successfully', function () {
        $server = ProxmoxServer::factory()->create([
            'code' => 'aglsrv1',
            'status' => 'online',
        ]);

        $containers = LxcContainer::factory()->count(3)->create([
            'proxmox_server_id' => $server->id,
            'status' => 'running',
        ]);

        $this->apiClient->shouldReceive('get')
            ->times(3)
            ->andReturn([
                'cpu' => 0.25,
                'mem' => 2147483648,
                'maxmem' => 4294967296,
                'disk' => 10737418240,
                'maxdisk' => 21474836480,
                'netin' => 1073741824,
                'netout' => 536870912,
                'uptime' => 3600,
            ]);

        $result = $this->collector->collectContainerMetrics((string) $server->id);

        expect($result)->toBeInstanceOf(\Illuminate\Support\Collection::class)
            ->and($result->count())->toBe(3)
            ->and($result->first())->toHaveKeys(['vmid', 'name', 'status', 'cpu_percent', 'memory_percent', 'disk_percent', 'health_status']);
    });

    test('collectContainerMetrics handles server not found', function () {
        $result = $this->collector->collectContainerMetrics('999999');

        expect($result)->toBeInstanceOf(\Illuminate\Support\Collection::class)
            ->and($result->isEmpty())->toBeTrue();
    });

    test('collectContainerMetrics skips offline servers', function () {
        $server = ProxmoxServer::factory()->create([
            'status' => 'offline',
        ]);

        $this->apiClient->shouldReceive('get')->never();

        $result = $this->collector->collectContainerMetrics((string) $server->id);

        expect($result->isEmpty())->toBeTrue();
    });

    test('collectContainerMetrics calculates health status correctly', function () {
        $server = ProxmoxServer::factory()->create(['status' => 'online']);
        $container = LxcContainer::factory()->create([
            'proxmox_server_id' => $server->id,
            'status' => 'running',
        ]);

        // High CPU usage (85%) - should be critical
        $this->apiClient->shouldReceive('get')
            ->andReturn([
                'cpu' => 0.85,
                'mem' => 3221225472,
                'maxmem' => 4294967296,
                'disk' => 10737418240,
                'maxdisk' => 21474836480,
                'netin' => 0,
                'netout' => 0,
                'uptime' => 3600,
            ]);

        $result = $this->collector->collectContainerMetrics((string) $server->id);

        expect($result->first()['health_status'])->toBe('critical');
    });
});

describe('MetricsCollector - Network Metrics', function () {
    test('collectNetworkMetrics returns WireGuard peer status', function () {
        // Mock wg show command output
        $this->apiClient->shouldReceive('exec')
            ->with('wg show wg0 dump')
            ->andReturn("wg0\t10.6.0.1\tlistening port\t51820\n10.6.0.5\tpeer1_pubkey\t0.0.0.0:51820\t10.6.0.5/32\t1000\t5000\t1000000\n10.6.0.12\tpeer2_pubkey\t0.0.0.0:51820\t10.6.0.12/32\t500\t3000\t500000\n");

        $result = $this->collector->collectNetworkMetrics();

        expect($result)->toBeArray()
            ->and($result['success'])->toBeTrue()
            ->and($result['peers'])->toBeArray()
            ->and($result['peers'])->toHaveCount(2)
            ->and($result['summary']['total_peers'])->toBe(2)
            ->and($result['summary']['connected_peers'])->toBeGreaterThanOrEqual(0)
            ->and($result['health_status'])->toBeIn(['healthy', 'warning', 'critical']);
    });

    test('collectNetworkMetrics handles no WireGuard interface', function () {
        $this->apiClient->shouldReceive('exec')
            ->andThrow(new Exception('WireGuard not configured'));

        $result = $this->collector->collectNetworkMetrics();

        expect($result)->toBeArray()
            ->and($result['success'])->toBeFalse()
            ->and($result['error'])->toContain('Failed to collect');
    });

    test('collectNetworkMetrics uses cache correctly', function () {
        $cachedData = [
            'success' => true,
            'peers' => [],
            'summary' => ['total_peers' => 0],
            'health_status' => 'healthy',
        ];

        Cache::put('metrics:network', $cachedData, now()->addSeconds(30));

        $this->apiClient->shouldReceive('exec')->never();

        $result = $this->collector->collectNetworkMetrics();

        expect($result)->toBe($cachedData);
    });
});

describe('MetricsCollector - Storage Metrics', function () {
    test('collectStorageMetrics returns NFS mount status', function () {
        $server = ProxmoxServer::factory()->create(['code' => 'aglsrv1', 'status' => 'online']);

        // Mock df output
        $this->apiClient->shouldReceive('exec')
            ->with('df -h | grep -E "wg|nfs"')
            ->andReturn("10.6.0.5:/mnt/fgsrv6  197G  150G  47G  76% /mnt/pve/fgsrv6-wg\n10.6.0.5:/export/ct111/shares  66G  50G  16G  75% /mnt/pve/ct111-shares\n");

        $result = $this->collector->collectStorageMetrics();

        expect($result)->toBeArray()
            ->and($result['success'])->toBeTrue()
            ->and($result['mounts'])->toBeArray()
            ->and($result['mounts'])->toHaveCount(2)
            ->and($result['summary']['total_mounts'])->toBe(2)
            ->and($result['summary']['avg_usage_percent'])->toBeGreaterThan(0)
            ->and($result['health_status'])->toBeIn(['healthy', 'warning', 'critical']);
    });

    test('collectStorageMetrics handles no NFS mounts', function () {
        $this->apiClient->shouldReceive('exec')
            ->andReturn('');

        $result = $this->collector->collectStorageMetrics();

        expect($result)->toBeArray()
            ->and($result['success'])->toBeTrue()
            ->and($result['mounts'])->toBeArray()
            ->and($result['mounts'])->toBeEmpty();
    });

    test('collectStorageMetrics uses cache correctly', function () {
        $cachedData = [
            'success' => true,
            'mounts' => [],
            'summary' => ['total_mounts' => 0],
            'health_status' => 'healthy',
        ];

        Cache::put('metrics:storage', $cachedData, now()->addSeconds(60));

        $this->apiClient->shouldReceive('exec')->never();

        $result = $this->collector->collectStorageMetrics();

        expect($result)->toBe($cachedData);
    });
});

describe('MetricsCollector - Aggregate Metrics', function () {
    test('aggregateAllMetrics returns complete infrastructure snapshot', function () {
        // Create test data
        $server = ProxmoxServer::factory()->create(['code' => 'aglsrv1', 'status' => 'online']);
        LxcContainer::factory()->count(5)->create([
            'proxmox_server_id' => $server->id,
            'status' => 'running',
        ]);

        // Mock API calls
        $this->apiClient->shouldReceive('get')->andReturn([
            'cpu' => 0.45,
            'cpuinfo' => ['cores' => 32],
            'memory' => ['used' => 34359738368, 'total' => 274877906944],
            'uptime' => 8640000,
            'loadavg' => ['0.80', '0.75', '0.70'],
        ]);

        $this->apiClient->shouldReceive('exec')->andReturn('');

        $result = $this->collector->aggregateAllMetrics();

        expect($result)->toBeArray()
            ->and($result)->toHaveKeys(['summary', 'servers', 'containers', 'network', 'storage', 'timestamp'])
            ->and($result['summary'])->toHaveKeys([
                'total_servers',
                'online_servers',
                'total_containers',
                'running_containers',
                'warning_containers',
                'critical_containers',
            ])
            ->and($result['timestamp'])->toBeString();
    });

    test('aggregateAllMetrics calculates summary statistics correctly', function () {
        $server1 = ProxmoxServer::factory()->create(['status' => 'online']);
        $server2 = ProxmoxServer::factory()->create(['status' => 'offline']);

        LxcContainer::factory()->count(3)->create([
            'proxmox_server_id' => $server1->id,
            'status' => 'running',
        ]);

        LxcContainer::factory()->count(2)->create([
            'proxmox_server_id' => $server1->id,
            'status' => 'stopped',
        ]);

        $this->apiClient->shouldReceive('get')->andReturn([
            'cpu' => 0.45,
            'cpuinfo' => ['cores' => 32],
            'memory' => ['used' => 34359738368, 'total' => 274877906944],
            'uptime' => 8640000,
            'loadavg' => ['0.80', '0.75', '0.70'],
        ]);

        $this->apiClient->shouldReceive('exec')->andReturn('');

        $result = $this->collector->aggregateAllMetrics();

        expect($result['summary']['total_servers'])->toBe(2)
            ->and($result['summary']['online_servers'])->toBe(1)
            ->and($result['summary']['total_containers'])->toBe(5)
            ->and($result['summary']['running_containers'])->toBe(3);
    });
});

describe('MetricsCollector - Health Status Calculations', function () {
    test('calculateServerHealthStatus returns critical for high CPU', function () {
        $metrics = [
            'cpu' => ['usage_percent' => 90, 'cores' => 32],
            'memory' => ['usage_percent' => 50],
            'load' => ['1min' => 10],
        ];

        $reflection = new ReflectionClass(MetricsCollector::class);
        $method = $reflection->getMethod('calculateServerHealthStatus');
        $method->setAccessible(true);

        $result = $method->invoke($this->collector, $metrics);

        expect($result)->toBe('critical');
    });

    test('calculateServerHealthStatus returns warning for medium CPU', function () {
        $metrics = [
            'cpu' => ['usage_percent' => 75, 'cores' => 32],
            'memory' => ['usage_percent' => 50],
            'load' => ['1min' => 10],
        ];

        $reflection = new ReflectionClass(MetricsCollector::class);
        $method = $reflection->getMethod('calculateServerHealthStatus');
        $method->setAccessible(true);

        $result = $method->invoke($this->collector, $metrics);

        expect($result)->toBe('warning');
    });

    test('calculateServerHealthStatus returns healthy for normal metrics', function () {
        $metrics = [
            'cpu' => ['usage_percent' => 45, 'cores' => 32],
            'memory' => ['usage_percent' => 50],
            'load' => ['1min' => 10],
        ];

        $reflection = new ReflectionClass(MetricsCollector::class);
        $method = $reflection->getMethod('calculateServerHealthStatus');
        $method->setAccessible(true);

        $result = $method->invoke($this->collector, $metrics);

        expect($result)->toBe('healthy');
    });

    test('calculateContainerHealthStatus returns critical for high memory', function () {
        $container = [
            'cpu_percent' => 50,
            'memory_percent' => 95,
            'disk_percent' => 50,
        ];

        $reflection = new ReflectionClass(MetricsCollector::class);
        $method = $reflection->getMethod('calculateContainerHealthStatus');
        $method->setAccessible(true);

        $result = $method->invoke($this->collector, $container);

        expect($result)->toBe('critical');
    });
});

describe('MetricsCollector - Cache Management', function () {
    test('refreshAllMetrics clears all metric caches', function () {
        // Set some cached data
        Cache::put('metrics:server:aglsrv1', ['test' => 'data'], now()->addMinutes(10));
        Cache::put('metrics:containers:1', ['test' => 'data'], now()->addMinutes(10));
        Cache::put('metrics:network', ['test' => 'data'], now()->addMinutes(10));
        Cache::put('metrics:storage', ['test' => 'data'], now()->addMinutes(10));

        expect(Cache::has('metrics:server:aglsrv1'))->toBeTrue();

        $this->collector->refreshAllMetrics();

        expect(Cache::has('metrics:server:aglsrv1'))->toBeFalse()
            ->and(Cache::has('metrics:containers:1'))->toBeFalse()
            ->and(Cache::has('metrics:network'))->toBeFalse()
            ->and(Cache::has('metrics:storage'))->toBeFalse();
    });

    test('metrics use correct cache TTL from config', function () {
        config(['monitoring.cache_ttl' => 10]);

        $server = ProxmoxServer::factory()->create(['code' => 'aglsrv1', 'status' => 'online']);

        $this->apiClient->shouldReceive('get')
            ->once()
            ->andReturn([
                'cpu' => 0.45,
                'cpuinfo' => ['cores' => 32],
                'memory' => ['used' => 34359738368, 'total' => 274877906944],
                'uptime' => 8640000,
                'loadavg' => ['0.80', '0.75', '0.70'],
            ]);

        // First call - should hit API
        $result1 = $this->collector->collectServerMetrics('aglsrv1');

        // Second call - should use cache (API should not be called again)
        $result2 = $this->collector->collectServerMetrics('aglsrv1');

        expect($result1)->toBe($result2);
    });
});
