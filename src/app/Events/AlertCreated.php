<?php

declare(strict_types=1);

namespace App\Events;

use App\Models\Alert;
use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * AlertCreated - Broadcast when new alert is created
 *
 * Fired when a new alert is created in the system
 * Broadcasts to 'alerts' channel for real-time UI updates
 */
class AlertCreated implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public Alert $alert;

    /**
     * Create a new event instance
     */
    public function __construct(Alert $alert)
    {
        $this->alert = $alert;
    }

    /**
     * Get the channels the event should broadcast on
     *
     * @return array<int, \Illuminate\Broadcasting\Channel>
     */
    public function broadcastOn(): array
    {
        return [
            new Channel('alerts'),
        ];
    }

    /**
     * The event's broadcast name
     */
    public function broadcastAs(): string
    {
        return 'alert.created';
    }

    /**
     * Get the data to broadcast
     *
     * @return array<string, mixed>
     */
    public function broadcastWith(): array
    {
        return [
            'alert' => [
                'id' => $this->alert->id,
                'type' => $this->alert->type,
                'title' => $this->alert->title,
                'message' => $this->alert->message,
                'source' => $this->alert->source,
                'source_id' => $this->alert->source_id,
                'severity' => $this->alert->severity,
                'status' => $this->alert->status,
                'color' => $this->alert->color,
                'icon' => $this->alert->icon,
                'metadata' => $this->alert->metadata,
                'created_at' => $this->alert->created_at->toIso8601String(),
                'should_notify' => $this->alert->shouldNotify(),
            ],
        ];
    }
}
