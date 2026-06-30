<?php

namespace App\Models\PcGamer;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PcgBuildEvent extends Model
{
    public $timestamps = false;

    protected $table = 'pcg_build_events';

    protected $fillable = [
        'build_id',
        'event_type',
        'from_status',
        'to_status',
        'payload_json',
        'notes',
        'created_at',
    ];

    protected function casts(): array
    {
        return [
            'payload_json' => 'array',
            'created_at' => 'datetime',
        ];
    }

    /** @return BelongsTo<PcgBuild, $this> */
    public function build(): BelongsTo
    {
        return $this->belongsTo(PcgBuild::class, 'build_id');
    }
}
