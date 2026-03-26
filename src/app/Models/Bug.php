<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\MorphToMany;

class Bug extends Model
{
    use HasFactory;

    protected $fillable = [
        'title',
        'description',
        'severity',
        'priority',
        'status',
        'reproduction_steps',
        'expected_behavior',
        'actual_behavior',
        'environment',
        'sprint_id',
        'story_id',
        'task_id',
        'reported_by',
        'assigned_to',
        'found_in_version',
        'resolved_in_version',
        'labels',
        'attachments',
        'reported_at',
        'resolved_at',
        'verified_at',
    ];

    protected $casts = [
        'reproduction_steps' => 'array',
        'labels' => 'array',
        'attachments' => 'array',
        'reported_at' => 'datetime',
        'resolved_at' => 'datetime',
        'verified_at' => 'datetime',
    ];

    /**
     * Get the sprint this bug belongs to
     */
    public function sprint(): BelongsTo
    {
        return $this->belongsTo(Sprint::class);
    }

    /**
     * Get the story this bug is related to
     */
    public function story(): BelongsTo
    {
        return $this->belongsTo(Story::class);
    }

    /**
     * Get the task this bug is related to
     */
    public function task(): BelongsTo
    {
        return $this->belongsTo(Task::class);
    }

    /**
     * Get the user who reported this bug
     */
    public function reporter(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reported_by');
    }

    /**
     * Get the user assigned to fix this bug
     */
    public function assignee(): BelongsTo
    {
        return $this->belongsTo(User::class, 'assigned_to');
    }

    /**
     * Get users watching this bug
     */
    public function watchers(): MorphToMany
    {
        return $this->morphToMany(User::class, 'watchable', 'watchables');
    }

    /**
     * Scope for critical bugs
     */
    public function scopeCritical($query)
    {
        return $query->whereIn('severity', ['critical', 'blocker'])
            ->whereNotIn('status', ['resolved', 'verified']);
    }

    /**
     * Scope for open bugs
     */
    public function scopeOpen($query)
    {
        return $query->whereNotIn('status', ['resolved', 'verified']);
    }

    /**
     * Scope for bugs in current sprint
     */
    public function scopeInCurrentSprint($query)
    {
        $activeSprint = Sprint::active();
        if ($activeSprint) {
            return $query->where('sprint_id', $activeSprint->id);
        }

        return $query->whereNull('sprint_id');
    }

    /**
     * Calculate bug age in days
     */
    public function getAgeInDaysAttribute(): int
    {
        return $this->reported_at ? now()->diffInDays($this->reported_at) : 0;
    }

    /**
     * Calculate resolution time in days
     */
    public function getResolutionTimeAttribute(): ?int
    {
        if (! $this->reported_at || ! $this->resolved_at) {
            return null;
        }

        return $this->resolved_at->diffInDays($this->reported_at);
    }

    /**
     * Move bug to a different status
     */
    public function moveToStatus(string $status, ?User $verifiedBy = null): self
    {
        $this->status = $status;

        if ($status === 'resolved' && ! $this->resolved_at) {
            $this->resolved_at = now();
        }

        if ($status === 'verified' && ! $this->verified_at) {
            $this->verified_at = now();
        }

        $this->save();

        return $this;
    }

    /**
     * Assign bug to a user
     */
    public function assignTo(User $user): self
    {
        $this->assigned_to = $user->id;
        $this->save();

        return $this;
    }

    /**
     * Check if bug is overdue
     */
    public function isOverdue(): bool
    {
        if ($this->status === 'verified' || $this->status === 'resolved') {
            return false;
        }

        // Critical bugs should be resolved within 24 hours
        if ($this->severity === 'critical' || $this->severity === 'blocker') {
            return $this->reported_at && $this->reported_at->diffInHours(now()) > 24;
        }

        // High priority bugs within 3 days
        if ($this->priority === 'high') {
            return $this->reported_at && $this->reported_at->diffInDays(now()) > 3;
        }

        return false;
    }

    /**
     * Add labels to the bug
     */
    public function addLabels(array $labels): self
    {
        $currentLabels = $this->labels ?? [];
        $this->labels = array_unique(array_merge($currentLabels, $labels));
        $this->save();

        return $this;
    }

    /**
     * Get severity level (numeric for comparison)
     */
    public function getSeverityLevelAttribute(): int
    {
        return match ($this->severity) {
            'blocker' => 5,
            'critical' => 4,
            'high' => 3,
            'medium' => 2,
            'low' => 1,
            'trivial' => 0,
            default => 1,
        };
    }
}
