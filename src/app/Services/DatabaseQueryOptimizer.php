<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\Alert;
use App\Models\DokployDeployment;
use App\Models\LxcContainer;
use App\Models\PerformanceTrend;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;

/**
 * Database Query Optimization Service
 *
 * Provides optimized query methods to prevent N+1 problems,
 * reduce database load, and improve query performance.
 */
class DatabaseQueryOptimizer
{
    /**
     * Get containers with optimized eager loading
     */
    public function getContainersOptimized(array $filters = []): Collection
    {
        $query = LxcContainer::with([
            'server:id,name,host,status',  // Select only needed fields
            'healthLogs' => function ($query) {
                $query->latest()->limit(10);  // Limit related records
            },
        ])
            ->select([
                'id', 'vmid', 'name', 'hostname', 'status',
                'cores', 'memory_mb', 'disk_gb',
                'proxmox_server_id', 'created_at', 'updated_at',
            ]);

        // Apply filters
        if (isset($filters['status'])) {
            $query->where('status', $filters['status']);
        }

        if (isset($filters['server_id'])) {
            $query->where('proxmox_server_id', $filters['server_id']);
        }

        if (isset($filters['search'])) {
            $query->where(function ($q) use ($filters) {
                $q->where('name', 'like', '%'.$filters['search'].'%')
                    ->orWhere('hostname', 'like', '%'.$filters['search'].'%')
                    ->orWhere('vmid', 'like', '%'.$filters['search'].'%');
            });
        }

        return $query->get();
    }

    /**
     * Get deployments with optimized eager loading
     *
     * @return \Illuminate\Contracts\Pagination\LengthAwarePaginator
     */
    public function getDeploymentsOptimized(array $filters = [], int $perPage = 15)
    {
        $query = DokployDeployment::with([
            'application:id,name,type,project_id',
            'application.user:id,name,email',
        ])
            ->select([
                'id', 'application_id', 'status', 'title',
                'commit_hash', 'branch', 'triggered_by',
                'duration_seconds', 'started_at', 'completed_at',
                'created_at', 'updated_at',
            ]);

        // Apply filters
        if (isset($filters['status'])) {
            $query->where('status', $filters['status']);
        }

        if (isset($filters['application_id'])) {
            $query->where('application_id', $filters['application_id']);
        }

        if (isset($filters['branch'])) {
            $query->where('branch', $filters['branch']);
        }

        // Order by created_at desc (most recent first)
        $query->orderBy('created_at', 'desc');

        return $query->paginate($perPage);
    }

    /**
     * Get user with all relationships optimized
     */
    public function getUserWithRelationships(int $userId): ?User
    {
        return User::with([
            'roles:id,name',  // Only select id and name
            'permissions:id,name',
            'physicalLocations:id,name,access_level',
            'apiKeys' => function ($query) {
                $query->select('id', 'user_id', 'name', 'last_used_at', 'is_active')
                    ->where('is_active', true);
            },
        ])
            ->select([
                'id', 'name', 'email', 'avatar_url', 'is_active',
                'last_login_at', 'created_at',
            ])
            ->find($userId);
    }

    /**
     * Get performance trends with optimization
     */
    public function getPerformanceTrendsOptimized(
        string $resourceType,
        string $resourceId,
        string $metricType,
        int $hours = 24
    ): Collection {
        return PerformanceTrend::where('resource_type', $resourceType)
            ->where('resource_id', $resourceId)
            ->where('metric_type', $metricType)
            ->where('recorded_at', '>=', now()->subHours($hours))
            ->select(['id', 'metric_type', 'value', 'unit', 'recorded_at'])
            ->orderBy('recorded_at', 'asc')
            ->get();
    }

    /**
     * Get alerts with optimized queries
     */
    public function getAlertsOptimized(array $filters = []): Collection
    {
        $query = Alert::select([
            'id', 'severity', 'title', 'message', 'resource_type',
            'resource_id', 'is_resolved', 'created_at',
        ]);

        // Apply filters
        if (isset($filters['severity'])) {
            $query->where('severity', $filters['severity']);
        }

        if (isset($filters['is_resolved'])) {
            $query->where('is_resolved', $filters['is_resolved']);
        }

        if (isset($filters['resource_type'])) {
            $query->where('resource_type', $filters['resource_type']);
        }

        // Order by severity and created_at
        $query->orderByRaw('FIELD(severity, "critical", "high", "medium", "low")')
            ->orderBy('created_at', 'desc');

        return $query->get();
    }

    /**
     * Count containers by status (optimized single query)
     */
    public function getContainerStatusCounts(): array
    {
        return LxcContainer::query()
            ->selectRaw('status, COUNT(*) as count')
            ->groupBy('status')
            ->pluck('count', 'status')
            ->toArray();
    }

    /**
     * Get deployment statistics (optimized single query)
     */
    public function getDeploymentStatistics(int $days = 30): array
    {
        $stats = DokployDeployment::where('created_at', '>=', now()->subDays($days))
            ->selectRaw('
                COUNT(*) as total,
                SUM(CASE WHEN status = "success" THEN 1 ELSE 0 END) as successful,
                SUM(CASE WHEN status = "failed" THEN 1 ELSE 0 END) as failed,
                SUM(CASE WHEN status IN ("pending", "building", "deploying") THEN 1 ELSE 0 END) as in_progress,
                AVG(CASE WHEN status = "success" THEN duration_seconds END) as avg_duration
            ')
            ->first();

        return [
            'total' => (int) ($stats->total ?? 0),
            'successful' => (int) ($stats->successful ?? 0),
            'failed' => (int) ($stats->failed ?? 0),
            'in_progress' => (int) ($stats->in_progress ?? 0),
            'success_rate' => $stats->total > 0
                ? round((($stats->successful ?? 0) / $stats->total) * 100, 2)
                : 0,
            'avg_duration_seconds' => (int) ($stats->avg_duration ?? 0),
        ];
    }

    /**
     * Get recent activity across all resources (optimized with UNION)
     */
    public function getRecentActivity(int $limit = 50): Collection
    {
        // Use raw SQL for efficient UNION query
        $results = DB::select("
            (
                SELECT id, 'container' as type, name as title, status, created_at
                FROM lxc_containers
                WHERE created_at >= ?
                ORDER BY created_at DESC
                LIMIT ?
            )
            UNION ALL
            (
                SELECT id, 'deployment' as type, title, status, created_at
                FROM dokploy_deployments
                WHERE created_at >= ?
                ORDER BY created_at DESC
                LIMIT ?
            )
            UNION ALL
            (
                SELECT id, 'alert' as type, title, CONCAT('severity', ': ', is_resolved) as status, created_at
                FROM alerts
                WHERE created_at >= ?
                ORDER BY created_at DESC
                LIMIT ?
            )
            ORDER BY created_at DESC
            LIMIT ?
        ", [
            now()->subDays(7), $limit,
            now()->subDays(7), $limit,
            now()->subDays(7), $limit,
            $limit,
        ]);

        return collect($results);
    }

    /**
     * Batch insert or update containers (upsert)
     *
     * @return int Number of affected rows
     */
    public function upsertContainers(array $containers): int
    {
        if (empty($containers)) {
            return 0;
        }

        $timestamp = now();

        $data = collect($containers)->map(function ($container) use ($timestamp) {
            return [
                'vmid' => $container['vmid'],
                'name' => $container['name'],
                'hostname' => $container['hostname'] ?? null,
                'status' => $container['status'],
                'cores' => $container['cores'] ?? 0,
                'memory_mb' => $container['memory_mb'] ?? 0,
                'disk_gb' => $container['disk_gb'] ?? 0,
                'proxmox_server_id' => $container['proxmox_server_id'],
                'network_config' => $container['network_config'] ?? null,
                'metadata' => $container['metadata'] ?? null,
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ];
        })->toArray();

        return DB::table('lxc_containers')->upsert(
            $data,
            ['vmid'],  // Unique constraint
            ['name', 'hostname', 'status', 'cores', 'memory_mb', 'disk_gb', 'updated_at']
        );
    }

    /**
     * Chunked processing for large datasets
     */
    public function chunkedProcessing(Builder $query, int $chunkSize, callable $callback): void
    {
        $query->chunk($chunkSize, function ($records) use ($callback) {
            $callback($records);
        });
    }

    /**
     * Optimize subquery with JOIN instead of WHERE IN
     */
    public function getContainersByServersJoin(array $serverIds): Collection
    {
        return LxcContainer::select('lxc_containers.*')
            ->join('proxmox_servers', 'lxc_containers.proxmox_server_id', '=', 'proxmox_servers.id')
            ->whereIn('proxmox_servers.id', $serverIds)
            ->with('server:id,name,host')
            ->get();
    }

    /**
     * Get aggregate metrics in single query
     */
    public function getAggregateMetrics(
        string $resourceType,
        string $resourceId,
        string $metricType,
        int $hours = 24
    ): array {
        $metrics = PerformanceTrend::where('resource_type', $resourceType)
            ->where('resource_id', $resourceId)
            ->where('metric_type', $metricType)
            ->where('recorded_at', '>=', now()->subHours($hours))
            ->selectRaw('
                MIN(value) as min_value,
                MAX(value) as max_value,
                AVG(value) as avg_value,
                COUNT(*) as data_points
            ')
            ->first();

        return [
            'min' => $metrics->min_value ?? 0,
            'max' => $metrics->max_value ?? 0,
            'avg' => round($metrics->avg_value ?? 0, 2),
            'data_points' => $metrics->data_points ?? 0,
        ];
    }

    /**
     * Paginated results with cursor-based pagination (better for large datasets)
     */
    public function cursorPaginate(Builder $query, int $perPage = 50, ?string $cursor = null): array
    {
        if ($cursor) {
            $query->where('id', '>', $cursor);
        }

        $results = $query->orderBy('id', 'asc')
            ->limit($perPage + 1)  // Fetch one extra to check if there's a next page
            ->get();

        $hasMore = $results->count() > $perPage;
        $items = $results->take($perPage);
        $nextCursor = $hasMore ? $items->last()->id : null;

        return [
            'data' => $items,
            'next_cursor' => $nextCursor,
            'has_more' => $hasMore,
        ];
    }
}
