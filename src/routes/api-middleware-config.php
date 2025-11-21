<?php

/**
 * API Middleware Configuration
 *
 * Phase 1 Critical Security Fixes:
 * - N8N Webhook HMAC Verification
 * - API Rate Limiting (100 req/min per user)
 *
 * Add these routes to routes/api.php
 */

use App\Http\Middleware\VerifyN8NWebhook;
use App\Http\Middleware\ThrottleApiRequests;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| N8N Webhook Routes (with HMAC verification)
|--------------------------------------------------------------------------
*/

Route::middleware([VerifyN8NWebhook::class])
    ->prefix('webhooks')
    ->group(function () {
        // N8N webhook endpoint with HMAC signature verification
        Route::post('/n8n', [App\Http\Controllers\N8NController::class, 'handleWebhook'])
            ->name('webhooks.n8n');

        // Additional webhook endpoints can be added here
    });

/*
|--------------------------------------------------------------------------
| API Routes (with rate limiting)
|--------------------------------------------------------------------------
*/

// Apply rate limiting to all API routes
Route::middleware([ThrottleApiRequests::class . ':100,1']) // 100 requests per minute
    ->prefix('api')
    ->group(function () {

        // Infrastructure endpoints
        Route::prefix('infrastructure')->group(function () {
            Route::get('/locations', [App\Http\Controllers\InfrastructureController::class, 'locations']);
            Route::get('/servers/{code}', [App\Http\Controllers\InfrastructureController::class, 'server']);
            Route::get('/analytics', [App\Http\Controllers\InfrastructureController::class, 'analytics']);
        });

        // AI Model endpoints (stricter rate limiting)
        Route::middleware([ThrottleApiRequests::class . ':20,1']) // 20 requests per minute for AI
            ->prefix('ai')
            ->group(function () {
                Route::post('/query', [App\Http\Controllers\AIController::class, 'query']);
                Route::post('/multi-agent', [App\Http\Controllers\AIController::class, 'multiAgent']);
                Route::get('/models', [App\Http\Controllers\AIController::class, 'models']);
                Route::post('/analyze-infrastructure', [App\Http\Controllers\AIController::class, 'analyzeInfrastructure']);
            });

        // N8N Integration endpoints
        Route::prefix('n8n')->group(function () {
            Route::post('/execute', [App\Http\Controllers\N8NController::class, 'execute']);
            Route::post('/monitoring', [App\Http\Controllers\N8NController::class, 'triggerMonitoring']);
            Route::get('/workflows', [App\Http\Controllers\N8NController::class, 'listWorkflows']);
        });

        // Scrum Board endpoints
        Route::prefix('scrum')->group(function () {
            Route::get('/dashboard', [App\Http\Controllers\ScrumController::class, 'dashboard']);
            Route::get('/board', [App\Http\Controllers\ScrumController::class, 'board']);

            Route::get('/sprints', [App\Http\Controllers\ScrumController::class, 'sprints']);
            Route::post('/sprints', [App\Http\Controllers\ScrumController::class, 'createSprint']);

            Route::get('/tasks', [App\Http\Controllers\ScrumController::class, 'tasks']);
            Route::post('/tasks', [App\Http\Controllers\ScrumController::class, 'createTask']);
            Route::post('/tasks/{id}/move', [App\Http\Controllers\ScrumController::class, 'moveTask']);
        });
    });

/*
|--------------------------------------------------------------------------
| Admin Routes (higher rate limits for authenticated admins)
|--------------------------------------------------------------------------
*/

Route::middleware(['auth:sanctum', ThrottleApiRequests::class . ':300,1']) // 300 requests per minute for admins
    ->prefix('api/admin')
    ->group(function () {
        Route::get('/metrics', [App\Http\Controllers\AdminController::class, 'metrics']);
        Route::get('/users', [App\Http\Controllers\AdminController::class, 'users']);
        Route::post('/config/cache-clear', [App\Http\Controllers\AdminController::class, 'clearCache']);
    });

/*
|--------------------------------------------------------------------------
| Public Routes (very strict rate limiting)
|--------------------------------------------------------------------------
*/

Route::middleware([ThrottleApiRequests::class . ':30,1']) // 30 requests per minute for public
    ->prefix('api/public')
    ->group(function () {
        Route::get('/status', function () {
            return response()->json([
                'status' => 'operational',
                'version' => config('app.version'),
                'timestamp' => now()->toIso8601String(),
            ]);
        });
    });

/*
|--------------------------------------------------------------------------
| Rate Limit Management (admin only)
|--------------------------------------------------------------------------
*/

Route::middleware(['auth:sanctum', 'role:admin'])
    ->prefix('api/admin/rate-limits')
    ->group(function () {
        Route::post('/clear/{key}', function ($key) {
            App\Http\Middleware\ThrottleApiRequests::clearRateLimit($key);
            return response()->json(['message' => 'Rate limit cleared']);
        });

        Route::get('/status', function (Illuminate\Http\Request $request) {
            $status = App\Http\Middleware\ThrottleApiRequests::getRateLimitStatus($request, 100);
            return response()->json($status);
        });
    });
