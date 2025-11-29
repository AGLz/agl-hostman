<?php

namespace App\Events\Notifications;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class PROpened
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    /**
     * Create a new event instance.
     */
    public function __construct(
        public int $prNumber,
        public string $title,
        public string $author,
        public string $url,
        public array $labels = [],
        public ?string $description = null
    ) {}

    /**
     * Get the notification data.
     */
    public function getNotificationData(): array
    {
        return [
            'type' => 'pull_request',
            'subtype' => 'opened',
            'title' => "🔔 New Pull Request #$this->prNumber",
            'message' => "{$this->title}\nBy: {$this->author}",
            'data' => [
                'pr_number' => $this->prNumber,
                'title' => $this->title,
                'author' => $this->author,
                'url' => $this->url,
                'labels' => $this->labels,
                'description' => $this->description,
            ],
            'severity' => 'info',
            'channels' => ['slack'],
            'actions' => [
                [
                    'text' => 'Review PR',
                    'url' => $this->url,
                    'style' => 'primary',
                ],
                [
                    'text' => 'Approve',
                    'value' => json_encode(['action' => 'approve', 'pr' => $this->prNumber]),
                    'style' => 'primary',
                ],
            ],
        ];
    }
}
