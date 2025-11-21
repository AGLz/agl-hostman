<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Builder;

class Alert extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'type',
        'title',
        'message',
        'source',
        'source_id',
        'severity',
        'status',
        'acknowledged_by',
        'acknowledged_at',
        'resolved_by',
        'resolved_at',
        'metadata',
        'muted_until',
    ];

    protected $casts = [
        'metadata' => 'array',
        'severity' => 'integer',
        'acknowledged_at' => 'datetime',
        'resolved_at' => 'datetime',
        'muted_until' => 'datetime',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    /**
     * Scope: Active alerts (not acknowledged or resolved)
     */
    public function scopeActive(Builder $query): void
    {
        $query->where('status', 'active')
            ->where(function ($q) {
                $q->whereNull('muted_until')
                  ->orWhere('muted_until', '<', now());
            });
    }

    /**
     * Scope: Acknowledged alerts
     */
    public function scopeAcknowledged(Builder $query): void
    {
        $query->where('status', 'acknowledged');
    }

    /**
     * Scope: Resolved alerts
     */
    public function scopeResolved(Builder $query): void
    {
        $query->where('status', 'resolved');
    }

    /**
     * Scope: By alert type
     */
    public function scopeByType(Builder $query, string $type): void
    {
        $query->where('type', $type);
    }

    /**
     * Scope: By severity level
     */
    public function scopeBySeverity(Builder $query, int $minSeverity): void
    {
        $query->where('severity', '>=', $minSeverity);
    }

    /**
     * Scope: Critical alerts (severity >= 90)
     */
    public function scopeCritical(Builder $query): void
    {
        $query->where('severity', '>=', 90)->where('type', 'critical');
    }

    /**
     * Scope: Warning alerts (severity 60-89)
     */
    public function scopeWarning(Builder $query): void
    {
        $query->where('severity', '>=', 60)
            ->where('severity', '<', 90)
            ->where('type', 'warning');
    }

    /**
     * Scope: Recent alerts (last N hours)
     */
    public function scopeRecent(Builder $query, int $hours = 24): void
    {
        $query->where('created_at', '>=', now()->subHours($hours));
    }

    /**
     * Scope: By source type
     */
    public function scopeBySource(Builder $query, string $source): void
    {
        $query->where('source', $source);
    }

    /**
     * Scope: Not muted
     */
    public function scopeNotMuted(Builder $query): void
    {
        $query->where(function ($q) {
            $q->whereNull('muted_until')
              ->orWhere('muted_until', '<', now());
        });
    }

    /**
     * Check if alert is currently muted
     */
    public function isMuted(): bool
    {
        return $this->muted_until && $this->muted_until->isFuture();
    }

    /**
     * Mark alert as acknowledged
     */
    public function acknowledge(string $userId): bool
    {
        return $this->update([
            'status' => 'acknowledged',
            'acknowledged_by' => $userId,
            'acknowledged_at' => now(),
        ]);
    }

    /**
     * Mark alert as resolved
     */
    public function resolve(string $userId): bool
    {
        return $this->update([
            'status' => 'resolved',
            'resolved_by' => $userId,
            'resolved_at' => now(),
        ]);
    }

    /**
     * Mute alert for specified minutes
     */
    public function mute(int $minutes): bool
    {
        return $this->update([
            'muted_until' => now()->addMinutes($minutes),
        ]);
    }

    /**
     * Get color for alert type
     */
    public function getColorAttribute(): string
    {
        return match($this->type) {
            'critical' => '#EF4444', // Red
            'warning' => '#F59E0B', // Yellow
            'info' => '#3B82F6', // Blue
            default => '#6B7280', // Gray
        };
    }

    /**
     * Get icon for alert source
     */
    public function getIconAttribute(): string
    {
        return match($this->source) {
            'server' => 'server',
            'container' => 'box',
            'network' => 'network',
            'storage' => 'hard-drive',
            'system' => 'alert-circle',
            default => 'info',
        };
    }

    /**
     * Check if browser notification should be sent
     */
    public function shouldNotify(): bool
    {
        // Only notify for critical and warning alerts
        if (!in_array($this->type, ['critical', 'warning'])) {
            return false;
        }

        // Don't notify if muted
        if ($this->isMuted()) {
            return false;
        }

        // Don't notify if not active
        if ($this->status !== 'active') {
            return false;
        }

        return true;
    }
}
