<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DailySessionLog extends Model
{
    /** @use HasFactory<\Database\Factories\DailySessionLogFactory> */
    use HasFactory;

    protected $fillable = [
        'user_id',
        'occurred_on',
        'title',
        'summary',
        'topics',
        'project_tags',
        'source',
    ];

    protected function casts(): array
    {
        return [
            'occurred_on' => 'date',
            'topics' => 'array',
            'project_tags' => 'array',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Pesquisa simples no resumo e etiquetas (SQLite LIKE).
     *
     * @param  Builder<DailySessionLog>  $query
     * @return Builder<DailySessionLog>
     */
    public function scopeSearch(Builder $query, ?string $term): Builder
    {
        if ($term === null || trim($term) === '') {
            return $query;
        }

        $like = '%'.addcslashes(trim($term), '%_\\').'%';

        return $query->where(function (Builder $q) use ($like) {
            $q->where('summary', 'like', $like)
                ->orWhere('title', 'like', $like)
                ->orWhere('topics', 'like', $like)
                ->orWhere('project_tags', 'like', $like);
        });
    }
}
