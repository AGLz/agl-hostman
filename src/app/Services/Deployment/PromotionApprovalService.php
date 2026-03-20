<?php

declare(strict_types=1);

namespace App\Services\Deployment;

use App\Events\PromotionApproved;
use App\Events\PromotionRejected;
use App\Models\ProductionApproval;
use App\Models\Promotion;
use App\Models\User;
use Illuminate\Support\Facades\Log;

/**
 * Promotion Approval Service
 *
 * Manages the approval workflow for environment promotions
 */
class PromotionApprovalService
{
    public function __construct() {}

    /**
     * Request approval for promotion
     *
     * @param  Promotion  $promotion  Promotion requiring approval
     * @param  array  $approvers  List of approver roles or user IDs
     * @param  int  $requiredCount  Number of approvals required
     */
    public function requestApproval(
        Promotion $promotion,
        array $approvers,
        int $requiredCount = 1
    ): void {
        Log::info('Requesting approval for promotion', [
            'promotion_id' => $promotion->id,
            'approvers' => $approvers,
            'required_count' => $requiredCount,
        ]);

        // 1. Get users with approver roles
        $approverUsers = User::role($approvers)->get();

        if ($approverUsers->isEmpty()) {
            throw new \RuntimeException('No users found with required approval roles');
        }

        // 2. Create approval records for each required approver
        foreach ($approverUsers as $approver) {
            ProductionApproval::create([
                'promotion_id' => $promotion->id,
                'approver_id' => $approver->id,
                'status' => 'pending',
                'requested_at' => now(),
                'expires_at' => now()->addHours(
                    config('deployment.promotion_approval_timeout_hours', 24)
                ),
            ]);
        }

        // 3. Send notification emails/Slack
        // Handled by NotificationService in event listener

        // 4. Set approval deadline
        $promotion->update([
            'approval_deadline' => now()->addHours(
                config('deployment.promotion_approval_timeout_hours', 24)
            ),
        ]);

        Log::info('Approval requests created', [
            'promotion_id' => $promotion->id,
            'approvers_count' => $approverUsers->count(),
        ]);
    }

    /**
     * Approve promotion
     *
     * @param  Promotion  $promotion  Promotion to approve
     * @param  User  $approver  User approving
     * @param  string|null  $notes  Optional approval notes
     */
    public function approve(
        Promotion $promotion,
        User $approver,
        ?string $notes = null
    ): ProductionApproval {
        Log::info('Processing promotion approval', [
            'promotion_id' => $promotion->id,
            'approver_id' => $approver->id,
        ]);

        // 1. Validate approver has correct role
        $approval = ProductionApproval::where('promotion_id', $promotion->id)
            ->where('approver_id', $approver->id)
            ->where('status', 'pending')
            ->firstOrFail();

        // 2. Check if already approved
        if ($approval->status === 'approved') {
            throw new \RuntimeException('Promotion already approved by this user');
        }

        // 3. Check if approval expired
        if ($approval->expires_at && $approval->expires_at->isPast()) {
            throw new \RuntimeException('Approval request has expired');
        }

        // 4. Record approval with timestamp
        $approval->update([
            'status' => 'approved',
            'approved_at' => now(),
            'notes' => $notes,
        ]);

        // 5. Update promotion's approved_by array
        $approvedBy = $promotion->approved_by ?? [];
        if (! in_array($approver->id, $approvedBy)) {
            $approvedBy[] = $approver->id;
            $promotion->update(['approved_by' => $approvedBy]);
        }

        event(new PromotionApproved($promotion, $approver));

        // 6. Check if all required approvals met
        if ($this->isFullyApproved($promotion)) {
            Log::info('All approvals complete, executing promotion', [
                'promotion_id' => $promotion->id,
            ]);

            // Trigger promotion execution
            $promotion->update([
                'status' => 'approved',
                'approved_at' => now(),
            ]);

            // Execute promotion asynchronously
            dispatch(function () use ($promotion): void {
                app(PromotionWorkflowService::class)->executePromotion($promotion);
            })->afterResponse();
        }

        Log::info('Promotion approved', [
            'promotion_id' => $promotion->id,
            'approver_id' => $approver->id,
            'remaining_approvals' => $promotion->getRemainingApprovals(),
        ]);

        return $approval;
    }

    /**
     * Reject promotion
     *
     * @param  Promotion  $promotion  Promotion to reject
     * @param  User  $approver  User rejecting
     * @param  string  $reason  Rejection reason
     */
    public function reject(
        Promotion $promotion,
        User $approver,
        string $reason
    ): void {
        Log::info('Processing promotion rejection', [
            'promotion_id' => $promotion->id,
            'approver_id' => $approver->id,
        ]);

        // 1. Validate approver authority
        $approval = ProductionApproval::where('promotion_id', $promotion->id)
            ->where('approver_id', $approver->id)
            ->firstOrFail();

        // 2. Record rejection with reason
        $approval->update([
            'status' => 'rejected',
            'approved_at' => now(),
            'notes' => $reason,
        ]);

        // 3. Cancel promotion
        $promotion->update([
            'status' => 'rejected',
            'approval_notes' => $reason,
            'approved_by' => [$approver->id],
            'approved_at' => now(),
        ]);

        event(new PromotionRejected($promotion, $approver, $reason));

        Log::info('Promotion rejected', [
            'promotion_id' => $promotion->id,
            'approver_id' => $approver->id,
            'reason' => $reason,
        ]);
    }

    /**
     * Check if all approvals are complete
     *
     * @param  Promotion  $promotion  Promotion to check
     * @return bool True if fully approved
     */
    public function isFullyApproved(Promotion $promotion): bool
    {
        $approvedCount = ProductionApproval::where('promotion_id', $promotion->id)
            ->where('status', 'approved')
            ->count();

        return $approvedCount >= $promotion->requires_approvals;
    }

    /**
     * Get pending approvals for a user
     *
     * @param  User  $approver  User to get pending approvals for
     * @return array List of promotions awaiting approval
     */
    public function getPendingApprovals(User $approver): array
    {
        $pendingApprovals = ProductionApproval::where('approver_id', $approver->id)
            ->where('status', 'pending')
            ->where('expires_at', '>', now())
            ->with(['promotion.sourceEnvironment', 'promotion.targetEnvironment'])
            ->get();

        return $pendingApprovals->map(function ($approval) {
            $promotion = $approval->promotion;

            return [
                'promotion_id' => $promotion->id,
                'approval_id' => $approval->id,
                'source_environment' => $promotion->sourceEnvironment->type,
                'target_environment' => $promotion->targetEnvironment->type,
                'version' => $promotion->source_version,
                'requested_by' => $promotion->requested_by,
                'requested_at' => $promotion->requested_at->toIso8601String(),
                'expires_at' => $approval->expires_at->toIso8601String(),
                'remaining_approvals' => $promotion->getRemainingApprovals(),
                'required_approvals' => $promotion->requires_approvals,
            ];
        })->toArray();
    }

    /**
     * Get approval status for a promotion
     *
     * @param  Promotion  $promotion  Promotion to check
     * @return array Approval status details
     */
    public function getApprovalStatus(Promotion $promotion): array
    {
        $approvals = ProductionApproval::where('promotion_id', $promotion->id)
            ->with('approver')
            ->get();

        return [
            'promotion_id' => $promotion->id,
            'status' => $promotion->status,
            'requires_approvals' => $promotion->requires_approvals,
            'approved_count' => $approvals->where('status', 'approved')->count(),
            'rejected_count' => $approvals->where('status', 'rejected')->count(),
            'pending_count' => $approvals->where('status', 'pending')->count(),
            'is_fully_approved' => $this->isFullyApproved($promotion),
            'approvals' => $approvals->map(function ($approval) {
                return [
                    'approver' => $approval->approver->name,
                    'approver_email' => $approval->approver->email,
                    'status' => $approval->status,
                    'approved_at' => $approval->approved_at?->toIso8601String(),
                    'notes' => $approval->notes,
                ];
            })->toArray(),
        ];
    }

    /**
     * Cancel expired approval requests
     *
     * @return int Number of expired approvals cancelled
     */
    public function cancelExpiredApprovals(): int
    {
        $expiredApprovals = ProductionApproval::where('status', 'pending')
            ->where('expires_at', '<', now())
            ->with('promotion')
            ->get();

        $count = 0;

        foreach ($expiredApprovals as $approval) {
            $approval->update([
                'status' => 'expired',
                'notes' => 'Approval request expired',
            ]);

            // Cancel promotion if not yet approved
            if ($approval->promotion->status === 'pending_approval') {
                $approval->promotion->update([
                    'status' => 'expired',
                    'approval_notes' => 'Approval deadline exceeded',
                ]);
            }

            $count++;
        }

        Log::info('Cancelled expired approvals', ['count' => $count]);

        return $count;
    }
}
