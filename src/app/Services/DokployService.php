<?php

declare(strict_types=1);

namespace App\Services;

use App\DTOs\Dokploy\ApplicationDTO;
use App\DTOs\Dokploy\DeploymentDTO;
use App\DTOs\Dokploy\DomainDTO;
use App\DTOs\Dokploy\EnvironmentDTO;
use App\DTOs\Dokploy\LogDTO;
use App\DTOs\Dokploy\ProjectDTO;
use App\Repositories\DokployRepository;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Log;
use Exception;

/**
 * Dokploy Service
 *
 * Main service class for Dokploy API operations
 * Provides high-level methods for managing projects, applications, and deployments
 */
class DokployService
{
    public function __construct(
        private readonly DokployRepository $repository
    ) {}

    // ========== Project Management ==========

    /**
     * Get all projects
     */
    public function getProjects(): Collection
    {
        try {
            $data = $this->repository->get('/api/project.all');

            return collect($data)
                ->map(fn($project) => ProjectDTO::fromArray($project));
        } catch (Exception $e) {
            Log::error('Failed to get Dokploy projects', [
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Get project by ID
     */
    public function getProject(string $projectId): ProjectDTO
    {
        try {
            $data = $this->repository->get("/api/project.one", [
                'projectId' => $projectId,
            ]);

            return ProjectDTO::fromArray($data);
        } catch (Exception $e) {
            Log::error('Failed to get Dokploy project', [
                'projectId' => $projectId,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Create new project
     */
    public function createProject(ProjectDTO $project): ProjectDTO
    {
        try {
            $data = $this->repository->post('/api/project.create', $project->toArray());

            Log::info('Created Dokploy project', [
                'name' => $project->name,
                'projectId' => $data['projectId'] ?? null,
            ]);

            return ProjectDTO::fromArray($data);
        } catch (Exception $e) {
            Log::error('Failed to create Dokploy project', [
                'name' => $project->name,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Update existing project
     */
    public function updateProject(ProjectDTO $project): ProjectDTO
    {
        try {
            $data = $this->repository->put('/api/project.update', $project->toArray());

            Log::info('Updated Dokploy project', [
                'projectId' => $project->projectId,
            ]);

            return ProjectDTO::fromArray($data);
        } catch (Exception $e) {
            Log::error('Failed to update Dokploy project', [
                'projectId' => $project->projectId,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Delete project
     */
    public function deleteProject(string $projectId): bool
    {
        try {
            $this->repository->delete('/api/project.remove', [
                'projectId' => $projectId,
            ]);

            Log::info('Deleted Dokploy project', [
                'projectId' => $projectId,
            ]);

            return true;
        } catch (Exception $e) {
            Log::error('Failed to delete Dokploy project', [
                'projectId' => $projectId,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    // ========== Application Management ==========

    /**
     * Create new application
     */
    public function createApplication(ApplicationDTO $application): ApplicationDTO
    {
        try {
            $data = $this->repository->post('/api/application.create', $application->toArray());

            Log::info('Created Dokploy application', [
                'name' => $application->name,
                'applicationId' => $data['applicationId'] ?? null,
            ]);

            return ApplicationDTO::fromArray($data);
        } catch (Exception $e) {
            Log::error('Failed to create Dokploy application', [
                'name' => $application->name,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Get application by ID
     */
    public function getApplication(string $applicationId): ApplicationDTO
    {
        try {
            $data = $this->repository->get('/api/application.one', [
                'applicationId' => $applicationId,
            ]);

            return ApplicationDTO::fromArray($data);
        } catch (Exception $e) {
            Log::error('Failed to get Dokploy application', [
                'applicationId' => $applicationId,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Update application
     */
    public function updateApplication(ApplicationDTO $application): ApplicationDTO
    {
        try {
            $data = $this->repository->put('/api/application.update', $application->toArray());

            Log::info('Updated Dokploy application', [
                'applicationId' => $application->applicationId,
            ]);

            return ApplicationDTO::fromArray($data);
        } catch (Exception $e) {
            Log::error('Failed to update Dokploy application', [
                'applicationId' => $application->applicationId,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Delete application
     */
    public function deleteApplication(string $applicationId): bool
    {
        try {
            $this->repository->delete('/api/application.delete', [
                'applicationId' => $applicationId,
            ]);

            Log::info('Deleted Dokploy application', [
                'applicationId' => $applicationId,
            ]);

            return true;
        } catch (Exception $e) {
            Log::error('Failed to delete Dokploy application', [
                'applicationId' => $applicationId,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Start application
     */
    public function startApplication(string $applicationId): bool
    {
        try {
            $this->repository->post('/api/application.start', [
                'applicationId' => $applicationId,
            ]);

            Log::info('Started Dokploy application', [
                'applicationId' => $applicationId,
            ]);

            return true;
        } catch (Exception $e) {
            Log::error('Failed to start Dokploy application', [
                'applicationId' => $applicationId,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Stop application
     */
    public function stopApplication(string $applicationId): bool
    {
        try {
            $this->repository->post('/api/application.stop', [
                'applicationId' => $applicationId,
            ]);

            Log::info('Stopped Dokploy application', [
                'applicationId' => $applicationId,
            ]);

            return true;
        } catch (Exception $e) {
            Log::error('Failed to stop Dokploy application', [
                'applicationId' => $applicationId,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Restart application
     */
    public function restartApplication(string $applicationId): bool
    {
        try {
            $this->repository->post('/api/application.restart', [
                'applicationId' => $applicationId,
            ]);

            Log::info('Restarted Dokploy application', [
                'applicationId' => $applicationId,
            ]);

            return true;
        } catch (Exception $e) {
            Log::error('Failed to restart Dokploy application', [
                'applicationId' => $applicationId,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    // ========== Deployment Management ==========

    /**
     * Deploy application
     */
    public function deployApplication(
        string $applicationId,
        ?string $title = null,
        ?string $description = null
    ): DeploymentDTO {
        try {
            $deployment = DeploymentDTO::forDeploy($applicationId, $title, $description);

            $data = $this->repository->post('/api/application.deploy', $deployment->toArray());

            Log::info('Deployed Dokploy application', [
                'applicationId' => $applicationId,
                'title' => $title,
            ]);

            return DeploymentDTO::fromArray($data);
        } catch (Exception $e) {
            Log::error('Failed to deploy Dokploy application', [
                'applicationId' => $applicationId,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Redeploy application (force redeploy)
     */
    public function redeployApplication(
        string $applicationId,
        ?string $title = null,
        ?string $description = null
    ): DeploymentDTO {
        try {
            $deployment = DeploymentDTO::forDeploy($applicationId, $title, $description);

            $data = $this->repository->post('/api/application.redeploy', $deployment->toArray());

            Log::info('Redeployed Dokploy application', [
                'applicationId' => $applicationId,
            ]);

            return DeploymentDTO::fromArray($data);
        } catch (Exception $e) {
            Log::error('Failed to redeploy Dokploy application', [
                'applicationId' => $applicationId,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Cancel ongoing deployment
     */
    public function cancelDeployment(string $applicationId): bool
    {
        try {
            $this->repository->post('/api/application.cancelDeployment', [
                'applicationId' => $applicationId,
            ]);

            Log::info('Cancelled Dokploy deployment', [
                'applicationId' => $applicationId,
            ]);

            return true;
        } catch (Exception $e) {
            Log::error('Failed to cancel Dokploy deployment', [
                'applicationId' => $applicationId,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Get deployment status
     */
    public function getDeploymentStatus(string $applicationId): string
    {
        try {
            $application = $this->getApplication($applicationId);
            return $application->applicationStatus ?? 'unknown';
        } catch (Exception $e) {
            Log::error('Failed to get deployment status', [
                'applicationId' => $applicationId,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    // ========== Domain Management ==========

    /**
     * Get domains for application
     */
    public function getDomains(string $applicationId): Collection
    {
        try {
            $data = $this->repository->get('/api/domain.byApplicationId', [
                'applicationId' => $applicationId,
            ]);

            return collect($data)
                ->map(fn($domain) => DomainDTO::fromArray($domain));
        } catch (Exception $e) {
            Log::error('Failed to get Dokploy domains', [
                'applicationId' => $applicationId,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Add domain to application
     */
    public function addDomain(DomainDTO $domain): DomainDTO
    {
        try {
            $data = $this->repository->post('/api/domain.create', $domain->toArray());

            Log::info('Added Dokploy domain', [
                'host' => $domain->host,
                'applicationId' => $domain->applicationId,
            ]);

            return DomainDTO::fromArray($data);
        } catch (Exception $e) {
            Log::error('Failed to add Dokploy domain', [
                'host' => $domain->host,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Update domain
     */
    public function updateDomain(DomainDTO $domain): DomainDTO
    {
        try {
            $data = $this->repository->put('/api/domain.update', $domain->toArray());

            Log::info('Updated Dokploy domain', [
                'domainId' => $domain->domainId,
            ]);

            return DomainDTO::fromArray($data);
        } catch (Exception $e) {
            Log::error('Failed to update Dokploy domain', [
                'domainId' => $domain->domainId,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Remove domain
     */
    public function removeDomain(string $domainId): bool
    {
        try {
            $this->repository->delete('/api/domain.delete', [
                'domainId' => $domainId,
            ]);

            Log::info('Removed Dokploy domain', [
                'domainId' => $domainId,
            ]);

            return true;
        } catch (Exception $e) {
            Log::error('Failed to remove Dokploy domain', [
                'domainId' => $domainId,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    // ========== Environment Management ==========

    /**
     * Get environment variables
     */
    public function getEnvironmentVariables(string $applicationId): EnvironmentDTO
    {
        try {
            $application = $this->getApplication($applicationId);

            return EnvironmentDTO::fromArray([
                'applicationId' => $applicationId,
                'env' => $application->env,
                'buildArgs' => $application->buildArgs,
            ]);
        } catch (Exception $e) {
            Log::error('Failed to get environment variables', [
                'applicationId' => $applicationId,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Set environment variables
     */
    public function setEnvironmentVariables(EnvironmentDTO $environment): bool
    {
        try {
            $this->repository->post('/api/application.saveEnvironment', $environment->toArray());

            Log::info('Set environment variables', [
                'applicationId' => $environment->applicationId,
            ]);

            return true;
        } catch (Exception $e) {
            Log::error('Failed to set environment variables', [
                'applicationId' => $environment->applicationId,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    // ========== Log Management ==========

    /**
     * Get deployment logs
     */
    public function getDeploymentLogs(string $applicationId, int $lines = 100): Collection
    {
        try {
            // This is a simplified version - actual implementation may vary
            $data = $this->repository->get('/api/application.logs', [
                'applicationId' => $applicationId,
                'tail' => $lines,
            ], false); // Don't cache logs

            return collect($data)
                ->map(fn($log) => LogDTO::fromArray($log));
        } catch (Exception $e) {
            Log::error('Failed to get deployment logs', [
                'applicationId' => $applicationId,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    // ========== Health & Monitoring ==========

    /**
     * Test API connection
     */
    public function testConnection(): bool
    {
        return $this->repository->testConnection();
    }

    /**
     * Get API health status
     */
    public function healthCheck(): array
    {
        return $this->repository->healthCheck();
    }

    /**
     * Clear all caches
     */
    public function clearCache(): void
    {
        $this->repository->clearCache();
    }
}
