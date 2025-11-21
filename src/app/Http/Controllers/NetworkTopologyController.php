<?php

namespace App\Http\Controllers;

use App\Services\NetworkTopologyService;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

class NetworkTopologyController extends Controller
{
    private NetworkTopologyService $networkTopologyService;

    public function __construct(NetworkTopologyService $networkTopologyService)
    {
        $this->networkTopologyService = $networkTopologyService;
    }

    /**
     * Display the network topology visualizer page
     */
    public function index(): Response
    {
        return Inertia::render('Network/Topology', [
            'title' => 'Network Topology Visualizer',
            'description' => 'Interactive 3D/2D visualization of WireGuard mesh network',
        ]);
    }

    /**
     * Get complete network graph data
     */
    public function getGraph()
    {
        try {
            $graph = $this->networkTopologyService->getNetworkGraph();

            return response()->json([
                ...$graph,
                'timestamp' => now()->toISOString(),
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'error' => 'Failed to fetch network graph',
                'message' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get detailed information for a specific node
     */
    public function getNodeDetails(string $nodeId)
    {
        try {
            $metrics = $this->networkTopologyService->getNodeMetrics($nodeId);

            return response()->json([
                'node_id' => $nodeId,
                'metrics' => $metrics,
                'timestamp' => now()->toISOString(),
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'error' => 'Failed to fetch node details',
                'message' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get connection health between two nodes
     */
    public function getConnectionDetails(string $sourceId, string $targetId)
    {
        try {
            $health = $this->networkTopologyService->getConnectionHealth($sourceId, $targetId);

            return response()->json([
                'source_id' => $sourceId,
                'target_id' => $targetId,
                'health' => $health,
                'timestamp' => now()->toISOString(),
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'error' => 'Failed to fetch connection details',
                'message' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get overall network health metrics
     */
    public function getNetworkHealth()
    {
        try {
            $graph = $this->networkTopologyService->getNetworkGraph();

            return response()->json([
                'metadata' => $graph['metadata'],
                'timestamp' => now()->toISOString(),
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'error' => 'Failed to fetch network health',
                'message' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Detect network issues
     */
    public function detectIssues()
    {
        try {
            $issues = $this->networkTopologyService->detectNetworkIssues();

            return response()->json($issues->toArray());
        } catch (\Exception $e) {
            return response()->json([
                'error' => 'Failed to detect network issues',
                'message' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Calculate network path between two nodes
     */
    public function calculatePath(Request $request)
    {
        $validated = $request->validate([
            'from' => 'required|string',
            'to' => 'required|string',
        ]);

        try {
            $path = $this->networkTopologyService->calculateNetworkPaths(
                $validated['from'],
                $validated['to']
            );

            return response()->json($path);
        } catch (\Exception $e) {
            return response()->json([
                'error' => 'Failed to calculate path',
                'message' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get WireGuard peers
     */
    public function getWireGuardPeers()
    {
        try {
            $peers = $this->networkTopologyService->getWireGuardPeers();

            return response()->json($peers->toArray());
        } catch (\Exception $e) {
            return response()->json([
                'error' => 'Failed to fetch WireGuard peers',
                'message' => $e->getMessage(),
            ], 500);
        }
    }
}
