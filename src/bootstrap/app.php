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
            Route::middleware('web')
                ->group(base_path('routes/rbac-test.php'));

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
        ]);

        // Apply security and performance middleware to API routes (Laravel 11)
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
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        //
    })->create();
