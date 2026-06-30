<?php

namespace App\Models\PcGamer;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PcgMarketPrice extends Model
{
    public $timestamps = false;

    protected $table = 'pcg_market_prices';

    protected $fillable = [
        'retailer_id',
        'category_slug',
        'product_name',
        'price_cents',
        'url',
        'recorded_at',
        'source',
        'notes',
    ];

    protected function casts(): array
    {
        return [
            'recorded_at' => 'datetime',
        ];
    }

    /** @return BelongsTo<PcgRetailer, $this> */
    public function retailer(): BelongsTo
    {
        return $this->belongsTo(PcgRetailer::class, 'retailer_id');
    }
}
