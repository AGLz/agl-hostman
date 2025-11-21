<?php

declare(strict_types=1);

namespace App\Events;

use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Server Metrics Updated Event
 *
 * Broadcasts real-time server metrics to connected clients
 * Channel: infrastructure.server.{serverCode}
 */
class ServerMetricsUpdated implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    /**
     * Create a new event instance.
     */
    public function __construct(
        public string $serverCode,
        public float $cpuUsage,
        public float $memoryUsage,
        public int $containerCount,
        public string $status,
        public ?int $uptime = null,
        public ?array $networkStats = null,
    ) {}

    /**
     * Get the channels the event should broadcast on.
     */
    public function broadcastOn(): Channel
    {
        return new Channel('infrastructure.server.' . $this->serverCode);
    }

    /**
     * Get the data to broadcast.
     */
    public function broadcastWith(): array
    {
        return [
            'server_code' => $this->serverCode,
            'cpu_usage' => $this->cpuUsage,
            'memory_usage' => $this->memoryUsage,
            'container_count' => $this->containerCount,
            'status' => $this->status,
            'uptime' => $this->uptime,
            'network_stats' => $this->networkStats,
            'timestamp' => now()->toIso8601String(),
        ];
    }

    /**
     * Get the event name for broadcasting.
     */
    public function broadcastAs(): string
    {
        return 'server.metrics.updated';
    }
}
