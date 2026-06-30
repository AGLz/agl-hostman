<?php

declare(strict_types=1);

namespace App\DTO\PcGamer;

/**
 * Resultado de uma execução fetch por provider + query.
 */
final readonly class FetchResult
{
    /**
     * @param  list<MarketListing>  $listings
     * @param  list<string>  $errors
     */
    public function __construct(
        public string $provider,
        public string $categorySlug,
        public string $query,
        public int $stored,
        public int $skipped,
        public array $listings,
        public array $errors = [],
    ) {}

    /**
     * @param  list<FetchResult>  $results
     * @return array{runs: int, stored: int, skipped: int, errors: list<string>}
     */
    public static function summarize(array $results): array
    {
        $errors = [];
        foreach ($results as $result) {
            foreach ($result->errors as $error) {
                $errors[] = $error;
            }
        }

        return [
            'runs' => count($results),
            'stored' => array_sum(array_map(fn (FetchResult $r) => $r->stored, $results)),
            'skipped' => array_sum(array_map(fn (FetchResult $r) => $r->skipped, $results)),
            'errors' => $errors,
        ];
    }
}
