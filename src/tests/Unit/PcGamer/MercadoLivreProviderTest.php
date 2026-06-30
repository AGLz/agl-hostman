<?php

use App\Services\PcGamer\MarketProviderRegistry;
use App\Services\PcGamer\Providers\MercadoLivreProvider;
use Illuminate\Support\Facades\Http;

it('filtra vendedores fora do BR na API Mercado Livre', function () {
    Http::fake([
        'api.mercadolibre.com/*' => Http::response([
            'results' => [
                [
                    'id' => 'MLB1',
                    'title' => 'Ryzen 5 7600',
                    'price' => 899.99,
                    'permalink' => 'https://produto.mercadolivre.com.br/MLB1',
                    'seller_address' => ['country' => ['id' => 'BR']],
                    'seller' => ['nickname' => 'loja_br'],
                ],
                [
                    'id' => 'MLB2',
                    'title' => 'Importado',
                    'price' => 100.0,
                    'permalink' => 'https://example.com',
                    'seller_address' => ['country' => ['id' => 'AR']],
                ],
            ],
        ]),
    ]);

    $provider = new MercadoLivreProvider;
    $listings = $provider->search('ryzen 7600', 'processador', 5);

    expect($listings)->toHaveCount(1)
        ->and($listings[0]->externalId)->toBe('MLB1')
        ->and($listings[0]->priceCents)->toBe(89999)
        ->and($listings[0]->notes)->toContain('ship:BR');
});

it('resolve providers activos a partir da config', function () {
    config(['pcgamer.market.providers' => ['mercadolivre', 'desconhecido']]);

    $registry = app(MarketProviderRegistry::class);
    $enabled = $registry->enabled();

    expect($enabled)->toHaveCount(1)
        ->and($enabled[0]->slug())->toBe('mercadolivre');
});
