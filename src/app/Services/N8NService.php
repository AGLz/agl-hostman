<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use App\Models\User;

class N8NService
{
    protected string $apiUrl;
    protected ?string $apiKey;
    protected array $defaultHeaders;

    public function __construct()
    {
        $this->apiUrl = rtrim(config('services.n8n.api_url'), '/');
        $this->apiKey = config('services.n8n.api_key');
        
        $this->defaultHeaders = [
            'Accept' => 'application/json',
            'Content-Type' => 'application/json',
        ];
        
        if ($this->apiKey) {
            $this->defaultHeaders['X-N8N-API-KEY'] = $this->apiKey;
        }
    }

    /**
     * Execute a workflow in N8N
     */
    public function executeWorkflow(string $workflowId, array $data = []): array
    {
        try {
            $response = Http::withHeaders($this->defaultHeaders)
                ->timeout(30)
                ->post("{$this->apiUrl}/webhook/{$workflowId}", $data);

            if ($response->successful()) {
                return [
                    'success' => true,
                    'data' => $response->json(),
                    'status' => $response->status(),
                ];
            }

            Log::error('N8N workflow execution failed', [
                'workflow_id' => $workflowId,
                'status' => $response->status(),
                'response' => $response->body(),
            ]);

            return [
                'success' => false,
                'error' => 'Workflow execution failed',
                'status' => $response->status(),
            ];
        } catch (\Exception $e) {
            Log::error('N8N service error', [
                'workflow_id' => $workflowId,
                'error' => $e->getMessage(),
            ]);

            return [
                'success' => false,
                'error' => $e->getMessage(),
            ];
        }
    }

    /**
     * Trigger infrastructure monitoring workflow
     */
    public function triggerMonitoring(array $servers): array
    {
        $workflowId = config('services.n8n.workflows.monitoring');
        
        return $this->executeWorkflow($workflowId, [
            'servers' => $servers,
            'timestamp' => now()->toIso8601String(),
            'type' => 'infrastructure_monitoring',
        ]);
    }

    /**
     * Trigger AI agent workflow
     */
    public function triggerAIAgent(string $model, string $prompt, array $context = []): array
    {
        $workflowId = config('services.n8n.workflows.ai_agent');
        
        return $this->executeWorkflow($workflowId, [
            'model' => $model,
            'prompt' => $prompt,
            'context' => $context,
            'timestamp' => now()->toIso8601String(),
            'type' => 'ai_agent_request',
        ]);
    }

    /**
     * Trigger deployment workflow
     */
    public function triggerDeployment(string $service, string $environment, array $config = []): array
    {
        $workflowId = config('services.n8n.workflows.deployment');
        
        return $this->executeWorkflow($workflowId, [
            'service' => $service,
            'environment' => $environment,
            'config' => $config,
            'timestamp' => now()->toIso8601String(),
            'type' => 'deployment_request',
        ]);
    }

    /**
     * Handle incoming webhook from N8N
     */
    public function handleWebhook(array $payload): array
    {
        $type = $payload['type'] ?? null;
        
        switch ($type) {
            case 'monitoring_alert':
                return $this->processMonitoringAlert($payload);
            
            case 'ai_response':
                return $this->processAIResponse($payload);
            
            case 'deployment_status':
                return $this->processDeploymentStatus($payload);
            
            case 'workflow_error':
                return $this->processWorkflowError($payload);
            
            default:
                Log::warning('Unknown N8N webhook type', ['type' => $type]);
                return ['success' => false, 'error' => 'Unknown webhook type'];
        }
    }

    /**
     * Process monitoring alert from N8N
     */
    protected function processMonitoringAlert(array $payload): array
    {
        Log::info('Monitoring alert received', $payload);
        
        // Process alert logic here
        // Could create notification, update status, etc.
        
        return ['success' => true, 'processed' => 'monitoring_alert'];
    }

    /**
     * Process AI response from N8N
     */
    protected function processAIResponse(array $payload): array
    {
        Log::info('AI response received', $payload);
        
        // Process AI response logic here
        // Could store in database, update task, etc.
        
        return ['success' => true, 'processed' => 'ai_response'];
    }

    /**
     * Process deployment status from N8N
     */
    protected function processDeploymentStatus(array $payload): array
    {
        Log::info('Deployment status received', $payload);
        
        // Process deployment status logic here
        // Could update deployment record, notify user, etc.
        
        return ['success' => true, 'processed' => 'deployment_status'];
    }

    /**
     * Process workflow error from N8N
     */
    protected function processWorkflowError(array $payload): array
    {
        Log::error('Workflow error received', $payload);
        
        // Process error logic here
        // Could create incident, notify admin, etc.
        
        return ['success' => true, 'processed' => 'workflow_error'];
    }

    /**
     * Get workflow status from N8N
     */
    public function getWorkflowStatus(string $executionId): array
    {
        try {
            $response = Http::withHeaders($this->defaultHeaders)
                ->timeout(10)
                ->get("{$this->apiUrl}/executions/{$executionId}");

            if ($response->successful()) {
                return [
                    'success' => true,
                    'data' => $response->json(),
                ];
            }

            return [
                'success' => false,
                'error' => 'Failed to get workflow status',
                'status' => $response->status(),
            ];
        } catch (\Exception $e) {
            Log::error('N8N status check error', [
                'execution_id' => $executionId,
                'error' => $e->getMessage(),
            ]);

            return [
                'success' => false,
                'error' => $e->getMessage(),
            ];
        }
    }

    /**
     * List available workflows
     */
    public function listWorkflows(): array
    {
        try {
            $response = Http::withHeaders($this->defaultHeaders)
                ->timeout(10)
                ->get("{$this->apiUrl}/workflows");

            if ($response->successful()) {
                return [
                    'success' => true,
                    'workflows' => $response->json()['data'] ?? [],
                ];
            }

            return [
                'success' => false,
                'error' => 'Failed to list workflows',
                'status' => $response->status(),
            ];
        } catch (\Exception $e) {
            Log::error('N8N list workflows error', [
                'error' => $e->getMessage(),
            ]);

            return [
                'success' => false,
                'error' => $e->getMessage(),
            ];
        }
    }
}