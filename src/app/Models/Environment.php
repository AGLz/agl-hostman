<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * Environment Model
 *
 * Represents deployment environments (dev, qa, uat, production)
 * Manages configuration, deployments, and Dokploy integration
 *
 * @property int $id
 * @property string $name
 * @property string $type
 * @property string|null $dokploy_project_id
 * @property string $harbor_project
 * @property string $git_branch
 * @property bool $auto_deploy
 * @property bool $auto_test
 * @property string $status
 * @property array $domains
 * @property array $env_vars
 * @property array $resources
 * @property \Carbon\Carbon|null $last_deployed_at
 * @property \Carbon\Carbon|null $created_at
 * @property \Carbon\Carbon|null $updated_at
 */
class Environment extends Model
{
    use HasFactory;

    protected $fillable = [
        'name',
        'type',
        'dokploy_project_id',
        'harbor_project',
        'git_branch',
        'auto_deploy',
        'auto_test',
        'status',
        'domains',
        'env_vars',
        'resources',
        'last_deployed_at',
    ];

    protected $casts = [
        'auto_deploy' => 'boolean',
        'auto_test' => 'boolean',
        'domains' => 'array',
        'env_vars' => 'array',
        'resources' => 'array',
        'last_deployed_at' => 'datetime',
    ];

    protected $attributes = [
        'auto_deploy' => false,
        'auto_test' => false,
        'status' => 'active',
    ];

    // ========== Relationships ==========

    /**
     * Get applications deployed to this environment
     */
    public function applications(): HasMany
    {
        return $this->hasMany(DokployApplication::class, 'environment_id');
    }

    /**
     * Get deployments for this environment
     */
    public function deployments(): HasMany
    {
        return $this->hasMany(DokployDeployment::class, 'environment_id');
    }

    // ========== Scopes ==========

    /**
     * Scope query to active environments
     */
    public function scopeActive(Builder $query): Builder
    {
        return $query->where('status', 'active');
    }

    /**
     * Scope query by environment type
     */
    public function scopeByType(Builder $query, string $type): Builder
    {
        return $query->where('type', $type);
    }

    /**
     * Scope query to auto-deploy enabled environments
     */
    public function scopeAutoDeployEnabled(Builder $query): Builder
    {
        return $query->where('auto_deploy', true)
            ->where('status', 'active');
    }

    /**
     * Scope query to auto-test enabled environments
     */
    public function scopeAutoTestEnabled(Builder $query): Builder
    {
        return $query->where('auto_test', true)
            ->where('status', 'active');
    }

    // ========== Methods ==========

    /**
     * Deploy to this environment
     *
     * @return bool True if deployment initiated
     */
    public function deploy(): bool
    {
        // This will be implemented by DeploymentWorkflowService
        // For now, just update last_deployed_at
        $this->update([
            'last_deployed_at' => now(),
        ]);

        return true;
    }

    /**
     * Rollback to previous deployment
     *
     * @return bool True if rollback successful
     */
    public function rollback(): bool
    {
        // Get last successful deployment
        $lastDeployment = $this->deployments()
            ->where('status', 'success')
            ->orderBy('created_at', 'desc')
            ->skip(1) // Skip current deployment
            ->first();

        if (! $lastDeployment) {
            return false;
        }

        // Trigger rollback (to be implemented)
        return true;
    }

    /**
     * Get current deployment status
     *
     * @return string Current status (idle, deploying, running, error)
     */
    public function getStatus(): string
    {
        // Check latest deployment
        $latestDeployment = $this->deployments()
            ->orderBy('created_at', 'desc')
            ->first();

        if (! $latestDeployment) {
            return 'idle';
        }

        return $latestDeployment->status;
    }

    /**
     * Sync environment configuration to Dokploy
     *
     * @return bool True if sync successful
     */
    public function syncToDokploy(): bool
    {
        // This will be implemented by EnvironmentConfigService
        return app(\App\Services\Deployment\EnvironmentConfigService::class)
            ->syncEnvironmentToDokploy((string) $this->id);
    }

    /**
     * Check if environment is production
     */
    public function isProduction(): bool
    {
        return $this->type === 'production';
    }

    /**
     * Check if environment is QA
     */
    public function isQA(): bool
    {
        return $this->type === 'qa';
    }

    /**
     * Check if environment is UAT
     */
    public function isUAT(): bool
    {
        return $this->type === 'uat';
    }

    /**
     * Check if environment is development
     */
    public function isDevelopment(): bool
    {
        return $this->type === 'dev';
    }

    /**
     * Get primary domain for this environment
     */
    public function getPrimaryDomain(): ?string
    {
        return $this->domains[0] ?? null;
    }

    /**
     * Get environment variable by key
     */
    public function getEnvVar(string $key, mixed $default = null): mixed
    {
        return $this->env_vars[$key] ?? $default;
    }

    /**
     * Get resource limit by key
     */
    public function getResource(string $key, mixed $default = null): mixed
    {
        return $this->resources[$key] ?? $default;
    }
}
