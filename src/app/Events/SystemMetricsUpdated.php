<?php

declare(strict_types=1);

namespace App\Events;

use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * System Metrics Updated Event
 *
 * Broadcasts overall infrastructure metrics and health status
 * Channel: system.monitoring
 */
class SystemMetricsUpdated implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    /**
     * Create a new event instance.
     */
    public function __construct(
        public array $servers,
        public int $totalContainers,
        public int $runningContainers,
        public int $stoppedContainers,
        public int $errorContainers,
        public float $averageCpuUsage,
        public float $averageMemoryUsage,
        public string $overallStatus,
        public ?array $alerts = null,
    ) {}

    /**
     * Get the channels the event should broadcast on.
     */
    public function broadcastOn(): Channel
    {
        return new Channel('system.monitoring');
    }

    /**
     * Get the data to broadcast.
     */
    public function broadcastWith(): array
    {
        return [
            'servers' => $this->servers,
            'total_containers' => $this->totalContainers,
            'running_containers' => $this->runningContainers,
            'stopped_containers' => $this->stoppedContainers,
            'error_containers' => $this->errorContainers,
            'average_cpu_usage' => $this->averageCpuUsage,
            'average_memory_usage' => $this->averageMemoryUsage,
            'overall_status' => $this->overallStatus,
            'alerts' => $this->alerts,
            'timestamp' => now()->toIso8601String(),
        ];
    }

    /**
     * Get the event name for broadcasting.
     */
    public function broadcastAs(): string
    {
        return 'system.metrics.updated';
    }
}
