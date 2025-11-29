<?php

namespace App\Events\Notifications;

use App\Models\Deployment;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class DeploymentFailed
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    /**
     * Create a new event instance.
     */
    public function __construct(
        public Deployment $deployment,
        public string $errorMessage
    ) {}

    /**
     * Get the notification data.
     */
    public function getNotificationData(): array
    {
        return [
            'type' => 'deployment',
            'subtype' => 'failed',
            'title' => "❌ Deployment Failed: {$this->deployment->environment->name}",
            'message' => "Version {$this->deployment->version} deployment failed: {$this->errorMessage}",
            'data' => [
                'deployment_id' => $this->deployment->id,
                'environment' => $this->deployment->environment->name,
                'version' => $this->deployment->version,
                'error' => $this->errorMessage,
                'failed_at' => now(),
                'logs_url' => route('deployments.logs', $this->deployment),
                'url' => route('deployments.show', $this->deployment),
            ],
            'severity' => 'critical',
            'channels' => ['slack', 'pagerduty'],
            'actions' => [
                [
                    'text' => 'View Logs',
                    'url' => route('deployments.logs', $this->deployment),
                    'style' => 'danger',
                ],
                [
                    'text' => 'Retry Deployment',
                    'url' => route('deployments.retry', $this->deployment),
                    'style' => 'primary',
                ],
            ],
        ];
    }
}
