<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use App\Jobs\MonitorInfrastructure;
use App\Jobs\PcGamer\FetchMarketPricesJob;
use App\Jobs\PcGamer\SyncTmeOffersJob;
use App\Jobs\PcGamer\ValidateTelegramOffersJob;
use App\Jobs\PerformBackup;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

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

// PC Gamer — fetch diário de preços de mercado (08:00 BRT)
Schedule::job(new FetchMarketPricesJob(allCategories: true))
    ->dailyAt('08:00')
    ->timezone('America/Sao_Paulo')
    ->name('pcg-daily-market-fetch')
    ->withoutOverlapping()
    ->onOneServer();

// PC Gamer — sync Telegram t.me/s/ a cada 15 min
Schedule::job(new SyncTmeOffersJob)
    ->everyFifteenMinutes()
    ->name('pcg-tme-sync')
    ->withoutOverlapping()
    ->onOneServer();

// PC Gamer — validação de ofertas a cada 30 min
Schedule::job(new ValidateTelegramOffersJob)
    ->everyThirtyMinutes()
    ->name('pcg-telegram-validate')
    ->withoutOverlapping()
    ->onOneServer();
