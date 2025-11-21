<?php

declare(strict_types=1);

namespace App\Events;

use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Alert Triggered Event
 *
 * Broadcasts infrastructure alerts to connected clients
 * Channel: infrastructure.alerts
 */
class AlertTriggered implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    /**
     * Create a new event instance.
     */
    public function __construct(
        public string $severity,
        public string $title,
        public string $message,
        public string $resourceType,
        public string $resourceId,
        public ?array $metadata = null,
    ) {}

    /**
     * Get the channels the event should broadcast on.
     */
    public function broadcastOn(): array
    {
        return [
            new Channel('infrastructure.alerts'),
            new Channel("infrastructure.alerts.{$this->severity}"),
        ];
    }

    /**
     * Get the data to broadcast.
     */
    public function broadcastWith(): array
    {
        return [
            'severity' => $this->severity,
            'title' => $this->title,
            'message' => $this->message,
            'resource_type' => $this->resourceType,
            'resource_id' => $this->resourceId,
            'metadata' => $this->metadata,
            'timestamp' => now()->toIso8601String(),
        ];
    }

    /**
     * Get the event name for broadcasting.
     */
    public function broadcastAs(): string
    {
        return 'alert.triggered';
    }
}
