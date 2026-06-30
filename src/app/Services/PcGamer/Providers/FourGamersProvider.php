<?php

declare(strict_types=1);

namespace App\Services\PcGamer\Providers;

use App\DTO\PcGamer\MarketListing;
use Illuminate\Support\Facades\Http;

class FourGamersProvider implements MarketProvider
{
    private const BASE_URL = 'https://www.4gamers.com.br';

    /** @var array<string, list<string>> */
    private const CATEGORY_PATHS = [
        'processador' => ['/processador', '/hardware/processador'],
        'motherboard' => ['/placa-mae', '/hardware/placa-mae'],
        'memoria_ddr5' => ['/memoria-ram', '/hardware/memoria-ram'],
        'placa_video' => ['/placa-de-video', '/hardware/placa-de-video'],
        'nvme' => ['/ssd-e-hd', '/hardware/ssd-e-hd', '/armazenamento'],
        'gabinete' => ['/gabinete-gamer', '/hardware/gabinete-gamer'],
        'fonte' => ['/fonte', '/hardware/fonte'],
        'water_cooler' => ['/water-cooler-e-air-cooler', '/cooler'],
        'fan' => ['/cooler-de-gabinete', '/fan'],
        'suporte_vga' => ['/hardware'],
    ];

    public function slug(): string
    {
        return '4gamers';
    }

    public function retailerSlug(): string
    {
        return '4gamers';
    }

    public function search(string $query, string $categorySlug, int $limit = 5): array
    {
        $apiResults = $this->searchNuvemshopApi($query, $categorySlug, $limit);
        if ($apiResults !== []) {
            return $apiResults;
        }

        $htmlResults = $this->searchCategoryHtml($query, $categorySlug, $limit);
        if ($htmlResults !== []) {
            return $htmlResults;
        }

        return [
            new MarketListing(
                provider: $this->slug(),
                categorySlug: $categorySlug,
                productName: "[manual] {$query}",
                priceCents: 0,
                url: self::BASE_URL.'/monte-seu-computador',
                query: $query,
                notes: 'blocked:waf — consultar monte-seu-computador no browser',
                confidence: 0.0,
            ),
        ];
    }

    /**
     * @return list<MarketListing>
     */
    private function searchNuvemshopApi(string $query, string $categorySlug, int $limit): array
    {
        $encoded = rawurlencode($query);
        $endpoints = [
            self::BASE_URL."/api/catalog_system/pub/products/search?q={$encoded}",
            "https://www.4gamerslojaoficial.com.br/api/catalog_system/pub/products/search?q={$encoded}",
        ];

        foreach ($endpoints as $endpoint) {
            $response = Http::timeout(20)->acceptJson()->get($endpoint);
            if (! $response->successful()) {
                continue;
            }

            $payload = $response->json();
            $products = $payload['results'] ?? $payload;
            if (! is_array($products) || ! array_is_list($products)) {
                continue;
            }

            $listings = [];
            foreach (array_slice($products, 0, $limit) as $product) {
                if (! is_array($product)) {
                    continue;
                }
                $priceInfo = $product['price'] ?? $product['price_with_discount'] ?? null;
                if ($priceInfo === null) {
                    continue;
                }
                $canonical = $product['canonical_url'] ?? $product['url'] ?? null;
                $url = is_string($canonical)
                    ? (str_starts_with($canonical, 'http') ? $canonical : self::BASE_URL.$canonical)
                    : self::BASE_URL;

                $listings[] = new MarketListing(
                    provider: $this->slug(),
                    categorySlug: $categorySlug,
                    productName: mb_substr((string) ($product['name'] ?? $query), 0, 240),
                    priceCents: (int) round((float) $priceInfo * 100),
                    url: $url,
                    externalId: isset($product['id']) ? (string) $product['id'] : null,
                    query: $query,
                    notes: 'api:nuvemshop',
                );
            }

            if ($listings !== []) {
                return $listings;
            }
        }

        return [];
    }

    /**
     * @return list<MarketListing>
     */
    private function searchCategoryHtml(string $query, string $categorySlug, int $limit): array
    {
        $paths = self::CATEGORY_PATHS[$categorySlug] ?? ['/hardware'];
        $queryLower = mb_strtolower($query);

        foreach ($paths as $path) {
            $url = self::BASE_URL.$path;
            $response = Http::timeout(20)->get($url);
            if (! $response->successful()) {
                continue;
            }

            $listings = $this->parseProductCards($response->body(), $url, $categorySlug, $queryLower, $limit);
            if ($listings !== []) {
                return $listings;
            }
        }

        return [];
    }

    /**
     * @return list<MarketListing>
     */
    private function parseProductCards(
        string $html,
        string $baseUrl,
        string $categorySlug,
        string $queryLower,
        int $limit,
    ): array {
        $listings = [];

        if (preg_match_all('/<script type="application\/ld\+json">(.*?)<\/script>/s', $html, $blocks)) {
            foreach ($blocks[1] as $jsonRaw) {
                $data = json_decode($jsonRaw, true);
                if (! is_array($data)) {
                    continue;
                }
                $items = array_is_list($data) ? $data : [$data];
                foreach ($items as $item) {
                    $type = $item['@type'] ?? null;
                    if (! in_array($type, ['Product', 'Offer'], true)) {
                        continue;
                    }
                    $name = (string) ($item['name'] ?? '');
                    if ($queryLower !== '' && ! str_contains(mb_strtolower($name), $queryLower)) {
                        continue;
                    }
                    $offers = $item['offers'] ?? [];
                    if (is_array($offers) && array_is_list($offers)) {
                        $offers = $offers[0] ?? [];
                    }
                    $priceRaw = $offers['price'] ?? $offers['lowPrice'] ?? null;
                    if ($priceRaw === null) {
                        continue;
                    }
                    $listings[] = new MarketListing(
                        provider: $this->slug(),
                        categorySlug: $categorySlug,
                        productName: mb_substr($name, 0, 240),
                        priceCents: (int) round((float) $priceRaw * 100),
                        url: $offers['url'] ?? $baseUrl,
                        query: $queryLower,
                        notes: 'html:json-ld',
                        confidence: 0.75,
                    );
                    if (count($listings) >= $limit) {
                        return $listings;
                    }
                }
            }
        }

        if (preg_match_all(
            '/itemprop="name"[^>]*content="([^"]+)"[^>]*>.*?itemprop="price"[^>]*content="([0-9.]+)"/si',
            $html,
            $micro,
            PREG_SET_ORDER,
        )) {
            foreach ($micro as $match) {
                $name = $match[1];
                if ($queryLower !== '' && ! str_contains(mb_strtolower($name), $queryLower)) {
                    continue;
                }
                $listings[] = new MarketListing(
                    provider: $this->slug(),
                    categorySlug: $categorySlug,
                    productName: mb_substr($name, 0, 240),
                    priceCents: (int) round((float) $match[2] * 100),
                    url: $baseUrl,
                    query: $queryLower,
                    notes: 'html:microdata',
                    confidence: 0.65,
                );
                if (count($listings) >= $limit) {
                    break;
                }
            }
        }

        if ($listings !== []) {
            return $listings;
        }

        if (preg_match_all('/R\$\s*([0-9]{1,3}(?:\.[0-9]{3})*,[0-9]{2})/', $html, $prices)) {
            foreach ($prices[1] as $brl) {
                $normalized = str_replace(['.', ','], ['', '.'], $brl);
                if (! is_numeric($normalized)) {
                    continue;
                }
                $priceCents = (int) round((float) $normalized * 100);
                if ($priceCents < 5000) {
                    continue;
                }
                $listings[] = new MarketListing(
                    provider: $this->slug(),
                    categorySlug: $categorySlug,
                    productName: mb_substr($queryLower, 0, 240) ?: 'Produto 4Gamers',
                    priceCents: $priceCents,
                    url: $baseUrl,
                    query: $queryLower,
                    notes: 'html:price-scan',
                    confidence: 0.4,
                );
                if (count($listings) >= $limit) {
                    break;
                }
            }
        }

        return $listings;
    }
}
