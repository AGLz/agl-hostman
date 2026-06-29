<?php

declare(strict_types=1);

use App\Http\Controllers\Api\LlmMonitorController;
use Illuminate\Support\Facades\Route;

Route::middleware(['auth:sanctum', 'throttle:60,1'])->prefix('llm-monitor')->group(function () {
    Route::get('/status', [LlmMonitorController::class, 'status'])->name('api.llm-monitor.status');
    Route::get('/providers/{provider}', [LlmMonitorController::class, 'provider'])->name('api.llm-monitor.provider');
    Route::post('/proposals/{proposal}/approve', [LlmMonitorController::class, 'approveProposal'])->name('api.llm-monitor.proposals.approve');
    Route::post('/proposals/{proposal}/reject', [LlmMonitorController::class, 'rejectProposal'])->name('api.llm-monitor.proposals.reject');
});

Route::middleware(['api.key', 'throttle:30,1'])->prefix('llm-monitor')->group(function () {
    Route::post('/ingest', [LlmMonitorController::class, 'ingest'])->name('api.llm-monitor.ingest');
    Route::post('/probe', [LlmMonitorController::class, 'dispatchProbe'])->name('api.llm-monitor.probe');
    Route::post('/ingest/dispatch', [LlmMonitorController::class, 'dispatchIngest'])->name('api.llm-monitor.ingest.dispatch');
    Route::post('/proposals', [LlmMonitorController::class, 'storeProposal'])->name('api.llm-monitor.proposals.store');
});
