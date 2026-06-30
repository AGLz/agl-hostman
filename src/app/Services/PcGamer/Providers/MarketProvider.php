<?php

declare(strict_types=1);

namespace App\Services\PcGamer\Providers;

use App\DTO\PcGamer\MarketListing;

interface MarketProvider
{
    public function slug(): string;

    public function retailerSlug(): string;

    /**
     * @return list<MarketListing>
     */
    public function search(string $query, string $categorySlug, int $limit = 5): array;
}
