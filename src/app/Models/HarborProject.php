<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * HarborProject Model
 *
 * Represents a Harbor container registry project
 */
class HarborProject extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'harbor_id',
        'name',
        'public',
        'owner_id',
        'owner_name',
        'metadata',
        'cve_allowlist',
        'prevent_vul',
        'severity',
        'auto_scan',
        'enable_content_trust',
        'enable_content_trust_ci',
        'storage_quota',
        'storage_used',
        'registry_id',
    ];

    protected $casts = [
        'public' => 'boolean',
        'metadata' => 'array',
        'cve_allowlist' => 'array',
        'prevent_vul' => 'boolean',
        'auto_scan' => 'boolean',
        'enable_content_trust' => 'boolean',
        'enable_content_trust_ci' => 'boolean',
        'storage_quota' => 'integer',
        'storage_used' => 'integer',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
        'deleted_at' => 'datetime',
    ];

    /**
     * Repositories in this project
     */
    public function repositories(): HasMany
    {
        return $this->hasMany(HarborRepository::class, 'project_id');
    }

    /**
     * Scope for public projects
     */
    public function scopePublic($query)
    {
        return $query->where('public', true);
    }

    /**
     * Scope for private projects
     */
    public function scopePrivate($query)
    {
        return $query->where('public', false);
    }

    /**
     * Scope for auto-scan enabled
     */
    public function scopeAutoScan($query)
    {
        return $query->where('auto_scan', true);
    }

    /**
     * Get storage usage percentage
     */
    public function getStorageUsagePercentAttribute(): float
    {
        if ($this->storage_quota && $this->storage_quota > 0) {
            return round(($this->storage_used / $this->storage_quota) * 100, 2);
        }
        return 0;
    }

    /**
     * Check if project is over storage quota
     */
    public function isOverQuota(): bool
    {
        return $this->storage_quota > 0 && $this->storage_used > $this->storage_quota;
    }
}
