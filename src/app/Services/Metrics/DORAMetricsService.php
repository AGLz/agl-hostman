<?php

namespace App\Services\Metrics;

use App\Models\Alert;
use App\Models\Deployment;
use App\Models\DORAMetric;
use Carbon\Carbon;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;

class DORAMetricsService
{
    private const CACHE_TTL = 3600; // 1 hour

    /**
     * Calculate all DORA metrics
     */
    public function calculateAllMetrics(string $period = 'week'): array
    {
        return [
            'deployment_frequency' => $this->calculateDeploymentFrequency($period),
            'lead_time' => $this->calculateLeadTime($period),
            'mttr' => $this->calculateMTTR($period),
            'change_failure_rate' => $this->calculateChangeFailureRate($period),
            'performance_tier' => $this->determinePerformanceTier(),
            'period' => $period,
            'calculated_at' => now(),
        ];
    }

    /**
     * Calculate Deployment Frequency
     * How often deployments occur to production
     */
    public function calculateDeploymentFrequency(string $period = 'week'): array
    {
        $cacheKey = "dora:deployment_frequency:{$period}";

        return Cache::remember($cacheKey, self::CACHE_TTL, function () use ($period) {
            $start = $this->getPeriodStart($period);

            $deployments = Deployment::where('environment', 'production')
                ->where('status', 'success')
                ->where('created_at', '>=', $start)
                ->get();

            $days = $start->diffInDays(now());
            $count = $deployments->count();

            $perDay = $days > 0 ? $count / $days : 0;
            $perWeek = $perDay * 7;
            $perMonth = $perDay * 30;

            return [
                'total_deployments' => $count,
                'per_day' => round($perDay, 2),
                'per_week' => round($perWeek, 2),
                'per_month' => round($perMonth, 2),
                'period_days' => $days,
                'trend' => $this->calculateTrend('deployment_frequency', $period),
                'tier' => $this->getDeploymentFrequencyTier($perDay),
            ];
        });
    }

    /**
     * Calculate Lead Time for Changes
     * Time from commit to production deployment
     */
    public function calculateLeadTime(string $period = 'week'): array
    {
        $cacheKey = "dora:lead_time:{$period}";

        return Cache::remember($cacheKey, self::CACHE_TTL, function () use ($period) {
            $start = $this->getPeriodStart($period);

            $deployments = Deployment::where('environment', 'production')
                ->where('status', 'success')
                ->where('created_at', '>=', $start)
                ->get();

            $leadTimes = [];

            foreach ($deployments as $deployment) {
                $commitTime = $this->getCommitTime($deployment->commit_sha);

                if ($commitTime) {
                    $leadTime = $commitTime->diffInMinutes($deployment->created_at);
                    $leadTimes[] = $leadTime;
                }
            }

            if (empty($leadTimes)) {
                return [
                    'average_minutes' => 0,
                    'average_hours' => 0,
                    'median_minutes' => 0,
                    'p95_minutes' => 0,
                    'sample_size' => 0,
                    'tier' => 'unknown',
                ];
            }

            sort($leadTimes);
            $avg = array_sum($leadTimes) / count($leadTimes);
            $median = $leadTimes[intval(count($leadTimes) / 2)];
            $p95 = $leadTimes[intval(count($leadTimes) * 0.95)];

            return [
                'average_minutes' => round($avg, 2),
                'average_hours' => round($avg / 60, 2),
                'median_minutes' => $median,
                'median_hours' => round($median / 60, 2),
                'p95_minutes' => $p95,
                'p95_hours' => round($p95 / 60, 2),
                'sample_size' => count($leadTimes),
                'trend' => $this->calculateTrend('lead_time', $period),
                'tier' => $this->getLeadTimeTier($avg),
            ];
        });
    }

    /**
     * Calculate Mean Time to Recovery (MTTR)
     * Time to restore service after incident
     */
    public function calculateMTTR(string $period = 'week'): array
    {
        $cacheKey = "dora:mttr:{$period}";

        return Cache::remember($cacheKey, self::CACHE_TTL, function () use ($period) {
            $start = $this->getPeriodStart($period);

            $incidents = Alert::where('severity', 'critical')
                ->where('created_at', '>=', $start)
                ->whereNotNull('resolved_at')
                ->get();

            $recoveryTimes = [];

            foreach ($incidents as $incident) {
                $recoveryTime = $incident->created_at->diffInMinutes($incident->resolved_at);
                $recoveryTimes[] = $recoveryTime;
            }

            if (empty($recoveryTimes)) {
                return [
                    'average_minutes' => 0,
                    'average_hours' => 0,
                    'median_minutes' => 0,
                    'p95_minutes' => 0,
                    'total_incidents' => 0,
                    'tier' => 'unknown',
                ];
            }

            sort($recoveryTimes);
            $avg = array_sum($recoveryTimes) / count($recoveryTimes);
            $median = $recoveryTimes[intval(count($recoveryTimes) / 2)];
            $p95 = $recoveryTimes[intval(count($recoveryTimes) * 0.95)];

            return [
                'average_minutes' => round($avg, 2),
                'average_hours' => round($avg / 60, 2),
                'median_minutes' => $median,
                'median_hours' => round($median / 60, 2),
                'p95_minutes' => $p95,
                'p95_hours' => round($p95 / 60, 2),
                'total_incidents' => count($recoveryTimes),
                'trend' => $this->calculateTrend('mttr', $period),
                'tier' => $this->getMTTRTier($avg),
            ];
        });
    }

    /**
     * Calculate Change Failure Rate
     * Percentage of deployments that fail
     */
    public function calculateChangeFailureRate(string $period = 'week'): array
    {
        $cacheKey = "dora:change_failure_rate:{$period}";

        return Cache::remember($cacheKey, self::CACHE_TTL, function () use ($period) {
            $start = $this->getPeriodStart($period);

            $totalDeployments = Deployment::where('environment', 'production')
                ->where('created_at', '>=', $start)
                ->count();

            $failedDeployments = Deployment::where('environment', 'production')
                ->where('status', 'failed')
                ->where('created_at', '>=', $start)
                ->count();

            $rate = $totalDeployments > 0 ? ($failedDeployments / $totalDeployments) * 100 : 0;

            return [
                'total_deployments' => $totalDeployments,
                'failed_deployments' => $failedDeployments,
                'success_deployments' => $totalDeployments - $failedDeployments,
                'failure_rate_pct' => round($rate, 2),
                'success_rate_pct' => round(100 - $rate, 2),
                'trend' => $this->calculateTrend('change_failure_rate', $period),
                'tier' => $this->getChangeFailureRateTier($rate),
            ];
        });
    }

    /**
     * Determine overall performance tier based on all metrics
     */
    public function determinePerformanceTier(): array
    {
        $metrics = [
            'deployment_frequency' => $this->calculateDeploymentFrequency('week'),
            'lead_time' => $this->calculateLeadTime('week'),
            'mttr' => $this->calculateMTTR('week'),
            'change_failure_rate' => $this->calculateChangeFailureRate('week'),
        ];

        $tiers = array_column($metrics, 'tier');
        $tierCounts = array_count_values($tiers);

        // Determine overall tier (majority wins)
        arsort($tierCounts);
        $overallTier = array_key_first($tierCounts);

        return [
            'tier' => $overallTier,
            'metrics_breakdown' => [
                'deployment_frequency' => $metrics['deployment_frequency']['tier'],
                'lead_time' => $metrics['lead_time']['tier'],
                'mttr' => $metrics['mttr']['tier'],
                'change_failure_rate' => $metrics['change_failure_rate']['tier'],
            ],
            'tier_distribution' => $tierCounts,
            'benchmark' => $this->getTierBenchmark($overallTier),
        ];
    }

    /**
     * Get commit time from GitHub API
     */
    private function getCommitTime(string $sha): ?Carbon
    {
        try {
            $token = config('services.github.token');
            $repo = config('services.github.repository');

            if (! $token || ! $repo) {
                return null;
            }

            $response = Http::withToken($token)
                ->get("https://api.github.com/repos/{$repo}/commits/{$sha}");

            if ($response->successful()) {
                $data = $response->json();

                return Carbon::parse($data['commit']['author']['date']);
            }
        } catch (\Exception $e) {
            // Silently fail - will skip this deployment
        }

        return null;
    }

    /**
     * Get period start date
     */
    private function getPeriodStart(string $period): Carbon
    {
        return match ($period) {
            'day' => now()->subDay(),
            'week' => now()->subWeek(),
            'month' => now()->subMonth(),
            'quarter' => now()->subQuarter(),
            'year' => now()->subYear(),
            default => now()->subWeek(),
        };
    }

    /**
     * Calculate trend compared to previous period
     */
    private function calculateTrend(string $metric, string $period): array
    {
        $currentValue = $this->getMetricValue($metric, $period);
        $previousValue = $this->getMetricValue($metric, $period, true);

        if ($previousValue === 0) {
            return [
                'direction' => 'neutral',
                'change_pct' => 0,
                'improved' => false,
            ];
        }

        $changePct = (($currentValue - $previousValue) / $previousValue) * 100;

        // For some metrics, lower is better (lead_time, mttr, change_failure_rate)
        $lowerIsBetter = in_array($metric, ['lead_time', 'mttr', 'change_failure_rate']);

        $improved = $lowerIsBetter ? ($changePct < 0) : ($changePct > 0);

        return [
            'direction' => $changePct > 0 ? 'up' : ($changePct < 0 ? 'down' : 'neutral'),
            'change_pct' => round(abs($changePct), 2),
            'improved' => $improved,
        ];
    }

    /**
     * Get metric value for trend calculation
     */
    private function getMetricValue(string $metric, string $period, bool $previous = false): float
    {
        $start = $this->getPeriodStart($period);

        if ($previous) {
            $duration = now()->diffInDays($start);
            $start = $start->copy()->subDays($duration);
            $end = $this->getPeriodStart($period);
        } else {
            $end = now();
        }

        return match ($metric) {
            'deployment_frequency' => Deployment::where('environment', 'production')
                ->where('status', 'success')
                ->whereBetween('created_at', [$start, $end])
                ->count(),

            'lead_time' => Deployment::where('environment', 'production')
                ->where('status', 'success')
                ->whereBetween('created_at', [$start, $end])
                ->avg('duration') ?? 0,

            'mttr' => Alert::where('severity', 'critical')
                ->whereNotNull('resolved_at')
                ->whereBetween('created_at', [$start, $end])
                ->get()
                ->avg(fn ($alert) => $alert->created_at->diffInMinutes($alert->resolved_at)) ?? 0,

            'change_failure_rate' => $this->calculateFailureRate($start, $end),

            default => 0,
        };
    }

    /**
     * Calculate failure rate for a period
     */
    private function calculateFailureRate(Carbon $start, Carbon $end): float
    {
        $total = Deployment::where('environment', 'production')
            ->whereBetween('created_at', [$start, $end])
            ->count();

        if ($total === 0) {
            return 0;
        }

        $failed = Deployment::where('environment', 'production')
            ->where('status', 'failed')
            ->whereBetween('created_at', [$start, $end])
            ->count();

        return ($failed / $total) * 100;
    }

    /**
     * Determine deployment frequency tier
     */
    private function getDeploymentFrequencyTier(float $perDay): string
    {
        if ($perDay >= 1) {
            return 'elite';
        }
        if ($perDay >= 0.14) {
            return 'high';
        }      // ~1 per week
        if ($perDay >= 0.03) {
            return 'medium';
        }    // ~1 per month

        return 'low';
    }

    /**
     * Determine lead time tier
     */
    private function getLeadTimeTier(float $minutes): string
    {
        $hours = $minutes / 60;

        if ($hours < 1) {
            return 'elite';
        }
        if ($hours < 24) {
            return 'high';
        }
        if ($hours < 168) {
            return 'medium';
        }  // 1 week

        return 'low';
    }

    /**
     * Determine MTTR tier
     */
    private function getMTTRTier(float $minutes): string
    {
        $hours = $minutes / 60;

        if ($hours < 1) {
            return 'elite';
        }
        if ($hours < 24) {
            return 'high';
        }

        return 'medium';
    }

    /**
     * Determine change failure rate tier
     */
    private function getChangeFailureRateTier(float $rate): string
    {
        if ($rate < 15) {
            return 'elite';
        }
        if ($rate < 30) {
            return 'high';
        }
        if ($rate < 45) {
            return 'medium';
        }

        return 'low';
    }

    /**
     * Get benchmark thresholds for a tier
     */
    private function getTierBenchmark(string $tier): array
    {
        return match ($tier) {
            'elite' => [
                'deployment_frequency' => 'Multiple deploys per day',
                'lead_time' => 'Less than 1 hour',
                'mttr' => 'Less than 1 hour',
                'change_failure_rate' => '< 15%',
            ],
            'high' => [
                'deployment_frequency' => 'Between once per week and once per month',
                'lead_time' => 'Between 1 day and 1 week',
                'mttr' => 'Less than 1 day',
                'change_failure_rate' => '< 15%',
            ],
            'medium' => [
                'deployment_frequency' => 'Between once per month and once per 6 months',
                'lead_time' => 'Between 1 week and 1 month',
                'mttr' => 'Between 1 day and 1 week',
                'change_failure_rate' => '< 15%',
            ],
            'low' => [
                'deployment_frequency' => 'Fewer than once per 6 months',
                'lead_time' => 'More than 1 month',
                'mttr' => 'More than 1 week',
                'change_failure_rate' => '> 15%',
            ],
            default => [],
        };
    }

    /**
     * Store metrics snapshot
     */
    public function storeMetricsSnapshot(string $period = 'week'): DORAMetric
    {
        $metrics = $this->calculateAllMetrics($period);

        return DORAMetric::create([
            'period' => $period,
            'deployment_frequency' => $metrics['deployment_frequency'],
            'lead_time' => $metrics['lead_time'],
            'mttr' => $metrics['mttr'],
            'change_failure_rate' => $metrics['change_failure_rate'],
            'performance_tier' => $metrics['performance_tier'],
            'calculated_at' => now(),
        ]);
    }

    /**
     * Get historical metrics
     */
    public function getHistoricalMetrics(int $weeks = 12): array
    {
        return DORAMetric::where('period', 'week')
            ->where('calculated_at', '>=', now()->subWeeks($weeks))
            ->orderBy('calculated_at')
            ->get()
            ->toArray();
    }
}
