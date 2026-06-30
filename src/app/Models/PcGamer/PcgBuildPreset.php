<?php

namespace App\Models\PcGamer;

use Illuminate\Database\Eloquent\Model;

class PcgBuildPreset extends Model
{
    public const UPDATED_AT = 'updated_at';

    public const CREATED_AT = null;

    protected $table = 'pcg_build_presets';

    protected $fillable = [
        'slug',
        'name',
        'tier',
        'platform',
        'reference_site',
        'description',
        'total_reference_cents',
        'items_json',
    ];

    protected function casts(): array
    {
        return [
            'items_json' => 'array',
            'updated_at' => 'datetime',
        ];
    }
}
