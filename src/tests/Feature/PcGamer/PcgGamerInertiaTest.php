<?php

declare(strict_types=1);

use App\Http\Controllers\PcGamer\BuildController;
use App\Models\User;
use Database\Seeders\PcgCatalogSeeder;
use Illuminate\Foundation\Http\Middleware\ValidateCsrfToken;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

covers(BuildController::class);

beforeEach(function () {
    $this->withoutVite();
    $this->withoutMiddleware(ValidateCsrfToken::class);
    $this->seed(PcgCatalogSeeder::class);
    $this->user = User::factory()->create();
});

it('renderiza lista de builds Inertia', function () {
    $this->actingAs($this->user);

    $this->get(route('pc-gamer.builds.index'))
        ->assertOk()
        ->assertInertia(fn ($page) => $page
            ->component('PcGamer/Builds/Index')
            ->has('builds')
            ->has('filters')
        );
});

it('cria build via web e redirecciona para show', function () {
    $this->actingAs($this->user);

    $response = $this->post(route('pc-gamer.builds.store'), [
        'title' => 'PC Web Test',
        'margin_percent' => 12,
    ]);

    $response->assertRedirect();
    $this->assertDatabaseHas('pcg_builds', ['title' => 'PC Web Test']);
});

it('renderiza show com comparativo', function () {
    $this->actingAs($this->user);

    $this->post(route('pc-gamer.builds.store'), ['title' => 'Show test']);
    $buildId = (int) \App\Models\PcGamer\PcgBuild::query()->value('id');

    $this->get(route('pc-gamer.builds.show', $buildId))
        ->assertOk()
        ->assertInertia(fn ($page) => $page
            ->component('PcGamer/Builds/Show')
            ->has('build')
            ->where('build.id', $buildId)
        );
});

it('renderiza presets e market prices', function () {
    $this->actingAs($this->user);

    $this->get(route('pc-gamer.presets.index'))
        ->assertOk()
        ->assertInertia(fn ($page) => $page
            ->component('PcGamer/Presets/Index')
            ->has('presets')
        );

    $this->get(route('pc-gamer.market-prices.index'))
        ->assertOk()
        ->assertInertia(fn ($page) => $page
            ->component('PcGamer/MarketPrices/Index')
            ->has('prices')
        );
});
