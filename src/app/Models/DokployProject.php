<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * Dokploy Project Model
 *
 * @property int $id
 * @property string $dokploy_id
 * @property string $name
 * @property string|null $description
 * @property string|null $organization_id
 * @property string|null $env
 * @property array|null $metadata
 * @property string $status
 * @property \Illuminate\Support\Carbon $created_at
 * @property \Illuminate\Support\Carbon $updated_at
 * @property \Illuminate\Support\Carbon|null $deleted_at
 */
class DokployProject extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'dokploy_id',
        'name',
        'description',
        'organization_id',
        'env',
        'metadata',
        'status',
    ];

    protected $casts = [
        'metadata' => 'array',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
        'deleted_at' => 'datetime',
    ];

    protected $attributes = [
        'status' => 'active',
    ];

    /**
     * Get applications for this project
     */
    public function applications(): HasMany
    {
        return $this->hasMany(DokployApplication::class, 'project_id');
    }

    /**
     * Get active applications
     */
    public function activeApplications(): HasMany
    {
        return $this->applications()->where('status', '!=', 'error');
    }

    /**
     * Scope: Active projects
     */
    public function scopeActive($query)
    {
        return $query->where('status', 'active');
    }

    /**
     * Scope: By Dokploy ID
     */
    public function scopeByDokployId($query, string $dokployId)
    {
        return $query->where('dokploy_id', $dokployId);
    }
}
