<?php

declare(strict_types=1);

namespace App\Services;

use Closure;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

/**
 * Redis Cache Strategy Service
 *
 * Comprehensive caching strategy for AGL Hostman with:
 * - Multi-layer caching (L1: Redis, L2: Database)
 * - Intelligent cache invalidation
 * - API response caching
 * - External service integration caching
 * - Automatic cache warming
 * - Cache tagging and hierarchical invalidation
 * - Rate limiting and throttling
 * - Cache stampede prevention
 */
class RedisCacheStrategy
{
    // Cache key prefixes
    private const PREFIX_API = 'api';

    private const PREFIX_PROXMOX = 'proxmox';

    private const PREFIX_DOKPLOY = 'dokploy';

    private const PREFIX_HARBOR = 'harbor';

    private const PREFIX_DB = 'db';

    private const PREFIX_METRICS = 'metrics';

    // Cache TTLs (in seconds)
    private const TTL_SHORT = 300;        // 5 minutes - Real-time data

    private const TTL_MEDIUM = 1800;      // 30 minutes - Semi-static data

    private const TTL_LONG = 3600;        // 1 hour - Static data

    private const TTL_DAILY = 86400;      // 24 hours - Rarely changing data

    private const TTL_WEEKLY = 604800;    // 7 days - Reference data

    // Cache tags for hierarchical invalidation
    private const TAG_CONTAINERS = 'containers';

    private const TAG_DEPLOYMENTS = 'deployments';

    private const TAG_SERVERS = 'servers';

    private const TAG_IMAGES = 'images';

    private const TAG_USERS = 'users';

    private const TAG_METRICS = 'metrics';

    private CacheService $cacheService;

    public function __construct(CacheService $cacheService)
    {
        $this->cacheService = $cacheService;
    }

    /**
     * Cache API response with headers
     *
     * @param  string  $endpoint  API endpoint path
     * @param  array  $parameters  Request parameters
     * @param  Closure  $callback  Data fetcher callback
     * @param  string|null  $ttl  TTL strategy
     */
    public function cacheApiResponse(
        string $endpoint,
        array $parameters,
        Closure $callback,
        ?string $ttl = 'medium'
    ): mixed {
        $key = $this->makeApiKey($endpoint, $parameters);
        $tags = $this->extractTagsFromEndpoint($endpoint);
        $resolvedTtl = $this->resolveTtl($ttl);

        return $this->cacheService->remember(
            $key,
            $callback,
            $resolvedTtl,
            $tags
        );
    }

    /**
     * Cache Proxmox API response
     *
     * @param  string  $resource  Resource type (containers, vms, nodes, etc.)
     * @param  string|null  $identifier  Resource ID
     * @param  Closure  $callback  Proxmox API callback
     * @param  string|null  $ttl  TTL strategy
     */
    public function cacheProxmoxResponse(
        string $resource,
        ?string $identifier,
        Closure $callback,
        ?string $ttl = 'short'
    ): mixed {
        $key = $this->makeProxmoxKey($resource, $identifier);
        $tags = array_merge([self::TAG_SERVERS], $this->getResourceTags($resource));
        $resolvedTtl = $this->resolveTtl($ttl);

        // Use cache stampede prevention for Proxmox
        return $this->cacheService->rememberWithLock(
            $key,
            $callback,
            $resolvedTtl,
            10  // 10 second lock
        );
    }

    /**
     * Cache Dokploy API response
     *
     * @param  string  $resource  Resource type (applications, deployments, etc.)
     * @param  string|null  $identifier  Resource ID
     * @param  Closure  $callback  Dokploy API callback
     * @param  string|null  $ttl  TTL strategy
     */
    public function cacheDokployResponse(
        string $resource,
        ?string $identifier,
        Closure $callback,
        ?string $ttl = 'medium'
    ): mixed {
        $key = $this->makeDokployKey($resource, $identifier);
        $tags = array_merge([self::TAG_DEPLOYMENTS], $this->getResourceTags($resource));
        $resolvedTtl = $this->resolveTtl($ttl);

        return $this->cacheService->remember(
            $key,
            $callback,
            $resolvedTtl,
            $tags
        );
    }

    /**
     * Cache Harbor API response
     *
     * @param  string  $resource  Resource type (projects, repositories, artifacts, etc.)
     * @param  string|null  $identifier  Resource ID
     * @param  Closure  $callback  Harbor API callback
     * @param  string|null  $ttl  TTL strategy
     */
    public function cacheHarborResponse(
        string $resource,
        ?string $identifier,
        Closure $callback,
        ?string $ttl = 'long'
    ): mixed {
        $key = $this->makeHarborKey($resource, $identifier);
        $tags = array_merge([self::TAG_IMAGES], $this->getResourceTags($resource));
        $resolvedTtl = $this->resolveTtl($ttl);

        return $this->cacheService->remember(
            $key,
            $callback,
            $resolvedTtl,
            $tags
        );
    }

    /**
     * Cache database query result
     *
     * @param  string  $table  Database table name
     * @param  array  $conditions  Query conditions
     * @param  Closure  $callback  Query callback
     * @param  string|null  $ttl  TTL strategy
     */
    public function cacheDbQuery(
        string $table,
        array $conditions,
        Closure $callback,
        ?string $ttl = 'short'
    ): mixed {
        $key = $this->makeDbKey($table, $conditions);
        $tags = $this->getTableTags($table);
        $resolvedTtl = $this->resolveTtl($ttl);

        return $this->cacheService->remember(
            $key,
            $callback,
            $resolvedTtl,
            $tags
        );
    }

    /**
     * Cache user-specific data
     *
     * @param  int  $userId  User ID
     * @param  string  $dataType  Data type (permissions, preferences, etc.)
     * @param  Closure  $callback  Data fetcher callback
     * @param  string|null  $ttl  TTL strategy
     */
    public function cacheUserData(
        int $userId,
        string $dataType,
        Closure $callback,
        ?string $ttl = 'long'
    ): mixed {
        $key = $this->makeUserKey($userId, $dataType);
        $tags = [self::TAG_USERS, "user_{$userId}"];
        $resolvedTtl = $this->resolveTtl($ttl);

        return $this->cacheService->remember(
            $key,
            $callback,
            $resolvedTtl,
            $tags
        );
    }

    /**
     * Cache system metrics
     *
     * @param  string  $metricType  Metric type (cpu, memory, disk, etc.)
     * @param  string|null  $resource  Resource identifier
     * @param  Closure  $callback  Metrics fetcher callback
     * @param  string|null  $ttl  TTL strategy
     */
    public function cacheMetrics(
        string $metricType,
        ?string $resource,
        Closure $callback,
        ?string $ttl = 'short'
    ): mixed {
        $key = $this->makeMetricsKey($metricType, $resource);
        $tags = [self::TAG_METRICS, "metrics_{$metricType}"];
        $resolvedTtl = $this->resolveTtl($ttl);

        return $this->cacheService->remember(
            $key,
            $callback,
            $resolvedTtl,
            $tags
        );
    }

    /**
     * Invalidate cache by resource type
     *
     * @param  string  $resourceType  Resource type to invalidate
     * @param  string|null  $identifier  Specific resource ID (optional)
     * @return int Number of keys invalidated
     */
    public function invalidateResource(string $resourceType, ?string $identifier = null): int
    {
        $tags = $this->getResourceTags($resourceType);

        if ($identifier) {
            $tags[] = "{$resourceType}_{$identifier}";
        }

        $result = $this->cacheService->flushTags($tags);

        Log::info('Cache invalidated', [
            'resource_type' => $resourceType,
            'identifier' => $identifier,
            'tags' => $tags,
            'success' => $result,
        ]);

        return $result ? 1 : 0;
    }

    /**
     * Invalidate container cache
     *
     * @param  string|null  $vmid  Container VMID (null for all containers)
     */
    public function invalidateContainers(?string $vmid = null): bool
    {
        $tags = [self::TAG_CONTAINERS];

        if ($vmid) {
            $tags[] = "container_{$vmid}";
            // Also invalidate server cache
            $this->invalidateResource('servers');
        }

        return $this->cacheService->flushTags($tags);
    }

    /**
     * Invalidate deployment cache
     *
     * @param  string|null  $deploymentId  Deployment ID (null for all deployments)
     */
    public function invalidateDeployments(?string $deploymentId = null): bool
    {
        $tags = [self::TAG_DEPLOYMENTS];

        if ($deploymentId) {
            $tags[] = "deployment_{$deploymentId}";
        }

        return $this->cacheService->flushTags($tags);
    }

    /**
     * Invalidate image cache
     *
     * @param  string|null  $imageId  Image ID (null for all images)
     */
    public function invalidateImages(?string $imageId = null): bool
    {
        $tags = [self::TAG_IMAGES];

        if ($imageId) {
            $tags[] = "image_{$imageId}";
        }

        return $this->cacheService->flushTags($tags);
    }

    /**
     * Invalidate user cache
     *
     * @param  int  $userId  User ID
     */
    public function invalidateUser(int $userId): bool
    {
        return $this->cacheService->flushTags([self::TAG_USERS, "user_{$userId}"]);
    }

    /**
     * Warm cache with critical data
     *
     * @param  array<string, mixed>  $data  Data to warm
     * @param  string  $category  Cache category
     * @return int Number of items warmed
     */
    public function warmCache(array $data, string $category = 'general'): int
    {
        $tags = $this->getCategoryTags($category);
        $count = $this->cacheService->warm($data, 'long', $tags);

        Log::info('Cache warmed', [
            'category' => $category,
            'items' => $count,
        ]);

        return $count;
    }

    /**
     * Get cache performance metrics
     *
     * @return array<string, mixed>
     */
    public function getPerformanceMetrics(): array
    {
        $metrics = $this->cacheService->getMetrics();

        // Add custom metrics
        $metrics['redis_info'] = $this->getRedisInfo();
        $metrics['memory_usage'] = $this->getRedisMemoryUsage();
        $metrics['key_count'] = $this->getRedisKeyCount();

        return $metrics;
    }

    /**
     * Clear all application cache
     */
    public function clearAll(): bool
    {
        try {
            Cache::flush();
            Log::info('All cache cleared');

            return true;
        } catch (\Exception $e) {
            Log::error('Failed to clear cache', [
                'error' => $e->getMessage(),
            ]);

            return false;
        }
    }

    /**
     * Generate cache key for API endpoints
     */
    private function makeApiKey(string $endpoint, array $parameters): string
    {
        $params = empty($parameters) ? '' : '_'.md5(json_encode($parameters));

        return self::PREFIX_API.'_'.str_replace('/', '_', $endpoint).$params;
    }

    /**
     * Generate cache key for Proxmox resources
     */
    private function makeProxmoxKey(string $resource, ?string $identifier): string
    {
        $key = self::PREFIX_PROXMOX.'_'.$resource;
        if ($identifier) {
            $key .= '_'.$identifier;
        }

        return $key;
    }

    /**
     * Generate cache key for Dokploy resources
     */
    private function makeDokployKey(string $resource, ?string $identifier): string
    {
        $key = self::PREFIX_DOKPLOY.'_'.$resource;
        if ($identifier) {
            $key .= '_'.$identifier;
        }

        return $key;
    }

    /**
     * Generate cache key for Harbor resources
     */
    private function makeHarborKey(string $resource, ?string $identifier): string
    {
        $key = self::PREFIX_HARBOR.'_'.$resource;
        if ($identifier) {
            $key .= '_'.$identifier;
        }

        return $key;
    }

    /**
     * Generate cache key for database queries
     */
    private function makeDbKey(string $table, array $conditions): string
    {
        $params = empty($conditions) ? '' : '_'.md5(json_encode($conditions));

        return self::PREFIX_DB.'_'.$table.$params;
    }

    /**
     * Generate cache key for user data
     */
    private function makeUserKey(int $userId, string $dataType): string
    {
        return 'user_'.$userId.'_'.$dataType;
    }

    /**
     * Generate cache key for metrics
     */
    private function makeMetricsKey(string $metricType, ?string $resource): string
    {
        $key = self::PREFIX_METRICS.'_'.$metricType;
        if ($resource) {
            $key .= '_'.$resource;
        }

        return $key;
    }

    /**
     * Extract tags from API endpoint
     *
     * @return array<string>
     */
    private function extractTagsFromEndpoint(string $endpoint): array
    {
        $tags = [];

        if (Str::contains($endpoint, 'containers')) {
            $tags[] = self::TAG_CONTAINERS;
        }

        if (Str::contains($endpoint, 'deployments')) {
            $tags[] = self::TAG_DEPLOYMENTS;
        }

        if (Str::contains($endpoint, 'servers')) {
            $tags[] = self::TAG_SERVERS;
        }

        if (Str::contains($endpoint, 'images')) {
            $tags[] = self::TAG_IMAGES;
        }

        if (Str::contains($endpoint, 'users')) {
            $tags[] = self::TAG_USERS;
        }

        return $tags;
    }

    /**
     * Get resource-specific tags
     *
     * @return array<string>
     */
    private function getResourceTags(string $resource): array
    {
        $tags = [];

        switch ($resource) {
            case 'containers':
            case 'container':
                $tags[] = self::TAG_CONTAINERS;
                break;
            case 'deployments':
            case 'deployment':
            case 'applications':
                $tags[] = self::TAG_DEPLOYMENTS;
                break;
            case 'nodes':
            case 'servers':
                $tags[] = self::TAG_SERVERS;
                break;
            case 'images':
            case 'artifacts':
            case 'repositories':
                $tags[] = self::TAG_IMAGES;
                break;
        }

        return $tags;
    }

    /**
     * Get table-specific tags
     *
     * @return array<string>
     */
    private function getTableTags(string $table): array
    {
        $tags = [];

        switch ($table) {
            case 'users':
                $tags[] = self::TAG_USERS;
                break;
            case 'containers':
                $tags[] = self::TAG_CONTAINERS;
                break;
            case 'deployments':
                $tags[] = self::TAG_DEPLOYMENTS;
                break;
        }

        return $tags;
    }

    /**
     * Get category-specific tags
     *
     * @return array<string>
     */
    private function getCategoryTags(string $category): array
    {
        return match ($category) {
            'containers' => [self::TAG_CONTAINERS],
            'deployments' => [self::TAG_DEPLOYMENTS],
            'infrastructure' => [self::TAG_SERVERS, self::TAG_CONTAINERS],
            'registry' => [self::TAG_IMAGES],
            'users' => [self::TAG_USERS],
            'metrics' => [self::TAG_METRICS],
            default => [],
        };
    }

    /**
     * Resolve TTL strategy to seconds
     */
    private function resolveTtl(?string $ttl): int
    {
        return match ($ttl) {
            'short' => self::TTL_SHORT,
            'medium' => self::TTL_MEDIUM,
            'long' => self::TTL_LONG,
            'day' => self::TTL_DAILY,
            'week' => self::TTL_WEEKLY,
            default => self::TTL_MEDIUM,
        };
    }

    /**
     * Get Redis information
     *
     * @return array<string, mixed>
     */
    private function getRedisInfo(): array
    {
        try {
            if (! Cache::getStore() instanceof \Illuminate\Cache\RedisStore) {
                return ['error' => 'Redis not configured'];
            }

            $redis = Cache::getStore()->connection();
            $info = $redis->info();

            return [
                'version' => $info['redis_version'] ?? 'unknown',
                'uptime' => $info['uptime_in_days'] ?? 0,
                'connected_clients' => $info['connected_clients'] ?? 0,
                'used_memory' => $info['used_memory_human'] ?? 'unknown',
                'total_commands' => $info['total_commands_processed'] ?? 0,
                'keyspace_hits' => $info['keyspace_hits'] ?? 0,
                'keyspace_misses' => $info['keyspace_misses'] ?? 0,
            ];
        } catch (\Exception $e) {
            return ['error' => $e->getMessage()];
        }
    }

    /**
     * Get Redis memory usage
     *
     * @return array<string, mixed>
     */
    private function getRedisMemoryUsage(): array
    {
        try {
            if (! Cache::getStore() instanceof \Illuminate\Cache\RedisStore) {
                return ['error' => 'Redis not configured'];
            }

            $redis = Cache::getStore()->connection();
            $info = $redis->info('memory');

            return [
                'used_memory' => $info['used_memory'] ?? 0,
                'used_memory_peak' => $info['used_memory_peak'] ?? 0,
                'used_memory_percentage' => $info['used_memory_perc'] ?? 0,
                'maxmemory' => $info['maxmemory'] ?? 0,
            ];
        } catch (\Exception $e) {
            return ['error' => $e->getMessage()];
        }
    }

    /**
     * Get Redis key count
     */
    private function getRedisKeyCount(): int
    {
        try {
            if (! Cache::getStore() instanceof \Illuminate\Cache\RedisStore) {
                return 0;
            }

            $redis = Cache::getStore()->connection();
            $info = $redis->info('keyspace');

            $count = 0;
            foreach ($info as $db => $data) {
                if (preg_match('/keys=(\d+)/', $data, $matches)) {
                    $count += (int) $matches[1];
                }
            }

            return $count;
        } catch (\Exception $e) {
            return 0;
        }
    }
}
