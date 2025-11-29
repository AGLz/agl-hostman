<?php

namespace App\Console;

use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Console\Kernel as ConsoleKernel;

class Kernel extends ConsoleKernel
{
    /**
     * The Artisan commands provided by your application.
     *
     * @var array
     */
    protected $commands = [
        \App\Console\Commands\NotificationsSetup::class,
        \App\Console\Commands\NotificationsTest::class,
        \App\Console\Commands\OnCallRotate::class,
        \App\Console\Commands\OnCallCurrent::class,
    ];

    /**
     * Define the application's command schedule.
     */
    protected function schedule(Schedule $schedule): void
    {
        // Check for on-call rotations every hour
        $schedule->command('oncall:current')
            ->hourly()
            ->appendOutputTo(storage_path('logs/oncall.log'));

        // Daily summary at 9 AM
        $schedule->call(function () {
            // Send daily notification summary
        })->dailyAt('09:00');
    }

    /**
     * Register the commands for the application.
     */
    protected function commands(): void
    {
        $this->load(__DIR__.'/Commands');

        require base_path('routes/console.php');
    }
}
