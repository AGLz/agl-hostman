<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Casts\AsArrayObject;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * Proxmox Server Model
 *
 * Represents a Proxmox VE host server in the infrastructure.
 *
 * @property int $id
 * @property string $name Server hostname
 * @property string $code Unique server code
 * @property string $ip_address Primary IP address
 * @property int $port API port
 * @property string $username API username
 * @property string|null $password Encrypted API password
 * @property string|null $realm Authentication realm
 * @property bool $verify_ssl SSL verification enabled
 * @property int|null $physical_location_id Physical location
 * @property string $status Server status (online, offline, maintenance)
 * @property array $metadata Additional server metadata
 * @property \Illuminate\Support\Carbon|null $last_seen_at
 * @property \Illuminate\Support\Carbon|null $created_at
 * @property \Illuminate\Support\Carbon|null $updated_at
 * @property \Illuminate\Support\Carbon|null $deleted_at
 * @property-read PhysicalLocation|null $location
 * @property-read \Illuminate\Database\Eloquent\Collection<int, LxcContainer> $containers
 */
class ProxmoxServer extends Model
{
    use HasFactory, SoftDeletes;

    protected $table = 'proxmox_servers';

    /**
     * The attributes that are mass assignable.
     *
     * @var array<int, string>
     */
    protected $fillable = [
        'name',
        'code',
        'ip_address',
        'port',
        'username',
        'password',
        'realm',
        'verify_ssl',
        'physical_location_id',
        'status',
        'metadata',
        'last_seen_at',
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var array<int, string>
     */
    protected $hidden = [
        'password',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'port' => 'integer',
            'verify_ssl' => 'boolean',
            'metadata' => AsArrayObject::class,
            'last_seen_at' => 'datetime',
            'created_at' => 'datetime',
            'updated_at' => 'datetime',
            'deleted_at' => 'datetime',
        ];
    }

    /**
     * Physical location relationship
     */
    public function location(): BelongsTo
    {
        return $this->belongsTo(PhysicalLocation::class, 'physical_location_id');
    }

    /**
     * LXC containers on this server
     */
    public function containers(): HasMany
    {
        return $this->hasMany(LxcContainer::class, 'proxmox_server_id');
    }

    /**
     * Scope: online servers only
     */
    public function scopeOnline($query)
    {
        return $query->where('status', 'online');
    }

    /**
     * Scope: by location
     */
    public function scopeInLocation($query, int $locationId)
    {
        return $query->where('physical_location_id', $locationId);
    }

    /**
     * Check if server is online
     */
    public function isOnline(): bool
    {
        return $this->status === 'online'
            && $this->last_seen_at?->gt(now()->subMinutes(5));
    }

    /**
     * Check if server is in maintenance
     */
    public function isInMaintenance(): bool
    {
        return $this->status === 'maintenance';
    }

    /**
     * Mark server as online
     */
    public function markOnline(): bool
    {
        return $this->update([
            'status' => 'online',
            'last_seen_at' => now(),
        ]);
    }

    /**
     * Mark server as offline
     */
    public function markOffline(): bool
    {
        return $this->update([
            'status' => 'offline',
            'last_seen_at' => now(),
        ]);
    }

    /**
     * Get API configuration array
     *
     * @return array<string, mixed>
     */
    public function getApiConfig(): array
    {
        return [
            'host' => $this->ip_address,
            'port' => $this->port,
            'username' => $this->username,
            'password' => decrypt($this->password),
            'realm' => $this->realm ?? 'pam',
            'verify_ssl' => $this->verify_ssl,
        ];
    }

    /**
     * Get display name
     */
    public function getDisplayName(): string
    {
        return $this->name.' ('.$this->code.')';
    }

    /**
     * Boot method
     */
    protected static function boot()
    {
        parent::boot();

        // Encrypt password before saving
        static::saving(function ($server) {
            if ($server->isDirty('password') && $server->password) {
                $server->password = encrypt($server->password);
            }
        });
    }
}
