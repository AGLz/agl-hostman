<?php

namespace App\Events;

use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Resource Exhaustion Predicted Event
 *
 * Fired when AI predicts resource exhaustion for a container.
 * Allows proactive intervention before critical failures.
 *
 * @package App\Events
 */
class ResourceExhaustionPredicted implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public string $node;
    public int $vmid;
    public string $resourceType;
    public float $predictedUsage;
    public int $hoursAhead;
    public float $confidence;

    /**
     * Create a new event instance
     */
    public function __construct(
        string $node,
        int $vmid,
        string $resourceType,
        float $predictedUsage,
        int $hoursAhead,
        float $confidence
    ) {
        $this->node = $node;
        $this->vmid = $vmid;
        $this->resourceType = $resourceType;
        $this->predictedUsage = $predictedUsage;
        $this->hoursAhead = $hoursAhead;
        $this->confidence = $confidence;
    }

    /**
     * Get the channels the event should broadcast on
     *
     * @return array<int, \Illuminate\Broadcasting\Channel>
     */
    public function broadcastOn(): array
    {
        return [
            new Channel('infrastructure-alerts'),
            new Channel("node.{$this->node}"),
            new Channel('predictive-maintenance'),
        ];
    }

    /**
     * Get the data to broadcast
     */
    public function broadcastWith(): array
    {
        return [
            'type' => 'resource_exhaustion_predicted',
            'node' => $this->node,
            'vmid' => $this->vmid,
            'resource_type' => $this->resourceType,
            'predicted_usage' => round($this->predictedUsage, 2),
            'hours_ahead' => $this->hoursAhead,
            'confidence' => round($this->confidence, 3),
            'timestamp' => now()->toIso8601String(),
        ];
    }
}
