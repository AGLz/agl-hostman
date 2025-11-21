<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\Alert;
use App\Models\AlertRule;
use App\Events\AlertCreated;
use App\Events\AlertAcknowledged;
use App\Events\AlertResolved;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Cache;

/**
 * AlertService - Manages alert lifecycle and operations
 *
 * Provides CRUD operations for alerts with real-time broadcasting
 * Implements rate limiting and deduplication
 */
class AlertService
{
    protected int $maxAlertsPerRuleHourly;
    protected int $deduplicationWindowMinutes;

    public function __construct()
    {
        $this->maxAlertsPerRuleHourly = (int) config('alerts.max_per_rule_hourly', 10);
        $this->deduplicationWindowMinutes = (int) config('alerts.deduplication_window_minutes', 15);
    }

    /**
     * Create a new alert with deduplication and rate limiting
     *
     * @param array{
     *   type: string,
     *   title: string,
     *   message: string,
     *   source: string,
     *   source_id?: string,
     *   severity: int,
     *   metadata?: array,
     *   rule_id?: string
     * } $data
     * @return Alert|null Returns null if rate limited or duplicate
     */
    public function createAlert(array $data): ?Alert
    {
        // Validate severity range
        $data['severity'] = max(0, min(100, $data['severity'] ?? 0));

        // Check for duplicate alerts in deduplication window
        if ($this->isDuplicate($data)) {
            Log::info('Duplicate alert suppressed', $data);
            return null;
        }

        // Check rate limit for rule-based alerts
        if (isset($data['rule_id']) && $this->isRateLimited($data['rule_id'])) {
            Log::warning('Alert rate limit exceeded for rule', ['rule_id' => $data['rule_id']]);
            return null;
        }

        // Create alert
        $alert = Alert::create([
            'type' => $data['type'],
            'title' => $data['title'],
            'message' => $data['message'],
            'source' => $data['source'],
            'source_id' => $data['source_id'] ?? null,
            'severity' => $data['severity'],
            'metadata' => array_merge($data['metadata'] ?? [], [
                'rule_id' => $data['rule_id'] ?? null,
                'created_at_timestamp' => now()->timestamp,
            ]),
            'status' => 'active',
        ]);

        // Broadcast alert created event
        broadcast(new AlertCreated($alert))->toOthers();

        Log::info('Alert created', [
            'alert_id' => $alert->id,
            'type' => $alert->type,
            'severity' => $alert->severity,
        ]);

        return $alert;
    }

    /**
     * Acknowledge an alert
     */
    public function acknowledgeAlert(string $alertId, string $userId): bool
    {
        $alert = Alert::find($alertId);

        if (!$alert) {
            return false;
        }

        if ($alert->status !== 'active') {
            return false;
        }

        $success = $alert->acknowledge($userId);

        if ($success) {
            broadcast(new AlertAcknowledged($alert))->toOthers();

            Log::info('Alert acknowledged', [
                'alert_id' => $alert->id,
                'user_id' => $userId,
            ]);
        }

        return $success;
    }

    /**
     * Resolve an alert
     */
    public function resolveAlert(string $alertId, string $userId): bool
    {
        $alert = Alert::find($alertId);

        if (!$alert) {
            return false;
        }

        $success = $alert->resolve($userId);

        if ($success) {
            broadcast(new AlertResolved($alert))->toOthers();

            Log::info('Alert resolved', [
                'alert_id' => $alert->id,
                'user_id' => $userId,
            ]);
        }

        return $success;
    }

    /**
     * Mute an alert for specified minutes
     */
    public function muteAlert(string $alertId, int $minutes): bool
    {
        $alert = Alert::find($alertId);

        if (!$alert) {
            return false;
        }

        return $alert->mute($minutes);
    }

    /**
     * Get active alerts with optional filtering
     */
    public function getActiveAlerts(?string $type = null): Collection
    {
        $query = Alert::active()
            ->notMuted()
            ->orderByDesc('severity')
            ->orderByDesc('created_at');

        if ($type) {
            $query->byType($type);
        }

        return $query->get();
    }

    /**
     * Get alert history for specified days
     */
    public function getAlertHistory(int $days = 7): Collection
    {
        return Alert::where('created_at', '>=', now()->subDays($days))
            ->orderByDesc('created_at')
            ->get();
    }

    /**
     * Get alert statistics
     *
     * @return array{
     *   total: int,
     *   active: int,
     *   acknowledged: int,
     *   resolved: int,
     *   by_type: array,
     *   by_source: array,
     *   by_severity: array,
     *   last_24h: int,
     *   last_7d: int
     * }
     */
    public function getAlertStats(): array
    {
        return Cache::remember('alert_stats', 60, function () {
            $all = Alert::all();
            $last24h = Alert::recent(24)->count();
            $last7d = Alert::recent(168)->count();

            return [
                'total' => $all->count(),
                'active' => $all->where('status', 'active')->count(),
                'acknowledged' => $all->where('status', 'acknowledged')->count(),
                'resolved' => $all->where('status', 'resolved')->count(),
                'by_type' => [
                    'critical' => $all->where('type', 'critical')->count(),
                    'warning' => $all->where('type', 'warning')->count(),
                    'info' => $all->where('type', 'info')->count(),
                ],
                'by_source' => [
                    'server' => $all->where('source', 'server')->count(),
                    'container' => $all->where('source', 'container')->count(),
                    'network' => $all->where('source', 'network')->count(),
                    'storage' => $all->where('source', 'storage')->count(),
                    'system' => $all->where('source', 'system')->count(),
                ],
                'by_severity' => [
                    'critical' => $all->where('severity', '>=', 90)->count(),
                    'high' => $all->where('severity', '>=', 70)->where('severity', '<', 90)->count(),
                    'medium' => $all->where('severity', '>=', 40)->where('severity', '<', 70)->count(),
                    'low' => $all->where('severity', '<', 40)->count(),
                ],
                'last_24h' => $last24h,
                'last_7d' => $last7d,
            ];
        });
    }

    /**
     * Cleanup old resolved alerts
     */
    public function cleanupOldAlerts(int $days = 90): int
    {
        $count = Alert::resolved()
            ->where('resolved_at', '<', now()->subDays($days))
            ->delete();

        Log::info("Cleaned up {$count} old resolved alerts");

        // Clear stats cache
        Cache::forget('alert_stats');

        return $count;
    }

    /**
     * Check if alert is duplicate within deduplication window
     */
    protected function isDuplicate(array $data): bool
    {
        $windowStart = now()->subMinutes($this->deduplicationWindowMinutes);

        $existing = Alert::active()
            ->where('type', $data['type'])
            ->where('source', $data['source'])
            ->where('source_id', $data['source_id'] ?? null)
            ->where('created_at', '>=', $windowStart)
            ->exists();

        return $existing;
    }

    /**
     * Check if alert creation is rate limited for a rule
     */
    protected function isRateLimited(string $ruleId): bool
    {
        $hourAgo = now()->subHour();

        $count = Alert::where('metadata->rule_id', $ruleId)
            ->where('created_at', '>=', $hourAgo)
            ->count();

        return $count >= $this->maxAlertsPerRuleHourly;
    }

    /**
     * Bulk acknowledge alerts
     */
    public function bulkAcknowledge(array $alertIds, string $userId): int
    {
        $count = 0;

        foreach ($alertIds as $alertId) {
            if ($this->acknowledgeAlert($alertId, $userId)) {
                $count++;
            }
        }

        return $count;
    }

    /**
     * Bulk resolve alerts
     */
    public function bulkResolve(array $alertIds, string $userId): int
    {
        $count = 0;

        foreach ($alertIds as $alertId) {
            if ($this->resolveAlert($alertId, $userId)) {
                $count++;
            }
        }

        return $count;
    }
}
