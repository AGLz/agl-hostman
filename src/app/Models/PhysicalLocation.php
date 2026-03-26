<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;

class PhysicalLocation extends Model
{
    use HasFactory;

    /**
     * The attributes that are mass assignable.
     *
     * @var array<int, string>
     */
    protected $fillable = [
        'code',
        'name',
        'description',
        'address',
        'city',
        'state',
        'country',
        'latitude',
        'longitude',
        'type',
        'ip_range',
        'metadata',
        'is_active',
    ];

    /**
     * The attributes that should be cast.
     *
     * @var array<string, string>
     */
    protected $casts = [
        'latitude' => 'decimal:8',
        'longitude' => 'decimal:8',
        'metadata' => 'array',
        'is_active' => 'boolean',
    ];

    /**
     * Users that have access to this location
     */
    public function users(): BelongsToMany
    {
        return $this->belongsToMany(User::class, 'user_locations')
            ->withPivot(['access_level', 'is_primary'])
            ->withTimestamps();
    }

    /**
     * Check if location is active
     */
    public function isActive(): bool
    {
        return $this->is_active ?? true;
    }

    /**
     * Get location type label
     */
    public function getTypeLabel(): string
    {
        return match ($this->type) {
            'headquarters' => 'Headquarters',
            'datacenter' => 'Data Center',
            'container' => 'Container',
            'remote' => 'Remote Location',
            default => ucfirst($this->type),
        };
    }

    /**
     * Scope: Only active locations
     */
    public function scopeActive($query)
    {
        return $query->where('is_active', true);
    }

    /**
     * Scope: Filter by type
     */
    public function scopeOfType($query, string $type)
    {
        return $query->where('type', $type);
    }

    /**
     * Scope: Filter by code
     */
    public function scopeByCode($query, string $code)
    {
        return $query->where('code', $code);
    }

    /**
     * Get users with specific access level
     */
    public function getUsersWithAccessLevel(string $level)
    {
        return $this->users()
            ->wherePivot('access_level', '>=', $level)
            ->get();
    }

    /**
     * Get admin users for this location
     */
    public function getAdminUsers()
    {
        return $this->getUsersWithAccessLevel('admin');
    }

    /**
     * Check if location has IP range defined
     */
    public function hasIpRange(): bool
    {
        return ! empty($this->ip_range);
    }

    /**
     * Check if IP address is within location's IP range
     */
    public function isIpInRange(string $ip): bool
    {
        if (! $this->hasIpRange()) {
            return false;
        }

        // Support for CIDR notation (e.g., 192.168.0.0/24)
        if (strpos($this->ip_range, '/') !== false) {
            return $this->ipInCidr($ip, $this->ip_range);
        }

        // Support for simple IP match
        return $ip === $this->ip_range;
    }

    /**
     * Check if IP is within CIDR range
     */
    protected function ipInCidr(string $ip, string $cidr): bool
    {
        [$subnet, $mask] = explode('/', $cidr);

        $ip_long = ip2long($ip);
        $subnet_long = ip2long($subnet);
        $mask_long = ~((1 << (32 - $mask)) - 1);

        return ($ip_long & $mask_long) === ($subnet_long & $mask_long);
    }

    /**
     * Get location coordinates
     */
    public function getCoordinates(): ?array
    {
        if ($this->latitude && $this->longitude) {
            return [
                'lat' => (float) $this->latitude,
                'lng' => (float) $this->longitude,
            ];
        }

        return null;
    }

    /**
     * Get full address string
     */
    public function getFullAddress(): string
    {
        $parts = array_filter([
            $this->address,
            $this->city,
            $this->state,
            $this->country,
        ]);

        return implode(', ', $parts);
    }
}
