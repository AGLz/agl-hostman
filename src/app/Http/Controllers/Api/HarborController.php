<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\HarborService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

/**
 * Harbor API Controller
 *
 * RESTful API for managing Harbor container registry
 * Handles projects, repositories, artifacts, and vulnerability scanning
 */
class HarborController extends Controller
{
    public function __construct(
        private HarborService $harbor
    ) {}

    /**
     * Get all projects
     * GET /api/harbor/projects
     */
    public function projects(): JsonResponse
    {
        try {
            $projects = $this->harbor->getProjects();

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
     * Get single project
     * GET /api/harbor/projects/{project}
     */
    public function getProject(string $project): JsonResponse
    {
        try {
            $projectData = $this->harbor->getProject($project);

            return response()->json([
                'success' => true,
                'data' => $projectData->toArray(),
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 404);
        }
    }

    /**
     * Create project
     * POST /api/harbor/projects
     */
    public function createProject(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'public' => 'boolean',
            'enable_content_trust' => 'boolean',
            'enable_content_trust_ci' => 'boolean',
            'prevent_vulnerable_images' => 'boolean',
            'severity' => 'string|in:none,low,medium,high,critical',
            'auto_scan' => 'boolean',
            'storage_limit' => 'integer',
        ]);

        try {
            $project = $this->harbor->createProject($validated);

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
     * Update project
     * PUT /api/harbor/projects/{project}
     */
    public function updateProject(Request $request, string $project): JsonResponse
    {
        $validated = $request->validate([
            'public' => 'boolean',
        ]);

        try {
            $projectData = $this->harbor->updateProject($project, $validated);

            return response()->json([
                'success' => true,
                'data' => $projectData->toArray(),
                'message' => 'Project updated successfully',
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Delete project
     * DELETE /api/harbor/projects/{project}
     */
    public function deleteProject(string $project): JsonResponse
    {
        try {
            $this->harbor->deleteProject($project);

            return response()->json([
                'success' => true,
                'message' => 'Project deleted successfully',
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get repositories for a project
     * GET /api/harbor/repositories
     */
    public function repositories(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'project' => 'required|string',
        ]);

        try {
            $repositories = $this->harbor->getRepositories($validated['project']);

            return response()->json([
                'success' => true,
                'data' => $repositories->toArray(),
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get single repository
     * GET /api/harbor/repositories/{project}/{repository}
     */
    public function getRepository(string $project, string $repository): JsonResponse
    {
        try {
            $repo = $this->harbor->getRepository($project, $repository);

            return response()->json([
                'success' => true,
                'data' => $repo->toArray(),
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 404);
        }
    }

    /**
     * Delete repository
     * DELETE /api/harbor/repositories/{project}/{repository}
     */
    public function deleteRepository(string $project, string $repository): JsonResponse
    {
        try {
            $this->harbor->deleteRepository($project, $repository);

            return response()->json([
                'success' => true,
                'message' => 'Repository deleted successfully',
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get artifacts for a repository
     * GET /api/harbor/artifacts
     */
    public function artifacts(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'project' => 'required|string',
            'repository' => 'required|string',
        ]);

        try {
            $artifacts = $this->harbor->getArtifacts(
                $validated['project'],
                $validated['repository']
            );

            return response()->json([
                'success' => true,
                'data' => $artifacts->toArray(),
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get single artifact
     * GET /api/harbor/artifacts/{project}/{repository}/{reference}
     */
    public function getArtifact(string $project, string $repository, string $reference): JsonResponse
    {
        try {
            $artifact = $this->harbor->getArtifact($project, $repository, $reference);

            return response()->json([
                'success' => true,
                'data' => $artifact->toArray(),
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 404);
        }
    }

    /**
     * Delete artifact
     * DELETE /api/harbor/artifacts/{project}/{repository}/{reference}
     */
    public function deleteArtifact(string $project, string $repository, string $reference): JsonResponse
    {
        try {
            $this->harbor->deleteArtifact($project, $repository, $reference);

            return response()->json([
                'success' => true,
                'message' => 'Artifact deleted successfully',
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Copy artifact
     * POST /api/harbor/artifacts/copy
     */
    public function copyArtifact(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'from_project' => 'required|string',
            'from_repository' => 'required|string',
            'from_reference' => 'required|string',
            'to_project' => 'required|string',
            'to_repository' => 'required|string',
        ]);

        try {
            $this->harbor->copyArtifact(
                $validated['from_project'],
                $validated['from_repository'],
                $validated['from_reference'],
                $validated['to_project'],
                $validated['to_repository']
            );

            return response()->json([
                'success' => true,
                'message' => 'Artifact copied successfully',
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get vulnerability scan results
     * GET /api/harbor/vulnerabilities/{project}/{repository}/{reference}
     */
    public function vulnerabilities(string $project, string $repository, string $reference): JsonResponse
    {
        try {
            $vulnerabilities = $this->harbor->getVulnerabilities($project, $repository, $reference);

            return response()->json([
                'success' => true,
                'data' => $vulnerabilities->toArray(),
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Trigger vulnerability scan
     * POST /api/harbor/scan
     */
    public function triggerScan(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'project' => 'required|string',
            'repository' => 'required|string',
            'reference' => 'required|string',
        ]);

        try {
            $this->harbor->triggerScan(
                $validated['project'],
                $validated['repository'],
                $validated['reference']
            );

            return response()->json([
                'success' => true,
                'message' => 'Vulnerability scan triggered',
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get retention policies
     * GET /api/harbor/retention/{projectId}
     */
    public function retentionPolicies(string $projectId): JsonResponse
    {
        try {
            $policies = $this->harbor->getRetentionPolicies($projectId);

            return response()->json([
                'success' => true,
                'data' => $policies->toArray(),
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Create retention policy
     * POST /api/harbor/retention/{projectId}
     */
    public function createRetentionPolicy(Request $request, string $projectId): JsonResponse
    {
        $validated = $request->validate([
            'tag_pattern' => 'string',
            'keep_last_n' => 'integer|min:1',
        ]);

        try {
            $policy = $this->harbor->createRetentionPolicy($projectId, $validated);

            return response()->json([
                'success' => true,
                'data' => $policy,
                'message' => 'RetentionPolicy created successfully',
            ], 201);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get webhooks
     * GET /api/harbor/webhooks/{projectId}
     */
    public function webhooks(string $projectId): JsonResponse
    {
        try {
            $webhooks = $this->harbor->getWebhooks($projectId);

            return response()->json([
                'success' => true,
                'data' => $webhooks->toArray(),
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Create webhook
     * POST /api/harbor/webhooks/{projectId}
     */
    public function createWebhook(Request $request, string $projectId): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'string',
            'description' => 'string',
            'url' => 'required|url',
            'secret' => 'string',
            'skip_ssl_verify' => 'boolean',
            'events' => 'array',
            'enabled' => 'boolean',
        ]);

        try {
            $webhook = $this->harbor->createWebhook($projectId, $validated);

            return response()->json([
                'success' => true,
                'data' => $webhook,
                'message' => 'Webhook created successfully',
            ], 201);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Delete webhook
     * DELETE /api/harbor/webhooks/{projectId}/{webhookId}
     */
    public function deleteWebhook(string $projectId, int $webhookId): JsonResponse
    {
        try {
            $this->harbor->deleteWebhook($projectId, $webhookId);

            return response()->json([
                'success' => true,
                'message' => 'Webhook deleted successfully',
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get system info
     * GET /api/harbor/system/info
     */
    public function systemInfo(): JsonResponse
    {
        try {
            $info = $this->harbor->getSystemInfo();

            return response()->json([
                'success' => true,
                'data' => $info,
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get health status
     * GET /api/harbor/system/health
     */
    public function health(): JsonResponse
    {
        try {
            $health = $this->harbor->getHealthStatus();

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

    /**
     * Get pull credentials
     * GET /api/harbor/credentials
     */
    public function credentials(): JsonResponse
    {
        try {
            $credentials = $this->harbor->getPullCredentials();

            return response()->json([
                'success' => true,
                'data' => $credentials,
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Test connection
     * GET /api/harbor/test
     */
    public function testConnection(): JsonResponse
    {
        $isConnected = $this->harbor->testConnection();

        return response()->json([
            'success' => $isConnected,
            'connected' => $isConnected,
            'message' => $isConnected
                ? 'Harbor API is accessible'
                : 'Harbor API connection failed',
        ], $isConnected ? 200 : 503);
    }
}
