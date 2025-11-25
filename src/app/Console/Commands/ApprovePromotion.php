<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Services\Deployment\PromotionApprovalService;
use App\Models\Promotion;
use App\Models\User;
use Illuminate\Console\Command;

class ApprovePromotion extends Command
{
    protected $signature = 'deployment:approve 
                            {promotionId : Promotion ID to approve}
                            {--approver= : Email of approver}
                            {--notes= : Approval notes}';

    protected $description = 'Approve a pending promotion';

    public function __construct(
        private readonly PromotionApprovalService $approvalService
    ) {
        parent::__construct();
    }

    public function handle(): int
    {
        $promotionId = $this->argument('promotionId');
        $approverEmail = $this->option('approver');
        $notes = $this->option('notes');

        if (!$approverEmail) {
            $this->error('❌ --approver option is required');
            return self::FAILURE;
        }

        try {
            $promotion = Promotion::findOrFail($promotionId);
            $approver = User::where('email', $approverEmail)->firstOrFail();

            $this->info("Approving promotion: {$promotion->id}");
            $this->info("From: {$promotion->sourceEnvironment->type} → {$promotion->targetEnvironment->type}");

            $approval = $this->approvalService->approve($promotion, $approver, $notes);

            $this->info("✅ Promotion approved by {$approver->name}");
            $this->info("Remaining approvals: {$promotion->fresh()->getRemainingApprovals()}");

            return self::SUCCESS;
        } catch (\Exception $e) {
            $this->error("❌ Approval failed: {$e->getMessage()}");
            return self::FAILURE;
        }
    }
}
