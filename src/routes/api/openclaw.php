<?php

use App\Http\Controllers\Api\OpenClawController;
use Illuminate\Support\Facades\Route;

// OpenClaw API (for Mission Control integration)
Route::prefix('openclaw')->group(function () {
    Route::get('/', [OpenClawController::class, 'index'])->name('api.openclaw.index');
    Route::get('/agents', [OpenClawController::class, 'agents'])->name('api.openclaw.agents');
    Route::get('/sessions', [OpenClawController::class, 'sessions'])->name('api.openclaw.sessions');
    Route::get('/tasks', [OpenClawController::class, 'tasks'])->name('api.openclaw.tasks');
    Route::post('/execute', [OpenClawController::class, 'execute'])->name('api.openclaw.execute');
});
