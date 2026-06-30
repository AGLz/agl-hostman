<?php

namespace App\Models\PcGamer;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class PcgRetailer extends Model
{
    public $timestamps = false;

    protected $table = 'pcg_retailers';

    protected $fillable = [
        'slug',
        'name',
        'website',
        'configurator_url',
        'is_aggregator',
        'notes',
    ];

    protected function casts(): array
    {
        return [
            'is_aggregator' => 'boolean',
        ];
    }

    /** @return HasMany<PcgMarketPrice, $this> */
    public function marketPrices(): HasMany
    {
        return $this->hasMany(PcgMarketPrice::class, 'retailer_id');
    }
}
