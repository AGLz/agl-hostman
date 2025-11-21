<?php

declare(strict_types=1);

use App\DTO\ContainerMetrics;

describe('ContainerMetrics DTO', function () {
    it('creates from Proxmox API data', function () {
        $proxmoxData = [
            'vmid' => 100,
            'name' => 'test-container',
            'status' => 'running',
            'cpu' => 0.455,
            'mem' => 1073741824,
            'maxmem' => 2147483648,
            'disk' => 5368709120,
            'maxdisk' => 10737418240,
            'netin' => 1048576,
            'netout' => 2097152,
            'uptime' => 86400,
        ];

        $metrics = ContainerMetrics::fromProxmoxData($proxmoxData);

        expect($metrics->vmid)->toBe('100')
            ->and($metrics->cpuUsage)->toBe(45.5);
    });

    it('calculates memory usage percentage correctly', function () {
        $metrics = new ContainerMetrics(
            vmid: '100', name: 'test', status: 'running',
            cpuUsage: 45.5, memoryUsed: 1073741824,
            memoryTotal: 2147483648, diskUsed: 1, diskTotal: 1
        );

        expect($metrics->getMemoryUsagePercent())->toBe(50.0);
    });

    it('determines if container is healthy', function () {
        $healthy = new ContainerMetrics(
            vmid: '100', name: 'test', status: 'running',
            cpuUsage: 50.0, memoryUsed: 1073741824,
            memoryTotal: 2147483648, diskUsed: 5368709120,
            diskTotal: 10737418240
        );

        expect($healthy->isHealthy())->toBeTrue();
    });

    it('converts to array correctly', function () {
        $metrics = new ContainerMetrics(
            vmid: '100', name: 'test-container', status: 'running',
            cpuUsage: 45.5, memoryUsed: 1073741824,
            memoryTotal: 2147483648, diskUsed: 5368709120,
            diskTotal: 10737418240
        );

        $array = $metrics->toArray();

        expect($array)
            ->toHaveKey('vmid', '100')
            ->toHaveKey('cpu_usage', 45.5);
    });
});
