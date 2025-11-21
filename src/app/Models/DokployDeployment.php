<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DokployDeployment extends Model
{
    use HasFactory;

    protected $fillable = [
        'application_id',
        'dokploy_id',
        'status',
        'title',
        'description',
        'commit_hash',
        'branch',
        'tag',
        'triggered_by',
        'error_message',
        'metadata',
        'started_at',
        'completed_at',
        'duration_seconds',
    ];

    protected $casts = [
        'metadata' => 'array',
        'started_at' => 'datetime',
        'completed_at' => 'datetime',
        'duration_seconds' => 'integer',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    public function application(): BelongsTo
    {
        return $this->belongsTo(DokployApplication::class, 'application_id');
    }

    public function scopeSuccessful($query)
    {
        return $query->where('status', 'success');
    }

    public function scopeFailed($query)
    {
        return $query->where('status', 'failed');
    }

    public function scopeInProgress($query)
    {
        return $query->whereIn('status', ['pending', 'building', 'deploying']);
    }
}
