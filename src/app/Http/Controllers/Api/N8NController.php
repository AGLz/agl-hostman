<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\N8NWorkflow;
use App\Services\N8NService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

/**
 * N8N Integration API Controller
 *
 * RESTful API for managing N8N workflows and webhooks
 * Provides endpoints for triggering, syncing, and monitoring workflows
 */
class N8NController extends Controller
{
    public function __construct(
        private N8NService $n8nService
    ) {}

    /**
     * Receive webhook from N8N
     * POST /api/n8n/webhook/{workflow}
     *
     * Public endpoint (no auth required - secured by webhook secret)
     */
    public function webhook(Request $request, string $workflow): JsonResponse
    {
        $signature = $request->header('X-N8N-Signature');
        $payload = $request->all();

        Log::info('N8N webhook received', [
            'workflow' => $workflow,
            'payload' => $payload,
            'ip' => $request->ip(),
        ]);

        $result = $this->n8nService->handleWebhook($payload, $signature);

        return response()->json($result, $result['success'] ? 200 : 400);
    }

    /**
     * Trigger an N8N workflow
     * POST /api/n8n/trigger/{workflow}
     *
     * Authenticated endpoint
     */
    public function trigger(Request $request, string $workflow): JsonResponse
    {
        $validated = $request->validate([
            'data' => 'array',
            'async' => 'boolean',
        ]);

        $workflowModel = N8NWorkflow::where('slug', $workflow)
            ->orWhere('n8n_id', $workflow)
            ->first();

        if (! $workflowModel) {
            return response()->json([
                'success' => false,
                'error' => 'Workflow not found',
                'workflow' => $workflow,
            ], 404);
        }

        if (! $workflowModel->active) {
            return response()->json([
                'success' => false,
                'error' => 'Workflow is not active',
                'workflow' => $workflow,
            ], 400);
        }

        $data = $validated['data'] ?? [];
        $workflowId = $workflowModel->n8n_id ?? $workflow;

        $result = $this->n8nService->executeWorkflow($workflowId, $data);

        if ($result['success']) {
            $workflowModel->incrementExecution();
        }

        return response()->json($result, $result['success'] ? 200 : 500);
    }

    /**
     * List available workflows
     * GET /api/n8n/workflows
     *
     * Returns both local cached and remote N8N workflows
     */
    public function listWorkflows(Request $request): JsonResponse
    {
        $source = $request->query('source', 'local'); // local, remote, all
        $category = $request->query('category');
        $active = $request->query('active');

        $workflows = match ($source) {
            'remote' => $this->getRemoteWorkflows(),
            'all' => $this->getAllWorkflows($category, $active),
            default => $this->getLocalWorkflows($category, $active),
        };

        return response()->json([
            'success' => true,
            'source' => $source,
            'workflows' => $workflows,
            'count' => count($workflows),
        ]);
    }

    /**
     * Sync workflows from N8N
     * POST /api/n8n/sync
     *
     * Pulls latest workflows from N8N and updates local database
     */
    public function sync(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'force' => 'boolean',
        ]);

        $result = $this->n8nService->syncWorkflows();

        return response()->json($result, $result['success'] ? 200 : 500);
    }

    /**
     * Get workflow execution status
     * GET /api/n8n/status/{executionId}
     */
    public function getStatus(string $executionId): JsonResponse
    {
        $result = $this->n8nService->getWorkflowStatus($executionId);

        return response()->json($result, $result['success'] ? 200 : 404);
    }

    /**
     * Create a new workflow
     * POST /api/n8n/workflows
     */
    public function createWorkflow(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'description' => 'nullable|string',
            'nodes' => 'required|array',
            'connections' => 'required|array',
            'settings' => 'nullable|array',
            'static_data' => 'nullable|array',
            'tags' => 'nullable|array',
            'active' => 'boolean',
        ]);

        $workflowData = [
            'name' => $validated['name'],
            'nodes' => $validated['nodes'],
            'connections' => $validated['connections'],
            'settings' => $validated['settings'] ?? [],
            'staticData' => $validated['static_data'] ?? null,
            'tags' => $validated['tags'] ?? [],
            'active' => $validated['active'] ?? false,
        ];

        $result = $this->n8nService->createWorkflow($workflowData);

        return response()->json($result, $result['success'] ? 201 : 500);
    }

    /**
     * Update a workflow
     * PUT /api/n8n/workflows/{workflow}
     */
    public function updateWorkflow(Request $request, string $workflow): JsonResponse
    {
        $workflowModel = N8NWorkflow::where('slug', $workflow)
            ->orWhere('n8n_id', $workflow)
            ->first();

        if (! $workflowModel) {
            return response()->json([
                'success' => false,
                'error' => 'Workflow not found',
            ], 404);
        }

        $validated = $request->validate([
            'name' => 'string|max:255',
            'description' => 'nullable|string',
            'nodes' => 'array',
            'connections' => 'array',
            'settings' => 'array',
            'active' => 'boolean',
        ]);

        $result = $this->n8nService->updateWorkflow(
            $workflowModel->n8n_id,
            array_filter($validated, fn ($v) => $v !== null)
        );

        return response()->json($result, $result['success'] ? 200 : 500);
    }

    /**
     * Delete a workflow
     * DELETE /api/n8n/workflows/{workflow}
     */
    public function deleteWorkflow(string $workflow): JsonResponse
    {
        $workflowModel = N8NWorkflow::where('slug', $workflow)
            ->orWhere('n8n_id', $workflow)
            ->first();

        if (! $workflowModel) {
            return response()->json([
                'success' => false,
                'error' => 'Workflow not found',
            ], 404);
        }

        $result = $this->n8nService->deleteWorkflow($workflowModel->n8n_id);

        return response()->json($result, $result['success'] ? 200 : 500);
    }

    /**
     * Activate a workflow
     * POST /api/n8n/workflows/{workflow}/activate
     */
    public function activateWorkflow(string $workflow): JsonResponse
    {
        $workflowModel = N8NWorkflow::where('slug', $workflow)
            ->orWhere('n8n_id', $workflow)
            ->first();

        if (! $workflowModel) {
            return response()->json([
                'success' => false,
                'error' => 'Workflow not found',
            ], 404);
        }

        $result = $this->n8nService->activateWorkflow($workflowModel->n8n_id);

        return response()->json($result, $result['success'] ? 200 : 500);
    }

    /**
     * Deactivate a workflow
     * POST /api/n8n/workflows/{workflow}/deactivate
     */
    public function deactivateWorkflow(string $workflow): JsonResponse
    {
        $workflowModel = N8NWorkflow::where('slug', $workflow)
            ->orWhere('n8n_id', $workflow)
            ->first();

        if (! $workflowModel) {
            return response()->json([
                'success' => false,
                'error' => 'Workflow not found',
            ], 404);
        }

        $result = $this->n8nService->deactivateWorkflow($workflowModel->n8n_id);

        return response()->json($result, $result['success'] ? 200 : 500);
    }

    /**
     * Get workflow statistics
     * GET /api/n8n/statistics
     */
    public function statistics(): JsonResponse
    {
        $stats = $this->n8nService->getStatistics();

        return response()->json([
            'success' => true,
            'statistics' => $stats,
        ]);
    }

    /**
     * Test N8N connection
     * GET /api/n8n/test-connection
     */
    public function testConnection(): JsonResponse
    {
        $result = $this->n8nService->testConnection();

        return response()->json($result, $result['connected'] ? 200 : 503);
    }

    /**
     * Get workflow executions
     * GET /api/n8n/workflows/{workflow}/executions
     */
    public function executions(Request $request, string $workflow): JsonResponse
    {
        $workflowModel = N8NWorkflow::where('slug', $workflow)
            ->orWhere('n8n_id', $workflow)
            ->first();

        if (! $workflowModel) {
            return response()->json([
                'success' => false,
                'error' => 'Workflow not found',
            ], 404);
        }

        $status = $request->query('status');
        $limit = min((int) $request->query('limit', 50), 100);

        $query = $workflowModel->executions();

        if ($status) {
            $query->where('status', $status);
        }

        $executions = $query->latest('started_at')
            ->limit($limit)
            ->get();

        return response()->json([
            'success' => true,
            'executions' => $executions,
            'count' => $executions->count(),
        ]);
    }

    /**
     * Get workflow details
     * GET /api/n8n/workflows/{workflow}
     */
    public function showWorkflow(string $workflow): JsonResponse
    {
        $workflowModel = N8NWorkflow::where('slug', $workflow)
            ->orWhere('n8n_id', $workflow)
            ->with('executions')
            ->first();

        if (! $workflowModel) {
            return response()->json([
                'success' => false,
                'error' => 'Workflow not found',
            ], 404);
        }

        return response()->json([
            'success' => true,
            'workflow' => $workflowModel->load('executions'),
            'statistics' => $workflowModel->getStatistics(),
        ]);
    }

    /**
     * Get local workflows from database
     */
    protected function getLocalWorkflows(?string $category, ?string $active): array
    {
        $query = N8NWorkflow::query();

        if ($category) {
            $query->byCategory($category);
        }

        if ($active !== null) {
            $query->where('active', $active === 'true');
        }

        return $query->with('executions')
            ->get()
            ->map(fn ($w) => [
                'id' => $w->id,
                'n8n_id' => $w->n8n_id,
                'name' => $w->name,
                'slug' => $w->slug,
                'description' => $w->description,
                'active' => $w->active,
                'category' => $w->category,
                'tags' => $w->tags,
                'execution_count' => $w->execution_count,
                'last_executed_at' => $w->last_executed_at?->toIso8601String(),
                'is_synced' => $w->isSynced(),
                'statistics' => $w->getStatistics(),
            ])
            ->toArray();
    }

    /**
     * Get remote workflows from N8N API
     */
    protected function getRemoteWorkflows(): array
    {
        $result = $this->n8nService->listWorkflows();

        if (! $result['success']) {
            return [];
        }

        return $result['workflows'];
    }

    /**
     * Get all workflows (merge local and remote)
     */
    protected function getAllWorkflows(?string $category, ?string $active): array
    {
        $local = collect($this->getLocalWorkflows($category, $active));
        $remote = collect($this->getRemoteWorkflows());

        // Merge by n8n_id, giving precedence to local data
        return $remote->map(function ($remoteWorkflow) use ($local) {
            $localWorkflow = $local->firstWhere('n8n_id', $remoteWorkflow['id']);

            return $localWorkflow ?? [
                'id' => null,
                'n8n_id' => $remoteWorkflow['id'],
                'name' => $remoteWorkflow['name'],
                'active' => $remoteWorkflow['active'] ?? false,
                'category' => null,
                'tags' => $remoteWorkflow['tags'] ?? [],
                'execution_count' => 0,
                'is_synced' => false,
            ];
        })->toArray();
    }
}
