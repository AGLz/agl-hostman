<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use App\Services\Performance\PerformanceProfiler;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Log;

/**
 * Performance Monitoring Middleware
 *
 * Monitors API response times, database queries,
 * and logs performance issues.
 */
class PerformanceMiddleware
{
    private PerformanceProfiler $profiler;

    public function __construct(PerformanceProfiler $profiler)
    {
        $this->profiler = $profiler;
    }

    /**
     * Handle an incoming request.
     */
    public function handle(Request $request, Closure $next): Response
    {
        // Skip profiling for health checks and internal routes
        if ($this->shouldSkipProfiling($request)) {
            return $next($request);
        }

        // Start profiling
        $this->profiler->start($request);

        // Process request
        $response = $next($request);

        // Stop profiling and collect metrics
        $metrics = $this->profiler->stop();

        // Add performance headers
        if (! empty($metrics)) {
            $response->headers->set('X-Response-Time', ($metrics['duration_ms'] ?? 0).'ms');
            $response->headers->set('X-Memory-Usage', ($metrics['memory_mb'] ?? 0).'MB');
            $response->headers->set('X-Query-Count', (string) ($metrics['query_count'] ?? 0));
            $response->headers->set('X-Request-ID', $metrics['request_id'] ?? uniqid());
        }

        // Check for N+1 problems
        $nPlusOneWarnings = $this->profiler->detectNPlusOne();
        if (! empty($nPlusOneWarnings)) {
            Log::warning('Performance: N+1 query problems detected', [
                'request_id' => $metrics['request_id'] ?? null,
                'path' => $request->path(),
                'warnings' => $nPlusOneWarnings,
            ]);
        }

        return $response;
    }

    /**
     * Determine if profiling should be skipped
     */
    protected function shouldSkipProfiling(Request $request): bool
    {
        $skipPaths = [
            'health',
            'metrics',
            'telescope',
            'horizon',
            '_ignition',
        ];

        foreach ($skipPaths as $path) {
            if (str_contains($request->path(), $path)) {
                return true;
            }
        }

        // Skip if profiler is disabled
        if (! $this->profiler->isEnabled()) {
            return true;
        }

        return false;
    }
}
