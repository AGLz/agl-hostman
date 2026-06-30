<?php

namespace App\Models\PcGamer;

use App\Enums\PcGamer\BuildStatus;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class PcgBuild extends Model
{
    protected $table = 'pcg_builds';

    protected $fillable = [
        'code',
        'title',
        'customer_name',
        'customer_contact',
        'platform',
        'status',
        'margin_percent',
        'notes',
    ];

    protected function casts(): array
    {
        return [
            'status' => BuildStatus::class,
            'margin_percent' => 'float',
        ];
    }

    /** @return HasMany<PcgBuildItem, $this> */
    public function items(): HasMany
    {
        return $this->hasMany(PcgBuildItem::class, 'build_id')->orderBy('sort_order');
    }

    /** @return HasMany<PcgBuildEvent, $this> */
    public function events(): HasMany
    {
        return $this->hasMany(PcgBuildEvent::class, 'build_id');
    }
}
