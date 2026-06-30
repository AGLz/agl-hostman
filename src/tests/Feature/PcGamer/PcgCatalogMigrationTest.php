<?php

use App\Models\PcGamer\PcgBuildPreset;
use App\Models\PcGamer\PcgComponentCategory;
use App\Models\PcGamer\PcgRetailer;
use App\Models\PcGamer\PcgTelegramSource;
use Database\Seeders\PcgCatalogSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

it('cria tabelas pcg_ via migration', function () {
    expect(\Schema::hasTable('pcg_builds'))->toBeTrue()
        ->and(\Schema::hasTable('pcg_telegram_offers'))->toBeTrue()
        ->and(\Schema::hasTable('pcg_build_presets'))->toBeTrue();
});

it('semeia catálogo pc gamer com categorias retailers presets e canais telegram', function () {
    $this->seed(PcgCatalogSeeder::class);

    expect(PcgComponentCategory::query()->count())->toBe(10)
        ->and(PcgRetailer::query()->count())->toBe(10)
        ->and(PcgBuildPreset::query()->count())->toBe(4)
        ->and(PcgTelegramSource::query()->count())->toBeGreaterThanOrEqual(5);
});
