<?php

namespace App\Models\PcGamer;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PcgBuildItem extends Model
{
    public $timestamps = false;

    protected $table = 'pcg_build_items';

    protected $fillable = [
        'build_id',
        'category_slug',
        'component_id',
        'offer_id',
        'label',
        'quantity',
        'unit_cost_cents',
        'source',
        'notes',
        'sort_order',
    ];

    /** @return BelongsTo<PcgBuild, $this> */
    public function build(): BelongsTo
    {
        return $this->belongsTo(PcgBuild::class, 'build_id');
    }

    /** @return BelongsTo<PcgTelegramOffer, $this> */
    public function offer(): BelongsTo
    {
        return $this->belongsTo(PcgTelegramOffer::class, 'offer_id');
    }
}
