<?php

namespace Database\Seeders;

use App\Models\Environment;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Log;

/**
 * QA Environment Seeder
 *
 * Seeds the database with QA environment configuration
 * Run with: php artisan db:seed --class=QAEnvironmentSeeder
 */
class QAEnvironmentSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        Log::info('Starting QA Environment seeding');

        // Check if QA environment already exists
        $existing = Environment::where('type', 'qa')->first();

        if ($existing) {
            $this->command->warn('QA Environment already exists (ID: '.$existing->id.')');
            $this->command->warn('Skipping seeding to avoid duplicates');
            Log::warning('QA Environment already exists, skipping seed', [
                'id' => $existing->id,
            ]);

            return;
        }

        // Create QA environment
        $qaEnvironment = Environment::create([
            'name' => 'QA Environment',
            'type' => 'qa',
            'harbor_project' => 'agl-hostman-qa',
            'git_branch' => 'develop',
            'auto_deploy' => true,
            'auto_test' => true,
            'status' => 'active',
            'domains' => [
                'qa.agl-hostman.local',
                'qa-agl.aglz.io',
            ],
            'env_vars' => [
                'APP_ENV' => 'qa',
                'APP_DEBUG' => 'true',
                'APP_URL' => 'https://qa-agl.aglz.io',
                'DB_CONNECTION' => 'pgsql',
                'DB_HOST' => 'postgres',
                'DB_PORT' => '5432',
                'DB_DATABASE' => 'agl_hostman_qa',
                'CACHE_DRIVER' => 'redis',
                'QUEUE_CONNECTION' => 'redis',
                'SESSION_DRIVER' => 'redis',
                'REDIS_HOST' => 'redis',
                'REDIS_PORT' => '6379',
                'LOG_LEVEL' => 'info',
                'LOG_CHANNEL' => 'stack',
                'MAIL_MAILER' => 'log',

                // Dokploy
                'DOKPLOY_API_URL' => 'http://192.168.0.180:3000',

                // Harbor Registry
                'HARBOR_REGISTRY' => 'harbor.aglz.io:5000',
                'HARBOR_PROJECT' => 'agl-hostman-qa',

                // GitHub
                'GITHUB_WEBHOOK_ENABLED' => 'true',

                // Testing
                'DEPLOYMENT_RUN_TESTS' => 'true',
                'DEPLOYMENT_ROLLBACK_ON_FAILURE' => 'true',
            ],
            'resources' => [
                'cpu_limit' => '2',
                'cpu_reservation' => '1',
                'memory_limit' => '4096M',
                'memory_reservation' => '2048M',
                'replicas' => 1,
            ],
        ]);

        $this->command->info('✅ Created QA Environment (ID: '.$qaEnvironment->id.')');
        $this->command->info('   Name: '.$qaEnvironment->name);
        $this->command->info('   Type: '.$qaEnvironment->type);
        $this->command->info('   Branch: '.$qaEnvironment->git_branch);
        $this->command->info('   Auto-deploy: '.($qaEnvironment->auto_deploy ? 'Yes' : 'No'));
        $this->command->info('   Auto-test: '.($qaEnvironment->auto_test ? 'Yes' : 'No'));
        $this->command->info('   Domains: '.implode(', ', $qaEnvironment->domains));

        Log::info('QA Environment seeded successfully', [
            'id' => $qaEnvironment->id,
            'name' => $qaEnvironment->name,
        ]);

        $this->command->newLine();
        $this->command->info('Next steps:');
        $this->command->line('1. Run: php artisan deployment:setup-qa');
        $this->command->line('2. Configure Harbor project: agl-hostman-qa');
        $this->command->line('3. Set up GitHub webhook with secret');
    }
}
