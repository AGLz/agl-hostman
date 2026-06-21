<?php

declare(strict_types=1);

namespace App\Services\Harness;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Process;
use Illuminate\Support\Str;

final class HarnessSnapshotService
{
    /**
     * @return array<string, mixed>
     */
    public function getSnapshot(): array
    {
        $ttl = (int) config('harness.cache_ttl', 15);

        return Cache::remember('harness_snapshot', $ttl, function (): array {
            $governor = $this->loadGovernorState();
            $teams = $this->loadTeamsManifest();
            $bdReady = $this->loadBdReady();
            $agentOs = $this->loadAgentOsQueue();

            return [
                'checked_at' => now()->toIso8601String(),
                'source' => $governor['source'] ?? 'fallback',
                'litellm_gateway_url' => config('harness.litellm_gateway_url'),
                'governor' => $governor['data'],
                'teams' => $teams,
                'harnesses' => $this->harnessMatrix(),
                'work_queue' => [
                    'bd_ready' => $bdReady,
                    'bd_ready_count' => count($bdReady),
                    'agent_os_specs' => $agentOs,
                ],
                'cursor' => [
                    'note' => 'Pool Pro Cursor — sem API de quota; usar Auto ou LiteLLM virtual key',
                    'auth_modes' => ['cursor-pro', 'litellm'],
                ],
                'hermes' => [
                    'tier' => $governor['data']['hermes_tier'] ?? ($governor['data']['hermes_applied'] ?? false ? 'free' : 'paid'),
                    'hermes_applied' => (bool) ($governor['data']['hermes_applied'] ?? false),
                ],
            ];
        });
    }

    /**
     * @return array{data: array<string, mixed>, source: string}
     */
    private function loadGovernorState(): array
    {
        foreach (
            [
                (string) config('harness.governor_state_path'),
                (string) config('harness.governor_state_fallback'),
            ] as $path
        ) {
            if (! is_string($path) || $path === '' || ! File::isFile($path)) {
                continue;
            }

            $decoded = json_decode((string) File::get($path), true);
            if (is_array($decoded)) {
                return [
                    'data' => $decoded,
                    'source' => $path === config('harness.governor_state_fallback') ? 'example' : 'live',
                ];
            }
        }

        return [
            'data' => [
                'action' => 'unknown',
                'reason' => 'Governor state em falta — correr quota-governor.sh',
                'gateway_ok' => false,
            ],
            'source' => 'missing',
        ];
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function loadTeamsManifest(): array
    {
        $path = (string) config('harness.virtual_keys_manifest');
        if (! File::isFile($path)) {
            return [];
        }

        $decoded = json_decode((string) File::get($path), true);
        if (! is_array($decoded) || ! isset($decoded['teams']) || ! is_array($decoded['teams'])) {
            return [];
        }

        return array_values(array_map(static function (array $team): array {
            return [
                'team_alias' => $team['team_alias'] ?? '',
                'harness' => $team['harness'] ?? '',
                'max_budget_usd' => $team['max_budget_usd'] ?? null,
                'keys' => array_map(
                    static fn(array $key): array => [
                        'key_alias' => $key['key_alias'] ?? '',
                        'models_count' => is_array($key['models'] ?? null) ? count($key['models']) : 0,
                    ],
                    is_array($team['keys'] ?? null) ? $team['keys'] : [],
                ),
            ];
        }, $decoded['teams']));
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function loadBdReady(): array
    {
        if (! $this->commandExists('bd')) {
            return [];
        }

        $repoRoot = (string) config('harness.repo_root');
        $result = Process::path($repoRoot)->timeout(8)->run(['bd', 'ready', '--json']);

        if (! $result->successful()) {
            return [];
        }

        $decoded = json_decode($result->output(), true);

        return is_array($decoded) ? $decoded : [];
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function loadAgentOsQueue(): array
    {
        $root = rtrim((string) config('harness.repo_root'), '/') . '/agent-os/specs';
        if (! File::isDirectory($root)) {
            return [];
        }

        $specs = [];
        foreach (File::allFiles($root) as $file) {
            if ($file->getFilename() !== 'tasks.md') {
                continue;
            }

            $content = (string) File::get($file->getPathname());
            $open = preg_match_all('/^\s*-\s+\[ \]/m', $content) ?: 0;
            $done = preg_match_all('/^\s*-\s+\[[xX]\]/m', $content) ?: 0;
            $relative = Str::after($file->getPath(), $root . '/');

            $specs[] = [
                'path' => 'agent-os/specs/' . $relative . '/tasks.md',
                'slug' => basename($relative),
                'tasks_open' => $open,
                'tasks_done' => $done,
            ];
        }

        usort($specs, static fn(array $a, array $b): int => $b['tasks_open'] <=> $a['tasks_open']);

        return $specs;
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function harnessMatrix(): array
    {
        return [
            ['id' => 'claude-code', 'skill' => 'agl-claude-code-agent', 'auth_modes' => ['max-direct', 'litellm', 'litellm-free']],
            ['id' => 'cursor', 'skill' => 'agl-cursor-agent', 'auth_modes' => ['cursor-pro', 'litellm']],
            ['id' => 'verdent', 'skill' => 'agl-verdent-agent', 'auth_modes' => ['litellm']],
            ['id' => 'ruflo', 'skill' => 'agl-ruflo-orchestrator', 'auth_modes' => ['max-direct', 'litellm', 'mixed']],
        ];
    }

    private function commandExists(string $command): bool
    {
        $result = Process::run(['bash', '-lc', 'command -v ' . escapeshellarg($command)]);

        return $result->successful() && trim($result->output()) !== '';
    }
}
