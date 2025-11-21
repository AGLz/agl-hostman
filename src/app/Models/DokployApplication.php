<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class DokployApplication extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'project_id',
        'dokploy_id',
        'name',
        'app_name',
        'description',
        'environment_id',
        'server_id',
        'docker_image',
        'source_type',
        'build_type',
        'status',
        'env',
        'build_args',
        'cpu_limit',
        'memory_limit',
        'replicas',
        'auto_deploy',
        'metadata',
        'last_deployed_at',
    ];

    protected $casts = [
        'metadata' => 'array',
        'auto_deploy' => 'boolean',
        'replicas' => 'integer',
        'cpu_limit' => 'integer',
        'memory_limit' => 'integer',
        'last_deployed_at' => 'datetime',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
        'deleted_at' => 'datetime',
    ];

    public function project(): BelongsTo
    {
        return $this->belongsTo(DokployProject::class, 'project_id');
    }

    public function deployments(): HasMany
    {
        return $this->hasMany(DokployDeployment::class, 'application_id');
    }

    public function domains(): HasMany
    {
        return $this->hasMany(DokployDomain::class, 'application_id');
    }

    public function scopeRunning($query)
    {
        return $query->where('status', 'running');
    }

    public function scopeByStatus($query, string $status)
    {
        return $query->where('status', $status);
    }
}
