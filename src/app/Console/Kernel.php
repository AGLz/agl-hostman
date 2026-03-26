<?php

namespace App\Console;

use App\Jobs\BackupJob;
use App\Jobs\CleanupJob;
use App\Jobs\ContainerHealthCheckJob;
use App\Jobs\MetricsCollectionJob;
use App\Jobs\NotificationJob;
use App\Jobs\SecurityScanJob;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Console\Kernel as ConsoleKernel;

class Kernel extends ConsoleKernel
{
    /**
     * The Artisan commands provided by the application.
     *
     * @var array
     */
    protected $commands = [
        \App\Console\Commands\NotificationsSetup::class,
        \App\Console\Commands\NotificationsTest::class,
        \App\Console\Commands\OnCallRotate::class,
        \App\Console\Commands\OnCallCurrent::class,
        \App\Console\Commands\QueueCheckCommand::class,
        \App\Console\Commands\QueueFlushCommand::class,
        \App\Console\Commands\QueueRetryCommand::class,
    ];

    /**
     * Define the application's command schedule.
     */
    protected function schedule(Schedule $schedule): void
    {
        // ============================================
        // HEALTH CHECKS - High Frequency
        // ============================================

        // Container health checks - every minute
        $schedule->job(new ContainerHealthCheckJob)
            ->everyMinute()
            ->onQueue('health-checks')
            ->withoutOverlapping()
            ->description('Container health monitoring');

        // Quick health check - every 30 seconds
        $schedule->job(new ContainerHealthCheckJob(null, false))
            ->everyThirtySeconds()
            ->onQueue('health-checks')
            ->withoutOverlapping()
            ->description('Quick container health ping');

        // ============================================
        // METRICS COLLECTION - Medium Frequency
        // ============================================

        // Full metrics collection - every 5 minutes
        $schedule->job(new MetricsCollectionJob('full', true))
            ->everyFiveMinutes()
            ->onQueue('metrics-collection')
            ->withoutOverlapping()
            ->description('Full metrics collection and aggregation');

        // Quick metrics collection - every 2 minutes
        $schedule->job(new MetricsCollectionJob('quick', false))
            ->everyTwoMinutes()
            ->onQueue('metrics-collection')
            ->withoutOverlapping()
            ->description('Quick metrics collection (CPU/Memory/Disk)');

        // Container metrics - every 3 minutes
        $schedule->job(new MetricsCollectionJob('containers', false))
            ->everyThreeMinutes()
            ->onQueue('metrics-collection')
            ->withoutOverlapping()
            ->description('Container-specific metrics collection');

        // ============================================
        // SECURITY SCANS - Lower Frequency
        // ============================================

        // Quick vulnerability scan - every hour
        $schedule->job(new SecurityScanJob('vulnerability', 'all', true))
            ->hourly()
            ->onQueue('security-scans')
            ->withoutOverlapping()
            ->description('Hourly vulnerability scan');

        // Compliance check - every 6 hours
        $schedule->job(new SecurityScanJob('compliance', 'all', true))
            ->everySixHours()
            ->onQueue('security-scans')
            ->withoutOverlapping()
            ->description('Security compliance check');

        // Full security scan - daily at 2 AM
        $schedule->job(new SecurityScanJob('full', 'all', true))
            ->dailyAt('02:00')
            ->onQueue('security-scans')
            ->withoutOverlapping()
            ->description('Daily comprehensive security scan');

        // Configuration audit - daily at 3 AM
        $schedule->job(new SecurityScanJob('configuration', 'all', true))
            ->dailyAt('03:00')
            ->onQueue('security-scans')
            ->withoutOverlapping()
            ->description('Daily security configuration audit');

        // ============================================
        // BACKUPS - Scheduled Based on Priority
        // ============================================

        // Critical containers backup - every 6 hours
        $schedule->job(new BackupJob('full', 'all', null, 7, true))
            ->everySixHours()
            ->onQueue('backups')
            ->withoutOverlapping()
            ->description('Critical containers backup');

        // Daily full backup - at 1 AM
        $schedule->job(new BackupJob('full', 'all', null, 30, true))
            ->dailyAt('01:00')
            ->onQueue('backups')
            ->withoutOverlapping()
            ->description('Daily full backup');

        // Weekly backup - Sunday at 2 AM
        $schedule->job(new BackupJob('full', 'all', null, 90, true))
            ->weeklyOn(0, '02:00')
            ->onQueue('backups')
            ->withoutOverlapping()
            ->description('Weekly full backup');

        // ============================================
        // CLEANUP TASKS - Low Frequency
        // ============================================

        // Log cleanup - daily at 4 AM
        $schedule->job(new CleanupJob('logs', 30, false))
            ->dailyAt('04:00')
            ->onQueue('cleanup')
            ->withoutOverlapping()
            ->description('Daily log cleanup (30-day retention)');

        // Database cleanup - daily at 5 AM
        $schedule->job(new CleanupJob('database', 7, false))
            ->dailyAt('05:00')
            ->onQueue('cleanup')
            ->withoutOverlapping()
            ->description('Daily database cleanup and optimization');

        // Backup cleanup - weekly on Sunday at 3 AM
        $schedule->job(new CleanupJob('backups', 90, false))
            ->weeklyOn(0, '03:00')
            ->onQueue('cleanup')
            ->withoutOverlapping()
            ->description('Weekly old backup cleanup (90-day retention)');

        // Snapshot cleanup - daily at 6 AM
        $schedule->job(new CleanupJob('snapshots', 7, false))
            ->dailyAt('06:00')
            ->onQueue('cleanup')
            ->withoutOverlapping()
            ->description('Daily old snapshot cleanup (7-day retention)');

        // ============================================
        // NOTIFICATIONS & ALERTS - Ongoing
        // ============================================

        // Check for on-call rotations every hour
        $schedule->command('oncall:current')
            ->hourly()
            ->appendOutputTo(storage_path('logs/oncall.log'));

        // Daily summary at 9 AM
        $schedule->call(function () {
            // Send daily notification summary
            NotificationJob::dispatch(
                'daily_summary',
                ['title' => 'Daily System Summary'],
                null,
                null,
                'normal'
            );
        })->dailyAt('09:00');

        // Weekly summary - Monday at 9 AM
        $schedule->call(function () {
            NotificationJob::dispatch(
                'weekly_summary',
                ['title' => 'Weekly System Summary'],
                null,
                null,
                'low'
            );
        })->weeklyOn(1, '09:00');

        // ============================================
        // SYSTEM MAINTENANCE
        // ============================================

        // Horizon metrics pruning - every 30 minutes
        $schedule->command('horizon:snapshot')
            ->everyThirtyMinutes()
            ->withoutOverlapping()
            ->description('Horizon performance snapshot');

        // Clear stale cache entries - every hour
        $schedule->command('cache:prune-stale-tags')
            ->hourly()
            ->description('Prune stale cache tags');

        // Queue monitoring - every 5 minutes
        $schedule->call(function () {
            $failedJobs = \Illuminate\Support\Facades\DB::table('failed_jobs')->count();
            if ($failedJobs > 100) {
                NotificationJob::dispatch(
                    'queue_backlog',
                    [
                        'title' => 'High Failed Job Count',
                        'message' => "There are currently {$failedJobs} failed jobs.",
                        'failed_count' => $failedJobs,
                    ],
                    null,
                    null,
                    'high'
                );
            }
        })->everyFiveMinutes();

        // ============================================
        // ENVIRONMENT-SPECIFIC SCHEDULES
        // ============================================

        if (config('app.env') === 'production') {
            // Production-only: Enable all monitoring
            $schedule->command('monitor:check')->everyMinute();
        }

        if (config('app.env') === 'local' || config('app.env') === 'staging') {
            // Development: Less frequent checks
            $schedule->job(new ContainerHealthCheckJob)
                ->everyTenMinutes()
                ->onQueue('health-checks');
        }
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
