<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Services\DokployService;
use App\Models\DokployApplication;
use App\Models\DokployDeployment;
use App\Models\DokployDomain;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Inertia\Inertia;
use Inertia\Response;
use Exception;

/**
 * Dokploy Application Controller
 *
 * Handles application management and deployment operations
 */
class DokployApplicationController extends Controller
{
    public function __construct(
        private readonly DokployService $dokployService
    ) {}

    /**
     * Show application details
     */
    public function show(string $id): Response
    {
        try {
            $application = DokployApplication::with([
                'project',
                'deployments' => function ($query) {
                    $query->latest()->limit(20);
                },
            ])->findOrFail($id);

            // Fetch fresh data from Dokploy API
            $apiApplication = $this->dokployService->getApplication($application->dokploy_id);

            // Get domains
            $domains = DokployDomain::where('application_id', $id)->get();

            return Inertia::render('Dokploy/ApplicationShow', [
                'application' => array_merge($application->toArray(), $apiApplication->toArray()),
                'deployments' => $application->deployments,
                'domains' => $domains,
                'project' => $application->project,
            ]);
        } catch (Exception $e) {
            \Log::error('Failed to load application', [
                'id' => $id,
                'error' => $e->getMessage(),
            ]);

            abort(404, 'Application not found');
        }
    }

    /**
     * Deploy application
     */
    public function deploy(Request $request, string $id): JsonResponse
    {
        try {
            $application = DokployApplication::findOrFail($id);

            $validated = $request->validate([
                'title' => 'nullable|string|max:255',
                'description' => 'nullable|string|max:1000',
            ]);

            // Trigger deployment via Dokploy API
            $deployment = $this->dokployService->deployApplication(
                $application->dokploy_id,
                $validated['title'] ?? null,
                $validated['description'] ?? null
            );

            // Create local deployment record
            DokployDeployment::create([
                'application_id' => $id,
                'dokploy_id' => $deployment->deploymentId ?? null,
                'status' => 'running',
                'title' => $validated['title'] ?? null,
                'description' => $validated['description'] ?? null,
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Deployment started successfully',
                'deployment' => $deployment,
            ]);
        } catch (Exception $e) {
            \Log::error('Deployment failed', [
                'application_id' => $id,
                'error' => $e->getMessage(),
            ]);

            return response()->json([
                'success' => false,
                'message' => 'Deployment failed: ' . $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Stop application
     */
    public function stop(string $id): JsonResponse
    {
        try {
            $application = DokployApplication::findOrFail($id);

            $this->dokployService->stopApplication($application->dokploy_id);

            $application->update(['status' => 'stopped']);

            return response()->json([
                'success' => true,
                'message' => 'Application stopped successfully',
            ]);
        } catch (Exception $e) {
            \Log::error('Stop failed', [
                'application_id' => $id,
                'error' => $e->getMessage(),
            ]);

            return response()->json([
                'success' => false,
                'message' => 'Stop failed: ' . $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Restart application
     */
    public function restart(string $id): JsonResponse
    {
        try {
            $application = DokployApplication::findOrFail($id);

            $this->dokployService->restartApplication($application->dokploy_id);

            $application->update(['status' => 'running']);

            return response()->json([
                'success' => true,
                'message' => 'Application restarted successfully',
            ]);
        } catch (Exception $e) {
            \Log::error('Restart failed', [
                'application_id' => $id,
                'error' => $e->getMessage(),
            ]);

            return response()->json([
                'success' => false,
                'message' => 'Restart failed: ' . $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get application status
     */
    public function status(string $id): JsonResponse
    {
        try {
            $application = DokployApplication::findOrFail($id);

            $status = $this->dokployService->getDeploymentStatus($application->dokploy_id);

            return response()->json([
                'success' => true,
                'status' => $status,
            ]);
        } catch (Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to get status',
            ], 500);
        }
    }

    /**
     * Get deployment logs
     */
    public function logs(Request $request, string $id): JsonResponse
    {
        try {
            $application = DokployApplication::findOrFail($id);

            $lines = $request->input('lines', 100);

            $logs = $this->dokployService->getDeploymentLogs(
                $application->dokploy_id,
                (int) $lines
            );

            return response()->json([
                'success' => true,
                'logs' => $logs->map(fn($log) => [
                    'timestamp' => $log->timestamp,
                    'level' => $log->level,
                    'message' => $log->message,
                ]),
            ]);
        } catch (Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to fetch logs',
            ], 500);
        }
    }

    /**
     * Stream deployment logs via SSE
     */
    public function streamLogs(Request $request, string $id)
    {
        $application = DokployApplication::findOrFail($id);

        return response()->stream(function () use ($application) {
            // Set headers for SSE
            header('Content-Type: text/event-stream');
            header('Cache-Control: no-cache');
            header('Connection: keep-alive');
            header('X-Accel-Buffering: no');

            // Keep connection alive
            while (true) {
                try {
                    // Fetch latest logs
                    $logs = $this->dokployService->getDeploymentLogs($application->dokploy_id, 10);

                    foreach ($logs as $log) {
                        echo "data: " . json_encode([
                            'timestamp' => $log->timestamp,
                            'level' => $log->level,
                            'message' => $log->message,
                        ]) . "\n\n";
                        ob_flush();
                        flush();
                    }

                    sleep(2); // Poll every 2 seconds
                } catch (Exception $e) {
                    echo "data: " . json_encode(['error' => $e->getMessage()]) . "\n\n";
                    break;
                }
            }
        }, 200, [
            'Content-Type' => 'text/event-stream',
            'Cache-Control' => 'no-cache',
            'Connection' => 'keep-alive',
            'X-Accel-Buffering' => 'no',
        ]);
    }
}
