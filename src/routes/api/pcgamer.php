<?php

use App\Http\Controllers\Api\PcGamer\BuildController;
use App\Http\Controllers\Api\PcGamer\CatalogController;
use App\Http\Controllers\Api\PcGamer\MarketPriceController;
use App\Http\Controllers\Api\PcGamer\PresetController;
use App\Http\Controllers\Api\PcGamer\TelegramOfferController;
use Illuminate\Support\Facades\Route;

Route::middleware(['auth:sanctum', 'throttle:60,1'])->prefix('pcgamer')->name('api.pcgamer.')->group(function () {
    Route::get('/categories', [CatalogController::class, 'categories'])->name('categories');
    Route::get('/components', [CatalogController::class, 'components'])->name('components.index');
    Route::post('/components', [CatalogController::class, 'storeComponent'])->name('components.store');

    Route::get('/presets', [PresetController::class, 'index'])->name('presets.index');

    Route::get('/market-prices', [MarketPriceController::class, 'index'])->name('market-prices.index');
    Route::post('/market-prices', [MarketPriceController::class, 'store'])->name('market-prices.store');

    Route::get('/builds', [BuildController::class, 'index'])->name('builds.index');
    Route::post('/builds', [BuildController::class, 'store'])->name('builds.store');
    Route::get('/builds/{build}', [BuildController::class, 'show'])->name('builds.show');
    Route::put('/builds/{build}/items/{item}', [BuildController::class, 'updateItem'])->name('builds.items.update');
    Route::post('/builds/{build}/transition', [BuildController::class, 'transition'])->name('builds.transition');
    Route::get('/builds/{build}/compare', [BuildController::class, 'compare'])->name('builds.compare');

    Route::get('/telegram-offers', [TelegramOfferController::class, 'index'])->name('telegram-offers.index');
});

// Ingest sidecar Python — autenticação por API key (padrão daily-memory)
Route::middleware(['api.key', 'throttle:60,1'])->prefix('pcgamer')->name('api.pcgamer.ingest.')->group(function () {
    Route::post('/telegram-offers', [TelegramOfferController::class, 'store'])->name('telegram-offers.store');
});
