<?php

declare(strict_types=1);

use App\Livewire\ServerHealthCard;
use App\Models\ProxmoxServer;
use App\Services\MetricsCollector;
use Livewire\Livewire;

beforeEach(function () {
    $this->metricsCollector = Mockery::mock(MetricsCollector::class);
    $this->app->instance(MetricsCollector::class, $this->metricsCollector);

    $this->server = ProxmoxServer::factory()->create([
        'code' => 'aglsrv1',
        'name' => 'AGLSRV1',
        'ip_address' => '192.168.0.245',
        'status' => 'online',
    ]);
});

afterEach(function () {
    Mockery::close();
});

describe('ServerHealthCard - Component Mounting', function () {
    test('component can be mounted with server code', function () {
        $this->metricsCollector->shouldReceive('collectServerMetrics')
            ->with('aglsrv1')
            ->andReturn([
                'success' => true,
                'server' => ['code' => 'aglsrv1', 'name' => 'AGLSRV1'],
                'metrics' => [
                    'cpu' => ['usage_percent' => 45, 'cores' => 32],
                    'memory' => ['usage_percent' => 50, 'used_gb' => 32, 'total_gb' => 256],
                    'load' => ['1min' => 8.5, '5min' => 7.2, '15min' => 6.8],
                    'uptime' => ['days' => 100, 'hours' => 2, 'minutes' => 30],
                ],
                'health_status' => 'healthy',
            ]);

        Livewire::test(ServerHealthCard::class, ['serverCode' => 'aglsrv1'])
            ->assertOk()
            ->assertSet('serverCode', 'aglsrv1')
            ->assertSet('showDetails', false);
    });

    test('component requires serverCode property', function () {
        expect(fn () => Livewire::test(ServerHealthCard::class))
            ->toThrow(Exception::class);
    });
});

describe('ServerHealthCard - Metrics Loading', function () {
    test('loadMetrics retrieves server metrics on mount', function () {
        $this->metricsCollector->shouldReceive('collectServerMetrics')
            ->with('aglsrv1')
            ->andReturn([
                'success' => true,
                'server' => ['code' => 'aglsrv1', 'name' => 'AGLSRV1'],
                'metrics' => [
                    'cpu' => ['usage_percent' => 45, 'cores' => 32],
                    'memory' => ['usage_percent' => 50, 'used_gb' => 32, 'total_gb' => 256],
                    'load' => ['1min' => 8.5, '5min' => 7.2, '15min' => 6.8],
                    'uptime' => ['days' => 100, 'hours' => 2, 'minutes' => 30],
                ],
                'health_status' => 'healthy',
            ]);

        Livewire::test(ServerHealthCard::class, ['serverCode' => 'aglsrv1'])
            ->assertSet('metrics.success', true)
            ->assertSet('metrics.health_status', 'healthy');
    });

    test('loadMetrics handles API errors gracefully', function () {
        $this->metricsCollector->shouldReceive('collectServerMetrics')
            ->with('aglsrv1')
            ->andReturn([
                'success' => false,
                'error' => 'Connection timeout',
            ]);

        Livewire::test(ServerHealthCard::class, ['serverCode' => 'aglsrv1'])
            ->assertSet('metrics.success', false)
            ->assertSet('metrics.error', 'Connection timeout');
    });

    test('loadMetrics can be called manually', function () {
        $this->metricsCollector->shouldReceive('collectServerMetrics')
            ->times(2)
            ->andReturn([
                'success' => true,
                'server' => ['code' => 'aglsrv1'],
                'metrics' => [
                    'cpu' => ['usage_percent' => 45, 'cores' => 32],
                    'memory' => ['usage_percent' => 50, 'used_gb' => 32, 'total_gb' => 256],
                    'load' => ['1min' => 8.5],
                    'uptime' => ['days' => 100],
                ],
                'health_status' => 'healthy',
            ]);

        Livewire::test(ServerHealthCard::class, ['serverCode' => 'aglsrv1'])
            ->call('loadMetrics')
            ->assertSet('metrics.success', true);
    });
});

describe('ServerHealthCard - Health Status Display', function () {
    test('getHealthBadgeColor returns green for healthy status', function () {
        $this->metricsCollector->shouldReceive('collectServerMetrics')
            ->andReturn([
                'success' => true,
                'server' => ['code' => 'aglsrv1'],
                'metrics' => [
                    'cpu' => ['usage_percent' => 45, 'cores' => 32],
                    'memory' => ['usage_percent' => 50, 'used_gb' => 32, 'total_gb' => 256],
                    'load' => ['1min' => 8.5],
                    'uptime' => ['days' => 100],
                ],
                'health_status' => 'healthy',
            ]);

        Livewire::test(ServerHealthCard::class, ['serverCode' => 'aglsrv1'])
            ->assertMethodReturnValue('getHealthBadgeColor', 'green');
    });

    test('getHealthBadgeColor returns yellow for warning status', function () {
        $this->metricsCollector->shouldReceive('collectServerMetrics')
            ->andReturn([
                'success' => true,
                'server' => ['code' => 'aglsrv1'],
                'metrics' => [
                    'cpu' => ['usage_percent' => 75, 'cores' => 32],
                    'memory' => ['usage_percent' => 85, 'used_gb' => 200, 'total_gb' => 256],
                    'load' => ['1min' => 25.0],
                    'uptime' => ['days' => 100],
                ],
                'health_status' => 'warning',
            ]);

        Livewire::test(ServerHealthCard::class, ['serverCode' => 'aglsrv1'])
            ->assertMethodReturnValue('getHealthBadgeColor', 'yellow');
    });

    test('getHealthBadgeColor returns red for critical status', function () {
        $this->metricsCollector->shouldReceive('collectServerMetrics')
            ->andReturn([
                'success' => true,
                'server' => ['code' => 'aglsrv1'],
                'metrics' => [
                    'cpu' => ['usage_percent' => 95, 'cores' => 32],
                    'memory' => ['usage_percent' => 95, 'used_gb' => 240, 'total_gb' => 256],
                    'load' => ['1min' => 45.0],
                    'uptime' => ['days' => 100],
                ],
                'health_status' => 'critical',
            ]);

        Livewire::test(ServerHealthCard::class, ['serverCode' => 'aglsrv1'])
            ->assertMethodReturnValue('getHealthBadgeColor', 'red');
    });

    test('getHealthBadgeColor returns gray for offline status', function () {
        $this->metricsCollector->shouldReceive('collectServerMetrics')
            ->andReturn([
                'success' => false,
                'error' => 'Server offline',
                'health_status' => 'offline',
            ]);

        Livewire::test(ServerHealthCard::class, ['serverCode' => 'aglsrv1'])
            ->assertMethodReturnValue('getHealthBadgeColor', 'gray');
    });
});

describe('ServerHealthCard - Details Toggle', function () {
    test('toggleDetails switches showDetails state', function () {
        $this->metricsCollector->shouldReceive('collectServerMetrics')
            ->andReturn([
                'success' => true,
                'server' => ['code' => 'aglsrv1'],
                'metrics' => [
                    'cpu' => ['usage_percent' => 45, 'cores' => 32],
                    'memory' => ['usage_percent' => 50, 'used_gb' => 32, 'total_gb' => 256],
                    'load' => ['1min' => 8.5],
                    'uptime' => ['days' => 100],
                ],
                'health_status' => 'healthy',
            ]);

        Livewire::test(ServerHealthCard::class, ['serverCode' => 'aglsrv1'])
            ->assertSet('showDetails', false)
            ->call('toggleDetails')
            ->assertSet('showDetails', true)
            ->call('toggleDetails')
            ->assertSet('showDetails', false);
    });
});

describe('ServerHealthCard - View Rendering', function () {
    test('renders server name and health status', function () {
        $this->metricsCollector->shouldReceive('collectServerMetrics')
            ->andReturn([
                'success' => true,
                'server' => ['code' => 'aglsrv1', 'name' => 'AGLSRV1'],
                'metrics' => [
                    'cpu' => ['usage_percent' => 45, 'cores' => 32],
                    'memory' => ['usage_percent' => 50, 'used_gb' => 32, 'total_gb' => 256],
                    'load' => ['1min' => 8.5, '5min' => 7.2, '15min' => 6.8],
                    'uptime' => ['days' => 100, 'hours' => 2, 'minutes' => 30],
                ],
                'health_status' => 'healthy',
            ]);

        Livewire::test(ServerHealthCard::class, ['serverCode' => 'aglsrv1'])
            ->assertSee('AGLSRV1')
            ->assertSee('healthy');
    });

    test('renders CPU metrics', function () {
        $this->metricsCollector->shouldReceive('collectServerMetrics')
            ->andReturn([
                'success' => true,
                'server' => ['code' => 'aglsrv1'],
                'metrics' => [
                    'cpu' => ['usage_percent' => 45.5, 'cores' => 32],
                    'memory' => ['usage_percent' => 50, 'used_gb' => 32, 'total_gb' => 256],
                    'load' => ['1min' => 8.5],
                    'uptime' => ['days' => 100],
                ],
                'health_status' => 'healthy',
            ]);

        Livewire::test(ServerHealthCard::class, ['serverCode' => 'aglsrv1'])
            ->assertSee('45.5')
            ->assertSee('32');
    });

    test('renders memory metrics', function () {
        $this->metricsCollector->shouldReceive('collectServerMetrics')
            ->andReturn([
                'success' => true,
                'server' => ['code' => 'aglsrv1'],
                'metrics' => [
                    'cpu' => ['usage_percent' => 45, 'cores' => 32],
                    'memory' => ['usage_percent' => 50.8, 'used_gb' => 130, 'total_gb' => 256],
                    'load' => ['1min' => 8.5],
                    'uptime' => ['days' => 100],
                ],
                'health_status' => 'healthy',
            ]);

        Livewire::test(ServerHealthCard::class, ['serverCode' => 'aglsrv1'])
            ->assertSee('50.8')
            ->assertSee('130')
            ->assertSee('256');
    });

    test('renders error state when metrics fail', function () {
        $this->metricsCollector->shouldReceive('collectServerMetrics')
            ->andReturn([
                'success' => false,
                'error' => 'Connection timeout',
            ]);

        Livewire::test(ServerHealthCard::class, ['serverCode' => 'aglsrv1'])
            ->assertSee('Connection timeout');
    });

    test('renders loading state initially', function () {
        $this->metricsCollector->shouldReceive('collectServerMetrics')
            ->andReturn([
                'success' => true,
                'server' => ['code' => 'aglsrv1'],
                'metrics' => [
                    'cpu' => ['usage_percent' => 45, 'cores' => 32],
                    'memory' => ['usage_percent' => 50, 'used_gb' => 32, 'total_gb' => 256],
                    'load' => ['1min' => 8.5],
                    'uptime' => ['days' => 100],
                ],
                'health_status' => 'healthy',
            ]);

        Livewire::test(ServerHealthCard::class, ['serverCode' => 'aglsrv1'])
            ->assertOk();
    });
});

describe('ServerHealthCard - Polling Configuration', function () {
    test('uses configured poll interval from config', function () {
        config(['monitoring.poll_interval' => 15]);

        $this->metricsCollector->shouldReceive('collectServerMetrics')
            ->andReturn([
                'success' => true,
                'server' => ['code' => 'aglsrv1'],
                'metrics' => [
                    'cpu' => ['usage_percent' => 45, 'cores' => 32],
                    'memory' => ['usage_percent' => 50, 'used_gb' => 32, 'total_gb' => 256],
                    'load' => ['1min' => 8.5],
                    'uptime' => ['days' => 100],
                ],
                'health_status' => 'healthy',
            ]);

        Livewire::test(ServerHealthCard::class, ['serverCode' => 'aglsrv1'])
            ->assertSee('15s');
    });
});

describe('ServerHealthCard - Progress Bar Calculations', function () {
    test('CPU progress bar shows correct percentage', function () {
        $this->metricsCollector->shouldReceive('collectServerMetrics')
            ->andReturn([
                'success' => true,
                'server' => ['code' => 'aglsrv1'],
                'metrics' => [
                    'cpu' => ['usage_percent' => 67.8, 'cores' => 32],
                    'memory' => ['usage_percent' => 50, 'used_gb' => 32, 'total_gb' => 256],
                    'load' => ['1min' => 8.5],
                    'uptime' => ['days' => 100],
                ],
                'health_status' => 'healthy',
            ]);

        Livewire::test(ServerHealthCard::class, ['serverCode' => 'aglsrv1'])
            ->assertSee('67.8');
    });

    test('memory progress bar shows correct percentage', function () {
        $this->metricsCollector->shouldReceive('collectServerMetrics')
            ->andReturn([
                'success' => true,
                'server' => ['code' => 'aglsrv1'],
                'metrics' => [
                    'cpu' => ['usage_percent' => 45, 'cores' => 32],
                    'memory' => ['usage_percent' => 82.3, 'used_gb' => 210, 'total_gb' => 256],
                    'load' => ['1min' => 8.5],
                    'uptime' => ['days' => 100],
                ],
                'health_status' => 'warning',
            ]);

        Livewire::test(ServerHealthCard::class, ['serverCode' => 'aglsrv1'])
            ->assertSee('82.3');
    });
});
