<?php

namespace App\Console\Commands;

use App\Services\Metrics\DORAMetricsService;
use Illuminate\Console\Command;

class DORAMetricsCalculate extends Command
{
    protected $signature = 'dora:calculate {period=week}';

    protected $description = 'Calculate and store DORA metrics';

    public function handle(DORAMetricsService $service): int
    {
        $period = $this->argument('period');

        $this->info("Calculating DORA metrics for period: {$period}");

        $metrics = $service->calculateAllMetrics($period);

        $this->table(
            ['Metric', 'Value', 'Tier'],
            [
                ['Deployment Frequency', $metrics['deployment_frequency']['per_day'].' /day', $metrics['deployment_frequency']['tier']],
                ['Lead Time', $metrics['lead_time']['average_hours'].' hours', $metrics['lead_time']['tier']],
                ['MTTR', $metrics['mttr']['average_hours'].' hours', $metrics['mttr']['tier']],
                ['Change Failure Rate', $metrics['change_failure_rate']['failure_rate_pct'].'%', $metrics['change_failure_rate']['tier']],
            ]
        );

        $this->info("\nPerformance Tier: ".$metrics['performance_tier']['tier']);

        $service->storeMetricsSnapshot($period);

        $this->info("\n✅ Metrics calculated and stored");

        return 0;
    }
}
