<?php

namespace App\Events\Notifications;

use App\Models\Deployment;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class DeploymentStarted
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
        return [
            'type' => 'deployment',
            'subtype' => 'started',
            'title' => "🚀 Deployment Started: {$this->deployment->environment->name}",
            'message' => "Version {$this->deployment->version} deployment initiated by {$this->deployment->triggered_by}",
            'data' => [
                'deployment_id' => $this->deployment->id,
                'environment' => $this->deployment->environment->name,
                'version' => $this->deployment->version,
                'triggered_by' => $this->deployment->triggered_by,
                'started_at' => $this->deployment->started_at,
                'url' => route('deployments.show', $this->deployment),
            ],
            'severity' => 'info',
            'channels' => ['slack'],
            'actions' => [
                [
                    'text' => 'View Deployment',
                    'url' => route('deployments.show', $this->deployment),
                    'style' => 'primary',
                ],
            ],
        ];
    }
}
