<?php

namespace App\Console\Commands;

use App\Models\NotificationChannel;
use App\Services\Notifications\NotificationManager;
use Illuminate\Console\Command;

class NotificationsTest extends Command
{
    protected $signature = 'notifications:test {channel} {--message=Test notification}';

    protected $description = 'Test notification delivery to specified channel';

    public function __construct(
        private NotificationManager $notificationManager
    ) {
        parent::__construct();
    }

    public function handle(): int
    {
        $channel = NotificationChannel::findOrFail($this->argument('channel'));

        $this->info("Testing notification channel: {$channel->name}");

        try {
            $this->notificationManager->send([
                'type' => 'test',
                'title' => 'Test Notification',
                'message' => $this->option('message'),
                'severity' => 'info',
                'channels' => [$channel->type],
                'data' => [
                    'test' => true,
                    'timestamp' => now()->toIso8601String(),
                ],
            ]);

            $this->info('✅ Test notification sent successfully');

            return self::SUCCESS;
        } catch (\Exception $e) {
            $this->error("❌ Test notification failed: {$e->getMessage()}");

            return self::FAILURE;
        }
    }
}
