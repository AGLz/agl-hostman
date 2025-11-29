<?php

namespace App\Listeners\Notifications;

use App\Events\Notifications\OnCallRotation;
use App\Services\Notifications\NotificationManager;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Support\Facades\Log;

class SendOnCallNotification implements ShouldQueue
{
    /**
     * Create the event listener.
     */
    public function __construct(
        private NotificationManager $notificationManager
    ) {}

    /**
     * Handle on-call rotation event.
     */
    public function handle(OnCallRotation $event): void
    {
        try {
            $this->notificationManager->send($event->getNotificationData());
        } catch (\Exception $e) {
            Log::error('Failed to send on-call rotation notification', [
                'schedule_id' => $event->schedule->id,
                'error' => $e->getMessage(),
            ]);
        }
    }
}
