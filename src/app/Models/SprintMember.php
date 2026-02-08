<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SprintMember extends Model
{
    use HasFactory;

    protected $fillable = [
        'sprint_id',
        'user_id',
        'role',
        'capacity',
        'availability',
        'joined_at',
        'left_at',
    ];

    protected $casts = [
        'capacity' => 'integer',
        'availability' => 'integer',
        'joined_at' => 'datetime',
        'left_at' => 'datetime',
    ];

    /**
     * Get the sprint
     */
    public function sprint(): BelongsTo
    {
        return $this->belongsTo(Sprint::class);
    }

    /**
     * Get the user
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Scope for active members
     */
    public function scopeActive($query)
    {
        return $query->whereNull('left_at');
    }

    /**
     * Scope for sprint roles
     */
    public function scopeWithRole($query, string $role)
    {
        return $query->where('role', $role);
    }

    /**
     * Get effective capacity (percentage of time available)
     */
    public function getEffectiveCapacityAttribute(): int
    {
        if ($this->capacity === null) {
            return $this->availability ?? 100;
        }

        return (int) round(($this->capacity / 100) * ($this->availability ?? 100));
    }

    /**
     * Check if member is currently active in sprint
     */
    public function isActive(): bool
    {
        return $this->left_at === null || $this->left_at->isFuture();
    }

    /**
     * Leave sprint
     */
    public function leaveSprint(): self
    {
        $this->left_at = now();
        $this->save();

        return $this;
    }

    /**
     * Get total story points assigned to this member in the sprint
     */
    public function getAssignedPointsAttribute(): int
    {
        return $this->sprint->tasks()
            ->where('assigned_to', $this->user_id)
            ->sum('story_points') ?? 0;
    }

    /**
     * Get completed story points by this member in the sprint
     */
    public function getCompletedPointsAttribute(): int
    {
        return $this->sprint->tasks()
            ->where('assigned_to', $this->user_id)
            ->where('status', 'done')
            ->sum('story_points') ?? 0;
    }
}
