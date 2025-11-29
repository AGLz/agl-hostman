<?php

namespace App\Events\Notifications;

use App\Models\Deployment;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class DeploymentCompleted
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    /**
     * Create a new event instance.
     */
    public function __construct(
        public Deployment $deployment
    ) {}

    /**
     * Get the notification data.
     */
    public function getNotificationData(): array
    {
        $duration = $this->deployment->started_at->diffForHumans(
            $this->deployment->completed_at,
            true
        );

        return [
            'type' => 'deployment',
            'subtype' => 'completed',
            'title' => "✅ Deployment Completed: {$this->deployment->environment->name}",
            'message' => "Version {$this->deployment->version} deployed successfully in {$duration}",
            'data' => [
                'deployment_id' => $this->deployment->id,
                'environment' => $this->deployment->environment->name,
                'version' => $this->deployment->version,
                'duration' => $duration,
                'completed_at' => $this->deployment->completed_at,
                'url' => route('deployments.show', $this->deployment),
            ],
            'severity' => 'success',
            'channels' => ['slack'],
            'actions' => [
                [
                    'text' => 'View Deployment',
                    'url' => route('deployments.show', $this->deployment),
                    'style' => 'primary',
                ],
                [
                    'text' => 'Rollback',
                    'url' => route('deployments.rollback', $this->deployment),
                    'style' => 'danger',
                ],
            ],
        ];
    }
}
