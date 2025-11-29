<?php

namespace App\Events\Notifications;

use App\Models\OnCallSchedule;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class OnCallRotation
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    /**
     * Create a new event instance.
     */
    public function __construct(
        public OnCallSchedule $schedule,
        public ?string $previousEngineer = null
    ) {}

    /**
     * Get the notification data.
     */
    public function getNotificationData(): array
    {
        $message = $this->previousEngineer
            ? "On-call rotation: {$this->previousEngineer} → {$this->schedule->engineer_name}"
            : "On-call assignment: {$this->schedule->engineer_name} is now on-call";

        return [
            'type' => 'on_call',
            'subtype' => 'rotation',
            'title' => "🔄 On-Call Rotation",
            'message' => $message,
            'data' => [
                'schedule_id' => $this->schedule->id,
                'current_engineer' => $this->schedule->engineer_name,
                'previous_engineer' => $this->previousEngineer,
                'start_time' => $this->schedule->start_time,
                'end_time' => $this->schedule->end_time,
                'is_override' => $this->schedule->is_override,
            ],
            'severity' => 'info',
            'channels' => ['slack'],
            'actions' => [
                [
                    'text' => 'View Schedule',
                    'url' => route('on-call.index'),
                    'style' => 'primary',
                ],
            ],
        ];
    }
}
