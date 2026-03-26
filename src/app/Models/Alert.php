<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\MorphTo;

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
        // For polymorphic relationship
        'resource_type',
        'resource_id',
        'alert_type',
        'is_resolved',
        'resolution_notes',
        'auto_resolve_after_hours',
    ];

    protected $casts = [
        'metadata' => 'array',
        'severity' => 'integer',
        'acknowledged_at' => 'datetime',
        'resolved_at' => 'datetime',
        'muted_until' => 'datetime',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
        'is_resolved' => 'boolean',
    ];

    /**
     * Get the parent resource (polymorphic)
     */
    public function resource(): MorphTo
    {
        return $this->morphTo();
    }

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
     * Scope: Unresolved alerts
     */
    public function scopeUnresolved(Builder $query): void
    {
        $query->where('status', '!=', 'resolved');
    }

    /**
     * Scope: High severity alerts
     */
    public function scopeHigh(Builder $query): void
    {
        $query->where('severity', '>=', 70)->where('severity', '<', 90);
    }

    /**
     * Scope: Medium severity alerts
     */
    public function scopeMedium(Builder $query): void
    {
        $query->where('severity', '>=', 40)->where('severity', '<', 70);
    }

    /**
     * Scope: Low severity alerts
     */
    public function scopeLow(Builder $query): void
    {
        $query->where('severity', '<', 40);
    }

    /**
     * Scope: By alert type
     */
    public function scopeByType(Builder $query, string $type): void
    {
        $query->where('alert_type', $type);
    }

    /**
     * Scope: By severity level
     */
    public function scopeBySeverity(Builder $query, string $severity): void
    {
        $query->where('severity', $severity);
    }

    /**
     * Scope: Critical alerts (severity >= 90)
     */
    public function scopeCritical(Builder $query): void
    {
        $query->where('severity', 'critical');
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
     * Scope: By resource (polymorphic)
     */
    public function scopeByResource(Builder $query, string $resourceType, string $resourceId): void
    {
        $query->where('resource_type', $resourceType)
            ->where('resource_id', $resourceId);
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
    public function resolve(string $resolutionNotes = ''): bool
    {
        return $this->update([
            'status' => 'resolved',
            'is_resolved' => true,
            'resolution_notes' => $resolutionNotes,
            'resolved_by' => auth()->id(),
            'resolved_at' => now(),
        ]);
    }

    /**
     * Reopen a resolved alert
     */
    public function reopen(): bool
    {
        return $this->update([
            'status' => 'active',
            'is_resolved' => false,
            'resolved_at' => null,
            'resolution_notes' => null,
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
     * Check if alert should auto-resolve based on TTL
     */
    public function shouldAutoResolve(): bool
    {
        if (! $this->auto_resolve_after_hours) {
            return false;
        }

        return $this->created_at->lt(now()->subHours($this->auto_resolve_after_hours));
    }

    /**
     * Get alert priority for sorting
     */
    public function getPriorityAttribute(): int
    {
        if ($this->is_resolved) {
            return 0;
        }

        return match ($this->severity) {
            'critical' => 100,
            'high' => 80,
            'medium' => 60,
            'low' => 40,
            default => 20,
        };
    }

    /**
     * Get color for alert type
     */
    public function getColorAttribute(): string
    {
        return match ($this->type) {
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
        return match ($this->source) {
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
        if (! in_array($this->type, ['critical', 'warning'])) {
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
