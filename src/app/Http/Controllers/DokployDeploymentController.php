<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Models\DokployDeployment;
use App\Services\DokployService;
use Exception;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Dokploy Deployment Controller
 *
 * Handles deployment operations (rollback, cancel, etc.)
 */
class DokployDeploymentController extends Controller
{
    public function __construct(
        private readonly DokployService $dokployService
    ) {}

    /**
     * Show deployment details
     */
    public function show(string $id): JsonResponse
    {
        try {
            $deployment = DokployDeployment::with(['application'])->findOrFail($id);

            return response()->json([
                'success' => true,
                'deployment' => $deployment,
            ]);
        } catch (Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Deployment not found',
            ], 404);
        }
    }

    /**
     * Rollback to specific deployment
     */
    public function rollback(string $id): JsonResponse
    {
        try {
            $deployment = DokployDeployment::with('application')->findOrFail($id);

            // Redeploy the application with the same configuration
            $newDeployment = $this->dokployService->redeployApplication(
                $deployment->application->dokploy_id,
                "Rollback to deployment #{$id}",
                'Automated rollback to previous version'
            );

            // Create rollback deployment record
            $rollbackDeployment = DokployDeployment::create([
                'application_id' => $deployment->application_id,
                'dokploy_id' => $newDeployment->deploymentId ?? null,
                'status' => 'running',
                'title' => "Rollback to deployment #{$id}",
                'description' => 'Automated rollback',
                'is_rollback' => true,
                'rollback_from_id' => $id,
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Rollback initiated successfully',
                'deployment' => $rollbackDeployment,
            ]);
        } catch (Exception $e) {
            \Log::error('Rollback failed', [
                'deployment_id' => $id,
                'error' => $e->getMessage(),
            ]);

            return response()->json([
                'success' => false,
                'message' => 'Rollback failed: '.$e->getMessage(),
            ], 500);
        }
    }

    /**
     * Cancel ongoing deployment
     */
    public function cancel(string $id): JsonResponse
    {
        try {
            $deployment = DokployDeployment::with('application')->findOrFail($id);

            if ($deployment->status !== 'running') {
                return response()->json([
                    'success' => false,
                    'message' => 'Only running deployments can be cancelled',
                ], 400);
            }

            $this->dokployService->cancelDeployment($deployment->application->dokploy_id);

            $deployment->update([
                'status' => 'cancelled',
                'completed_at' => now(),
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Deployment cancelled successfully',
            ]);
        } catch (Exception $e) {
            \Log::error('Cancel deployment failed', [
                'deployment_id' => $id,
                'error' => $e->getMessage(),
            ]);

            return response()->json([
                'success' => false,
                'message' => 'Cancel failed: '.$e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get deployment logs
     */
    public function logs(string $id): JsonResponse
    {
        try {
            $deployment = DokployDeployment::with('application')->findOrFail($id);

            $logs = $this->dokployService->getDeploymentLogs(
                $deployment->application->dokploy_id,
                500
            );

            return response()->json([
                'success' => true,
                'logs' => $logs,
            ]);
        } catch (Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to fetch logs',
            ], 500);
        }
    }

    /**
     * Get deployment timeline for application
     */
    public function timeline(Request $request): JsonResponse
    {
        try {
            $applicationId = $request->input('application_id');

            if (! $applicationId) {
                return response()->json([
                    'success' => false,
                    'message' => 'Application ID is required',
                ], 400);
            }

            $deployments = DokployDeployment::where('application_id', $applicationId)
                ->with('application')
                ->latest()
                ->limit(50)
                ->get();

            return response()->json([
                'success' => true,
                'deployments' => $deployments,
            ]);
        } catch (Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to fetch timeline',
            ], 500);
        }
    }
}
