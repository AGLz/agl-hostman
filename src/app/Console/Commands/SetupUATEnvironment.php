<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\DTOs\Dokploy\ApplicationDTO;
use App\DTOs\Dokploy\DomainDTO;
use App\DTOs\Dokploy\ProjectDTO;
use App\Models\Environment;
use App\Services\Deployment\EnvironmentConfigService;
use App\Services\DokployService;
use Exception;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Log;

/**
 * Setup UAT Environment Command
 *
 * Complete setup of UAT environment on CT181 including:
 * - Dokploy project creation
 * - Application configuration
 * - Domain setup
 * - Environment variables
 * - Resource limits
 * - Manual promotion workflow
 */
class SetupUATEnvironment extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'deployment:setup-uat
                            {--force : Force recreation if already exists}
                            {--skip-dokploy : Skip Dokploy integration}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Setup UAT environment on CT181 with manual promotion workflow';

    private EnvironmentConfigService $configService;

    private DokployService $dokployService;

    public function __construct(
        EnvironmentConfigService $configService,
        DokployService $dokployService
    ) {
        parent::__construct();
        $this->configService = $configService;
        $this->dokployService = $dokployService;
    }

    /**
     * Execute the console command.
     */
    public function handle(): int
    {
        $this->info('🚀 Setting up UAT Environment (CT181)');
        $this->newLine();

        try {
            // Step 1: Check if UAT environment exists
            $environment = Environment::where('type', 'uat')->first();

            if ($environment && ! $this->option('force')) {
                $this->error('❌ UAT Environment already exists (ID: '.$environment->id.')');
                $this->warn('Use --force to recreate');

                return self::FAILURE;
            }

            if ($environment && $this->option('force')) {
                $this->warn('⚠️  Force flag detected, deleting existing environment');
                $environment->delete();
            }

            // Step 2: Verify Dokploy connectivity (CT181)
            if (! $this->option('skip-dokploy')) {
                $this->task('Verifying Dokploy connectivity (CT181)', function () {
                    // Note: This uses DOKPLOY_API_URL from .env
                    // For UAT, should point to CT181: http://192.168.0.181:3000
                    if (! $this->dokployService->testConnection()) {
                        throw new Exception('Cannot connect to Dokploy API on CT181');
                    }

                    return true;
                });
            }

            // Step 3: Create environment record
            $environment = $this->task('Creating UAT Environment record', function () {
                return $this->configService->createEnvironment('UAT Environment', 'uat');
            });

            $this->info("   ✅ Environment created (ID: {$environment->id})");
            $this->info("   ✅ Branch: {$environment->git_branch} (release)");
            $this->info("   ✅ Harbor: {$environment->harbor_project}");
            $this->info('   ✅ Auto-deploy: '.($environment->auto_deploy ? 'Yes' : 'No (Manual)'));
            $this->info('   ✅ Approval: Required');

            // Step 4: Create Dokploy project on CT181
            if (! $this->option('skip-dokploy')) {
                $project = $this->task('Creating Dokploy project on CT181', function () use ($environment) {
                    $projectDTO = new ProjectDTO([
                        'name' => 'AGL-HOSTMAN UAT',
                        'description' => 'UAT Environment for AGL Infrastructure Management - Manual Promotion',
                    ]);

                    $project = $this->dokployService->createProject($projectDTO);

                    $environment->update([
                        'dokploy_project_id' => $project->projectId,
                    ]);

                    return $project;
                });

                $this->info("   ✅ Project created (ID: {$project->projectId})");

                // Step 5: Create application
                $application = $this->task('Creating Dokploy application', function () use ($project) {
                    $appDTO = new ApplicationDTO([
                        'name' => 'agl-hostman-uat',
                        'environmentId' => $project->projectId,
                        'appName' => 'agl-hostman-uat',
                        'description' => 'AGL Infrastructure Management - UAT Environment (CT181)',
                        'sourceType' => 'docker',
                        'dockerImage' => 'harbor.aglz.io:5000/agl-hostman-uat/agl-hostman:latest',
                    ]);

                    return $this->dokployService->createApplication($appDTO);
                });

                $this->info("   ✅ Application created (ID: {$application->applicationId})");

                // Step 6: Configure domains
                $this->task('Configuring domains', function () use ($environment, $application) {
                    foreach ($environment->domains as $domain) {
                        $domainDTO = new DomainDTO([
                            'host' => $domain,
                            'applicationId' => $application->applicationId,
                            'https' => str_contains($domain, 'aglz.io'),
                            'certificateType' => str_contains($domain, 'aglz.io') ? 'letsencrypt' : 'none',
                            'stripPath' => false,
                        ]);

                        $this->dokployService->addDomain($domainDTO);
                    }
                });

                $this->info('   ✅ Domains configured: '.implode(', ', $environment->domains));

                // Step 7: Set environment variables
                $this->task('Setting environment variables', function () use ($environment, $application) {
                    $envString = collect($environment->env_vars)
                        ->map(fn ($value, $key) => "{$key}={$value}")
                        ->implode("\n");

                    $envDTO = new \App\DTOs\Dokploy\EnvironmentDTO([
                        'applicationId' => $application->applicationId,
                        'env' => $envString,
                    ]);

                    $this->dokployService->setEnvironmentVariables($envDTO);
                });

                $this->info('   ✅ Environment variables set ('.count($environment->env_vars).' vars)');

                // Step 8: Configure resource limits
                $this->task('Setting resource limits', function () use ($environment, $application) {
                    $updateDTO = new ApplicationDTO([
                        'applicationId' => $application->applicationId,
                        'cpuLimit' => $environment->getResource('cpu_limit'),
                        'cpuReservation' => $environment->getResource('cpu_reservation'),
                        'memoryLimit' => $environment->getResource('memory_limit'),
                        'memoryReservation' => $environment->getResource('memory_reservation'),
                    ]);

                    $this->dokployService->updateApplication($updateDTO);
                });

                $this->info('   ✅ Resource limits configured');
                $this->info('      CPU: '.$environment->getResource('cpu_limit'));
                $this->info('      Memory: '.$environment->getResource('memory_limit'));
            }

            // Summary
            $this->newLine();
            $this->info('🎉 UAT Environment setup complete!');
            $this->newLine();
            $this->line('📋 Environment Details:');
            $this->table(
                ['Property', 'Value'],
                [
                    ['ID', $environment->id],
                    ['Type', $environment->type],
                    ['Target', 'CT181 (192.168.0.181)'],
                    ['Branch', $environment->git_branch.' (release)'],
                    ['Harbor Project', $environment->harbor_project],
                    ['Auto Deploy', 'No (Manual Only)'],
                    ['Auto Test', 'Yes (Smoke Tests)'],
                    ['Approval Required', 'Yes'],
                    ['Status', $environment->status],
                ]
            );

            $this->newLine();
            $this->line('🔗 Next Steps:');
            $this->line('1. Configure Harbor project: '.$environment->harbor_project);
            $this->line('2. Configure approval roles in .env:');
            $this->line('   UAT_APPROVER_ROLES=admin,lead-developer');
            $this->line('3. Promote from QA using API:');
            $this->line('   POST /api/promotion/qa-to-uat');
            $this->line('   {"source_version": "qa-1a2b3c4"}');
            $this->line('4. Approve promotion:');
            $this->line('   POST /api/promotion/{id}/approve');
            $this->line('5. Monitor smoke tests after deployment');

            Log::info('UAT Environment setup completed', [
                'environment_id' => $environment->id,
            ]);

            return self::SUCCESS;

        } catch (Exception $e) {
            $this->error('❌ Setup failed: '.$e->getMessage());
            Log::error('UAT Environment setup failed', [
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
            ]);

            return self::FAILURE;
        }
    }
}
