<?php

declare(strict_types=1);

use App\Http\Controllers\Api\HermesController;
use Illuminate\Support\Facades\Route;

Route::prefix('hermes')->group(function () {
    Route::get('/', [HermesController::class, 'index'])->name('api.hermes.index');
    Route::get('/status', [HermesController::class, 'index'])->name('api.hermes.status');
    Route::get('/agents', [HermesController::class, 'agents'])->name('api.hermes.agents');
    Route::get('/ui-links', [HermesController::class, 'uiLinks'])->name('api.hermes.ui-links');
    Route::get('/scheduled-tasks', [HermesController::class, 'scheduledTasks'])->name('api.hermes.scheduled-tasks');
    Route::post('/agents/{agent}/chat', [HermesController::class, 'chat'])->name('api.hermes.agents.chat');
    Route::get('/tasks', [HermesController::class, 'tasks'])->name('api.hermes.tasks');
});

Route::get('/agents', [HermesController::class, 'agentList'])->name('api.agents.index');
Route::get('/agent-status', [HermesController::class, 'agentStatus'])->name('api.agent-status');
Route::get('/tasks/summary', [HermesController::class, 'taskSummary'])->name('api.tasks.summary');
