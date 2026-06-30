<?php

declare(strict_types=1);

use App\Services\PcGamer\Telegram\OfferParser;

it('extrai preço BRL com separadores', function () {
    $parser = new OfferParser;
    expect($parser->extractPrice('RTX 5070 por R$ 4.299,90 na promo'))->toBe(429990);
});

it('extrai preço sem separador de milhar', function () {
    $parser = new OfferParser;
    $text = "Placa RTX 5090\nR$ 21299\nhttps://exemplo.com";
    expect($parser->extractPrice($text))->toBe(2129900);
});

it('prefere preço do produto sobre cupom', function () {
    $parser = new OfferParser;
    $text = "Cupom R$ 10 OFF\nProduto R$ 829\nhttps://shopee.com.br/x";
    expect($parser->extractPrice($text))->toBe(82900);
});

it('categoriza GPU e extrai URL', function () {
    $parser = new OfferParser;
    $text = <<<'TXT'
    Placa de vídeo RTX 4060 Ti 8GB
    R$ 2.199,00
    https://exemplo.com/produto
    TXT;

    $parsed = $parser->parse($text);
    expect($parsed['matched_category_slug'])->toBe('placa_video')
        ->and($parsed['price_cents'])->toBe(219900)
        ->and($parsed['url'])->toBe('https://exemplo.com/produto');
});

it('detecta DDR5 e AliExpress com moedas', function () {
    $parser = new OfferParser;
    $text = <<<'TXT'
    GPU RX 5600 6GB
    R$ 815,30
    Cupom: FAFASUPER01 + PCDOFAFA5 + 211 moedas no APP
    Somente no APP Com Moedas
    https://a.aliexpress.com/_c4T1OVCL
    TXT;

    $parsed = $parser->parse($text);
    expect($parsed['price_cents'])->toBe(81530)
        ->and($parsed['requirements']['requires_coins'])->toBeTrue()
        ->and($parsed['requirements']['requires_app'])->toBeTrue()
        ->and($parsed['requirements']['coupon_codes'])->toContain('FAFASUPER01')
        ->and($parsed['requirements']['retailer'])->toBe('aliexpress');
});

it('gera message hash determinístico', function () {
    $parser = new OfferParser;
    $hash = $parser->messageHash('texto', '@canal', 99);
    expect($hash)->toHaveLength(64)
        ->and($parser->messageHash('texto', '@canal', 99))->toBe($hash);
});
