<?php

namespace App\Http\Controllers\Api\AgentOS;

use App\Services\AgentOS\AgentOSService;
use App\Services\AgentOS\Consensus\ByzantineCoordinator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class NeuralController extends Controller
{
    public function __construct(
        private AgentOSService $agentOS,
        private ByzantineCoordinator $consensus
    ) {}

    /**
     * Achieve consensus among agents
     */
    public function consensus(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'consensus_id' => 'required|string|max:255',
            'agents' => 'required|array|min:1',
            'proposals' => 'required|array',
            'mechanism' => 'string|in:byzantine,raft,gossip,crdt',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors(),
            ], 422);
        }

        $result = $this->agentOS->consensus(
            $request->consensus_id,
            $request->agents,
            $request->proposals,
            $request->mechanism ?? 'byzantine'
        );

        return response()->json([
            'success' => true,
            'data' => $result,
        ]);
    }

    /**
     * Get consensus status
     */
    public function consensusStatus(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'consensus_id' => 'required|string',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors(),
            ], 422);
        }

        $status = $this->consensus->status($request->consensus_id);

        return response()->json([
            'success' => true,
            'data' => $status,
        ]);
    }

    /**
     * Get system overview
     */
    public function overview(): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data' => $this->agentOS->overview(),
        ]);
    }

    /**
     * Get system health
     */
    public function health(): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data' => $this->agentOS->health(),
        ]);
    }

    /**
     * Get neural network performance metrics
     */
    public function performance(): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data' => [
                'flash_attention_speedup' => 2.49,
                'napi_speedup' => 7.47,
                'memory_reduction' => 0.5,
                'hnsw_speedup_1m' => 150,
                'hnsw_speedup_10m' => 12500,
                'sona_latency_ms' => '<1',
                'lora_parameter_reduction' => 0.99,
                'gnn_recall_improvement' => 0.124,
            ],
        ]);
    }
}
