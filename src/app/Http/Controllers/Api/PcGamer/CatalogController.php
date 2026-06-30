<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\PcGamer;

use App\Http\Controllers\Controller;
use App\Http\Requests\PcGamer\StoreComponentRequest;
use App\Services\PcGamer\CatalogService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CatalogController extends Controller
{
    public function __construct(
        private readonly CatalogService $catalogService,
    ) {}

    public function categories(): JsonResponse
    {
        return response()->json(['data' => $this->catalogService->listCategories()]);
    }

    public function components(Request $request): JsonResponse
    {
        $category = $request->query('category');

        return response()->json([
            'data' => $this->catalogService->listComponents(is_string($category) ? $category : null),
        ]);
    }

    public function storeComponent(StoreComponentRequest $request): JsonResponse
    {
        $validated = $request->validated();
        $component = $this->catalogService->addComponent(
            categorySlug: $validated['category_slug'],
            model: $validated['model'],
            brand: $validated['brand'] ?? null,
            sku: $validated['sku'] ?? null,
            specs: $validated['specs'] ?? null,
            notes: $validated['notes'] ?? null,
        );

        return response()->json(['data' => $component->load('category')], 201);
    }
}
