<?php

declare(strict_types=1);

namespace App\Services\PcGamer\Telegram;

use App\DTO\PcGamer\OfferValidationResult;
use Illuminate\Support\Facades\Http;

class OfferValidatorService
{
    /** @var list<string> */
    private const UNAVAILABLE_STRONG = [
        'currently unavailable',
        'produto esgotado',
        'sem estoque',
        'out of stock',
        'sold out',
        'this item is unavailable',
        'item is no longer available',
        'não disponível para compra',
        'nao disponivel para compra',
        'produto indisponível no momento',
        'produto indisponivel no momento',
    ];

    /** @var list<string> */
    private const UNAVAILABLE_GENERIC = [
        'esgotado',
        'sem estoque',
        'out of stock',
        'sold out',
        'no longer available',
        'item not found',
        'page not found',
        'não encontrado',
        'nao encontrado',
    ];

    /** @var list<string> */
    private const MARKETPLACE_HOSTS = [
        'amazon.',
        'shopee.',
        'aliexpress.',
        'mercadolivre.',
        'mercadolibre.',
    ];

    public function validateUrl(
        string $url,
        ?int $expectedPriceCents = null,
        float $tolerancePercent = 5.0,
        string $requirementsNote = '',
    ): OfferValidationResult {
        if ($url === '') {
            return new OfferValidationResult('needs_manual', null, 'sem URL para validar');
        }

        if (! $this->isSafeUrl($url)) {
            return new OfferValidationResult(
                status: 'needs_manual',
                validatedPriceCents: null,
                notes: 'URL bloqueada (esquema ou host não permitido)',
                finalUrl: $url,
            );
        }

        try {
            $response = Http::timeout(15)
                ->withHeaders(['User-Agent' => 'Mozilla/5.0 (compatible; AGLPcGamer/1.0)'])
                ->get($url);
        } catch (\Throwable $e) {
            return new OfferValidationResult(
                status: 'needs_manual',
                validatedPriceCents: null,
                notes: 'erro HTTP: ' . $e->getMessage(),
                finalUrl: $url,
            );
        }

        $finalUrl = (string) $response->effectiveUri();
        $html = $response->body();
        $htmlLower = strtolower(mb_substr($html, 0, 500_000));
        $httpStatus = $response->status();
        $host = strtolower(parse_url($finalUrl, PHP_URL_HOST) ?: '');
        $isMarketplace = $this->hostIsMarketplace($host);

        if ($httpStatus >= 400) {
            return new OfferValidationResult(
                status: 'needs_manual',
                validatedPriceCents: null,
                notes: "HTTP {$httpStatus}",
                finalUrl: $finalUrl,
                httpStatus: $httpStatus,
            );
        }

        $markers = self::UNAVAILABLE_STRONG;
        if (! $isMarketplace) {
            $markers = array_merge($markers, self::UNAVAILABLE_GENERIC);
        }

        foreach ($markers as $marker) {
            if (str_contains($htmlLower, $marker)) {
                return new OfferValidationResult(
                    status: 'unavailable',
                    validatedPriceCents: null,
                    notes: "indisponível: {$marker}",
                    finalUrl: $finalUrl,
                    httpStatus: $httpStatus,
                );
            }
        }

        $foundPrices = $this->extractPricesFromHtml($html);
        $validatedPrice = $foundPrices !== [] ? min($foundPrices) : null;

        $notesParts = [];
        if ($requirementsNote !== '') {
            $notesParts[] = $requirementsNote;
        }
        if ($isMarketplace) {
            $notesParts[] = 'validação parcial (página pode exigir JS/login)';
        }

        if ($expectedPriceCents !== null && $validatedPrice !== null) {
            $within = $this->priceWithinTolerance($expectedPriceCents, $validatedPrice, $tolerancePercent);
            if ($within === true) {
                $status = 'active';
                $notesParts[] = 'preço confirmado no link';
            } elseif ($within === false) {
                $status = 'price_changed';
                $notesParts[] = "preço no link difere (esperado {$expectedPriceCents}, visto {$validatedPrice})";
            } else {
                $status = 'active';
                $notesParts[] = 'preço no link não comparável';
            }
        } elseif ($validatedPrice !== null) {
            $status = 'active';
            $notesParts[] = "preço visto: {$validatedPrice}";
        } else {
            $status = 'needs_manual';
            $notesParts[] = 'não foi possível confirmar preço/estoque automaticamente';
        }

        return new OfferValidationResult(
            status: $status,
            validatedPriceCents: $validatedPrice,
            notes: implode('; ', $notesParts),
            finalUrl: $finalUrl,
            httpStatus: $httpStatus,
        );
    }

    /** @return list<int> */
    private function extractPricesFromHtml(string $html): array
    {
        $prices = [];
        if (preg_match_all(
            '/(?:r\$|rs\.?)\s*(\d{1,3}(?:\.\d{3})*(?:,\d{2})?|\d{4,}(?:,\d{2})?|\d{1,3}(?:,\d{2}))/iu',
            $html,
            $matches,
        )) {
            foreach ($matches[1] as $raw) {
                $cents = $this->parsePriceCents($raw);
                if ($cents !== null && $cents >= 1000) {
                    $prices[] = $cents;
                }
            }
        }

        return $prices;
    }

    private function parsePriceCents(string $raw): ?int
    {
        $token = trim($raw);
        if (str_contains($token, ',')) {
            $cleaned = str_replace(['.', ','], ['', '.'], $token);
        } elseif (substr_count($token, '.') >= 1 && strlen(explode('.', $token)[count(explode('.', $token)) - 1]) === 3) {
            $cleaned = str_replace('.', '', $token);
        } else {
            $cleaned = $token;
        }

        if (! is_numeric($cleaned)) {
            return null;
        }
        $value = (float) $cleaned;
        if ($value <= 0) {
            return null;
        }

        return (int) round($value * 100);
    }

    private function priceWithinTolerance(?int $expected, ?int $found, float $tolerancePercent): ?bool
    {
        if ($expected === null || $found === null || $expected <= 0) {
            return null;
        }
        $delta = abs($found - $expected) / $expected * 100;

        return $delta <= $tolerancePercent;
    }

    private function hostIsMarketplace(string $host): bool
    {
        foreach (self::MARKETPLACE_HOSTS as $part) {
            if (str_contains($host, $part)) {
                return true;
            }
        }

        return false;
    }

    private function isSafeUrl(string $url): bool
    {
        $parsed = parse_url($url);
        if (! in_array($parsed['scheme'] ?? '', ['http', 'https'], true)) {
            return false;
        }

        $host = strtolower($parsed['host'] ?? '');
        if ($host === '' || $host === 'localhost') {
            return false;
        }

        if (filter_var($host, FILTER_VALIDATE_IP)) {
            return (bool) filter_var(
                $host,
                FILTER_VALIDATE_IP,
                FILTER_FLAG_NO_PRIV_RANGE | FILTER_FLAG_NO_RES_RANGE,
            );
        }

        return true;
    }
}
