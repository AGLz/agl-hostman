<?php

declare(strict_types=1);

namespace App\Services\PcGamer;

use App\Services\PcGamer\Providers\MarketProvider;
use App\Services\PcGamer\Providers\MercadoLivreProvider;
use InvalidArgumentException;

class MarketProviderRegistry
{
    /** @var array<string, class-string<MarketProvider>> */
    private const MAP = [
        'mercadolivre' => MercadoLivreProvider::class,
    ];

    public function __construct(
        private readonly MercadoLivreProvider $mercadoLivre,
    ) {}

    public function get(string $slug): MarketProvider
    {
        return match ($slug) {
            'mercadolivre' => $this->mercadoLivre,
            default => throw new InvalidArgumentException("Provider de mercado desconhecido: {$slug}"),
        };
    }

    /**
     * @return list<MarketProvider>
     */
    public function enabled(): array
    {
        $providers = [];
        foreach (config('pcgamer.market.providers', []) as $slug) {
            if (isset(self::MAP[$slug])) {
                $providers[] = $this->get($slug);
            }
        }

        return $providers;
    }
}
