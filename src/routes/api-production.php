<?php

use App\Http\Controllers\BackupController;
use App\Http\Controllers\DeploymentController;
use App\Http\Controllers\MonitoringController;
use App\Http\Controllers\ProductionApprovalController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Production Deployment API Routes
|--------------------------------------------------------------------------
|
| Routes for production environment deployment with blue-green strategy,
| 2-level approval workflow, monitoring, and backup management.
|
*/

// Production deployment routes (require admin role)
Route::prefix('deployment/production')->middleware(['auth:sanctum', 'role:admin'])->group(function () {
    // Approval workflow
    Route::post('/request', [ProductionApprovalController::class, 'requestProductionDeployment'])
        ->name('production.approval.request');

    Route::post('/approve/{id}', [ProductionApprovalController::class, 'approveProductionDeployment'])
        ->name('production.approval.approve');

    Route::post('/reject/{id}', [ProductionApprovalController::class, 'rejectProductionDeployment'])
        ->name('production.approval.reject');

    Route::get('/approval-status/{environmentId}', [ProductionApprovalController::class, 'getApprovalStatus'])
        ->name('production.approval.status');

    Route::get('/approvals/pending', [ProductionApprovalController::class, 'listPendingApprovals'])
        ->name('production.approvals.pending');

    // Deployment operations
    Route::post('/deploy', [DeploymentController::class, 'deployToProduction'])
        ->name('production.deploy');

    Route::post('/rollback', [DeploymentController::class, 'rollbackProduction'])
        ->name('production.rollback');

    Route::get('/status', [DeploymentController::class, 'getProductionStatus'])
        ->name('production.status');

    Route::post('/switch-traffic', [DeploymentController::class, 'switchTraffic'])
        ->name('production.switch-traffic');
});

// Production monitoring routes (authenticated users)
Route::prefix('monitoring/production')->middleware('auth:sanctum')->group(function () {
    Route::get('/metrics', [MonitoringController::class, 'getProductionMetrics'])
        ->name('production.monitoring.metrics');

    Route::get('/health', [MonitoringController::class, 'getProductionHealth'])
        ->name('production.monitoring.health');

    Route::get('/alerts', [MonitoringController::class, 'getActiveAlerts'])
        ->name('production.monitoring.alerts');

    Route::get('/dashboard', [MonitoringController::class, 'getGrafanaDashboard'])
        ->name('production.monitoring.dashboard');
});

// Backup routes (require admin role)
Route::prefix('backup')->middleware(['auth:sanctum', 'role:admin'])->group(function () {
    Route::post('/trigger', [BackupController::class, 'triggerBackup'])
        ->name('production.backup.trigger');

    Route::get('/status', [BackupController::class, 'getBackupStatus'])
        ->name('production.backup.status');

    Route::get('/history', [BackupController::class, 'getBackupHistory'])
        ->name('production.backup.history');

    Route::post('/restore', [BackupController::class, 'restoreBackup'])
        ->name('production.backup.restore');

    Route::delete('/{id}', [BackupController::class, 'deleteBackup'])
        ->name('production.backup.delete');
});

// Public health check (no authentication)
Route::get('/health', function () {
    return response()->json([
        'status' => 'healthy',
        'timestamp' => now()->toIso8601String(),
        'environment' => config('app.env'),
    ]);
})->name('health');

// Prometheus metrics endpoint (no authentication, but can be IP-restricted)
Route::get('/metrics', [MonitoringController::class, 'exportPrometheusMetrics'])
    ->name('metrics.prometheus');
