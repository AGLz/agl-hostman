<?php

declare(strict_types=1);

namespace App\Services\PcGamer\Providers;

use App\DTO\PcGamer\MarketListing;
use Illuminate\Support\Facades\Http;

class AliExpressProvider implements MarketProvider
{
    private const IOP_URL = 'https://api-sg.aliexpress.com/sync';

    public function slug(): string
    {
        return 'aliexpress';
    }

    public function retailerSlug(): string
    {
        return 'aliexpress';
    }

    public function search(string $query, string $categorySlug, int $limit = 5): array
    {
        $appKey = config('pcgamer.market.aliexpress.app_key');
        $appSecret = config('pcgamer.market.aliexpress.app_secret');

        if (is_string($appKey) && $appKey !== '' && is_string($appSecret) && $appSecret !== '') {
            $apiResults = $this->searchAffiliateApi($query, $categorySlug, $limit, $appKey, $appSecret);
            if ($apiResults !== []) {
                return $apiResults;
            }
        }

        return $this->searchPageFallback($query, $categorySlug, $limit);
    }

    /**
     * @return list<MarketListing>
     */
    private function searchAffiliateApi(
        string $query,
        string $categorySlug,
        int $limit,
        string $appKey,
        string $appSecret,
    ): array {
        $timestamp = (string) (int) (microtime(true) * 1000);
        $params = [
            'app_key' => $appKey,
            'method' => 'aliexpress.affiliate.product.query',
            'sign_method' => 'md5',
            'timestamp' => $timestamp,
            'format' => 'json',
            'v' => '2.0',
            'keywords' => $query,
            'page_size' => (string) min($limit, 20),
            'target_currency' => 'BRL',
            'target_language' => 'PT',
            'sort' => 'SALE_PRICE_ASC',
        ];

        $shipFrom = config('pcgamer.market.aliexpress.ship_from');
        if (is_string($shipFrom) && $shipFrom !== '') {
            $params['ship_to_country'] = $shipFrom;
        }

        $trackingId = config('pcgamer.market.aliexpress.tracking_id');
        if (is_string($trackingId) && $trackingId !== '') {
            $params['tracking_id'] = $trackingId;
        }

        $params['sign'] = $this->sign($params, $appSecret);

        $response = Http::timeout(30)->asForm()->post(self::IOP_URL, $params);
        if (! $response->successful()) {
            return [];
        }

        $payload = $response->json();
        $responseBlock = $payload['aliexpress_affiliate_product_query_response'] ?? [];
        $result = $responseBlock['resp_result'] ?? [];
        if (is_string($result)) {
            $result = json_decode($result, true) ?? [];
        }

        $products = $result['products']['product'] ?? [];
        if (! is_array($products)) {
            return [];
        }
        if (isset($products['product_id'])) {
            $products = [$products];
        }

        $listings = [];
        foreach (array_slice($products, 0, $limit) as $product) {
            if (! is_array($product)) {
                continue;
            }
            $priceRaw = $product['target_sale_price'] ?? $product['sale_price'] ?? null;
            if ($priceRaw === null) {
                continue;
            }
            $price = (float) str_replace(',', '.', (string) $priceRaw);
            $listings[] = new MarketListing(
                provider: $this->slug(),
                categorySlug: $categorySlug,
                productName: mb_substr((string) ($product['product_title'] ?? $query), 0, 240),
                priceCents: (int) round($price * 100),
                currency: (string) ($product['target_sale_price_currency'] ?? 'BRL'),
                url: $product['promotion_link'] ?? $product['product_detail_url'] ?? null,
                externalId: isset($product['product_id']) ? (string) $product['product_id'] : null,
                query: $query,
                notes: 'api:aliexpress_affiliate',
            );
        }

        return $listings;
    }

    /**
     * @param  array<string, string>  $params
     */
    private function sign(array $params, string $appSecret): string
    {
        ksort($params);
        $ordered = '';
        foreach ($params as $key => $value) {
            $ordered .= $key.$value;
        }

        return strtoupper(md5($appSecret.$ordered.$appSecret));
    }

    /**
     * @return list<MarketListing>
     */
    private function searchPageFallback(string $query, string $categorySlug, int $limit): array
    {
        $slug = rawurlencode(str_replace(' ', '-', mb_strtolower($query)));
        $url = "https://pt.aliexpress.com/w/wholesale-{$slug}.html";
        $shipFrom = config('pcgamer.market.aliexpress.ship_from');
        if (is_string($shipFrom) && $shipFrom !== '') {
            $url .= "?shipFromCountry={$shipFrom}";
        }
        $shipNote = is_string($shipFrom) && $shipFrom !== '' ? "ship_from:{$shipFrom}" : '';

        $response = Http::timeout(30)->get($url);
        if (! $response->successful()) {
            return [];
        }

        $html = $response->body();
        $bodyLower = mb_strtolower($html);
        if (str_contains($bodyLower, 'captcha') || str_contains((string) $response->effectiveUri(), 'punish')) {
            return [
                new MarketListing(
                    provider: $this->slug(),
                    categorySlug: $categorySlug,
                    productName: "[manual] {$query}",
                    priceCents: 0,
                    url: $url,
                    query: $query,
                    notes: 'blocked:captcha — configure ALIEXPRESS_APP_KEY ou abrir URL',
                    confidence: 0.0,
                ),
            ];
        }

        $listings = [];
        if (preg_match_all('/"formattedPrice"\s*:\s*"R\$\s*([0-9.,]+)"/', $html, $matches)) {
            foreach ($matches[1] as $raw) {
                $priceCents = $this->parseBrl((string) $raw);
                if ($priceCents === null) {
                    continue;
                }
                $listings[] = new MarketListing(
                    provider: $this->slug(),
                    categorySlug: $categorySlug,
                    productName: mb_substr($query, 0, 240),
                    priceCents: $priceCents,
                    url: $url,
                    query: $query,
                    notes: trim('html:formattedPrice '.$shipNote),
                    confidence: 0.55,
                );
                if (count($listings) >= $limit) {
                    break;
                }
            }
        }

        if ($listings !== []) {
            return $listings;
        }

        if (preg_match_all('/"minPrice"\s*:\s*([0-9]+)/', $html, $minMatches)) {
            foreach ($minMatches[1] as $centsRaw) {
                $cents = (int) $centsRaw;
                if ($cents < 1000) {
                    continue;
                }
                $listings[] = new MarketListing(
                    provider: $this->slug(),
                    categorySlug: $categorySlug,
                    productName: mb_substr($query, 0, 240),
                    priceCents: $cents,
                    url: $url,
                    query: $query,
                    notes: trim('html:minPrice '.$shipNote),
                    confidence: 0.5,
                );
                if (count($listings) >= $limit) {
                    break;
                }
            }
        }

        return array_slice($listings, 0, $limit);
    }

    private function parseBrl(string $raw): ?int
    {
        $cleaned = str_replace(['.', ','], ['', '.'], trim($raw));
        if (! is_numeric($cleaned)) {
            return null;
        }
        $value = (float) $cleaned;
        if ($value <= 0) {
            return null;
        }

        return (int) round($value * 100);
    }
}
