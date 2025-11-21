<?php

declare(strict_types=1);

namespace App\Services;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
use Closure;

/**
 * Flexible Cache Service
 *
 * Provides advanced caching patterns with:
 * - Strategy-based cache invalidation
 * - Tag-based cache management
 * - Automatic cache warming
 * - Cache hit/miss metrics
 * - Flexible TTL strategies
 *
 * @package App\Services
 */
class CacheService
{
    private const DEFAULT_TTL = 3600; // 1 hour
    private const METRICS_KEY = 'cache_metrics';

    /**
     * Remember with flexible TTL
     *
     * @param string $key
     * @param Closure $callback
     * @param int|string|null $ttl TTL in seconds, 'auto', or null for default
     * @param array<string> $tags Cache tags
     * @return mixed
     */
    public function remember(string $key, Closure $callback, int|string|null $ttl = null, array $tags = []): mixed
    {
        $resolvedTtl = $this->resolveTtl($ttl);

        $startTime = microtime(true);
        $hit = Cache::has($key);

        $value = empty($tags)
            ? Cache::remember($key, $resolvedTtl, $callback)
            : Cache::tags($tags)->remember($key, $resolvedTtl, $callback);

        $this->recordMetric($key, $hit, microtime(true) - $startTime);

        return $value;
    }

    /**
     * Remember forever (until manually cleared)
     *
     * @param string $key
     * @param Closure $callback
     * @param array<string> $tags
     * @return mixed
     */
    public function rememberForever(string $key, Closure $callback, array $tags = []): mixed
    {
        $hit = Cache::has($key);

        $value = empty($tags)
            ? Cache::rememberForever($key, $callback)
            : Cache::tags($tags)->rememberForever($key, $callback);

        $this->recordMetric($key, $hit, 0);

        return $value;
    }

    /**
     * Get cached value with fallback
     *
     * @param string $key
     * @param mixed $default
     * @return mixed
     */
    public function get(string $key, mixed $default = null): mixed
    {
        $hit = Cache::has($key);
        $value = Cache::get($key, $default);

        $this->recordMetric($key, $hit, 0);

        return $value;
    }

    /**
     * Put value in cache with flexible TTL
     *
     * @param string $key
     * @param mixed $value
     * @param int|string|null $ttl
     * @param array<string> $tags
     * @return bool
     */
    public function put(string $key, mixed $value, int|string|null $ttl = null, array $tags = []): bool
    {
        $resolvedTtl = $this->resolveTtl($ttl);

        if (empty($tags)) {
            return Cache::put($key, $value, $resolvedTtl);
        }

        return Cache::tags($tags)->put($key, $value, $resolvedTtl);
    }

    /**
     * Forget cache key
     *
     * @param string $key
     * @return bool
     */
    public function forget(string $key): bool
    {
        return Cache::forget($key);
    }

    /**
     * Flush cache by tags
     *
     * @param array<string> $tags
     * @return bool
     */
    public function flushTags(array $tags): bool
    {
        try {
            Cache::tags($tags)->flush();
            Log::info('Cache flushed by tags', ['tags' => $tags]);
            return true;
        } catch (\Exception $e) {
            Log::error('Failed to flush cache tags', [
                'tags' => $tags,
                'error' => $e->getMessage(),
            ]);
            return false;
        }
    }

    /**
     * Warm cache with predefined data
     *
     * @param array<string, mixed> $data Key-value pairs to cache
     * @param int|string|null $ttl
     * @param array<string> $tags
     * @return int Number of items cached
     */
    public function warm(array $data, int|string|null $ttl = null, array $tags = []): int
    {
        $count = 0;
        $resolvedTtl = $this->resolveTtl($ttl);

        foreach ($data as $key => $value) {
            if ($this->put($key, $value, $resolvedTtl, $tags)) {
                $count++;
            }
        }

        Log::info('Cache warmed', [
            'items' => $count,
            'tags' => $tags,
            'ttl' => $resolvedTtl,
        ]);

        return $count;
    }

    /**
     * Batch get multiple keys
     *
     * @param array<string> $keys
     * @return array<string, mixed>
     */
    public function getMany(array $keys): array
    {
        return Cache::many($keys);
    }

    /**
     * Batch put multiple key-value pairs
     *
     * @param array<string, mixed> $values
     * @param int|string|null $ttl
     * @return bool
     */
    public function putMany(array $values, int|string|null $ttl = null): bool
    {
        $resolvedTtl = $this->resolveTtl($ttl);
        return Cache::putMany($values, $resolvedTtl);
    }

    /**
     * Remember with lock (prevent cache stampede)
     *
     * @param string $key
     * @param Closure $callback
     * @param int|string|null $ttl
     * @param int $lockSeconds
     * @return mixed
     */
    public function rememberWithLock(
        string $key,
        Closure $callback,
        int|string|null $ttl = null,
        int $lockSeconds = 10
    ): mixed {
        if (Cache::has($key)) {
            return Cache::get($key);
        }

        $lock = Cache::lock($key . '_lock', $lockSeconds);

        try {
            if ($lock->get()) {
                // Double check after getting lock
                if (Cache::has($key)) {
                    return Cache::get($key);
                }

                $value = $callback();
                $resolvedTtl = $this->resolveTtl($ttl);
                Cache::put($key, $value, $resolvedTtl);

                return $value;
            }

            // Wait for lock to be released and try to get cached value
            sleep(1);
            return Cache::get($key) ?? $callback();

        } finally {
            $lock->release();
        }
    }

    /**
     * Increment cache value
     *
     * @param string $key
     * @param int $value
     * @return int|bool
     */
    public function increment(string $key, int $value = 1): int|bool
    {
        return Cache::increment($key, $value);
    }

    /**
     * Decrement cache value
     *
     * @param string $key
     * @param int $value
     * @return int|bool
     */
    public function decrement(string $key, int $value = 1): int|bool
    {
        return Cache::decrement($key, $value);
    }

    /**
     * Check if key exists
     *
     * @param string $key
     * @return bool
     */
    public function has(string $key): bool
    {
        return Cache::has($key);
    }

    /**
     * Get cache metrics
     *
     * @return array<string, mixed>
     */
    public function getMetrics(): array
    {
        return Cache::get(self::METRICS_KEY, [
            'total_requests' => 0,
            'hits' => 0,
            'misses' => 0,
            'hit_rate' => 0,
            'avg_retrieval_time' => 0,
        ]);
    }

    /**
     * Reset cache metrics
     */
    public function resetMetrics(): void
    {
        Cache::forget(self::METRICS_KEY);
    }

    /**
     * Resolve TTL value
     *
     * @param int|string|null $ttl
     * @return int
     */
    private function resolveTtl(int|string|null $ttl): int
    {
        if ($ttl === null) {
            return self::DEFAULT_TTL;
        }

        if (is_int($ttl)) {
            return $ttl;
        }

        // Auto TTL based on strategy
        return match($ttl) {
            'short' => 300,      // 5 minutes
            'medium' => 1800,    // 30 minutes
            'long' => 3600,      // 1 hour
            'day' => 86400,      // 24 hours
            'week' => 604800,    // 7 days
            'auto' => $this->calculateAutoTtl(),
            default => self::DEFAULT_TTL,
        };
    }

    /**
     * Calculate automatic TTL based on load
     *
     * @return int
     */
    private function calculateAutoTtl(): int
    {
        $metrics = $this->getMetrics();
        $hitRate = $metrics['hit_rate'] ?? 0;

        // Higher hit rate = longer TTL
        if ($hitRate > 80) {
            return 3600; // 1 hour
        }

        if ($hitRate > 50) {
            return 1800; // 30 minutes
        }

        return 900; // 15 minutes
    }

    /**
     * Record cache metric
     *
     * @param string $key
     * @param bool $hit
     * @param float $time
     */
    private function recordMetric(string $key, bool $hit, float $time): void
    {
        try {
            $metrics = $this->getMetrics();

            $metrics['total_requests'] = ($metrics['total_requests'] ?? 0) + 1;
            $metrics['hits'] = ($metrics['hits'] ?? 0) + ($hit ? 1 : 0);
            $metrics['misses'] = ($metrics['misses'] ?? 0) + ($hit ? 0 : 1);
            $metrics['hit_rate'] = round(
                ($metrics['hits'] / $metrics['total_requests']) * 100,
                2
            );

            // Update average retrieval time
            $totalTime = ($metrics['avg_retrieval_time'] ?? 0) * ($metrics['total_requests'] - 1);
            $metrics['avg_retrieval_time'] = round(
                ($totalTime + $time) / $metrics['total_requests'],
                4
            );

            Cache::put(self::METRICS_KEY, $metrics, 86400); // Store for 24 hours

        } catch (\Exception $e) {
            // Fail silently for metrics
            Log::debug('Failed to record cache metric', [
                'key' => $key,
                'error' => $e->getMessage(),
            ]);
        }
    }

    /**
     * Create cache key with prefix
     *
     * @param string $prefix
     * @param array<mixed> $parts
     * @return string
     */
    public static function makeKey(string $prefix, array $parts = []): string
    {
        $key = $prefix;

        foreach ($parts as $part) {
            if (is_array($part)) {
                $part = md5(json_encode($part));
            }
            $key .= '_' . $part;
        }

        return $key;
    }
}
