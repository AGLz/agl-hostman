<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\Hermes\HermesChatService;
use App\Services\Hermes\HermesStatusService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class HermesController extends Controller
{
    public function __construct(
        private readonly HermesStatusService $statusService,
        private readonly HermesChatService $chatService,
    ) {}

    public function index(): JsonResponse
    {
        $status = $this->statusService->getStatus();

        return response()->json([
            'status' => $status['gateway'] === 'running' ? 'online' : 'offline',
            'gateway' => $status['gateway'],
            'agents' => array_values($status['agents'] ?? []),
            'tasks' => $status['tasks'] ?? [],
            'scheduled_tasks' => $status['scheduled_tasks'] ?? [],
            'source' => $status['source'],
            'base_url' => $status['base_url'],
            'minions_url' => $status['minions_url'],
            'studio_url' => $status['studio_url'],
            'claw3d_ws_url' => $status['claw3d_ws_url'],
            'dashboard_url' => $status['dashboard_url'],
            'checked_at' => $status['checked_at'],
        ]);
    }

    public function agents(): JsonResponse
    {
        $status = $this->statusService->getStatus();
        $agents = $status['agents'] ?? [];
        $categorized = $this->statusService->categorizeAgents($agents);

        return response()->json([
            'total' => count($agents),
            'active' => count(array_filter($agents, fn($a) => ($a['status'] ?? '') === 'active')),
            'standby' => count(array_filter($agents, fn($a) => in_array($a['status'] ?? '', ['idle', 'standby'], true))),
            'errors' => count(array_filter($agents, fn($a) => ($a['status'] ?? '') === 'error')),
            'categorized' => $categorized,
            'agents' => array_values($agents),
            'gateway' => $status['gateway'],
            'source' => $status['source'],
            'base_url' => $status['base_url'],
            'checked_at' => $status['checked_at'],
        ]);
    }

    public function agentList(): JsonResponse
    {
        $status = $this->statusService->getStatus();

        return response()->json(array_values($status['agents'] ?? []));
    }

    public function agentStatus(): JsonResponse
    {
        $status = $this->statusService->getStatus();
        $agents = array_values($status['agents'] ?? []);

        return response()->json([
            'active' => count(array_filter($agents, fn($a) => ($a['status'] ?? '') === 'active')),
            'total' => count($agents),
            'gateway' => $status['gateway'],
            'checked_at' => $status['checked_at'],
        ]);
    }

    public function tasks(): JsonResponse
    {
        $status = $this->statusService->getStatus();
        $tasks = $status['tasks'] ?? [];
        $summary = $this->statusService->summarizeTasks($tasks);

        return response()->json([
            'total' => $summary['total'],
            'grouped' => [
                'active' => $summary['active'],
                'queued' => $summary['queued'],
                'failed' => $summary['failed'],
                'completed' => $summary['completed'],
            ],
            'recent_failed' => array_values(array_filter($tasks, fn($t) => in_array($t['status'] ?? '', ['failed', 'error', 'lost'], true))),
        ]);
    }

    public function taskSummary(): JsonResponse
    {
        $status = $this->statusService->getStatus();

        return response()->json(
            $this->statusService->summarizeTasks($status['tasks'] ?? [])
        );
    }

    public function scheduledTasks(): JsonResponse
    {
        $status = $this->statusService->getStatus();

        return response()->json([
            'tasks' => $this->statusService->mapScheduledTasksForUi($status['scheduled_tasks'] ?? []),
            'checked_at' => $status['checked_at'],
        ]);
    }

    public function uiLinks(): JsonResponse
    {
        return response()->json([
            'minions_url' => config('hermes.minions_base_url'),
            'studio_url' => config('hermes.studio_base_url'),
            'claw3d_ws_url' => config('hermes.claw3d_ws_url'),
            'dashboard_url' => config('hermes.dashboard_base_url'),
            'api_base_url' => config('hermes.api_base_url'),
            'studio_access_token' => config('hermes.studio_access_token'),
        ]);
    }

    public function chat(Request $request, string $agent): JsonResponse
    {
        if (! array_key_exists($agent, \App\Services\Hermes\HermesAgentCatalog::CATALOG)) {
            return response()->json([
                'success' => false,
                'error' => 'Unknown agent',
            ], 404);
        }

        $validated = $request->validate([
            'message' => 'required|string|max:4000',
            'history' => 'array|max:12',
            'history.*.role' => 'required|string|in:user,assistant,system',
            'history.*.content' => 'required|string|max:4000',
        ]);

        $history = array_slice($validated['history'] ?? [], -10);
        $messages = [
            ...$history,
            ['role' => 'user', 'content' => $validated['message']],
        ];

        [$payload, $status] = $this->chatService->chat($agent, $messages);

        return response()->json($payload, $status);
    }
}
