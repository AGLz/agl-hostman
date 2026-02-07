<?php

declare(strict_types=1);

namespace Tests\Unit\Services;

use App\Services\CacheService;
use App\Services\RedisCacheStrategy;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
use Tests\TestCase;

/**
 * Redis Cache Strategy Service Test
 *
 * Tests for the RedisCacheStrategy class.
 *
 * @package Tests\Unit\Services
 */
class RedisCacheStrategyTest extends TestCase
{
    private RedisCacheStrategy $cacheStrategy;
    private CacheService $cacheService;

    protected function setUp(): void
    {
        parent::setUp();

        $this->cacheService = $this->createMock(CacheService::class);
        $this->cacheStrategy = new RedisCacheStrategy($this->cacheService);
    }

    /**
     * Test caching API response
     */
    public function test_cache_api_response(): void
    {
        $endpoint = '/api/containers';
        $parameters = ['status' => 'running'];
        $callback = fn() => ['data' => 'test'];

        $this->cacheService->expects($this->once())
            ->method('remember')
            ->willReturn(['data' => 'test']);

        $result = $this->cacheStrategy->cacheApiResponse(
            $endpoint,
            $parameters,
            $callback,
            'medium'
        );

        $this->assertEquals(['data' => 'test'], $result);
    }

    /**
     * Test caching Proxmox response
     */
    public function test_cache_proxmox_response(): void
    {
        $resource = 'containers';
        $identifier = '101';
        $callback = fn() => ['vmid' => '101', 'name' => 'test-vm'];

        $this->cacheService->expects($this->once())
            ->method('rememberWithLock')
            ->willReturn(['vmid' => '101', 'name' => 'test-vm']);

        $result = $this->cacheStrategy->cacheProxmoxResponse(
            $resource,
            $identifier,
            $callback,
            'short'
        );

        $this->assertEquals(['vmid' => '101', 'name' => 'test-vm'], $result);
    }

    /**
     * Test caching Dokploy response
     */
    public function test_cache_dokploy_response(): void
    {
        $resource = 'applications';
        $identifier = 'app-1';
        $callback = fn() => ['id' => 'app-1', 'name' => 'test-app'];

        $this->cacheService->expects($this->once())
            ->method('remember')
            ->willReturn(['id' => 'app-1', 'name' => 'test-app']);

        $result = $this->cacheStrategy->cacheDokployResponse(
            $resource,
            $identifier,
            $callback,
            'medium'
        );

        $this->assertEquals(['id' => 'app-1', 'name' => 'test-app'], $result);
    }

    /**
     * Test caching Harbor response
     */
    public function test_cache_harbor_response(): void
    {
        $resource = 'projects';
        $identifier = 'project-1';
        $callback = fn() => ['id' => 'project-1', 'name' => 'test-project'];

        $this->cacheService->expects($this->once())
            ->method('remember')
            ->willReturn(['id' => 'project-1', 'name' => 'test-project']);

        $result = $this->cacheStrategy->cacheHarborResponse(
            $resource,
            $identifier,
            $callback,
            'long'
        );

        $this->assertEquals(['id' => 'project-1', 'name' => 'test-project'], $result);
    }

    /**
     * Test caching database query result
     */
    public function test_cache_db_query(): void
    {
        $table = 'containers';
        $conditions = ['status' => 'running'];
        $callback = fn() => ['id' => 1, 'name' => 'container-1'];

        $this->cacheService->expects($this->once())
            ->method('remember')
            ->willReturn(['id' => 1, 'name' => 'container-1']);

        $result = $this->cacheStrategy->cacheDbQuery(
            $table,
            $conditions,
            $callback,
            'short'
        );

        $this->assertEquals(['id' => 1, 'name' => 'container-1'], $result);
    }

    /**
     * Test caching user data
     */
    public function test_cache_user_data(): void
    {
        $userId = 1;
        $dataType = 'permissions';
        $callback = fn() => ['admin' => true, 'edit' => true];

        $this->cacheService->expects($this->once())
            ->method('remember')
            ->willReturn(['admin' => true, 'edit' => true]);

        $result = $this->cacheStrategy->cacheUserData(
            $userId,
            $dataType,
            $callback,
            'long'
        );

        $this->assertEquals(['admin' => true, 'edit' => true], $result);
    }

    /**
     * Test caching metrics
     */
    public function test_cache_metrics(): void
    {
        $metricType = 'cpu';
        $resource = 'server-1';
        $callback = fn() => ['usage' => 45.5, 'cores' => 4];

        $this->cacheService->expects($this->once())
            ->method('remember')
            ->willReturn(['usage' => 45.5, 'cores' => 4]);

        $result = $this->cacheStrategy->cacheMetrics(
            $metricType,
            $resource,
            $callback,
            'short'
        );

        $this->assertEquals(['usage' => 45.5, 'cores' => 4], $result);
    }

    /**
     * Test invalidating resource cache
     */
    public function test_invalidate_resource(): void
    {
        $resourceType = 'containers';
        $identifier = '101';

        $this->cacheService->expects($this->once())
            ->method('flushTags')
            ->willReturn(true);

        Log::shouldReceive('info')->once();

        $result = $this->cacheStrategy->invalidateResource($resourceType, $identifier);

        $this->assertEquals(1, $result);
    }

    /**
     * Test invalidating containers cache
     */
    public function test_invalidate_containers(): void
    {
        $vmid = '101';

        $this->cacheService->expects($this->exactly(2))
            ->method('flushTags')
            ->willReturn(true);

        $result = $this->cacheStrategy->invalidateContainers($vmid);

        $this->assertTrue($result);
    }

    /**
     * Test invalidating all containers
     */
    public function test_invalidate_all_containers(): void
    {
        $this->cacheService->expects($this->once())
            ->method('flushTags')
            ->willReturn(true);

        $result = $this->cacheStrategy->invalidateContainers();

        $this->assertTrue($result);
    }

    /**
     * Test invalidating deployments cache
     */
    public function test_invalidate_deployments(): void
    {
        $deploymentId = 'deployment-1';

        $this->cacheService->expects($this->once())
            ->method('flushTags')
            ->willReturn(true);

        $result = $this->cacheStrategy->invalidateDeployments($deploymentId);

        $this->assertTrue($result);
    }

    /**
     * Test invalidating images cache
     */
    public function test_invalidate_images(): void
    {
        $imageId = 'image-1';

        $this->cacheService->expects($this->once())
            ->method('flushTags')
            ->willReturn(true);

        $result = $this->cacheStrategy->invalidateImages($imageId);

        $this->assertTrue($result);
    }

    /**
     * Test invalidating user cache
     */
    public function test_invalidate_user(): void
    {
        $userId = 1;

        $this->cacheService->expects($this->once())
            ->method('flushTags')
            ->willReturn(true);

        $result = $this->cacheStrategy->invalidateUser($userId);

        $this->assertTrue($result);
    }

    /**
     * Test warming cache
     */
    public function test_warm_cache(): void
    {
        $data = ['key1' => 'value1', 'key2' => 'value2'];
        $category = 'containers';

        $this->cacheService->expects($this->once())
            ->method('warm')
            ->willReturn(2);

        Log::shouldReceive('info')->once();

        $result = $this->cacheStrategy->warmCache($data, $category);

        $this->assertEquals(2, $result);
    }

    /**
     * Test clearing all cache
     */
    public function test_clear_all(): void
    {
        Cache::shouldReceive('flush')->once();
        Log::shouldReceive('info')->once();

        $result = $this->cacheStrategy->clearAll();

        $this->assertTrue($result);
    }

    /**
     * Test clear all handles exceptions
     */
    public function test_clear_all_handles_exceptions(): void
    {
        Cache::shouldReceive('flush')
            ->andThrow(new \Exception('Cache error'));

        Log::shouldReceive('error')->once();

        $result = $this->cacheStrategy->clearAll();

        $this->assertFalse($result);
    }

    /**
     * Test getting performance metrics
     */
    public function test_get_performance_metrics(): void
    {
        $this->cacheService->expects($this->once())
            ->method('getMetrics')
            ->willReturn([
                'hits' => 100,
                'misses' => 10,
                'hit_rate' => 90.91,
            ]);

        $result = $this->cacheStrategy->getPerformanceMetrics();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('hits', $result);
        $this->assertArrayHasKey('misses', $result);
        $this->assertArrayHasKey('hit_rate', $result);
        $this->assertArrayHasKey('redis_info', $result);
        $this->assertArrayHasKey('memory_usage', $result);
        $this->assertArrayHasKey('key_count', $result);
    }

    /**
     * Test TTL resolution
     */
    public function test_resolve_ttl(): void
    {
        $reflection = new \ReflectionClass($this->cacheStrategy);
        $method = $reflection->getMethod('resolveTtl');
        $method->setAccessible(true);

        $shortTtl = $method->invoke($this->cacheStrategy, 'short');
        $mediumTtl = $method->invoke($this->cacheStrategy, 'medium');
        $longTtl = $method->invoke($this->cacheStrategy, 'long');
        $dayTtl = $method->invoke($this->cacheStrategy, 'day');
        $weekTtl = $method->invoke($this->cacheStrategy, 'week');
        $defaultTtl = $method->invoke($this->cacheStrategy, 'invalid');

        $this->assertEquals(300, $shortTtl);
        $this->assertEquals(1800, $mediumTtl);
        $this->assertEquals(3600, $longTtl);
        $this->assertEquals(86400, $dayTtl);
        $this->assertEquals(604800, $weekTtl);
        $this->assertEquals(1800, $defaultTtl);
    }

    /**
     * Test API key generation
     */
    public function test_make_api_key(): void
    {
        $reflection = new \ReflectionClass($this->cacheStrategy);
        $method = $reflection->getMethod('makeApiKey');
        $method->setAccessible(true);

        $endpoint = '/api/containers';
        $parameters = ['status' => 'running'];

        $key = $method->invoke($this->cacheStrategy, $endpoint, $parameters);

        $this->assertStringStartsWith('api_', $key);
        $this->assertStringContainsString('_api_containers', $key);
    }

    /**
     * Test Proxmox key generation
     */
    public function test_make_proxmox_key(): void
    {
        $reflection = new \ReflectionClass($this->cacheStrategy);
        $method = $reflection->getMethod('makeProxmoxKey');
        $method->setAccessible(true);

        $resource = 'containers';
        $identifier = '101';

        $key = $method->invoke($this->cacheStrategy, $resource, $identifier);

        $this->assertEquals('proxmox_containers_101', $key);
    }

    /**
     * Test user key generation
     */
    public function test_make_user_key(): void
    {
        $reflection = new \ReflectionClass($this->cacheStrategy);
        $method = $reflection->getMethod('makeUserKey');
        $method->setAccessible(true);

        $userId = 1;
        $dataType = 'permissions';

        $key = $method->invoke($this->cacheStrategy, $userId, $dataType);

        $this->assertEquals('user_1_permissions', $key);
    }

    /**
     * Test metrics key generation
     */
    public function test_make_metrics_key(): void
    {
        $reflection = new \ReflectionClass($this->cacheStrategy);
        $method = $reflection->getMethod('makeMetricsKey');
        $method->setAccessible(true);

        $metricType = 'cpu';
        $resource = 'server-1';

        $key = $method->invoke($this->cacheStrategy, $metricType, $resource);

        $this->assertEquals('metrics_cpu_server-1', $key);
    }

    /**
     * Test extracting tags from endpoint
     */
    public function test_extract_tags_from_endpoint(): void
    {
        $reflection = new \ReflectionClass($this->cacheStrategy);
        $method = $reflection->getMethod('extractTagsFromEndpoint');
        $method->setAccessible(true);

        $tags1 = $method->invoke($this->cacheStrategy, '/api/containers');
        $this->assertContains('containers', $tags1);

        $tags2 = $method->invoke($this->cacheStrategy, '/api/deployments');
        $this->assertContains('deployments', $tags2);

        $tags3 = $method->invoke($this->cacheStrategy, '/api/servers');
        $this->assertContains('servers', $tags3);

        $tags4 = $method->invoke($this->cacheStrategy, '/api/images');
        $this->assertContains('images', $tags4);

        $tags5 = $method->invoke($this->cacheStrategy, '/api/users');
        $this->assertContains('users', $tags5);
    }

    /**
     * Test getting resource tags
     */
    public function test_get_resource_tags(): void
    {
        $reflection = new \ReflectionClass($this->cacheStrategy);
        $method = $reflection->getMethod('getResourceTags');
        $method->setAccessible(true);

        $tags1 = $method->invoke($this->cacheStrategy, 'containers');
        $this->assertContains('containers', $tags1);

        $tags2 = $method->invoke($this->cacheStrategy, 'deployments');
        $this->assertContains('deployments', $tags2);

        $tags3 = $method->invoke($this->cacheStrategy, 'nodes');
        $this->assertContains('servers', $tags3);
    }

    /**
     * Test getting table tags
     */
    public function test_get_table_tags(): void
    {
        $reflection = new \ReflectionClass($this->cacheStrategy);
        $method = $reflection->getMethod('getTableTags');
        $method->setAccessible(true);

        $tags1 = $method->invoke($this->cacheStrategy, 'users');
        $this->assertContains('users', $tags1);

        $tags2 = $method->invoke($this->cacheStrategy, 'containers');
        $this->assertContains('containers', $tags2);

        $tags3 = $method->invoke($this->cacheStrategy, 'deployments');
        $this->assertContains('deployments', $tags3);
    }

    /**
     * Test getting category tags
     */
    public function test_get_category_tags(): void
    {
        $reflection = new \ReflectionClass($this->cacheStrategy);
        $method = $reflection->getMethod('getCategoryTags');
        $method->setAccessible(true);

        $tags1 = $method->invoke($this->cacheStrategy, 'containers');
        $this->assertContains('containers', $tags1);

        $tags2 = $method->invoke($this->cacheStrategy, 'infrastructure');
        $this->assertContains('servers', $tags2);
        $this->assertContains('containers', $tags2);
    }
}
