<?php

namespace App\Console\Commands;

use App\Models\NotificationChannel;
use Illuminate\Console\Command;

class NotificationsSetup extends Command
{
    protected $signature = 'notifications:setup';

    protected $description = 'Interactive wizard for setting up notification channels';

    public function handle(): int
    {
        $this->info('=== Notification System Setup ===');
        $this->newLine();

        if (! $this->confirm('Do you want to setup a Slack channel?', true)) {
            return self::SUCCESS;
        }

        // Slack setup
        $slackWebhook = $this->ask('Enter Slack webhook URL');
        $slackChannel = $this->ask('Enter Slack channel (optional)', '#deployments');

        $channel = NotificationChannel::create([
            'name' => 'Slack - Deployments',
            'type' => 'slack',
            'config' => [
                'webhook_url' => $slackWebhook,
                'channel' => $slackChannel,
            ],
            'enabled' => true,
        ]);

        $this->info("✅ Slack channel created: {$channel->name}");

        // Test notification
        if ($this->confirm('Send test notification?', true)) {
            $this->call('notifications:test', [
                'channel' => $channel->id,
                '--message' => 'Test notification from AGL-HOSTMAN',
            ]);
        }

        return self::SUCCESS;
    }
}
