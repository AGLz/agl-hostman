<?php

namespace App\Http\Controllers\Api\AgentOS;

use App\Services\AgentOS\AgentOSService;
use App\Services\AgentOS\Coordination\AdaptiveCoordinator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class CoordinationController extends Controller
{
    public function __construct(
        private AgentOSService $agentOS,
        private AdaptiveCoordinator $coordinator
    ) {}

    /**
     * Coordinate multiple agents
     */
    public function coordinate(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'session_id' => 'required|string|max:255',
            'agents' => 'required|array|min:1',
            'topology' => 'string|in:hierarchical,mesh,adaptive',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors(),
            ], 422);
        }

        $result = $this->agentOS->coordinate(
            $request->session_id,
            $request->agents,
            $request->topology ?? 'adaptive'
        );

        return response()->json([
            'success' => true,
            'data' => $result,
        ]);
    }

    /**
     * Apply attention mechanism to outputs
     */
    public function attend(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'outputs' => 'required|array',
            'mechanism' => 'string|in:flash,multi_head,linear,hyperbolic,moe,adaptive',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors(),
            ], 422);
        }

        $result = $this->agentOS->attend(
            $request->outputs,
            $request->mechanism ?? 'adaptive'
        );

        return response()->json([
            'success' => true,
            'data' => $result,
        ]);
    }

    /**
     * Get coordination status
     */
    public function status(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'session_id' => 'required|string',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors(),
            ], 422);
        }

        $status = $this->coordinator->status($request->session_id);

        return response()->json([
            'success' => true,
            'data' => $status,
        ]);
    }

    /**
     * Terminate coordination session
     */
    public function terminate(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'session_id' => 'required|string',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors(),
            ], 422);
        }

        $result = $this->coordinator->terminate($request->session_id);

        return response()->json([
            'success' => $result,
            'message' => $result ? 'Session terminated' : 'Failed to terminate session',
        ]);
    }

    /**
     * Get available topologies
     */
    public function topologies(): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data' => $this->coordinator->topologies(),
        ]);
    }

    /**
     * Get available attention mechanisms
     */
    public function mechanisms(): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data' => $this->coordinator->mechanisms(),
        ]);
    }
}
