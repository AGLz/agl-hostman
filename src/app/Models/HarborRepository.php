<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * HarborRepository Model
 *
 * Represents a Harbor repository (image collection)
 */
class HarborRepository extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'project_id',
        'harbor_id',
        'name',
        'project_name',
        'description',
        'pull_count',
        'artifact_count',
        'artifact_size_bytes',
        'last_push_at',
        'metadata',
    ];

    protected $casts = [
        'project_id' => 'integer',
        'pull_count' => 'integer',
        'artifact_count' => 'integer',
        'artifact_size_bytes' => 'integer',
        'metadata' => 'array',
        'last_push_at' => 'datetime',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
        'deleted_at' => 'datetime',
    ];

    /**
     * Project that owns this repository
     */
    public function project(): BelongsTo
    {
        return $this->belongsTo(HarborProject::class, 'project_id');
    }

    /**
     * Get artifact size in human readable format
     */
    public function getArtifactSizeHumanAttribute(): string
    {
        $bytes = $this->artifact_size_bytes;
        $units = ['B', 'KB', 'MB', 'GB', 'TB'];

        for ($i = 0; $bytes > 1024 && $i < count($units) - 1; $i++) {
            $bytes /= 1024;
        }

        return round($bytes, 2) . ' ' . $units[$i];
    }

    /**
     * Get full repository path
     */
    public function getFullPathAttribute(): string
    {
        return "{$this->project_name}/{$this->name}";
    }

    /**
     * Scope for repositories with artifacts
     */
    public function scopeWithArtifacts($query)
    {
        return $query->where('artifact_count', '>', 0);
    }

    /**
     * Scope for recently pushed
     */
    public function scopeRecentlyPushed($query, $days = 7)
    {
        return $query->where('last_push_at', '>=', now()->subDays($days));
    }
}
