<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Casts\AsArrayObject;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * Container Snapshot Model
 *
 * Represents a Proxmox LXC container snapshot.
 *
 * @property int $id
 * @property int $container_id
 * @property string $name
 * @property string|null $description
 * @property int|null $size_mb
 * @property string|null $parent_name
 * @property array $config
 * @property array $metadata
 * @property \Illuminate\Support\Carbon|null $created_at
 * @property \Illuminate\Support\Carbon|null $updated_at
 * @property \Illuminate\Support\Carbon|null $deleted_at
 * @property-read LxcContainer $container
 */
class ContainerSnapshot extends Model
{
    use HasFactory, SoftDeletes;

    protected $table = 'container_snapshots';

    /**
     * The attributes that are mass assignable.
     *
     * @var array<int, string>
     */
    protected $fillable = [
        'container_id',
        'name',
        'description',
        'size_mb',
        'parent_name',
        'config',
        'metadata',
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
            'config' => AsArrayObject::class,
            'metadata' => AsArrayObject::class,
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
     * Parent snapshot relationship
     */
    public function parent(): BelongsTo
    {
        return $this->belongsTo(ContainerSnapshot::class, 'parent_name', 'name');
    }

    /**
     * Scope: recent snapshots (last 7 days)
     */
    public function scopeRecent($query)
    {
        return $query->where('created_at', '>=', now()->subDays(7));
    }

    /**
     * Scope: old snapshots (> 30 days)
     */
    public function scopeOld($query)
    {
        return $query->where('created_at', '<=', now()->subDays(30));
    }

    /**
     * Scope: by name pattern
     */
    public function scopeNameLike($query, string $pattern)
    {
        return $query->where('name', 'like', "%{$pattern}%");
    }

    /**
     * Get snapshot age in days
     */
    public function getAgeDays(): int
    {
        return $this->created_at->diffInDays(now());
    }

    /**
     * Get formatted age
     */
    public function getFormattedAge(): string
    {
        $days = $this->getAgeDays();

        if ($days === 0) {
            $hours = $this->created_at->diffInHours(now());
            if ($hours === 0) {
                return $this->created_at->diffInMinutes(now()).' minutes ago';
            }

            return $hours.' hours ago';
        }

        if ($days === 1) {
            return 'Yesterday';
        }

        if ($days < 7) {
            return $days.' days ago';
        }

        if ($days < 30) {
            return floor($days / 7).' weeks ago';
        }

        return floor($days / 30).' months ago';
    }

    /**
     * Get formatted size
     */
    public function getFormattedSize(): string
    {
        if (! $this->size_mb) {
            return 'Unknown';
        }

        if ($this->size_mb >= 1024) {
            return sprintf('%.2f GB', $this->size_mb / 1024);
        }

        return sprintf('%d MB', $this->size_mb);
    }

    /**
     * Check if snapshot is recent (< 7 days)
     */
    public function isRecent(): bool
    {
        return $this->getAgeDays() < 7;
    }

    /**
     * Check if snapshot is old (> 30 days)
     */
    public function isOld(): bool
    {
        return $this->getAgeDays() > 30;
    }

    /**
     * Check if snapshot has parent
     */
    public function hasParent(): bool
    {
        return $this->parent_name !== null;
    }

    /**
     * Get snapshot chain depth
     */
    public function getChainDepth(): int
    {
        $depth = 0;
        $current = $this;

        while ($current->hasParent()) {
            $depth++;
            $current = $current->parent;

            // Prevent infinite loops
            if ($depth > 100) {
                break;
            }
        }

        return $depth;
    }
}
