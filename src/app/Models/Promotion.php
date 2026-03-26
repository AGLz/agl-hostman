<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Promotion Model
 *
 * Tracks environment promotions (QA → UAT → Production)
 * Maintains promotion history, approval workflow, and smoke test results
 */
class Promotion extends Model
{
    use HasFactory, HasUuids;

    /**
     * The attributes that are mass assignable.
     *
     * @var array<int, string>
     */
    protected $fillable = [
        'source_environment_id',
        'target_environment_id',
        'source_version',
        'target_version',
        'status',
        'requested_by',
        'approved_by',
        'requested_at',
        'approved_at',
        'completed_at',
        'rolled_back_at',
        'approval_notes',
        'smoke_test_results',
        'deployment_logs',
        'rollback_reason',
        'is_automatic',
        'requires_approvals',
        'approval_deadline',
    ];

    /**
     * The attributes that should be cast.
     *
     * @var array<string, string>
     */
    protected $casts = [
        'requested_at' => 'datetime',
        'approved_at' => 'datetime',
        'completed_at' => 'datetime',
        'rolled_back_at' => 'datetime',
        'approval_deadline' => 'datetime',
        'smoke_test_results' => 'array',
        'deployment_logs' => 'array',
        'approved_by' => 'array',
        'is_automatic' => 'boolean',
    ];

    /**
     * Possible promotion statuses
     */
    public const STATUS_PENDING = 'pending_approval';

    public const STATUS_APPROVED = 'approved';

    public const STATUS_REJECTED = 'rejected';

    public const STATUS_DEPLOYING = 'deploying';

    public const STATUS_COMPLETED = 'completed';

    public const STATUS_FAILED = 'failed';

    public const STATUS_ROLLED_BACK = 'rolled_back';

    public const STATUS_EXPIRED = 'expired';

    /**
     * Get source environment
     */
    public function sourceEnvironment(): BelongsTo
    {
        return $this->belongsTo(Environment::class, 'source_environment_id');
    }

    /**
     * Get target environment
     */
    public function targetEnvironment(): BelongsTo
    {
        return $this->belongsTo(Environment::class, 'target_environment_id');
    }

    /**
     * Get requester user
     */
    public function requester(): BelongsTo
    {
        return $this->belongsTo(User::class, 'requested_by');
    }

    /**
     * Get approver user
     */
    public function approver(): BelongsTo
    {
        return $this->belongsTo(User::class, 'approved_by');
    }

    /**
     * Check if promotion is pending approval
     */
    public function isPending(): bool
    {
        return $this->status === self::STATUS_PENDING;
    }

    /**
     * Check if promotion is approved
     */
    public function isApproved(): bool
    {
        return $this->status === self::STATUS_APPROVED;
    }

    /**
     * Check if promotion is completed
     */
    public function isCompleted(): bool
    {
        return $this->status === self::STATUS_COMPLETED;
    }

    /**
     * Check if promotion failed
     */
    public function isFailed(): bool
    {
        return $this->status === self::STATUS_FAILED;
    }

    /**
     * Approve promotion
     */
    public function approve(int $approverId, ?string $notes = null): bool
    {
        return $this->update([
            'status' => self::STATUS_APPROVED,
            'approved_by' => $approverId,
            'approved_at' => now(),
            'approval_notes' => $notes,
        ]);
    }

    /**
     * Reject promotion
     */
    public function reject(int $approverId, ?string $notes = null): bool
    {
        return $this->update([
            'status' => self::STATUS_REJECTED,
            'approved_by' => $approverId,
            'approved_at' => now(),
            'approval_notes' => $notes,
        ]);
    }

    /**
     * Mark promotion as completed
     */
    public function complete(string $targetVersion, ?array $smokeTestResults = null): bool
    {
        return $this->update([
            'status' => self::STATUS_COMPLETED,
            'target_version' => $targetVersion,
            'completed_at' => now(),
            'smoke_test_results' => $smokeTestResults,
        ]);
    }

    /**
     * Mark promotion as failed
     */
    public function markFailed(?array $smokeTestResults = null): bool
    {
        return $this->update([
            'status' => self::STATUS_FAILED,
            'completed_at' => now(),
            'smoke_test_results' => $smokeTestResults,
        ]);
    }

    /**
     * Get smoke test summary
     */
    public function getSmokeTestSummary(): ?array
    {
        if (! $this->smoke_test_results) {
            return null;
        }

        return [
            'total' => $this->smoke_test_results['total'] ?? 0,
            'passed' => $this->smoke_test_results['passed'] ?? 0,
            'failed' => $this->smoke_test_results['failed'] ?? 0,
            'duration' => $this->smoke_test_results['duration'] ?? 0,
            'success_rate' => $this->smoke_test_results['success_rate'] ?? 0,
        ];
    }

    /**
     * Get promotion duration in seconds
     */
    public function getDuration(): ?int
    {
        if (! $this->requested_at || ! $this->completed_at) {
            return null;
        }

        return $this->completed_at->diffInSeconds($this->requested_at);
    }

    /**
     * Scope: Get pending promotions
     */
    public function scopePending($query)
    {
        return $query->where('status', self::STATUS_PENDING);
    }

    /**
     * Scope: Get approved promotions
     */
    public function scopeApproved($query)
    {
        return $query->where('status', self::STATUS_APPROVED);
    }

    /**
     * Scope: Get completed promotions
     */
    public function scopeCompleted($query)
    {
        return $query->where('status', self::STATUS_COMPLETED);
    }

    /**
     * Scope: Get failed promotions
     */
    public function scopeFailed($query)
    {
        return $query->where('status', self::STATUS_FAILED);
    }

    /**
     * Scope: Get promotions for specific environments
     */
    public function scopeForEnvironments($query, string $sourceType, string $targetType)
    {
        return $query->whereHas('sourceEnvironment', function ($q) use ($sourceType) {
            $q->where('type', $sourceType);
        })->whereHas('targetEnvironment', function ($q) use ($targetType) {
            $q->where('type', $targetType);
        });
    }

    /**
     * Get production approvals
     */
    public function approvals()
    {
        return $this->hasMany(ProductionApproval::class);
    }

    /**
     * Check if approved by user
     */
    public function isApprovedBy(User $user): bool
    {
        return in_array($user->id, $this->approved_by ?? []);
    }

    /**
     * Get remaining approvals needed
     */
    public function getRemainingApprovals(): int
    {
        return max(0, $this->requires_approvals - count($this->approved_by ?? []));
    }

    /**
     * Scope: Get pending approval promotions
     */
    public function scopePendingApproval($query)
    {
        return $query->where('status', self::STATUS_PENDING);
    }

    /**
     * Scope: Get ready for deployment promotions
     */
    public function scopeReadyForDeployment($query)
    {
        return $query->where('status', self::STATUS_APPROVED);
    }
}
