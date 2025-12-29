<?php

namespace App\Services\Notifications;

use App\Models\Alert;
use App\Models\Deployment;
use App\Models\NotificationChannel;
use App\Models\NotificationHistory;
use App\Models\User;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Cache;

class NotificationManager
{
    protected NotificationRulesEngine $rulesEngine;
    protected SlackNotificationService $slack;
    protected PagerDutyService $pagerduty;

    public function __construct(
        NotificationRulesEngine $rulesEngine,
        SlackNotificationService $slack,
        PagerDutyService $pagerduty
    ) {
        $this->rulesEngine = $rulesEngine;
        $this->slack = $slack;
        $this->pagerduty = $pagerduty;
    }

    /**
     * Send notification through all applicable channels
     */
    public function notify(string $type, mixed $data, array $options = []): array
    {
        $results = [];

        // Apply noise reduction
        if ($this->shouldSuppress($type, $data)) {
            Log::info('Notification suppressed by noise reduction', [
                'type' => $type,
                'data_id' => $data->id ?? null
            ]);

            return [
                'suppressed' => true,
                'reason' => 'noise_reduction'
            ];
        }

        // Check if should group
        if ($this->shouldGroup($type, $data)) {
            Log::info('Notification grouped', [
                'type' => $type,
                'data_id' => $data->id ?? null
            ]);

            $this->addToGroup($type, $data);

            return [
                'grouped' => true,
                'group_id' => $this->getGroupId($type, $data)
            ];
        }

        // Get applicable channels based on rules
        $channels = $this->rulesEngine->getChannelsForNotification($type, $data, $options);

        // Send to each channel
        foreach ($channels as $channel) {
            try {
                $result = $this->sendToChannel($channel, $type, $data, $options);
                $results[$channel->type] = $result;
            } catch (\Exception $e) {
                Log::error('Failed to send notification to channel', [
                    'channel' => $channel->type,
                    'error' => $e->getMessage()
                ]);

                $results[$channel->type] = [
                    'success' => false,
                    'error' => $e->getMessage()
                ];
            }
        }

        return $results;
    }

    /**
     * Send deployment notification
     */
    public function notifyDeployment(Deployment $deployment): array
    {
        return $this->notify('deployment', $deployment);
    }

    /**
     * Send alert notification
     */
    public function notifyAlert(Alert $alert): array
    {
        return $this->notify('alert', $alert);
    }

    /**
     * Send PR notification
     */
    public function notifyPR(string $action, array $prData): array
    {
        return $this->notify('pr', (object) array_merge($prData, ['pr_action' => $action]));
    }

    /**
     * Send custom notification
     */
    public function notifyCustom(string $title, string $message, array $metadata = []): array
    {
        return $this->notify('custom', (object) [
            'title' => $title,
            'message' => $message,
            'metadata' => $metadata
        ]);
    }

    /**
     * Send to specific channel
     */
    protected function sendToChannel(NotificationChannel $channel, string $type, mixed $data, array $options): array
    {
        $service = $this->getServiceForChannel($channel);

        if (!$service) {
            return [
                'success' => false,
                'error' => 'Service not available for channel type: ' . $channel->type
            ];
        }

        return match($channel->type) {
            'slack' => $this->sendToSlack($service, $type, $data, $options),
            'pagerduty' => $this->sendToPagerDuty($service, $type, $data, $options),
            'email' => $this->sendToEmail($type, $data, $options),
            'webhook' => $this->sendToWebhook($channel, $type, $data, $options),
            default => [
                'success' => false,
                'error' => 'Unknown channel type: ' . $channel->type
            ]
        };
    }

    /**
     * Send to Slack
     */
    protected function sendToSlack(SlackNotificationService $slack, string $type, mixed $data, array $options): array
    {
        $success = match($type) {
            'deployment' => $slack->sendDeploymentNotification($data),
            'alert' => $slack->sendAlertNotification($data),
            'pr' => $slack->sendPRNotification($data->pr_action, (array) $data),
            'custom' => $slack->sendCustomMessage(
                $options['channel'] ?? '#general',
                $data->message ?? '',
                $options['attachments'] ?? []
            ),
            default => false
        };

        return [
            'success' => $success,
            'channel' => 'slack'
        ];
    }

    /**
     * Send to PagerDuty
     */
    protected function sendToPagerDuty(PagerDutyService $pagerduty, string $type, mixed $data, array $options): array
    {
        // Only create incidents for alerts
        if ($type !== 'alert') {
            return [
                'success' => false,
                'skipped' => true,
                'reason' => 'PagerDuty only supports alert notifications'
            ];
        }

        $incident = $pagerduty->createIncident($data);

        return [
            'success' => $incident !== null,
            'channel' => 'pagerduty',
            'incident_id' => $incident['id'] ?? null
        ];
    }

    /**
     * Send to email
     */
    protected function sendToEmail(string $type, mixed $data, array $options): array
    {
        try {
            $recipients = $options['recipients'] ?? $this->getDefaultRecipients($type, $data);

            if (empty($recipients)) {
                return [
                    'success' => false,
                    'error' => 'No email recipients specified'
                ];
            }

            $subject = $this->generateEmailSubject($type, $data);
            $view = $this->getEmailView($type);
            $mailData = $this->prepareMailData($type, $data);

            // Use Laravel's built-in mail functionality
            $mailSent = false;
            if (class_exists(\Illuminate\Support\Facades\Mail::class)) {

                // Determine if this is a critical notification that should use queue
                $shouldQueue = $options['queue'] ?? !($type === 'alert' && ($data->type ?? 'info') === 'critical');

                if (method_exists(\Illuminate\Support\Facades\Mail::class, 'to')) {
                    if ($shouldQueue && class_exists(\Illuminate\Support\Facades\Queue::class)) {
                        // Queue the email for non-critical notifications
                        foreach ($recipients as $recipient) {
                            \Illuminate\Support\Facades\Queue::push(function ($job) use ($subject, $view, $mailData, $recipient) {
                                try {
                                    \Illuminate\Support\Facades\Mail::send($view, $mailData, function ($message) use ($subject, $recipient) {
                                        $message->to($recipient)
                                                ->subject($subject)
                                                ->from(config('mail.from.address'), config('mail.from.name'));
                                    });
                                    $job->delete();
                                } catch (\Exception $e) {
                                    Log::error('Failed to send queued email', ['recipient' => $recipient, 'error' => $e->getMessage()]);
                                    $job->failed();
                                }
                            });
                        }
                        $mailSent = true;
                    } else {
                        // Send immediately for critical alerts
                        foreach ($recipients as $recipient) {
                            try {
                                \Illuminate\Support\Facades\Mail::send($view, $mailData, function ($message) use ($subject, $recipient) {
                                    $message->to($recipient)
                                            ->subject($subject)
                                            ->from(config('mail.from.address'), config('mail.from.name'));
                                });
                                $mailSent = true;
                            } catch (\Exception $e) {
                                Log::error('Failed to send immediate email', ['recipient' => $recipient, 'error' => $e->getMessage()]);
                                continue;
                            }
                        }
                    }
                } else {
                    // Fallback: use raw mail() function
                    foreach ($recipients as $recipient) {
                        $headers = "MIME-Version: 1.0\r\n";
                        $headers .= "Content-Type: text/html; charset=UTF-8\r\n";
                        $headers .= "From: " . config('mail.from.address') . "\r\n";

                        $messageBody = view($view, $mailData)->render();
                        $mailSent = mail($recipient, $subject, $messageBody, $headers);
                    }
                }
            }

            return [
                'success' => $mailSent,
                'channel' => 'email',
                'recipients_count' => count($recipients)
            ];

        } catch (\Exception $e) {
            Log::error('Email notification failed', [
                'type' => $type,
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString()
            ]);

            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Get default recipients for email notification
     */
    protected function getDefaultRecipients(string $type, mixed $data): array
    {
        $recipients = [];

        $roles = match($type) {
            'alert' => ['admin'],
            'deployment' => ['admin', 'devops'],
            'pr' => ['admin', 'developer'],
            'custom' => ['admin'],
            default => ['admin']
        };

        if (class_exists(\App\Models\User::class)) {
            $users = \App\Models\User::whereHas('roles', function ($query) use ($roles) {
                $query->whereIn('name', $roles);
            })->get();

            foreach ($users as $user) {
                if ($user->email && $user->notification_preferences['email'][$type] ?? true) {
                    $recipients[] = $user->email;
                }
            }
        }

        $adminEmail = config('notifications.admin_email');
        if (empty($recipients) && $adminEmail) {
            $recipients[] = $adminEmail;
        }

        return array_unique($recipients);
    }

    /**
     * Generate email subject based on notification type
     */
    protected function generateEmailSubject(string $type, mixed $data): string
    {
        return match($type) {
            'deployment' => sprintf('[Deployment %s] %s', strtoupper($data->status), $data->project_name ?? 'Unknown'),
            'alert' => sprintf('[%s] %s', strtoupper($data->type ?? 'Alert'), $data->title ?? 'Alert Notification'),
            'pr' => sprintf('[PR %s] %s by %s', strtoupper($data->pr_action ?? 'Updated'), $data->title ?? 'Unknown', $data->author ?? 'Unknown'),
            'custom' => $data->title ?? 'Notification',
            default => $data->title ?? 'AGL Infrastructure Notification'
        };
    }

    /**
     * Get email view based on notification type
     */
    protected function getEmailView(string $type): string
    {
        return match($type) {
            'deployment' => 'emails.default.deployment',
            'alert' => 'emails.default.alert',
            'pr' => 'emails.default.pull-request',
            'custom' => 'emails.default.custom',
            default => 'emails.default.notification'
        };
    }

    /**
     * Prepare mail data for email template
     */
    protected function prepareMailData(string $type, mixed $data): array
    {
        $baseData = [
            'title' => $this->generateEmailSubject($type, $data),
            'timestamp' => now()->toDateTimeString(),
        ];

        return array_merge($baseData, [
            'notification' => $data,
            'notification_type' => $type,
        ]);
    }

    /**
     * Send to webhook
     */
    protected function sendToWebhook(NotificationChannel $channel, string $type, mixed $data, array $options): array
    {
        $webhookUrl = $channel->config['webhook_url'] ?? null;

        if (!$webhookUrl) {
            return [
                'success' => false,
                'error' => 'Webhook URL not configured'
            ];
        }

        try {
            $payload = [
                'type' => $type,
                'data' => $data,
                'timestamp' => now()->toIso8601String(),
                'metadata' => $options['metadata'] ?? []
            ];

            $response = \Illuminate\Support\Facades\Http::timeout(10)
                ->retry(3, 1000)
                ->post($webhookUrl, $payload);

            return [
                'success' => $response->successful(),
                'channel' => 'webhook',
                'status' => $response->status()
            ];

        } catch (\Exception $e) {
            Log::error('Webhook notification failed', [
                'url' => $webhookUrl,
                'error' => $e->getMessage()
            ]);

            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Get service instance for channel
     */
    protected function getServiceForChannel(NotificationChannel $channel): mixed
    {
        $service = match($channel->type) {
            'slack' => $this->slack,
            'pagerduty' => $this->pagerduty,
            default => null
        };

        if ($service && method_exists($service, 'setChannel')) {
            $service->setChannel($channel);
        }

        return $service;
    }

    /**
     * Check if notification should be suppressed
     */
    protected function shouldSuppress(string $type, mixed $data): bool
    {
        // Don't suppress critical alerts
        if ($type === 'alert' && $data->type === 'critical') {
            return false;
        }

        // Check user preferences
        if ($this->isUserMuted($type)) {
            return true;
        }

        // Apply rules engine suppression rules
        return $this->rulesEngine->shouldSuppress($type, $data);
    }

    /**
     * Check if notification should be grouped
     */
    protected function shouldGroup(string $type, mixed $data): bool
    {
        if ($type !== 'alert') {
            return false;
        }

        // Check for similar alerts in last 5 minutes
        $groupWindow = config('notifications.grouping.window', 300); // 5 minutes
        $threshold = config('notifications.grouping.threshold', 3);

        $cacheKey = $this->getGroupCacheKey($type, $data);
        $count = Cache::get($cacheKey, 0);

        return $count >= $threshold;
    }

    /**
     * Add notification to group
     */
    protected function addToGroup(string $type, mixed $data): void
    {
        $groupWindow = config('notifications.grouping.window', 300);
        $cacheKey = $this->getGroupCacheKey($type, $data);

        Cache::put(
            $cacheKey,
            Cache::get($cacheKey, 0) + 1,
            $groupWindow
        );
    }

    /**
     * Get group cache key
     */
    protected function getGroupCacheKey(string $type, mixed $data): string
    {
        if ($type === 'alert') {
            return sprintf(
                'notification_group:%s:%s:%s',
                $data->source,
                $data->source_id,
                $data->type
            );
        }

        return sprintf('notification_group:%s:%s', $type, $data->id ?? 'unknown');
    }

    /**
     * Get group ID
     */
    protected function getGroupId(string $type, mixed $data): string
    {
        return md5($this->getGroupCacheKey($type, $data));
    }

    /**
     * Check if user has muted notifications
     */
    protected function isUserMuted(string $type): bool
    {
        $user = auth()->user();

        if (!$user) {
            return false;
        }

        $preferences = $user->notification_preferences ?? [];

        return $preferences['muted'][$type] ?? false;
    }

    /**
     * Get notification history
     */
    public function getHistory(array $filters = []): Collection
    {
        $query = NotificationHistory::query();

        if (!empty($filters['channel_type'])) {
            $query->where('channel_type', $filters['channel_type']);
        }

        if (!empty($filters['notification_type'])) {
            $query->where('notification_type', $filters['notification_type']);
        }

        if (!empty($filters['status'])) {
            $query->where('status', $filters['status']);
        }

        if (!empty($filters['source_id'])) {
            $query->where('source_id', $filters['source_id']);
        }

        if (!empty($filters['from_date'])) {
            $query->where('created_at', '>=', $filters['from_date']);
        }

        if (!empty($filters['to_date'])) {
            $query->where('created_at', '<=', $filters['to_date']);
        }

        return $query->orderBy('created_at', 'desc')
            ->limit($filters['limit'] ?? 100)
            ->get();
    }

    /**
     * Get notification statistics
     */
    public function getStatistics(string $period = '24h'): array
    {
        $since = match($period) {
            '1h' => now()->subHour(),
            '24h' => now()->subDay(),
            '7d' => now()->subWeek(),
            '30d' => now()->subMonth(),
            default => now()->subDay()
        };

        $history = NotificationHistory::where('created_at', '>=', $since)->get();

        return [
            'total' => $history->count(),
            'sent' => $history->where('status', 'sent')->count(),
            'failed' => $history->where('status', 'failed')->count(),
            'pending' => $history->where('status', 'pending')->count(),
            'by_channel' => $history->groupBy('channel_type')->map->count(),
            'by_type' => $history->groupBy('notification_type')->map->count(),
            'success_rate' => $history->count() > 0
                ? round(($history->where('status', 'sent')->count() / $history->count()) * 100, 2)
                : 0,
            'average_delivery_time' => $this->calculateAverageDeliveryTime($history),
        ];
    }

    /**
     * Calculate average delivery time
     */
    protected function calculateAverageDeliveryTime(Collection $history): ?float
    {
        $deliveryTimes = $history
            ->filter(fn($item) => $item->sent_at && $item->created_at)
            ->map(fn($item) => $item->created_at->diffInSeconds($item->sent_at));

        if ($deliveryTimes->isEmpty()) {
            return null;
        }

        return round($deliveryTimes->average(), 2);
    }

    /**
     * Flush grouped notifications
     */
    public function flushGroups(): array
    {
        // This would send aggregated notifications for all grouped items
        // Implementation depends on specific requirements

        return [
            'success' => true,
            'groups_flushed' => 0
        ];
    }
}
