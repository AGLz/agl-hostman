<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class NotificationChannel extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'name',
        'type',
        'description',
        'config',
        'enabled',
        'priority',
        'metadata',
    ];

    protected $casts = [
        'config' => 'array',
        'enabled' => 'boolean',
        'metadata' => 'array',
        'priority' => 'integer',
    ];

    protected $hidden = [
        'config', // Hide sensitive configuration data by default
    ];

    /**
     * Get notification history for this channel
     */
    public function history()
    {
        return $this->hasMany(NotificationHistory::class);
    }

    /**
     * Scope to get enabled channels
     */
    public function scopeEnabled($query)
    {
        return $query->where('enabled', true);
    }

    /**
     * Scope to get channels by type
     */
    public function scopeOfType($query, string $type)
    {
        return $query->where('type', $type);
    }

    /**
     * Scope to order by priority
     */
    public function scopeByPriority($query)
    {
        return $query->orderBy('priority', 'desc');
    }

    /**
     * Check if channel is Slack
     */
    public function isSlack(): bool
    {
        return $this->type === 'slack';
    }

    /**
     * Check if channel is PagerDuty
     */
    public function isPagerDuty(): bool
    {
        return $this->type === 'pagerduty';
    }

    /**
     * Check if channel is Email
     */
    public function isEmail(): bool
    {
        return $this->type === 'email';
    }

    /**
     * Check if channel is Webhook
     */
    public function isWebhook(): bool
    {
        return $this->type === 'webhook';
    }

    /**
     * Get sanitized config (removing sensitive data)
     */
    public function getSanitizedConfig(): array
    {
        $config = $this->config ?? [];
        $sensitive = ['api_key', 'webhook_url', 'password', 'secret', 'token'];

        foreach ($sensitive as $key) {
            if (isset($config[$key])) {
                $config[$key] = '***REDACTED***';
            }
        }

        return $config;
    }

    /**
     * Get statistics for this channel
     */
    public function getStatistics(string $period = '24h'): array
    {
        $since = match($period) {
            '1h' => now()->subHour(),
            '24h' => now()->subDay(),
            '7d' => now()->subWeek(),
            '30d' => now()->subMonth(),
            default => now()->subDay()
        };

        $history = $this->history()->where('created_at', '>=', $since)->get();

        return [
            'total' => $history->count(),
            'sent' => $history->where('status', 'sent')->count(),
            'failed' => $history->where('status', 'failed')->count(),
            'pending' => $history->where('status', 'pending')->count(),
            'success_rate' => $history->count() > 0
                ? round(($history->where('status', 'sent')->count() / $history->count()) * 100, 2)
                : 0,
        ];
    }
}
