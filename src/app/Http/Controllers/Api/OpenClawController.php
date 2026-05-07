<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\OpenClaw\OpenClawChatService;
use App\Services\OpenClaw\OpenClawLocalCliService;
use App\Services\OpenClaw\OpenClawStatusService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class OpenClawController extends Controller
{
    public function __construct(
        private readonly OpenClawStatusService $statusService,
        private readonly OpenClawChatService $chatService,
        private readonly OpenClawLocalCliService $localCli,
    ) {}

    public function index(): JsonResponse
    {
        $status = $this->statusService->getStatus();

        return response()->json([
            'status' => $status['gateway'] === 'running' ? 'online' : 'offline',
            'gateway' => $status['gateway'],
            'agents' => $status['agents'] ?? [],
            'sessions' => $status['sessions'] ?? 0,
            'tasks' => $status['tasks'] ?? [],
            'source' => $status['source'],
            'base_url' => $status['base_url'],
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
            'active' => count(array_filter($agents, fn ($a) => ($a['status'] ?? '') === 'active')),
            'standby' => count(array_filter($agents, fn ($a) => in_array($a['status'] ?? '', ['idle', 'standby'], true))),
            'errors' => count(array_filter($agents, fn ($a) => ($a['status'] ?? '') === 'error')),
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

    public function sessions(): JsonResponse
    {
        $status = $this->statusService->getStatus();
        $sessions = $status['sessions_data'] ?? [];

        return response()->json([
            'total' => $status['sessions'] ?? 0,
            'recent' => array_slice($sessions, 0, 20),
        ]);
    }

    public function tasks(): JsonResponse
    {
        $status = $this->statusService->getStatus();
        $tasks = $status['tasks'] ?? [];

        $grouped = [
            'active' => array_filter($tasks, fn ($t) => ($t['status'] ?? '') === 'running'),
            'queued' => array_filter($tasks, fn ($t) => ($t['status'] ?? '') === 'queued'),
            'failed' => array_filter($tasks, fn ($t) => in_array($t['status'] ?? '', ['failed', 'lost'])),
            'completed' => array_filter($tasks, fn ($t) => ($t['status'] ?? '') === 'succeeded'),
        ];

        return response()->json([
            'total' => count($tasks),
            'grouped' => [
                'active' => count($grouped['active']),
                'queued' => count($grouped['queued']),
                'failed' => count($grouped['failed']),
                'completed' => count($grouped['completed']),
            ],
            'recent_failed' => array_slice($grouped['failed'], 0, 10),
        ]);
    }

    public function taskSummary(): JsonResponse
    {
        $status = $this->statusService->getStatus();
        $tasks = $status['tasks'] ?? [];

        return response()->json([
            'total' => count($tasks),
            'active' => count(array_filter($tasks, fn ($t) => ($t['status'] ?? '') === 'running')),
            'queued' => count(array_filter($tasks, fn ($t) => ($t['status'] ?? '') === 'queued')),
            'failed' => count(array_filter($tasks, fn ($t) => in_array($t['status'] ?? '', ['failed', 'lost']))),
            'completed' => count(array_filter($tasks, fn ($t) => ($t['status'] ?? '') === 'succeeded')),
            'recent' => array_slice($tasks, 0, 10),
            'checked_at' => $status['checked_at'],
        ]);
    }

    public function chat(Request $request, string $agent): JsonResponse
    {
        if (! preg_match('/^[A-Za-z0-9_.-]+$/', $agent)) {
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

        if ($this->chatService->transport() === 'http') {
            [$payload, $status] = $this->chatService->chatViaHttp($agent, $messages);

            return response()->json($payload, $status);
        }

        [$payload, $status] = $this->chatService->chatViaRemoteCli($agent, $validated['message']);

        return response()->json($payload, $status);
    }

    public function execute(Request $request): JsonResponse
    {
        $command = $request->input('command');
        $args = $request->input('args', []);

        if (! $command) {
            return response()->json(['error' => 'Command required'], 400);
        }

        $result = $this->localCli->run((string) $command, is_array($args) ? $args : []);

        return response()->json($result);
    }
}
