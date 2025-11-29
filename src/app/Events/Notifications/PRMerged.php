<?php

namespace App\Events\Notifications;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class PRMerged
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    /**
     * Create a new event instance.
     */
    public function __construct(
        public int $prNumber,
        public string $title,
        public string $author,
        public string $mergedBy,
        public string $url
    ) {}

    /**
     * Get the notification data.
     */
    public function getNotificationData(): array
    {
        return [
            'type' => 'pull_request',
            'subtype' => 'merged',
            'title' => "✅ Pull Request #$this->prNumber Merged",
            'message' => "{$this->title}\nMerged by: {$this->mergedBy}",
            'data' => [
                'pr_number' => $this->prNumber,
                'title' => $this->title,
                'author' => $this->author,
                'merged_by' => $this->mergedBy,
                'url' => $this->url,
                'merged_at' => now(),
            ],
            'severity' => 'success',
            'channels' => ['slack'],
            'actions' => [
                [
                    'text' => 'View PR',
                    'url' => $this->url,
                    'style' => 'primary',
                ],
            ],
        ];
    }
}
