<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Traits\HasRoles;

class User extends Authenticatable
{
    /** @use HasFactory<\Database\Factories\UserFactory> */
    use HasApiTokens, HasFactory, Notifiable;

    use HasRoles {
        hasPermissionTo as protected hasPermissionToFromTrait;
        hasAnyPermission as protected hasAnyPermissionFromTrait;
        hasAllPermissions as protected hasAllPermissionsFromTrait;
        hasRole as protected hasRoleFromTrait;
        hasAnyRole as protected hasAnyRoleFromTrait;
        hasAllRoles as protected hasAllRolesFromTrait;
        getAllPermissions as protected getAllPermissionsFromTrait;
        givePermissionTo as protected givePermissionToFromTrait;
    }

    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'name',
        'email',
        'password',
        'workos_id',
        'avatar_url',
        'last_login_at',
        'is_active',
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var list<string>
     */
    protected $hidden = [
        'password',
        'remember_token',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'last_login_at' => 'datetime',
            'is_active' => 'boolean',
        ];
    }

    /**
     * Localizações físicas que o usuário pode acessar
     */
    public function physicalLocations(): BelongsToMany
    {
        return $this->belongsToMany(PhysicalLocation::class, 'user_locations')
            ->withPivot(['access_level', 'is_primary'])
            ->withTimestamps();
    }

    /**
     * Registos diários de trabalho com assistentes (resumos por dia).
     */
    public function dailySessionLogs(): HasMany
    {
        return $this->hasMany(DailySessionLog::class);
    }

    /**
     * Localização primária do usuário
     *
     * FIXED: Added eager loading scope to prevent N+1 queries
     */
    public function primaryLocation()
    {
        return $this->physicalLocations()
            ->wherePivot('is_primary', true)
            ->first();
    }

    /**
     * Scope: Eager load primary location to prevent N+1 queries
     *
     * Usage: User::withPrimaryLocation()->get()
     */
    public function scopeWithPrimaryLocation($query)
    {
        return $query->with(['physicalLocations' => function ($query) {
            $query->wherePivot('is_primary', true);
        }]);
    }

    /**
     * Get primary location with eager loading (optimized accessor)
     *
     * Usage: $user->primary_location
     */
    public function getPrimaryLocationAttribute(): ?PhysicalLocation
    {
        // Check if relation is already loaded
        if ($this->relationLoaded('physicalLocations')) {
            return $this->physicalLocations->firstWhere('pivot.is_primary', true);
        }

        // Fallback to query if not loaded
        return $this->primaryLocation();
    }

    /**
     * Verifica se usuário tem acesso a uma localização
     */
    public function hasAccessToLocation($locationCode, $level = 'view'): bool
    {
        $location = $this->physicalLocations()
            ->where('code', $locationCode)
            ->first();

        if (! $location) {
            return false;
        }

        // Convert access levels to numeric hierarchy
        $levels = ['view' => 1, 'manage' => 2, 'admin' => 3];
        $userLevel = $levels[$location->pivot->access_level] ?? 0;
        $requiredLevel = $levels[$level] ?? 0;

        return $userLevel >= $requiredLevel;
    }

    /**
     * Verifica se o usuário está ativo
     */
    public function isActive(): bool
    {
        return $this->is_active ?? true;
    }

    /**
     * Get all accessible locations with access level
     *
     * @return \Illuminate\Support\Collection
     */
    public function getAccessibleLocations()
    {
        return $this->physicalLocations()
            ->get()
            ->map(fn ($location) => [
                'location' => $location,
                'access_level' => $location->pivot->access_level,
                'is_primary' => $location->pivot->is_primary,
            ]);
    }

    /**
     * Check if user has admin access to any location
     */
    public function hasAdminAccess(): bool
    {
        return $this->physicalLocations()
            ->wherePivot('access_level', '>=', 'admin')
            ->exists();
    }

    // ========================================
    // RBAC Enhancement Methods (Phase 5)
    // ========================================

    /**
     * Check if user has specific permission
     *
     * @param  string  $permission  Permission name (e.g., 'view-dashboard', 'manage-users')
     */
    public function hasPermissionTo(string $permission): bool
    {
        // Check if user is active first
        if (! $this->isActive()) {
            return false;
        }

        try {
            return $this->hasPermissionToFromTrait($permission);
        } catch (\Throwable) {
            return false;
        }
    }

    /**
     * Check if user has any of the given permissions
     *
     * @param  array  $permissions  Array of permission names
     */
    public function hasAnyPermission(array $permissions): bool
    {
        if (! $this->isActive()) {
            return false;
        }

        try {
            return $this->hasAnyPermissionFromTrait($permissions);
        } catch (\Throwable) {
            return false;
        }
    }

    /**
     * Check if user has all of the given permissions
     *
     * @param  array  $permissions  Array of permission names
     */
    public function hasAllPermissions(array $permissions): bool
    {
        if (! $this->isActive()) {
            return false;
        }

        try {
            return $this->hasAllPermissionsFromTrait($permissions);
        } catch (\Throwable) {
            return false;
        }
    }

    public function givePermissionTo(...$permissions): static
    {
        $guard = $this->getDefaultGuardName();
        $flatPermissions = collect($permissions)->flatten();

        foreach ($flatPermissions as $permission) {
            if (is_string($permission)) {
                Permission::findOrCreate($permission, $guard);
            }
        }

        $this->givePermissionToFromTrait(...$permissions);

        return $this;
    }

    /**
     * Check if user has specific role
     *
     * @param  string  $role  Role name (e.g., 'admin', 'operator', 'viewer')
     */
    public function hasRole($role): bool
    {
        if (! $this->isActive()) {
            return false;
        }

        return $this->hasRoleFromTrait($role);
    }

    /**
     * Check if user has any of the given roles
     *
     * @param  array|string  $roles  Role name(s)
     */
    public function hasAnyRole($roles): bool
    {
        if (! $this->isActive()) {
            return false;
        }

        return $this->hasAnyRoleFromTrait($roles);
    }

    /**
     * Check if user has all of the given roles
     *
     * @param  array  $roles  Array of role names
     */
    public function hasAllRoles($roles): bool
    {
        if (! $this->isActive()) {
            return false;
        }

        return $this->hasAllRolesFromTrait($roles);
    }

    /**
     * Check if user is a super admin
     */
    public function isSuperAdmin(): bool
    {
        return $this->isActive() && $this->hasRole('super-admin');
    }

    /**
     * Check if user can access dashboard
     */
    public function canAccessDashboard(): bool
    {
        return $this->isActive() &&
               $this->hasAnyPermission(['view-dashboard', 'admin-access']);
    }

    /**
     * Check if user can manage other users
     */
    public function canManageUsers(): bool
    {
        return $this->isActive() &&
               $this->hasAnyPermission(['manage-users', 'admin-access']);
    }

    /**
     * Check if user can manage roles and permissions
     */
    public function canManageRoles(): bool
    {
        return $this->isActive() &&
               $this->hasAnyPermission(['manage-roles', 'admin-access']);
    }

    /**
     * Check if user can view predictive maintenance
     */
    public function canViewPredictiveMaintenance(): bool
    {
        return $this->isActive() &&
               $this->hasAnyPermission(['view-predictions', 'view-dashboard', 'admin-access']);
    }

    /**
     * Check if user can manage infrastructure
     */
    public function canManageInfrastructure(): bool
    {
        return $this->isActive() &&
               $this->hasAnyPermission(['manage-infrastructure', 'admin-access']);
    }

    /**
     * Get user's primary role
     *
     * @return \Spatie\Permission\Models\Role|null
     */
    public function getPrimaryRoleAttribute()
    {
        return $this->roles()->orderBy('id', 'asc')->first();
    }

    /**
     * Get user's permissions through roles
     *
     * @return \Illuminate\Support\Collection
     */
    public function getAllPermissions()
    {
        if (! $this->isActive()) {
            return collect();
        }

        return $this->getAllPermissionsFromTrait();
    }

    /**
     * Get user's direct permissions (not through roles)
     *
     * @return \Illuminate\Database\Eloquent\Collection
     */
    public function getDirectPermissions()
    {
        if (! $this->isActive()) {
            return collect();
        }

        return $this->permissions;
    }

    /**
     * Update last login timestamp
     */
    public function updateLastLogin(): void
    {
        $this->update(['last_login_at' => now()]);
    }

    /**
     * Deactivate user account
     */
    public function deactivate(): void
    {
        $this->update(['is_active' => false]);
    }

    /**
     * Activate user account
     */
    public function activate(): void
    {
        $this->update(['is_active' => true]);
    }

    /**
     * Get user's audit trail
     *
     * @return \Illuminate\Database\Eloquent\Relations\HasMany
     */
    public function auditLogs()
    {
        return $this->hasMany(AuditLog::class);
    }

    /**
     * Scope: Only active users
     *
     * @param  \Illuminate\Database\Eloquent\Builder  $query
     * @return \Illuminate\Database\Eloquent\Builder
     */
    public function scopeActive($query)
    {
        return $query->where('is_active', true);
    }

    /**
     * Scope: Only inactive users
     *
     * @param  \Illuminate\Database\Eloquent\Builder  $query
     * @return \Illuminate\Database\Eloquent\Builder
     */
    public function scopeInactive($query)
    {
        return $query->where('is_active', false);
    }

    /**
     * Scope: Users with specific role
     *
     * @param  \Illuminate\Database\Eloquent\Builder  $query
     * @return \Illuminate\Database\Eloquent\Builder
     */
    public function scopeWithRole($query, string $role)
    {
        return $query->role($role);
    }

    /**
     * Scope: Users with specific permission
     *
     * @param  \Illuminate\Database\Eloquent\Builder  $query
     * @return \Illuminate\Database\Eloquent\Builder
     */
    public function scopeWithPermission($query, string $permission)
    {
        return $query->permission($permission);
    }
}
