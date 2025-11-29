<?php

namespace App\Services\Notifications;

use App\Models\Alert;
use App\Models\Deployment;
use App\Models\NotificationChannel;
use App\Models\NotificationHistory;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class SlackNotificationService
{
    protected array $config;
    protected ?NotificationChannel $channel = null;

    public function __construct()
    {
        $this->config = config('notifications.slack', []);
    }

    /**
     * Set the notification channel configuration
     */
    public function setChannel(NotificationChannel $channel): self
    {
        $this->channel = $channel;
        return $this;
    }

    /**
     * Send deployment notification
     */
    public function sendDeploymentNotification(Deployment $deployment): bool
    {
        $color = match($deployment->status) {
            'completed' => 'good',
            'failed' => 'danger',
            'in_progress' => 'warning',
            default => '#808080'
        };

        $emoji = match($deployment->status) {
            'completed' => ':white_check_mark:',
            'failed' => ':x:',
            'in_progress' => ':hourglass_flowing_sand:',
            default => ':question:'
        };

        $message = [
            'channel' => $this->getChannel('deployments'),
            'username' => 'AGL-HOSTMAN Deploy Bot',
            'icon_emoji' => ':rocket:',
            'attachments' => [[
                'color' => $color,
                'title' => "{$emoji} Deployment {$deployment->environment->name}: " . ucfirst($deployment->status),
                'fields' => [
                    ['title' => 'Version', 'value' => $deployment->version, 'short' => true],
                    ['title' => 'Commit', 'value' => substr($deployment->git_commit ?? 'N/A', 0, 7), 'short' => true],
                    ['title' => 'Duration', 'value' => ($deployment->duration ?? 0) . 's', 'short' => true],
                    ['title' => 'Author', 'value' => $deployment->triggered_by ?? 'System', 'short' => true],
                ],
                'actions' => [
                    [
                        'type' => 'button',
                        'text' => 'View Logs',
                        'url' => route('deployments.show', $deployment->id)
                    ],
                    [
                        'type' => 'button',
                        'text' => 'Rollback',
                        'url' => route('deployments.rollback', $deployment->id),
                        'style' => 'danger',
                        'confirm' => [
                            'title' => 'Are you sure?',
                            'text' => 'This will rollback to the previous deployment',
                            'ok_text' => 'Yes, rollback',
                            'dismiss_text' => 'Cancel'
                        ]
                    ]
                ],
                'footer' => 'AGL-HOSTMAN',
                'footer_icon' => 'https://aglz.io/favicon.ico',
                'ts' => $deployment->created_at->timestamp
            ]]
        ];

        return $this->send($message, 'deployment', $deployment->id);
    }

    /**
     * Send alert notification
     */
    public function sendAlertNotification(Alert $alert): bool
    {
        $color = match($alert->type) {
            'critical' => 'danger',
            'warning' => 'warning',
            'info' => 'good',
            default => '#808080'
        };

        $emoji = match($alert->type) {
            'critical' => ':rotating_light:',
            'warning' => ':warning:',
            'info' => ':information_source:',
            default => ':bell:'
        };

        $message = [
            'channel' => $this->getChannel('alerts'),
            'username' => 'AGL-HOSTMAN Alert Bot',
            'icon_emoji' => ':bell:',
            'attachments' => [[
                'color' => $color,
                'title' => "{$emoji} {$alert->title}",
                'text' => $alert->message,
                'fields' => [
                    ['title' => 'Source', 'value' => ucfirst($alert->source), 'short' => true],
                    ['title' => 'Severity', 'value' => ucfirst($alert->type), 'short' => true],
                    ['title' => 'Environment', 'value' => $alert->metadata['environment'] ?? 'N/A', 'short' => true],
                    ['title' => 'Location', 'value' => $alert->metadata['host'] ?? 'N/A', 'short' => true],
                ],
                'actions' => [
                    [
                        'type' => 'button',
                        'text' => 'Acknowledge',
                        'url' => route('alerts.acknowledge', $alert->id),
                        'style' => 'primary'
                    ],
                    [
                        'type' => 'button',
                        'text' => 'Resolve',
                        'url' => route('alerts.resolve', $alert->id),
                        'style' => 'primary'
                    ],
                    [
                        'type' => 'button',
                        'text' => 'View Details',
                        'url' => route('alerts.show', $alert->id)
                    ]
                ],
                'footer' => 'AGL-HOSTMAN Alert Center',
                'ts' => $alert->created_at->timestamp
            ]]
        ];

        return $this->send($message, 'alert', $alert->id);
    }

    /**
     * Send PR notification
     */
    public function sendPRNotification(string $action, array $prData): bool
    {
        $color = match($action) {
            'opened' => 'good',
            'merged' => '#6f42c1',
            'closed' => '#dc3545',
            'commented' => 'warning',
            default => '#808080'
        };

        $emoji = match($action) {
            'opened' => ':arrow_heading_up:',
            'merged' => ':white_check_mark:',
            'closed' => ':x:',
            'commented' => ':speech_balloon:',
            default => ':git:'
        };

        $message = [
            'channel' => $this->getChannel('github'),
            'username' => 'AGL-HOSTMAN GitHub Bot',
            'icon_emoji' => ':github:',
            'attachments' => [[
                'color' => $color,
                'title' => "{$emoji} PR #{$prData['number']}: {$prData['title']}",
                'text' => $prData['description'] ?? '',
                'fields' => [
                    ['title' => 'Author', 'value' => $prData['author'], 'short' => true],
                    ['title' => 'Status', 'value' => ucfirst($action), 'short' => true],
                    ['title' => 'Branch', 'value' => "{$prData['source_branch']} → {$prData['target_branch']}", 'short' => false],
                ],
                'actions' => [
                    [
                        'type' => 'button',
                        'text' => 'View PR',
                        'url' => $prData['url']
                    ],
                    [
                        'type' => 'button',
                        'text' => 'Review Changes',
                        'url' => $prData['url'] . '/files'
                    ]
                ],
                'footer' => 'GitHub',
                'footer_icon' => 'https://github.githubassets.com/favicons/favicon.png',
                'ts' => time()
            ]]
        ];

        return $this->send($message, 'pr', $prData['number']);
    }

    /**
     * Send custom message
     */
    public function sendCustomMessage(string $channel, string $text, array $attachments = []): bool
    {
        $message = [
            'channel' => $channel,
            'text' => $text,
            'username' => 'AGL-HOSTMAN Bot',
            'icon_emoji' => ':robot_face:',
        ];

        if (!empty($attachments)) {
            $message['attachments'] = $attachments;
        }

        return $this->send($message, 'custom');
    }

    /**
     * Send threaded reply
     */
    public function sendThreadedReply(string $channel, string $threadTs, string $text): bool
    {
        $message = [
            'channel' => $channel,
            'thread_ts' => $threadTs,
            'text' => $text,
            'username' => 'AGL-HOSTMAN Bot',
            'icon_emoji' => ':robot_face:',
        ];

        return $this->send($message, 'thread');
    }

    /**
     * Update existing message
     */
    public function updateMessage(string $channel, string $ts, array $newAttachments): bool
    {
        $webhookUrl = $this->getWebhookUrl();

        if (!$webhookUrl) {
            Log::warning('Slack webhook URL not configured');
            return false;
        }

        try {
            $response = Http::timeout(10)
                ->retry(3, 1000)
                ->post($webhookUrl, [
                    'channel' => $channel,
                    'ts' => $ts,
                    'attachments' => $newAttachments,
                    'replace_original' => true
                ]);

            return $response->successful();
        } catch (\Exception $e) {
            Log::error('Failed to update Slack message', [
                'error' => $e->getMessage(),
                'channel' => $channel,
                'ts' => $ts
            ]);
            return false;
        }
    }

    /**
     * Send message with retry logic
     */
    protected function send(array $message, string $type = 'general', mixed $sourceId = null): bool
    {
        $webhookUrl = $this->getWebhookUrl();

        if (!$webhookUrl) {
            Log::warning('Slack webhook URL not configured');
            return false;
        }

        $historyId = $this->createHistory($message, $type, $sourceId);

        try {
            $response = Http::timeout(10)
                ->retry(3, 1000, function ($exception, $request) {
                    return $exception instanceof \Illuminate\Http\Client\ConnectionException;
                })
                ->post($webhookUrl, $message);

            $success = $response->successful();

            $this->updateHistory($historyId, $success, $response->body());

            if (!$success) {
                Log::error('Slack notification failed', [
                    'status' => $response->status(),
                    'response' => $response->body(),
                    'message' => $message
                ]);
            }

            return $success;

        } catch (\Exception $e) {
            $this->updateHistory($historyId, false, $e->getMessage());

            Log::error('Slack notification exception', [
                'error' => $e->getMessage(),
                'message' => $message
            ]);

            return false;
        }
    }

    /**
     * Get webhook URL from config or channel
     */
    protected function getWebhookUrl(): ?string
    {
        if ($this->channel) {
            return $this->channel->config['webhook_url'] ?? null;
        }

        return $this->config['webhook_url'] ?? null;
    }

    /**
     * Get channel name from config
     */
    protected function getChannel(string $type): string
    {
        if ($this->channel) {
            return $this->channel->config['channel'] ?? '#general';
        }

        return $this->config['channels'][$type] ?? '#general';
    }

    /**
     * Create notification history record
     */
    protected function createHistory(array $message, string $type, mixed $sourceId): ?int
    {
        try {
            $history = NotificationHistory::create([
                'channel_type' => 'slack',
                'notification_type' => $type,
                'source_id' => $sourceId,
                'payload' => $message,
                'status' => 'pending',
                'attempts' => 1,
            ]);

            return $history->id;
        } catch (\Exception $e) {
            Log::error('Failed to create notification history', [
                'error' => $e->getMessage()
            ]);
            return null;
        }
    }

    /**
     * Update notification history record
     */
    protected function updateHistory(?int $historyId, bool $success, ?string $response): void
    {
        if (!$historyId) {
            return;
        }

        try {
            NotificationHistory::where('id', $historyId)->update([
                'status' => $success ? 'sent' : 'failed',
                'response' => $response,
                'sent_at' => $success ? now() : null,
                'failed_at' => !$success ? now() : null,
            ]);
        } catch (\Exception $e) {
            Log::error('Failed to update notification history', [
                'error' => $e->getMessage(),
                'history_id' => $historyId
            ]);
        }
    }

    /**
     * Test Slack connection
     */
    public function test(): array
    {
        $webhookUrl = $this->getWebhookUrl();

        if (!$webhookUrl) {
            return [
                'success' => false,
                'message' => 'Webhook URL not configured'
            ];
        }

        $testMessage = [
            'channel' => $this->getChannel('general'),
            'username' => 'AGL-HOSTMAN Test',
            'icon_emoji' => ':test_tube:',
            'text' => 'This is a test notification from AGL-HOSTMAN',
            'attachments' => [[
                'color' => 'good',
                'title' => 'Connection Test',
                'text' => 'If you see this message, Slack integration is working correctly!',
                'footer' => 'AGL-HOSTMAN',
                'ts' => time()
            ]]
        ];

        try {
            $response = Http::timeout(10)->post($webhookUrl, $testMessage);

            return [
                'success' => $response->successful(),
                'message' => $response->successful()
                    ? 'Slack notification sent successfully'
                    : 'Failed to send Slack notification',
                'status' => $response->status(),
                'response' => $response->body()
            ];
        } catch (\Exception $e) {
            return [
                'success' => false,
                'message' => 'Exception occurred',
                'error' => $e->getMessage()
            ];
        }
    }
}
