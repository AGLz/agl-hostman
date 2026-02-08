<?php

declare(strict_types=1);

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
 * @property string $resource_type
 * @property string $resource_id
 * @property string $metric_type
 * @property float $value
 * @property string $unit
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
        'resource_type',
        'resource_id',
        'metric_type',
        'value',
        'unit',
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
     * Scope: Filter by resource type and id
     */
    public function scopeByResource(Builder $query, string $resourceType, string $resourceId): Builder
    {
        return $query->where('resource_type', $resourceType)
                     ->where('resource_id', $resourceId);
    }

    /**
     * Scope: Filter by metric type
     */
    public function scopeByMetricType(Builder $query, string $type): Builder
    {
        return $query->where('metric_type', $type);
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
    public function scopeOrdered(Builder $query): Builder
    {
        return $query->orderBy('recorded_at', 'desc');
    }

    /**
     * Scope: Latest per resource
     */
    public function scopeLatestPerResource(Builder $query, array $resourceIds, string $metricType): Builder
    {
        return $query->whereIn('resource_id', $resourceIds)
                     ->where('metric_type', $metricType)
                     ->orderBy('recorded_at', 'desc')
                     ->distinct('resource_id');
    }

    /**
     * Scope: For time range in hours
     */
    public function scopeForTimeRange(Builder $query, int $minHours, int $maxHours): Builder
    {
        return $query->whereBetween('recorded_at', [
            now()->subHours($maxHours),
            now()->subHours($minHours)
        ]);
    }

    /**
     * Record a new performance metric
     */
    public static function record(
        string $resourceType,
        string $resourceId,
        string $metricType,
        float $value,
        string $unit = '%',
        ?array $metadata = null
    ): self {
        return static::create([
            'resource_type' => $resourceType,
            'resource_id' => $resourceId,
            'metric_type' => $metricType,
            'value' => $value,
            'unit' => $unit,
            'metadata' => $metadata,
            'recorded_at' => now(),
        ]);
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
