<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\Dokploy;

use App\Http\Controllers\Controller;
use App\Services\DokployApiClient;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Dokploy Application API Controller
 *
 * RESTful API for managing Dokploy applications
 * Integrates with Dokploy deployment platform (CT180)
 */
class DokployApplicationController extends Controller
{
    public function __construct(
        private DokployApiClient $dokploy
    ) {}

    /**
     * List all applications
     * GET /api/dokploy/applications
     */
    public function index(): JsonResponse
    {
        try {
            $response = $this->dokploy->getApplications();

            return response()->json([
                'success' => true,
                'data' => $response->getData(),
            ], 200);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get single application
     * GET /api/dokploy/applications/{applicationId}
     */
    public function show(string $applicationId): JsonResponse
    {
        try {
            $response = $this->dokploy->getApplication($applicationId);

            return response()->json([
                'success' => true,
                'data' => $response->getData(),
            ], 200);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 404);
        }
    }

    /**
     * Create new application
     * POST /api/dokploy/applications
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'appName' => 'required|string|max:255',
            'description' => 'nullable|string',
            'projectId' => 'required|string',
            'serverId' => 'nullable|string',
            // Docker Image deployment
            'sourceType' => 'nullable|in:docker,git,github,gitlab',
            'dockerImage' => 'nullable|string',
            'username' => 'nullable|string', // Docker registry username
            'password' => 'nullable|string', // Docker registry password
            // Git deployment
            'repository' => 'nullable|string',
            'branch' => 'nullable|string',
            'buildPath' => 'nullable|string',
            // Configuration
            'env' => 'nullable|string',
            'command' => 'nullable|string',
            'ports' => 'nullable|array',
        ]);

        try {
            $response = $this->dokploy->createApplication($validated);

            return response()->json([
                'success' => true,
                'data' => $response->getData(),
                'message' => 'Application created successfully',
            ], 201);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Start application
     * POST /api/dokploy/applications/{applicationId}/start
     */
    public function start(string $applicationId): JsonResponse
    {
        try {
            $response = $this->dokploy->startApplication($applicationId);

            return response()->json([
                'success' => true,
                'data' => $response->getData(),
                'message' => 'Application started successfully',
            ], 200);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Stop application
     * POST /api/dokploy/applications/{applicationId}/stop
     */
    public function stop(string $applicationId): JsonResponse
    {
        try {
            $response = $this->dokploy->stopApplication($applicationId);

            return response()->json([
                'success' => true,
                'data' => $response->getData(),
                'message' => 'Application stopped successfully',
            ], 200);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Redeploy application (trigger new deployment)
     * POST /api/dokploy/applications/{applicationId}/redeploy
     */
    public function redeploy(string $applicationId): JsonResponse
    {
        try {
            $response = $this->dokploy->redeployApplication($applicationId);

            return response()->json([
                'success' => true,
                'data' => $response->getData(),
                'message' => 'Application redeployment triggered',
            ], 200);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Delete application
     * DELETE /api/dokploy/applications/{applicationId}
     */
    public function destroy(string $applicationId): JsonResponse
    {
        try {
            $response = $this->dokploy->deleteApplication($applicationId);

            return response()->json([
                'success' => true,
                'data' => $response->getData(),
                'message' => 'Application deleted successfully',
            ], 200);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get all projects
     * GET /api/dokploy/projects
     */
    public function projects(): JsonResponse
    {
        try {
            $response = $this->dokploy->getProjects();

            return response()->json([
                'success' => true,
                'data' => $response->getData(),
            ], 200);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Test Dokploy API connection
     * GET /api/dokploy/test-connection
     */
    public function testConnection(): JsonResponse
    {
        $isConnected = $this->dokploy->testConnection();
        $circuitBreaker = $this->dokploy->getCircuitBreakerStatus();

        return response()->json([
            'success' => $isConnected,
            'connected' => $isConnected,
            'circuit_breaker' => $circuitBreaker,
            'message' => $isConnected
                ? 'Dokploy API is accessible'
                : 'Dokploy API connection failed',
        ], $isConnected ? 200 : 503);
    }
}
