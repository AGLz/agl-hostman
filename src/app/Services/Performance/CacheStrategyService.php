<?php

declare(strict_types=1);

namespace App\Services\Performance;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Redis;

/**
 * Cache Strategy Service
 *
 * Implements intelligent caching strategies with automatic
 * invalidation, TTL management, and cache warming.
 */
class CacheStrategyService
{
    private array $strategies = [];

    private string $prefix;

    public function __construct()
    {
        $this->prefix = config('cache.prefix', 'agl_cache');
        $this->initializeStrategies();
    }

    /**
     * Initialize cache strategies for different data types
     */
    protected function initializeStrategies(): void
    {
        $this->strategies = [
            // Infrastructure monitoring data (short TTL - changes frequently)
            'infrastructure.status' => [
                'ttl' => 30, // 30 seconds
                'tags' => ['infrastructure', 'monitoring'],
                'warm_on_boot' => true,
            ],

            // Server metrics
            'server.metrics.{code}' => [
                'ttl' => 15, // 15 seconds
                'tags' => ['infrastructure', 'metrics', 'server:{code}'],
                'warm_on_boot' => false,
            ],

            // User permissions (medium TTL - changes rarely)
            'user.permissions.{id}' => [
                'ttl' => 3600, // 1 hour
                'tags' => ['user', 'permissions', 'user:{id}'],
                'warm_on_boot' => false,
            ],

            // User roles (medium TTL)
            'user.roles.{id}' => [
                'ttl' => 3600, // 1 hour
                'tags' => ['user', 'roles', 'user:{id}'],
                'warm_on_boot' => false,
            ],

            // N8N workflows (medium TTL)
            'n8n.workflows' => [
                'ttl' => 600, // 10 minutes
                'tags' => ['n8n', 'workflows'],
                'warm_on_boot' => true,
            ],

            // N8N workflow executions (short TTL)
            'n8n.executions.{workflow}' => [
                'ttl' => 60, // 1 minute
                'tags' => ['n8n', 'executions', 'workflow:{workflow}'],
                'warm_on_boot' => false,
            ],

            // Monitoring alerts (short TTL - critical data)
            'monitoring.alerts' => [
                'ttl' => 10, // 10 seconds
                'tags' => ['monitoring', 'alerts'],
                'warm_on_boot' => false,
            ],

            // Monitoring trends (longer TTL - aggregated data)
            'monitoring.trends.{hours}' => [
                'ttl' => 300, // 5 minutes
                'tags' => ['monitoring', 'trends'],
                'warm_on_boot' => false,
            ],

            // Harbor projects (medium TTL)
            'harbor.projects' => [
                'ttl' => 900, // 15 minutes
                'tags' => ['harbor', 'projects'],
                'warm_on_boot' => false,
            ],

            // Dokploy applications (medium TTL)
            'dokploy.applications' => [
                'ttl' => 300, // 5 minutes
                'tags' => ['dokploy', 'applications'],
                'warm_on_boot' => false,
            ],

            // Scrum board data (medium TTL)
            'scrum.sprints' => [
                'ttl' => 600, // 10 minutes
                'tags' => ['scrum', 'sprints'],
                'warm_on_boot' => false,
            ],

            'scrum.tasks' => [
                'ttl' => 300, // 5 minutes
                'tags' => ['scrum', 'tasks'],
                'warm_on_boot' => false,
            ],

            // Build metrics (short TTL)
            'build.metrics' => [
                'ttl' => 120, // 2 minutes
                'tags' => ['build', 'metrics'],
                'warm_on_boot' => false,
            ],
        ];
    }

    /**
     * Get cached data with strategy
     */
    public function remember(string $key, callable $callback, ?string $strategyKey = null): mixed
    {
        $strategy = $strategyKey ? $this->strategies[$strategyKey] ?? null : null;

        if ($strategy) {
            $ttl = $strategy['ttl'];
            $tags = $this->parseTags($strategy['tags'] ?? [], $key);
        } else {
            $ttl = config('performance.cache.default_ttl', 300);
            $tags = [];
        }

        $fullKey = $this->getFullKey($key);

        return Cache::tags($tags)->remember($fullKey, $ttl, $callback);
    }

    /**
     * Remember forever (for static/semi-static data)
     */
    public function rememberForever(string $key, callable $callback, array $tags = []): mixed
    {
        $fullKey = $this->getFullKey($key);
        $parsedTags = $this->parseTags($tags, $key);

        return Cache::tags($parsedTags)->rememberForever($fullKey, $callback);
    }

    /**
     * Cache data manually with strategy
     */
    public function put(string $key, mixed $value, ?string $strategyKey = null): bool
    {
        $strategy = $strategyKey ? $this->strategies[$strategyKey] ?? null : null;

        if ($strategy) {
            $ttl = $strategy['ttl'];
            $tags = $this->parseTags($strategy['tags'] ?? [], $key);
        } else {
            $ttl = config('performance.cache.default_ttl', 300);
            $tags = [];
        }

        $fullKey = $this->getFullKey($key);

        return Cache::tags($tags)->put($fullKey, $value, $ttl);
    }

    /**
     * Get cached data
     */
    public function get(string $key): mixed
    {
        $fullKey = $this->getFullKey($key);

        return Cache::get($fullKey);
    }

    /**
     * Check if key exists
     */
    public function has(string $key): bool
    {
        $fullKey = $this->getFullKey($key);

        return Cache::has($fullKey);
    }

    /**
     * Invalidate cache by key
     */
    public function forget(string $key): bool
    {
        $fullKey = $this->getFullKey($key);

        return Cache::forget($fullKey);
    }

    /**
     * Invalidate cache by tags
     */
    public function forgetByTags(array $tags): bool
    {
        Cache::tags($tags)->flush();

        return true;
    }

    /**
     * Warm up cache for specific strategy
     */
    public function warmUp(string $strategyKey, callable $dataProvider): void
    {
        $strategy = $this->strategies[$strategyKey] ?? null;

        if (! $strategy || ! $strategy['warm_on_boot']) {
            return;
        }

        $this->remember($strategyKey, $dataProvider, $strategyKey);
    }

    /**
     * Warm up all cache strategies marked for warmup
     */
    public function warmUpAll(array $dataProviders): void
    {
        foreach ($this->strategies as $key => $strategy) {
            if ($strategy['warm_on_boot'] && isset($dataProviders[$key])) {
                $this->warmUp($key, $dataProviders[$key]);
            }
        }
    }

    /**
     * Get cache statistics
     */
    public function getStats(): array
    {
        $redis = Redis::connection();

        return [
            'keys' => $redis->dbSize(),
            'memory' => $redis->info('memory'),
            'stats' => $redis->info('stats'),
            'strategies' => array_keys($this->strategies),
        ];
    }

    /**
     * Get full cache key with prefix
     */
    protected function getFullKey(string $key): string
    {
        return "{$this->prefix}:{$key}";
    }

    /**
     * Parse tags and replace placeholders
     */
    protected function parseTags(array $tags, string $key): array
    {
        $parsed = [];

        // Extract parameters from key for tag replacement
        $params = $this->extractParamsFromKey($key);

        foreach ($tags as $tag) {
            $parsedTag = $tag;

            // Replace {param} placeholders
            foreach ($params as $param => $value) {
                $parsedTag = str_replace("{{$param}}", (string) $value, $parsedTag);
            }

            $parsed[] = $parsedTag;
        }

        return array_filter($parsed);
    }

    /**
     * Extract parameters from cache key
     */
    protected function extractParamsFromKey(string $key): array
    {
        preg_match_all('/\.([a-z_]+)\.([a-f0-9-]+|[^.]+)/i', $key, $matches);

        $params = [];
        if (! empty($matches[1])) {
            foreach ($matches[1] as $index => $param) {
                $params[$param] = $matches[2][$index] ?? null;
            }
        }

        return $params;
    }

    /**
     * Get all available strategies
     */
    public function getStrategies(): array
    {
        return $this->strategies;
    }

    /**
     * Get specific strategy
     */
    public function getStrategy(string $key): ?array
    {
        return $this->strategies[$key] ?? null;
    }
}
