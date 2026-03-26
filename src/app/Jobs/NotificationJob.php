<?php

namespace App\Jobs;

use App\Models\Alert;
use App\Models\NotificationChannel;
use App\Models\NotificationRule;
use App\Services\Notification\NotificationManager;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

/**
 * Notification Job
 *
 * Sends notifications across multiple channels (email, Slack, PagerDuty, etc.)
 * Handles notification delivery, retries, and failure tracking.
 */
class NotificationJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    /**
     * Job timeout (seconds)
     */
    public int $timeout = 120;

    /**
     * Number of retry attempts
     */
    public int $tries = 5;

    /**
     * Exponential backoff (base delay in seconds)
     */
    public int $backoff = 30;

    /**
     * Notification type
     */
    protected string $type;

    /**
     * Notification data/payload
     */
    protected array $data;

    /**
     * Target channels (null = use default routing)
     */
    protected ?array $channels;

    /**
     * Alert ID if notification is for an alert
     */
    protected ?int $alertId;

    /**
     * Priority level: 'low', 'normal', 'high', 'urgent'
     */
    protected string $priority;

    /**
     * Create a new job instance.
     */
    public function __construct(
        string $type,
        array $data = [],
        ?array $channels = null,
        ?int $alertId = null,
        string $priority = 'normal'
    ) {
        $this->type = $type;
        $this->data = $data;
        $this->channels = $channels;
        $this->alertId = $alertId;
        $this->priority = $priority;

        // Notifications go on dedicated queue
        $this->onQueue('notifications');

        // Set timeout based on priority
        if ($this->priority === 'urgent') {
            $this->onQueue('critical');
        }
    }

    /**
     * Execute the job.
     */
    public function handle(NotificationManager $notificationManager): void
    {
        $startTime = microtime(true);

        Log::info('Processing notification job', [
            'type' => $this->type,
            'priority' => $this->priority,
            'alert_id' => $this->alertId,
            'channels' => $this->channels,
        ]);

        try {
            // Determine target channels
            $targetChannels = $this->channels ?? $this->getDefaultChannels();

            if (empty($targetChannels)) {
                Log::warning('No notification channels configured', [
                    'type' => $this->type,
                ]);

                return;
            }

            $results = [];

            // Send to each channel
            foreach ($targetChannels as $channel) {
                try {
                    $result = $this->sendToChannel($notificationManager, $channel);
                    $results[$channel] = $result;
                } catch (\Exception $e) {
                    Log::error('Failed to send notification to channel', [
                        'channel' => $channel,
                        'error' => $e->getMessage(),
                    ]);
                    $results[$channel] = [
                        'success' => false,
                        'error' => $e->getMessage(),
                    ];
                }
            }

            $duration = round(microtime(true) - $startTime, 2);

            $successCount = count(array_filter($results, fn ($r) => $r['success'] ?? false));

            Log::info('Notification job completed', [
                'type' => $this->type,
                'channels_sent' => $successCount,
                'channels_failed' => count($results) - $successCount,
                'duration' => $duration,
            ]);

            // Mark alert as notified if applicable
            if ($this->alertId && $successCount > 0) {
                Alert::where('id', $this->alertId)->update([
                    'notified_at' => now(),
                    'notification_status' => 'sent',
                ]);
            }

        } catch (\Exception $e) {
            Log::error('Notification job failed', [
                'type' => $this->type,
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
            ]);

            throw $e;
        }
    }

    /**
     * Get default channels based on notification type
     */
    protected function getDefaultChannels(): array
    {
        $rule = NotificationRule::where('event_type', $this->type)
            ->where('is_active', true)
            ->first();

        if ($rule) {
            return $rule->channels->pluck('type')->toArray();
        }

        // Fallback to system defaults
        return match ($this->priority) {
            'urgent', 'high' => ['slack', 'pagerduty', 'email'],
            'normal' => ['slack', 'email'],
            'low' => ['email'],
            default => ['email'],
        };
    }

    /**
     * Send notification to specific channel
     */
    protected function sendToChannel(NotificationManager $manager, string $channel): array
    {
        $channelConfig = NotificationChannel::where('type', $channel)
            ->where('is_active', true)
            ->first();

        if (! $channelConfig) {
            return [
                'success' => false,
                'error' => 'Channel not configured or inactive',
            ];
        }

        // Prepare notification payload
        $payload = [
            'type' => $this->type,
            'priority' => $this->priority,
            'title' => $this->data['title'] ?? $this->getDefaultTitle(),
            'message' => $this->data['message'] ?? '',
            'metadata' => $this->data,
            'alert_id' => $this->alertId,
        ];

        // Send via notification manager
        return $manager->send($channel, $payload);
    }

    /**
     * Get default title based on notification type
     */
    protected function getDefaultTitle(): string
    {
        return match ($this->type) {
            'alert_critical' => 'Critical Alert',
            'alert_high' => 'High Priority Alert',
            'backup_success' => 'Backup Completed',
            'backup_failed' => 'Backup Failed',
            'deployment_success' => 'Deployment Successful',
            'deployment_failed' => 'Deployment Failed',
            'security_scan_complete' => 'Security Scan Completed',
            'security_vulnerability' => 'Security Vulnerability Detected',
            'container_down' => 'Container Down',
            'server_unreachable' => 'Server Unreachable',
            default => 'System Notification',
        };
    }

    /**
     * Calculate exponential backoff
     */
    public function backoff(): array
    {
        // Exponential backoff: 30s, 60s, 120s, 240s, 480s
        return [
            30,
            60,
            120,
            240,
            480,
        ];
    }

    /**
     * Handle job failure.
     */
    public function failed(\Throwable $exception): void
    {
        Log::critical('Notification job failed permanently', [
            'type' => $this->type,
            'priority' => $this->priority,
            'alert_id' => $this->alertId,
            'error' => $exception->getMessage(),
            'trace' => $exception->getTraceAsString(),
        ]);

        // Update alert notification status
        if ($this->alertId) {
            Alert::where('id', $this->alertId)->update([
                'notification_status' => 'failed',
                'notification_error' => $exception->getMessage(),
            ]);
        }
    }

    /**
     * Get the tags that should be assigned to the job.
     */
    public function tags(): array
    {
        return array_filter([
            'notification',
            $this->type,
            $this->priority,
            $this->channels ? implode(',', $this->channels) : null,
        ]);
    }
}
