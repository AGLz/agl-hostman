<?php

declare(strict_types=1);

use App\Http\Controllers\Api\HarnessController;
use Illuminate\Support\Facades\Route;

Route::middleware(['auth:sanctum', 'throttle:60,1'])->prefix('harness')->group(function () {
    Route::get('/snapshot', [HarnessController::class, 'snapshot'])->name('api.harness.snapshot');
});
