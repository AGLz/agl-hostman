<?php

declare(strict_types=1);

namespace App\Services\PcGamer;

use App\Models\PcGamer\PcgComponent;
use App\Models\PcGamer\PcgComponentCategory;
use Illuminate\Support\Collection;

class CatalogService
{
    /**
     * @return Collection<int, PcgComponentCategory>
     */
    public function listCategories(): Collection
    {
        return PcgComponentCategory::query()->orderBy('sort_order')->get();
    }

    /**
     * @return Collection<int, PcgComponent>
     */
    public function listComponents(?string $categorySlug = null): Collection
    {
        return PcgComponent::query()
            ->with('category')
            ->when($categorySlug, fn ($q) => $q->whereHas(
                'category',
                fn ($c) => $c->where('slug', $categorySlug)
            ))
            ->where('active', true)
            ->orderBy('brand')
            ->orderBy('model')
            ->get();
    }

    /**
     * @param  array<string, mixed>  $specs
     */
    public function addComponent(
        string $categorySlug,
        string $model,
        ?string $brand = null,
        ?string $sku = null,
        ?array $specs = null,
        ?string $notes = null,
    ): PcgComponent {
        $category = PcgComponentCategory::query()->where('slug', $categorySlug)->firstOrFail();

        return PcgComponent::query()->create([
            'category_id' => $category->id,
            'model' => $model,
            'brand' => $brand,
            'sku' => $sku,
            'specs_json' => $specs ?? [],
            'notes' => $notes,
            'active' => true,
        ]);
    }
}
