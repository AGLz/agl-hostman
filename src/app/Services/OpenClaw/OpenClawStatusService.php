<?php

declare(strict_types=1);

namespace App\Services\OpenClaw;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;

final class OpenClawStatusService
{
    public function __construct(
        private readonly OpenClawRemoteExecutor $remoteExecutor,
    ) {}

    /**
     * @return array{
     *     gateway: string,
     *     agents: array<string, mixed>,
     *     sessions: int,
     *     sessions_data: array<int, mixed>,
     *     tasks: array<int, mixed>,
     *     source: string,
     *     base_url: string,
     *     checked_at: string,
     *     health?: mixed,
     *     remote_error?: string
     * }
     */
    public function getStatus(): array
    {
        return Cache::remember('openclaw_status', 5, function () {
            $baseUrl = config('openclaw.base_url');
            $result = [
                'gateway' => 'offline',
                'agents' => $this->buildAgentCatalog(false),
                'sessions' => 0,
                'sessions_data' => [],
                'tasks' => [],
                'source' => 'ct187-http',
                'base_url' => $baseUrl,
                'checked_at' => now()->toIso8601String(),
            ];

            try {
                $response = Http::timeout(5)->get($baseUrl.'/healthz');
                $result['gateway'] = $response->successful() ? 'running' : 'degraded';
                $result['health'] = $response->json() ?? ['http_status' => $response->status()];
                $result['agents'] = $this->buildAgentCatalog($response->successful());
            } catch (\Throwable $e) {
                $result['health'] = ['error' => $e->getMessage()];
            }

            if (config('openclaw.remote_status_enabled')) {
                $remote = $this->remoteExecutor->runOpenClaw(['gateway', 'call', 'health', '--timeout', '30000', '--json'], 45);
                if ($remote['success']) {
                    $this->mergeGatewayHealth($result, $this->remoteExecutor->decodeJsonOutput($remote['output']));
                    $result['source'] = 'ct187-ssh-docker-gateway';
                } else {
                    $result['remote_error'] = str($remote['output'])->limit(500)->toString();
                }
            }

            return $result;
        });
    }

    /**
     * @param  array<string, mixed>  $agents
     * @return array{core: array<string, mixed>, infrastructure: array<string, mixed>, scrum: array<string, mixed>, executive: array<string, mixed>}
     */
    public function categorizeAgents(array $agents): array
    {
        $categorized = [
            'core' => [],
            'infrastructure' => [],
            'scrum' => [],
            'executive' => [],
        ];

        foreach ($agents as $id => $agent) {
            if (str_starts_with($id, 'scr-')) {
                $categorized['scrum'][$id] = $agent;
            } elseif (in_array($id, ['altman', 'musk', 'gates', 'hassabis', 'hinton', 'karpathy', 'nadella', 'pichai'])) {
                $categorized['executive'][$id] = $agent;
            } elseif (in_array($id, ['devops', 'sre-team', 'infra-manager'])) {
                $categorized['infrastructure'][$id] = $agent;
            } else {
                $categorized['core'][$id] = $agent;
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

        foreach (OpenClawAgentCatalog::CATALOG as $id => $agent) {
            $isCore = in_array($id, ['main', 'devops', 'security', 'infra-manager', 'sre-team', 'scr-agl-hostman'], true);
            $status = ! $gatewayOnline ? 'error' : ($isCore ? 'active' : 'standby');

            $agents[$id] = [
                'id' => $id,
                'name' => $agent['name'],
                'role' => $agent['role'],
                'group' => $agent['group'],
                'status' => $status,
                'sessions' => 0,
                'currentTask' => $status === 'active' ? 'Ready for direct test' : '',
                'lastActive' => $gatewayOnline ? 'live' : 'unreachable',
                'error' => $status === 'error' ? 'Gateway health check failed' : null,
            ];
        }

        return $agents;
    }

    /**
     * @param  array<string, mixed>  $result
     * @param  array<string, mixed>  $health
     */
    private function mergeGatewayHealth(array &$result, array $health): void
    {
        $result['gateway'] = ($health['ok'] ?? false) ? 'running' : $result['gateway'];
        $result['health'] = [
            'ok' => $health['ok'] ?? null,
            'duration_ms' => $health['durationMs'] ?? null,
            'default_agent_id' => $health['defaultAgentId'] ?? null,
            'channels' => $health['channels'] ?? [],
        ];
        $result['agents'] = $this->buildAgentsFromGatewayHealth($health);
        $result['sessions'] = (int) data_get($health, 'sessions.count', 0);
        $result['sessions_data'] = data_get($health, 'sessions.recent', []);
    }

    /**
     * @param  array<string, mixed>  $health
     * @return array<string, mixed>
     */
    private function buildAgentsFromGatewayHealth(array $health): array
    {
        $agents = [];

        foreach (($health['agents'] ?? []) as $agent) {
            $id = $agent['agentId'] ?? null;
            if (! is_string($id) || $id === '') {
                continue;
            }

            $meta = OpenClawAgentCatalog::CATALOG[$id] ?? OpenClawAgentCatalog::ROLE_HINTS[$id] ?? OpenClawAgentCatalog::inferMetadata($id);
            $sessionCount = (int) data_get($agent, 'sessions.count', 0);
            $heartbeatEnabled = (bool) data_get($agent, 'heartbeat.enabled', false);
            $recent = data_get($agent, 'sessions.recent.0');

            $agents[$id] = [
                'id' => $id,
                'name' => $meta['name'],
                'role' => $meta['role'],
                'group' => $meta['group'],
                'status' => ($agent['isDefault'] ?? false) || $heartbeatEnabled ? 'active' : 'standby',
                'sessions' => $sessionCount,
                'currentTask' => $heartbeatEnabled ? 'Heartbeat '.data_get($agent, 'heartbeat.every', '') : 'Ready for direct test',
                'lastActive' => $recent ? $this->formatGatewayTimestamp((int) ($recent['updatedAt'] ?? 0)) : 'no sessions',
                'error' => null,
                'isDefault' => (bool) ($agent['isDefault'] ?? false),
                'heartbeat' => [
                    'enabled' => $heartbeatEnabled,
                    'every' => data_get($agent, 'heartbeat.every'),
                ],
            ];
        }

        return $agents ?: $this->buildAgentCatalog(($health['ok'] ?? false) === true);
    }

    private function formatGatewayTimestamp(int $timestampMs): string
    {
        if ($timestampMs <= 0) {
            return 'unknown';
        }

        return now()->setTimestamp((int) floor($timestampMs / 1000))->toIso8601String();
    }
}
