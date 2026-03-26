<?php

declare(strict_types=1);

namespace App\Traits;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\Cache;

/**
 * Has Optimization Trait
 *
 * Provides optimization methods for Eloquent models including
 * caching, eager loading scopes, and query optimization.
 */
trait HasOptimization
{
    /**
     * Cache key prefix for this model
     */
    protected string $cachePrefix = 'model';

    /**
     * Default cache TTL in seconds
     */
    protected int $cacheTTL = 300;

    /**
     * Relations to always eager load
     */
    protected array $alwaysEagerLoad = [];

    /**
     * Boot the trait
     */
    protected static function bootHasOptimization(): void
    {
        // Auto-eager load relations
        static::resolving(function ($model) {
            if (! empty($model->alwaysEagerLoad)) {
                $model->load($model->alwaysEagerLoad);
            }
        });
    }

    /**
     * Scope to cache query results
     */
    public function scopeCache(Builder $query, ?int $ttl = null): Builder
    {
        $ttl = $ttl ?? $this->cacheTTL;
        $key = $this->getCacheKey($query);

        return $query->cacheTags([$this->cachePrefix, $this->getTable()])
            ->cacheMinutes($ttl)
            ->cacheDriver('redis');
    }

    /**
     * Get cache key for query
     */
    protected function getCacheKey(Builder $query): string
    {
        return sprintf(
            '%s:%s:%s',
            $this->cachePrefix,
            $this->getTable(),
            md5($query->toSql().serialize($query->getBindings()))
        );
    }

    /**
     * Scope to eager load relations with count
     */
    public function scopeWithCount(Builder $query, array $relations): Builder
    {
        foreach ($relations as $relation) {
            $query->withCount($relation);
        }

        return $query;
    }

    /**
     * Scope to optimize common queries
     */
    public function scopeOptimized(Builder $query): Builder
    {
        // Eager load common relations
        if (! empty($this->alwaysEagerLoad)) {
            $query->with($this->alwaysEagerLoad);
        }

        // Select only necessary columns if not specified
        if (empty($query->columns)) {
            $query->select("{$this->table}.*");
        }

        return $query;
    }

    /**
     * Get cached model instance
     */
    public static function cachedFind($id, ?int $ttl = null): ?self
    {
        $instance = new static;
        $ttl = $ttl ?? $instance->cacheTTL;
        $key = "{$instance->cachePrefix}:{$instance->getTable()}:{$id}";

        return Cache::remember($key, $ttl, function () use ($id) {
            return static::find($id);
        });
    }

    /**
     * Clear model cache
     */
    public function clearCache(): bool
    {
        $key = "{$this->cachePrefix}:{$this->getTable()}:{$this->id}";

        if ($this->id) {
            Cache::forget($key);
        }

        // Clear all model cache by tag
        Cache::tags([$this->cachePrefix, $this->getTable()])->flush();

        return true;
    }

    /**
     * Clear cache for all instances
     */
    public static function clearAllCache(): bool
    {
        $instance = new static;

        return Cache::tags([$instance->cachePrefix, $instance->getTable()])->flush() !== false;
    }

    /**
     * Chunk results with memory efficiency
     */
    public static function chunkOptimized(int $count, callable $callback): void
    {
        static::query()
            ->optimized()
            ->chunk($count, function ($items) use ($callback) {
                return $callback($items);
            });
    }

    /**
     * Get paginated results with optimization
     */
    public function scopePaginated(Builder $query, ?int $perPage = null): \Illuminate\Contracts\Pagination\LengthAwarePaginator
    {
        $perPage = $perPage ?? config('performance.api.default_page_size', 25);
        $maxPerPage = config('performance.api.max_page_size', 100);

        return $query->optimized()
            ->paginate(min($perPage, $maxPerPage));
    }

    /**
     * Scope for active items
     */
    public function scopeActive(Builder $query): Builder
    {
        return $query->where(function ($q) {
            if (Schema::hasColumn($this->getTable(), 'is_active')) {
                $q->where('is_active', true);
            }

            if (Schema::hasColumn($this->getTable(), 'status')) {
                $q->where('status', 'active');
            }
        });
    }

    /**
     * Scope for recent items
     */
    public function scopeRecent(Builder $query, int $days = 7): Builder
    {
        return $query->where(
            'created_at',
            '>=',
            now()->subDays($days)
        )->latest('created_at');
    }

    /**
     * Get model statistics (cached)
     */
    public static function getStats(int $ttl = 300): array
    {
        $instance = new static;
        $key = "stats:{$instance->getTable()}";

        return Cache::remember($key, $ttl, function () {
            return [
                'total' => static::count(),
                'active' => static::active()->count(),
                'recent_7d' => static::recent(7)->count(),
                'recent_30d' => static::recent(30)->count(),
            ];
        });
    }
}
