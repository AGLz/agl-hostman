<?php

declare(strict_types=1);

use App\Services\Broadcasting\WebSocketBroadcastService;
use Illuminate\Support\Facades\Event;
use App\Events\ServerMetricsUpdated;
use App\Events\ContainerStatusChanged;
use App\Events\AlertTriggered;

describe('WebSocket Broadcasting', function () {
    beforeEach(function () {
        $this->broadcastService = new WebSocketBroadcastService();
        Event::fake();
    });

    it('broadcasts server metrics update', function () {
        // Act
        $this->broadcastService->broadcastServerMetrics(
            serverCode: 'AGLSRV1',
            cpuUsage: 45.5,
            memoryUsage: 62.3,
            containerCount: 68,
            status: 'online',
            uptime: 864000,
            networkStats: ['rx' => 1024, 'tx' => 2048]
        );

        // Assert
        Event::assertDispatched(ServerMetricsUpdated::class, function ($event) {
            return $event->serverCode === 'AGLSRV1'
                && $event->cpuUsage === 45.5
                && $event->memoryUsage === 62.3
                && $event->containerCount === 68
                && $event->status === 'online'
                && $event->uptime === 864000;
        });
    });

    it('broadcasts container status change', function () {
        // Act
        $this->broadcastService->broadcastContainerStatus(
            vmid: '179',
            name: 'CT179',
            status: 'running',
            previousStatus: 'stopped',
            serverCode: 'AGLSRV1',
            metrics: ['cpu' => 25.0, 'memory' => 48.0]
        );

        // Assert
        Event::assertDispatched(ContainerStatusChanged::class, function ($event) {
            return $event->vmid === '179'
                && $event->name === 'CT179'
                && $event->status === 'running'
                && $event->previousStatus === 'stopped'
                && $event->serverCode === 'AGLSRV1';
        });
    });

    it('broadcasts infrastructure alert', function () {
        // Act
        $this->broadcastService->broadcastAlert(
            severity: 'critical',
            title: 'High CPU Usage',
            message: 'AGLSRV1 CPU usage exceeded 90%',
            resourceType: 'server',
            resourceId: 'AGLSRV1',
            metadata: ['threshold' => 90, 'current' => 95]
        );

        // Assert
        Event::assertDispatched(AlertTriggered::class, function ($event) {
            return $event->severity === 'critical'
                && $event->title === 'High CPU Usage'
                && $event->resourceType === 'server'
                && $event->resourceId === 'AGLSRV1';
        });
    });

    it('broadcasts batch server metrics', function () {
        // Arrange
        $serversMetrics = [
            [
                'server_code' => 'AGLSRV1',
                'cpu_usage' => 45.5,
                'memory_usage' => 62.3,
                'container_count' => 68,
                'status' => 'online',
            ],
            [
                'server_code' => 'AGLSRV6',
                'cpu_usage' => 32.1,
                'memory_usage' => 54.7,
                'container_count' => 12,
                'status' => 'online',
            ],
        ];

        // Act
        $this->broadcastService->broadcastBatchServerMetrics($serversMetrics);

        // Assert
        Event::assertDispatched(ServerMetricsUpdated::class, 2);
    });

    it('server metrics event broadcasts on correct channel', function () {
        // Arrange
        $event = new ServerMetricsUpdated(
            serverCode: 'AGLSRV1',
            cpuUsage: 45.5,
            memoryUsage: 62.3,
            containerCount: 68,
            status: 'online'
        );

        // Act
        $channel = $event->broadcastOn();

        // Assert
        expect($channel->name)->toBe('infrastructure.server.AGLSRV1');
    });

    it('container status event broadcasts on multiple channels', function () {
        // Arrange
        $event = new ContainerStatusChanged(
            vmid: '179',
            name: 'CT179',
            status: 'running',
            previousStatus: 'stopped',
            serverCode: 'AGLSRV1'
        );

        // Act
        $channels = $event->broadcastOn();

        // Assert
        expect($channels)->toHaveCount(2)
            ->and($channels[0]->name)->toBe('infrastructure.container.179')
            ->and($channels[1]->name)->toBe('infrastructure.server.AGLSRV1');
    });

    it('alert event broadcasts on severity-filtered channels', function () {
        // Arrange
        $event = new AlertTriggered(
            severity: 'critical',
            title: 'System Alert',
            message: 'Critical issue detected',
            resourceType: 'server',
            resourceId: 'AGLSRV1'
        );

        // Act
        $channels = $event->broadcastOn();

        // Assert
        expect($channels)->toHaveCount(2)
            ->and($channels[0]->name)->toBe('infrastructure.alerts')
            ->and($channels[1]->name)->toBe('infrastructure.alerts.critical');
    });

    it('event includes timestamp in broadcast data', function () {
        // Arrange
        $event = new ServerMetricsUpdated(
            serverCode: 'AGLSRV1',
            cpuUsage: 45.5,
            memoryUsage: 62.3,
            containerCount: 68,
            status: 'online'
        );

        // Act
        $data = $event->broadcastWith();

        // Assert
        expect($data)->toHaveKey('timestamp')
            ->and($data['timestamp'])->toBeString()
            ->and($data['server_code'])->toBe('AGLSRV1');
    });
});
