<?php

declare(strict_types=1);

namespace App\Services\PcGamer;

use App\DTO\PcGamer\FetchResult;
use App\DTO\PcGamer\MarketListing;
use App\Enums\PcGamer\ComponentCategory;
use App\Models\PcGamer\PcgMarketPrice;
use App\Models\PcGamer\PcgRetailer;
use App\Services\PcGamer\Providers\MarketProvider;
use Throwable;

class MarketFetchService
{
    public function __construct(
        private readonly MarketProviderRegistry $registry,
    ) {}

    /**
     * @param  list<string>|null  $providerSlugs
     * @return list<FetchResult>
     */
    public function fetchCategory(
        string $categorySlug,
        ?string $query = null,
        ?array $providerSlugs = null,
        int $limit = 3,
        bool $persist = true,
    ): array {
        $providers = $this->resolveProviders($providerSlugs);
        $searchQuery = $this->queryForCategory($categorySlug, $query);
        $results = [];

        foreach ($providers as $provider) {
            $result = new FetchResult(
                provider: $provider->slug(),
                categorySlug: $categorySlug,
                query: $searchQuery,
                stored: 0,
                skipped: 0,
                listings: [],
            );

            try {
                $listings = $provider->search($searchQuery, $categorySlug, $limit);
            } catch (Throwable $e) {
                $result = new FetchResult(
                    provider: $provider->slug(),
                    categorySlug: $categorySlug,
                    query: $searchQuery,
                    stored: 0,
                    skipped: 0,
                    listings: [],
                    errors: [$e->getMessage()],
                );
                $results[] = $result;

                continue;
            }

            $stored = 0;
            $skipped = 0;
            if ($persist) {
                foreach ($listings as $listing) {
                    if ($listing->priceCents <= 0) {
                        $skipped++;

                        continue;
                    }
                    $this->persistListing($provider, $listing);
                    $stored++;
                }
            }

            $results[] = new FetchResult(
                provider: $provider->slug(),
                categorySlug: $categorySlug,
                query: $searchQuery,
                stored: $stored,
                skipped: $skipped,
                listings: $listings,
            );
        }

        return $results;
    }

    /**
     * @param  list<string>|null  $providerSlugs
     * @return list<FetchResult>
     */
    public function fetchAllPresetCategories(
        ?array $providerSlugs = null,
        int $limit = 2,
        bool $persist = true,
    ): array {
        $all = [];
        foreach (ComponentCategory::cases() as $category) {
            foreach ($this->fetchCategory(
                categorySlug: $category->value,
                providerSlugs: $providerSlugs,
                limit: $limit,
                persist: $persist,
            ) as $result) {
                $all[] = $result;
            }
        }

        return $all;
    }

    /**
     * @param  list<string>|null  $providerSlugs
     * @return list<MarketProvider>
     */
    private function resolveProviders(?array $providerSlugs): array
    {
        if ($providerSlugs === null || $providerSlugs === []) {
            return $this->registry->enabled();
        }

        $providers = [];
        foreach ($providerSlugs as $slug) {
            $providers[] = $this->registry->get($slug);
        }

        return $providers;
    }

    private function queryForCategory(string $categorySlug, ?string $query): string
    {
        if ($query !== null && $query !== '') {
            return $query;
        }

        return (string) (config("pcgamer.queries.{$categorySlug}") ?? $categorySlug);
    }

    private function persistListing(MarketProvider $provider, MarketListing $listing): void
    {
        $retailer = PcgRetailer::query()->where('slug', $provider->retailerSlug())->first();
        if ($retailer === null) {
            return;
        }

        PcgMarketPrice::query()->create([
            'retailer_id' => $retailer->id,
            'category_slug' => $listing->categorySlug,
            'product_name' => $listing->productName,
            'price_cents' => $listing->priceCents,
            'url' => $listing->url,
            'recorded_at' => now(),
            'source' => 'fetch:'.$provider->slug(),
            'notes' => $listing->notes,
        ]);
    }
}
