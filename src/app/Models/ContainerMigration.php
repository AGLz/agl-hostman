<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Casts\AsArrayObject;

/**
 * Container Migration Model
 *
 * Represents a container migration between Proxmox nodes.
 *
 * @property int $id
 * @property int $container_id
 * @property int $source_server_id
 * @property int $target_server_id
 * @property string $status
 * @property int $progress
 * @property bool $online
 * @property string|null $task_id
 * @property int|null $transferred_mb
 * @property int|null $total_mb
 * @property int|null $estimated_seconds
 * @property string|null $error_message
 * @property array $metadata
 * @property \Illuminate\Support\Carbon|null $started_at
 * @property \Illuminate\Support\Carbon|null $completed_at
 * @property \Illuminate\Support\Carbon|null $created_at
 * @property \Illuminate\Support\Carbon|null $updated_at
 *
 * @property-read LxcContainer $container
 * @property-read ProxmoxServer $sourceServer
 * @property-read ProxmoxServer $targetServer
 */
class ContainerMigration extends Model
{
    use HasFactory;

    protected $table = 'container_migrations';

    public const STATUS_PENDING = 'pending';
    public const STATUS_PREPARING = 'preparing';
    public const STATUS_SYNCING = 'syncing';
    public const STATUS_MIGRATING = 'migrating';
    public const STATUS_COMPLETING = 'completing';
    public const STATUS_COMPLETED = 'completed';
    public const STATUS_FAILED = 'failed';

    /**
     * The attributes that are mass assignable.
     *
     * @var array<int, string>
     */
    protected $fillable = [
        'container_id',
        'source_server_id',
        'target_server_id',
        'status',
        'progress',
        'online',
        'task_id',
        'transferred_mb',
        'total_mb',
        'estimated_seconds',
        'error_message',
        'metadata',
        'started_at',
        'completed_at',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'container_id' => 'integer',
            'source_server_id' => 'integer',
            'target_server_id' => 'integer',
            'progress' => 'integer',
            'online' => 'boolean',
            'transferred_mb' => 'integer',
            'total_mb' => 'integer',
            'estimated_seconds' => 'integer',
            'metadata' => AsArrayObject::class,
            'started_at' => 'datetime',
            'completed_at' => 'datetime',
            'created_at' => 'datetime',
            'updated_at' => 'datetime',
        ];
    }

    /**
     * Container relationship
     */
    public function container(): BelongsTo
    {
        return $this->belongsTo(LxcContainer::class, 'container_id');
    }

    /**
     * Source server relationship
     */
    public function sourceServer(): BelongsTo
    {
        return $this->belongsTo(ProxmoxServer::class, 'source_server_id');
    }

    /**
     * Target server relationship
     */
    public function targetServer(): BelongsTo
    {
        return $this->belongsTo(ProxmoxServer::class, 'target_server_id');
    }

    /**
     * Scope: in progress migrations
     */
    public function scopeInProgress($query)
    {
        return $query->whereIn('status', [
            self::STATUS_PENDING,
            self::STATUS_PREPARING,
            self::STATUS_SYNCING,
            self::STATUS_MIGRATING,
            self::STATUS_COMPLETING,
        ]);
    }

    /**
     * Scope: completed migrations
     */
    public function scopeCompleted($query)
    {
        return $query->where('status', self::STATUS_COMPLETED);
    }

    /**
     * Scope: failed migrations
     */
    public function scopeFailed($query)
    {
        return $query->where('status', self::STATUS_FAILED);
    }

    /**
     * Scope: recent migrations (last 24 hours)
     */
    public function scopeRecent($query)
    {
        return $query->where('started_at', '>=', now()->subDay());
    }

    /**
     * Scope: online migrations
     */
    public function scopeOnline($query)
    {
        return $query->where('online', true);
    }

    /**
     * Check if migration is in progress
     */
    public function isInProgress(): bool
    {
        return in_array($this->status, [
            self::STATUS_PENDING,
            self::STATUS_PREPARING,
            self::STATUS_SYNCING,
            self::STATUS_MIGRATING,
            self::STATUS_COMPLETING,
        ], true);
    }

    /**
     * Check if migration is completed
     */
    public function isCompleted(): bool
    {
        return $this->status === self::STATUS_COMPLETED;
    }

    /**
     * Check if migration failed
     */
    public function isFailed(): bool
    {
        return $this->status === self::STATUS_FAILED;
    }

    /**
     * Get migration duration in seconds
     */
    public function getDurationSeconds(): ?int
    {
        if (!$this->started_at) {
            return null;
        }

        $end = $this->completed_at ?? now();
        return $end->diffInSeconds($this->started_at);
    }

    /**
     * Get formatted duration
     */
    public function getFormattedDuration(): ?string
    {
        $duration = $this->getDurationSeconds();

        if ($duration === null) {
            return null;
        }

        $hours = floor($duration / 3600);
        $minutes = floor(($duration % 3600) / 60);
        $seconds = $duration % 60;

        if ($hours > 0) {
            return sprintf('%dh %dm %ds', $hours, $minutes, $seconds);
        }

        if ($minutes > 0) {
            return sprintf('%dm %ds', $minutes, $seconds);
        }

        return sprintf('%ds', $seconds);
    }

    /**
     * Get transfer rate in MB/s
     */
    public function getTransferRate(): ?float
    {
        if (!$this->transferred_mb || !$this->getDurationSeconds()) {
            return null;
        }

        return round($this->transferred_mb / $this->getDurationSeconds(), 2);
    }

    /**
     * Get formatted transfer rate
     */
    public function getFormattedTransferRate(): ?string
    {
        $rate = $this->getTransferRate();

        if ($rate === null) {
            return null;
        }

        if ($rate >= 1024) {
            return sprintf('%.2f GB/s', $rate / 1024);
        }

        return sprintf('%.2f MB/s', $rate);
    }

    /**
     * Get progress percentage
     */
    public function getProgressPercentage(): int
    {
        return min(100, max(0, $this->progress));
    }

    /**
     * Get formatted estimated time remaining
     */
    public function getFormattedEstimatedTime(): ?string
    {
        if (!$this->estimated_seconds) {
            return null;
        }

        $minutes = floor($this->estimated_seconds / 60);
        $seconds = $this->estimated_seconds % 60;

        if ($minutes > 60) {
            $hours = floor($minutes / 60);
            $minutes = $minutes % 60;
            return sprintf('%dh %dm', $hours, $minutes);
        }

        if ($minutes > 0) {
            return sprintf('%dm %ds', $minutes, $seconds);
        }

        return sprintf('%ds', $seconds);
    }
}
