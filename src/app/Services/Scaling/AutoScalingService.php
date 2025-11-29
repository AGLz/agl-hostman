<?php

namespace App\Services\Scaling;

use App\Models\ScalingEvent;
use App\Services\Monitoring\MetricsCollector;
use App\Services\Notification\NotificationService;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Carbon\Carbon;

class AutoScalingService
{
    private const CACHE_PREFIX = 'autoscaling:';
    private const DECISION_CACHE_TTL = 300; // 5 minutes

    public function __construct(
        private MetricsCollector $metricsCollector,
        private NotificationService $notificationService
    ) {}

    /**
     * Evaluate scaling decisions based on current metrics
     */
    public function evaluateScaling(string $environment = 'production'): array
    {
        if (!config('scaling.enabled')) {
            return ['action' => 'none', 'reason' => 'Auto-scaling disabled'];
        }

        // Check blackout windows
        if ($this->isInBlackoutWindow()) {
            return ['action' => 'none', 'reason' => 'In blackout window'];
        }

        // Get current metrics
        $metrics = $this->collectCurrentMetrics();
        $currentReplicas = $this->getCurrentReplicas();

        // Evaluate each trigger
        $triggers = $this->evaluateTriggers($metrics);

        // Make scaling decision
        $decision = $this->makeScalingDecision($triggers, $currentReplicas, $environment);

        // Log decision
        $this->logDecision($decision, $metrics, $triggers);

        return $decision;
    }

    /**
     * Execute scaling action
     */
    public function executeScaling(array $decision): bool
    {
        if ($decision['action'] === 'none') {
            return true;
        }

        $action = $decision['action'];
        $targetReplicas = $decision['target_replicas'];

        // Check cooldown period
        if (!$this->canScale($action)) {
            Log::info("Scaling {$action} blocked by cooldown period");
            return false;
        }

        try {
            // Call Dokploy API to scale
            $result = $this->scaleViaDokploy($targetReplicas);

            if ($result) {
                // Record scaling event
                $this->recordScalingEvent($action, $decision);

                // Update cooldown
                $this->updateCooldown($action);

                // Send notification
                $this->notifyScaling($action, $decision);

                return true;
            }

            return false;
        } catch (\Exception $e) {
            Log::error('Scaling execution failed', [
                'action' => $action,
                'error' => $e->getMessage(),
            ]);

            $this->notifyScalingFailure($action, $e);
            return false;
        }
    }

    /**
     * Collect current resource metrics
     */
    private function collectCurrentMetrics(): array
    {
        $cacheKey = self::CACHE_PREFIX . 'current_metrics';

        return Cache::remember($cacheKey, 30, function () {
            return [
                'cpu' => $this->metricsCollector->getAverageCPU(60), // Last minute
                'memory' => $this->metricsCollector->getAverageMemory(60),
                'request_rate' => $this->metricsCollector->getRequestRate(60),
                'response_time' => $this->metricsCollector->getAverageResponseTime(60),
                'queue_length' => $this->metricsCollector->getQueueLength(),
                'timestamp' => now(),
            ];
        });
    }

    /**
     * Evaluate all scaling triggers
     */
    private function evaluateTriggers(array $metrics): array
    {
        $triggers = config('scaling.triggers');
        $results = [];

        foreach ($triggers as $metric => $config) {
            if (!$config['enabled']) {
                continue;
            }

            $value = $metrics[$metric] ?? null;
            if ($value === null) {
                continue;
            }

            $results[$metric] = $this->evaluateTrigger($metric, $value, $config);
        }

        return $results;
    }

    /**
     * Evaluate a single trigger
     */
    private function evaluateTrigger(string $metric, float $value, array $config): array
    {
        $scaleUp = $config['scale_up'];
        $scaleDown = $config['scale_down'];

        $result = [
            'metric' => $metric,
            'value' => $value,
            'action' => 'none',
            'triggered' => false,
        ];

        // Check scale up threshold
        if ($value >= $scaleUp['threshold']) {
            $duration = $this->getMetricDuration($metric, $scaleUp['threshold'], '>=');

            if ($duration >= $scaleUp['duration']) {
                $result['action'] = 'scale_up';
                $result['triggered'] = true;
                $result['duration'] = $duration;
                $result['threshold'] = $scaleUp['threshold'];
            }
        }

        // Check scale down threshold
        if ($value <= $scaleDown['threshold']) {
            $duration = $this->getMetricDuration($metric, $scaleDown['threshold'], '<=');

            if ($duration >= $scaleDown['duration']) {
                // Only scale down if not already triggered for scale up
                if (!$result['triggered']) {
                    $result['action'] = 'scale_down';
                    $result['triggered'] = true;
                    $result['duration'] = $duration;
                    $result['threshold'] = $scaleDown['threshold'];
                }
            }
        }

        return $result;
    }

    /**
     * Get duration that metric has been above/below threshold
     */
    private function getMetricDuration(string $metric, float $threshold, string $operator): int
    {
        $cacheKey = self::CACHE_PREFIX . "duration:{$metric}:{$operator}:{$threshold}";

        $start = Cache::get($cacheKey);

        if (!$start) {
            // First time seeing this threshold breach
            Cache::put($cacheKey, time(), 3600);
            return 0;
        }

        return time() - $start;
    }

    /**
     * Make scaling decision based on trigger results
     */
    private function makeScalingDecision(array $triggers, int $currentReplicas, string $environment): array
    {
        $envConfig = config("scaling.environments.{$environment}", []);
        $minReplicas = $envConfig['min_replicas'] ?? config('scaling.limits.min_replicas');
        $maxReplicas = $envConfig['max_replicas'] ?? config('scaling.limits.max_replicas');

        // Count scale up and scale down triggers
        $scaleUpCount = count(array_filter($triggers, fn($t) => $t['action'] === 'scale_up'));
        $scaleDownCount = count(array_filter($triggers, fn($t) => $t['action'] === 'scale_down'));

        // Consensus check if enabled
        if (config('scaling.advanced.require_consensus')) {
            $consensusThreshold = config('scaling.advanced.consensus_threshold');

            if ($scaleUpCount < $consensusThreshold && $scaleDownCount < $consensusThreshold) {
                return [
                    'action' => 'none',
                    'reason' => 'Consensus threshold not met',
                    'current_replicas' => $currentReplicas,
                    'scale_up_votes' => $scaleUpCount,
                    'scale_down_votes' => $scaleDownCount,
                ];
            }
        }

        // Determine action
        $action = 'none';
        $targetReplicas = $currentReplicas;

        if ($scaleUpCount > $scaleDownCount) {
            $action = 'scale_up';
            $step = config('scaling.limits.max_scale_up_step', 2);
            $targetReplicas = min($currentReplicas + $step, $maxReplicas);
        } elseif ($scaleDownCount > $scaleUpCount) {
            $action = 'scale_down';
            $step = config('scaling.limits.max_scale_down_step', 1);
            $targetReplicas = max($currentReplicas - $step, $minReplicas);

            // Health check before scale down
            if (config('scaling.advanced.health_check_before_scale_down')) {
                if (!$this->isHealthy()) {
                    return [
                        'action' => 'none',
                        'reason' => 'Failed health check - unsafe to scale down',
                        'current_replicas' => $currentReplicas,
                    ];
                }
            }
        }

        // Check if we hit limits
        if ($targetReplicas === $currentReplicas && $action !== 'none') {
            $limit = $action === 'scale_up' ? 'max' : 'min';
            $this->notifyLimitReached($limit, $currentReplicas);

            return [
                'action' => 'none',
                'reason' => "Already at {$limit} replicas",
                'current_replicas' => $currentReplicas,
                'limit_reached' => true,
            ];
        }

        return [
            'action' => $action,
            'current_replicas' => $currentReplicas,
            'target_replicas' => $targetReplicas,
            'triggered_by' => array_filter($triggers, fn($t) => $t['triggered']),
            'scale_up_votes' => $scaleUpCount,
            'scale_down_votes' => $scaleDownCount,
            'reason' => $this->buildReasonMessage($triggers, $action),
        ];
    }

    /**
     * Check if scaling action is allowed (cooldown check)
     */
    private function canScale(string $action): bool
    {
        $cacheKey = self::CACHE_PREFIX . "cooldown:{$action}";
        return !Cache::has($cacheKey);
    }

    /**
     * Update cooldown period after scaling
     */
    private function updateCooldown(string $action): void
    {
        $triggers = config('scaling.triggers');

        // Get maximum cooldown from all triggers
        $maxCooldown = 0;
        foreach ($triggers as $config) {
            if (!$config['enabled']) {
                continue;
            }

            $cooldown = $config[$action]['cooldown'] ?? 0;
            $maxCooldown = max($maxCooldown, $cooldown);
        }

        $cacheKey = self::CACHE_PREFIX . "cooldown:{$action}";
        Cache::put($cacheKey, true, $maxCooldown);
    }

    /**
     * Get current number of replicas from Dokploy
     */
    private function getCurrentReplicas(): int
    {
        try {
            $response = Http::withToken(config('scaling.dokploy.api_token'))
                ->timeout(config('scaling.dokploy.timeout'))
                ->get(config('scaling.dokploy.api_url') . '/applications/' . config('scaling.dokploy.application_id'));

            if ($response->successful()) {
                return $response->json()['replicas'] ?? 1;
            }
        } catch (\Exception $e) {
            Log::error('Failed to get current replicas', ['error' => $e->getMessage()]);
        }

        return 1; // Default fallback
    }

    /**
     * Scale application via Dokploy API
     */
    private function scaleViaDokploy(int $replicas): bool
    {
        try {
            $response = Http::withToken(config('scaling.dokploy.api_token'))
                ->timeout(config('scaling.dokploy.timeout'))
                ->patch(
                    config('scaling.dokploy.api_url') . '/applications/' . config('scaling.dokploy.application_id'),
                    ['replicas' => $replicas]
                );

            return $response->successful();
        } catch (\Exception $e) {
            Log::error('Dokploy scaling failed', [
                'replicas' => $replicas,
                'error' => $e->getMessage(),
            ]);
            return false;
        }
    }

    /**
     * Record scaling event in database
     */
    private function recordScalingEvent(string $action, array $decision): void
    {
        ScalingEvent::create([
            'action' => $action,
            'old_replicas' => $decision['current_replicas'],
            'new_replicas' => $decision['target_replicas'],
            'trigger' => $decision['reason'],
            'metadata' => json_encode([
                'triggered_by' => $decision['triggered_by'] ?? [],
                'votes' => [
                    'scale_up' => $decision['scale_up_votes'] ?? 0,
                    'scale_down' => $decision['scale_down_votes'] ?? 0,
                ],
            ]),
            'created_at' => now(),
        ]);
    }

    /**
     * Check if current time is in blackout window
     */
    private function isInBlackoutWindow(): bool
    {
        $windows = config('scaling.advanced.blackout_windows', []);

        if (empty($windows)) {
            return false;
        }

        $now = Carbon::now();

        foreach ($windows as $window) {
            $start = Carbon::parse($window['start']);
            $end = Carbon::parse($window['end']);

            if ($now->between($start, $end)) {
                return true;
            }
        }

        return false;
    }

    /**
     * Check application health
     */
    private function isHealthy(): bool
    {
        // Check recent alerts
        $recentAlerts = $this->metricsCollector->getRecentAlerts(300); // Last 5 minutes

        if ($recentAlerts > 0) {
            return false;
        }

        // Check error rate
        $errorRate = $this->metricsCollector->getErrorRate(60);
        if ($errorRate > 5) { // More than 5% errors
            return false;
        }

        return true;
    }

    /**
     * Build human-readable reason message
     */
    private function buildReasonMessage(array $triggers, string $action): string
    {
        $triggered = array_filter($triggers, fn($t) => $t['triggered']);

        if (empty($triggered)) {
            return 'No triggers';
        }

        $reasons = array_map(function ($trigger) {
            return sprintf(
                '%s: %.2f %s threshold %.2f for %ds',
                $trigger['metric'],
                $trigger['value'],
                $trigger['action'] === 'scale_up' ? '>' : '<',
                $trigger['threshold'],
                $trigger['duration']
            );
        }, $triggered);

        return implode('; ', $reasons);
    }

    /**
     * Send scaling notification
     */
    private function notifyScaling(string $action, array $decision): void
    {
        if (!config('scaling.notifications.enabled')) {
            return;
        }

        if (!config("scaling.notifications.events.{$action}")) {
            return;
        }

        $severity = config("scaling.notifications.severity.{$action}", 'info');

        $message = sprintf(
            'Auto-scaling %s: %d → %d replicas. Reason: %s',
            strtoupper(str_replace('_', ' ', $action)),
            $decision['current_replicas'],
            $decision['target_replicas'],
            $decision['reason']
        );

        $this->notificationService->send(
            title: 'Auto-Scaling Event',
            message: $message,
            severity: $severity,
            metadata: $decision
        );
    }

    /**
     * Notify when scaling limit is reached
     */
    private function notifyLimitReached(string $limit, int $replicas): void
    {
        if (!config('scaling.notifications.events.limit_reached')) {
            return;
        }

        $message = sprintf(
            'Auto-scaling %s limit reached: %d replicas',
            $limit,
            $replicas
        );

        $this->notificationService->send(
            title: 'Auto-Scaling Limit Reached',
            message: $message,
            severity: 'warning'
        );
    }

    /**
     * Notify scaling failure
     */
    private function notifyScalingFailure(string $action, \Exception $e): void
    {
        if (!config('scaling.notifications.events.scale_failed')) {
            return;
        }

        $this->notificationService->send(
            title: 'Auto-Scaling Failed',
            message: "Failed to execute {$action}: {$e->getMessage()}",
            severity: 'error',
            metadata: [
                'action' => $action,
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
            ]
        );
    }

    /**
     * Log scaling decision
     */
    private function logDecision(array $decision, array $metrics, array $triggers): void
    {
        if (!config('scaling.logging.enabled')) {
            return;
        }

        $level = config('scaling.logging.level', 'info');

        Log::channel(config('scaling.logging.channel', 'scaling'))->$level('Scaling decision', [
            'decision' => $decision,
            'metrics' => config('scaling.logging.log_metrics') ? $metrics : null,
            'triggers' => config('scaling.logging.log_decisions') ? $triggers : null,
        ]);
    }

    /**
     * Get scaling history
     */
    public function getScalingHistory(int $hours = 24): array
    {
        return ScalingEvent::where('created_at', '>=', now()->subHours($hours))
            ->orderBy('created_at', 'desc')
            ->get()
            ->toArray();
    }

    /**
     * Get scaling statistics
     */
    public function getScalingStats(int $days = 7): array
    {
        $events = ScalingEvent::where('created_at', '>=', now()->subDays($days))->get();

        return [
            'total_events' => $events->count(),
            'scale_up_count' => $events->where('action', 'scale_up')->count(),
            'scale_down_count' => $events->where('action', 'scale_down')->count(),
            'avg_replicas' => $events->avg('new_replicas'),
            'max_replicas' => $events->max('new_replicas'),
            'min_replicas' => $events->min('new_replicas'),
            'most_common_trigger' => $this->getMostCommonTrigger($events),
        ];
    }

    /**
     * Get most common scaling trigger
     */
    private function getMostCommonTrigger($events): ?string
    {
        $triggers = $events->pluck('trigger')->countBy();

        if ($triggers->isEmpty()) {
            return null;
        }

        return $triggers->sortDesc()->keys()->first();
    }
}
