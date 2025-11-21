<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\AIModelService;
use Illuminate\Http\Request;
use OpenApi\Annotations as OA;

class AIModelController extends Controller
{
    protected $aiModelService;

    public function __construct(AIModelService $aiModelService)
    {
        $this->aiModelService = $aiModelService;
    }

    /**
     * @OA\Get(
     *     path="/api/ai-models",
     *     tags={"AI Models"},
     *     summary="List available AI models",
     *     description="Get list of all available AI models and their status",
     *     operationId="listAIModels",
     *     security={{"bearerAuth":{}}},
     *     @OA\Response(
     *         response=200,
     *         description="List of AI models",
     *         @OA\JsonContent(
     *             type="array",
     *             @OA\Items(
     *                 @OA\Property(property="id", type="string", example="claude-3"),
     *                 @OA\Property(property="name", type="string", example="Claude 3"),
     *                 @OA\Property(property="provider", type="string", example="anthropic"),
     *                 @OA\Property(property="status", type="string", example="available"),
     *                 @OA\Property(property="capabilities", type="array", @OA\Items(type="string")),
     *                 @OA\Property(property="max_tokens", type="integer", example=100000),
     *                 @OA\Property(property="cost_per_1k_tokens", type="number", example=0.015)
     *             )
     *         )
     *     )
     * )
     */
    public function index()
    {
        $models = $this->aiModelService->listModels();
        return response()->json($models);
    }

    /**
     * @OA\Post(
     *     path="/api/ai-models/execute",
     *     tags={"AI Models"},
     *     summary="Execute AI model",
     *     description="Execute a task using specified AI model or orchestrated multi-model approach",
     *     operationId="executeAIModel",
     *     security={{"bearerAuth":{}}},
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             required={"prompt"},
     *             @OA\Property(property="prompt", type="string", description="The prompt or task to execute"),
     *             @OA\Property(property="model", type="string", example="claude-3", description="Specific model to use"),
     *             @OA\Property(property="orchestrate", type="boolean", example=true, description="Use multi-model orchestration"),
     *             @OA\Property(property="max_tokens", type="integer", example=2000),
     *             @OA\Property(property="temperature", type="number", example=0.7),
     *             @OA\Property(property="context", type="object", description="Additional context for the model")
     *         )
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Execution result",
     *         @OA\JsonContent(
     *             @OA\Property(property="response", type="string", description="Model response"),
     *             @OA\Property(property="model_used", type="string", example="claude-3"),
     *             @OA\Property(property="tokens_used", type="integer", example=1523),
     *             @OA\Property(property="execution_time", type="number", example=2.34),
     *             @OA\Property(property="confidence", type="number", example=0.95),
     *             @OA\Property(property="orchestration", type="object",
     *                 @OA\Property(property="models_consulted", type="array", @OA\Items(type="string")),
     *                 @OA\Property(property="consensus_score", type="number", example=0.88)
     *             )
     *         )
     *     ),
     *     @OA\Response(
     *         response=400,
     *         description="Invalid request",
     *         @OA\JsonContent(ref="#/components/schemas/Error")
     *     )
     * )
     */
    public function execute(Request $request)
    {
        $validated = $request->validate([
            'prompt' => 'required|string',
            'model' => 'string|nullable',
            'orchestrate' => 'boolean',
            'max_tokens' => 'integer|min:1|max:100000',
            'temperature' => 'numeric|min:0|max:2',
            'context' => 'array|nullable'
        ]);

        if ($request->input('orchestrate', false)) {
            $result = $this->aiModelService->orchestrateModels($validated['prompt'], $validated);
        } else {
            $model = $request->input('model', 'claude-3');
            $result = $this->aiModelService->executeModel($model, $validated['prompt'], $validated);
        }

        return response()->json($result);
    }

    /**
     * @OA\Post(
     *     path="/api/ai-models/analyze",
     *     tags={"AI Models"},
     *     summary="Analyze data with AI",
     *     description="Perform AI-powered analysis on provided data",
     *     operationId="analyzeWithAI",
     *     security={{"bearerAuth":{}}},
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             required={"data", "analysis_type"},
     *             @OA\Property(property="data", type="object", description="Data to analyze"),
     *             @OA\Property(property="analysis_type", type="string", enum={"sentiment", "classification", "summary", "prediction", "anomaly"}, example="anomaly"),
     *             @OA\Property(property="model", type="string", example="gpt-4", description="Preferred model for analysis")
     *         )
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Analysis results",
     *         @OA\JsonContent(
     *             @OA\Property(property="analysis_type", type="string", example="anomaly"),
     *             @OA\Property(property="results", type="object"),
     *             @OA\Property(property="confidence", type="number", example=0.92),
     *             @OA\Property(property="insights", type="array", @OA\Items(type="string")),
     *             @OA\Property(property="recommendations", type="array", @OA\Items(type="string"))
     *         )
     *     )
     * )
     */
    public function analyze(Request $request)
    {
        $validated = $request->validate([
            'data' => 'required|array',
            'analysis_type' => 'required|string|in:sentiment,classification,summary,prediction,anomaly',
            'model' => 'string|nullable'
        ]);

        $result = $this->aiModelService->analyzeData(
            $validated['data'],
            $validated['analysis_type'],
            $validated['model'] ?? null
        );

        return response()->json($result);
    }
}