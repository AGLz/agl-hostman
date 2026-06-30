<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\PcGamer;

use App\Http\Controllers\Controller;
use App\Http\Requests\PcGamer\AddMarketPriceRequest;
use App\Models\PcGamer\PcgMarketPrice;
use App\Models\PcGamer\PcgRetailer;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MarketPriceController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = PcgMarketPrice::query()->with('retailer');

        if ($category = $request->query('category')) {
            $query->where('category_slug', $category);
        }
        if ($retailer = $request->query('retailer')) {
            $query->whereHas('retailer', fn ($q) => $q->where('slug', $retailer));
        }

        $limit = min((int) $request->query('limit', 50), 200);

        $rows = $query
            ->orderBy('category_slug')
            ->orderBy('price_cents')
            ->limit($limit)
            ->get()
            ->map(fn (PcgMarketPrice $row) => [
                'id' => $row->id,
                'retailer_slug' => $row->retailer?->slug,
                'retailer_name' => $row->retailer?->name,
                'category_slug' => $row->category_slug,
                'product_name' => $row->product_name,
                'price_cents' => $row->price_cents,
                'url' => $row->url,
                'recorded_at' => $row->recorded_at?->toIso8601String(),
                'source' => $row->source,
                'notes' => $row->notes,
            ]);

        return response()->json(['data' => $rows]);
    }

    public function store(AddMarketPriceRequest $request): JsonResponse
    {
        $validated = $request->validated();
        $retailer = PcgRetailer::query()->where('slug', $validated['retailer_slug'])->firstOrFail();

        $price = PcgMarketPrice::query()->create([
            'retailer_id' => $retailer->id,
            'category_slug' => $validated['category_slug'],
            'product_name' => $validated['product_name'],
            'price_cents' => $validated['price_cents'],
            'url' => $validated['url'] ?? null,
            'recorded_at' => now(),
            'source' => 'manual',
            'notes' => $validated['notes'] ?? null,
        ]);

        return response()->json(['data' => $price->load('retailer')], 201);
    }
}
