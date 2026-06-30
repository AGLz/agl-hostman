<?php

declare(strict_types=1);

use App\Services\PcGamer\Telegram\OfferValidatorService;
use Illuminate\Support\Facades\Http;

it('marca indisponível quando HTML contém sold out', function () {
    Http::fake([
        'https://exemplo.com/produto' => Http::response(
            '<html><body>Product sold out</body></html>',
            200,
        ),
    ]);

    $result = app(OfferValidatorService::class)->validateUrl(
        'https://exemplo.com/produto',
        expectedPriceCents: 100000,
    );

    expect($result->status)->toBe('unavailable');
});

it('confirma preço dentro da tolerância', function () {
    Http::fake([
        'https://kabum.com.br/p/1' => Http::response(
            '<html><span>R$ 999,00</span></html>',
            200,
        ),
    ]);

    $result = app(OfferValidatorService::class)->validateUrl(
        'https://kabum.com.br/p/1',
        expectedPriceCents: 99900,
        tolerancePercent: 5,
    );

    expect($result->status)->toBe('active')
        ->and($result->validatedPriceCents)->toBe(99900);
});

it('extrai preço sem centavos no HTML', function () {
    Http::fake([
        'https://kabum.com.br/p/2' => Http::response(
            '<html><span>R$ 1.899</span></html>',
            200,
        ),
    ]);

    $result = app(OfferValidatorService::class)->validateUrl('https://kabum.com.br/p/2');

    expect($result->validatedPriceCents)->toBe(189900);
});

it('bloqueia URL com IP privado', function () {
    Http::fake();

    $result = app(OfferValidatorService::class)->validateUrl('http://192.168.1.1/admin');

    expect($result->status)->toBe('needs_manual')
        ->and($result->notes)->toContain('bloqueada');
    Http::assertNothingSent();
});
