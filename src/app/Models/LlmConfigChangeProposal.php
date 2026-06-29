<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

class LlmConfigChangeProposal extends Model
{
    protected $fillable = [
        'diff',
        'reason',
        'tier',
        'status',
        'approved_by',
        'applied_at',
    ];

    protected function casts(): array
    {
        return [
            'diff' => 'array',
            'applied_at' => 'datetime',
        ];
    }

    /**
     * @param  Builder<LlmConfigChangeProposal>  $query
     * @return Builder<LlmConfigChangeProposal>
     */
    public function scopePending(Builder $query): Builder
    {
        return $query->where('status', 'pending');
    }
}
