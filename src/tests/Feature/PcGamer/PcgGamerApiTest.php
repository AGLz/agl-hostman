<?php

declare(strict_types=1);

use App\Enums\PcGamer\BuildStatus;
use App\Http\Controllers\Api\PcGamer\BuildController;
use App\Http\Controllers\Api\PcGamer\TelegramOfferController;
use App\Models\PcGamer\PcgMarketPrice;
use App\Models\PcGamer\PcgTelegramOffer;
use App\Models\User;
use Database\Seeders\PcgCatalogSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

covers(BuildController::class, TelegramOfferController::class);

beforeEach(function () {
    $this->seed(PcgCatalogSeeder::class);
    config(['services.hostman.api_key' => 'pcgamer-test-api-key']);
});

it('exige autenticação Sanctum para builds', function () {
    $this->getJson('/api/pcgamer/builds')->assertUnauthorized();
});

it('cria build com template AMD e 10 slots', function () {
    $this->actingAs(User::factory()->create(), 'sanctum');

    $response = $this->postJson('/api/pcgamer/builds', [
        'title' => 'PC Cliente Teste',
        'customer_name' => 'João',
        'margin_percent' => 20,
    ]);

    $response->assertCreated()
        ->assertJsonPath('data.title', 'PC Cliente Teste')
        ->assertJsonPath('data.status', 'draft')
        ->assertJsonCount(10, 'data.items');

    expect($response->json('data.code'))->toMatch('/^PC-\d{4}-\d{3}$/');
});

it('actualiza item e calcula quote_cents', function () {
    $this->actingAs(User::factory()->create(), 'sanctum');

    $build = $this->postJson('/api/pcgamer/builds', ['title' => 'Quote test'])->json('data');
    $itemId = $build['items'][0]['id'];

    $this->putJson("/api/pcgamer/builds/{$build['id']}/items/{$itemId}", [
        'unit_cost_cents' => 100000,
        'quantity' => 1,
    ])->assertOk();

    $show = $this->getJson("/api/pcgamer/builds/{$build['id']}")->json('data');
    expect($show['cost_cents'])->toBe(100000)
        ->and($show['quote_cents'])->toBe(115000);
});

it('transiciona estado da montagem', function () {
    $this->actingAs(User::factory()->create(), 'sanctum');

    $buildId = $this->postJson('/api/pcgamer/builds', ['title' => 'Status test'])->json('data.id');

    $this->postJson("/api/pcgamer/builds/{$buildId}/transition", [
        'status' => 'quoted',
        'notes' => 'Enviado ao cliente',
    ])->assertOk()
        ->assertJsonPath('data.status', 'quoted');
});

it('compara build com preços de mercado e telegram', function () {
    $this->actingAs(User::factory()->create(), 'sanctum');

    PcgMarketPrice::query()->create([
        'retailer_id' => 3,
        'category_slug' => 'processador',
        'product_name' => 'Ryzen 5 7600',
        'price_cents' => 85000,
        'source' => 'fetch:mercadolivre',
        'recorded_at' => now(),
    ]);

    PcgTelegramOffer::query()->create([
        'source_id' => 1,
        'message_id' => 1001,
        'message_hash' => 'hash-test-1001',
        'raw_text' => 'Promo GPU',
        'product_name' => 'RTX 4060',
        'price_cents' => 200000,
        'matched_category_slug' => 'placa_video',
        'status' => 'active',
    ]);

    $build = $this->postJson('/api/pcgamer/builds', ['title' => 'Compare'])->json('data');
    foreach ($build['items'] as $item) {
        if ($item['category_slug'] === 'processador') {
            $this->putJson("/api/pcgamer/builds/{$build['id']}/items/{$item['id']}", [
                'unit_cost_cents' => 90000,
            ]);
        }
    }

    $compare = $this->getJson("/api/pcgamer/builds/{$build['id']}/compare")
        ->assertOk()
        ->json('data');

    expect($compare['lines'])->toHaveCount(10)
        ->and(collect($compare['lines'])->firstWhere('category_slug', 'processador')['delta_cents'])->toBe(5000);
});

it('lista categorias presets e market prices', function () {
    $this->actingAs(User::factory()->create(), 'sanctum');

    $this->getJson('/api/pcgamer/categories')->assertOk()->assertJsonCount(10, 'data');
    $this->getJson('/api/pcgamer/presets')->assertOk()->assertJsonCount(4, 'data');

    $this->postJson('/api/pcgamer/market-prices', [
        'retailer_slug' => 'pichau',
        'category_slug' => 'nvme',
        'product_name' => 'Samsung 990',
        'price_cents' => 49900,
    ])->assertCreated();

    $this->getJson('/api/pcgamer/market-prices?category=nvme')
        ->assertOk()
        ->assertJsonPath('data.0.price_cents', 49900);
});

it('ingere oferta telegram via API key com dedup', function () {
    $payload = [
        'chat_key' => '@mmpromo',
        'message_id' => 555,
        'message_hash' => 'dedup-hash-555',
        'raw_text' => 'RTX 5070 R$ 3500',
        'parsed' => [
            'product_name' => 'RTX 5070',
            'price_cents' => 350000,
            'matched_category_slug' => 'placa_video',
            'url' => 'https://example.com/gpu',
        ],
    ];

    $this->postJson('/api/pcgamer/telegram-offers', $payload, [
        'X-API-Key' => 'pcgamer-test-api-key',
    ])->assertCreated()
        ->assertJsonPath('created', true);

    $this->postJson('/api/pcgamer/telegram-offers', $payload, [
        'X-API-Key' => 'pcgamer-test-api-key',
    ])->assertOk()
        ->assertJsonPath('created', false);

    expect(PcgTelegramOffer::query()->where('message_hash', 'dedup-hash-555')->count())->toBe(1);
});

it('rejeita ingest telegram sem API key', function () {
    $this->postJson('/api/pcgamer/telegram-offers', [
        'chat_key' => '@test',
        'message_id' => 1,
        'message_hash' => 'x',
        'raw_text' => 'test',
        'parsed' => [],
    ])->assertUnauthorized();
});
