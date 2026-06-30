<?php

declare(strict_types=1);

namespace App\Console\Commands\PcGamer;

use App\DTO\PcGamer\FetchResult;
use App\Jobs\PcGamer\FetchMarketPricesJob;
use App\Services\PcGamer\MarketFetchService;
use Illuminate\Console\Command;

class FetchMarketPricesCommand extends Command
{
    protected $signature = 'pcg:fetch-market
                            {--category= : Slug da categoria (ex. processador)}
                            {--query= : Query de busca override}
                            {--all-categories : Buscar todas as categorias preset}
                            {--providers= : Slugs separados por vírgula}
                            {--limit=2 : Máximo de listagens por provider}
                            {--sync : Executar inline em vez de enfileirar}';

    protected $description = 'Busca preços de mercado (ML, Pichau, AliExpress, 4Gamers) e grava em pcg_market_prices';

    public function handle(MarketFetchService $fetchService): int
    {
        $allCategories = (bool) $this->option('all-categories');
        $category = $this->option('category');
        $providers = $this->parseProviders();
        $limit = max(1, (int) $this->option('limit'));

        if (! $allCategories && ! is_string($category)) {
            $this->error('Use --category=slug ou --all-categories');

            return self::FAILURE;
        }

        if (! $this->option('sync')) {
            FetchMarketPricesJob::dispatch(
                categorySlug: is_string($category) ? $category : null,
                query: is_string($this->option('query')) ? $this->option('query') : null,
                allCategories: $allCategories,
                providerSlugs: $providers,
                limit: $limit,
            );
            $this->info('Job FetchMarketPricesJob enfileirado (fila pc-gamer).');

            return self::SUCCESS;
        }

        $results = $allCategories
            ? $fetchService->fetchAllPresetCategories($providers, $limit)
            : $fetchService->fetchCategory(
                categorySlug: (string) $category,
                query: is_string($this->option('query')) ? $this->option('query') : null,
                providerSlugs: $providers,
                limit: $limit,
            );

        $summary = FetchResult::summarize($results);
        $this->table(
            ['Métrica', 'Valor'],
            [
                ['runs', (string) $summary['runs']],
                ['stored', (string) $summary['stored']],
                ['skipped', (string) $summary['skipped']],
                ['errors', (string) count($summary['errors'])],
            ],
        );

        foreach ($summary['errors'] as $error) {
            $this->warn($error);
        }

        return self::SUCCESS;
    }

    /**
     * @return list<string>|null
     */
    private function parseProviders(): ?array
    {
        $raw = $this->option('providers');
        if (! is_string($raw) || trim($raw) === '') {
            return null;
        }

        return array_values(array_filter(array_map(trim(...), explode(',', $raw))));
    }
}
