<?php

declare(strict_types=1);

use App\Http\Controllers\Api\MissionControlHostController;
use Illuminate\Support\Facades\Route;

Route::middleware(['auth:sanctum', 'throttle:60,1'])->prefix('mission-control')->group(function () {
    Route::get('/hosts/{code}/snapshot', [MissionControlHostController::class, 'snapshot'])
        ->name('api.mission-control.hosts.snapshot');
    Route::get('/hosts/{code}/guests', [MissionControlHostController::class, 'guests'])
        ->name('api.mission-control.hosts.guests');
    Route::post('/hosts/{code}/refresh', [MissionControlHostController::class, 'refresh'])
        ->name('api.mission-control.hosts.refresh');
});
