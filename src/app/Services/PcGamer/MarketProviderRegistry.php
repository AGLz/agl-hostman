<?php

declare(strict_types=1);

namespace App\Services\PcGamer;

use App\Services\PcGamer\Providers\AliExpressProvider;
use App\Services\PcGamer\Providers\FourGamersProvider;
use App\Services\PcGamer\Providers\MarketProvider;
use App\Services\PcGamer\Providers\MercadoLivreProvider;
use App\Services\PcGamer\Providers\PichauProvider;
use InvalidArgumentException;

class MarketProviderRegistry
{
    /** @var array<string, class-string<MarketProvider>> */
    private const MAP = [
        'mercadolivre' => MercadoLivreProvider::class,
        'pichau' => PichauProvider::class,
        'aliexpress' => AliExpressProvider::class,
        '4gamers' => FourGamersProvider::class,
    ];

    public function __construct(
        private readonly MercadoLivreProvider $mercadoLivre,
        private readonly PichauProvider $pichau,
        private readonly AliExpressProvider $aliExpress,
        private readonly FourGamersProvider $fourGamers,
    ) {}

    public function get(string $slug): MarketProvider
    {
        return match ($slug) {
            'mercadolivre' => $this->mercadoLivre,
            'pichau' => $this->pichau,
            'aliexpress' => $this->aliExpress,
            '4gamers' => $this->fourGamers,
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
