<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Cache;
use Symfony\Component\Process\Exception\ProcessTimedOutException;
use Symfony\Component\Process\Process;

class OpenClawController extends Controller
{
    private const AGENT_CATALOG = [
        'main' => ['name' => 'Main Agent', 'role' => 'Coordinator', 'group' => 'Core'],
        'devops' => ['name' => 'DevOps Agent', 'role' => 'DevOps Engineer', 'group' => 'Core'],
        'security' => ['name' => 'Security Agent', 'role' => 'Security Analyst', 'group' => 'Core'],
        'sre-team' => ['name' => 'SRE Team', 'role' => 'Site Reliability', 'group' => 'Operations'],
        'infra-manager' => ['name' => 'Infra Manager', 'role' => 'Infrastructure Manager', 'group' => 'Operations'],
        'release-manager' => ['name' => 'Release Manager', 'role' => 'Release Coordination', 'group' => 'Operations'],
        'scr-agl-hostman' => ['name' => 'Scrum - Hostman', 'role' => 'Project Tracking', 'group' => 'Scrum Agents'],
        'scr-api8' => ['name' => 'Scrum - API8', 'role' => 'API Tracking', 'group' => 'Scrum Agents'],
        'scr-api9' => ['name' => 'Scrum - API9', 'role' => 'API Tracking', 'group' => 'Scrum Agents'],
        'scr-crowbar' => ['name' => 'Scrum - Crowbar', 'role' => 'Project Tracking', 'group' => 'Scrum Agents'],
        'altman' => ['name' => 'Altman', 'role' => 'AI Advisor', 'group' => 'Specialists'],
        'gates' => ['name' => 'Gates', 'role' => 'Tech Advisor', 'group' => 'Specialists'],
        'hassabis' => ['name' => 'Hassabis', 'role' => 'AI Research', 'group' => 'Specialists'],
        'karpathy' => ['name' => 'Karpathy', 'role' => 'ML Advisor', 'group' => 'Specialists'],
        'musk' => ['name' => 'Musk', 'role' => 'Strategy Advisor', 'group' => 'Specialists'],
    ];

    private const AGENT_ROLE_HINTS = [
        'coder' => ['name' => 'Coder', 'role' => 'Code Implementation', 'group' => 'Engineering'],
        'planner' => ['name' => 'Planner', 'role' => 'Planning', 'group' => 'Engineering'],
        'researcher' => ['name' => 'Researcher', 'role' => 'Research', 'group' => 'Engineering'],
        'reviewer' => ['name' => 'Reviewer', 'role' => 'Code Review', 'group' => 'Engineering'],
        'tester' => ['name' => 'Tester', 'role' => 'Quality Assurance', 'group' => 'Engineering'],
        'infra' => ['name' => 'Infra', 'role' => 'Infrastructure', 'group' => 'Operations'],
        'storage' => ['name' => 'Storage', 'role' => 'Storage Operations', 'group' => 'Operations'],
        'harbor' => ['name' => 'Harbor', 'role' => 'Registry Operations', 'group' => 'Operations'],
        'net' => ['name' => 'Network', 'role' => 'Network Operations', 'group' => 'Operations'],
        'openclaw-expert' => ['name' => 'OpenClaw Expert', 'role' => 'OpenClaw Specialist', 'group' => 'Specialists'],
    ];

    /**
     * Get OpenClaw status overview
     */
    public function index(): JsonResponse
    {
        $status = $this->getOpenClawStatus();
        
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

    /**
     * Get detailed agent information
     */
    public function agents(): JsonResponse
    {
        $status = $this->getOpenClawStatus();
        $agents = $status['agents'] ?? [];
        
        // Organize agents by category
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
        
        return response()->json([
            'total' => count($agents),
            'active' => count(array_filter($agents, fn($a) => ($a['status'] ?? '') === 'active')),
            'categorized' => $categorized,
            'agents' => array_values($agents),
            'checked_at' => $status['checked_at'],
        ]);
    }

    /**
     * Flat list used by Mission Control dashboards.
     */
    public function agentList(): JsonResponse
    {
        $status = $this->getOpenClawStatus();

        return response()->json(array_values($status['agents'] ?? []));
    }

    /**
     * Get active sessions
     */
    public function sessions(): JsonResponse
    {
        $status = $this->getOpenClawStatus();
        $sessions = $status['sessions_data'] ?? [];
        
        return response()->json([
            'total' => $status['sessions'] ?? 0,
            'recent' => array_slice($sessions, 0, 20),
        ]);
    }

    /**
     * Get tasks overview
     */
    public function tasks(): JsonResponse
    {
        $status = $this->getOpenClawStatus();
        $tasks = $status['tasks'] ?? [];
        
        $grouped = [
            'active' => array_filter($tasks, fn($t) => ($t['status'] ?? '') === 'running'),
            'queued' => array_filter($tasks, fn($t) => ($t['status'] ?? '') === 'queued'),
            'failed' => array_filter($tasks, fn($t) => in_array($t['status'] ?? '', ['failed', 'lost'])),
            'completed' => array_filter($tasks, fn($t) => ($t['status'] ?? '') === 'succeeded'),
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

    /**
     * Task summary used by Mission Control dashboards.
     */
    public function taskSummary(): JsonResponse
    {
        $status = $this->getOpenClawStatus();
        $tasks = $status['tasks'] ?? [];

        return response()->json([
            'total' => count($tasks),
            'active' => count(array_filter($tasks, fn($t) => ($t['status'] ?? '') === 'running')),
            'failed' => count(array_filter($tasks, fn($t) => in_array($t['status'] ?? '', ['failed', 'lost']))),
            'completed' => count(array_filter($tasks, fn($t) => ($t['status'] ?? '') === 'succeeded')),
            'checked_at' => $status['checked_at'],
        ]);
    }

    /**
     * Send a direct test message to one OpenClaw agent.
     */
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

        if ($this->chatTransport() === 'http') {
            return $this->chatViaHttp($agent, $messages);
        }

        return $this->chatViaRemoteCli($agent, $validated['message']);
    }

    private function chatViaHttp(string $agent, array $messages): JsonResponse
    {
        $token = env('OPENCLAW_GATEWAY_TOKEN');
        if (! $token) {
            return response()->json([
                'success' => false,
                'error' => 'OPENCLAW_GATEWAY_TOKEN is not configured for direct agent chat',
            ], 503);
        }

        $baseUrl = rtrim(env('OPENCLAW_CHAT_BASE_URL', env('OPENCLAW_BASE_URL', 'http://100.123.184.125:28789')), '/');

        try {
            $started = microtime(true);
            $response = Http::timeout((int) env('OPENCLAW_CHAT_TIMEOUT', 90))
                ->withHeaders([
                    'Authorization' => 'Bearer '.$token,
                    'x-openclaw-agent-id' => $agent,
                ])
                ->post($baseUrl.'/v1/chat/completions', [
                    'model' => 'openclaw/'.$agent,
                    'messages' => $messages,
                    'stream' => false,
                    'max_tokens' => 900,
                ]);

            if (! $response->successful()) {
                return response()->json([
                    'success' => false,
                    'error' => 'OpenClaw chat request failed',
                    'http_status' => $response->status(),
                    'body' => str($response->body())->limit(500)->toString(),
                ], 502);
            }

            $data = $response->json();
            $message = data_get($data, 'choices.0.message.content');

            return response()->json([
                'success' => true,
                'agent' => $agent,
                'message' => $message,
                'latency_ms' => (int) round((microtime(true) - $started) * 1000),
                'usage' => $data['usage'] ?? null,
                'raw' => $message ? null : $data,
                'timestamp' => now()->toIso8601String(),
            ]);
        } catch (\Throwable $e) {
            return response()->json([
                'success' => false,
                'error' => 'OpenClaw chat unavailable',
                'message' => $e->getMessage(),
            ], 502);
        }
    }

    private function chatViaRemoteCli(string $agent, string $message): JsonResponse
    {
        try {
            $started = microtime(true);
            $timeout = (int) env('OPENCLAW_CHAT_TIMEOUT', 90);
            $result = $this->runRemoteOpenClaw([
                'agent',
                '--agent',
                $agent,
                '--message',
                $message,
                '--json',
                '--timeout',
                (string) $timeout,
            ], $timeout + 15);

            if (! $result['success']) {
                return response()->json([
                    'success' => false,
                    'error' => 'OpenClaw agent command failed',
                    'body' => str($result['output'])->limit(500)->toString(),
                ], 502);
            }

            $data = $this->decodeJsonOutput($result['output']);
            $payloads = data_get($data, 'result.payloads', data_get($data, 'payloads', []));
            $firstPayload = is_array($payloads) ? ($payloads[0] ?? []) : [];
            $text = $firstPayload['text'] ?? data_get($data, 'result.finalAssistantVisibleText');

            return response()->json([
                'success' => filled($text),
                'agent' => $agent,
                'message' => $text,
                'latency_ms' => (int) round((microtime(true) - $started) * 1000),
                'usage' => data_get($data, 'result.meta.agentMeta.lastCallUsage'),
                'model' => data_get($data, 'result.meta.agentMeta.model'),
                'provider' => data_get($data, 'result.meta.agentMeta.provider'),
                'session_id' => data_get($data, 'result.meta.agentMeta.sessionId'),
                'raw' => filled($text) ? null : $data,
                'timestamp' => now()->toIso8601String(),
            ], filled($text) ? 200 : 502);
        } catch (ProcessTimedOutException $e) {
            return response()->json([
                'success' => false,
                'error' => 'OpenClaw agent command timed out',
            ], 504);
        } catch (\Throwable $e) {
            return response()->json([
                'success' => false,
                'error' => 'OpenClaw chat unavailable',
                'message' => $e->getMessage(),
            ], 502);
        }
    }

    /**
     * Execute OpenClaw command and return result
     */
    public function execute(Request $request): JsonResponse
    {
        $command = $request->input('command');
        $args = $request->input('args', []);
        
        if (!$command) {
            return response()->json(['error' => 'Command required'], 400);
        }
        
        $result = $this->runOpenClawCommand($command, $args);
        
        return response()->json($result);
    }

    /**
     * Get OpenClaw status by running CLI commands
     */
    private function getOpenClawStatus(): array
    {
        return Cache::remember('openclaw_status', 5, function () {
            $baseUrl = rtrim(env('OPENCLAW_BASE_URL', 'http://100.123.184.125:28789'), '/');
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

            if ($this->remoteStatusEnabled()) {
                $remote = $this->runRemoteOpenClaw(['gateway', 'call', 'health', '--timeout', '30000', '--json'], 45);
                if ($remote['success']) {
                    $this->mergeGatewayHealth($result, $this->decodeJsonOutput($remote['output']));
                    $result['source'] = 'ct187-ssh-docker-gateway';
                } else {
                    $result['remote_error'] = str($remote['output'])->limit(500)->toString();
                }
            }

            return $result;
        });
    }

    /**
     * Run OpenClaw CLI command
     */
    private function runOpenClawCommand(string $command, array $args = []): array
    {
        $checkCmd = 'command -v openclaw >/dev/null 2>&1 && echo "installed" || echo "not_installed"';
        if (trim(shell_exec($checkCmd)) !== 'installed') {
            return ['success' => false, 'error' => 'OpenClaw not installed'];
        }
        
        $cmd = 'openclaw ' . escapeshellarg($command);
        foreach ($args as $arg) {
            $cmd .= ' ' . escapeshellarg($arg);
        }
        $cmd .= ' 2>&1';
        
        $output = shell_exec($cmd);
        
        return [
            'success' => true,
            'output' => $output,
            'command' => $command,
        ];
    }

    private function buildAgentCatalog(bool $gatewayOnline): array
    {
        $agents = [];

        foreach (self::AGENT_CATALOG as $id => $agent) {
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

    private function buildAgentsFromGatewayHealth(array $health): array
    {
        $agents = [];

        foreach (($health['agents'] ?? []) as $agent) {
            $id = $agent['agentId'] ?? null;
            if (! is_string($id) || $id === '') {
                continue;
            }

            $meta = self::AGENT_CATALOG[$id] ?? self::AGENT_ROLE_HINTS[$id] ?? $this->inferAgentMetadata($id);
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

    private function inferAgentMetadata(string $id): array
    {
        $name = str($id)->replace(['-', '_'], ' ')->title()->toString();

        return [
            'name' => $name,
            'role' => str_starts_with($id, 'scr-') ? 'Scrum Tracking' : 'OpenClaw Agent',
            'group' => match (true) {
                str_starts_with($id, 'scr-') => 'Scrum Agents',
                in_array($id, ['altman', 'bezos', 'gates', 'hassabis', 'hinton', 'karpathy', 'musk', 'nadella', 'norvig', 'pichai'], true) => 'Specialists',
                in_array($id, ['devops', 'infra', 'infra-manager', 'sre-team', 'storage', 'harbor', 'net'], true) => 'Operations',
                default => 'Core',
            },
        ];
    }

    private function formatGatewayTimestamp(int $timestampMs): string
    {
        if ($timestampMs <= 0) {
            return 'unknown';
        }

        return now()->setTimestamp((int) floor($timestampMs / 1000))->toIso8601String();
    }

    private function runRemoteOpenClaw(array $openClawArgs, int $timeout): array
    {
        $host = env('OPENCLAW_SSH_HOST', 'root@100.123.184.125');
        $container = env('OPENCLAW_DOCKER_CONTAINER', 'agl-openclaw-openclaw-gateway-1');
        $connectTimeout = (string) env('OPENCLAW_SSH_CONNECT_TIMEOUT', 8);
        $remoteCommand = implode(' ', [
            'docker',
            'exec',
            $this->remoteShellArg($container),
            'openclaw',
            ...array_map(fn ($arg) => $this->remoteShellArg((string) $arg), $openClawArgs),
        ]);

        $process = new Process([
            'ssh',
            '-o',
            'BatchMode=yes',
            '-o',
            'ConnectTimeout='.$connectTimeout,
            $host,
            $remoteCommand,
        ]);
        $process->setTimeout($timeout);
        $process->run();

        return [
            'success' => $process->isSuccessful(),
            'output' => trim($process->getOutput()."\n".$process->getErrorOutput()),
            'exit_code' => $process->getExitCode(),
        ];
    }

    private function remoteShellArg(string $value): string
    {
        return "'".str_replace("'", "'\\''", $value)."'";
    }

    private function decodeJsonOutput(string $output): array
    {
        $decoded = json_decode($output, true);
        if (is_array($decoded)) {
            return $decoded;
        }

        if (preg_match('/\{.*\}/s', $output, $matches)) {
            $decoded = json_decode($matches[0], true);
            if (is_array($decoded)) {
                return $decoded;
            }
        }

        return [];
    }

    private function remoteStatusEnabled(): bool
    {
        return filter_var(env('OPENCLAW_REMOTE_STATUS_ENABLED', true), FILTER_VALIDATE_BOOLEAN);
    }

    private function chatTransport(): string
    {
        return strtolower((string) env('OPENCLAW_CHAT_TRANSPORT', 'ssh-docker'));
    }

    /**
     * Parse agents list output
     */
    private function parseAgentsOutput(string $output): array
    {
        $agents = [];
        $lines = explode("\n", $output);
        
        foreach ($lines as $line) {
            // Parse agent lines from openclaw agents list
            if (preg_match('/(\S+)\s+(\w+)\s+(.+?)(?:\s+(\d+)\s+sessions)?/i', $line, $matches)) {
                $id = $matches[1];
                $agents[$id] = [
                    'id' => $id,
                    'status' => strtolower($matches[2]) === 'on' ? 'active' : 'standby',
                    'role' => trim($matches[3]),
                    'sessions' => isset($matches[4]) ? (int)$matches[4] : 0,
                ];
            }
        }
        
        return $agents;
    }

    /**
     * Parse tasks list output
     */
    private function parseTasksOutput(string $output): array
    {
        $tasks = [];
        $lines = explode("\n", $output);
        
        foreach ($lines as $line) {
            if (preg_match('/([a-f0-9-]+)\s+(\w+)\s+(\w+)\s+(.+)/i', $line, $matches)) {
                $tasks[] = [
                    'id' => $matches[1],
                    'kind' => $matches[2],
                    'status' => $matches[3],
                    'summary' => trim($matches[4]),
                ];
            }
        }
        
        return $tasks;
    }

    /**
     * Get mock data when OpenClaw is not available
     */
    private function getMockData(): array
    {
        return [
            'gateway' => 'running',
            'agents' => [
                'main' => ['id' => 'main', 'name' => 'Main Agent', 'role' => 'Coordinator', 'status' => 'active', 'sessions' => 12, 'lastActive' => '2m ago'],
                'devops' => ['id' => 'devops', 'name' => 'DevOps Agent', 'role' => 'DevOps Engineer', 'status' => 'active', 'sessions' => 8, 'lastActive' => '5m ago'],
                'security' => ['id' => 'security', 'name' => 'Security Agent', 'role' => 'Security Analyst', 'status' => 'active', 'sessions' => 15, 'lastActive' => '1m ago'],
                'sre-team' => ['id' => 'sre-team', 'name' => 'SRE Team', 'role' => 'Site Reliability', 'status' => 'active', 'sessions' => 6, 'lastActive' => '10m ago'],
                'infra-manager' => ['id' => 'infra-manager', 'name' => 'Infra Manager', 'role' => 'Infrastructure Manager', 'status' => 'active', 'sessions' => 4, 'lastActive' => '15m ago'],
                'release-manager' => ['id' => 'release-manager', 'name' => 'Release Manager', 'role' => 'Release Coordination', 'status' => 'standby', 'sessions' => 2, 'lastActive' => '1h ago'],
                'scr-agl-hostman' => ['id' => 'scr-agl-hostman', 'name' => 'Scrum - Hostman', 'role' => 'Project Tracking', 'status' => 'active', 'sessions' => 20, 'lastActive' => '3m ago'],
                'scr-api8' => ['id' => 'scr-api8', 'name' => 'Scrum - API8', 'role' => 'API Tracking', 'status' => 'standby', 'sessions' => 5, 'lastActive' => '30m ago'],
                'scr-api9' => ['id' => 'scr-api9', 'name' => 'Scrum - API9', 'role' => 'API Tracking', 'status' => 'standby', 'sessions' => 3, 'lastActive' => '45m ago'],
                'scr-crowbar' => ['id' => 'scr-crowbar', 'name' => 'Scrum - Crowbar', 'role' => 'Project Tracking', 'status' => 'standby', 'sessions' => 1, 'lastActive' => '2h ago'],
                'altman' => ['id' => 'altman', 'name' => 'Altman', 'role' => 'AI Advisor', 'status' => 'standby', 'sessions' => 0, 'lastActive' => '1d ago'],
                'musk' => ['id' => 'musk', 'name' => 'Musk', 'role' => 'Strategy Advisor', 'status' => 'standby', 'sessions' => 0, 'lastActive' => '2d ago'],
                'gates' => ['id' => 'gates', 'name' => 'Gates', 'role' => 'Tech Advisor', 'status' => 'standby', 'sessions' => 0, 'lastActive' => '3d ago'],
                'hassabis' => ['id' => 'hassabis', 'name' => 'Hassabis', 'role' => 'AI Research', 'status' => 'standby', 'sessions' => 0, 'lastActive' => '1d ago'],
                'hinton' => ['id' => 'hinton', 'name' => 'Hinton', 'role' => 'AI Research', 'status' => 'standby', 'sessions' => 0, 'lastActive' => '4d ago'],
                'karpathy' => ['id' => 'karpathy', 'name' => 'Karpathy', 'role' => 'ML Advisor', 'status' => 'standby', 'sessions' => 0, 'lastActive' => '2d ago'],
                'nadella' => ['id' => 'nadella', 'name' => 'Nadella', 'role' => 'Cloud Strategy', 'status' => 'standby', 'sessions' => 0, 'lastActive' => '3d ago'],
                'pichai' => ['id' => 'pichai', 'name' => 'Pichai', 'role' => 'AI Strategy', 'status' => 'standby', 'sessions' => 0, 'lastActive' => '2d ago'],
            ],
            'sessions' => 51,
            'sessions_data' => [],
            'tasks' => [],
        ];
    }
}
