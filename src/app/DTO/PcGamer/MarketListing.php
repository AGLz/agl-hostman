<?php

declare(strict_types=1);

namespace App\DTO\PcGamer;

/**
 * Listagem normalizada de um provider de mercado (preços em centavos BRL).
 */
final readonly class MarketListing
{
    public function __construct(
        public string $provider,
        public string $categorySlug,
        public string $productName,
        public int $priceCents,
        public string $currency = 'BRL',
        public ?string $url = null,
        public ?string $externalId = null,
        public ?string $query = null,
        public ?string $notes = null,
        public float $confidence = 1.0,
    ) {}

    /** @param array<string, mixed> $item */
    public static function fromMercadoLivreItem(
        array $item,
        string $query,
        string $categorySlug,
        string $providerSlug = 'mercadolivre',
    ): ?self {
        $price = $item['price'] ?? null;
        if ($price === null) {
            return null;
        }

        $address = $item['seller_address'] ?? [];
        $country = ($address['country'] ?? [])['id'] ?? null;
        if ($country !== null && $country !== 'BR') {
            return null;
        }

        $seller = $item['seller'] ?? [];
        $sellerName = $seller['nickname'] ?? ($seller['eshop']['nick_name'] ?? null);
        $officialId = $item['official_store_id'] ?? null;
        $logistic = ($item['shipping'] ?? [])['logistic_type'] ?? null;

        $noteBits = ['api:mercadolibre', 'ship:BR'];
        if ($officialId) {
            $noteBits[] = "loja_oficial:{$officialId}";
        }
        if ($sellerName) {
            $noteBits[] = "vendedor:{$sellerName}";
        }
        if ($logistic === 'fulfillment') {
            $noteBits[] = 'full';
        }

        return new self(
            provider: $providerSlug,
            categorySlug: $categorySlug,
            productName: mb_substr((string) ($item['title'] ?? $query), 0, 240),
            priceCents: (int) round((float) $price * 100),
            url: $item['permalink'] ?? null,
            externalId: isset($item['id']) ? (string) $item['id'] : null,
            query: $query,
            notes: implode(' ', $noteBits),
        );
    }
}
