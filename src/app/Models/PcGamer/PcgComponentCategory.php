<?php

namespace App\Models\PcGamer;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class PcgComponentCategory extends Model
{
    public $timestamps = false;

    protected $table = 'pcg_component_categories';

    protected $fillable = ['slug', 'name', 'sort_order'];

    /** @return HasMany<PcgComponent, $this> */
    public function components(): HasMany
    {
        return $this->hasMany(PcgComponent::class, 'category_id');
    }
}
