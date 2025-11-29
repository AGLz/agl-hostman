<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Log;

class OnCallSchedule extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'start_time',
        'end_time',
        'rotation_type',
        'rotation_config',
        'is_override',
        'override_reason',
        'created_by',
    ];

    protected $casts = [
        'start_time' => 'datetime',
        'end_time' => 'datetime',
        'rotation_config' => 'array',
        'is_override' => 'boolean',
    ];

    /**
     * Get the user on call
     */
    public function user()
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Get the user who created this schedule
     */
    public function creator()
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    /**
     * Scope to get current on-call schedule
     */
    public function scopeCurrent($query)
    {
        return $query->where('start_time', '<=', now())
            ->where('end_time', '>=', now());
    }

    /**
     * Scope to get upcoming schedules
     */
    public function scopeUpcoming($query)
    {
        return $query->where('start_time', '>', now())
            ->orderBy('start_time');
    }

    /**
     * Scope to get past schedules
     */
    public function scopePast($query)
    {
        return $query->where('end_time', '<', now())
            ->orderBy('end_time', 'desc');
    }

    /**
     * Scope to get schedules for specific user
     */
    public function scopeForUser($query, int $userId)
    {
        return $query->where('user_id', $userId);
    }

    /**
     * Scope to get override schedules
     */
    public function scopeOverrides($query)
    {
        return $query->where('is_override', true);
    }

    /**
     * Check if schedule is active
     */
    public function isActive(): bool
    {
        $now = now();
        return $this->start_time <= $now && $this->end_time >= $now;
    }

    /**
     * Check if schedule is upcoming
     */
    public function isUpcoming(): bool
    {
        return $this->start_time > now();
    }

    /**
     * Check if schedule is in the past
     */
    public function isPast(): bool
    {
        return $this->end_time < now();
    }

    /**
     * Get duration in hours
     */
    public function getDurationHours(): float
    {
        return $this->start_time->diffInHours($this->end_time);
    }

    /**
     * Get current on-call user
     */
    public static function getCurrentOnCallUser(): ?User
    {
        $schedule = static::current()->first();

        return $schedule?->user;
    }

    /**
     * Get next on-call user
     */
    public static function getNextOnCallUser(): ?User
    {
        $schedule = static::upcoming()->first();

        return $schedule?->user;
    }

    /**
     * Create rotation schedule
     */
    public static function createRotation(User $user, string $rotationType = 'weekly', ?User $createdBy = null): self
    {
        $startTime = now();
        $endTime = match($rotationType) {
            'daily' => $startTime->copy()->addDay(),
            'weekly' => $startTime->copy()->addWeek(),
            default => $startTime->copy()->addWeek()
        };

        $schedule = static::create([
            'user_id' => $user->id,
            'start_time' => $startTime,
            'end_time' => $endTime,
            'rotation_type' => $rotationType,
            'created_by' => $createdBy?->id,
        ]);

        Log::info('On-call rotation created', [
            'schedule_id' => $schedule->id,
            'user_id' => $user->id,
            'rotation_type' => $rotationType,
        ]);

        return $schedule;
    }

    /**
     * Create manual override
     */
    public static function createOverride(
        User $user,
        \Carbon\Carbon $startTime,
        \Carbon\Carbon $endTime,
        string $reason,
        ?User $createdBy = null
    ): self {
        $schedule = static::create([
            'user_id' => $user->id,
            'start_time' => $startTime,
            'end_time' => $endTime,
            'rotation_type' => 'custom',
            'is_override' => true,
            'override_reason' => $reason,
            'created_by' => $createdBy?->id,
        ]);

        Log::info('On-call override created', [
            'schedule_id' => $schedule->id,
            'user_id' => $user->id,
            'reason' => $reason,
        ]);

        return $schedule;
    }
}
