<?php

use App\Services\PcGamer\MarketFetchService;
use App\Services\PcGamer\MarketProviderRegistry;
use App\Services\PcGamer\Providers\AliExpressProvider;
use App\Services\PcGamer\Providers\FourGamersProvider;
use App\Services\PcGamer\Providers\MercadoLivreProvider;
use App\Services\PcGamer\Providers\PichauProvider;
use Database\Seeders\PcgCatalogSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;

uses(RefreshDatabase::class);

it('persiste preços válidos em pcg_market_prices', function () {
    $this->seed(PcgCatalogSeeder::class);

    Http::fake([
        'api.mercadolibre.com/*' => Http::response([
            'results' => [
                [
                    'id' => 'MLB99',
                    'title' => 'Ryzen 5 7600',
                    'price' => 850.0,
                    'permalink' => 'https://produto.mercadolivre.com.br/MLB99',
                    'seller_address' => ['country' => ['id' => 'BR']],
                ],
            ],
        ]),
        '*' => Http::response('', 404),
    ]);

    config(['pcgamer.market.providers' => ['mercadolivre']]);

    $results = app(MarketFetchService::class)->fetchCategory('processador', limit: 1);

    expect($results)->toHaveCount(1)
        ->and($results[0]->stored)->toBe(1);

    $this->assertDatabaseHas('pcg_market_prices', [
        'category_slug' => 'processador',
        'price_cents' => 85000,
        'source' => 'fetch:mercadolivre',
    ]);
});

it('AliExpress affiliate API devolve listagens BRL', function () {
    config([
        'pcgamer.market.aliexpress.app_key' => 'test-key',
        'pcgamer.market.aliexpress.app_secret' => 'test-secret',
    ]);

    Http::fake([
        'api-sg.aliexpress.com/*' => Http::response([
            'aliexpress_affiliate_product_query_response' => [
                'resp_result' => [
                    'products' => [
                        'product' => [
                            [
                                'product_id' => '123',
                                'product_title' => 'SSD NVMe 1TB',
                                'target_sale_price' => '199.90',
                                'target_sale_price_currency' => 'BRL',
                                'promotion_link' => 'https://pt.aliexpress.com/item/123.html',
                            ],
                        ],
                    ],
                ],
            ],
        ]),
    ]);

    $listings = (new AliExpressProvider)->search('ssd nvme', 'nvme', 3);

    expect($listings)->toHaveCount(1)
        ->and($listings[0]->priceCents)->toBe(19990)
        ->and($listings[0]->notes)->toContain('aliexpress_affiliate');
});

it('Pichau GraphQL devolve produtos Magento', function () {
    Http::fake([
        'www.pichau.com.br/graphql' => Http::response([
            'data' => [
                'products' => [
                    'items' => [
                        [
                            'name' => 'RTX 4060 Pichau',
                            'sku' => 'SKU1',
                            'url_key' => 'rtx-4060',
                            'price_range' => [
                                'minimum_price' => [
                                    'final_price' => ['value' => 2199.99, 'currency' => 'BRL'],
                                ],
                            ],
                        ],
                    ],
                ],
            ],
        ]),
    ]);

    $listings = (new PichauProvider)->search('rtx 4060', 'placa_video', 3);

    expect($listings)->toHaveCount(1)
        ->and($listings[0]->priceCents)->toBe(219999)
        ->and($listings[0]->notes)->toBe('api:magento_graphql');
});

it('4Gamers Nuvemshop API devolve produtos', function () {
    Http::fake([
        'www.4gamers.com.br/api/*' => Http::response([
            'results' => [
                [
                    'id' => 42,
                    'name' => 'Fonte 750W',
                    'price' => 549.90,
                    'canonical_url' => '/fonte-750w',
                ],
            ],
        ]),
    ]);

    $listings = (new FourGamersProvider)->search('fonte 750w', 'fonte', 3);

    expect($listings)->toHaveCount(1)
        ->and($listings[0]->priceCents)->toBe(54990)
        ->and($listings[0]->notes)->toBe('api:nuvemshop');
});

it('registry expõe os quatro providers configurados', function () {
    config(['pcgamer.market.providers' => ['mercadolivre', 'pichau', 'aliexpress', '4gamers']]);

    $enabled = app(MarketProviderRegistry::class)->enabled();

    expect($enabled)->toHaveCount(4)
        ->and(array_map(fn ($p) => $p->slug(), $enabled))
        ->toEqual(['mercadolivre', 'pichau', 'aliexpress', '4gamers']);
});
