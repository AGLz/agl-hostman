<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\AIService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\StreamedResponse;
use OpenApi\Annotations as OA;

/**
 * AI Integration Controller
 *
 * Provides REST API endpoints for AI-powered features including:
 * - Predictions and forecasting
 * - Log and metrics analysis
 * - Interactive chat
 * - Model listing and management
 */
class AIController extends Controller
{
    protected AIService $aiService;

    public function __construct(AIService $aiService)
    {
        $this->aiService = $aiService;
    }

    /**
     * Generate AI predictions
     *
     * @OA\Post(
     *     path="/api/ai/predict",
     *     tags={"AI"},
     *     summary="Generate AI predictions",
     *     description="Generate predictions based on historical data using AI models",
     *     operationId="aiPredict",
     *     security={{"bearerAuth":{}}},
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             required={"data"},
     *             @OA\Property(
     *                 property="data",
     *                 type="array",
     *                 description="Historical data for prediction",
     *                 @OA\Items(type="object")
     *             ),
     *             @OA\Property(
     *                 property="type",
     *                 type="string",
     *                 enum={"capacity", "performance", "failure", "cost", "traffic"},
     *                 description="Prediction type",
     *                 example="performance"
     *             ),
     *             @OA\Property(
     *                 property="model",
     *                 type="string",
     *                 description="Specific model to use (optional)",
     *                 example="gpt-4-turbo"
     *             )
     *         )
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Predictions generated successfully",
     *         @OA\JsonContent(
     *             @OA\Property(property="success", type="boolean", example=true),
     *             @OA\Property(property="predictions", type="object"),
     *             @OA\Property(property="model_used", type="string", example="gpt-4-turbo"),
     *             @OA\Property(property="confidence", type="number", example=0.87),
     *             @OA\Property(property="timestamp", type="string", example="2024-01-15T10:30:00Z")
     *         )
     *     ),
     *     @OA\Response(response=400, description="Invalid request"),
     *     @OA\Response(response=401, description="Unauthorized"),
     *     @OA\Response(response=500, description="Server error")
     * )
     */
    public function predict(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'data' => 'required|array|min:1',
            'type' => 'string|in:capacity,performance,failure,cost,traffic',
            'model' => 'string|nullable',
        ]);

        $result = $this->aiService->generatePrediction(
            $validated['data'],
            $validated['type'] ?? 'performance',
            $validated['model'] ?? null
        );

        return response()->json($result, $result['success'] ? 200 : 500);
    }

    /**
     * Analyze data with AI
     *
     * @OA\Post(
     *     path="/api/ai/analyze",
     *     tags={"AI"},
     *     summary="Analyze data with AI",
     *     description="Analyze logs and metrics using AI to extract insights and detect anomalies",
     *     operationId="aiAnalyze",
     *     security={{"bearerAuth":{}}},
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             required={"logs", "metrics"},
     *             @OA\Property(
     *                 property="logs",
     *                 type="array",
     *                 description="Log entries to analyze",
     *                 @OA\Items(type="object", example={"timestamp": "2024-01-15T10:00:00Z", "level": "error", "message": "Connection timeout"})
     *             )
     *             ),
     *             @OA\Property(
     *                 property="metrics",
     *                 type="object",
     *                 description="System metrics",
     *                 example={"cpu": 85, "memory": 72, "disk": 45}
     *             ),
     *             @OA\Property(
     *                 property="model",
     *                 type="string",
     *                 description="Specific model to use (optional)",
     *                 example="claude-3-opus-20240229"
     *             )
     *         )
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Analysis completed successfully",
     *         @OA\JsonContent(
     *             @OA\Property(property="success", type="boolean", example=true),
     *             @OA\Property(
     *                 property="analysis",
     *                 type="object",
     *                 @OA\Property(property="findings", type="array", @OA\Items(type="string")),
     *                 @OA\Property(property="anomalies", type="array", @OA\Items(type="string")),
     *                 @OA\Property(property="recommendations", type="array", @OA\Items(type="string"))
     *             ),
     *             @OA\Property(property="model_used", type="string"),
     *             @OA\Property(property="timestamp", type="string")
     *         )
     *     )
     * )
     */
    public function analyze(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'logs' => 'required|array',
            'metrics' => 'required|array',
            'model' => 'string|nullable',
        ]);

        $result = $this->aiService->analyzeLogsAndMetrics(
            $validated['logs'],
            $validated['metrics'],
            $validated['model'] ?? null
        );

        return response()->json($result, $result['success'] ? 200 : 500);
    }

    /**
     * Interactive chat with AI
     *
     * @OA\Post(
     *     path="/api/ai/chat",
     *     tags={"AI"},
     *     summary="Chat with AI",
     *     description="Interactive chat interface with AI models",
     *     operationId="aiChat",
     *     security={{"bearerAuth":{}}},
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             required={"message"},
     *             @OA\Property(
     *                 property="message",
     *                 type="string",
     *                 description="User message",
     *                 example="Analyze the current server performance"
     *             ),
     *             @OA\Property(
     *                 property="history",
     *                 type="array",
     *                 description="Conversation history",
     *                 @OA\Items(
     *                     type="object",
     *                     @OA\Property(property="role", type="string", example="user"),
     *                     @OA\Property(property="content", type="string", example="Hello")
     *                 )
     *             ),
     *             @OA\Property(
     *                 property="model",
     *                 type="string",
     *                 description="Specific model to use (optional)"
     *             ),
     *             @OA\Property(
     *                 property="stream",
     *                 type="boolean",
     *                 description="Enable streaming response",
     *                 example=false
     *             )
     *         )
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Chat response",
     *         @OA\JsonContent(
     *             @OA\Property(property="success", type="boolean", example=true),
     *             @OA\Property(property="message", type="string"),
     *             @OA\Property(property="model_used", type="string"),
     *             @OA\Property(property="timestamp", type="string")
     *         )
     *     )
     * )
     */
    public function chat(Request $request): JsonResponse|StreamedResponse
    {
        $validated = $request->validate([
            'message' => 'required|string|max:10000',
            'history' => 'array',
            'history.*.role' => 'string|in:user,assistant,system',
            'history.*.content' => 'string',
            'model' => 'string|nullable',
            'stream' => 'boolean',
        ]);

        $stream = $validated['stream'] ?? false;

        if ($stream) {
            return response()->stream(function () use ($validated) {
                $generator = $this->aiService->chat(
                    $validated['message'],
                    $validated['history'] ?? [],
                    $validated['model'] ?? null,
                    true
                );

                foreach ($generator as $chunk) {
                    echo "data: " . json_encode($chunk) . "\n\n";
                    ob_flush();
                    flush();
                }

                echo "data: [DONE]\n\n";
                ob_flush();
                flush();
            }, 200, [
                'Content-Type' => 'text/event-stream',
                'Cache-Control' => 'no-cache',
                'X-Accel-Buffering' => 'no',
            ]);
        }

        $result = $this->aiService->chat(
            $validated['message'],
            $validated['history'] ?? [],
            $validated['model'] ?? null,
            false
        );

        return response()->json($result, $result['success'] ? 200 : 500);
    }

    /**
     * List available AI models
     *
     * @OA\Get(
     *     path="/api/ai/models",
     *     tags={"AI"},
     *     summary="List available AI models",
     *     description="Get a list of all available AI models and their capabilities",
     *     operationId="aiModels",
     *     security={{"bearerAuth":{}}},
     *     @OA\Response(
     *         response=200,
     *         description="List of available models",
     *         @OA\JsonContent(
     *             type="array",
     *             @OA\Items(
     *                 @OA\Property(property="id", type="string", example="gpt-4-turbo"),
     *                 @OA\Property(property="provider", type="string", example="openai"),
     *                 @OA\Property(property="max_tokens", type="integer", example=128000),
     *                 @OA\Property(property="supports_streaming", type="boolean", example=true),
     *                 @OA\Property(property="available", type="boolean", example=true)
     *             )
     *         )
     *     )
     * )
     */
    public function models(): JsonResponse
    {
        $models = $this->aiService->getAvailableModels();

        return response()->json([
            'success' => true,
            'models' => $models,
            'count' => count($models),
        ]);
    }

    /**
     * Get AI usage statistics
     *
     * @OA\Get(
     *     path="/api/ai/usage",
     *     tags={"AI"},
     *     summary="Get AI usage statistics",
     *     description="Get usage statistics for AI models",
     *     operationId="aiUsage",
     *     security={{"bearerAuth":{}}},
     *     @OA\Parameter(
     *         name="period",
     *         in="query",
     *         description="Time period",
     *         required=false,
     *         @OA\Schema(type="string", enum={"24h", "7d", "30d"}, example="7d")
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Usage statistics",
     *         @OA\JsonContent(
     *             @OA\Property(property="total_requests", type="integer"),
     *             @OA\Property(property="total_tokens", type="integer"),
     *             @OA\Property(property="by_model", type="object"),
     *             @OA\Property(property="by_task_type", type="object")
     *         )
     *     )
     * )
     */
    public function usage(Request $request): JsonResponse
    {
        $period = $request->query('period', '7d');

        $periodMap = [
            '24h' => now()->subHours(24),
            '7d' => now()->subDays(7),
            '30d' => now()->subDays(30),
        ];

        $startDate = $periodMap[$period] ?? now()->subDays(7);

        $usageQuery = \App\Models\AIModelUsage::where('created_at', '>=', $startDate);

        if (!auth()->user()?->hasRole('admin')) {
            $usageQuery->where('user_id', auth()->id());
        }

        $usage = $usageQuery->get();

        return response()->json([
            'success' => true,
            'period' => $period,
            'total_requests' => $usage->count(),
            'total_tokens' => $usage->sum('total_tokens'),
            'by_model' => $usage->groupBy('model')->map(fn($group) => [
                'requests' => $group->count(),
                'tokens' => $group->sum('total_tokens'),
            ]),
            'by_task_type' => $usage->groupBy('task_type')->map(fn($group) => [
                'requests' => $group->count(),
                'tokens' => $group->sum('total_tokens'),
            ]),
        ]);
    }
}
