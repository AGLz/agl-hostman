<?php

declare(strict_types=1);

namespace App\Services\Deployment;

use App\Models\Environment;
use App\Models\DokployDeployment;
use App\Services\DokployService;
use App\DTOs\Dokploy\ApplicationDTO;
use App\DTOs\Dokploy\DomainDTO;
use App\DTOs\Dokploy\EnvironmentDTO;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Process;
use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Facades\Cache;
use Exception;

/**
 * Deployment Workflow Service
 *
 * Handles the complete deployment workflow:
 * - Pull from Git
 * - Build Docker image
 * - Push to Harbor
 * - Deploy to Dokploy
 * - Run tests
 * - Notify status
 */
class DeploymentWorkflowService
{
    private const MAX_WAIT_TIME = 300; // 5 minutes
    private const POLL_INTERVAL = 5; // 5 seconds

    public function __construct(
        private readonly DokployService $dokployService
    ) {}

    /**
     * Deploy to QA environment
     *
     * @param array $options Deployment options
     * @return DokployDeployment Deployment record
     * @throws Exception If deployment fails
     */
    public function deployToQA(array $options = []): DokployDeployment
    {
        try {
            // Get QA environment
            $environment = Environment::where('type', 'qa')->firstOrFail();

            Log::info('Starting QA deployment', [
                'environment_id' => $environment->id,
                'options' => $options,
            ]);

            // Create deployment record
            $deployment = DokployDeployment::create([
                'environment_id' => $environment->id,
                'status' => 'pending',
                'triggered_by' => $options['triggered_by'] ?? 'manual',
                'git_branch' => $environment->git_branch,
                'git_commit' => $options['git_commit'] ?? null,
                'started_at' => now(),
            ]);

            try {
                // Step 1: Build and push Docker image
                $imageTag = $this->buildAndPushImage($environment, $deployment);

                // Step 2: Deploy to Dokploy
                $this->deployToDokploy($environment, $imageTag, $deployment);

                // Step 3: Wait for deployment to complete
                $this->waitForDeployment($environment, $deployment);

                // Step 4: Run health checks
                $this->runHealthChecks($environment, $deployment);

                // Step 5: Run integration tests (if enabled)
                if ($environment->auto_test) {
                    $testResult = $this->runIntegrationTests($deployment->id);

                    if (!$testResult->success) {
                        throw new Exception('Integration tests failed');
                    }
                }

                // Step 6: Update deployment status
                $deployment->update([
                    'status' => 'success',
                    'completed_at' => now(),
                ]);

                // Update environment last deployed timestamp
                $environment->update([
                    'last_deployed_at' => now(),
                ]);

                // Step 7: Send success notification
                $this->notifyDeploymentStatus($deployment->id, 'success');

                Log::info('QA deployment successful', [
                    'deployment_id' => $deployment->id,
                    'image_tag' => $imageTag,
                ]);

                return $deployment;

            } catch (Exception $e) {
                // Mark deployment as failed
                $deployment->update([
                    'status' => 'failed',
                    'error_message' => $e->getMessage(),
                    'completed_at' => now(),
                ]);

                // Send failure notification
                $this->notifyDeploymentStatus($deployment->id, 'failed');

                // Rollback if configured
                if (config('deployment.rollback_on_failure', true)) {
                    Log::warning('Attempting automatic rollback', [
                        'deployment_id' => $deployment->id,
                    ]);
                    // TODO: Implement rollback logic
                }

                throw $e;
            }
        } catch (Exception $e) {
            Log::error('QA deployment failed', [
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
            ]);
            throw $e;
        }
    }

    /**
     * Build Docker image and push to Harbor
     *
     * @param Environment $environment
     * @param DokployDeployment $deployment
     * @return string Image tag
     */
    private function buildAndPushImage(Environment $environment, DokployDeployment $deployment): string
    {
        Log::info('Building Docker image', [
            'environment' => $environment->type,
        ]);

        // Generate image tag
        $gitCommit = $this->getGitCommit($environment->git_branch);
        $shortCommit = substr($gitCommit, 0, 7);
        $imageTag = "qa-{$shortCommit}";
        $fullImageName = config('harbor.registry') . "/{$environment->harbor_project}/agl-hostman:{$imageTag}";

        // Update deployment record
        $deployment->update([
            'docker_image' => $fullImageName,
            'git_commit' => $gitCommit,
        ]);

        // Build image
        $buildResult = Process::run([
            'docker',
            'build',
            '-t', $fullImageName,
            '-f', base_path('Dockerfile'),
            base_path(),
        ]);

        if (!$buildResult->successful()) {
            throw new Exception("Docker build failed: {$buildResult->errorOutput()}");
        }

        // Push to Harbor
        $pushResult = Process::run([
            'docker',
            'push',
            $fullImageName,
        ]);

        if (!$pushResult->successful()) {
            throw new Exception("Docker push failed: {$pushResult->errorOutput()}");
        }

        Log::info('Docker image built and pushed', [
            'image' => $fullImageName,
            'tag' => $imageTag,
        ]);

        return $imageTag;
    }

    /**
     * Deploy to Dokploy
     */
    private function deployToDokploy(Environment $environment, string $imageTag, DokployDeployment $deployment): void
    {
        Log::info('Deploying to Dokploy', [
            'environment' => $environment->type,
            'image_tag' => $imageTag,
        ]);

        // Get or create application
        $applicationId = $this->getOrCreateApplication($environment);

        // Update environment variables
        $envDTO = new EnvironmentDTO([
            'applicationId' => $applicationId,
            'env' => $this->buildEnvString($environment->env_vars),
            'buildArgs' => null,
        ]);
        $this->dokployService->setEnvironmentVariables($envDTO);

        // Trigger deployment
        $result = $this->dokployService->deployApplication(
            $applicationId,
            "QA Deployment - {$imageTag}",
            "Automated deployment from develop branch"
        );

        $deployment->update([
            'dokploy_application_id' => $applicationId,
        ]);

        Log::info('Dokploy deployment triggered', [
            'application_id' => $applicationId,
        ]);
    }

    /**
     * Wait for deployment to complete
     */
    private function waitForDeployment(Environment $environment, DokployDeployment $deployment): void
    {
        $startTime = time();
        $maxWaitTime = config('deployment.timeout', self::MAX_WAIT_TIME);

        while (true) {
            $elapsed = time() - $startTime;

            if ($elapsed >= $maxWaitTime) {
                throw new Exception('Deployment timeout after ' . $maxWaitTime . ' seconds');
            }

            $status = $this->dokployService->getDeploymentStatus($deployment->dokploy_application_id);

            if ($status === 'done') {
                Log::info('Deployment completed successfully');
                return;
            }

            if ($status === 'error') {
                throw new Exception('Deployment failed in Dokploy');
            }

            sleep(self::POLL_INTERVAL);
        }
    }

    /**
     * Run health checks
     */
    private function runHealthChecks(Environment $environment, DokployDeployment $deployment): void
    {
        Log::info('Running health checks');

        $primaryDomain = $environment->getPrimaryDomain();
        if (!$primaryDomain) {
            Log::warning('No primary domain configured, skipping health check');
            return;
        }

        $healthUrl = "https://{$primaryDomain}/api/health";

        // Give the application some time to start
        sleep(10);

        $attempts = 0;
        $maxAttempts = 6;

        while ($attempts < $maxAttempts) {
            try {
                $response = \Illuminate\Support\Facades\Http::timeout(5)->get($healthUrl);

                if ($response->successful()) {
                    Log::info('Health check passed', [
                        'url' => $healthUrl,
                        'status' => $response->status(),
                    ]);
                    return;
                }
            } catch (Exception $e) {
                Log::warning('Health check attempt failed', [
                    'attempt' => $attempts + 1,
                    'error' => $e->getMessage(),
                ]);
            }

            $attempts++;
            if ($attempts < $maxAttempts) {
                sleep(10);
            }
        }

        throw new Exception("Health check failed after {$maxAttempts} attempts");
    }

    /**
     * Run integration tests
     *
     * @param string $deploymentId
     * @return object Test result
     */
    public function runIntegrationTests(string $deploymentId): object
    {
        Log::info('Running integration tests', [
            'deployment_id' => $deploymentId,
        ]);

        try {
            // Run Pest integration tests
            $result = Process::run([
                'php',
                'artisan',
                'test',
                '--group=integration',
                '--stop-on-failure',
            ], base_path());

            $success = $result->successful();

            Log::info('Integration tests completed', [
                'deployment_id' => $deploymentId,
                'success' => $success,
                'output' => $result->output(),
            ]);

            return (object) [
                'success' => $success,
                'output' => $result->output(),
                'error' => $success ? null : $result->errorOutput(),
            ];
        } catch (Exception $e) {
            Log::error('Integration tests failed', [
                'deployment_id' => $deploymentId,
                'error' => $e->getMessage(),
            ]);

            return (object) [
                'success' => false,
                'output' => null,
                'error' => $e->getMessage(),
            ];
        }
    }

    /**
     * Validate deployment
     *
     * @param string $deploymentId
     * @return object Validation result
     */
    public function validateDeployment(string $deploymentId): object
    {
        $deployment = DokployDeployment::findOrFail($deploymentId);

        $checks = [
            'deployment_exists' => !is_null($deployment),
            'deployment_successful' => $deployment->status === 'success',
            'environment_active' => $deployment->environment->status === 'active',
        ];

        $allPassed = !in_array(false, $checks, true);

        return (object) [
            'valid' => $allPassed,
            'checks' => $checks,
        ];
    }

    /**
     * Notify deployment status
     *
     * @param string $deploymentId
     * @param string $status
     */
    public function notifyDeploymentStatus(string $deploymentId, string $status): void
    {
        $deployment = DokployDeployment::findOrFail($deploymentId);

        Log::info('Sending deployment notification', [
            'deployment_id' => $deploymentId,
            'status' => $status,
        ]);

        // TODO: Implement notification channels (Slack, Discord, Email)
        // For now, just log
        if ($status === 'success') {
            Log::channel('deployments')->info('✅ Deployment successful', [
                'environment' => $deployment->environment->type,
                'commit' => $deployment->git_commit,
                'image' => $deployment->docker_image,
            ]);
        } else {
            Log::channel('deployments')->error('❌ Deployment failed', [
                'environment' => $deployment->environment->type,
                'error' => $deployment->error_message,
            ]);
        }
    }

    /**
     * Get or create Dokploy application
     */
    private function getOrCreateApplication(Environment $environment): string
    {
        // Check if environment already has an application
        $app = $environment->applications()->first();

        if ($app && $app->dokploy_application_id) {
            return $app->dokploy_application_id;
        }

        // Create new application in Dokploy
        $appDTO = new ApplicationDTO([
            'name' => 'agl-hostman-' . $environment->type,
            'environmentId' => $environment->dokploy_project_id,
            'appName' => 'agl-hostman-' . $environment->type,
            'description' => "AGL Hostman - {$environment->type} environment",
        ]);

        $createdApp = $this->dokployService->createApplication($appDTO);

        // Store in database
        \App\Models\DokployApplication::create([
            'environment_id' => $environment->id,
            'dokploy_application_id' => $createdApp->applicationId,
            'name' => $appDTO->name,
            'status' => 'active',
        ]);

        return $createdApp->applicationId;
    }

    /**
     * Build environment variables string from array
     */
    private function buildEnvString(array $envVars): string
    {
        return collect($envVars)
            ->map(fn($value, $key) => "{$key}={$value}")
            ->implode("\n");
    }

    /**
     * Get current Git commit hash
     */
    private function getGitCommit(string $branch): string
    {
        $result = Process::run([
            'git',
            'rev-parse',
            $branch,
        ], base_path());

        if (!$result->successful()) {
            throw new Exception("Failed to get Git commit: {$result->errorOutput()}");
        }

        return trim($result->output());
    }

    /**
     * Deploy to UAT environment
     *
     * @param array $options Deployment options
     * @return DokployDeployment Deployment record
     * @throws Exception If deployment fails
     */
    public function deployToUAT(array $options = []): DokployDeployment
    {
        try {
            // Get UAT environment
            $environment = Environment::where('type', 'uat')->firstOrFail();

            Log::info('Starting UAT deployment', [
                'environment_id' => $environment->id,
                'options' => $options,
            ]);

            // Check if promotion is approved (if promotion_id provided)
            if (isset($options['promotion_id'])) {
                $promotion = \App\Models\Promotion::findOrFail($options['promotion_id']);
                if (!$promotion->isApproved()) {
                    throw new Exception('Promotion is not approved for UAT deployment');
                }
            }

            // Create deployment record
            $deployment = DokployDeployment::create([
                'environment_id' => $environment->id,
                'status' => 'pending',
                'triggered_by' => $options['triggered_by'] ?? 'manual',
                'git_branch' => $environment->git_branch,
                'git_commit' => $options['git_commit'] ?? null,
                'started_at' => now(),
            ]);

            try {
                // Step 1: Build and push Docker image
                $imageTag = $this->buildAndPushImageForUAT($environment, $deployment, $options['source_version'] ?? null);

                // Step 2: Deploy to Dokploy (CT181)
                $this->deployToDokployForUAT($environment, $imageTag, $deployment);

                // Step 3: Wait for deployment to complete
                $this->waitForDeployment($environment, $deployment);

                // Step 4: Run health checks
                $this->runHealthChecks($environment, $deployment);

                // Step 5: Run smoke tests (lighter than integration tests)
                $testResult = $this->runSmokeTests($deployment->id);

                if (!$testResult->success) {
                    // Update promotion with failed smoke tests
                    if (isset($options['promotion_id'])) {
                        $promotion = \App\Models\Promotion::findOrFail($options['promotion_id']);
                        $promotion->markFailed([
                            'total' => $testResult->total ?? 0,
                            'passed' => $testResult->passed ?? 0,
                            'failed' => $testResult->failed ?? 0,
                            'error' => $testResult->error,
                        ]);
                    }

                    throw new Exception('Smoke tests failed');
                }

                // Step 6: Update deployment status
                $deployment->update([
                    'status' => 'success',
                    'completed_at' => now(),
                ]);

                // Update environment last deployed timestamp
                $environment->update([
                    'last_deployed_at' => now(),
                ]);

                // Step 7: Mark promotion as completed
                if (isset($options['promotion_id'])) {
                    $promotion = \App\Models\Promotion::findOrFail($options['promotion_id']);
                    $promotion->complete($imageTag, [
                        'total' => $testResult->total ?? 0,
                        'passed' => $testResult->passed ?? 0,
                        'failed' => $testResult->failed ?? 0,
                        'duration' => $testResult->duration ?? 0,
                        'success_rate' => $testResult->success_rate ?? 100,
                    ]);
                }

                // Step 8: Send success notification
                $this->notifyDeploymentStatus($deployment->id, 'success');

                Log::info('UAT deployment successful', [
                    'deployment_id' => $deployment->id,
                    'image_tag' => $imageTag,
                ]);

                return $deployment;

            } catch (Exception $e) {
                // Mark deployment as failed
                $deployment->update([
                    'status' => 'failed',
                    'error_message' => $e->getMessage(),
                    'completed_at' => now(),
                ]);

                // Send failure notification
                $this->notifyDeploymentStatus($deployment->id, 'failed');

                // Rollback if configured
                if (config('deployment.rollback_on_failure', true)) {
                    Log::warning('Attempting automatic rollback', [
                        'deployment_id' => $deployment->id,
                    ]);
                    $this->rollbackUAT($deployment->id);
                }

                throw $e;
            }
        } catch (Exception $e) {
            Log::error('UAT deployment failed', [
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
            ]);
            throw $e;
        }
    }

    /**
     * Build Docker image and push to Harbor for UAT
     */
    private function buildAndPushImageForUAT(Environment $environment, DokployDeployment $deployment, ?string $sourceVersion = null): string
    {
        Log::info('Building Docker image for UAT', [
            'environment' => $environment->type,
            'source_version' => $sourceVersion,
        ]);

        // Generate image tag
        $gitCommit = $this->getGitCommit($environment->git_branch);
        $shortCommit = substr($gitCommit, 0, 7);
        $imageTag = "uat-{$shortCommit}";
        $fullImageName = config('harbor.registry') . "/{$environment->harbor_project}/agl-hostman:{$imageTag}";

        // Update deployment record
        $deployment->update([
            'docker_image' => $fullImageName,
            'git_commit' => $gitCommit,
        ]);

        // Build image
        $buildResult = Process::run([
            'docker',
            'build',
            '-t', $fullImageName,
            '-f', base_path('Dockerfile'),
            base_path(),
        ]);

        if (!$buildResult->successful()) {
            throw new Exception("Docker build failed: {$buildResult->errorOutput()}");
        }

        // Push to Harbor
        $pushResult = Process::run([
            'docker',
            'push',
            $fullImageName,
        ]);

        if (!$pushResult->successful()) {
            throw new Exception("Docker push failed: {$pushResult->errorOutput()}");
        }

        Log::info('Docker image built and pushed for UAT', [
            'image' => $fullImageName,
            'tag' => $imageTag,
        ]);

        return $imageTag;
    }

    /**
     * Deploy to Dokploy for UAT (CT181)
     */
    private function deployToDokployForUAT(Environment $environment, string $imageTag, DokployDeployment $deployment): void
    {
        Log::info('Deploying to Dokploy (CT181)', [
            'environment' => $environment->type,
            'image_tag' => $imageTag,
        ]);

        // Get or create application
        $applicationId = $this->getOrCreateApplication($environment);

        // Update environment variables
        $envDTO = new EnvironmentDTO([
            'applicationId' => $applicationId,
            'env' => $this->buildEnvString($environment->env_vars),
            'buildArgs' => null,
        ]);
        $this->dokployService->setEnvironmentVariables($envDTO);

        // Trigger deployment
        $result = $this->dokployService->deployApplication(
            $applicationId,
            "UAT Deployment - {$imageTag}",
            "Manual deployment from release branch"
        );

        $deployment->update([
            'dokploy_application_id' => $applicationId,
        ]);

        Log::info('Dokploy deployment triggered on CT181', [
            'application_id' => $applicationId,
        ]);
    }

    /**
     * Run smoke tests (lighter than full integration tests)
     *
     * @param string $deploymentId
     * @return object Test result
     */
    public function runSmokeTests(string $deploymentId): object
    {
        Log::info('Running smoke tests', [
            'deployment_id' => $deploymentId,
        ]);

        try {
            // Run Pest smoke tests
            $result = Process::timeout(120)->run([ // 2 minute timeout
                'php',
                'artisan',
                'test',
                '--group=smoke',
                '--stop-on-failure',
            ], base_path());

            $success = $result->successful();
            $output = $result->output();

            // Parse test results
            preg_match('/Tests:\s+(\d+)\s+passed/', $output, $passedMatches);
            preg_match('/Tests:\s+\d+\s+passed.*?(\d+)\s+failed/', $output, $failedMatches);

            $passed = isset($passedMatches[1]) ? (int)$passedMatches[1] : 0;
            $failed = isset($failedMatches[1]) ? (int)$failedMatches[1] : 0;
            $total = $passed + $failed;

            Log::info('Smoke tests completed', [
                'deployment_id' => $deploymentId,
                'success' => $success,
                'passed' => $passed,
                'failed' => $failed,
            ]);

            return (object) [
                'success' => $success,
                'total' => $total,
                'passed' => $passed,
                'failed' => $failed,
                'success_rate' => $total > 0 ? ($passed / $total) * 100 : 0,
                'duration' => 0, // TODO: Parse duration from output
                'output' => $output,
                'error' => $success ? null : $result->errorOutput(),
            ];
        } catch (Exception $e) {
            Log::error('Smoke tests failed', [
                'deployment_id' => $deploymentId,
                'error' => $e->getMessage(),
            ]);

            return (object) [
                'success' => false,
                'total' => 0,
                'passed' => 0,
                'failed' => 0,
                'output' => null,
                'error' => $e->getMessage(),
            ];
        }
    }

    /**
     * Rollback UAT deployment
     *
     * @param string $deploymentId
     * @return array Rollback result
     */
    public function rollbackUAT(string $deploymentId): array
    {
        try {
            $deployment = DokployDeployment::findOrFail($deploymentId);

            Log::info('Rolling back UAT deployment', [
                'deployment_id' => $deploymentId,
            ]);

            // Find previous successful deployment
            $previousDeployment = DokployDeployment::where('environment_id', $deployment->environment_id)
                ->where('status', 'success')
                ->where('id', '!=', $deployment->id)
                ->orderBy('completed_at', 'desc')
                ->first();

            if (!$previousDeployment) {
                throw new Exception('No previous successful deployment found for rollback');
            }

            // Redeploy previous version
            $this->dokployService->deployApplication(
                $previousDeployment->dokploy_application_id,
                "Rollback to {$previousDeployment->git_commit}",
                "Automatic rollback from failed deployment {$deployment->id}"
            );

            Log::info('UAT rollback completed', [
                'rolled_back_to' => $previousDeployment->id,
                'commit' => $previousDeployment->git_commit,
            ]);

            return [
                'success' => true,
                'rolled_back_to_deployment' => $previousDeployment->id,
                'rolled_back_to_commit' => $previousDeployment->git_commit,
            ];

        } catch (Exception $e) {
            Log::error('UAT rollback failed', [
                'deployment_id' => $deploymentId,
                'error' => $e->getMessage(),
            ]);

            return [
                'success' => false,
                'error' => $e->getMessage(),
            ];
        }
    }
}
