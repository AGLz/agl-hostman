<?php

declare(strict_types=1);

use Illuminate\Support\Facades\Route;
use App\Services\MetricsCollector;

/**
 * Monitoring Dashboard Routes
 *
 * Real-time infrastructure monitoring endpoints
 * Includes Livewire dashboard and API endpoints for metrics
 */

// Monitoring Dashboard (Livewire)
Route::middleware(['auth'])->prefix('monitoring')->name('monitoring.')->group(function () {

    // Main Dashboard Page (Livewire Enhanced)
    Route::get('/', function () {
        return view('app'); // Inertia will handle routing
    })->name('dashboard');

    // Server Detail View
    Route::get('/server/{code}', function (string $code) {
        return view('app'); // Inertia will handle routing
    })->name('server.show');

    // Container Detail View
    Route::get('/container/{id}', function (string $id) {
        return view('app'); // Inertia will handle routing
    })->name('container.show');

    // Force Refresh Endpoint (bypasses cache)
    Route::post('/refresh', function (MetricsCollector $metricsCollector) {
        $metricsCollector->refreshAllMetrics();

        return response()->json([
            'success' => true,
            'message' => 'Metrics cache cleared',
            'timestamp' => now()->toIso8601String(),
        ]);
    })->name('refresh');

    // Export Metrics Endpoint
    Route::get('/export', function (MetricsCollector $metricsCollector) {
        $metrics = $metricsCollector->aggregateAllMetrics();

        $filename = 'infrastructure-metrics-' . now()->format('Y-m-d-His') . '.json';

        return response()->json($metrics)
            ->header('Content-Disposition', "attachment; filename={$filename}");
    })->name('export');

    // API Endpoints for AJAX/fetch requests
    Route::prefix('api')->name('api.')->group(function () {

        // Get all aggregated metrics
        Route::get('/metrics', function (MetricsCollector $metricsCollector) {
            return response()->json($metricsCollector->aggregateAllMetrics());
        })->name('metrics.all');

        // Get server metrics
        Route::get('/server/{code}/metrics', function (string $code, MetricsCollector $metricsCollector) {
            return response()->json($metricsCollector->collectServerMetrics($code));
        })->name('server.metrics');

        // Get container metrics for a server
        Route::get('/server/{serverId}/containers', function (string $serverId, MetricsCollector $metricsCollector) {
            return response()->json([
                'success' => true,
                'containers' => $metricsCollector->collectContainerMetrics($serverId),
            ]);
        })->name('server.containers');

        // Get network metrics
        Route::get('/network', function (MetricsCollector $metricsCollector) {
            return response()->json($metricsCollector->collectNetworkMetrics());
        })->name('network.metrics');

        // Get storage metrics
        Route::get('/storage', function (MetricsCollector $metricsCollector) {
            return response()->json($metricsCollector->collectStorageMetrics());
        })->name('storage.metrics');
    });
});
