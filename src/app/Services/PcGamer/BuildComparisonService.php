<?php

declare(strict_types=1);

namespace App\Services\PcGamer;

use App\Enums\PcGamer\ComponentCategory;
use App\Enums\PcGamer\OfferStatus;
use App\Models\PcGamer\PcgMarketPrice;
use App\Models\PcGamer\PcgTelegramOffer;
use InvalidArgumentException;

class BuildComparisonService
{
    public function __construct(
        private readonly BuildService $buildService,
    ) {}

    /**
     * @return array<string, mixed>
     */
    public function compare(int $buildId): array
    {
        $build = $this->buildService->getBuild($buildId);
        if ($build === null) {
            throw new InvalidArgumentException("Montagem #{$buildId} não encontrada");
        }

        $market = $this->bestMarketByCategory();
        $telegram = $this->bestTelegramByCategory();

        $lines = [];
        $referenceTotal = 0;
        $marketBestTotal = 0;
        $ourCostTotal = (int) $build['cost_cents'];

        foreach ($build['items'] as $item) {
            $slug = $item['category_slug'];
            $ourCents = (int) $item['unit_cost_cents'] * (int) $item['quantity'];

            $marketRows = $market[$slug] ?? [];
            $marketBest = $marketRows[0] ?? null;
            $tgBest = $telegram[$slug] ?? null;

            $candidates = [];
            if ($marketBest !== null) {
                $candidates[] = ['mercado', (int) $marketBest['price_cents'], $marketBest['retailer_name'] ?? null];
            }
            if ($tgBest !== null && ! empty($tgBest['price_cents'])) {
                $candidates[] = ['telegram', (int) $tgBest['price_cents'], 'Telegram'];
            }

            $bestSource = null;
            $bestCents = null;
            if ($candidates !== []) {
                usort($candidates, fn ($a, $b) => $a[1] <=> $b[1]);
                [$bestSource, $bestCents] = [$candidates[0][0], $candidates[0][1]];
                $marketBestTotal += $bestCents * (int) $item['quantity'];
            }

            if ($ourCents > 0) {
                $referenceTotal += $ourCents;
            } elseif ($bestCents !== null) {
                $referenceTotal += $bestCents * (int) $item['quantity'];
            }

            $delta = ($ourCents > 0 && $bestCents !== null) ? $ourCents - $bestCents : null;

            $lines[] = [
                'item_id' => $item['id'],
                'category_slug' => $slug,
                'label' => $item['label'],
                'our_cents' => $ourCents,
                'market_best_cents' => $bestCents,
                'market_best_source' => $bestSource,
                'market_product' => $marketBest['product_name'] ?? null,
                'telegram_product' => $tgBest['product_name'] ?? null,
                'delta_cents' => $delta,
            ];
        }

        return [
            'build_id' => $buildId,
            'code' => $build['code'],
            'title' => $build['title'],
            'our_cost_cents' => $ourCostTotal,
            'our_quote_cents' => $build['quote_cents'],
            'reference_market_total_cents' => $marketBestTotal > 0 ? $marketBestTotal : $referenceTotal,
            'lines' => $lines,
        ];
    }

    /**
     * @return array<string, list<array<string, mixed>>>
     */
    private function bestMarketByCategory(int $limitPerCategory = 5): array
    {
        $rows = PcgMarketPrice::query()
            ->with('retailer')
            ->orderBy('category_slug')
            ->orderBy('price_cents')
            ->limit(500)
            ->get();

        $byCategory = [];
        foreach ($rows as $row) {
            $slug = $row->category_slug;
            if (! isset($byCategory[$slug])) {
                $byCategory[$slug] = [];
            }
            if (count($byCategory[$slug]) >= $limitPerCategory) {
                continue;
            }
            $byCategory[$slug][] = [
                'id' => $row->id,
                'retailer_slug' => $row->retailer?->slug,
                'retailer_name' => $row->retailer?->name,
                'category_slug' => $row->category_slug,
                'product_name' => $row->product_name,
                'price_cents' => $row->price_cents,
                'url' => $row->url,
                'recorded_at' => $row->recorded_at?->toIso8601String(),
                'source' => $row->source,
            ];
        }

        return $byCategory;
    }

    /**
     * @return array<string, array<string, mixed>|null>
     */
    private function bestTelegramByCategory(int $limit = 3): array
    {
        $result = [];
        foreach (ComponentCategory::cases() as $category) {
            $offers = PcgTelegramOffer::query()
                ->where('matched_category_slug', $category->value)
                ->whereNotNull('price_cents')
                ->where('price_cents', '>', 0)
                ->whereNotIn('status', [OfferStatus::Unavailable, OfferStatus::Expired])
                ->orderByDesc('posted_at')
                ->orderByDesc('id')
                ->limit($limit)
                ->get();

            $best = $offers->sortBy('price_cents')->first();
            $result[$category->value] = $best ? [
                'id' => $best->id,
                'product_name' => $best->product_name,
                'price_cents' => $best->price_cents,
                'url' => $best->url,
                'status' => $best->status->value,
            ] : null;
        }

        return $result;
    }
}
