<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\DokployService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

/**
 * Dokploy API Controller
 *
 * RESTful API for managing Dokploy deployment platform
 * Handles applications, deployments, services, and domains
 */
class DokployController extends Controller
{
    public function __construct(
        private DokployService $dokploy
    ) {}

    /**
     * List all applications
     * GET /api/dokploy/applications
     */
    public function applications(): JsonResponse
    {
        try {
            // Get projects first, then applications from each project
            $projects = $this->dokploy->getProjects();
            $applications = collect();

            foreach ($projects as $project) {
                // Note: DokployService doesn't have a direct method to get all applications
                // This is a simplified implementation - you may need to enhance DokployService
                $applications = $applications->merge([
                    'project' => $project->name,
                    'project_id' => $project->projectId,
                ]);
            }

            return response()->json([
                'success' => true,
                'data' => $applications->toArray(),
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * List all services
     * GET /api/dokploy/services
     */
    public function services(): JsonResponse
    {
        try {
            $projects = $this->dokploy->getProjects();

            $services = collect();
            foreach ($projects as $project) {
                $services->push([
                    'id' => $project->projectId,
                    'name' => $project->name,
                    'type' => 'project',
                    'status' => 'active',
                ]);
            }

            return response()->json([
                'success' => true,
                'data' => $services->toArray(),
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Deploy application
     * POST /api/dokploy/deploy
     */
    public function deploy(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'application_id' => 'required|string',
            'title' => 'nullable|string',
            'description' => 'nullable|string',
        ]);

        try {
            $deployment = $this->dokploy->deployApplication(
                $validated['application_id'],
                $validated['title'] ?? null,
                $validated['description'] ?? null
            );

            return response()->json([
                'success' => true,
                'data' => $deployment->toArray(),
                'message' => 'Deployment triggered successfully',
            ], 201);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Redeploy application
     * POST /api/dokploy/redeploy
     */
    public function redeploy(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'application_id' => 'required|string',
            'title' => 'nullable|string',
            'description' => 'nullable|string',
        ]);

        try {
            $deployment = $this->dokploy->redeployApplication(
                $validated['application_id'],
                $validated['title'] ?? null,
                $validated['description'] ?? null
            );

            return response()->json([
                'success' => true,
                'data' => $deployment->toArray(),
                'message' => 'Redeployment triggered successfully',
            ], 201);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Start service
     * POST /api/dokploy/services/{id}/start
     */
    public function startService(string $id): JsonResponse
    {
        try {
            $this->dokploy->startApplication($id);

            return response()->json([
                'success' => true,
                'message' => 'Service started successfully',
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Stop service
     * POST /api/dokploy/services/{id}/stop
     */
    public function stopService(string $id): JsonResponse
    {
        try {
            $this->dokploy->stopApplication($id);

            return response()->json([
                'success' => true,
                'message' => 'Service stopped successfully',
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Restart service
     * POST /api/dokploy/services/{id}/restart
     */
    public function restartService(string $id): JsonResponse
    {
        try {
            $this->dokploy->restartApplication($id);

            return response()->json([
                'success' => true,
                'message' => 'Service restarted successfully',
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get deployment status
     * GET /api/dokploy/deployments/{applicationId}/status
     */
    public function deploymentStatus(string $applicationId): JsonResponse
    {
        try {
            $status = $this->dokploy->getDeploymentStatus($applicationId);

            return response()->json([
                'success' => true,
                'data' => [
                    'application_id' => $applicationId,
                    'status' => $status,
                ],
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * List deployments
     * GET /api/dokploy/deployments
     */
    public function deployments(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'application_id' => 'nullable|string',
            'limit' => 'nullable|integer|min:1|max:100',
        ]);

        try {
            // For now, return a basic response
            // You may need to enhance DokployService to support listing deployments
            return response()->json([
                'success' => true,
                'data' => [],
                'message' => 'Deployment history requires implementation in DokployService',
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Cancel deployment
     * POST /api/dokploy/deployments/{applicationId}/cancel
     */
    public function cancelDeployment(string $applicationId): JsonResponse
    {
        try {
            $this->dokploy->cancelDeployment($applicationId);

            return response()->json([
                'success' => true,
                'message' => 'Deployment cancelled successfully',
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get domains for application
     * GET /api/dokploy/domains
     */
    public function domains(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'application_id' => 'required|string',
        ]);

        try {
            $domains = $this->dokploy->getDomains($validated['application_id']);

            return response()->json([
                'success' => true,
                'data' => $domains->toArray(),
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Add domain to application
     * POST /api/dokploy/domains
     */
    public function addDomain(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'application_id' => 'required|string',
            'host' => 'required|string',
            'port' => 'nullable|integer',
            'path' => 'nullable|string',
            'https' => 'boolean',
        ]);

        try {
            $domainDTO = new \App\DTOs\Dokploy\DomainDTO(
                applicationId: $validated['application_id'],
                host: $validated['host'],
                port: $validated['port'] ?? null,
                path: $validated['path'] ?? null,
                https: $validated['https'] ?? true
            );

            $domain = $this->dokploy->addDomain($domainDTO);

            return response()->json([
                'success' => true,
                'data' => $domain->toArray(),
                'message' => 'Domain added successfully',
            ], 201);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Remove domain
     * DELETE /api/dokploy/domains/{domainId}
     */
    public function removeDomain(string $domainId): JsonResponse
    {
        try {
            $this->dokploy->removeDomain($domainId);

            return response()->json([
                'success' => true,
                'message' => 'Domain removed successfully',
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get environment variables
     * GET /api/dokploy/environment
     */
    public function environment(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'application_id' => 'required|string',
        ]);

        try {
            $environment = $this->dokploy->getEnvironmentVariables($validated['application_id']);

            return response()->json([
                'success' => true,
                'data' => $environment->toArray(),
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Set environment variables
     * POST /api/dokploy/environment
     */
    public function setEnvironment(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'application_id' => 'required|string',
            'env' => 'nullable|array',
            'build_args' => 'nullable|array',
        ]);

        try {
            $envDTO = new \App\DTOs\Dokploy\EnvironmentDTO(
                applicationId: $validated['application_id'],
                env: $validated['env'] ?? [],
                buildArgs: $validated['build_args'] ?? []
            );

            $this->dokploy->setEnvironmentVariables($envDTO);

            return response()->json([
                'success' => true,
                'message' => 'Environment variables updated successfully',
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get deployment logs
     * GET /api/dokploy/logs
     */
    public function logs(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'application_id' => 'required|string',
            'lines' => 'nullable|integer|min:1|max:1000',
        ]);

        try {
            $lines = $validated['lines'] ?? 100;
            $logs = $this->dokploy->getDeploymentLogs($validated['application_id'], $lines);

            return response()->json([
                'success' => true,
                'data' => $logs->toArray(),
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get projects
     * GET /api/dokploy/projects
     */
    public function projects(): JsonResponse
    {
        try {
            $projects = $this->dokploy->getProjects();

            return response()->json([
                'success' => true,
                'data' => $projects->toArray(),
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Create project
     * POST /api/dokploy/projects
     */
    public function createProject(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'description' => 'nullable|string',
        ]);

        try {
            $projectDTO = new \App\DTOs\Dokploy\ProjectDTO(
                name: $validated['name'],
                description: $validated['description'] ?? ''
            );

            $project = $this->dokploy->createProject($projectDTO);

            return response()->json([
                'success' => true,
                'data' => $project->toArray(),
                'message' => 'Project created successfully',
            ], 201);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Test connection
     * GET /api/dokploy/test
     */
    public function testConnection(): JsonResponse
    {
        $isConnected = $this->dokploy->testConnection();

        return response()->json([
            'success' => $isConnected,
            'connected' => $isConnected,
            'message' => $isConnected
                ? 'Dokploy API is accessible'
                : 'Dokploy API connection failed',
        ], $isConnected ? 200 : 503);
    }

    /**
     * Get health status
     * GET /api/dokploy/health
     */
    public function health(): JsonResponse
    {
        try {
            $health = $this->dokploy->healthCheck();

            return response()->json([
                'success' => true,
                'data' => $health,
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }
}
