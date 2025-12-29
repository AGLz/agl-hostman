<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Auth\WorkOSController;
use App\Http\Controllers\DashboardController;

// Public routes
Route::get('/', function () {
    return view('app');
})->name('home');

// WorkOS Authentication
Route::prefix('auth')->group(function () {
    Route::get('/login', function () {
        return view('auth.login');
    })->name('login');

    Route::get('/workos/redirect', [WorkOSController::class, 'redirect'])->name('workos.redirect');
    Route::get('/workos/callback', [WorkOSController::class, 'callback'])->name('workos.callback');
    Route::post('/logout', [WorkOSController::class, 'logout'])->name('logout');
});

// Protected routes
Route::middleware(['auth'])->group(function () {
    Route::get('/dashboard', function () {
        return view('app');
    })->name('dashboard');

    // Dokploy Dashboard (client-side route)
    Route::get('/dokploy', function () {
        return view('app');
    })->name('dokploy');

    Route::post('/logout', [WorkOSController::class, 'logout'])->name('logout');

    // Monitoring Dashboard Routes
    Route::prefix('monitoring')->name('monitoring.')->group(function () {
        Route::get('/', [\App\Http\Controllers\DashboardController::class, 'index'])->name('index');

        // API endpoints for dashboard data
        Route::prefix('api')->name('api.')->group(function () {
            Route::get('/cluster-health', [\App\Http\Controllers\DashboardController::class, 'getClusterHealth'])->name('cluster-health');
            Route::get('/dashboard-stats', [\App\Http\Controllers\DashboardController::class, 'getDashboardStats'])->name('dashboard-stats');
            Route::get('/realtime-snapshot', [\App\Http\Controllers\DashboardController::class, 'getRealtimeSnapshot'])->name('realtime-snapshot');

            // Node-specific routes
            Route::get('/node/{node}', [\App\Http\Controllers\DashboardController::class, 'getNodeHealth'])->name('node-health');

            // Container-specific routes
            Route::get('/container/{node}/{vmid}/history', [\App\Http\Controllers\DashboardController::class, 'getContainerHistory'])->name('container-history');

            // Resource trends
            Route::get('/trends', [\App\Http\Controllers\DashboardController::class, 'getResourceTrends'])->name('resource-trends');

            // Alert history
            Route::get('/alerts/history', [\App\Http\Controllers\DashboardController::class, 'getAlertHistory'])->name('alert-history');

            // Predictive maintenance
            Route::get('/predictive/container', [\App\Http\Controllers\DashboardController::class, 'getPredictiveMaintenance'])->name('predictive-maintenance');
            Route::get('/predictive/cluster', [\App\Http\Controllers\DashboardController::class, 'getClusterForecasts'])->name('cluster-forecasts');
        });
    });
});

// Laravel Telescope (dev only)
if (app()->environment('local')) {
    Route::get('/telescope', function () {
        return redirect('/telescope/requests');
    });
}

// Laravel Horizon
Route::get('/horizon', function () {
    return redirect('/horizon/dashboard');
})->middleware(['auth']);


// Archon AI Command Center Routes
Route::middleware(['auth'])->prefix('archon')->name('archon.')->group(function () {
    // Dashboard
    Route::get('/', [\App\Http\Controllers\ArchonController::class, 'index'])->name('index');

    // Knowledge Base
    Route::get('/knowledge', [\App\Http\Controllers\ArchonController::class, 'knowledge'])->name('knowledge');
    Route::post('/knowledge/search', [\App\Http\Controllers\ArchonController::class, 'searchKnowledge'])->name('knowledge.search');
    Route::post('/knowledge/suggestions', [\App\Http\Controllers\ArchonController::class, 'searchSuggestions'])->name('knowledge.suggestions');
    Route::post('/knowledge/page', [\App\Http\Controllers\ArchonController::class, 'getPage'])->name('knowledge.page');
    Route::get('/knowledge/sources', [\App\Http\Controllers\ArchonController::class, 'getSources'])->name('knowledge.sources');
    Route::post('/knowledge/code', [\App\Http\Controllers\ArchonController::class, 'searchCodeExamples'])->name('knowledge.code');

    // Projects
    Route::resource('projects', \App\Http\Controllers\ArchonProjectController::class);
    Route::get('/projects/{project}/tasks/board', [\App\Http\Controllers\ArchonProjectController::class, 'taskBoard'])->name('projects.tasks.board');

    // Tasks
    Route::post('/tasks', [\App\Http\Controllers\ArchonTaskController::class, 'store'])->name('tasks.store');
    Route::put('/tasks/{task}', [\App\Http\Controllers\ArchonTaskController::class, 'update'])->name('tasks.update');
    Route::delete('/tasks/{task}', [\App\Http\Controllers\ArchonTaskController::class, 'destroy'])->name('tasks.destroy');
    Route::post('/tasks/bulk-update', [\App\Http\Controllers\ArchonTaskController::class, 'bulkUpdate'])->name('tasks.bulk-update');
});

// Alert Center (Phase 3)
Route::middleware(['auth'])->prefix('alerts')->name('alerts.')->group(function () {
    Route::get('/', [\App\Http\Controllers\AlertController::class, 'index'])->name('index');
});

// Network Topology Visualizer (Phase 3)
Route::middleware(['auth'])->prefix('network')->name('network.')->group(function () {
    Route::get('/topology', [\App\Http\Controllers\NetworkTopologyController::class, 'index'])->name('topology');
});

// Dokploy Dashboard Routes
require __DIR__.'/dokploy.php';
