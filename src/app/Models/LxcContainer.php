<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Casts\AsArrayObject;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * LXC Container Model
 *
 * Represents a Proxmox LXC container instance.
 *
 * @property int $id
 * @property int $proxmox_server_id Parent Proxmox server
 * @property string $vmid Container VMID
 * @property string $name Container name
 * @property string $hostname Container hostname
 * @property string $status Current status
 * @property string|null $os_template OS template used
 * @property int $cores CPU cores
 * @property int $memory_mb Memory in MB
 * @property int $disk_gb Disk size in GB
 * @property array $network_config Network configuration
 * @property array $metadata Additional metadata
 * @property string|null $description Container description
 * @property bool $is_template Is template container
 * @property bool $auto_start Auto-start on boot
 * @property \Illuminate\Support\Carbon|null $started_at
 * @property \Illuminate\Support\Carbon|null $stopped_at
 * @property \Illuminate\Support\Carbon|null $created_at
 * @property \Illuminate\Support\Carbon|null $updated_at
 * @property \Illuminate\Support\Carbon|null $deleted_at
 * @property-read ProxmoxServer $server
 */
class LxcContainer extends Model
{
    use HasFactory, SoftDeletes;

    protected $table = 'lxc_containers';

    /**
     * The attributes that are mass assignable.
     *
     * @var array<int, string>
     */
    protected $fillable = [
        'proxmox_server_id',
        'vmid',
        'name',
        'hostname',
        'status',
        'os_template',
        'cores',
        'memory_mb',
        'disk_gb',
        'network_config',
        'metadata',
        'description',
        'is_template',
        'auto_start',
        'started_at',
        'stopped_at',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'proxmox_server_id' => 'integer',
            'cores' => 'integer',
            'memory_mb' => 'integer',
            'disk_gb' => 'integer',
            'network_config' => AsArrayObject::class,
            'metadata' => AsArrayObject::class,
            'is_template' => 'boolean',
            'auto_start' => 'boolean',
            'started_at' => 'datetime',
            'stopped_at' => 'datetime',
            'created_at' => 'datetime',
            'updated_at' => 'datetime',
            'deleted_at' => 'datetime',
        ];
    }

    /**
     * Proxmox server relationship
     */
    public function server(): BelongsTo
    {
        return $this->belongsTo(ProxmoxServer::class, 'proxmox_server_id');
    }

    /**
     * Scope: running containers
     */
    public function scopeRunning($query)
    {
        return $query->where('status', 'running');
    }

    /**
     * Scope: stopped containers
     */
    public function scopeStopped($query)
    {
        return $query->where('status', 'stopped');
    }

    /**
     * Scope: by server
     */
    public function scopeOnServer($query, int $serverId)
    {
        return $query->where('proxmox_server_id', $serverId);
    }

    /**
     * Scope: templates only
     */
    public function scopeTemplates($query)
    {
        return $query->where('is_template', true);
    }

    /**
     * Scope: non-templates only
     */
    public function scopeNonTemplates($query)
    {
        return $query->where('is_template', false);
    }

    /**
     * Check if container is running
     */
    public function isRunning(): bool
    {
        return $this->status === 'running';
    }

    /**
     * Check if container is stopped
     */
    public function isStopped(): bool
    {
        return $this->status === 'stopped';
    }

    /**
     * Get uptime in seconds
     */
    public function getUptimeSeconds(): ?int
    {
        if (! $this->isRunning() || ! $this->started_at) {
            return null;
        }

        return now()->diffInSeconds($this->started_at);
    }

    /**
     * Get formatted uptime
     */
    public function getFormattedUptime(): ?string
    {
        $uptime = $this->getUptimeSeconds();

        if ($uptime === null) {
            return null;
        }

        $days = floor($uptime / 86400);
        $hours = floor(($uptime % 86400) / 3600);
        $minutes = floor(($uptime % 3600) / 60);

        if ($days > 0) {
            return sprintf('%dd %dh %dm', $days, $hours, $minutes);
        }

        if ($hours > 0) {
            return sprintf('%dh %dm', $hours, $minutes);
        }

        return sprintf('%dm', $minutes);
    }

    /**
     * Get primary IP address
     */
    public function getPrimaryIp(): ?string
    {
        if (! isset($this->network_config['net0'])) {
            return null;
        }

        $net0 = $this->network_config['net0'];

        if (is_string($net0) && preg_match('/ip=([0-9\.]+)/', $net0, $matches)) {
            return $matches[1];
        }

        if (is_array($net0) && isset($net0['ip'])) {
            return $net0['ip'];
        }

        return null;
    }

    /**
     * Get full qualified domain name
     */
    public function getFqdn(): string
    {
        return $this->hostname ?: ($this->name.'.'.config('app.domain', 'local'));
    }

    /**
     * Get resource summary
     *
     * @return array<string, mixed>
     */
    public function getResourceSummary(): array
    {
        return [
            'cores' => $this->cores,
            'memory_mb' => $this->memory_mb,
            'memory_gb' => round($this->memory_mb / 1024, 2),
            'disk_gb' => $this->disk_gb,
        ];
    }

    /**
     * Mark container as started
     */
    public function markStarted(): bool
    {
        return $this->update([
            'status' => 'running',
            'started_at' => now(),
            'stopped_at' => null,
        ]);
    }

    /**
     * Mark container as stopped
     */
    public function markStopped(): bool
    {
        return $this->update([
            'status' => 'stopped',
            'stopped_at' => now(),
        ]);
    }

    /**
     * Get display name
     */
    public function getDisplayName(): string
    {
        return sprintf('%s (CT%s)', $this->name, $this->vmid);
    }
}
