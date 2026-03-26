<?php

namespace App\Services;

use App\Mail\CriticalAlertMail;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;

/**
 * Alert Dispatcher Service
 *
 * Dispatches alerts to multiple channels (Slack, Discord, Email) based on
 * severity levels and channel configuration.
 *
 * Features:
 * - Multi-channel alert routing
 * - Severity-based filtering
 * - Rate limiting to prevent spam
 * - Retry logic for failed dispatches
 * - Alert aggregation
 */
class AlertDispatcher
{
    /**
     * Channel configurations
     */
    protected array $channels = [];

    /**
     * Alert rate limits (per channel, per hour)
     */
    protected array $rateLimits = [
        'slack' => 20,
        'discord' => 30,
        'email' => 10,
    ];

    /**
     * Severity to channel mapping
     */
    protected array $severityChannels = [
        'critical' => ['slack', 'discord', 'email'],
        'warning' => ['slack', 'discord'],
        'info' => ['slack'],
    ];

    public function __construct()
    {
        $this->loadChannelConfigurations();
    }

    /**
     * Dispatch alert to configured channels
     *
     * @param  string  $alertType  Alert type identifier
     * @param  array  $data  Alert data
     * @param  string  $severity  Severity level (critical, warning, info)
     * @return array Dispatch results
     */
    public function dispatch(string $alertType, array $data, string $severity = 'info'): array
    {
        $channels = $this->getChannelsForSeverity($severity);
        $results = [];

        foreach ($channels as $channel) {
            if ($this->isRateLimited($channel)) {
                Log::warning("Rate limit exceeded for channel: {$channel}");
                $results[$channel] = ['success' => false, 'reason' => 'rate_limited'];

                continue;
            }

            try {
                $success = $this->dispatchToChannel($channel, $alertType, $data, $severity);
                $results[$channel] = ['success' => $success];

                if ($success) {
                    $this->incrementRateLimit($channel);
                }
            } catch (\Exception $e) {
                Log::error("Failed to dispatch to {$channel}: {$e->getMessage()}");
                $results[$channel] = ['success' => false, 'error' => $e->getMessage()];
            }
        }

        return $results;
    }

    /**
     * Dispatch alert to specific channel
     *
     * @param  string  $channel  Channel name
     * @param  string  $alertType  Alert type
     * @param  array  $data  Alert data
     * @param  string  $severity  Severity level
     * @return bool Success status
     */
    protected function dispatchToChannel(string $channel, string $alertType, array $data, string $severity): bool
    {
        return match ($channel) {
            'slack' => $this->dispatchToSlack($alertType, $data, $severity),
            'discord' => $this->dispatchToDiscord($alertType, $data, $severity),
            'email' => $this->dispatchToEmail($alertType, $data, $severity),
            default => false,
        };
    }

    /**
     * Dispatch alert to Slack
     *
     * @param  string  $alertType  Alert type
     * @param  array  $data  Alert data
     * @param  string  $severity  Severity level
     * @return bool Success status
     */
    protected function dispatchToSlack(string $alertType, array $data, string $severity): bool
    {
        $webhookUrl = $this->channels['slack']['webhook_url'] ?? null;

        if (! $webhookUrl) {
            Log::warning('Slack webhook URL not configured');

            return false;
        }

        $color = $this->getSeverityColor($severity);
        $emoji = $this->getSeverityEmoji($severity);

        $message = [
            'username' => 'Infrastructure Monitor',
            'icon_emoji' => ':robot_face:',
            'attachments' => [
                [
                    'color' => $color,
                    'title' => "{$emoji} {$this->formatAlertTitle($alertType, $severity)}",
                    'text' => $this->formatAlertMessage($data),
                    'fields' => $this->formatAlertFields($data),
                    'footer' => 'AGL Infrastructure Monitor',
                    'ts' => now()->timestamp,
                ],
            ],
        ];

        $response = Http::post($webhookUrl, $message);

        return $response->successful();
    }

    /**
     * Dispatch alert to Discord
     *
     * @param  string  $alertType  Alert type
     * @param  array  $data  Alert data
     * @param  string  $severity  Severity level
     * @return bool Success status
     */
    protected function dispatchToDiscord(string $alertType, array $data, string $severity): bool
    {
        $webhookUrl = $this->channels['discord']['webhook_url'] ?? null;

        if (! $webhookUrl) {
            Log::warning('Discord webhook URL not configured');

            return false;
        }

        $color = hexdec(str_replace('#', '', $this->getSeverityColor($severity)));
        $emoji = $this->getSeverityEmoji($severity);

        $message = [
            'username' => 'Infrastructure Monitor',
            'avatar_url' => 'https://cdn-icons-png.flaticon.com/512/2311/2311524.png',
            'embeds' => [
                [
                    'title' => "{$emoji} {$this->formatAlertTitle($alertType, $severity)}",
                    'description' => $this->formatAlertMessage($data),
                    'color' => $color,
                    'fields' => $this->formatDiscordFields($data),
                    'footer' => [
                        'text' => 'AGL Infrastructure Monitor',
                    ],
                    'timestamp' => now()->toIso8601String(),
                ],
            ],
        ];

        $response = Http::post($webhookUrl, $message);

        return $response->successful();
    }

    /**
     * Dispatch alert to Email
     *
     * @param  string  $alertType  Alert type
     * @param  array  $data  Alert data
     * @param  string  $severity  Severity level
     * @return bool Success status
     */
    protected function dispatchToEmail(string $alertType, array $data, string $severity): bool
    {
        $recipients = $this->channels['email']['recipients'] ?? [];

        if (empty($recipients)) {
            Log::warning('No email recipients configured');

            return false;
        }

        try {
            foreach ($recipients as $recipient) {
                Mail::to($recipient)->send(new CriticalAlertMail($alertType, $data, $severity));
            }

            return true;
        } catch (\Exception $e) {
            Log::error("Failed to send email: {$e->getMessage()}");

            return false;
        }
    }

    /**
     * Get channels for severity level
     *
     * @param  string  $severity  Severity level
     * @return array Channels
     */
    protected function getChannelsForSeverity(string $severity): array
    {
        return $this->severityChannels[$severity] ?? ['slack'];
    }

    /**
     * Check if channel is rate limited
     *
     * @param  string  $channel  Channel name
     * @return bool Is rate limited
     */
    protected function isRateLimited(string $channel): bool
    {
        $cacheKey = "alert_rate_limit:{$channel}";
        $count = Cache::get($cacheKey, 0);
        $limit = $this->rateLimits[$channel] ?? 10;

        return $count >= $limit;
    }

    /**
     * Increment rate limit counter
     *
     * @param  string  $channel  Channel name
     */
    protected function incrementRateLimit(string $channel): void
    {
        $cacheKey = "alert_rate_limit:{$channel}";
        $count = Cache::get($cacheKey, 0);
        Cache::put($cacheKey, $count + 1, now()->addHour());
    }

    /**
     * Format alert title
     *
     * @param  string  $alertType  Alert type
     * @param  string  $severity  Severity level
     * @return string Formatted title
     */
    protected function formatAlertTitle(string $alertType, string $severity): string
    {
        $titles = [
            'container_critical' => 'Container Critical Alert',
            'resource_exhaustion' => 'Resource Exhaustion Predicted',
            'service_failure' => 'Service Failure Detected',
            'anomaly_detected' => 'Anomaly Detected',
        ];

        $title = $titles[$alertType] ?? 'Infrastructure Alert';

        return "{$title} - ".strtoupper($severity);
    }

    /**
     * Format alert message
     *
     * @param  array  $data  Alert data
     * @return string Formatted message
     */
    protected function formatAlertMessage(array $data): string
    {
        $message = '';

        if (isset($data['node'])) {
            $message .= "**Node:** {$data['node']}\n";
        }

        if (isset($data['container'])) {
            $message .= "**Container:** {$data['container']} (VMID: {$data['vmid']})\n";
        }

        if (isset($data['issues']) && is_array($data['issues'])) {
            $message .= "\n**Issues:**\n";
            foreach ($data['issues'] as $issue) {
                $message .= "• {$issue}\n";
            }
        }

        return $message;
    }

    /**
     * Format alert fields for Slack
     *
     * @param  array  $data  Alert data
     * @return array Formatted fields
     */
    protected function formatAlertFields(array $data): array
    {
        $fields = [];

        if (isset($data['metrics'])) {
            foreach ($data['metrics'] as $metric => $value) {
                $fields[] = [
                    'title' => ucfirst(str_replace('_', ' ', $metric)),
                    'value' => is_numeric($value) ? round($value, 2) : $value,
                    'short' => true,
                ];
            }
        }

        return $fields;
    }

    /**
     * Format alert fields for Discord
     *
     * @param  array  $data  Alert data
     * @return array Formatted fields
     */
    protected function formatDiscordFields(array $data): array
    {
        $fields = [];

        if (isset($data['metrics'])) {
            foreach ($data['metrics'] as $metric => $value) {
                $fields[] = [
                    'name' => ucfirst(str_replace('_', ' ', $metric)),
                    'value' => is_numeric($value) ? round($value, 2) : $value,
                    'inline' => true,
                ];
            }
        }

        return $fields;
    }

    /**
     * Get severity color
     *
     * @param  string  $severity  Severity level
     * @return string Hex color code
     */
    protected function getSeverityColor(string $severity): string
    {
        return match ($severity) {
            'critical' => '#dc3545', // Red
            'warning' => '#ffc107',  // Yellow
            'info' => '#17a2b8',     // Blue
            default => '#6c757d',    // Gray
        };
    }

    /**
     * Get severity emoji
     *
     * @param  string  $severity  Severity level
     * @return string Emoji
     */
    protected function getSeverityEmoji(string $severity): string
    {
        return match ($severity) {
            'critical' => '🚨',
            'warning' => '⚠️',
            'info' => 'ℹ️',
            default => '📢',
        };
    }

    /**
     * Load channel configurations
     */
    protected function loadChannelConfigurations(): void
    {
        $this->channels = [
            'slack' => [
                'enabled' => config('alerts.slack.enabled', false),
                'webhook_url' => config('alerts.slack.webhook_url'),
            ],
            'discord' => [
                'enabled' => config('alerts.discord.enabled', false),
                'webhook_url' => config('alerts.discord.webhook_url'),
            ],
            'email' => [
                'enabled' => config('alerts.email.enabled', false),
                'recipients' => config('alerts.email.recipients', []),
            ],
        ];
    }

    /**
     * Send aggregated alerts (batch multiple alerts)
     *
     * @param  array  $alerts  Array of alerts
     * @param  string  $channel  Channel name
     * @return bool Success status
     */
    public function sendAggregatedAlerts(array $alerts, string $channel): bool
    {
        if (empty($alerts)) {
            return true;
        }

        $aggregatedData = [
            'count' => count($alerts),
            'alerts' => $alerts,
            'timestamp' => now()->toIso8601String(),
        ];

        return $this->dispatchToChannel($channel, 'aggregated_alerts', $aggregatedData, 'warning');
    }

    /**
     * Test alert configuration
     *
     * @param  string  $channel  Channel to test
     * @return array Test results
     */
    public function testChannel(string $channel): array
    {
        $testData = [
            'node' => 'test-node',
            'container' => 'test-container',
            'vmid' => 999,
            'issues' => ['This is a test alert'],
            'metrics' => [
                'cpu_percent' => 50.0,
                'memory_percent' => 60.0,
            ],
        ];

        try {
            $success = $this->dispatchToChannel($channel, 'test_alert', $testData, 'info');

            return [
                'success' => $success,
                'message' => $success ? "Test alert sent to {$channel}" : "Failed to send to {$channel}",
            ];
        } catch (\Exception $e) {
            return [
                'success' => false,
                'message' => "Error: {$e->getMessage()}",
            ];
        }
    }
}
