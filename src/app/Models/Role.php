<?php

namespace App\Models;

use Spatie\Permission\Models\Role as SpatieRole;

class Role extends SpatieRole
{
    protected $fillable = [
        'name',
        'guard_name',
        'description',
        'is_system',
    ];

    /**
     * The attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'is_system' => 'boolean',
        ];
    }

    /**
     * Scope: Only system roles
     */
    public function scopeSystem($query)
    {
        return $query->where('is_system', true);
    }

    /**
     * Scope: Only custom roles
     */
    public function scopeCustom($query)
    {
        return $query->where('is_system', false);
    }

    /**
     * Check if role is a system role
     */
    public function isSystem(): bool
    {
        return $this->is_system ?? false;
    }

    /**
     * Check if role can be deleted
     * System roles should not be deleted
     */
    public function canBeDeleted(): bool
    {
        return ! $this->is_system;
    }

    /**
     * Get permissions grouped by module
     */
    public function getPermissionsGroupedByModuleAttribute()
    {
        return $this->permissions->groupBy('module');
    }

    /**
     * Get count of users with this role
     */
    public function getUsersCountAttribute(): int
    {
        return $this->users()->count();
    }
}
