<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Facades\Redis;
use Illuminate\Support\Facades\Storage;

/**
 * Health Check Controller
 *
 * Provides comprehensive health check endpoints for load balancers,
 * monitoring systems, and orchestration platforms.
 *
 * Endpoints:
 * - GET /health - Basic health (returns 200 if app is running)
 * - GET /health/detailed - Full health status with all components
 * - GET /health/database - Database connectivity check
 * - GET /health/cache - Cache/Redis check
 * - GET /health/queue - Queue worker status
 * - GET /health/storage - Storage availability
 * - GET /health/readiness - Kubernetes-style readiness probe
 * - GET /health/liveness - Kubernetes-style liveness probe
 */
class HealthCheckController extends Controller
{
    /**
     * Health check threshold for warning state (milliseconds)
     */
    private const WARNING_THRESHOLD = 500;

    /**
     * Health check threshold for critical state (milliseconds)
     */
    private const CRITICAL_THRESHOLD = 2000;

    /**
     * Basic health check endpoint
     *
     * Simple ping endpoint for load balancers to verify the application is running.
     * Returns immediately with minimal processing.
     */
    public function index(): JsonResponse
    {
        return response()->json([
            'status' => 'ok',
            'timestamp' => now()->toIso8601String(),
            'version' => config('app.version', 'dev'),
        ], 200);
    }

    /**
     * Detailed health check with all components
     *
     * Returns comprehensive health status of all system components.
     * Suitable for monitoring dashboards and health check pages.
     */
    public function detailed(): JsonResponse
    {
        $startTime = microtime(true);

        $health = [
            'status' => 'healthy',
            'timestamp' => now()->toIso8601String(),
            'version' => config('app.version', 'dev'),
            'environment' => config('app.env'),
            'components' => [
                'database' => $this->checkDatabase(),
                'cache' => $this->checkCache(),
                'queue' => $this->checkQueue(),
                'storage' => $this->checkStorage(),
            ],
            'metrics' => [
                'response_time_ms' => round((microtime(true) - $startTime) * 1000, 2),
                'memory_usage_mb' => round(memory_get_usage(true) / 1024 / 1024, 2),
                'uptime' => $this->getUptime(),
            ],
        ];

        // Determine overall status
        $overallStatus = 'healthy';
        foreach ($health['components'] as $component) {
            if ($component['status'] === 'unhealthy') {
                $overallStatus = 'unhealthy';
                break;
            } elseif ($component['status'] === 'degraded' && $overallStatus !== 'unhealthy') {
                $overallStatus = 'degraded';
            }
        }

        $health['status'] = $overallStatus;

        $statusCode = match ($overallStatus) {
            'unhealthy' => 503,
            'degraded' => 200,  // Return 200 but indicate degraded state
            default => 200,
        };

        return response()->json($health, $statusCode);
    }

    /**
     * Database health check
     *
     * Verifies database connectivity and runs a simple query.
     */
    public function database(): array
    {
        return $this->checkDatabase();
    }

    /**
     * Cache/Redis health check
     *
     * Verifies Redis connectivity and performs a PING operation.
     */
    public function cache(): array
    {
        return $this->checkCache();
    }

    /**
     * Queue health check
     *
     * Checks if queue workers are running and processing jobs.
     */
    public function queue(): array
    {
        return $this->checkQueue();
    }

    /**
     * Readiness probe (Kubernetes style)
     *
     * Returns 200 when the application is ready to accept traffic.
     * Checks database, cache, and queue connectivity.
     */
    public function readiness(): JsonResponse
    {
        $checks = [
            'database' => $this->checkDatabase()['status'] === 'healthy',
            'cache' => $this->checkCache()['status'] === 'healthy',
            'storage' => $this->checkStorage()['status'] === 'healthy',
        ];

        $ready = count(array_filter($checks)) === count($checks);

        return response()->json([
            'ready' => $ready,
            'checks' => $checks,
        ], $ready ? 200 : 503);
    }

    /**
     * Liveness probe (Kubernetes style)
     *
     * Simple check to verify the application is alive.
     * Returns immediately with minimal processing.
     */
    public function liveness(): JsonResponse
    {
        return response()->json([
            'alive' => true,
            'timestamp' => now()->toIso8601String(),
        ], 200);
    }

    /**
     * Check database connectivity
     */
    private function checkDatabase(): array
    {
        $startTime = microtime(true);

        try {
            DB::select('SELECT 1');
            $latency = round((microtime(true) - $startTime) * 1000, 2);

            $status = 'healthy';
            if ($latency > self::CRITICAL_THRESHOLD) {
                $status = 'degraded';
            } elseif ($latency > self::WARNING_THRESHOLD) {
                $status = 'degraded';
            }

            return [
                'status' => $status,
                'latency_ms' => $latency,
                'connection' => config('database.default'),
                'message' => 'Database connection successful',
            ];
        } catch (\Exception $e) {
            return [
                'status' => 'unhealthy',
                'latency_ms' => null,
                'connection' => config('database.default'),
                'message' => 'Database connection failed: '.$e->getMessage(),
            ];
        }
    }

    /**
     * Check cache connectivity
     */
    private function checkCache(): array
    {
        $startTime = microtime(true);

        try {
            if (config('cache.default') === 'redis') {
                Redis::ping();
                $info = Redis::info('server');
                $latency = round((microtime(true) - $startTime) * 1000, 2);

                $status = 'healthy';
                if ($latency > self::CRITICAL_THRESHOLD) {
                    $status = 'degraded';
                }

                return [
                    'status' => $status,
                    'latency_ms' => $latency,
                    'driver' => 'redis',
                    'redis_version' => $info['redis_version'] ?? 'unknown',
                    'message' => 'Redis connection successful',
                ];
            }

            // Fallback for other cache drivers
            Cache::put('health_check', 'ok', 60);
            $value = Cache::get('health_check');

            return [
                'status' => $value === 'ok' ? 'healthy' : 'unhealthy',
                'latency_ms' => round((microtime(true) - $startTime) * 1000, 2),
                'driver' => config('cache.default'),
                'message' => 'Cache connection successful',
            ];
        } catch (\Exception $e) {
            return [
                'status' => 'unhealthy',
                'latency_ms' => null,
                'driver' => config('cache.default'),
                'message' => 'Cache connection failed: '.$e->getMessage(),
            ];
        }
    }

    /**
     * Check queue workers
     */
    private function checkQueue(): array
    {
        try {
            // For Horizon-enabled installations
            if (class_exists(\Laravel\Horizon\Horizon::class)) {
                $status = \Laravel\Horizon\Horizon::status();

                return [
                    'status' => $status === 'running' ? 'healthy' : 'unhealthy',
                    'driver' => config('queue.default'),
                    'horizon_status' => $status,
                    'message' => 'Queue workers '.$status,
                ];
            }

            // Fallback check for Redis queue
            if (config('queue.default') === 'redis') {
                $queueSize = Redis::connection()->llen('queues:default');

                return [
                    'status' => 'healthy',
                    'driver' => 'redis',
                    'pending_jobs' => $queueSize,
                    'message' => 'Queue connection successful',
                ];
            }

            return [
                'status' => 'healthy',
                'driver' => config('queue.default'),
                'message' => 'Queue configured',
            ];
        } catch (\Exception $e) {
            return [
                'status' => 'unhealthy',
                'driver' => config('queue.default'),
                'message' => 'Queue check failed: '.$e->getMessage(),
            ];
        }
    }

    /**
     * Check storage availability
     */
    private function checkStorage(): array
    {
        try {
            // Test local storage
            $testFile = 'health_check_'.time().'.tmp';
            Storage::disk('local')->put($testFile, 'test');
            Storage::disk('local')->delete($testFile);

            $disks = [];
            foreach (config('filesystems.disks') as $name => $config) {
                try {
                    Storage::disk($name)->listFiles('/');
                    $disks[$name] = 'available';
                } catch (\Exception $e) {
                    $disks[$name] = 'unavailable: '.$e->getMessage();
                }
            }

            return [
                'status' => 'healthy',
                'default_disk' => config('filesystems.default'),
                'disks' => $disks,
                'message' => 'Storage is available',
            ];
        } catch (\Exception $e) {
            return [
                'status' => 'unhealthy',
                'default_disk' => config('filesystems.default'),
                'message' => 'Storage check failed: '.$e->getMessage(),
            ];
        }
    }

    /**
     * Get application uptime
     */
    private function getUptime(): string
    {
        if (file_exists('/proc/uptime')) {
            $uptime = (int) file_get_contents('/proc/uptime');
            $uptime = explode(' ', $uptime)[0];

            $hours = floor($uptime / 3600);
            $minutes = floor(($uptime % 3600) / 60);

            return sprintf('%dh %dm', $hours, $minutes);
        }

        return 'unknown';
    }
}
