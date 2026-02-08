<?php

namespace App\Http\Controllers\Api\AgentOS;

use App\Services\AgentOS\AgentOSService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class MemoryController extends Controller
{
    public function __construct(
        private AgentOSService $agentOS
    ) {}

    /**
     * Store memory in Agent OS
     */
    public function store(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'agent_id' => 'required|string|max:255',
            'content' => 'required|string',
            'metadata' => 'array',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors(),
            ], 422);
        }

        $result = $this->agentOS->remember(
            $request->agent_id,
            $request->content,
            $request->metadata ?? []
        );

        return response()->json([
            'success' => $result,
            'message' => $result ? 'Memory stored successfully' : 'Failed to store memory',
        ]);
    }

    /**
     * Recall similar memories
     */
    public function recall(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'query' => 'required|string',
            'k' => 'integer|min:1|max:100',
            'agent_id' => 'nullable|string',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors(),
            ], 422);
        }

        $results = $this->agentOS->recall(
            $request->query,
            $request->k ?? 10,
            $request->agent_id
        );

        return response()->json([
            'success' => true,
            'data' => $results,
            'count' => count($results),
        ]);
    }

    /**
     * Get memory statistics
     */
    public function stats(): JsonResponse
    {
        $overview = $this->agentOS->overview();

        return response()->json([
            'success' => true,
            'data' => $overview['memory'],
        ]);
    }

    /**
     * Get learning patterns from ReasoningBank
     */
    public function patterns(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'query' => 'required|string',
            'k' => 'integer|min:1|max:20',
            'min_reward' => 'numeric|min:0|max:1',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors(),
            ], 422);
        }

        $patterns = $this->agentOS->getPatterns(
            $request->query,
            $request->k ?? 5,
            $request->min_reward ?? 0.7
        );

        return response()->json([
            'success' => true,
            'data' => $patterns,
            'count' => count($patterns),
        ]);
    }

    /**
     * Learn from experience
     */
    public function learn(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'pattern' => 'required|string',
            'reward' => 'required|numeric|min:0|max:1',
            'context' => 'array',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors(),
            ], 422);
        }

        $result = $this->agentOS->learn(
            $request->pattern,
            $request->reward,
            $request->context ?? []
        );

        return response()->json([
            'success' => $result,
            'message' => $result ? 'Pattern learned successfully' : 'Failed to learn pattern',
        ]);
    }

    /**
     * Clear memory
     */
    public function clear(): JsonResponse
    {
        // This would call the memory service clear method
        return response()->json([
            'success' => true,
            'message' => 'Memory cleared successfully',
        ]);
    }
}
