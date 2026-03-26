<?php

declare(strict_types=1);

namespace Database\Seeders;

use App\Models\Environment;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Log;

/**
 * UAT Environment Seeder
 *
 * Seeds the database with UAT environment configuration
 * Run with: php artisan db:seed --class=UATEnvironmentSeeder
 */
class UATEnvironmentSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        Log::info('Starting UAT Environment seeding');

        // Check if UAT environment already exists
        $existing = Environment::where('type', 'uat')->first();

        if ($existing) {
            $this->command->warn('UAT Environment already exists (ID: '.$existing->id.')');
            $this->command->warn('Skipping seeding to avoid duplicates');
            Log::warning('UAT Environment already exists, skipping seed', [
                'id' => $existing->id,
            ]);

            return;
        }

        // Create UAT environment
        $uatEnvironment = Environment::create([
            'name' => 'UAT Environment',
            'type' => 'uat',
            'harbor_project' => 'agl-hostman-uat',
            'git_branch' => 'release',
            'auto_deploy' => false, // Manual deployment only
            'auto_test' => true, // Run smoke tests
            'status' => 'active',
            'domains' => [
                'uat.agl-hostman.local',
                'uat-agl.aglz.io',
            ],
            'env_vars' => [
                'APP_ENV' => 'uat',
                'APP_DEBUG' => 'false',
                'APP_URL' => 'https://uat-agl.aglz.io',
                'DB_CONNECTION' => 'pgsql',
                'DB_HOST' => 'postgres',
                'DB_PORT' => '5432',
                'DB_DATABASE' => 'agl_hostman_uat',
                'CACHE_DRIVER' => 'redis',
                'QUEUE_CONNECTION' => 'redis',
                'SESSION_DRIVER' => 'redis',
                'REDIS_HOST' => 'redis',
                'REDIS_PORT' => '6379',
                'LOG_LEVEL' => 'warning',
                'LOG_CHANNEL' => 'stack',
                'MAIL_MAILER' => 'smtp',

                // Dokploy (CT181)
                'DOKPLOY_API_URL' => 'http://192.168.0.181:3000',

                // Harbor Registry
                'HARBOR_REGISTRY' => 'harbor.aglz.io:5000',
                'HARBOR_PROJECT' => 'agl-hostman-uat',

                // GitHub
                'GITHUB_WEBHOOK_ENABLED' => 'false', // Manual promotion only

                // Testing
                'DEPLOYMENT_RUN_TESTS' => 'true',
                'DEPLOYMENT_TEST_TYPE' => 'smoke', // Smoke tests only
                'DEPLOYMENT_ROLLBACK_ON_FAILURE' => 'true',

                // Approval
                'DEPLOYMENT_APPROVAL_REQUIRED' => 'true',
                'DEPLOYMENT_APPROVER_ROLES' => 'admin,lead-developer',
            ],
            'resources' => [
                'cpu_limit' => '2',
                'cpu_reservation' => '1',
                'memory_limit' => '4096M',
                'memory_reservation' => '2048M',
                'replicas' => 1,
            ],
        ]);

        $this->command->info('✅ Created UAT Environment (ID: '.$uatEnvironment->id.')');
        $this->command->info('   Name: '.$uatEnvironment->name);
        $this->command->info('   Type: '.$uatEnvironment->type);
        $this->command->info('   Branch: '.$uatEnvironment->git_branch);
        $this->command->info('   Auto-deploy: '.($uatEnvironment->auto_deploy ? 'Yes' : 'No (Manual Only)'));
        $this->command->info('   Auto-test: '.($uatEnvironment->auto_test ? 'Yes (Smoke Tests)' : 'No'));
        $this->command->info('   Approval Required: Yes');
        $this->command->info('   Domains: '.implode(', ', $uatEnvironment->domains));

        Log::info('UAT Environment seeded successfully', [
            'id' => $uatEnvironment->id,
            'name' => $uatEnvironment->name,
        ]);

        $this->command->newLine();
        $this->command->info('Next steps:');
        $this->command->line('1. Run: php artisan deployment:setup-uat');
        $this->command->line('2. Configure Harbor project: agl-hostman-uat');
        $this->command->line('3. Configure manual promotion workflow');
        $this->command->line('4. Set up approval roles in .env');
    }
}
