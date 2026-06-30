<?php

declare(strict_types=1);

namespace App\Services\PcGamer\Providers;

use App\DTO\PcGamer\MarketListing;
use Illuminate\Support\Facades\Http;

class PichauProvider implements MarketProvider
{
    private const BASE_URL = 'https://www.pichau.com.br';

    private const GRAPHQL_URL = self::BASE_URL.'/graphql';

    // Reason: query mínima Magento 2 — preço final + marca + url por produto
    private const PRODUCTS_QUERY = 'query($q:String!,$n:Int!){products(search:$q,pageSize:$n,sort:{relevance:DESC}){items{name sku url_key price_range{minimum_price{final_price{value currency}}}}}}';

    public function slug(): string
    {
        return 'pichau';
    }

    public function retailerSlug(): string
    {
        return 'pichau';
    }

    public function search(string $query, string $categorySlug, int $limit = 5): array
    {
        $apiResults = $this->searchGraphql($query, $categorySlug, $limit);
        if ($apiResults !== []) {
            return $apiResults;
        }

        $htmlResults = $this->searchHtml($query, $categorySlug, $limit);
        if ($htmlResults !== []) {
            return $htmlResults;
        }

        return [
            new MarketListing(
                provider: $this->slug(),
                categorySlug: $categorySlug,
                productName: "[manual] {$query}",
                priceCents: 0,
                url: self::BASE_URL.'/search?q='.rawurlencode($query),
                query: $query,
                notes: 'blocked:waf — abrir busca Pichau no browser',
                confidence: 0.0,
            ),
        ];
    }

    /**
     * @return list<MarketListing>
     */
    private function searchGraphql(string $query, string $categorySlug, int $limit): array
    {
        $response = Http::timeout(20)
            ->acceptJson()
            ->post(self::GRAPHQL_URL, [
                'query' => self::PRODUCTS_QUERY,
                'variables' => ['q' => $query, 'n' => min($limit, 20)],
            ]);

        if (! $response->successful()) {
            return [];
        }

        $items = $response->json('data.products.items', []);
        if (! is_array($items)) {
            return [];
        }

        $listings = [];
        foreach (array_slice($items, 0, $limit) as $item) {
            if (! is_array($item)) {
                continue;
            }
            $final = $item['price_range']['minimum_price']['final_price'] ?? null;
            if (! is_array($final) || ! isset($final['value'])) {
                continue;
            }
            $priceCents = (int) round((float) $final['value'] * 100);
            if ($priceCents <= 0) {
                continue;
            }
            $urlKey = $item['url_key'] ?? null;
            $listings[] = new MarketListing(
                provider: $this->slug(),
                categorySlug: $categorySlug,
                productName: mb_substr((string) ($item['name'] ?? $query), 0, 240),
                priceCents: $priceCents,
                currency: (string) ($final['currency'] ?? 'BRL'),
                url: is_string($urlKey) ? self::BASE_URL.'/'.$urlKey : self::BASE_URL,
                externalId: isset($item['sku']) ? (string) $item['sku'] : null,
                query: $query,
                notes: 'api:magento_graphql',
            );
        }

        return $listings;
    }

    /**
     * @return list<MarketListing>
     */
    private function searchHtml(string $query, string $categorySlug, int $limit): array
    {
        $url = self::BASE_URL.'/search?q='.rawurlencode($query);
        $response = Http::timeout(20)->get($url);
        if (! $response->successful()) {
            return [];
        }

        $html = $response->body();
        $listings = $this->parseJsonLdProducts($html, $url, $categorySlug, $query, $limit);
        if ($listings !== []) {
            return $listings;
        }

        if (preg_match_all('/R\$\s*([0-9]{1,3}(?:\.[0-9]{3})*,[0-9]{2})/', $html, $matches)) {
            foreach ($matches[1] as $brl) {
                $priceCents = $this->parseBrazilianPrice($brl);
                if ($priceCents === null || $priceCents < 5000) {
                    continue;
                }
                $listings[] = new MarketListing(
                    provider: $this->slug(),
                    categorySlug: $categorySlug,
                    productName: mb_substr(mb_strtolower($query), 0, 240) ?: 'Produto Pichau',
                    priceCents: $priceCents,
                    url: $url,
                    query: $query,
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

    /**
     * @return list<MarketListing>
     */
    private function parseJsonLdProducts(
        string $html,
        string $fallbackUrl,
        string $categorySlug,
        string $query,
        int $limit,
    ): array {
        $listings = [];
        if (! preg_match_all('/<script type="application\/ld\+json">(.*?)<\/script>/s', $html, $blocks)) {
            return [];
        }

        foreach ($blocks[1] as $jsonRaw) {
            $data = json_decode($jsonRaw, true);
            if (! is_array($data)) {
                continue;
            }
            $items = array_is_list($data) ? $data : [$data];
            foreach ($items as $item) {
                if (($item['@type'] ?? null) !== 'Product') {
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
                    productName: mb_substr((string) ($item['name'] ?? ''), 0, 240),
                    priceCents: (int) round((float) $priceRaw * 100),
                    url: $offers['url'] ?? $fallbackUrl,
                    query: $query,
                    notes: 'html:json-ld',
                    confidence: 0.7,
                );
                if (count($listings) >= $limit) {
                    return $listings;
                }
            }
        }

        return $listings;
    }

    private function parseBrazilianPrice(string $brl): ?int
    {
        $normalized = str_replace(['.', ','], ['', '.'], $brl);
        if (! is_numeric($normalized)) {
            return null;
        }

        return (int) round((float) $normalized * 100);
    }
}
