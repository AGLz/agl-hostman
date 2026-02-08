<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Task extends Model
{
    use HasFactory;

    protected $fillable = [
        'title',
        'description',
        'status',
        'priority',
        'story_points',
        'sprint_id',
        'assigned_to',
        'created_by',
        'location_id',
        'epic',
        'tags',
        'attachments',
        'started_at',
        'completed_at',
    ];

    protected $casts = [
        'tags' => 'array',
        'attachments' => 'array',
        'started_at' => 'datetime',
        'completed_at' => 'datetime',
        'story_points' => 'integer',
    ];

    /**
     * Get the sprint this task belongs to
     */
    public function sprint(): BelongsTo
    {
        return $this->belongsTo(Sprint::class);
    }

    /**
     * Get the user assigned to this task
     */
    public function assignee(): BelongsTo
    {
        return $this->belongsTo(User::class, 'assigned_to');
    }

    /**
     * Get the user who created this task
     */
    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    /**
     * Get the physical location associated with this task
     */
    public function location(): BelongsTo
    {
        return $this->belongsTo(PhysicalLocation::class, 'location_id');
    }

    /**
     * Get the story this task belongs to
     */
    public function story(): BelongsTo
    {
        return $this->belongsTo(Story::class);
    }

    /**
     * Scope for backlog tasks
     */
    public function scopeBacklog($query)
    {
        return $query->where('status', 'backlog')
            ->whereNull('sprint_id');
    }

    /**
     * Scope for tasks in current sprint
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
     * Move task to a different status
     */
    public function moveToStatus(string $status): self
    {
        $this->status = $status;
        
        if ($status === 'in_progress' && !$this->started_at) {
            $this->started_at = now();
        }
        
        if ($status === 'done' && !$this->completed_at) {
            $this->completed_at = now();
        }
        
        $this->save();
        
        return $this;
    }

    /**
     * Assign task to a user
     */
    public function assignTo(User $user): self
    {
        $this->assigned_to = $user->id;
        $this->save();
        
        return $this;
    }

    /**
     * Add tags to the task
     */
    public function addTags(array $tags): self
    {
        $currentTags = $this->tags ?? [];
        $this->tags = array_unique(array_merge($currentTags, $tags));
        $this->save();
        
        return $this;
    }

    /**
     * Get task duration in hours
     */
    public function getDurationInHours(): ?float
    {
        if (!$this->started_at || !$this->completed_at) {
            return null;
        }
        
        return round($this->completed_at->diffInHours($this->started_at), 2);
    }

    /**
     * Check if task is overdue (for tasks with deadlines)
     */
    public function isOverdue(): bool
    {
        if ($this->status === 'done' || !$this->sprint) {
            return false;
        }
        
        return $this->sprint->end_date < now() && $this->status !== 'done';
    }
}