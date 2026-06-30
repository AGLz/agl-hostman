<?php

declare(strict_types=1);

namespace App\Services\PcGamer\Providers;

use App\DTO\PcGamer\MarketListing;
use Illuminate\Support\Facades\Http;

class MercadoLivreProvider implements MarketProvider
{
    private const SITE_ID = 'MLB';

    public function slug(): string
    {
        return 'mercadolivre';
    }

    public function retailerSlug(): string
    {
        return 'mercadolivre';
    }

    public function search(string $query, string $categorySlug, int $limit = 5): array
    {
        $apiResults = $this->searchApi($query, $categorySlug, $limit);
        if ($apiResults !== []) {
            return $apiResults;
        }

        return $this->searchHtmlFallback($query, $categorySlug, $limit);
    }

    /**
     * @return list<MarketListing>
     */
    private function searchApi(string $query, string $categorySlug, int $limit): array
    {
        $params = [
            'q' => $query,
            'sort' => 'price_asc',
            'limit' => min($limit, 50),
            'condition' => 'new',
        ];

        if (config('pcgamer.market.mercadolivre.only_official')) {
            $params['official_store'] = 'all';
        }

        $request = Http::timeout(20)->acceptJson();
        $token = config('pcgamer.market.mercadolivre.access_token');
        if (is_string($token) && $token !== '') {
            $request = $request->withToken($token);
        }

        $response = $request->get(
            'https://api.mercadolibre.com/sites/'.self::SITE_ID.'/search',
            $params,
        );

        if ($response->status() === 403 || ! $response->successful()) {
            return [];
        }

        $listings = [];
        foreach (array_slice($response->json('results', []), 0, $limit) as $item) {
            if (! is_array($item)) {
                continue;
            }
            $listing = MarketListing::fromMercadoLivreItem($item, $query, $categorySlug, $this->slug());
            if ($listing !== null) {
                $listings[] = $listing;
            }
        }

        return $listings;
    }

    /**
     * @return list<MarketListing>
     */
    private function searchHtmlFallback(string $query, string $categorySlug, int $limit): array
    {
        $slug = str_replace(' ', '-', mb_strtolower($query));
        $url = "https://lista.mercadolivre.com.br/{$slug}";

        $response = Http::timeout(20)->get($url);
        if (! $response->successful()) {
            return [];
        }

        $html = $response->body();
        $listings = [];

        if (preg_match_all('/"price"\s*:\s*([0-9]+(?:\.[0-9]{1,2})?)/', $html, $matches)) {
            foreach ($matches[1] as $priceRaw) {
                $price = (float) $priceRaw;
                if ($price < 10) {
                    continue;
                }
                $listings[] = new MarketListing(
                    provider: $this->slug(),
                    categorySlug: $categorySlug,
                    productName: mb_substr($query, 0, 240),
                    priceCents: (int) round($price * 100),
                    url: $url,
                    query: $query,
                    notes: 'html:fallback',
                    confidence: 0.6,
                );
                if (count($listings) >= $limit) {
                    break;
                }
            }
        }

        if ($listings !== []) {
            return array_slice($listings, 0, 1);
        }

        preg_match_all('/"title"\s*:\s*"([^"]{8,200})"/', $html, $titles);
        preg_match_all('/"price"\s*:\s*([0-9]+(?:\.[0-9]{1,2})?)/', $html, $prices);

        foreach ($titles[1] ?? [] as $i => $title) {
            $priceRaw = $prices[1][$i] ?? null;
            if ($priceRaw === null) {
                continue;
            }
            $price = (float) $priceRaw;
            if ($price < 10) {
                continue;
            }
            $listings[] = new MarketListing(
                provider: $this->slug(),
                categorySlug: $categorySlug,
                productName: mb_substr($title, 0, 240),
                priceCents: (int) round($price * 100),
                url: $url,
                query: $query,
                notes: 'html:paired',
                confidence: 0.7,
            );
            if (count($listings) >= $limit) {
                break;
            }
        }

        return $listings;
    }
}
