<?php

declare(strict_types=1);

namespace App\Events;

use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Container Status Changed Event
 *
 * Broadcasts container lifecycle changes to connected clients
 * Channel: infrastructure.container.{vmid}
 */
class ContainerStatusChanged implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    /**
     * Create a new event instance.
     */
    public function __construct(
        public string $vmid,
        public string $name,
        public string $status,
        public string $previousStatus,
        public string $serverCode,
        public ?array $metrics = null,
    ) {}

    /**
     * Get the channels the event should broadcast on.
     */
    public function broadcastOn(): array
    {
        return [
            new Channel('infrastructure.container.'.$this->vmid),
            new Channel('infrastructure.server.'.$this->serverCode),
        ];
    }

    /**
     * Get the data to broadcast.
     */
    public function broadcastWith(): array
    {
        return [
            'vmid' => $this->vmid,
            'name' => $this->name,
            'status' => $this->status,
            'previous_status' => $this->previousStatus,
            'server_code' => $this->serverCode,
            'metrics' => $this->metrics,
            'timestamp' => now()->toIso8601String(),
        ];
    }

    /**
     * Get the event name for broadcasting.
     */
    public function broadcastAs(): string
    {
        return 'container.status.changed';
    }
}
