<?php

use App\Http\Controllers\DokployApplicationController;
use App\Http\Controllers\DokployController;
use App\Http\Controllers\DokployDeploymentController;
use Illuminate\Support\Facades\Route;

/**
 * Dokploy Dashboard Routes
 *
 * All routes for Dokploy integration frontend
 * Requires authentication middleware
 */
Route::middleware(['auth'])->prefix('dokploy')->name('dokploy.')->group(function () {

    // Dashboard
    Route::get('/', [DokployController::class, 'index'])->name('index');

    // Projects
    Route::get('/projects/{id}', [DokployController::class, 'show'])->name('projects.show');

    // Applications
    Route::get('/applications/{id}', [DokployApplicationController::class, 'show'])->name('applications.show');

    // Deployment History
    Route::get('/deployments/history', [DokployController::class, 'deploymentHistory'])->name('deployments.history');

    // API Routes (JSON responses)
    Route::prefix('api')->name('api.')->group(function () {

        // Application operations
        Route::post('/applications/{id}/deploy', [DokployApplicationController::class, 'deploy'])->name('applications.deploy');
        Route::post('/applications/{id}/stop', [DokployApplicationController::class, 'stop'])->name('applications.stop');
        Route::post('/applications/{id}/restart', [DokployApplicationController::class, 'restart'])->name('applications.restart');
        Route::get('/applications/{id}/status', [DokployApplicationController::class, 'status'])->name('applications.status');

        // Logs
        Route::get('/applications/{id}/logs', [DokployApplicationController::class, 'logs'])->name('applications.logs');
        Route::get('/applications/{id}/logs/stream', [DokployApplicationController::class, 'streamLogs'])->name('applications.logs.stream');

        // Deployment operations
        Route::post('/deployments/{id}/rollback', [DokployDeploymentController::class, 'rollback'])->name('deployments.rollback');
        Route::post('/deployments/{id}/cancel', [DokployDeploymentController::class, 'cancel'])->name('deployments.cancel');
        Route::get('/deployments/{id}', [DokployDeploymentController::class, 'show'])->name('deployments.show');
        Route::get('/deployments/{id}/logs', [DokployDeploymentController::class, 'logs'])->name('deployments.logs');
        Route::get('/deployments/timeline', [DokployDeploymentController::class, 'timeline'])->name('deployments.timeline');
    });
});
