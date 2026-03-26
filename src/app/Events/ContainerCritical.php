<?php

namespace App\Events;

use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Container Critical Event
 *
 * Fired when a container enters critical health status.
 * Broadcasts to real-time dashboard and triggers alert listeners.
 */
class ContainerCritical implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public string $node;

    public int $vmid;

    public string $containerName;

    public string $severity;

    public array $issues;

    public array $metrics;

    /**
     * Create a new event instance
     */
    public function __construct(
        string $node,
        int $vmid,
        string $containerName,
        string $severity,
        array $issues,
        array $metrics
    ) {
        $this->node = $node;
        $this->vmid = $vmid;
        $this->containerName = $containerName;
        $this->severity = $severity;
        $this->issues = $issues;
        $this->metrics = $metrics;
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
        ];
    }

    /**
     * Get the data to broadcast
     */
    public function broadcastWith(): array
    {
        return [
            'type' => 'container_critical',
            'node' => $this->node,
            'vmid' => $this->vmid,
            'container' => $this->containerName,
            'severity' => $this->severity,
            'issues' => $this->issues,
            'metrics' => $this->metrics,
            'timestamp' => now()->toIso8601String(),
        ];
    }
}
