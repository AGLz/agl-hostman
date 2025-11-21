<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Database\Eloquent\Casts\AsArrayObject;

/**
 * Container Backup Model
 *
 * Represents a Proxmox LXC container backup.
 *
 * @property int $id
 * @property int $container_id
 * @property string $storage
 * @property string $filename
 * @property int|null $size_mb
 * @property string $mode
 * @property string $compress
 * @property string $status
 * @property string|null $task_id
 * @property string|null $notes
 * @property array $metadata
 * @property \Illuminate\Support\Carbon|null $completed_at
 * @property \Illuminate\Support\Carbon|null $created_at
 * @property \Illuminate\Support\Carbon|null $updated_at
 * @property \Illuminate\Support\Carbon|null $deleted_at
 *
 * @property-read LxcContainer $container
 */
class ContainerBackup extends Model
{
    use HasFactory, SoftDeletes;

    protected $table = 'container_backups';

    /**
     * The attributes that are mass assignable.
     *
     * @var array<int, string>
     */
    protected $fillable = [
        'container_id',
        'storage',
        'filename',
        'size_mb',
        'mode',
        'compress',
        'status',
        'task_id',
        'notes',
        'metadata',
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
            'size_mb' => 'integer',
            'metadata' => AsArrayObject::class,
            'completed_at' => 'datetime',
            'created_at' => 'datetime',
            'updated_at' => 'datetime',
            'deleted_at' => 'datetime',
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
     * Scope: completed backups
     */
    public function scopeCompleted($query)
    {
        return $query->where('status', 'completed');
    }

    /**
     * Scope: failed backups
     */
    public function scopeFailed($query)
    {
        return $query->where('status', 'failed');
    }

    /**
     * Scope: in progress backups
     */
    public function scopeInProgress($query)
    {
        return $query->whereIn('status', ['pending', 'running']);
    }

    /**
     * Scope: recent backups (last 7 days)
     */
    public function scopeRecent($query)
    {
        return $query->where('created_at', '>=', now()->subDays(7));
    }

    /**
     * Scope: by storage
     */
    public function scopeOnStorage($query, string $storage)
    {
        return $query->where('storage', $storage);
    }

    /**
     * Check if backup is completed
     */
    public function isCompleted(): bool
    {
        return $this->status === 'completed';
    }

    /**
     * Check if backup is in progress
     */
    public function isInProgress(): bool
    {
        return in_array($this->status, ['pending', 'running'], true);
    }

    /**
     * Check if backup failed
     */
    public function isFailed(): bool
    {
        return $this->status === 'failed';
    }

    /**
     * Get backup duration in seconds
     */
    public function getDurationSeconds(): ?int
    {
        if (!$this->completed_at || !$this->created_at) {
            return null;
        }

        return $this->completed_at->diffInSeconds($this->created_at);
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
     * Get backup speed in MB/s
     */
    public function getBackupSpeed(): ?float
    {
        if (!$this->size_mb || !$this->getDurationSeconds()) {
            return null;
        }

        return round($this->size_mb / $this->getDurationSeconds(), 2);
    }

    /**
     * Get formatted size
     */
    public function getFormattedSize(): string
    {
        if (!$this->size_mb) {
            return 'Unknown';
        }

        if ($this->size_mb >= 1024) {
            return sprintf('%.2f GB', $this->size_mb / 1024);
        }

        return sprintf('%d MB', $this->size_mb);
    }

    /**
     * Get full storage path
     */
    public function getStoragePath(): string
    {
        return "{$this->storage}:backup/{$this->filename}";
    }

    /**
     * Get backup age in days
     */
    public function getAgeDays(): int
    {
        return $this->created_at->diffInDays(now());
    }

    /**
     * Check if backup is recent (< 7 days)
     */
    public function isRecent(): bool
    {
        return $this->getAgeDays() < 7;
    }

    /**
     * Check if backup is old (> 30 days)
     */
    public function isOld(): bool
    {
        return $this->getAgeDays() > 30;
    }
}
