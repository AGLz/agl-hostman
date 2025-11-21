<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\Alert;
use App\Models\AlertRule;
use App\Models\ProxmoxServer;
use App\Models\LxcContainer;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Log;

/**
 * AlertRuleEngine - Evaluates alert rules and triggers alerts
 *
 * Supports three rule types:
 * - Threshold: Metric exceeds threshold for duration
 * - Pattern: Log pattern matching
 * - Anomaly: Statistical anomaly detection
 */
class AlertRuleEngine
{
    protected AlertService $alertService;
    protected MetricsCollector $metricsCollector;

    public function __construct(AlertService $alertService, MetricsCollector $metricsCollector)
    {
        $this->alertService = $alertService;
        $this->metricsCollector = $metricsCollector;
    }

    /**
     * Evaluate all enabled rules
     */
    public function evaluateAllRules(): Collection
    {
        $rules = AlertRule::enabled()->notInCooldown()->get();
        $triggeredAlerts = collect([]);

        foreach ($rules as $rule) {
            try {
                $alert = $this->evaluateRule($rule);

                if ($alert) {
                    $rule->markTriggered();
                    $triggeredAlerts->push($alert);
                }
            } catch (\Exception $e) {
                Log::error("Failed to evaluate rule {$rule->id}", [
                    'error' => $e->getMessage(),
                    'rule_name' => $rule->name,
                ]);
            }
        }

        return $triggeredAlerts;
    }

    /**
     * Evaluate a single rule
     */
    public function evaluateRule(AlertRule $rule): ?Alert
    {
        if (!$rule->enabled) {
            return null;
        }

        if ($rule->isInCooldown()) {
            return null;
        }

        return match($rule->rule_type) {
            'threshold' => $this->evaluateThresholdRule($rule),
            'pattern' => $this->evaluatePatternRule($rule),
            'anomaly' => $this->evaluateAnomalyRule($rule),
            default => null,
        };
    }

    /**
     * Evaluate threshold rule (CPU/RAM/Storage thresholds)
     *
     * Conditions structure:
     * {
     *   "metric": "cpu" | "memory" | "disk" | "load",
     *   "target": "server" | "container",
     *   "target_id": "aglsrv1" | "179",
     *   "operator": ">" | ">=" | "<" | "<=",
     *   "value": 90,
     *   "duration_minutes": 5
     * }
     */
    public function evaluateThresholdRule(AlertRule $rule): ?Alert
    {
        $conditions = $rule->conditions;
        $actions = $rule->actions;

        $target = $conditions['target'] ?? 'server';
        $targetId = $conditions['target_id'] ?? null;
        $metric = $conditions['metric'] ?? 'cpu';
        $operator = $conditions['operator'] ?? '>';
        $threshold = $conditions['value'] ?? 90;

        // Collect current metrics
        if ($target === 'server') {
            $metrics = $this->getServerMetrics($targetId);
        } elseif ($target === 'container') {
            $metrics = $this->getContainerMetrics($targetId);
        } else {
            return null;
        }

        if (!$metrics) {
            return null;
        }

        // Extract metric value
        $currentValue = $this->extractMetricValue($metrics, $metric);

        if ($currentValue === null) {
            return null;
        }

        // Evaluate condition
        $triggered = $this->compareValues($currentValue, $operator, $threshold);

        if (!$triggered) {
            return null;
        }

        // Create alert
        return $this->alertService->createAlert([
            'type' => $actions['alert_type'] ?? 'warning',
            'title' => $actions['title'] ?? "{$rule->name} triggered",
            'message' => sprintf(
                "%s %s is %s %s (threshold: %s)",
                ucfirst($target),
                $targetId ?? 'unknown',
                $metric,
                $currentValue,
                $threshold
            ),
            'source' => $target,
            'source_id' => $targetId,
            'severity' => $this->calculateSeverity($currentValue, $threshold, $operator),
            'metadata' => [
                'rule_id' => $rule->id,
                'rule_name' => $rule->name,
                'metric' => $metric,
                'current_value' => $currentValue,
                'threshold' => $threshold,
                'operator' => $operator,
            ],
            'rule_id' => $rule->id,
        ]);
    }

    /**
     * Evaluate pattern rule (log pattern matching)
     *
     * Conditions structure:
     * {
     *   "pattern": "regex_pattern",
     *   "source": "system_logs" | "container_logs",
     *   "target_id": "179",
     *   "match_count": 5,
     *   "time_window_minutes": 10
     * }
     */
    public function evaluatePatternRule(AlertRule $rule): ?Alert
    {
        // Placeholder for log pattern matching
        // This would require log aggregation infrastructure
        // For now, we'll skip implementation

        return null;
    }

    /**
     * Evaluate anomaly rule (statistical anomaly detection)
     *
     * Conditions structure:
     * {
     *   "metric": "cpu" | "memory",
     *   "target": "server" | "container",
     *   "target_id": "aglsrv1",
     *   "deviation_threshold": 2.0,
     *   "baseline_hours": 24
     * }
     */
    public function evaluateAnomalyRule(AlertRule $rule): ?Alert
    {
        // Placeholder for statistical anomaly detection
        // This would require historical metrics storage
        // For now, we'll skip implementation

        return null;
    }

    /**
     * Get server metrics
     */
    protected function getServerMetrics(string $serverCode): ?array
    {
        $result = $this->metricsCollector->collectServerMetrics($serverCode);

        return $result['success'] ? $result['metrics'] : null;
    }

    /**
     * Get container metrics
     */
    protected function getContainerMetrics(string $vmid): ?array
    {
        $container = LxcContainer::where('vmid', $vmid)->first();

        if (!$container) {
            return null;
        }

        $server = $container->proxmoxServer;
        $containerMetrics = $this->metricsCollector->collectContainerMetrics($server->id);

        return $containerMetrics->firstWhere('vmid', $vmid);
    }

    /**
     * Extract metric value from metrics array
     */
    protected function extractMetricValue(array $metrics, string $metric): ?float
    {
        return match($metric) {
            'cpu' => $metrics['cpu']['usage_percent'] ?? null,
            'memory' => $metrics['memory']['usage_percent'] ?? null,
            'disk' => $metrics['disk']['usage_percent'] ?? null,
            'load' => $metrics['load']['1min'] ?? null,
            default => null,
        };
    }

    /**
     * Compare values based on operator
     */
    protected function compareValues(float $current, string $operator, float $threshold): bool
    {
        return match($operator) {
            '>' => $current > $threshold,
            '>=' => $current >= $threshold,
            '<' => $current < $threshold,
            '<=' => $current <= $threshold,
            '==' => abs($current - $threshold) < 0.01,
            '!=' => abs($current - $threshold) >= 0.01,
            default => false,
        };
    }

    /**
     * Calculate severity based on how far current value exceeds threshold
     */
    protected function calculateSeverity(float $current, float $threshold, string $operator): int
    {
        if (in_array($operator, ['>', '>='])) {
            $excess = $current - $threshold;
            $percentOver = ($excess / $threshold) * 100;

            // More than 50% over threshold = critical (95-100)
            if ($percentOver > 50) {
                return 95;
            }

            // 20-50% over threshold = critical (90-95)
            if ($percentOver > 20) {
                return 90;
            }

            // 10-20% over threshold = warning (70-89)
            if ($percentOver > 10) {
                return 75;
            }

            // Slightly over threshold = warning (60-70)
            return 65;
        }

        // For '<' or '<=' operators, less critical
        return 60;
    }

    /**
     * Check if rule is in cooldown
     */
    public function checkCooldown(AlertRule $rule): bool
    {
        return $rule->isInCooldown();
    }
}
