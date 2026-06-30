<?php

namespace App\Models\PcGamer;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PcgComponent extends Model
{
    protected $table = 'pcg_components';

    protected $fillable = [
        'category_id',
        'sku',
        'brand',
        'model',
        'specs_json',
        'notes',
        'active',
    ];

    protected function casts(): array
    {
        return [
            'specs_json' => 'array',
            'active' => 'boolean',
        ];
    }

    /** @return BelongsTo<PcgComponentCategory, $this> */
    public function category(): BelongsTo
    {
        return $this->belongsTo(PcgComponentCategory::class, 'category_id');
    }
}
