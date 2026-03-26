<?php

namespace App\Http\Controllers;

use App\Services\AIModelService;
use App\Services\N8NService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class AIController extends Controller
{
    protected AIModelService $aiService;

    protected N8NService $n8nService;

    public function __construct(AIModelService $aiService, N8NService $n8nService)
    {
        $this->aiService = $aiService;
        $this->n8nService = $n8nService;
    }

    /**
     * Query a single AI model
     */
    public function query(Request $request)
    {
        $request->validate([
            'model' => 'required|string|in:claude,gemini,openai,abacusai,ollama',
            'prompt' => 'required|string',
            'max_tokens' => 'integer|min:1|max:128000',
            'temperature' => 'numeric|min:0|max:2',
        ]);

        $result = $this->aiService->query(
            $request->model,
            $request->prompt,
            $request->only(['max_tokens', 'temperature'])
        );

        // Log to N8N if successful
        if ($result['success']) {
            $this->n8nService->triggerAIAgent(
                $request->model,
                $request->prompt,
                ['response' => $result['content']]
            );
        }

        return response()->json($result);
    }

    /**
     * Query multiple AI models concurrently (hive-mind)
     */
    public function multiAgent(Request $request)
    {
        $request->validate([
            'models' => 'required|array|min:2',
            'models.*' => 'string|in:claude,gemini,openai,abacusai,ollama',
            'prompt' => 'required|string',
            'max_tokens' => 'integer|min:1|max:128000',
            'temperature' => 'numeric|min:0|max:2',
        ]);

        $results = $this->aiService->multiAgentQuery(
            $request->models,
            $request->prompt,
            $request->only(['max_tokens', 'temperature'])
        );

        return response()->json($results);
    }

    /**
     * Get available AI models
     */
    public function models()
    {
        $models = $this->aiService->getAvailableModels();

        return response()->json([
            'success' => true,
            'models' => $models,
            'configured' => array_keys(array_filter($models, fn ($m) => $m['configured'])),
        ]);
    }

    /**
     * Smart model selection based on task
     */
    public function selectModel(Request $request)
    {
        $request->validate([
            'task_type' => 'required|string|in:code_generation,data_analysis,multimodal,function_calling,offline,reasoning,quick_response',
        ]);

        $selectedModel = $this->aiService->selectBestModel($request->task_type);
        $models = $this->aiService->getAvailableModels();

        return response()->json([
            'success' => true,
            'selected_model' => $selectedModel,
            'model_info' => $models[$selectedModel] ?? null,
            'task_type' => $request->task_type,
        ]);
    }

    /**
     * Execute AI-powered infrastructure analysis
     */
    public function analyzeInfrastructure(Request $request)
    {
        $request->validate([
            'servers' => 'required|array',
            'analysis_type' => 'required|string|in:health,performance,security,optimization',
        ]);

        $prompt = $this->buildInfrastructurePrompt($request->servers, $request->analysis_type);

        // Use the best model for analysis
        $model = $this->aiService->selectBestModel('data_analysis');
        $result = $this->aiService->query($model, $prompt);

        if ($result['success']) {
            // Trigger N8N workflow for infrastructure monitoring
            $this->n8nService->triggerMonitoring($request->servers);
        }

        return response()->json([
            'success' => $result['success'],
            'analysis' => $result['content'] ?? null,
            'model_used' => $model,
            'servers_analyzed' => $request->servers,
            'type' => $request->analysis_type,
        ]);
    }

    /**
     * Build infrastructure analysis prompt
     */
    protected function buildInfrastructurePrompt(array $servers, string $type): string
    {
        $serverList = implode(', ', $servers);

        $prompts = [
            'health' => "Analyze the health status of these servers: {$serverList}. Check for potential issues, uptime, and resource utilization.",
            'performance' => "Analyze performance metrics for servers: {$serverList}. Identify bottlenecks and optimization opportunities.",
            'security' => "Perform security analysis for servers: {$serverList}. Identify vulnerabilities and recommend hardening measures.",
            'optimization' => "Suggest optimizations for servers: {$serverList}. Focus on resource efficiency and cost reduction.",
        ];

        return $prompts[$type] ?? $prompts['health'];
    }

    /**
     * Execute AI-powered code review
     */
    public function reviewCode(Request $request)
    {
        $request->validate([
            'code' => 'required|string',
            'language' => 'required|string',
            'review_type' => 'string|in:security,performance,best_practices,all',
        ]);

        $reviewType = $request->review_type ?? 'all';
        $prompt = "Review this {$request->language} code for {$reviewType} issues:\n\n```{$request->language}\n{$request->code}\n```";

        // Use Claude for code review as it excels at this
        $result = $this->aiService->query('claude', $prompt, ['max_tokens' => 4096]);

        return response()->json([
            'success' => $result['success'],
            'review' => $result['content'] ?? null,
            'language' => $request->language,
            'review_type' => $request->review_type ?? 'all',
        ]);
    }
}
