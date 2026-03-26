<?php

namespace App\Http\Controllers;

use App\Services\N8NService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class N8NController extends Controller
{
    protected N8NService $n8nService;

    public function __construct(N8NService $n8nService)
    {
        $this->n8nService = $n8nService;
    }

    /**
     * Handle incoming webhook from N8N
     */
    public function webhook(Request $request)
    {
        Log::info('N8N webhook received', [
            'payload' => $request->all(),
            'headers' => $request->headers->all(),
        ]);

        $result = $this->n8nService->handleWebhook($request->all());

        return response()->json($result);
    }

    /**
     * Execute a workflow
     */
    public function executeWorkflow(Request $request)
    {
        $request->validate([
            'workflow_id' => 'required|string',
            'data' => 'array',
        ]);

        $result = $this->n8nService->executeWorkflow(
            $request->workflow_id,
            $request->data ?? []
        );

        return response()->json($result);
    }

    /**
     * Trigger infrastructure monitoring
     */
    public function triggerMonitoring(Request $request)
    {
        $request->validate([
            'servers' => 'required|array',
            'servers.*' => 'string',
        ]);

        $result = $this->n8nService->triggerMonitoring($request->servers);

        return response()->json($result);
    }

    /**
     * Trigger AI agent
     */
    public function triggerAI(Request $request)
    {
        $request->validate([
            'model' => 'required|string|in:claude,gemini,codex,abacusai,ollama',
            'prompt' => 'required|string',
            'context' => 'array',
        ]);

        $result = $this->n8nService->triggerAIAgent(
            $request->model,
            $request->prompt,
            $request->context ?? []
        );

        return response()->json($result);
    }

    /**
     * Trigger deployment
     */
    public function triggerDeployment(Request $request)
    {
        $request->validate([
            'service' => 'required|string',
            'environment' => 'required|string|in:production,staging,development',
            'config' => 'array',
        ]);

        $result = $this->n8nService->triggerDeployment(
            $request->service,
            $request->environment,
            $request->config ?? []
        );

        return response()->json($result);
    }

    /**
     * Get workflow status
     */
    public function getStatus($executionId)
    {
        $result = $this->n8nService->getWorkflowStatus($executionId);

        return response()->json($result);
    }

    /**
     * List available workflows
     */
    public function listWorkflows()
    {
        $result = $this->n8nService->listWorkflows();

        return response()->json($result);
    }
}
