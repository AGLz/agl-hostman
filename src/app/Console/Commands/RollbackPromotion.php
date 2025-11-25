<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Services\Deployment\PromotionWorkflowService;
use App\Models\Promotion;
use Illuminate\Console\Command;

class RollbackPromotion extends Command
{
    protected $signature = 'deployment:rollback {promotionId : Promotion ID to rollback}';
    protected $description = 'Rollback a failed promotion';

    public function __construct(
        private readonly PromotionWorkflowService $workflowService
    ) {
        parent::__construct();
    }

    public function handle(): int
    {
        $promotionId = $this->argument('promotionId');

        try {
            $promotion = Promotion::findOrFail($promotionId);

            $this->warn("🔄 Rolling back promotion: {$promotion->id}");
            $this->warn("Environment: {$promotion->targetEnvironment->type}");

            if (!$this->confirm('Are you sure you want to rollback?')) {
                $this->info('Rollback cancelled');
                return self::SUCCESS;
            }

            $result = $this->workflowService->rollbackPromotion($promotion);

            if ($result['success']) {
                $this->info("✅ Rollback completed");
                $this->info("Reason: {$result['reason']}");
            } else {
                $this->error("❌ Rollback failed: {$result['error']}");
                return self::FAILURE;
            }

            return self::SUCCESS;
        } catch (\Exception $e) {
            $this->error("❌ Rollback failed: {$e->getMessage()}");
            return self::FAILURE;
        }
    }
}
