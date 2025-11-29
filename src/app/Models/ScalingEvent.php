<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ScalingEvent extends Model
{
    const UPDATED_AT = null; // No updated_at timestamp

    protected $fillable = [
        'action',
        'old_replicas',
        'new_replicas',
        'trigger',
        'metadata',
    ];

    protected $casts = [
        'metadata' => 'array',
        'created_at' => 'datetime',
    ];

    /**
     * Get recent scaling events
     */
    public static function recent(int $hours = 24)
    {
        return static::where('created_at', '>=', now()->subHours($hours))
            ->orderBy('created_at', 'desc')
            ->get();
    }

    /**
     * Get scaling statistics
     */
    public static function stats(int $days = 7): array
    {
        $events = static::where('created_at', '>=', now()->subDays($days))->get();

        return [
            'total_events' => $events->count(),
            'scale_up_count' => $events->where('action', 'scale_up')->count(),
            'scale_down_count' => $events->where('action', 'scale_down')->count(),
            'avg_replicas' => round($events->avg('new_replicas'), 2),
            'max_replicas' => $events->max('new_replicas'),
            'min_replicas' => $events->min('new_replicas'),
        ];
    }
}
