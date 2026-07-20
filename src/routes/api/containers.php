<?php

use Illuminate\Support\Facades\Route;

// Container Management Routes
Route::prefix("containers")->middleware('auth:sanctum')->name("containers.")->group(function () {
    Route::get("/", [\App\Http\Controllers\API\ContainerController::class, "index"])->name("index");
    Route::get("/{id}", [\App\Http\Controllers\API\ContainerController::class, "show"])->name("show");
    Route::post("/", [\App\Http\Controllers\API\ContainerController::class, "store"])->name("store");
    Route::post("/clone", [\App\Http\Controllers\API\ContainerController::class, "clone"])->name("clone");
    Route::post("/{id}/snapshot", [\App\Http\Controllers\API\ContainerController::class, "snapshot"])->name("snapshot");
    Route::post("/{id}/start", [\App\Http\Controllers\API\ContainerController::class, "start"])->name("start");
    Route::post("/{id}/stop", [\App\Http\Controllers\API\ContainerController::class, "stop"])->name("stop");
    Route::post("/{id}/restart", [\App\Http\Controllers\API\ContainerController::class, "restart"])->name("restart");
    Route::delete("/{id}", [\App\Http\Controllers\API\ContainerController::class, "destroy"])->name("destroy");
    Route::get("/{id}/status", [\App\Http\Controllers\API\ContainerController::class, "status"])->name("status");
});

// Container Backup Routes
Route::prefix("containers")->middleware('auth:sanctum')->name("containers.")->group(function () {
    Route::get("/{id}/backups", [\App\Http\Controllers\API\ContainerBackupController::class, "index"])->name("backups.index");
    Route::get("/{id}/backups/{backupId}", [\App\Http\Controllers\API\ContainerBackupController::class, "show"])->name("backups.show");
    Route::post("/{id}/backups", [\App\Http\Controllers\API\ContainerBackupController::class, "store"])->name("backups.store");
    Route::delete("/{id}/backups/{backupId}", [\App\Http\Controllers\API\ContainerBackupController::class, "destroy"])->name("backups.destroy");
    Route::get("/{id}/backups/stats", [\App\Http\Controllers\API\ContainerBackupController::class, "stats"])->name("backups.stats");
});

// Container Migration Routes
Route::prefix("containers")->middleware('auth:sanctum')->name("containers.")->group(function () {
    Route::get("/{id}/migrations", [\App\Http\Controllers\API\ContainerMigrationController::class, "index"])->name("migrations.index");
    Route::get("/{id}/migrations/{migrationId}", [\App\Http\Controllers\API\ContainerMigrationController::class, "show"])->name("migrations.show");
    Route::post("/{id}/migrate", [\App\Http\Controllers\API\ContainerMigrationController::class, "store"])->name("migrations.store");
    Route::post("/{id}/migrations/{migrationId}/cancel", [\App\Http\Controllers\API\ContainerMigrationController::class, "cancel"])->name("migrations.cancel");
    Route::post("/{id}/migrations/{migrationId}/rollback", [\App\Http\Controllers\API\ContainerMigrationController::class, "rollback"])->name("migrations.rollback");
    Route::get("/{id}/migrations/{migrationId}/progress", [\App\Http\Controllers\API\ContainerMigrationController::class, "progress"])->name("migrations.progress");
    Route::get("/{id}/migrations/stats", [\App\Http\Controllers\API\ContainerMigrationController::class, "stats"])->name("migrations.stats");
});

