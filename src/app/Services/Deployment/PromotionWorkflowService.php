<?php

declare(strict_types=1);

namespace App\Services\Deployment;

use App\Events\PromotionCompleted;
use App\Events\PromotionDeploying;
use App\Events\PromotionRequested;
use App\Events\RollbackInitiated;
use App\Models\Environment;
use App\Models\Promotion;
use App\Services\Notification\NotificationService;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * Promotion Workflow Service
 *
 * Manages automated promotion workflows between environments:
 * - dev → qa (automatic on develop branch push)
 * - qa → uat (1 approval required)
 * - uat → production (2 approvals required)
 */
class PromotionWorkflowService
{
    public function __construct(
        private readonly DeploymentWorkflowService $deploymentService,
        private readonly NotificationService $notificationService,
        private readonly PromotionApprovalService $approvalService
    ) {}

    /**
     * Auto-promote from dev to QA on develop branch push
     *
     * @param  array  $payload  GitHub webhook payload
     * @return array Promotion result with status and details
     */
    public function autoPromoteDevToQA(array $payload): array
    {
        Log::info('Auto-promotion dev→qa triggered', ['payload' => $payload]);

        try {
            // 1. Verify branch is develop
            $branch = $payload['ref'] ?? '';
            if ($branch !== 'refs/heads/develop') {
                return [
                    'success' => false,
                    'message' => 'Not develop branch',
                    'branch' => $branch,
                ];
            }

            // 2. Extract version from commit
            $commitSha = $payload['after'] ?? '';
            $version = substr($commitSha, 0, 7);

            // 3. Get environments
            $devEnv = Environment::where('type', 'dev')->firstOrFail();
            $qaEnv = Environment::where('type', 'qa')->firstOrFail();

            // 4. Create promotion record
            $promotion = Promotion::create([
                'source_environment_id' => $devEnv->id,
                'target_environment_id' => $qaEnv->id,
                'source_version' => $version,
                'target_version' => $version,
                'status' => 'deploying',
                'requested_by' => 'github-webhook',
                'approved_by' => ['system'], // Auto-approved
                'requested_at' => now(),
                'approved_at' => now(),
                'is_automatic' => true,
                'requires_approvals' => 0,
                'deployment_logs' => [],
            ]);

            event(new PromotionRequested($promotion));
            event(new PromotionDeploying($promotion));

            // 5. Deploy to QA environment
            $deploymentResult = $this->deploymentService->deployToEnvironment(
                environmentId: $qaEnv->id,
                version: $version,
                source: 'github',
                metadata: [
                    'promotion_id' => $promotion->id,
                    'commit' => $commitSha,
                    'author' => $payload['pusher']['name'] ?? 'unknown',
                ]
            );

            if (! $deploymentResult['success']) {
                // 6. Auto-rollback on deployment failure
                $this->rollbackPromotion($promotion);

                return [
                    'success' => false,
                    'message' => 'Deployment failed',
                    'promotion_id' => $promotion->id,
                    'error' => $deploymentResult['error'] ?? 'Unknown error',
                ];
            }

            // 7. Run integration tests
            $testResults = $this->deploymentService->runIntegrationTests($qaEnv->id);

            if (! $testResults['success']) {
                // Auto-rollback on test failure
                $this->rollbackPromotion($promotion);

                return [
                    'success' => false,
                    'message' => 'Integration tests failed',
                    'promotion_id' => $promotion->id,
                    'test_results' => $testResults,
                ];
            }

            // 8. Mark promotion complete
            $promotion->update([
                'status' => 'completed',
                'completed_at' => now(),
                'smoke_test_results' => $testResults,
            ]);

            event(new PromotionCompleted($promotion));

            // 9. Notify team
            $this->notificationService->notifyPromotionCompleted($promotion);

            Log::info('Auto-promotion dev→qa completed', [
                'promotion_id' => $promotion->id,
                'version' => $version,
            ]);

            return [
                'success' => true,
                'message' => 'Auto-promotion to QA completed',
                'promotion_id' => $promotion->id,
                'version' => $version,
                'test_results' => $testResults,
            ];

        } catch (\Exception $e) {
            Log::error('Auto-promotion dev→qa failed', [
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
            ]);

            return [
                'success' => false,
                'message' => 'Auto-promotion failed',
                'error' => $e->getMessage(),
            ];
        }
    }

    /**
     * Manual promotion from QA to UAT (requires 1 approval)
     *
     * @param  string  $version  Version to promote
     * @param  string  $requestedBy  User requesting promotion
     */
    public function promoteQAtoUAT(string $version, string $requestedBy): Promotion
    {
        Log::info('Promotion qa→uat requested', [
            'version' => $version,
            'requested_by' => $requestedBy,
        ]);

        // 1. Validate QA deployment is stable (> 24 hours uptime)
        $qaEnv = Environment::where('type', 'qa')->firstOrFail();
        $uatEnv = Environment::where('type', 'uat')->firstOrFail();

        $eligibility = $this->checkPromotionEligibility('qa', 'uat');
        if (! $eligibility['eligible']) {
            throw new \RuntimeException(
                'QA environment not eligible for promotion: '.
                implode(', ', $eligibility['reasons'])
            );
        }

        // 2. Create promotion request
        $promotion = Promotion::create([
            'source_environment_id' => $qaEnv->id,
            'target_environment_id' => $uatEnv->id,
            'source_version' => $version,
            'target_version' => $version,
            'status' => 'pending_approval',
            'requested_by' => $requestedBy,
            'requested_at' => now(),
            'is_automatic' => false,
            'requires_approvals' => 1,
            'deployment_logs' => [],
        ]);

        event(new PromotionRequested($promotion));

        // 3. Request approval (lead-developer or admin)
        $this->approvalService->requestApproval(
            promotion: $promotion,
            approvers: ['lead-developer', 'admin'],
            requiredCount: 1
        );

        // 4. Notify approvers
        $this->notificationService->notifyPromotionRequested($promotion);

        Log::info('Promotion qa→uat created, awaiting approval', [
            'promotion_id' => $promotion->id,
        ]);

        return $promotion;
    }

    /**
     * Manual promotion from UAT to Production (requires 2 approvals)
     *
     * @param  string  $version  Version to promote
     * @param  string  $requestedBy  User requesting promotion
     */
    public function promoteUATtoProduction(string $version, string $requestedBy): Promotion
    {
        Log::info('Promotion uat→production requested', [
            'version' => $version,
            'requested_by' => $requestedBy,
        ]);

        // 1. Validate UAT deployment (> 72 hours stable)
        $uatEnv = Environment::where('type', 'uat')->firstOrFail();
        $prodEnv = Environment::where('type', 'production')->firstOrFail();

        $eligibility = $this->checkPromotionEligibility('uat', 'production');
        if (! $eligibility['eligible']) {
            throw new \RuntimeException(
                'UAT environment not eligible for promotion: '.
                implode(', ', $eligibility['reasons'])
            );
        }

        // 2. Create promotion request
        $promotion = Promotion::create([
            'source_environment_id' => $uatEnv->id,
            'target_environment_id' => $prodEnv->id,
            'source_version' => $version,
            'target_version' => $version,
            'status' => 'pending_approval',
            'requested_by' => $requestedBy,
            'requested_at' => now(),
            'is_automatic' => false,
            'requires_approvals' => 2,
            'deployment_logs' => [],
        ]);

        event(new PromotionRequested($promotion));

        // 3. Require 2 approvals (lead-developer + admin)
        $this->approvalService->requestApproval(
            promotion: $promotion,
            approvers: ['lead-developer', 'admin'],
            requiredCount: 2
        );

        // 4. Notify approvers
        $this->notificationService->notifyPromotionRequested($promotion);

        Log::info('Promotion uat→production created, awaiting 2 approvals', [
            'promotion_id' => $promotion->id,
        ]);

        return $promotion;
    }

    /**
     * Check if environment is ready for promotion
     *
     * @param  string  $sourceEnv  Source environment type
     * @param  string  $targetEnv  Target environment type
     * @return array Eligibility check results
     */
    public function checkPromotionEligibility(string $sourceEnv, string $targetEnv): array
    {
        $reasons = [];
        $eligible = true;

        // Get latest deployment for source environment
        $sourceEnvironment = Environment::where('type', $sourceEnv)->firstOrFail();
        $latestDeployment = $sourceEnvironment->deployments()
            ->where('status', 'completed')
            ->latest()
            ->first();

        if (! $latestDeployment) {
            $reasons[] = "No completed deployment in {$sourceEnv}";
            $eligible = false;
        }

        // Check minimum uptime
        $minUptimeHours = match ($targetEnv) {
            'uat' => 24,      // QA → UAT requires 24h
            'production' => 72, // UAT → Prod requires 72h
            default => 0,
        };

        if ($latestDeployment && $minUptimeHours > 0) {
            $uptimeHours = $latestDeployment->completed_at->diffInHours(now());
            if ($uptimeHours < $minUptimeHours) {
                $reasons[] = "Insufficient uptime: {$uptimeHours}h < {$minUptimeHours}h required";
                $eligible = false;
            }
        }

        // Check for critical alerts
        $criticalAlerts = $sourceEnvironment->alerts()
            ->where('severity', 'critical')
            ->where('created_at', '>', now()->subHours(24))
            ->count();

        if ($criticalAlerts > 0) {
            $reasons[] = "{$criticalAlerts} critical alerts in last 24h";
            $eligible = false;
        }

        // Check for pending deployments
        $pendingDeployments = $sourceEnvironment->deployments()
            ->whereIn('status', ['pending', 'deploying'])
            ->count();

        if ($pendingDeployments > 0) {
            $reasons[] = "{$pendingDeployments} pending deployments";
            $eligible = false;
        }

        return [
            'eligible' => $eligible,
            'reasons' => $reasons,
            'checks' => [
                'has_deployment' => $latestDeployment !== null,
                'uptime_met' => $eligible || $minUptimeHours === 0,
                'no_critical_alerts' => $criticalAlerts === 0,
                'no_pending_deployments' => $pendingDeployments === 0,
            ],
        ];
    }

    /**
     * Execute promotion after all approvals
     *
     * @param  Promotion  $promotion  Promotion to execute
     * @return array Execution result
     */
    public function executePromotion(Promotion $promotion): array
    {
        Log::info('Executing promotion', ['promotion_id' => $promotion->id]);

        try {
            // 1. Lock environments
            DB::beginTransaction();

            $promotion->update(['status' => 'deploying']);
            event(new PromotionDeploying($promotion));

            // 2. Backup target environment
            $backupResult = $this->deploymentService->backupEnvironment(
                $promotion->target_environment_id
            );

            if (! $backupResult['success']) {
                throw new \RuntimeException('Environment backup failed');
            }

            // 3. Deploy to target
            $deploymentResult = $this->deploymentService->deployToEnvironment(
                environmentId: $promotion->target_environment_id,
                version: $promotion->source_version,
                source: 'promotion',
                metadata: [
                    'promotion_id' => $promotion->id,
                    'source_environment' => $promotion->sourceEnvironment->type,
                    'backup_id' => $backupResult['backup_id'],
                ]
            );

            if (! $deploymentResult['success']) {
                // Auto-rollback on deployment failure
                $this->rollbackPromotion($promotion);
                throw new \RuntimeException('Deployment failed: '.
                    ($deploymentResult['error'] ?? 'Unknown error'));
            }

            // 4. Run environment-specific tests
            $testResults = $this->deploymentService->runSmokeTests(
                $promotion->target_environment_id
            );

            if (! $testResults['success']) {
                // Auto-rollback on test failure
                $this->rollbackPromotion($promotion);
                throw new \RuntimeException('Smoke tests failed');
            }

            // 5. Update promotion status
            $promotion->update([
                'status' => 'completed',
                'completed_at' => now(),
                'smoke_test_results' => $testResults,
            ]);

            event(new PromotionCompleted($promotion));

            // 6. Unlock environments
            DB::commit();

            // 7. Send notifications
            $this->notificationService->notifyPromotionCompleted($promotion);

            Log::info('Promotion executed successfully', [
                'promotion_id' => $promotion->id,
            ]);

            return [
                'success' => true,
                'promotion_id' => $promotion->id,
                'deployment' => $deploymentResult,
                'tests' => $testResults,
            ];

        } catch (\Exception $e) {
            DB::rollBack();

            Log::error('Promotion execution failed', [
                'promotion_id' => $promotion->id,
                'error' => $e->getMessage(),
            ]);

            return [
                'success' => false,
                'promotion_id' => $promotion->id,
                'error' => $e->getMessage(),
            ];
        }
    }

    /**
     * Automatic rollback on promotion failure
     *
     * @param  Promotion  $promotion  Promotion to rollback
     * @return array Rollback result
     */
    public function rollbackPromotion(Promotion $promotion): array
    {
        Log::warning('Rolling back promotion', ['promotion_id' => $promotion->id]);

        try {
            event(new RollbackInitiated($promotion));

            // 1. Detect failure (tests, health checks, error rates)
            $failureReason = $this->detectFailureReason($promotion);

            // 2. Restore previous version
            $rollbackResult = $this->deploymentService->rollbackEnvironment(
                environmentId: $promotion->target_environment_id,
                targetVersion: $promotion->sourceEnvironment->current_version ?? 'previous'
            );

            if (! $rollbackResult['success']) {
                throw new \RuntimeException('Rollback failed: '.
                    ($rollbackResult['error'] ?? 'Unknown error'));
            }

            // 3. Update promotion status
            $promotion->update([
                'status' => 'rolled_back',
                'rolled_back_at' => now(),
                'rollback_reason' => $failureReason,
            ]);

            // 4. Send alert notifications
            $this->notificationService->notifyRollbackInitiated($promotion);

            // 5. Create incident record
            // TODO: Integrate with incident management system

            Log::info('Promotion rolled back successfully', [
                'promotion_id' => $promotion->id,
                'reason' => $failureReason,
            ]);

            return [
                'success' => true,
                'promotion_id' => $promotion->id,
                'reason' => $failureReason,
                'rollback' => $rollbackResult,
            ];

        } catch (\Exception $e) {
            Log::error('Rollback failed', [
                'promotion_id' => $promotion->id,
                'error' => $e->getMessage(),
            ]);

            return [
                'success' => false,
                'promotion_id' => $promotion->id,
                'error' => $e->getMessage(),
            ];
        }
    }

    /**
     * Detect failure reason for rollback
     *
     * @param  Promotion  $promotion  Promotion that failed
     * @return string Failure reason
     */
    private function detectFailureReason(Promotion $promotion): string
    {
        $reasons = [];

        // Check smoke test results
        if ($promotion->smoke_test_results) {
            $results = $promotion->smoke_test_results;
            if (isset($results['failed']) && $results['failed'] > 0) {
                $reasons[] = "{$results['failed']} smoke tests failed";
            }
        }

        // Check deployment logs
        if ($promotion->deployment_logs) {
            $errors = array_filter($promotion->deployment_logs, function ($log) {
                return isset($log['level']) && $log['level'] === 'error';
            });
            if (count($errors) > 0) {
                $reasons[] = count($errors).' deployment errors';
            }
        }

        return implode(', ', $reasons) ?: 'Unknown failure';
    }
}
