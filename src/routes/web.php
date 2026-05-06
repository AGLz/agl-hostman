<?php

use App\Http\Controllers\Auth\LoginController;
use App\Http\Controllers\Auth\WorkOSController;
use Illuminate\Support\Facades\Route;

// Public routes
Route::get('/', function () {
    return view('app');
})->name('home');

// Sessão web (email/password) — o formulário em auth/login faz POST para route('login')
Route::prefix('auth')->group(function () {
    Route::get('/login', [LoginController::class, 'showLoginForm'])->name('login');
    Route::post('/login', [LoginController::class, 'login']);

    Route::get('/forgot-password', function () {
        return redirect()->route('login');
    })->name('password.request');

    Route::get('/workos/redirect', [WorkOSController::class, 'redirect'])->name('workos.redirect');
    Route::get('/workos/callback', [WorkOSController::class, 'callback'])->name('workos.callback');
});

// Protected routes
Route::middleware(['auth'])->group(function () {
    Route::get('/dashboard', function () {
        return view('app');
    })->name('dashboard');

    // SPA catch-all routes — servem view('app') para que o BrowserRouter
    // trate o routing do lado do cliente (evita 404/Inertia no refresh direto)
    Route::get('/infrastructure', fn() => view('app'))->name('infrastructure');
    Route::get('/metrics', fn() => view('app'))->name('metrics');
    Route::get('/scrum', fn() => view('app'))->name('scrum');
    Route::get('/memory', fn() => view('app'))->name('memory');
    Route::get('/notifications', fn() => view('app'))->name('notifications');
    Route::get('/mission-control/{path?}', fn() => view('app'))
        ->where('path', '.*')
        ->name('mission-control');

    // Dokploy Dashboard (client-side route)
    Route::get('/dokploy', function () {
        return view('app');
    })->name('dokploy');

    Route::post('/logout', [WorkOSController::class, 'logout'])->name('logout');

    Route::resource('daily-memory', \App\Http\Controllers\DailyMemoryController::class);

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

// Admin RBAC Routes
Route::middleware(['auth'])->prefix('admin')->name('admin.')->group(function () {
    // Roles management - Read operations
    Route::middleware(['permission:view-roles'])->prefix('roles')->name('roles.')->group(function () {
        Route::get('/', [\App\Http\Controllers\Admin\RolesController::class, 'index'])->name('index');
        Route::get('/create', [\App\Http\Controllers\Admin\RolesController::class, 'create'])->name('create');
        Route::get('/{role}', [\App\Http\Controllers\Admin\RolesController::class, 'show'])->name('show');
    });

    // Roles management - Write operations
    Route::middleware(['permission:create-roles'])->prefix('roles')->name('roles.')->group(function () {
        Route::post('/', [\App\Http\Controllers\Admin\RolesController::class, 'store'])->name('store');
    });

    Route::middleware(['permission:edit-roles'])->prefix('roles')->name('roles.')->group(function () {
        Route::get('/{role}/edit', [\App\Http\Controllers\Admin\RolesController::class, 'edit'])->name('edit');
        Route::put('/{role}', [\App\Http\Controllers\Admin\RolesController::class, 'update'])->name('update');
    });

    Route::middleware(['permission:delete-roles'])->prefix('roles')->name('roles.')->group(function () {
        Route::delete('/{role}', [\App\Http\Controllers\Admin\RolesController::class, 'destroy'])->name('destroy');
    });

    // Permissions management - Read operations
    Route::middleware(['permission:permissions.view'])->prefix('permissions')->name('permissions.')->group(function () {
        Route::get('/', [\App\Http\Controllers\Admin\PermissionsController::class, 'index'])->name('index');
        Route::get('/create', [\App\Http\Controllers\Admin\PermissionsController::class, 'create'])->name('create');
    });

    // Permissions management - Write operations
    Route::middleware(['permission:permissions.manage'])->prefix('permissions')->name('permissions.')->group(function () {
        Route::post('/', [\App\Http\Controllers\Admin\PermissionsController::class, 'store'])->name('store');
        Route::get('/{permission}/edit', [\App\Http\Controllers\Admin\PermissionsController::class, 'edit'])->name('edit');
        Route::put('/{permission}', [\App\Http\Controllers\Admin\PermissionsController::class, 'update'])->name('update');
        Route::delete('/{permission}', [\App\Http\Controllers\Admin\PermissionsController::class, 'destroy'])->name('destroy');
    });

    // User role & permission management
    Route::middleware(['permission:assign-roles'])->prefix('users')->name('users.')->group(function () {
        Route::get('/{user}/roles', [\App\Http\Controllers\Admin\UserRoleController::class, 'editRoles'])->name('roles.edit');
        Route::put('/{user}/roles', [\App\Http\Controllers\Admin\UserRoleController::class, 'updateRoles'])->name('roles.update');
        Route::delete('/{user}/roles/{role}', [\App\Http\Controllers\Admin\UserRoleController::class, 'removeRole'])->name('roles.remove');
    });

    Route::middleware(['permission:assign-permissions'])->prefix('users')->name('users.')->group(function () {
        Route::get('/{user}/permissions', [\App\Http\Controllers\Admin\UserRoleController::class, 'editPermissions'])->name('permissions.edit');
        Route::put('/{user}/permissions', [\App\Http\Controllers\Admin\UserRoleController::class, 'updatePermissions'])->name('permissions.update');
        Route::delete('/{user}/permissions/{permission}', [\App\Http\Controllers\Admin\UserRoleController::class, 'removePermission'])->name('permissions.remove');
    });

    Route::middleware(['permission:view-users'])->prefix('users')->name('users.')->group(function () {
        Route::get('/', function () {
            return redirect()->route('dashboard');
        })->name('roles');
        Route::get('/{user}/access', [\App\Http\Controllers\Admin\UserRoleController::class, 'showAccess'])->name('access');
    });
});

// Dokploy Dashboard Routes
require __DIR__.'/dokploy.php';

// =============================================================================
// Health Check Endpoints (Load Balancer & Monitoring)
// =============================================================================
Route::prefix('health')->name('health.')->group(function () {
    Route::get('/', [App\Http\Controllers\HealthCheckController::class, 'index'])->name('index');
    Route::get('/detailed', [App\Http\Controllers\HealthCheckController::class, 'detailed'])->name('detailed');
    Route::get('/database', [App\Http\Controllers\HealthCheckController::class, 'database'])->name('database');
    Route::get('/cache', [App\Http\Controllers\HealthCheckController::class, 'cache'])->name('cache');
    Route::get('/queue', [App\Http\Controllers\HealthCheckController::class, 'queue'])->name('queue');
    Route::get('/readiness', [App\Http\Controllers\HealthCheckController::class, 'readiness'])->name('readiness');
    Route::get('/liveness', [App\Http\Controllers\HealthCheckController::class, 'liveness'])->name('liveness');
});
