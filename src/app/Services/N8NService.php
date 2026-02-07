<?php

declare(strict_types=1);

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Cache;
use App\Models\N8NWorkflow;
use Exception;
use Illuminate\Support\Str;

/**
 * Comprehensive N8N Integration Service
 *
 * Handles N8N webhook triggers, workflow management, and API interactions
 * with retry logic, error handling, and authentication support.
 */
class N8NService
{
    protected string $apiUrl;
    protected ?string $apiKey;
    protected ?string $webhookSecret;
    protected array $defaultHeaders;
    protected int $maxRetries;
    protected int $timeout;
    protected array $circuitBreaker = [
        'failures' => 0,
        'last_failure' => null,
        'threshold' => 5,
        'timeout' => 60,
    ];

    public function __construct()
    {
        $n8nConfig = config('n8n');

        $this->apiUrl = rtrim($n8nConfig['api_url'] ?? env('N8N_API_URL', 'http://n8n:5678'), '/');
        $this->apiKey = $n8nConfig['api_key'] ?? env('N8N_API_KEY');
        $this->webhookSecret = $n8nConfig['webhook_secret'] ?? env('N8N_WEBHOOK_SECRET');
        $this->maxRetries = $n8nConfig['max_retries'] ?? 3;
        $this->timeout = $n8nConfig['timeout'] ?? 30;
        $this->circuitBreaker['threshold'] = $n8nConfig['circuit_breaker']['threshold'] ?? 5;
        $this->circuitBreaker['timeout'] = $n8nConfig['circuit_breaker']['timeout'] ?? 60;

        $this->defaultHeaders = [
            'Accept' => 'application/json',
            'Content-Type' => 'application/json',
        ];

        if ($this->apiKey) {
            $this->defaultHeaders['X-N8N-API-KEY'] = $this->apiKey;
        }
    }

    /**
     * Execute a workflow in N8N with retry logic
     */
    public function executeWorkflow(string $workflowId, array $data = [], array $options = []): array
    {
        if (!$this->isCircuitBreakerOpen()) {
            return $this->executeWithRetry($workflowId, $data, $options);
        }

        return [
            'success' => false,
            'error' => 'Circuit breaker is open. N8N service is temporarily unavailable.',
            'retry_after' => $this->getRetryAfter(),
        ];
    }

    /**
     * Execute webhook with retry logic
     */
    public function triggerWebhook(string $webhookPath, array $data = []): array
    {
        $url = $this->getWebhookUrl($webhookPath);

        return $this->executeWithRetry('webhook', $data, ['url' => $url]);
    }

    /**
     * Execute operation with exponential backoff retry
     */
    protected function executeWithRetry(string $workflowId, array $data, array $options = []): array
    {
        $attempt = 0;
        $lastError = null;
        $delay = 500; // Start with 500ms

        while ($attempt < $this->maxRetries) {
            $attempt++;

            try {
                $url = $options['url'] ?? "{$this->apiUrl}/webhook/{$workflowId}";
                $method = $options['method'] ?? 'POST';
                $timeout = $options['timeout'] ?? $this->timeout;

                $response = Http::withHeaders($this->defaultHeaders)
                    ->timeout($timeout)
                    ->send($method, $url, [
                        'json' => $data,
                    ]);

                if ($response->successful()) {
                    $this->resetCircuitBreaker();

                    $responseData = $response->json();

                    // Store execution log if workflow exists in database
                    if (isset($responseData['executionId'])) {
                        $this->logWorkflowExecution($workflowId, $responseData['executionId'], 'success', $data);
                    }

                    return [
                        'success' => true,
                        'data' => $responseData,
                        'status' => $response->status(),
                        'attempt' => $attempt,
                    ];
                }

                $lastError = [
                    'status' => $response->status(),
                    'body' => $response->body(),
                ];

                Log::warning('N8N request failed', [
                    'workflow_id' => $workflowId,
                    'attempt' => $attempt,
                    'status' => $response->status(),
                    'response' => $response->body(),
                ]);

            } catch (Exception $e) {
                $lastError = [
                    'message' => $e->getMessage(),
                    'code' => $e->getCode(),
                ];

                Log::warning('N8N request exception', [
                    'workflow_id' => $workflowId,
                    'attempt' => $attempt,
                    'error' => $e->getMessage(),
                ]);
            }

            // Don't retry on the last attempt
            if ($attempt < $this->maxRetries) {
                usleep($delay * 1000); // Convert to microseconds
                $delay *= 1.5; // Exponential backoff
            }
        }

        $this->recordCircuitBreakerFailure();

        // Log failed execution
        $this->logWorkflowExecution($workflowId, null, 'failed', $data, $lastError);

        return [
            'success' => false,
            'error' => 'Workflow execution failed after ' . $this->maxRetries . ' attempts',
            'attempts' => $attempt,
            'last_error' => $lastError,
        ];
    }

    /**
     * Create a new workflow dynamically in N8N
     */
    public function createWorkflow(array $workflowData): array
    {
        try {
            $response = Http::withHeaders($this->defaultHeaders)
                ->timeout($this->timeout)
                ->post("{$this->apiUrl}/workflows", $workflowData);

            if ($response->successful()) {
                $data = $response->json();

                // Store workflow metadata in database
                $workflow = N8NWorkflow::create([
                    'n8n_id' => $data['id'],
                    'name' => $workflowData['name'] ?? 'Unnamed Workflow',
                    'description' => $workflowData['description'] ?? null,
                    'active' => $data['active'] ?? false,
                    'settings' => $data['nodes'] ?? [],
                    'metadata' => [
                        'created_via' => 'api',
                        'tags' => $workflowData['tags'] ?? [],
                    ],
                ]);

                return [
                    'success' => true,
                    'workflow' => $data,
                    'local_id' => $workflow->id,
                ];
            }

            return [
                'success' => false,
                'error' => 'Failed to create workflow',
                'status' => $response->status(),
                'response' => $response->body(),
            ];

        } catch (Exception $e) {
            Log::error('N8N create workflow error', [
                'error' => $e->getMessage(),
                'workflow_data' => $workflowData,
            ]);

            return [
                'success' => false,
                'error' => $e->getMessage(),
            ];
        }
    }

    /**
     * Update an existing workflow
     */
    public function updateWorkflow(string $workflowId, array $updates): array
    {
        try {
            $response = Http::withHeaders($this->defaultHeaders)
                ->timeout($this->timeout)
                ->patch("{$this->apiUrl}/workflows/{$workflowId}", $updates);

            if ($response->successful()) {
                $data = $response->json();

                // Update local workflow record
                $localWorkflow = N8NWorkflow::where('n8n_id', $workflowId)->first();
                if ($localWorkflow) {
                    $localWorkflow->update([
                        'name' => $updates['name'] ?? $localWorkflow->name,
                        'description' => $updates['description'] ?? $localWorkflow->description,
                        'active' => $data['active'] ?? $localWorkflow->active,
                        'settings' => $updates['nodes'] ?? $localWorkflow->settings,
                    ]);
                }

                return [
                    'success' => true,
                    'workflow' => $data,
                ];
            }

            return [
                'success' => false,
                'error' => 'Failed to update workflow',
                'status' => $response->status(),
            ];

        } catch (Exception $e) {
            Log::error('N8N update workflow error', [
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
     * Activate a workflow
     */
    public function activateWorkflow(string $workflowId): array
    {
        return $this->updateWorkflow($workflowId, ['active' => true]);
    }

    /**
     * Deactivate a workflow
     */
    public function deactivateWorkflow(string $workflowId): array
    {
        return $this->updateWorkflow($workflowId, ['active' => false]);
    }

    /**
     * Delete a workflow
     */
    public function deleteWorkflow(string $workflowId): array
    {
        try {
            $response = Http::withHeaders($this->defaultHeaders)
                ->timeout($this->timeout)
                ->delete("{$this->apiUrl}/workflows/{$workflowId}");

            if ($response->successful()) {
                // Delete local workflow record
                N8NWorkflow::where('n8n_id', $workflowId)->delete();

                return [
                    'success' => true,
                    'message' => 'Workflow deleted successfully',
                ];
            }

            return [
                'success' => false,
                'error' => 'Failed to delete workflow',
                'status' => $response->status(),
            ];

        } catch (Exception $e) {
            Log::error('N8N delete workflow error', [
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
     * Get workflow execution status
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

        } catch (Exception $e) {
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
     * List all workflows from N8N API
     */
    public function listWorkflows(): array
    {
        try {
            $response = Http::withHeaders($this->defaultHeaders)
                ->timeout(10)
                ->get("{$this->apiUrl}/workflows");

            if ($response->successful()) {
                $workflows = $response->json()['data'] ?? [];

                return [
                    'success' => true,
                    'workflows' => $workflows,
                    'count' => count($workflows),
                ];
            }

            return [
                'success' => false,
                'error' => 'Failed to list workflows',
                'status' => $response->status(),
            ];

        } catch (Exception $e) {
            Log::error('N8N list workflows error', [
                'error' => $e->getMessage(),
            ]);

            return [
                'success' => false,
                'error' => $e->getMessage(),
            ];
        }
    }

    /**
     * Sync workflows from N8N to local database
     */
    public function syncWorkflows(): array
    {
        $result = $this->listWorkflows();

        if (!$result['success']) {
            return $result;
        }

        $synced = 0;
        $created = 0;
        $updated = 0;

        foreach ($result['workflows'] as $workflow) {
            $localWorkflow = N8NWorkflow::where('n8n_id', $workflow['id'])->first();

            $data = [
                'name' => $workflow['name'],
                'description' => $workflow['nodes'][0]['parameters']['description'] ?? null,
                'active' => $workflow['active'] ?? false,
                'settings' => $workflow['nodes'] ?? [],
                'last_synced_at' => now(),
            ];

            if ($localWorkflow) {
                $localWorkflow->update($data);
                $updated++;
            } else {
                N8NWorkflow::create([
                    'n8n_id' => $workflow['id'],
                    ...$data,
                    'metadata' => [
                        'synced_via' => 'api_sync',
                    ],
                ]);
                $created++;
            }

            $synced++;
        }

        // Cache the result
        Cache::put('n8n_workflows_sync', [
            'synced_at' => now()->toIso8601String(),
            'count' => $synced,
        ], 3600);

        return [
            'success' => true,
            'synced' => $synced,
            'created' => $created,
            'updated' => $updated,
            'message' => "Synced {$synced} workflows ({$created} created, {$updated} updated)",
        ];
    }

    /**
     * Handle incoming webhook from N8N
     */
    public function handleWebhook(array $payload, ?string $signature = null): array
    {
        // Verify webhook signature if secret is configured
        if ($this->webhookSecret && $signature) {
            if (!$this->verifyWebhookSignature($payload, $signature)) {
                Log::warning('N8N webhook signature verification failed');
                return ['success' => false, 'error' => 'Invalid signature'];
            }
        }

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

            case 'workflow_completed':
                return $this->processWorkflowCompleted($payload);

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

        // Store alert for dashboard
        if (isset($payload['alert'])) {
            // Could integrate with AlertService
        }

        return ['success' => true, 'processed' => 'monitoring_alert'];
    }

    /**
     * Process AI response from N8N
     */
    protected function processAIResponse(array $payload): array
    {
        Log::info('AI response received', $payload);

        // Store AI response for retrieval
        Cache::put(
            'ai_response_' . ($payload['request_id'] ?? Str::uuid()),
            $payload,
            now()->addHours(24)
        );

        return ['success' => true, 'processed' => 'ai_response'];
    }

    /**
     * Process deployment status from N8N
     */
    protected function processDeploymentStatus(array $payload): array
    {
        Log::info('Deployment status received', $payload);

        // Update deployment record
        if (isset($payload['deployment_id'])) {
            // Could integrate with DeploymentWorkflowService
        }

        return ['success' => true, 'processed' => 'deployment_status'];
    }

    /**
     * Process workflow error from N8N
     */
    protected function processWorkflowError(array $payload): array
    {
        Log::error('Workflow error received', $payload);

        // Create incident or alert
        // Could integrate with AlertService

        return ['success' => true, 'processed' => 'workflow_error'];
    }

    /**
     * Process workflow completed from N8N
     */
    protected function processWorkflowCompleted(array $payload): array
    {
        Log::info('Workflow completed received', $payload);

        // Update execution record
        if (isset($payload['execution_id'])) {
            // Update local workflow execution log
        }

        return ['success' => true, 'processed' => 'workflow_completed'];
    }

    /**
     * Get workflow by local ID
     */
    public function getLocalWorkflow(string $workflowId): ?N8NWorkflow
    {
        return N8NWorkflow::find($workflowId);
    }

    /**
     * Get workflow by N8N ID
     */
    public function getWorkflowByN8NId(string $n8nId): ?N8NWorkflow
    {
        return N8NWorkflow::where('n8n_id', $n8nId)->first();
    }

    /**
     * Get all active workflows
     */
    public function getActiveWorkflows(): array
    {
        return N8NWorkflow::active()->get()->toArray();
    }

    /**
     * Test N8N connection
     */
    public function testConnection(): array
    {
        try {
            $response = Http::withHeaders($this->defaultHeaders)
                ->timeout(5)
                ->get("{$this->apiUrl}/rest/active-workflows");

            $isConnected = $response->successful();

            return [
                'success' => $isConnected,
                'connected' => $isConnected,
                'circuit_breaker' => $this->getCircuitBreakerStatus(),
                'message' => $isConnected
                    ? 'N8N API is accessible'
                    : 'N8N API connection failed',
            ];

        } catch (Exception $e) {
            return [
                'success' => false,
                'connected' => false,
                'error' => $e->getMessage(),
            ];
        }
    }

    /**
     * Circuit Breaker: Check if circuit is open
     */
    protected function isCircuitBreakerOpen(): bool
    {
        if ($this->circuitBreaker['last_failure'] === null) {
            return false;
        }

        $timeSinceLastFailure = now()->diffInSeconds($this->circuitBreaker['last_failure']);

        // Reset circuit breaker if timeout has passed
        if ($timeSinceLastFailure > $this->circuitBreaker['timeout']) {
            $this->resetCircuitBreaker();
            return false;
        }

        return $this->circuitBreaker['failures'] >= $this->circuitBreaker['threshold'];
    }

    /**
     * Circuit Breaker: Record a failure
     */
    protected function recordCircuitBreakerFailure(): void
    {
        $this->circuitBreaker['failures']++;
        $this->circuitBreaker['last_failure'] = now();

        Cache::put('n8n_circuit_breaker', $this->circuitBreaker, 3600);
    }

    /**
     * Circuit Breaker: Reset after success
     */
    protected function resetCircuitBreaker(): void
    {
        $this->circuitBreaker['failures'] = 0;
        $this->circuitBreaker['last_failure'] = null;

        Cache::put('n8n_circuit_breaker', $this->circuitBreaker, 3600);
    }

    /**
     * Circuit Breaker: Get retry after time
     */
    protected function getRetryAfter(): int
    {
        if ($this->circuitBreaker['last_failure'] === null) {
            return 0;
        }

        $elapsed = now()->diffInSeconds($this->circuitBreaker['last_failure']);
        $remaining = $this->circuitBreaker['timeout'] - $elapsed;

        return max(0, $remaining);
    }

    /**
     * Circuit Breaker: Get current status
     */
    public function getCircuitBreakerStatus(): array
    {
        return [
            'open' => $this->isCircuitBreakerOpen(),
            'failures' => $this->circuitBreaker['failures'],
            'threshold' => $this->circuitBreaker['threshold'],
            'last_failure' => $this->circuitBreaker['last_failure']?->toIso8601String(),
            'retry_after' => $this->getRetryAfter(),
        ];
    }

    /**
     * Verify webhook signature
     */
    protected function verifyWebhookSignature(array $payload, string $signature): bool
    {
        $expected = hash_hmac('sha256', json_encode($payload), $this->webhookSecret);
        return hash_equals($expected, $signature);
    }

    /**
     * Get full webhook URL
     */
    protected function getWebhookUrl(string $path): string
    {
        $baseUrl = config('n8n.webhook_base_url', $this->apiUrl);
        return rtrim($baseUrl, '/') . '/' . ltrim($path, '/');
    }

    /**
     * Log workflow execution
     */
    protected function logWorkflowExecution(
        string $workflowId,
        ?string $executionId,
        string $status,
        array $input,
        ?array $error = null
    ): void {
        Log::info('N8N Workflow Execution', [
            'workflow_id' => $workflowId,
            'execution_id' => $executionId,
            'status' => $status,
            'input_size' => count($input),
            'error' => $error,
        ]);

        // Could store in workflow_executions table if needed
    }

    /**
     * Get workflow statistics
     */
    public function getStatistics(): array
    {
        $totalWorkflows = N8NWorkflow::count();
        $activeWorkflows = N8NWorkflow::active()->count();
        $lastSync = Cache::get('n8n_workflows_sync');

        return [
            'total_workflows' => $totalWorkflows,
            'active_workflows' => $activeWorkflows,
            'inactive_workflows' => $totalWorkflows - $activeWorkflows,
            'last_sync' => $lastSync['synced_at'] ?? null,
            'circuit_breaker' => $this->getCircuitBreakerStatus(),
        ];
    }
}
