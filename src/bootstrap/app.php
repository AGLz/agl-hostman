<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        channels: __DIR__.'/../routes/channels.php',
        health: '/up',
        then: function () {
            // Reason: rotas rbac-test expõem helpers sem auth adequada — só em ambiente local.
            if (app()->environment('local')) {
                Route::middleware('web')
                    ->group(base_path('routes/rbac-test.php'));
            }

            Route::middleware('web')
                ->group(base_path('routes/location-test.php'));
        },
    )
    ->withMiddleware(function (Middleware $middleware): void {
        // Phase 5: RBAC & Performance Middleware Aliases
        $middleware->alias([
            'permission' => \App\Http\Middleware\CheckPermission::class,
            'role' => \App\Http\Middleware\CheckRole::class,
            'active' => \App\Http\Middleware\EnsureUserIsActive::class,
            'location' => \App\Http\Middleware\CheckLocationAccess::class,
            'cache.api' => \App\Http\Middleware\CacheApiResponse::class,
            'throttle' => \App\Http\Middleware\RateLimiting::class,
            'performance' => \App\Http\Middleware\PerformanceMiddleware::class,
            'cache.response' => \App\Http\Middleware\CacheMiddleware::class,
            // MCP Server Security
            'mcp.security' => \App\Http\Middleware\McpSecurity::class,
            'mcp.rbac' => \App\Http\Middleware\McpRbac::class,
            // API Key Authentication (for OpenClaw/Jarvis integration)
            'api.key' => \App\Http\Middleware\ApiKeyAuth::class,
        ]);

        // Apply security and performance middleware to API routes
        $middleware->api(prepend: [
            \App\Http\Middleware\SecurityHeaders::class,
            \App\Http\Middleware\RateLimiting::class,
            \App\Http\Middleware\CacheApiResponse::class,
            \App\Http\Middleware\PerformanceMiddleware::class,
        ]);

        // Apply security middleware to web routes
        $middleware->web(prepend: [
            \App\Http\Middleware\SecurityHeaders::class,
        ]);

        $middleware->web(append: [
            \App\Http\Middleware\HandleInertiaRequests::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        //
    })->create();
