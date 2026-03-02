<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

use Illuminate\Support\Facades\Schedule;
use App\Jobs\MonitorInfrastructure;
use App\Jobs\PerformBackup;

// Schedule infrastructure monitoring every 5 minutes
Schedule::job(new MonitorInfrastructure(
    ['AGLSRV1', 'AGLSRV2', 'AGLSRV3', 'AGLSRV4', 'AGLSRV5', 'AGLSRV6']
))->everyFiveMinutes()
  ->name('infrastructure-monitoring')
  ->withoutOverlapping()
  ->onOneServer();

// Schedule daily full backup at 2 AM
Schedule::job(new PerformBackup('full', true))
    ->dailyAt('02:00')
    ->name('daily-full-backup')
    ->withoutOverlapping()
    ->onOneServer();

// Schedule hourly database backup
Schedule::job(new PerformBackup('database', false))
    ->hourly()
    ->name('hourly-database-backup')
    ->withoutOverlapping()
    ->onOneServer();

// Schedule weekly config backup on Sundays
Schedule::job(new PerformBackup('config', true))
    ->weeklyOn(0, '03:00')
    ->name('weekly-config-backup')
    ->withoutOverlapping()
    ->onOneServer();

// Clean old backups daily
Schedule::command('backup:clean')
    ->dailyAt('04:00')
    ->name('clean-old-backups')
    ->withoutOverlapping();

// Generate analytics report weekly
Schedule::command('analytics:report')
    ->weeklyOn(1, '08:00') // Monday at 8 AM
    ->name('weekly-analytics-report')
    ->withoutOverlapping();
