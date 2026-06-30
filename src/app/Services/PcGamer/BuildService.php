<?php

declare(strict_types=1);

namespace App\Services\PcGamer;

use App\Enums\PcGamer\BuildStatus;
use App\Models\PcGamer\PcgBuild;
use App\Models\PcGamer\PcgBuildEvent;
use App\Models\PcGamer\PcgBuildItem;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use InvalidArgumentException;

class BuildService
{
    /**
     * @return Collection<int, array<string, mixed>>
     */
    public function listBuilds(?BuildStatus $status = null): Collection
    {
        return PcgBuild::query()
            ->when($status, fn ($q) => $q->where('status', $status))
            ->with('items')
            ->orderByDesc('updated_at')
            ->orderByDesc('id')
            ->get()
            ->map(fn (PcgBuild $build) => $this->toSummary($build));
    }

    /**
     * @param  array<string, mixed>  $data
     */
    public function createBuild(array $data, bool $useTemplate = true): array
    {
        return DB::transaction(function () use ($data, $useTemplate) {
            $margin = (float) ($data['margin_percent'] ?? config('pcgamer.default_margin_percent', 15));

            $build = PcgBuild::query()->create([
                'code' => $this->nextBuildCode(),
                'title' => $data['title'],
                'customer_name' => $data['customer_name'] ?? null,
                'customer_contact' => $data['customer_contact'] ?? null,
                'platform' => $data['platform'] ?? 'amd',
                'status' => BuildStatus::Draft,
                'margin_percent' => $margin,
                'notes' => $data['notes'] ?? null,
            ]);

            PcgBuildEvent::query()->create([
                'build_id' => $build->id,
                'event_type' => 'created',
                'to_status' => BuildStatus::Draft->value,
                'notes' => 'Montagem criada',
                'created_at' => now(),
            ]);

            if ($useTemplate) {
                foreach (config('pcgamer.build_template_amd', []) as $index => $slot) {
                    PcgBuildItem::query()->create([
                        'build_id' => $build->id,
                        'category_slug' => $slot['category_slug'],
                        'label' => $slot['label'],
                        'sort_order' => $index * 10,
                        'source' => 'template',
                    ]);
                }
            }

            return $this->getBuild($build->id);
        });
    }

    /**
     * @return array<string, mixed>|null
     */
    public function getBuild(int $buildId): ?array
    {
        $build = PcgBuild::query()
            ->with(['items', 'events'])
            ->find($buildId);

        if ($build === null) {
            return null;
        }

        return $this->toDetail($build);
    }

    /**
     * @param  array<string, mixed>  $data
     */
    public function updateBuildItem(int $buildId, int $itemId, array $data): array
    {
        $item = PcgBuildItem::query()
            ->where('build_id', $buildId)
            ->where('id', $itemId)
            ->firstOrFail();

        $item->fill(array_filter([
            'label' => $data['label'] ?? null,
            'unit_cost_cents' => $data['unit_cost_cents'] ?? null,
            'component_id' => $data['component_id'] ?? null,
            'offer_id' => $data['offer_id'] ?? null,
            'quantity' => $data['quantity'] ?? null,
            'notes' => $data['notes'] ?? null,
        ], fn ($v) => $v !== null));

        $item->save();

        PcgBuild::query()->whereKey($buildId)->touch();

        return $this->getBuild($buildId) ?? throw new InvalidArgumentException("Montagem {$buildId} não encontrada");
    }

    /**
     * @param  array<string, mixed>|null  $payload
     */
    public function transitionStatus(
        int $buildId,
        BuildStatus $toStatus,
        ?string $notes = null,
        ?array $payload = null,
    ): array {
        return DB::transaction(function () use ($buildId, $toStatus, $notes, $payload) {
            $build = PcgBuild::query()->findOrFail($buildId);
            $fromStatus = $build->status;

            $build->update(['status' => $toStatus]);

            PcgBuildEvent::query()->create([
                'build_id' => $buildId,
                'event_type' => 'status_change',
                'from_status' => $fromStatus->value,
                'to_status' => $toStatus->value,
                'payload_json' => $payload,
                'notes' => $notes,
                'created_at' => now(),
            ]);

            return $this->getBuild($buildId);
        });
    }

    private function nextBuildCode(): string
    {
        $year = (int) now()->format('Y');
        $prefix = "PC-{$year}-";

        $last = PcgBuild::query()
            ->where('code', 'like', "{$prefix}%")
            ->orderByDesc('code')
            ->value('code');

        if ($last === null) {
            return "{$prefix}001";
        }

        $lastNum = (int) substr((string) $last, strrpos((string) $last, '-') + 1);

        return $prefix.str_pad((string) ($lastNum + 1), 3, '0', STR_PAD_LEFT);
    }

    /**
     * @return array<string, mixed>
     */
    private function toSummary(PcgBuild $build): array
    {
        $costCents = (int) $build->items->sum(
            fn (PcgBuildItem $item) => (int) $item->unit_cost_cents * (int) $item->quantity
        );
        $margin = (float) $build->margin_percent;

        return [
            'id' => $build->id,
            'code' => $build->code,
            'title' => $build->title,
            'status' => $build->status->value,
            'customer_name' => $build->customer_name,
            'cost_cents' => $costCents,
            'quote_cents' => (int) round($costCents * (1 + $margin / 100)),
            'margin_percent' => $margin,
            'item_count' => $build->items->count(),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function toDetail(PcgBuild $build): array
    {
        $items = $build->items->map(fn (PcgBuildItem $item) => [
            'id' => $item->id,
            'category_slug' => $item->category_slug,
            'label' => $item->label,
            'quantity' => $item->quantity,
            'unit_cost_cents' => $item->unit_cost_cents,
            'component_id' => $item->component_id,
            'offer_id' => $item->offer_id,
            'source' => $item->source,
            'notes' => $item->notes,
            'sort_order' => $item->sort_order,
        ])->values()->all();

        $costCents = array_sum(array_map(
            fn (array $i) => (int) $i['unit_cost_cents'] * (int) $i['quantity'],
            $items,
        ));
        $margin = (float) $build->margin_percent;

        return [
            'id' => $build->id,
            'code' => $build->code,
            'title' => $build->title,
            'status' => $build->status->value,
            'customer_name' => $build->customer_name,
            'customer_contact' => $build->customer_contact,
            'platform' => $build->platform,
            'margin_percent' => $margin,
            'notes' => $build->notes,
            'cost_cents' => $costCents,
            'quote_cents' => (int) round($costCents * (1 + $margin / 100)),
            'items' => $items,
            'events' => $build->events->map(fn (PcgBuildEvent $e) => [
                'event_type' => $e->event_type,
                'from_status' => $e->from_status,
                'to_status' => $e->to_status,
                'notes' => $e->notes,
                'created_at' => $e->created_at?->toIso8601String(),
            ])->values()->all(),
            'created_at' => $build->created_at?->toIso8601String(),
            'updated_at' => $build->updated_at?->toIso8601String(),
        ];
    }
}
