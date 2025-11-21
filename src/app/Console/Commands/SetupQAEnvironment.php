<?php

namespace App\Console\Commands;

use App\Models\Environment;
use App\Services\Deployment\EnvironmentConfigService;
use App\Services\DokployService;
use App\DTOs\Dokploy\ProjectDTO;
use App\DTOs\Dokploy\ApplicationDTO;
use App\DTOs\Dokploy\DomainDTO;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Log;
use Exception;

/**
 * Setup QA Environment Command
 *
 * Complete setup of QA environment including:
 * - Dokploy project creation
 * - Application configuration
 * - Domain setup
 * - Environment variables
 * - Resource limits
 */
class SetupQAEnvironment extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'deployment:setup-qa
                            {--force : Force recreation if already exists}
                            {--skip-dokploy : Skip Dokploy integration}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Setup QA environment with Dokploy integration';

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
        $this->info('🚀 Setting up QA Environment');
        $this->newLine();

        try {
            // Step 1: Check if QA environment exists
            $environment = Environment::where('type', 'qa')->first();

            if ($environment && !$this->option('force')) {
                $this->error('❌ QA Environment already exists (ID: ' . $environment->id . ')');
                $this->warn('Use --force to recreate');
                return self::FAILURE;
            }

            if ($environment && $this->option('force')) {
                $this->warn('⚠️  Force flag detected, deleting existing environment');
                $environment->delete();
            }

            // Step 2: Verify Dokploy connectivity
            if (!$this->option('skip-dokploy')) {
                $this->task('Verifying Dokploy connectivity', function () {
                    if (!$this->dokployService->testConnection()) {
                        throw new Exception('Cannot connect to Dokploy API');
                    }
                    return true;
                });
            }

            // Step 3: Create environment record
            $environment = $this->task('Creating QA Environment record', function () {
                return $this->configService->createEnvironment('QA Environment', 'qa');
            });

            $this->info("   ✅ Environment created (ID: {$environment->id})");

            // Step 4: Create Dokploy project
            if (!$this->option('skip-dokploy')) {
                $project = $this->task('Creating Dokploy project', function () use ($environment) {
                    $projectDTO = new ProjectDTO([
                        'name' => 'AGL-HOSTMAN QA',
                        'description' => 'QA Environment for AGL Infrastructure Management',
                    ]);

                    $project = $this->dokployService->createProject($projectDTO);

                    $environment->update([
                        'dokploy_project_id' => $project->projectId,
                    ]);

                    return $project;
                });

                $this->info("   ✅ Project created (ID: {$project->projectId})");

                // Step 5: Create application
                $application = $this->task('Creating Dokploy application', function () use ($environment, $project) {
                    $appDTO = new ApplicationDTO([
                        'name' => 'agl-hostman-qa',
                        'environmentId' => $project->projectId,
                        'appName' => 'agl-hostman-qa',
                        'description' => 'AGL Infrastructure Management - QA Environment',
                        'sourceType' => 'docker',
                        'dockerImage' => 'harbor.aglz.io:5000/agl-hostman-qa/agl-hostman:latest',
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

                $this->info('   ✅ Domains configured: ' . implode(', ', $environment->domains));

                // Step 7: Set environment variables
                $this->task('Setting environment variables', function () use ($environment, $application) {
                    $envString = collect($environment->env_vars)
                        ->map(fn($value, $key) => "{$key}={$value}")
                        ->implode("\n");

                    $envDTO = new \App\DTOs\Dokploy\EnvironmentDTO([
                        'applicationId' => $application->applicationId,
                        'env' => $envString,
                    ]);

                    $this->dokployService->setEnvironmentVariables($envDTO);
                });

                $this->info('   ✅ Environment variables set (' . count($environment->env_vars) . ' vars)');

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
                $this->info('      CPU: ' . $environment->getResource('cpu_limit'));
                $this->info('      Memory: ' . $environment->getResource('memory_limit'));
            }

            // Summary
            $this->newLine();
            $this->info('🎉 QA Environment setup complete!');
            $this->newLine();
            $this->line('📋 Environment Details:');
            $this->table(
                ['Property', 'Value'],
                [
                    ['ID', $environment->id],
                    ['Type', $environment->type],
                    ['Branch', $environment->git_branch],
                    ['Harbor Project', $environment->harbor_project],
                    ['Auto Deploy', $environment->auto_deploy ? 'Yes' : 'No'],
                    ['Auto Test', $environment->auto_test ? 'Yes' : 'No'],
                    ['Status', $environment->status],
                ]
            );

            $this->newLine();
            $this->line('🔗 Next Steps:');
            $this->line('1. Configure Harbor project: ' . $environment->harbor_project);
            $this->line('2. Set up GitHub webhook:');
            $this->line('   URL: ' . config('app.url') . '/webhooks/github');
            $this->line('   Secret: Set GITHUB_WEBHOOK_SECRET in .env');
            $this->line('3. Push Docker image to Harbor:');
            $this->line('   docker build -t harbor.aglz.io:5000/' . $environment->harbor_project . '/agl-hostman:qa-latest .');
            $this->line('   docker push harbor.aglz.io:5000/' . $environment->harbor_project . '/agl-hostman:qa-latest');
            $this->line('4. Trigger first deployment:');
            $this->line('   php artisan deployment:deploy-qa');

            Log::info('QA Environment setup completed', [
                'environment_id' => $environment->id,
            ]);

            return self::SUCCESS;

        } catch (Exception $e) {
            $this->error('❌ Setup failed: ' . $e->getMessage());
            Log::error('QA Environment setup failed', [
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
            ]);
            return self::FAILURE;
        }
    }
}
