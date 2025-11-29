<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class NotificationHistory extends Model
{
    use HasFactory;

    protected $table = 'notification_history';

    protected $fillable = [
        'notification_channel_id',
        'channel_type',
        'notification_type',
        'source_id',
        'payload',
        'status',
        'response',
        'attempts',
        'sent_at',
        'failed_at',
        'acknowledged_by',
        'acknowledged_at',
    ];

    protected $casts = [
        'payload' => 'array',
        'response' => 'array',
        'attempts' => 'integer',
        'sent_at' => 'datetime',
        'failed_at' => 'datetime',
        'acknowledged_at' => 'datetime',
    ];

    /**
     * Get the notification channel
     */
    public function channel()
    {
        return $this->belongsTo(NotificationChannel::class, 'notification_channel_id');
    }

    /**
     * Get the user who acknowledged
     */
    public function acknowledgedBy()
    {
        return $this->belongsTo(User::class, 'acknowledged_by');
    }

    /**
     * Scope to get sent notifications
     */
    public function scopeSent($query)
    {
        return $query->where('status', 'sent');
    }

    /**
     * Scope to get failed notifications
     */
    public function scopeFailed($query)
    {
        return $query->where('status', 'failed');
    }

    /**
     * Scope to get pending notifications
     */
    public function scopePending($query)
    {
        return $query->where('status', 'pending');
    }

    /**
     * Scope to filter by channel type
     */
    public function scopeByChannelType($query, string $type)
    {
        return $query->where('channel_type', $type);
    }

    /**
     * Scope to filter by notification type
     */
    public function scopeByNotificationType($query, string $type)
    {
        return $query->where('notification_type', $type);
    }

    /**
     * Scope to get recent notifications
     */
    public function scopeRecent($query, int $hours = 24)
    {
        return $query->where('created_at', '>=', now()->subHours($hours));
    }

    /**
     * Check if notification was sent successfully
     */
    public function wasSuccessful(): bool
    {
        return $this->status === 'sent';
    }

    /**
     * Check if notification failed
     */
    public function hasFailed(): bool
    {
        return $this->status === 'failed';
    }

    /**
     * Check if notification is pending
     */
    public function isPending(): bool
    {
        return $this->status === 'pending';
    }

    /**
     * Check if notification was acknowledged
     */
    public function isAcknowledged(): bool
    {
        return $this->acknowledged_at !== null;
    }

    /**
     * Acknowledge notification
     */
    public function acknowledge(User $user): bool
    {
        return $this->update([
            'acknowledged_by' => $user->id,
            'acknowledged_at' => now(),
        ]);
    }

    /**
     * Get delivery time in seconds
     */
    public function getDeliveryTime(): ?float
    {
        if (!$this->sent_at || !$this->created_at) {
            return null;
        }

        return $this->created_at->diffInSeconds($this->sent_at);
    }

    /**
     * Get error message from response
     */
    public function getErrorMessage(): ?string
    {
        if ($this->status !== 'failed') {
            return null;
        }

        $response = $this->response ?? [];

        return $response['error'] ?? $response['message'] ?? 'Unknown error';
    }
}
