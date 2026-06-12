<?php

namespace Database\Seeders;

use App\Models\Environment;
use App\Models\ProductionDeployment;
use Illuminate\Database\Seeder;

class ProductionEnvironmentSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        // Create production environment
        $production = Environment::create([
            'name' => 'Production',
            'type' => 'production',
            'dokploy_url' => config('deployment.production_dokploy_url', 'http://192.168.0.182:3000'),
            'dokploy_token' => config('deployment.production_dokploy_token'),
            'harbor_project' => 'agl-hostman-prod',
            'domains' => ['ah.aglz.io', 'prod-agl.aglz.io', 'agl-hostman.aglz.io'],
            'auto_deploy' => false, // Always manual for production
            'auto_test' => true,
            'git_branch' => 'main',
            'docker_compose_file' => 'docker/production/docker-compose.yml',
            'environment_variables' => [
                'APP_ENV' => 'production',
                'APP_DEBUG' => 'false',
                'LOG_LEVEL' => 'warning',
                'DB_CONNECTION' => 'pgsql',
                'CACHE_STORE' => 'redis',
                'QUEUE_CONNECTION' => 'redis',
                'SESSION_DRIVER' => 'redis',
            ],
            'resource_limits' => [
                'cpu_cores' => 4,
                'memory_mb' => 8192,
                'disk_gb' => 100,
            ],
        ]);

        // Create production deployment configuration
        ProductionDeployment::create([
            'environment_id' => $production->id,
            'deployment_type' => 'blue_green',
            'active_slot' => 'blue',
            'blue_version' => null, // Will be set on first deployment
            'green_version' => null,
            'active_replicas' => 2,
            'desired_replicas' => 2,
            'health_status' => [
                'status' => 'pending',
                'message' => 'Awaiting first deployment',
            ],
            'load_balancer_config' => [
                'type' => 'nginx',
                'algorithm' => 'least_conn',
                'health_check_path' => '/health',
                'health_check_interval' => 30,
                'ssl_enabled' => true,
            ],
        ]);

        $this->command->info('✅ Production environment configured:');
        $this->command->info('   - Environment: ' . $production->name);
        $this->command->info('   - Type: ' . $production->type);
        $this->command->info('   - Auto-deploy: ' . ($production->auto_deploy ? 'Yes' : 'No'));
        $this->command->info('   - Replicas: 2 (HA)');
        $this->command->info('   - Deployment: Blue-Green');
        $this->command->info('   - Domains: ' . implode(', ', $production->domains));
    }
}
