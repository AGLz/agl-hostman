<?php

declare(strict_types=1);

namespace App\Events;

use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Deployment Progress Updated Event
 *
 * Broadcasts real-time deployment progress to connected clients
 * Channel: deployments.{deploymentId}
 */
class DeploymentProgressUpdated implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    /**
     * Create a new event instance.
     */
    public function __construct(
        public string $deploymentId,
        public string $environment,
        public string $status,
        public int $progress,
        public string $currentStep,
        public ?array $details = null,
        public ?array $errors = null,
    ) {}

    /**
     * Get the channels the event should broadcast on.
     */
    public function broadcastOn(): array
    {
        return [
            new Channel('deployments.' . $this->deploymentId),
            new Channel('deployments.environment.' . $this->environment),
        ];
    }

    /**
     * Get the data to broadcast.
     */
    public function broadcastWith(): array
    {
        return [
            'deployment_id' => $this->deploymentId,
            'environment' => $this->environment,
            'status' => $this->status,
            'progress' => $this->progress,
            'current_step' => $this->currentStep,
            'details' => $this->details,
            'errors' => $this->errors,
            'timestamp' => now()->toIso8601String(),
        ];
    }

    /**
     * Get the event name for broadcasting.
     */
    public function broadcastAs(): string
    {
        return 'deployment.progress.updated';
    }
}
