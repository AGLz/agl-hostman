<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Builder;
use Carbon\Carbon;

/**
 * Performance Trend Model
 *
 * Stores performance metrics over time for trend analysis,
 * capacity planning, and predictive maintenance.
 *
 * @property int $id
 * @property string $metric_type
 * @property string $metric_name
 * @property string|null $node_code
 * @property string|null $vmid
 * @property float $value
 * @property array|null $metadata
 * @property Carbon $recorded_at
 * @property Carbon $created_at
 * @property Carbon $updated_at
 *
 * @package App\Models
 */
class PerformanceTrend extends Model
{
    use HasFactory;

    protected $fillable = [
        'metric_type',
        'metric_name',
        'node_code',
        'vmid',
        'value',
        'metadata',
        'recorded_at',
    ];

    protected $casts = [
        'value' => 'decimal:2',
        'metadata' => 'array',
        'recorded_at' => 'datetime',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    /**
     * Scope: Filter by metric type
     */
    public function scopeOfType(Builder $query, string $type): Builder
    {
        return $query->where('metric_type', $type);
    }

    /**
     * Scope: Filter by metric name
     */
    public function scopeNamed(Builder $query, string $name): Builder
    {
        return $query->where('metric_name', $name);
    }

    /**
     * Scope: Filter by node
     */
    public function scopeForNode(Builder $query, string $node): Builder
    {
        return $query->where('node_code', $node);
    }

    /**
     * Scope: Filter by container
     */
    public function scopeForContainer(Builder $query, string $node, int $vmid): Builder
    {
        return $query->where('node_code', $node)
                     ->where('vmid', $vmid);
    }

    /**
     * Scope: Recent trends (last N hours)
     */
    public function scopeRecent(Builder $query, int $hours = 24): Builder
    {
        return $query->where('recorded_at', '>=', now()->subHours($hours));
    }

    /**
     * Scope: Time range
     */
    public function scopeBetweenDates(Builder $query, Carbon $start, Carbon $end): Builder
    {
        return $query->whereBetween('recorded_at', [$start, $end]);
    }

    /**
     * Scope: Order by recording time
     */
    public function scopeChronological(Builder $query): Builder
    {
        return $query->orderBy('recorded_at', 'asc');
    }

    /**
     * Record a new performance metric
     */
    public static function record(
        string $metricType,
        string $metricName,
        float $value,
        ?string $nodeCode = null,
        ?string $vmid = null,
        ?array $metadata = null
    ): self {
        return static::create([
            'metric_type' => $metricType,
            'metric_name' => $metricName,
            'node_code' => $nodeCode,
            'vmid' => $vmid,
            'value' => $value,
            'metadata' => $metadata,
            'recorded_at' => now(),
        ]);
    }

    /**
     * Get trend statistics for a metric
     */
    public static function getTrendStats(
        string $metricType,
        string $metricName,
        int $hours = 24,
        ?string $nodeCode = null,
        ?string $vmid = null
    ): array {
        $query = static::ofType($metricType)
            ->named($metricName)
            ->recent($hours)
            ->chronological();

        if ($nodeCode) {
            $query->forNode($nodeCode);
        }

        if ($vmid) {
            $query->where('vmid', $vmid);
        }

        $records = $query->get();

        if ($records->isEmpty()) {
            return [
                'count' => 0,
                'min' => null,
                'max' => null,
                'avg' => null,
                'current' => null,
                'trend' => 'unknown',
            ];
        }

        $values = $records->pluck('value');
        $first = $values->first();
        $last = $values->last();

        return [
            'count' => $records->count(),
            'min' => $values->min(),
            'max' => $values->max(),
            'avg' => round($values->avg(), 2),
            'current' => $last,
            'trend' => $last > $first ? 'increasing' : ($last < $first ? 'decreasing' : 'stable'),
            'change_percent' => $first > 0 ? round((($last - $first) / $first) * 100, 2) : 0,
        ];
    }

    /**
     * Get cluster-wide metric aggregation
     */
    public static function getClusterMetric(
        string $metricType,
        string $metricName,
        int $hours = 1
    ): ?float {
        return static::ofType($metricType)
            ->named($metricName)
            ->recent($hours)
            ->avg('value');
    }

    /**
     * Clean up old trends (data retention)
     */
    public static function cleanupOldTrends(int $daysToKeep = 90): int
    {
        return static::where('recorded_at', '<', now()->subDays($daysToKeep))
            ->delete();
    }
}
