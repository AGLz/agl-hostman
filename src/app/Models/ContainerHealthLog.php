<?php

namespace App\Models;

use Carbon\Carbon;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * Container Health Log Model
 *
 * Stores historical container health monitoring data for trend analysis
 * and anomaly detection.
 *
 * @property int $id
 * @property string $node_code
 * @property string $vmid
 * @property string $container_name
 * @property string $health_status
 * @property float $cpu_usage_percent
 * @property float $memory_usage_percent
 * @property float $disk_usage_percent
 * @property int|null $uptime_seconds
 * @property array|null $issues
 * @property array|null $metrics
 * @property Carbon $created_at
 * @property Carbon $updated_at
 */
class ContainerHealthLog extends Model
{
    use HasFactory;

    protected $fillable = [
        'node_code',
        'vmid',
        'container_name',
        'health_status',
        'cpu_usage_percent',
        'memory_usage_percent',
        'disk_usage_percent',
        'uptime_seconds',
        'issues',
        'metrics',
    ];

    protected $casts = [
        'cpu_usage_percent' => 'decimal:2',
        'memory_usage_percent' => 'decimal:2',
        'disk_usage_percent' => 'decimal:2',
        'uptime_seconds' => 'integer',
        'issues' => 'array',
        'metrics' => 'array',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

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
     * Scope: Critical health status only
     */
    public function scopeCritical(Builder $query): Builder
    {
        return $query->where('health_status', 'critical');
    }

    /**
     * Scope: Warning or critical
     */
    public function scopeUnhealthy(Builder $query): Builder
    {
        return $query->whereIn('health_status', ['warning', 'critical']);
    }

    /**
     * Scope: Recent logs (last N hours)
     */
    public function scopeRecent(Builder $query, int $hours = 24): Builder
    {
        return $query->where('created_at', '>=', now()->subHours($hours));
    }

    /**
     * Scope: Time range
     */
    public function scopeBetweenDates(Builder $query, Carbon $start, Carbon $end): Builder
    {
        return $query->whereBetween('created_at', [$start, $end]);
    }

    /**
     * Get average CPU usage for time period
     */
    public static function getAverageCpuUsage(string $node, int $vmid, int $hours = 24): float
    {
        return static::forContainer($node, $vmid)
            ->recent($hours)
            ->avg('cpu_usage_percent') ?? 0.0;
    }

    /**
     * Get average memory usage for time period
     */
    public static function getAverageMemoryUsage(string $node, int $vmid, int $hours = 24): float
    {
        return static::forContainer($node, $vmid)
            ->recent($hours)
            ->avg('memory_usage_percent') ?? 0.0;
    }

    /**
     * Get critical incident count
     */
    public static function getCriticalIncidentCount(string $node, int $vmid, int $hours = 24): int
    {
        return static::forContainer($node, $vmid)
            ->critical()
            ->recent($hours)
            ->count();
    }

    /**
     * Check if container has issues
     */
    public function hasIssues(): bool
    {
        return ! empty($this->issues) && count($this->issues) > 0;
    }

    /**
     * Get formatted uptime
     */
    public function getFormattedUptimeAttribute(): string
    {
        if (! $this->uptime_seconds) {
            return '0m';
        }

        $seconds = $this->uptime_seconds;
        $days = floor($seconds / 86400);
        $hours = floor(($seconds % 86400) / 3600);
        $minutes = floor(($seconds % 3600) / 60);

        if ($days > 0) {
            return "{$days}d {$hours}h {$minutes}m";
        }
        if ($hours > 0) {
            return "{$hours}h {$minutes}m";
        }

        return "{$minutes}m";
    }
}
