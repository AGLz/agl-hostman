<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class AlertRule extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'name',
        'description',
        'rule_type',
        'conditions',
        'actions',
        'enabled',
        'cooldown_minutes',
        'last_triggered_at',
        'trigger_count',
    ];

    protected $casts = [
        'conditions' => 'array',
        'actions' => 'array',
        'enabled' => 'boolean',
        'cooldown_minutes' => 'integer',
        'trigger_count' => 'integer',
        'last_triggered_at' => 'datetime',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    /**
     * Scope: Enabled rules only
     */
    public function scopeEnabled(Builder $query): void
    {
        $query->where('enabled', true);
    }

    /**
     * Scope: By rule type
     */
    public function scopeByType(Builder $query, string $type): void
    {
        $query->where('rule_type', $type);
    }

    /**
     * Scope: Not in cooldown
     */
    public function scopeNotInCooldown(Builder $query): void
    {
        $query->where(function ($q) {
            $q->whereNull('last_triggered_at')
                ->orWhereRaw('last_triggered_at < NOW() - INTERVAL cooldown_minutes MINUTE');
        });
    }

    /**
     * Check if rule is in cooldown period
     */
    public function isInCooldown(): bool
    {
        if (! $this->last_triggered_at) {
            return false;
        }

        $cooldownEndsAt = $this->last_triggered_at->addMinutes($this->cooldown_minutes);

        return now()->isBefore($cooldownEndsAt);
    }

    /**
     * Get time remaining in cooldown (in seconds)
     */
    public function getCooldownRemainingAttribute(): ?int
    {
        if (! $this->isInCooldown()) {
            return null;
        }

        $cooldownEndsAt = $this->last_triggered_at->addMinutes($this->cooldown_minutes);

        return max(0, now()->diffInSeconds($cooldownEndsAt, false));
    }

    /**
     * Mark rule as triggered
     */
    public function markTriggered(): bool
    {
        return $this->update([
            'last_triggered_at' => now(),
            'trigger_count' => $this->trigger_count + 1,
        ]);
    }

    /**
     * Reset trigger statistics
     */
    public function resetTriggers(): bool
    {
        return $this->update([
            'last_triggered_at' => null,
            'trigger_count' => 0,
        ]);
    }

    /**
     * Enable the rule
     */
    public function enable(): bool
    {
        return $this->update(['enabled' => true]);
    }

    /**
     * Disable the rule
     */
    public function disable(): bool
    {
        return $this->update(['enabled' => false]);
    }

    /**
     * Validate rule conditions structure
     */
    public function validateConditions(): bool
    {
        if (! is_array($this->conditions)) {
            return false;
        }

        return match ($this->rule_type) {
            'threshold' => $this->validateThresholdConditions(),
            'pattern' => $this->validatePatternConditions(),
            'anomaly' => $this->validateAnomalyConditions(),
            default => false,
        };
    }

    /**
     * Validate threshold rule conditions
     */
    protected function validateThresholdConditions(): bool
    {
        $required = ['metric', 'operator', 'value', 'duration_minutes'];
        foreach ($required as $field) {
            if (! isset($this->conditions[$field])) {
                return false;
            }
        }

        $validOperators = ['>', '>=', '<', '<=', '==', '!='];

        return in_array($this->conditions['operator'], $validOperators);
    }

    /**
     * Validate pattern rule conditions
     */
    protected function validatePatternConditions(): bool
    {
        return isset($this->conditions['pattern']) &&
               isset($this->conditions['source']);
    }

    /**
     * Validate anomaly rule conditions
     */
    protected function validateAnomalyConditions(): bool
    {
        return isset($this->conditions['metric']) &&
               isset($this->conditions['deviation_threshold']);
    }
}
