<?php

namespace App\Events\Notifications;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class PRCommented
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    /**
     * Create a new event instance.
     */
    public function __construct(
        public int $prNumber,
        public string $title,
        public string $commenter,
        public string $comment,
        public string $url
    ) {}

    /**
     * Get the notification data.
     */
    public function getNotificationData(): array
    {
        $truncatedComment = strlen($this->comment) > 200
            ? substr($this->comment, 0, 200).'...'
            : $this->comment;

        return [
            'type' => 'pull_request',
            'subtype' => 'commented',
            'title' => "💬 New Comment on PR #$this->prNumber",
            'message' => "{$this->commenter}: {$truncatedComment}",
            'data' => [
                'pr_number' => $this->prNumber,
                'title' => $this->title,
                'commenter' => $this->commenter,
                'comment' => $this->comment,
                'url' => $this->url,
                'commented_at' => now(),
            ],
            'severity' => 'info',
            'channels' => ['slack'],
            'actions' => [
                [
                    'text' => 'View Comment',
                    'url' => $this->url,
                    'style' => 'primary',
                ],
                [
                    'text' => 'Reply',
                    'url' => $this->url.'#discussion',
                    'style' => 'default',
                ],
            ],
        ];
    }
}
