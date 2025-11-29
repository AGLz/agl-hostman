<?php

namespace App\Listeners\Notifications;

use App\Events\Notifications\PROpened;
use App\Events\Notifications\PRMerged;
use App\Events\Notifications\PRCommented;
use App\Services\Notifications\NotificationManager;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Support\Facades\Log;

class SendPRNotification implements ShouldQueue
{
    /**
     * Create the event listener.
     */
    public function __construct(
        private NotificationManager $notificationManager
    ) {}

    /**
     * Handle PR opened event.
     */
    public function handleOpened(PROpened $event): void
    {
        try {
            $this->notificationManager->send($event->getNotificationData());
        } catch (\Exception $e) {
            Log::error('Failed to send PR opened notification', [
                'pr_number' => $event->prNumber,
                'error' => $e->getMessage(),
            ]);
        }
    }

    /**
     * Handle PR merged event.
     */
    public function handleMerged(PRMerged $event): void
    {
        try {
            $this->notificationManager->send($event->getNotificationData());
        } catch (\Exception $e) {
            Log::error('Failed to send PR merged notification', [
                'pr_number' => $event->prNumber,
                'error' => $e->getMessage(),
            ]);
        }
    }

    /**
     * Handle PR commented event.
     */
    public function handleCommented(PRCommented $event): void
    {
        try {
            $this->notificationManager->send($event->getNotificationData());
        } catch (\Exception $e) {
            Log::error('Failed to send PR commented notification', [
                'pr_number' => $event->prNumber,
                'error' => $e->getMessage(),
            ]);
        }
    }
}
