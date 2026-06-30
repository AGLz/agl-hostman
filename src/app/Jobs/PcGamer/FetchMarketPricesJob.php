<?php

declare(strict_types=1);

namespace App\Jobs\PcGamer;

use App\Services\PcGamer\MarketFetchService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

class FetchMarketPricesJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $timeout = 600;

    public int $tries = 2;

    /**
     * @param  list<string>|null  $providerSlugs
     */
    public function __construct(
        public readonly ?string $categorySlug = null,
        public readonly ?string $query = null,
        public readonly bool $allCategories = false,
        public readonly ?array $providerSlugs = null,
        public readonly int $limit = 2,
    ) {
        $this->onQueue('pc-gamer');
    }

    public function handle(MarketFetchService $fetchService): void
    {
        if ($this->allCategories) {
            $results = $fetchService->fetchAllPresetCategories(
                providerSlugs: $this->providerSlugs,
                limit: $this->limit,
            );
        } elseif ($this->categorySlug !== null) {
            $results = $fetchService->fetchCategory(
                categorySlug: $this->categorySlug,
                query: $this->query,
                providerSlugs: $this->providerSlugs,
                limit: $this->limit,
            );
        } else {
            Log::warning('FetchMarketPricesJob: nenhum alvo definido (use allCategories ou categorySlug)');

            return;
        }

        $summary = \App\DTO\PcGamer\FetchResult::summarize($results);
        Log::info('PC Gamer market fetch concluído', $summary);
    }

    /**
     * @return list<int>
     */
    public function backoff(): array
    {
        return [60, 300];
    }
}
