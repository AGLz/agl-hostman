<?php

declare(strict_types=1);

namespace App\Http\Controllers\PcGamer;

use App\Http\Controllers\Controller;
use App\Http\Requests\PcGamer\StoreComponentRequest;
use App\Services\PcGamer\CatalogService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

class CatalogController extends Controller
{
    public function __construct(
        private readonly CatalogService $catalogService,
    ) {}

    public function index(Request $request): Response
    {
        $category = $request->query('category');

        return Inertia::render('PcGamer/Catalog/Index', [
            'categories' => $this->catalogService->listCategories()
                ->map(fn($cat) => [
                    'slug' => $cat->slug,
                    'name' => $cat->name,
                ])
                ->values(),
            'components' => $this->catalogService->listComponents(is_string($category) ? $category : null)
                ->map(fn($component) => [
                    'id' => $component->id,
                    'brand' => $component->brand,
                    'model' => $component->model,
                    'sku' => $component->sku,
                    'notes' => $component->notes,
                    'category_slug' => $component->category?->slug,
                    'category_name' => $component->category?->name,
                ])
                ->values(),
            'filters' => [
                'category' => is_string($category) ? $category : null,
            ],
        ]);
    }

    public function store(StoreComponentRequest $request): RedirectResponse
    {
        $validated = $request->validated();

        $this->catalogService->addComponent(
            categorySlug: $validated['category_slug'],
            model: $validated['model'],
            brand: $validated['brand'] ?? null,
            sku: $validated['sku'] ?? null,
            specs: $validated['specs'] ?? null,
            notes: $validated['notes'] ?? null,
        );

        return redirect()
            ->route('pc-gamer.catalog.index', [
                'category' => $validated['category_slug'],
            ])
            ->with('success', 'Componente adicionado ao catálogo.');
    }
}
