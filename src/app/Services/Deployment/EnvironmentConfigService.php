<?php

declare(strict_types=1);

namespace App\Services\Deployment;

use App\DTOs\Dokploy\ProjectDTO;
use App\Models\Environment;
use App\Services\DokployService;
use Exception;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\ValidationException;

/**
 * Environment Configuration Service
 *
 * Manages QA/UAT/Production environment configurations
 * Handles environment creation, validation, and synchronization with Dokploy
 */
class EnvironmentConfigService
{
    private const CACHE_TTL = 600; // 10 minutes

    private const CACHE_PREFIX = 'env_config:';

    public function __construct(
        private readonly DokployService $dokployService
    ) {}

    /**
     * Create new environment configuration
     *
     * @param  string  $name  Environment name (e.g., "QA Environment")
     * @param  string  $type  Environment type (dev, qa, uat, production)
     * @return Environment Created environment instance
     *
     * @throws ValidationException If validation fails
     * @throws Exception If creation fails
     */
    public function createEnvironment(string $name, string $type): Environment
    {
        try {
            // Validate type
            if (! in_array($type, ['dev', 'qa', 'uat', 'production'])) {
                throw new ValidationException(
                    Validator::make([], [])
                        ->after(fn ($validator) => $validator->errors()->add('type', "Invalid environment type: {$type}"))
                );
            }

            // Check if environment of this type already exists
            $existing = Environment::where('type', $type)->first();
            if ($existing) {
                throw new Exception("Environment of type '{$type}' already exists (ID: {$existing->id})");
            }

            // Get default configuration for type
            $config = $this->getEnvironmentConfig($type);

            // Create environment
            $environment = Environment::create([
                'name' => $name,
                'type' => $type,
                'harbor_project' => $config['harbor_project'],
                'git_branch' => $config['git_branch'],
                'auto_deploy' => $config['auto_deploy'],
                'auto_test' => $config['auto_test'],
                'domains' => $config['domains'],
                'env_vars' => $config['env_vars'],
                'resources' => $config['resources'],
                'status' => 'active',
            ]);

            // Clear cache
            Cache::forget(self::CACHE_PREFIX.$type);

            Log::info('Created environment', [
                'id' => $environment->id,
                'name' => $name,
                'type' => $type,
            ]);

            return $environment;
        } catch (Exception $e) {
            Log::error('Failed to create environment', [
                'name' => $name,
                'type' => $type,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Get environment-specific configuration
     *
     * @param  string  $type  Environment type
     * @return array Configuration array
     */
    public function getEnvironmentConfig(string $type): array
    {
        return Cache::remember(
            self::CACHE_PREFIX.$type,
            self::CACHE_TTL,
            function () use ($type) {
                return match ($type) {
                    'dev' => $this->getDevConfig(),
                    'qa' => $this->getQAConfig(),
                    'uat' => $this->getUATConfig(),
                    'production' => $this->getProductionConfig(),
                    default => throw new Exception("Unknown environment type: {$type}"),
                };
            }
        );
    }

    /**
     * Validate environment configuration
     *
     * @param  array  $config  Configuration to validate
     * @return bool True if valid
     *
     * @throws ValidationException If validation fails
     */
    public function validateEnvironmentConfig(array $config): bool
    {
        $validator = Validator::make($config, [
            'harbor_project' => 'required|string|max:255',
            'git_branch' => 'required|string|max:255',
            'auto_deploy' => 'required|boolean',
            'auto_test' => 'required|boolean',
            'domains' => 'required|array|min:1',
            'domains.*' => 'required|string|max:255',
            'env_vars' => 'required|array',
            'env_vars.APP_ENV' => 'required|string',
            'env_vars.APP_DEBUG' => 'required|string',
            'resources' => 'required|array',
            'resources.cpu_limit' => 'required|string',
            'resources.memory_limit' => 'required|string',
        ]);

        if ($validator->fails()) {
            throw new ValidationException($validator);
        }

        return true;
    }

    /**
     * Synchronize environment to Dokploy
     *
     * @param  string  $environmentId  Environment ID
     * @return bool True if successful
     *
     * @throws Exception If sync fails
     */
    public function syncEnvironmentToDokploy(string $environmentId): bool
    {
        try {
            $environment = Environment::findOrFail($environmentId);

            // Check if already has Dokploy project
            if ($environment->dokploy_project_id) {
                Log::info('Environment already has Dokploy project', [
                    'environment_id' => $environmentId,
                    'project_id' => $environment->dokploy_project_id,
                ]);

                return true;
            }

            // Create Dokploy project
            $projectDTO = new ProjectDTO([
                'name' => $environment->name,
                'description' => "Environment: {$environment->type}",
            ]);

            $project = $this->dokployService->createProject($projectDTO);

            // Update environment with project ID
            $environment->update([
                'dokploy_project_id' => $project->projectId,
            ]);

            Log::info('Synced environment to Dokploy', [
                'environment_id' => $environmentId,
                'project_id' => $project->projectId,
            ]);

            return true;
        } catch (Exception $e) {
            Log::error('Failed to sync environment to Dokploy', [
                'environment_id' => $environmentId,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Get development environment configuration
     */
    private function getDevConfig(): array
    {
        return [
            'harbor_project' => 'agl-hostman-dev',
            'git_branch' => 'main',
            'auto_deploy' => false,
            'auto_test' => false,
            'domains' => ['dev.agl-hostman.local', 'dev-agl.aglz.io'],
            'env_vars' => [
                'APP_ENV' => 'development',
                'APP_DEBUG' => 'true',
                'DB_DATABASE' => 'agl_hostman_dev',
                'CACHE_DRIVER' => 'file',
                'QUEUE_CONNECTION' => 'sync',
                'LOG_LEVEL' => 'debug',
            ],
            'resources' => [
                'cpu_limit' => '1',
                'cpu_reservation' => '0.5',
                'memory_limit' => '2048M',
                'memory_reservation' => '1024M',
            ],
        ];
    }

    /**
     * Get QA environment configuration
     */
    private function getQAConfig(): array
    {
        return [
            'harbor_project' => 'agl-hostman-qa',
            'git_branch' => 'develop',
            'auto_deploy' => true,
            'auto_test' => true,
            'domains' => ['qa.agl-hostman.local', 'qa-agl.aglz.io'],
            'env_vars' => [
                'APP_ENV' => 'qa',
                'APP_DEBUG' => 'true',
                'DB_DATABASE' => 'agl_hostman_qa',
                'CACHE_DRIVER' => 'redis',
                'QUEUE_CONNECTION' => 'redis',
                'LOG_LEVEL' => 'info',
                'MAIL_MAILER' => 'log',
            ],
            'resources' => [
                'cpu_limit' => '2',
                'cpu_reservation' => '1',
                'memory_limit' => '4096M',
                'memory_reservation' => '2048M',
            ],
        ];
    }

    /**
     * Get UAT environment configuration
     */
    private function getUATConfig(): array
    {
        return [
            'harbor_project' => 'agl-hostman-uat',
            'git_branch' => 'release',
            'auto_deploy' => false,
            'auto_test' => true,
            'domains' => ['uat.agl-hostman.local', 'uat-agl.aglz.io'],
            'env_vars' => [
                'APP_ENV' => 'uat',
                'APP_DEBUG' => 'false',
                'DB_DATABASE' => 'agl_hostman_uat',
                'CACHE_DRIVER' => 'redis',
                'QUEUE_CONNECTION' => 'redis',
                'LOG_LEVEL' => 'warning',
            ],
            'resources' => [
                'cpu_limit' => '3',
                'cpu_reservation' => '2',
                'memory_limit' => '6144M',
                'memory_reservation' => '4096M',
            ],
        ];
    }

    /**
     * Get production environment configuration
     */
    private function getProductionConfig(): array
    {
        return [
            'harbor_project' => 'agl-hostman',
            'git_branch' => 'main',
            'auto_deploy' => false,
            'auto_test' => true,
            'domains' => ['hostman.aglz.io', 'infra.aglz.io'],
            'env_vars' => [
                'APP_ENV' => 'production',
                'APP_DEBUG' => 'false',
                'DB_DATABASE' => 'agl_hostman',
                'CACHE_DRIVER' => 'redis',
                'QUEUE_CONNECTION' => 'redis',
                'LOG_LEVEL' => 'error',
                'SESSION_DRIVER' => 'redis',
            ],
            'resources' => [
                'cpu_limit' => '4',
                'cpu_reservation' => '2',
                'memory_limit' => '8192M',
                'memory_reservation' => '4096M',
            ],
        ];
    }

    /**
     * Clear all environment configuration caches
     */
    public function clearCache(): void
    {
        Cache::forget(self::CACHE_PREFIX.'dev');
        Cache::forget(self::CACHE_PREFIX.'qa');
        Cache::forget(self::CACHE_PREFIX.'uat');
        Cache::forget(self::CACHE_PREFIX.'production');

        Log::info('Cleared environment configuration cache');
    }
}
