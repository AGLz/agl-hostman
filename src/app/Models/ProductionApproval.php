<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ProductionApproval extends Model
{
    use HasFactory;

    protected $fillable = [
        'environment_id',
        'deployment_version',
        'approval_level',
        'approver_role',
        'approved_by',
        'approved_at',
        'approval_notes',
        'status',
        'expires_at',
    ];

    protected $casts = [
        'approved_at' => 'datetime',
        'expires_at' => 'datetime',
    ];

    /**
     * Get the environment that owns the approval.
     */
    public function environment(): BelongsTo
    {
        return $this->belongsTo(Environment::class);
    }

    /**
     * Get the user who approved.
     */
    public function approver(): BelongsTo
    {
        return $this->belongsTo(User::class, 'approved_by');
    }

    /**
     * Check if approval is expired.
     */
    public function isExpired(): bool
    {
        return $this->expires_at && $this->expires_at->isPast();
    }

    /**
     * Check if approval is still pending.
     */
    public function isPending(): bool
    {
        return $this->status === 'pending' && !$this->isExpired();
    }

    /**
     * Approve the deployment.
     */
    public function approve(User $user, ?string $notes = null): bool
    {
        if (!$this->isPending()) {
            return false;
        }

        $this->update([
            'status' => 'approved',
            'approved_by' => $user->id,
            'approved_at' => now(),
            'approval_notes' => $notes,
        ]);

        return true;
    }

    /**
     * Reject the deployment.
     */
    public function reject(User $user, string $reason): bool
    {
        if (!$this->isPending()) {
            return false;
        }

        $this->update([
            'status' => 'rejected',
            'approved_by' => $user->id,
            'approved_at' => now(),
            'approval_notes' => $reason,
        ]);

        return true;
    }

    /**
     * Mark as expired.
     */
    public function markExpired(): void
    {
        if ($this->isPending() && $this->isExpired()) {
            $this->update(['status' => 'expired']);
        }
    }
}
