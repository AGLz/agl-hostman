<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;

class NotificationService
{
    protected array $channels = [];

    protected array $config;

    public function __construct()
    {
        $this->config = config('notifications', [
            'channels' => [
                'email' => ['enabled' => true],
                'slack' => ['enabled' => true],
                'discord' => ['enabled' => true],
                'telegram' => ['enabled' => true],
                'webhook' => ['enabled' => true],
                'sms' => ['enabled' => false],
            ],
            'priorities' => [
                'critical' => ['email', 'slack', 'sms'],
                'high' => ['email', 'slack'],
                'medium' => ['email'],
                'low' => ['email'],
            ],
        ]);

        $this->initializeChannels();
    }

    /**
     * Initialize notification channels
     */
    protected function initializeChannels(): void
    {
        foreach ($this->config['channels'] as $channel => $settings) {
            if ($settings['enabled'] ?? false) {
                $this->channels[$channel] = true;
            }
        }
    }

    /**
     * Send notification through multiple channels
     */
    public function send(array $notification): array
    {
        $results = [];
        $channels = $this->determineChannels($notification['priority'] ?? 'medium');

        foreach ($channels as $channel) {
            if (! isset($this->channels[$channel])) {
                continue;
            }

            try {
                $method = 'send'.ucfirst($channel);
                if (method_exists($this, $method)) {
                    $results[$channel] = $this->$method($notification);
                }
            } catch (\Exception $e) {
                Log::error("Notification failed for channel {$channel}", [
                    'error' => $e->getMessage(),
                    'notification' => $notification,
                ]);
                $results[$channel] = [
                    'success' => false,
                    'error' => $e->getMessage(),
                ];
            }
        }

        // Store notification in database
        $this->storeNotification($notification, $results);

        return $results;
    }

    /**
     * Send email notification
     */
    protected function sendEmail(array $notification): array
    {
        $to = $notification['to'] ?? config('notifications.default_email');
        $subject = $notification['subject'] ?? 'AGL Infrastructure Notification';
        $content = $notification['content'] ?? '';

        try {
            Mail::raw($content, function ($message) use ($to, $subject) {
                $message->to($to)
                    ->subject($subject)
                    ->priority(1);
            });

            return ['success' => true, 'message' => 'Email sent successfully'];
        } catch (\Exception $e) {
            throw $e;
        }
    }

    /**
     * Send Slack notification
     */
    protected function sendSlack(array $notification): array
    {
        $webhookUrl = config('notifications.slack.webhook_url');

        if (! $webhookUrl) {
            throw new \Exception('Slack webhook URL not configured');
        }

        $payload = [
            'text' => $notification['subject'] ?? 'Infrastructure Alert',
            'attachments' => [
                [
                    'color' => $this->getColorForPriority($notification['priority'] ?? 'medium'),
                    'title' => $notification['title'] ?? 'Alert',
                    'text' => $notification['content'] ?? '',
                    'fields' => $notification['fields'] ?? [],
                    'footer' => 'AGL Infrastructure',
                    'ts' => time(),
                ],
            ],
        ];

        if (isset($notification['channel'])) {
            $payload['channel'] = $notification['channel'];
        }

        $response = Http::post($webhookUrl, $payload);

        if ($response->successful()) {
            return ['success' => true, 'message' => 'Slack notification sent'];
        } else {
            throw new \Exception('Failed to send Slack notification');
        }
    }

    /**
     * Send Discord notification
     */
    protected function sendDiscord(array $notification): array
    {
        $webhookUrl = config('notifications.discord.webhook_url');

        if (! $webhookUrl) {
            throw new \Exception('Discord webhook URL not configured');
        }

        $embed = [
            'title' => $notification['title'] ?? 'Infrastructure Alert',
            'description' => $notification['content'] ?? '',
            'color' => $this->getDiscordColor($notification['priority'] ?? 'medium'),
            'timestamp' => now()->toIso8601String(),
            'footer' => [
                'text' => 'AGL Infrastructure Monitor',
            ],
        ];

        if (isset($notification['fields'])) {
            $embed['fields'] = array_map(function ($field) {
                return [
                    'name' => $field['title'] ?? $field['name'] ?? 'Info',
                    'value' => $field['value'] ?? '',
                    'inline' => $field['inline'] ?? true,
                ];
            }, $notification['fields']);
        }

        $payload = [
            'username' => 'AGL Bot',
            'embeds' => [$embed],
        ];

        $response = Http::post($webhookUrl, $payload);

        if ($response->successful()) {
            return ['success' => true, 'message' => 'Discord notification sent'];
        } else {
            throw new \Exception('Failed to send Discord notification');
        }
    }

    /**
     * Send Telegram notification
     */
    protected function sendTelegram(array $notification): array
    {
        $botToken = config('notifications.telegram.bot_token');
        $chatId = config('notifications.telegram.chat_id');

        if (! $botToken || ! $chatId) {
            throw new \Exception('Telegram bot token or chat ID not configured');
        }

        $text = "*{$notification['title']}*\n\n";
        $text .= $notification['content'] ?? '';

        if (isset($notification['fields'])) {
            $text .= "\n\n";
            foreach ($notification['fields'] as $field) {
                $text .= "*{$field['title']}:* {$field['value']}\n";
            }
        }

        $url = "https://api.telegram.org/bot{$botToken}/sendMessage";

        $response = Http::post($url, [
            'chat_id' => $chatId,
            'text' => $text,
            'parse_mode' => 'Markdown',
        ]);

        if ($response->successful()) {
            return ['success' => true, 'message' => 'Telegram notification sent'];
        } else {
            throw new \Exception('Failed to send Telegram notification');
        }
    }

    /**
     * Send webhook notification
     */
    protected function sendWebhook(array $notification): array
    {
        $webhookUrl = $notification['webhook_url'] ?? config('notifications.webhook.default_url');

        if (! $webhookUrl) {
            throw new \Exception('Webhook URL not provided');
        }

        $headers = $notification['headers'] ?? [];
        $headers['Content-Type'] = 'application/json';

        if ($secret = config('notifications.webhook.secret')) {
            $payload = json_encode($notification);
            $headers['X-Webhook-Signature'] = hash_hmac('sha256', $payload, $secret);
        }

        $response = Http::withHeaders($headers)->post($webhookUrl, $notification);

        if ($response->successful()) {
            return ['success' => true, 'message' => 'Webhook notification sent'];
        } else {
            throw new \Exception('Failed to send webhook notification');
        }
    }

    /**
     * Batch send notifications
     */
    public function sendBatch(array $notifications): array
    {
        $results = [];

        foreach ($notifications as $key => $notification) {
            $results[$key] = $this->send($notification);
        }

        return $results;
    }

    /**
     * Send notification to user
     */
    public function notifyUser(User $user, array $notification): array
    {
        $notification['to'] = $user->email;

        // Add user preferences
        if ($user->notification_preferences) {
            $notification['channels'] = $user->notification_preferences['channels'] ?? [];
        }

        return $this->send($notification);
    }

    /**
     * Send infrastructure alert
     */
    public function sendInfrastructureAlert(array $alert): array
    {
        $notification = [
            'priority' => $this->determineAlertPriority($alert),
            'title' => 'Infrastructure Alert: '.($alert['server'] ?? 'Unknown'),
            'subject' => 'Infrastructure Alert',
            'content' => $this->formatAlertContent($alert),
            'fields' => $this->formatAlertFields($alert),
        ];

        return $this->send($notification);
    }

    /**
     * Send deployment notification
     */
    public function sendDeploymentNotification(array $deployment): array
    {
        $status = $deployment['status'] ?? 'unknown';
        $app = $deployment['application'] ?? 'Unknown';

        $notification = [
            'priority' => $status === 'failed' ? 'high' : 'medium',
            'title' => "Deployment {$status}: {$app}",
            'subject' => 'Deployment Notification',
            'content' => $this->formatDeploymentContent($deployment),
            'fields' => [
                ['title' => 'Application', 'value' => $app],
                ['title' => 'Environment', 'value' => $deployment['environment'] ?? 'production'],
                ['title' => 'Version', 'value' => $deployment['version'] ?? 'latest'],
                ['title' => 'Status', 'value' => ucfirst($status)],
            ],
        ];

        return $this->send($notification);
    }

    /**
     * Determine channels based on priority
     */
    protected function determineChannels(string $priority): array
    {
        return $this->config['priorities'][$priority] ?? ['email'];
    }

    /**
     * Determine alert priority
     */
    protected function determineAlertPriority(array $alert): string
    {
        $severity = $alert['severity'] ?? 'medium';

        $priorityMap = [
            'critical' => 'critical',
            'high' => 'high',
            'medium' => 'medium',
            'low' => 'low',
            'warning' => 'medium',
            'error' => 'high',
        ];

        return $priorityMap[$severity] ?? 'medium';
    }

    /**
     * Format alert content
     */
    protected function formatAlertContent(array $alert): string
    {
        $content = "An infrastructure alert has been triggered.\n\n";

        if (isset($alert['message'])) {
            $content .= "Message: {$alert['message']}\n";
        }

        if (isset($alert['details'])) {
            $content .= "\nDetails:\n";
            foreach ($alert['details'] as $key => $value) {
                $content .= "  - {$key}: {$value}\n";
            }
        }

        $content .= "\nTimestamp: ".now()->toIso8601String();

        return $content;
    }

    /**
     * Format alert fields
     */
    protected function formatAlertFields(array $alert): array
    {
        $fields = [];

        if (isset($alert['server'])) {
            $fields[] = ['title' => 'Server', 'value' => $alert['server']];
        }

        if (isset($alert['severity'])) {
            $fields[] = ['title' => 'Severity', 'value' => ucfirst($alert['severity'])];
        }

        if (isset($alert['type'])) {
            $fields[] = ['title' => 'Type', 'value' => $alert['type']];
        }

        if (isset($alert['metrics'])) {
            foreach ($alert['metrics'] as $metric => $value) {
                $fields[] = ['title' => ucfirst($metric), 'value' => $value];
            }
        }

        return $fields;
    }

    /**
     * Format deployment content
     */
    protected function formatDeploymentContent(array $deployment): string
    {
        $content = 'Deployment '.($deployment['status'] ?? 'update').":\n\n";

        if (isset($deployment['message'])) {
            $content .= $deployment['message']."\n\n";
        }

        if (isset($deployment['commit'])) {
            $content .= "Commit: {$deployment['commit']}\n";
        }

        if (isset($deployment['branch'])) {
            $content .= "Branch: {$deployment['branch']}\n";
        }

        if (isset($deployment['user'])) {
            $content .= "Deployed by: {$deployment['user']}\n";
        }

        $content .= "\nTimestamp: ".now()->toIso8601String();

        return $content;
    }

    /**
     * Get color for priority (Slack)
     */
    protected function getColorForPriority(string $priority): string
    {
        $colors = [
            'critical' => '#FF0000',
            'high' => '#FF6600',
            'medium' => '#FFCC00',
            'low' => '#00CC00',
        ];

        return $colors[$priority] ?? '#808080';
    }

    /**
     * Get Discord color
     */
    protected function getDiscordColor(string $priority): int
    {
        $colors = [
            'critical' => 0xFF0000,
            'high' => 0xFF6600,
            'medium' => 0xFFCC00,
            'low' => 0x00CC00,
        ];

        return $colors[$priority] ?? 0x808080;
    }

    /**
     * Store notification in database
     */
    protected function storeNotification(array $notification, array $results): void
    {
        try {
            \DB::table('notifications')->insert([
                'type' => $notification['type'] ?? 'general',
                'priority' => $notification['priority'] ?? 'medium',
                'title' => $notification['title'] ?? '',
                'content' => json_encode($notification),
                'channels' => json_encode(array_keys($results)),
                'results' => json_encode($results),
                'created_at' => now(),
            ]);
        } catch (\Exception $e) {
            Log::error('Failed to store notification', [
                'error' => $e->getMessage(),
            ]);
        }
    }

    /**
     * Get notification statistics
     */
    public function getStatistics(string $period = '24h'): array
    {
        $since = match ($period) {
            '1h' => now()->subHour(),
            '24h' => now()->subDay(),
            '7d' => now()->subWeek(),
            '30d' => now()->subMonth(),
            default => now()->subDay(),
        };

        $stats = \DB::table('notifications')
            ->where('created_at', '>=', $since)
            ->selectRaw('priority, COUNT(*) as count')
            ->groupBy('priority')
            ->get();

        return [
            'period' => $period,
            'total' => $stats->sum('count'),
            'by_priority' => $stats->pluck('count', 'priority')->toArray(),
            'since' => $since->toIso8601String(),
        ];
    }
}
