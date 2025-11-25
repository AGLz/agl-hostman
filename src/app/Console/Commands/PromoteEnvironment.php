<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Services\Deployment\PromotionWorkflowService;
use App\Services\Deployment\PromotionApprovalService;
use App\Models\Promotion;
use App\Models\User;
use Illuminate\Console\Command;

class PromoteEnvironment extends Command
{
    protected $signature = 'deployment:promote 
                            {source : Source environment (qa/uat)} 
                            {target : Target environment (uat/production)} 
                            {--version= : Version to promote}
                            {--requester= : Email of requester}';

    protected $description = 'Request environment promotion (qa→uat or uat→production)';

    public function __construct(
        private readonly PromotionWorkflowService $workflowService
    ) {
        parent::__construct();
    }

    public function handle(): int
    {
        $source = $this->argument('source');
        $target = $this->argument('target');
        $version = $this->option('version') ?? 'latest';
        $requester = $this->option('requester') ?? 'cli@agl.com';

        $this->info("Requesting promotion: {$source} → {$target} (v{$version})");

        try {
            $promotion = match("{$source}-{$target}") {
                'qa-uat' => $this->workflowService->promoteQAtoUAT($version, $requester),
                'uat-production' => $this->workflowService->promoteUATtoProduction($version, $requester),
                default => throw new \InvalidArgumentException('Invalid environment pair')
            };

            $this->info("✅ Promotion request created: {$promotion->id}");
            $this->info("Status: {$promotion->status}");
            $this->info("Requires approvals: {$promotion->requires_approvals}");

            return self::SUCCESS;
        } catch (\Exception $e) {
            $this->error("❌ Promotion failed: {$e->getMessage()}");
            return self::FAILURE;
        }
    }
}
