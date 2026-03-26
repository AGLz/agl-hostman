<?php

namespace App\Services;

use App\Jobs\NotificationJob;
use Carbon\Carbon;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;

/**
 * Queue Monitoring Service
 *
 * Monitors queue health, tracks failed jobs, and provides alerts
 * for queue-related issues.
 */
class QueueMonitoringService
{
    /**
     * Check queue health and generate alerts if needed.
     */
    public function checkQueueHealth(): array
    {
        $health = [
            'status' => 'healthy',
            'issues' => [],
            'metrics' => [],
        ];

        // Check for long-running jobs
        $longRunning = $this->checkLongRunningJobs();
        if (! empty($longRunning)) {
            $health['issues'][] = [
                'type' => 'long_running_jobs',
                'count' => count($longRunning),
                'jobs' => $longRunning,
            ];
        }

        // Check failed job count
        $failedCount = $this->getFailedJobCount();
        $health['metrics']['failed_jobs'] = $failedCount;

        if ($failedCount > config('horizon.notifications.high_failed_job_count.threshold', 100)) {
            $health['issues'][] = [
                'type' => 'high_failed_count',
                'count' => $failedCount,
                'threshold' => config('horizon.notifications.high_failed_job_count.threshold', 100),
            ];
        }

        // Check queue backlog
        $backlog = $this->checkQueueBacklog();
        if (! empty($backlog)) {
            $health['issues'][] = [
                'type' => 'queue_backlog',
                'queues' => $backlog,
            ];
        }

        // Get overall metrics
        $health['metrics'] = array_merge($health['metrics'], $this->getQueueMetrics());

        // Determine overall status
        if (! empty($health['issues'])) {
            $health['status'] = 'warning';

            // Check for critical issues
            foreach ($health['issues'] as $issue) {
                if ($issue['type'] === 'high_failed_count' && $issue['count'] > 500) {
                    $health['status'] = 'critical';
                }
            }
        }

        return $health;
    }

    /**
     * Get queue metrics.
     */
    public function getQueueMetrics(): array
    {
        return Cache::remember('queue:metrics', 60, function () {
            return [
                'pending_jobs' => $this->getPendingJobCount(),
                'processing_jobs' => $this->getProcessingJobCount(),
                'failed_jobs' => $this->getFailedJobCount(),
                'completed_jobs_today' => $this->getCompletedJobsToday(),
                'avg_wait_time' => $this->getAverageWaitTime(),
            ];
        });
    }

    /**
     * Get pending job count.
     */
    public function getPendingJobCount(): int
    {
        return Cache::remember('queue:pending_count', 30, function () {
            // Check Redis for pending jobs
            $redis = app('redis')->connection();

            $pending = 0;
            $queues = config('horizon.environments.'.config('app.env'));

            if ($queues) {
                foreach ($queues as $supervisor) {
                    $queueList = is_array($supervisor['queue']) ? $supervisor['queue'] : [$supervisor['queue']];
                    foreach ($queueList as $queue) {
                        $pending += $redis->llen('queues:'.$queue);
                    }
                }
            }

            return $pending;
        });
    }

    /**
     * Get processing job count (reserved jobs).
     */
    public function getProcessingJobCount(): int
    {
        return Cache::remember('queue:processing_count', 30, function () {
            return DB::table('jobs')
                ->whereNotNull('reserved_at')
                ->whereNull('completed_at')
                ->count();
        });
    }

    /**
     * Get failed job count.
     */
    public function getFailedJobCount(): int
    {
        return Cache::remember('queue:failed_count', 60, function () {
            return DB::table('failed_jobs')->count();
        });
    }

    /**
     * Get completed jobs today.
     */
    public function getCompletedJobsToday(): int
    {
        return Cache::remember('queue:completed_today', 300, function () {
            // This would be tracked in job_performance_metrics
            return DB::table('job_performance_metrics')
                ->where('completed_at', '>=', Carbon::today())
                ->where('status', 'completed')
                ->count();
        });
    }

    /**
     * Get average wait time in seconds.
     */
    public function getAverageWaitTime(): float
    {
        return Cache::remember('queue:avg_wait_time', 300, function () {
            $recentJobs = DB::table('job_performance_metrics')
                ->where('started_at', '>=', Carbon::now()->subHour())
                ->get();

            if ($recentJobs->isEmpty()) {
                return 0.0;
            }

            // Calculate wait time from reserved_at to started_at
            // This would need to be tracked during job execution
            return 0.0;
        });
    }

    /**
     * Check for long-running jobs.
     */
    public function checkLongRunningJobs(int $thresholdMinutes = 30): array
    {
        $threshold = Carbon::now()->subMinutes($thresholdMinutes);

        $longRunning = DB::table('jobs')
            ->where('reserved_at', '<=', $threshold)
            ->whereNull('completed_at')
            ->select('id', 'queue', 'payload', 'reserved_at', 'attempts')
            ->limit(10)
            ->get()
            ->map(function ($job) {
                $payload = json_decode($job->payload, true);

                return [
                    'id' => $job->id,
                    'queue' => $job->queue,
                    'job' => $payload['displayName'] ?? $payload['job'] ?? 'Unknown',
                    'reserved_at' => $job->reserved_at,
                    'attempts' => $job->attempts,
                    'duration_minutes' => Carbon::now()->diffInMinutes(Carbon::parse($job->reserved_at)),
                ];
            })
            ->toArray();

        return $longRunning;
    }

    /**
     * Check for queue backlog.
     */
    public function checkQueueBacklog(int $threshold = 1000): array
    {
        $backlog = [];
        $queues = config('horizon.environments.'.config('app.env'));

        if ($queues) {
            $redis = app('redis')->connection();

            foreach ($queues as $supervisor) {
                $queueList = is_array($supervisor['queue']) ? $supervisor['queue'] : [$supervisor['queue']];

                foreach ($queueList as $queue) {
                    $count = $redis->llen('queues:'.$queue);

                    if ($count > $threshold) {
                        $backlog[] = [
                            'queue' => $queue,
                            'pending_count' => $count,
                            'threshold' => $threshold,
                        ];
                    }
                }
            }
        }

        return $backlog;
    }

    /**
     * Get failed jobs by type.
     */
    public function getFailedJobsByType(int $limit = 20): array
    {
        return DB::table('failed_jobs')
            ->orderBy('failed_at', 'desc')
            ->limit($limit)
            ->get()
            ->map(function ($job) {
                $payload = json_decode($job->payload, true);

                return [
                    'id' => $job->id,
                    'uuid' => $job->uuid,
                    'queue' => $job->queue,
                    'job' => $payload['displayName'] ?? $payload['job'] ?? 'Unknown',
                    'exception' => $this->extractExceptionMessage($job->exception),
                    'failed_at' => $job->failed_at,
                ];
            })
            ->groupBy('job')
            ->map(function ($jobs) {
                return [
                    'job_type' => $jobs->first()['job'],
                    'count' => $jobs->count(),
                    'last_failed' => $jobs->first()['failed_at'],
                    'sample_error' => $jobs->first()['exception'],
                ];
            })
            ->sortByDesc('count')
            ->values()
            ->toArray();
    }

    /**
     * Extract exception message from full exception.
     */
    protected function extractExceptionMessage(string $exception): string
    {
        $lines = explode("\n", $exception);

        return $lines[0] ?? 'Unknown error';
    }

    /**
     * Take snapshot of queue health.
     */
    public function takeQueueHealthSnapshot(): void
    {
        $queues = config('horizon.environments.'.config('app.env'));

        if ($queues) {
            $redis = app('redis')->connection();

            foreach ($queues as $supervisor) {
                $queueList = is_array($supervisor['queue']) ? $supervisor['queue'] : [$supervisor['queue']];

                foreach ($queueList as $queue) {
                    $pending = $redis->llen('queues:'.$queue);

                    DB::table('queue_health_snapshots')->insert([
                        'queue' => $queue,
                        'pending_jobs' => $pending,
                        'processing_jobs' => 0, // Would need to track this
                        'failed_jobs' => $this->getFailedJobCount(),
                        'completed_jobs' => 0, // Would need to track this
                        'snapshot_at' => now(),
                        'created_at' => now(),
                        'updated_at' => now(),
                    ]);
                }
            }
        }
    }

    /**
     * Send alert for queue issues.
     */
    public function sendQueueAlert(array $issues): void
    {
        foreach ($issues as $issue) {
            switch ($issue['type']) {
                case 'high_failed_count':
                    NotificationJob::dispatch(
                        'queue_high_failed',
                        [
                            'title' => 'High Failed Job Count Alert',
                            'message' => "Queue has {$issue['count']} failed jobs, exceeding threshold of {$issue['threshold']}.",
                            'failed_count' => $issue['count'],
                            'threshold' => $issue['threshold'],
                        ],
                        null,
                        null,
                        'high'
                    );
                    break;

                case 'queue_backlog':
                    NotificationJob::dispatch(
                        'queue_backlog',
                        [
                            'title' => 'Queue Backlog Alert',
                            'message' => 'Some queues have high pending job counts.',
                            'queues' => $issue['queues'],
                        ],
                        null,
                        null,
                        'medium'
                    );
                    break;

                case 'long_running_jobs':
                    NotificationJob::dispatch(
                        'queue_long_running',
                        [
                            'title' => 'Long Running Jobs Alert',
                            'message' => count($issue['jobs']).' jobs have been running for over 30 minutes.',
                            'jobs' => $issue['jobs'],
                        ],
                        null,
                        null,
                        'medium'
                    );
                    break;
            }
        }
    }
}
