<?php

namespace App\Listeners\Notifications;

use App\Events\Notifications\DeploymentCompleted;
use App\Events\Notifications\DeploymentFailed;
use App\Events\Notifications\DeploymentStarted;
use App\Services\Notifications\NotificationManager;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Support\Facades\Log;

class SendDeploymentNotification implements ShouldQueue
{
    /**
     * Create the event listener.
     */
    public function __construct(
        private NotificationManager $notificationManager
    ) {}

    /**
     * Handle deployment started event.
     */
    public function handleStarted(DeploymentStarted $event): void
    {
        try {
            $this->notificationManager->send($event->getNotificationData());
        } catch (\Exception $e) {
            Log::error('Failed to send deployment started notification', [
                'deployment_id' => $event->deployment->id,
                'error' => $e->getMessage(),
            ]);
        }
    }

    /**
     * Handle deployment completed event.
     */
    public function handleCompleted(DeploymentCompleted $event): void
    {
        try {
            $this->notificationManager->send($event->getNotificationData());
        } catch (\Exception $e) {
            Log::error('Failed to send deployment completed notification', [
                'deployment_id' => $event->deployment->id,
                'error' => $e->getMessage(),
            ]);
        }
    }

    /**
     * Handle deployment failed event.
     */
    public function handleFailed(DeploymentFailed $event): void
    {
        try {
            $this->notificationManager->send($event->getNotificationData());
        } catch (\Exception $e) {
            Log::error('Failed to send deployment failed notification', [
                'deployment_id' => $event->deployment->id,
                'error' => $e->getMessage(),
            ]);
        }
    }
}
