<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Story extends Model
{
    use HasFactory;

    protected $fillable = [
        'title',
        'description',
        'acceptance_criteria',
        'user_role',
        'story_points',
        'priority',
        'status',
        'epic',
        'sprint_id',
        'created_by',
        'business_value',
        'complexity',
        'tags',
        'attachments',
        'started_at',
        'completed_at',
    ];

    protected $casts = [
        'acceptance_criteria' => 'array',
        'tags' => 'array',
        'attachments' => 'array',
        'started_at' => 'datetime',
        'completed_at' => 'datetime',
        'story_points' => 'integer',
        'business_value' => 'integer',
        'complexity' => 'integer',
    ];

    /**
     * Get the sprint this story belongs to
     */
    public function sprint(): BelongsTo
    {
        return $this->belongsTo(Sprint::class);
    }

    /**
     * Get the user who created this story
     */
    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    /**
     * Get all tasks associated with this story
     */
    public function tasks(): HasMany
    {
        return $this->hasMany(Task::class);
    }

    /**
     * Get all bugs associated with this story
     */
    public function bugs(): HasMany
    {
        return $this->hasMany(Bug::class);
    }

    /**
     * Scope for backlog stories
     */
    public function scopeBacklog($query)
    {
        return $query->where('status', 'backlog')
            ->whereNull('sprint_id');
    }

    /**
     * Scope for stories in current sprint
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
     * Calculate the total story points of associated tasks
     */
    public function getTaskPointsAttribute(): int
    {
        return $this->tasks()->sum('story_points') ?? 0;
    }

    /**
     * Get completed tasks count
     */
    public function getCompletedTasksCountAttribute(): int
    {
        return $this->tasks()->where('status', 'done')->count();
    }

    /**
     * Check if story is completed (all tasks done)
     */
    public function isCompleted(): bool
    {
        if ($this->tasks()->count() === 0) {
            return $this->status === 'done';
        }

        return $this->tasks()->where('status', '!=', 'done')->count() === 0;
    }

    /**
     * Move story to a different status
     */
    public function moveToStatus(string $status): self
    {
        $this->status = $status;

        if ($status === 'in_progress' && ! $this->started_at) {
            $this->started_at = now();
        }

        if ($status === 'done' && ! $this->completed_at) {
            $this->completed_at = now();
        }

        $this->save();

        return $this;
    }

    /**
     * Calculate priority score based on business value and complexity
     */
    public function getPriorityScoreAttribute(): float
    {
        if ($this->complexity === 0) {
            return $this->business_value * 2;
        }

        return round(($this->business_value / $this->complexity) * 10, 2);
    }

    /**
     * Add tags to the story
     */
    public function addTags(array $tags): self
    {
        $currentTags = $this->tags ?? [];
        $this->tags = array_unique(array_merge($currentTags, $tags));
        $this->save();

        return $this;
    }
}
