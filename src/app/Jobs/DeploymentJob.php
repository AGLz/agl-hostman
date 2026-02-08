<?php

namespace App\Jobs;

use App\Services\DeploymentWorkflowService;
use App\Services\PromotionWorkflowService;
use App\Services\DokployService;
use App\Models\ProductionDeployment;
use App\Models\Promotion;
use App\Models\DokployApplication;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Deployment Job
 *
 * Handles application deployments across environments.
 * Supports Dokploy deployments and production promotions.
 *
 * @package App\Jobs
 */
class DeploymentJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    /**
     * Job timeout (seconds) - deployments can vary greatly in time
     */
    public int $timeout = 1800;

    /**
     * Number of retry attempts
     */
    public int $tries = 1;

    /**
     * Deployment type: 'deploy', 'promote', 'rollback'
     */
    protected string $deploymentType;

    /**
     * Application or project identifier
     */
    protected string $applicationId;

    /**
     * Target environment
     */
    protected string $environment;

    /**
     * Version/commit/tag to deploy
     */
    protected ?string $version;

    /**
     * Deployment configuration
     */
    protected array $config;

    /**
     * User who initiated the deployment
     */
    protected ?int $userId;

    /**
     * Deployment tracking ID
     */
    protected ?string $deploymentId;

    /**
     * Create a new job instance.
     */
    public function __construct(
        string $deploymentType,
        string $applicationId,
        string $environment = 'production',
        ?string $version = null,
        array $config = [],
        ?int $userId = null
    ) {
        $this->deploymentType = $deploymentType;
        $this->applicationId = $applicationId;
        $this->environment = $environment;
        $this->version = $version;
        $this->config = $config;
        $this->userId = $userId;

        $this->deploymentId = 'deploy_' . now()->format('Ymd_His') . '_' . Str::random(8);

        // Deployments go on high-priority queue
        $this->onQueue('deployments');
    }

    /**
     * Execute the job.
     */
    public function handle(
        DeploymentWorkflowService $deploymentService,
        PromotionWorkflowService $promotionService,
        DokployService $dokployService
    ): void {
        $startTime = microtime(true);

        Log::info('Starting deployment job', [
            'deployment_id' => $this->deploymentId,
            'type' => $this->deploymentType,
            'application' => $this->applicationId,
            'environment' => $this->environment,
            'version' => $this->version,
        ]);

        // Create deployment record
        $deployment = $this->createDeploymentRecord();

        try {
            DB::beginTransaction();

            $result = match ($this->deploymentType) {
                'deploy' => $this->executeDeploy($deploymentService, $dokployService, $deployment),
                'promote' => $this->executePromote($promotionService, $deployment),
                'rollback' => $this->executeRollback($deploymentService, $deployment),
                default => throw new \Exception("Unknown deployment type: {$this->deploymentType}"),
            };

            $duration = round(microtime(true) - $startTime, 2);

            // Update deployment record
            $deployment->update([
                'status' => $result['success'] ? 'completed' : 'failed',
                'output' => json_encode($result),
                'duration' => $duration,
                'completed_at' => now(),
            ]);

            DB::commit();

            if ($result['success']) {
                Log::info('Deployment completed successfully', [
                    'deployment_id' => $this->deploymentId,
                    'duration' => $duration,
                ]);
            } else {
                Log::error('Deployment failed', [
                    'deployment_id' => $this->deploymentId,
                    'error' => $result['error'] ?? 'Unknown error',
                    'duration' => $duration,
                ]);
            }

        } catch (\Exception $e) {
            DB::rollBack();

            $deployment->update([
                'status' => 'failed',
                'error_message' => $e->getMessage(),
                'completed_at' => now(),
            ]);

            Log::error('Deployment job failed with exception', [
                'deployment_id' => $this->deploymentId,
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
            ]);

            throw $e;
        }
    }

    /**
     * Create deployment record
     */
    protected function createDeploymentRecord(): ProductionDeployment
    {
        return ProductionDeployment::create([
            'deployment_id' => $this->deploymentId,
            'application_id' => $this->applicationId,
            'environment' => $this->environment,
            'type' => $this->deploymentType,
            'version' => $this->version,
            'status' => 'pending',
            'config' => json_encode($this->config),
            'initiated_by' => $this->userId,
            'started_at' => now(),
        ]);
    }

    /**
     * Execute deployment
     */
    protected function executeDeploy(
        DeploymentWorkflowService $service,
        DokployService $dokployService,
        ProductionDeployment $deployment
    ): array {
        // Check if this is a Dokploy deployment
        $dokployApp = DokployApplication::find($this->applicationId);

        if ($dokployApp) {
            return $this->executeDokployDeploy($dokployService, $dokployApp, $deployment);
        }

        // Standard deployment workflow
        $result = $service->deploy($this->applicationId, [
            'environment' => $this->environment,
            'version' => $this->version,
            'config' => $this->config,
        ]);

        return $result;
    }

    /**
     * Execute Dokploy deployment
     */
    protected function executeDokployDeploy(
        DokployService $service,
        DokployApplication $app,
        ProductionDeployment $deployment
    ): array {
        $deployment->update(['current_step' => 'deploying_via_dokploy']);

        $result = $service->deployApplication($app->id, [
            'branch' => $this->version ?? $app->branch,
            'environment' => $this->environment,
        ]);

        return [
            'success' => $result['success'] ?? false,
            'output' => $result,
        ];
    }

    /**
     * Execute promotion
     */
    protected function executePromote(
        PromotionWorkflowService $service,
        ProductionDeployment $deployment
    ): array {
        $deployment->update(['current_step' => 'promoting']);

        // Get or create promotion record
        $promotion = Promotion::create([
            'deployment_id' => $deployment->id,
            'from_environment' => $this->config['from_environment'] ?? 'staging',
            'to_environment' => $this->environment,
            'version' => $this->version,
            'status' => 'in_progress',
        ]);

        $result = $service->promote($promotion->id, [
            'auto_approve' => $this->config['auto_approve'] ?? false,
            'skip_tests' => $this->config['skip_tests'] ?? false,
        ]);

        return [
            'success' => $result['success'] ?? false,
            'output' => $result,
        ];
    }

    /**
     * Execute rollback
     */
    protected function executeRollback(
        DeploymentWorkflowService $service,
        ProductionDeployment $deployment
    ): array {
        $deployment->update(['current_step' => 'rolling_back']);

        $result = $service->rollback($this->applicationId, [
            'environment' => $this->environment,
            'to_version' => $this->version,
        ]);

        return [
            'success' => $result['success'] ?? false,
            'output' => $result,
        ];
    }

    /**
     * Handle job failure.
     */
    public function failed(\Throwable $exception): void
    {
        Log::critical('Deployment job failed permanently', [
            'deployment_id' => $this->deploymentId,
            'type' => $this->deploymentType,
            'application' => $this->applicationId,
            'error' => $exception->getMessage(),
            'trace' => $exception->getTraceAsString(),
        ]);

        // Update deployment record if it exists
        if ($this->deploymentId) {
            ProductionDeployment::where('deployment_id', $this->deploymentId)
                ->update([
                    'status' => 'failed',
                    'error_message' => $exception->getMessage(),
                    'completed_at' => now(),
                ]);
        }
    }

    /**
     * Get the tags that should be assigned to the job.
     */
    public function tags(): array
    {
        return [
            'deployment',
            $this->deploymentType,
            $this->applicationId,
            $this->environment,
        ];
    }
}
