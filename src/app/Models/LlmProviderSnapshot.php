<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

class LlmProviderSnapshot extends Model
{
    protected $fillable = [
        'provider',
        'model_alias',
        'tier',
        'status',
        'windows_json',
        'context_tokens',
        'detail',
        'captured_at',
    ];

    protected function casts(): array
    {
        return [
            'windows_json' => 'array',
            'context_tokens' => 'integer',
            'captured_at' => 'datetime',
        ];
    }

    /**
     * @param  Builder<LlmProviderSnapshot>  $query
     * @return Builder<LlmProviderSnapshot>
     */
    public function scopeForProvider(Builder $query, string $provider): Builder
    {
        return $query->where('provider', strtolower($provider));
    }

    /**
     * @param  Builder<LlmProviderSnapshot>  $query
     * @return Builder<LlmProviderSnapshot>
     */
    public function scopeLatestPerModel(Builder $query): Builder
    {
        return $query->whereIn('id', function ($sub) {
            $sub->selectRaw('MAX(id)')
                ->from('llm_provider_snapshots')
                ->groupBy('model_alias');
        });
    }
}
