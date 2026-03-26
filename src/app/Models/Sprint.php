<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Sprint extends Model
{
    use HasFactory;

    protected $fillable = [
        'name',
        'goal',
        'start_date',
        'end_date',
        'status',
        'velocity',
        'created_by',
    ];

    protected $casts = [
        'start_date' => 'date',
        'end_date' => 'date',
        'velocity' => 'integer',
    ];

    /**
     * Get the user who created the sprint
     */
    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    /**
     * Get the tasks in this sprint
     */
    public function tasks(): HasMany
    {
        return $this->hasMany(Task::class);
    }

    /**
     * Get active sprint
     */
    public static function active()
    {
        return self::where('status', 'active')->first();
    }

    /**
     * Calculate sprint progress
     */
    public function getProgressAttribute(): float
    {
        $totalTasks = $this->tasks()->count();
        if ($totalTasks === 0) {
            return 0;
        }

        $completedTasks = $this->tasks()->where('status', 'done')->count();

        return round(($completedTasks / $totalTasks) * 100, 2);
    }

    /**
     * Calculate velocity based on completed story points
     */
    public function calculateVelocity(): int
    {
        return $this->tasks()
            ->where('status', 'done')
            ->sum('story_points');
    }

    /**
     * Get burndown chart data
     */
    public function getBurndownData(): array
    {
        $days = [];
        $startDate = $this->start_date;
        $endDate = $this->end_date;
        $totalPoints = $this->tasks()->sum('story_points');

        $currentDate = $startDate;
        while ($currentDate <= $endDate) {
            $completedPoints = $this->tasks()
                ->where('status', 'done')
                ->where('completed_at', '<=', $currentDate)
                ->sum('story_points');

            $days[] = [
                'date' => $currentDate->format('Y-m-d'),
                'ideal' => $totalPoints - ($totalPoints * $currentDate->diffInDays($startDate) / $endDate->diffInDays($startDate)),
                'actual' => $totalPoints - $completedPoints,
            ];

            $currentDate->addDay();
        }

        return $days;
    }
}
