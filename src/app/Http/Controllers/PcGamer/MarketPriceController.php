<?php

declare(strict_types=1);

namespace App\Http\Controllers\PcGamer;

use App\Http\Controllers\Controller;
use App\Models\PcGamer\PcgMarketPrice;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

class MarketPriceController extends Controller
{
    public function index(Request $request): Response
    {
        $query = PcgMarketPrice::query()->with('retailer');

        if ($category = $request->query('category')) {
            $query->where('category_slug', $category);
        }

        $prices = $query
            ->orderBy('category_slug')
            ->orderBy('price_cents')
            ->limit(100)
            ->get()
            ->map(fn (PcgMarketPrice $row) => [
                'id' => $row->id,
                'retailer_name' => $row->retailer?->name,
                'retailer_slug' => $row->retailer?->slug,
                'category_slug' => $row->category_slug,
                'product_name' => $row->product_name,
                'price_cents' => $row->price_cents,
                'url' => $row->url,
                'source' => $row->source,
                'recorded_at' => $row->recorded_at?->toIso8601String(),
            ]);

        return Inertia::render('PcGamer/MarketPrices/Index', [
            'prices' => $prices,
            'filters' => [
                'category' => is_string($category) ? $category : null,
            ],
        ]);
    }
}
