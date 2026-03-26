<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class NotificationRule extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'name',
        'description',
        'conditions',
        'action',
        'config',
        'priority',
        'enabled',
        'last_triggered_at',
        'trigger_count',
    ];

    protected $casts = [
        'conditions' => 'array',
        'config' => 'array',
        'enabled' => 'boolean',
        'priority' => 'integer',
        'trigger_count' => 'integer',
        'last_triggered_at' => 'datetime',
    ];

    /**
     * Scope to get enabled rules
     */
    public function scopeEnabled($query)
    {
        return $query->where('enabled', true);
    }

    /**
     * Scope to get rules by action
     */
    public function scopeByAction($query, string $action)
    {
        return $query->where('action', $action);
    }

    /**
     * Scope to order by priority
     */
    public function scopeByPriority($query)
    {
        return $query->orderBy('priority', 'desc');
    }

    /**
     * Check if rule is for routing
     */
    public function isRoute(): bool
    {
        return $this->action === 'route';
    }

    /**
     * Check if rule is for suppression
     */
    public function isSuppress(): bool
    {
        return $this->action === 'suppress';
    }

    /**
     * Check if rule is for escalation
     */
    public function isEscalate(): bool
    {
        return $this->action === 'escalate';
    }

    /**
     * Check if rule is for grouping
     */
    public function isGroup(): bool
    {
        return $this->action === 'group';
    }

    /**
     * Record that rule was triggered
     */
    public function recordTrigger(): void
    {
        $this->increment('trigger_count');
        $this->update(['last_triggered_at' => now()]);
    }

    /**
     * Get human-readable description of conditions
     */
    public function getConditionsDescription(): string
    {
        $conditions = $this->conditions ?? [];
        $parts = [];

        if (isset($conditions['notification_type'])) {
            $parts[] = "Type: {$conditions['notification_type']}";
        }

        if (isset($conditions['severity'])) {
            $severity = is_array($conditions['severity'])
                ? implode(', ', $conditions['severity'])
                : $conditions['severity'];
            $parts[] = "Severity: {$severity}";
        }

        if (isset($conditions['source'])) {
            $source = is_array($conditions['source'])
                ? implode(', ', $conditions['source'])
                : $conditions['source'];
            $parts[] = "Source: {$source}";
        }

        if (isset($conditions['environment'])) {
            $env = is_array($conditions['environment'])
                ? implode(', ', $conditions['environment'])
                : $conditions['environment'];
            $parts[] = "Environment: {$env}";
        }

        if (isset($conditions['time_window'])) {
            $window = $conditions['time_window'];
            if (isset($window['days'])) {
                $parts[] = 'Days: '.implode(', ', $window['days']);
            }
            if (isset($window['start_time']) && isset($window['end_time'])) {
                $parts[] = "Time: {$window['start_time']} - {$window['end_time']}";
            }
        }

        return ! empty($parts) ? implode(' | ', $parts) : 'No conditions';
    }

    /**
     * Get human-readable description of action
     */
    public function getActionDescription(): string
    {
        $config = $this->config ?? [];

        return match ($this->action) {
            'route' => 'Route to: '.implode(', ', $config['channels'] ?? ['default']),
            'suppress' => 'Suppress notification',
            'escalate' => 'Escalate to: '.implode(', ', $config['channels'] ?? ['all']),
            'group' => 'Group for '.($config['window'] ?? 300).' seconds',
            default => ucfirst($this->action)
        };
    }
}
