<?php

declare(strict_types=1);

namespace App\Services\Broadcasting;

use App\Events\AlertTriggered;
use App\Events\ContainerStatusChanged;
use App\Events\ServerMetricsUpdated;
use Illuminate\Support\Facades\Log;

/**
 * WebSocket Broadcast Service
 *
 * Centralized service for dispatching real-time broadcast events
 * to WebSocket clients via Laravel Reverb
 */
class WebSocketBroadcastService
{
    /**
     * Broadcast server metrics update
     */
    public function broadcastServerMetrics(
        string $serverCode,
        float $cpuUsage,
        float $memoryUsage,
        int $containerCount,
        string $status,
        ?int $uptime = null,
        ?array $networkStats = null
    ): void {
        try {
            event(new ServerMetricsUpdated(
                serverCode: $serverCode,
                cpuUsage: $cpuUsage,
                memoryUsage: $memoryUsage,
                containerCount: $containerCount,
                status: $status,
                uptime: $uptime,
                networkStats: $networkStats
            ));

            Log::debug('Server metrics broadcasted', ['server' => $serverCode]);
        } catch (\Exception $e) {
            Log::error('Failed to broadcast server metrics', [
                'server' => $serverCode,
                'error' => $e->getMessage(),
            ]);
        }
    }

    /**
     * Broadcast container status change
     */
    public function broadcastContainerStatus(
        string $vmid,
        string $name,
        string $status,
        string $previousStatus,
        string $serverCode,
        ?array $metrics = null
    ): void {
        try {
            event(new ContainerStatusChanged(
                vmid: $vmid,
                name: $name,
                status: $status,
                previousStatus: $previousStatus,
                serverCode: $serverCode,
                metrics: $metrics
            ));

            Log::debug('Container status broadcasted', [
                'vmid' => $vmid,
                'status' => $status,
            ]);
        } catch (\Exception $e) {
            Log::error('Failed to broadcast container status', [
                'vmid' => $vmid,
                'error' => $e->getMessage(),
            ]);
        }
    }

    /**
     * Broadcast infrastructure alert
     */
    public function broadcastAlert(
        string $severity,
        string $title,
        string $message,
        string $resourceType,
        string $resourceId,
        ?array $metadata = null
    ): void {
        try {
            event(new AlertTriggered(
                severity: $severity,
                title: $title,
                message: $message,
                resourceType: $resourceType,
                resourceId: $resourceId,
                metadata: $metadata
            ));

            Log::info('Alert broadcasted', [
                'severity' => $severity,
                'title' => $title,
            ]);
        } catch (\Exception $e) {
            Log::error('Failed to broadcast alert', [
                'severity' => $severity,
                'error' => $e->getMessage(),
            ]);
        }
    }

    /**
     * Broadcast batch server metrics for multiple servers
     */
    public function broadcastBatchServerMetrics(array $serversMetrics): void
    {
        foreach ($serversMetrics as $metrics) {
            $this->broadcastServerMetrics(
                serverCode: $metrics['server_code'],
                cpuUsage: $metrics['cpu_usage'],
                memoryUsage: $metrics['memory_usage'],
                containerCount: $metrics['container_count'] ?? 0,
                status: $metrics['status'],
                uptime: $metrics['uptime'] ?? null,
                networkStats: $metrics['network_stats'] ?? null
            );
        }
    }
}
