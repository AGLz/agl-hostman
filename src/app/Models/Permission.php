<?php

namespace App\Models;

use Spatie\Permission\Models\Permission as SpatiePermission;

class Permission extends SpatiePermission
{
    protected $fillable = [
        'name',
        'guard_name',
        'module',
        'description',
    ];

    /**
     * Scope: Filter by module
     */
    public function scopeByModule($query, string $module)
    {
        return $query->where('module', $module);
    }

    /**
     * Scope: Filter by multiple modules
     */
    public function scopeInModules($query, array $modules)
    {
        return $query->whereIn('module', $modules);
    }

    /**
     * Get all available modules
     */
    public static function getModules(): array
    {
        return static::select('module')
            ->distinct()
            ->whereNotNull('module')
            ->pluck('module')
            ->sort()
            ->values()
            ->toArray();
    }

    /**
     * Get permission with module.action format
     */
    public function getFullNameAttribute(): string
    {
        return $this->module . '.' . $this->name;
    }

    /**
     * Scope: Search permissions by name or description
     */
    public function scopeSearch($query, string $term)
    {
        return $query->where(function ($q) use ($term) {
            $q->where('name', 'like', "%{$term}%")
                ->orWhere('description', 'like', "%{$term}%")
                ->orWhere('module', 'like', "%{$term}%");
        });
    }

    /**
     * Get count of roles with this permission
     */
    public function getRolesCountAttribute(): int
    {
        return $this->roles()->count();
    }

    /**
     * Get count of users with direct permission
     */
    public function getUsersCountAttribute(): int
    {
        // This uses the morph relationship
        return \DB::table('model_has_permissions')
            ->where('permission_id', $this->id)
            ->where('model_type', User::class)
            ->count();
    }
}
