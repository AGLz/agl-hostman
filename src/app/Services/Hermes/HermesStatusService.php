<?php

declare(strict_types=1);

namespace App\Services\Hermes;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;

final class HermesStatusService
{
    /**
     * @return array{
     *     gateway: string,
     *     agents: array<string, mixed>,
     *     sessions: int,
     *     sessions_data: array<int, mixed>,
     *     tasks: array<int, mixed>,
     *     scheduled_tasks: array<int, mixed>,
     *     source: string,
     *     base_url: string,
     *     minions_url: string,
     *     studio_url: string,
     *     claw3d_ws_url: string,
     *     dashboard_url: string,
     *     checked_at: string,
     *     health?: mixed,
     *     minions_health?: mixed,
     *     remote_error?: string
     * }
     */
    public function getStatus(): array
    {
        return Cache::remember('hermes_status', 5, function () {
            $baseUrl = config('hermes.api_base_url');
            $minionsUrl = config('hermes.minions_base_url');
            $timeout = (int) config('hermes.health_timeout');

            $result = [
                'gateway' => 'offline',
                'agents' => $this->buildAgentCatalog(false),
                'sessions' => 0,
                'sessions_data' => [],
                'tasks' => [],
                'scheduled_tasks' => [],
                'source' => 'ct188-http',
                'base_url' => $baseUrl,
                'minions_url' => $minionsUrl,
                'studio_url' => config('hermes.studio_base_url'),
                'claw3d_ws_url' => config('hermes.claw3d_ws_url'),
                'dashboard_url' => config('hermes.dashboard_base_url'),
                'checked_at' => now()->toIso8601String(),
            ];

            try {
                $request = Http::timeout($timeout);
                $apiKey = config('hermes.api_key');
                if ($apiKey) {
                    $request = $request->withToken($apiKey);
                }

                $response = $request->get($baseUrl . '/health');
                $gatewayOnline = $response->successful();
                $result['gateway'] = $gatewayOnline ? 'running' : 'degraded';
                $result['health'] = $response->json() ?? ['http_status' => $response->status()];
                $result['agents'] = $this->buildAgentCatalog($gatewayOnline);
            } catch (\Throwable $e) {
                $result['health'] = ['error' => $e->getMessage()];
            }

            try {
                $minionsResponse = Http::timeout($timeout)->get($minionsUrl . '/api/health');
                $result['minions_health'] = $minionsResponse->json() ?? ['http_status' => $minionsResponse->status()];
            } catch (\Throwable $e) {
                $result['minions_health'] = ['error' => $e->getMessage()];
            }

            try {
                $tasksResponse = Http::timeout($timeout)->get($minionsUrl . '/api/tasks');
                if ($tasksResponse->successful()) {
                    $result['tasks'] = $tasksResponse->json('tasks') ?? [];
                }
            } catch (\Throwable $e) {
                $result['remote_error'] = str($e->getMessage())->limit(500)->toString();
            }

            try {
                $cronResponse = Http::timeout($timeout)->get($minionsUrl . '/api/scheduled-tasks');
                if ($cronResponse->successful()) {
                    $result['scheduled_tasks'] = $cronResponse->json('scheduledTasks') ?? [];
                }
            } catch (\Throwable) {
                // Minions cron optional for dashboard shell
            }

            return $result;
        });
    }

    /**
     * @param  array<string, mixed>  $agents
     * @return array{executive: array<string, mixed>, infrastructure: array<string, mixed>}
     */
    public function categorizeAgents(array $agents): array
    {
        $categorized = [
            'executive' => [],
            'infrastructure' => [],
        ];

        foreach ($agents as $id => $agent) {
            if (($agent['group'] ?? '') === 'Infrastructure') {
                $categorized['infrastructure'][$id] = $agent;
            } else {
                $categorized['executive'][$id] = $agent;
            }
        }

        return $categorized;
    }

    /**
     * @return array<string, mixed>
     */
    private function buildAgentCatalog(bool $gatewayOnline): array
    {
        $agents = [];

        foreach (HermesAgentCatalog::CATALOG as $id => $agent) {
            $isGateway = $id === 'jarvis';
            $status = ! $gatewayOnline ? 'error' : ($isGateway ? 'active' : 'standby');

            $agents[$id] = [
                'id' => $id,
                'name' => $agent['name'],
                'role' => $agent['role'],
                'group' => $agent['group'],
                'profile' => $agent['profile'],
                'status' => $status,
                'sessions' => 0,
                'currentTask' => $status === 'active' ? 'Gateway API online' : 'Telegram profile',
                'lastActive' => $gatewayOnline ? 'live' : 'unreachable',
                'error' => $status === 'error' ? 'Hermes API health check failed' : null,
            ];
        }

        return $agents;
    }

    /**
     * @param  array<int, array<string, mixed>>  $tasks
     * @return array{
     *     total: int,
     *     active: int,
     *     queued: int,
     *     failed: int,
     *     completed: int,
     *     recent: array<int, mixed>,
     *     checked_at: string
     * }
     */
    public function summarizeTasks(array $tasks): array
    {
        $activeStatuses = ['in_progress', 'running'];
        $reviewStatuses = ['in_review', 'review', 'queued'];
        $failedStatuses = ['failed', 'error', 'lost'];
        $doneStatuses = ['done', 'completed', 'succeeded'];

        return [
            'total' => count($tasks),
            'active' => count(array_filter($tasks, fn($t) => in_array($t['status'] ?? '', $activeStatuses, true))),
            'queued' => count(array_filter($tasks, fn($t) => in_array($t['status'] ?? '', $reviewStatuses, true))),
            'failed' => count(array_filter($tasks, fn($t) => in_array($t['status'] ?? '', $failedStatuses, true))),
            'completed' => count(array_filter($tasks, fn($t) => in_array($t['status'] ?? '', $doneStatuses, true))),
            'recent' => array_slice($tasks, 0, 10),
            'checked_at' => now()->toIso8601String(),
        ];
    }

    /**
     * @param  array<int, array<string, mixed>>  $scheduledTasks
     * @return array<int, array<string, mixed>>
     */
    public function mapScheduledTasksForUi(array $scheduledTasks): array
    {
        return array_map(function (array $task): array {
            $lastStatus = (string) ($task['lastStatus'] ?? 'unknown');

            return [
                'id' => $task['id'] ?? null,
                'name' => $task['name'] ?? 'unnamed',
                'interval' => $task['scheduleDisplay'] ?? data_get($task, 'schedule.expr', '—'),
                'status' => match (true) {
                    $lastStatus === 'ok' => 'succeeded',
                    in_array($lastStatus, ['error', 'failed'], true) => 'failed',
                    default => 'running',
                },
                'lastRun' => $task['lastRunAt'] ?? null,
                'nextRun' => $task['nextRunAt'] ?? null,
                'description' => str($task['prompt'] ?? '')->limit(120)->toString(),
                'enabled' => (bool) ($task['enabled'] ?? false),
            ];
        }, $scheduledTasks);
    }
}
