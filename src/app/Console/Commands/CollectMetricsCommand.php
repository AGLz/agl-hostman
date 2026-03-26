<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Services\AlertService;
use App\Services\MonitoringService;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Cache;

/**
 * CollectMetricsCommand - Scheduled metrics collection command
 *
 * Collects infrastructure metrics, evaluates alerts, and records trends.
 * Designed to be run via Laravel scheduler every minute.
 */
class CollectMetricsCommand extends Command
{
    protected $signature = 'monitoring:collect {--force : Force collection regardless of interval}';

    protected $description = 'Collect infrastructure metrics and generate alerts';

    protected MonitoringService $monitoringService;

    protected AlertService $alertService;

    public function __construct(MonitoringService $monitoringService, AlertService $alertService)
    {
        parent::__construct();
        $this->monitoringService = $monitoringService;
        $this->alertService = $alertService;
    }

    public function handle(): int
    {
        $this->info('Starting metrics collection...');
        $startTime = microtime(true);

        // Check if collection is needed (unless forced)
        if (! $this->option('force')) {
            $lastCollection = Cache::get('monitoring:last_collection_time');
            $collectionInterval = (int) config('monitoring.collection_interval', 60);

            if ($lastCollection && now()->diffInSeconds($lastCollection) < $collectionInterval) {
                $this->info('Metrics collection skipped (interval not elapsed)');
                $this->info("Last collection: {$lastCollection->toIso8601String()}");
                $this->info("Next collection: {$lastCollection->addSeconds($collectionInterval)->toIso8601String()}");

                return self::SUCCESS;
            }
        }

        // Perform collection
        $result = $this->monitoringService->collectAndMonitor();

        // Update last collection time
        Cache::put('monitoring:last_collection_time', now());

        // Display results
        $this->newLine();
        $this->info('Metrics Collection Results:');
        $this->table(
            ['Metric', 'Value'],
            [
                ['Success', $result['success'] ? '✓' : '✗'],
                ['Metrics Collected', $result['metrics_collected'] ? '✓' : '✗'],
                ['Alerts Generated', $result['alerts_generated']],
                ['Trends Recorded', $result['trends_recorded']],
                ['Duration', round(microtime(true) - $startTime, 2).'s'],
                ['Timestamp', $result['timestamp']],
            ]
        );

        // Display errors if any
        if (! empty($result['errors'])) {
            $this->newLine();
            $this->error('Errors encountered:');
            foreach ($result['errors'] as $error) {
                $this->line("  - {$error}");
            }
        }

        // Get active alerts summary
        $activeAlerts = $this->alertService->getActiveAlerts();
        $criticalCount = $activeAlerts->where('severity', '>=', 90)->count();
        $warningCount = $activeAlerts->where('severity', '>=', 70)->where('severity', '<', 90)->count();

        if ($criticalCount > 0 || $warningCount > 0) {
            $this->newLine();
            $this->info('Active Alerts Summary:');
            $this->table(
                ['Severity', 'Count'],
                [
                    ['Critical', $criticalCount],
                    ['Warning', $warningCount],
                    ['Total', $activeAlerts->count()],
                ]
            );
        }

        $this->newLine();

        if ($result['success']) {
            $this->info('✅ Metrics collection completed successfully');

            return self::SUCCESS;
        } else {
            $this->error('❌ Metrics collection completed with errors');

            return self::FAILURE;
        }
    }
}
