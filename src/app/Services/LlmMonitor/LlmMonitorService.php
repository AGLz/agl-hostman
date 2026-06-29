<?php

declare(strict_types=1);

namespace App\Services\LlmMonitor;

use App\Jobs\ApplyLlmConfigChangeProposalJob;
use App\Models\LlmConfigChangeProposal;
use App\Models\LlmLimitEvent;
use App\Models\LlmProbeRun;
use App\Models\LlmProviderSnapshot;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\File;
use Illuminate\Validation\ValidationException;

final class LlmMonitorService
{
    public function __construct(
        private readonly LiteLLMClient $liteLLMClient,
    ) {}

    /**
     * @return array<string, mixed>
     */
    public function getStatus(): array
    {
        $governor = $this->loadGovernorState();
        $gatewayOk = $this->liteLLMClient->isHealthy();
        $spend = $this->liteLLMClient->getGlobalSpend();
        $spendWarn = (float) config('llm-monitor.spend_warn_usd', 80);

        $latestSnapshots = LlmProviderSnapshot::query()
            ->latestPerModel()
            ->orderByDesc('captured_at')
            ->get();

        $openEvents = LlmLimitEvent::query()
            ->unresolved()
            ->orderByDesc('created_at')
            ->limit(20)
            ->get();

        $pendingProposals = LlmConfigChangeProposal::query()
            ->pending()
            ->orderByDesc('created_at')
            ->limit(10)
            ->get();

        $recentProbes = LlmProbeRun::query()
            ->orderByDesc('created_at')
            ->limit(10)
            ->get();

        $action = is_array($governor) ? ($governor['action'] ?? 'unknown') : 'unknown';
        $overall = $this->deriveOverallStatus($action, $gatewayOk, $openEvents->count(), $spend, $spendWarn);

        return [
            'success' => true,
            'checked_at' => now()->toIso8601String(),
            'overall' => $overall,
            'gateway' => [
                'url' => config('llm-monitor.litellm_gateway_url'),
                'ok' => $gatewayOk,
                'global_spend_usd' => $spend,
                'spend_warn_usd' => $spendWarn,
            ],
            'governor' => $governor ?? [
                'action' => 'unknown',
                'reason' => 'Governor state em falta',
            ],
            'providers' => $latestSnapshots->values()->map(fn(LlmProviderSnapshot $s) => [
                'provider' => $s->provider,
                'model_alias' => $s->model_alias,
                'tier' => $s->tier,
                'status' => $s->status,
                'captured_at' => $s->captured_at?->toIso8601String(),
            ]),
            'limit_events_open' => $openEvents->map(fn(LlmLimitEvent $e) => [
                'id' => $e->id,
                'provider' => $e->provider,
                'model_alias' => $e->model_alias,
                'window' => $e->window,
                'severity' => $e->severity,
                'message' => $e->message,
                'created_at' => $e->created_at?->toIso8601String(),
            ]),
            'pending_proposals' => $pendingProposals->map(fn(LlmConfigChangeProposal $p) => [
                'id' => $p->id,
                'tier' => $p->tier,
                'reason' => $p->reason,
                'status' => $p->status,
                'created_at' => $p->created_at?->toIso8601String(),
            ]),
            'recent_probes' => $recentProbes->map(fn(LlmProbeRun $r) => [
                'id' => $r->id,
                'probe_type' => $r->probe_type,
                'model' => $r->model,
                'result' => $r->result,
                'latency_ms' => $r->latency_ms,
                'created_at' => $r->created_at?->toIso8601String(),
            ]),
        ];
    }

    /**
     * @param  array<string, mixed>  $data
     * @return array<string, mixed>
     */
    public function createProposal(array $data): array
    {
        $proposal = LlmConfigChangeProposal::query()->create([
            'diff' => $data['diff'],
            'reason' => $data['reason'],
            'tier' => strtoupper((string) $data['tier']),
            'status' => 'pending',
        ]);

        return [
            'success' => true,
            'proposal' => $this->formatProposal($proposal),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function approveProposal(int $proposalId, ?string $approvedBy): array
    {
        $proposal = $this->findPendingProposal($proposalId);
        $proposal->update([
            'status' => 'approved',
            'approved_by' => $approvedBy,
        ]);

        ApplyLlmConfigChangeProposalJob::dispatch($proposal->id);

        return [
            'success' => true,
            'message' => 'Proposta aprovada — delegação Werner enfileirada',
            'proposal' => $this->formatProposal($proposal->fresh()),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function rejectProposal(int $proposalId, ?string $rejectedBy): array
    {
        $proposal = $this->findPendingProposal($proposalId);
        $proposal->update([
            'status' => 'rejected',
            'approved_by' => $rejectedBy,
        ]);

        return [
            'success' => true,
            'message' => 'Proposta rejeitada',
            'proposal' => $this->formatProposal($proposal->fresh()),
        ];
    }

    private function findPendingProposal(int $proposalId): LlmConfigChangeProposal
    {
        $proposal = LlmConfigChangeProposal::query()->find($proposalId);
        if ($proposal === null) {
            throw ValidationException::withMessages([
                'proposal' => 'Proposta não encontrada',
            ]);
        }

        if ($proposal->status !== 'pending') {
            throw ValidationException::withMessages([
                'proposal' => 'Proposta já foi ' . $proposal->status,
            ]);
        }

        return $proposal;
    }

    /**
     * @return array<string, mixed>
     */
    private function formatProposal(LlmConfigChangeProposal $proposal): array
    {
        return [
            'id' => $proposal->id,
            'tier' => $proposal->tier,
            'reason' => $proposal->reason,
            'status' => $proposal->status,
            'diff' => $proposal->diff,
            'approved_by' => $proposal->approved_by,
            'applied_at' => $proposal->applied_at?->toIso8601String(),
            'created_at' => $proposal->created_at?->toIso8601String(),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function getProvider(string $providerId, bool $withLiveProbe = false): array
    {
        $providerId = strtolower($providerId);
        $canonicalModel = $this->resolveProviderModel($providerId);

        $snapshots = LlmProviderSnapshot::query()
            ->forProvider($providerId)
            ->orderByDesc('captured_at')
            ->limit(24)
            ->get();

        if ($snapshots->isEmpty() && $canonicalModel !== null) {
            $snapshots = LlmProviderSnapshot::query()
                ->where('model_alias', $canonicalModel)
                ->orderByDesc('captured_at')
                ->limit(24)
                ->get();
        }

        $events = LlmLimitEvent::query()
            ->where('provider', $providerId)
            ->orderByDesc('created_at')
            ->limit(20)
            ->get();

        $probes = LlmProbeRun::query()
            ->when($canonicalModel !== null, fn($q) => $q->where('model', $canonicalModel))
            ->orderByDesc('created_at')
            ->limit(20)
            ->get();

        $latest = $snapshots->first();
        $liveProbe = ($withLiveProbe && $canonicalModel !== null)
            ? $this->liteLLMClient->probe($canonicalModel)
            : null;

        return [
            'success' => true,
            'provider' => $providerId,
            'canonical_model' => $canonicalModel,
            'latest_snapshot' => $latest ? [
                'status' => $latest->status,
                'tier' => $latest->tier,
                'detail' => $latest->detail,
                'captured_at' => $latest->captured_at?->toIso8601String(),
            ] : null,
            'live_probe' => $liveProbe,
            'snapshots' => $snapshots->map(fn(LlmProviderSnapshot $s) => [
                'model_alias' => $s->model_alias,
                'status' => $s->status,
                'tier' => $s->tier,
                'captured_at' => $s->captured_at?->toIso8601String(),
            ]),
            'limit_events' => $events,
            'recent_probes' => $probes,
        ];
    }

    /**
     * Ingere estado do quota-governor e grava snapshots + eventos.
     */
    public function ingestGovernorState(?array $state = null): int
    {
        $cacheKey = 'llm_monitor:ingest:lock';
        if (Cache::has($cacheKey)) {
            return 0;
        }

        $state ??= $this->loadGovernorState();
        if ($state === null) {
            return 0;
        }

        Cache::put($cacheKey, true, (int) config('llm-monitor.ingest_cache_ttl', 60));

        $capturedAt = isset($state['timestamp'])
            ? Carbon::parse((string) $state['timestamp'])
            : now();

        return DB::transaction(function () use ($state, $capturedAt): int {
            $written = 0;
            $tiers = is_array($state['tiers'] ?? null) ? $state['tiers'] : [];

            foreach ($tiers as $tier => $tierData) {
                if (! is_array($tierData)) {
                    continue;
                }

                foreach ($this->parseTierDetail((string) ($tierData['detail'] ?? '')) as $entry) {
                    $provider = $this->inferProviderFromModel($entry['model']);

                    LlmProviderSnapshot::query()->create([
                        'provider' => $provider,
                        'model_alias' => $entry['model'],
                        'tier' => (string) $tier,
                        'status' => $entry['status'],
                        'windows_json' => [
                            'ok' => $tierData['ok'] ?? null,
                            'quota' => $tierData['quota'] ?? null,
                            'fail' => $tierData['fail'] ?? null,
                        ],
                        'detail' => $entry['detail'],
                        'captured_at' => $capturedAt,
                    ]);
                    $written++;

                    if (in_array($entry['status'], ['fail', 'quota', 'rate-limited', 'blocked'], true)) {
                        LlmLimitEvent::query()->create([
                            'provider' => $provider,
                            'model_alias' => $entry['model'],
                            'window' => (string) $tier,
                            'severity' => $entry['status'] === 'quota' || $entry['status'] === 'rate-limited' ? 'warn' : 'critical',
                            'message' => $entry['detail'] ?? "Modelo {$entry['model']} em estado {$entry['status']}",
                        ]);
                    }
                }
            }

            if (isset($state['action']) && in_array($state['action'], ['critical', 'degraded', 'free-tier', 'warn-spend'], true)) {
                LlmLimitEvent::query()->create([
                    'provider' => 'all',
                    'model_alias' => null,
                    'window' => 'governor',
                    'severity' => in_array($state['action'], ['critical', 'degraded'], true) ? 'critical' : 'warn',
                    'message' => (string) ($state['reason'] ?? $state['action']),
                ]);
                $written++;
            }

            return $written;
        });
    }

    public function recordProbeRun(
        string $probeType,
        string $model,
        array $probeResult,
        string $harness = 'laravel',
    ): LlmProbeRun {
        return LlmProbeRun::query()->create([
            'probe_type' => $probeType,
            'harness' => $harness,
            'model' => $model,
            'latency_ms' => $probeResult['latency_ms'] ?? null,
            'result' => $probeResult['result'] ?? 'unknown',
            'tokens_in' => $probeResult['tokens_in'] ?? null,
            'tokens_out' => $probeResult['tokens_out'] ?? null,
            'http_status' => $probeResult['http_status'] ?? null,
            'meta_json' => array_merge(
                is_array($probeResult['meta'] ?? null) ? $probeResult['meta'] : [],
                ['detail' => $probeResult['detail'] ?? null],
            ),
        ]);
    }

    /**
     * @return array<string, mixed>|null
     */
    public function loadGovernorState(): ?array
    {
        foreach (
            [
                (string) config('llm-monitor.governor_state_path'),
                (string) config('llm-monitor.governor_state_fallback'),
            ] as $path
        ) {
            if ($path === '' || ! File::isFile($path)) {
                continue;
            }

            $decoded = json_decode((string) File::get($path), true);
            if (is_array($decoded)) {
                return $decoded;
            }
        }

        return null;
    }

    public function resolveProviderModel(string $providerId): ?string
    {
        $map = config('llm-monitor.provider_models', []);

        return is_array($map) ? ($map[strtolower($providerId)] ?? null) : null;
    }

    /**
     * @return list<array{model: string, status: string, detail: string|null}>
     */
    private function parseTierDetail(string $detail): array
    {
        if ($detail === '') {
            return [];
        }

        $entries = [];
        foreach (explode(',', $detail) as $chunk) {
            $chunk = trim($chunk);
            if ($chunk === '') {
                continue;
            }

            $parts = explode(':', $chunk);
            $model = $parts[0] ?? 'unknown';
            $rawStatus = strtoupper($parts[1] ?? 'UNKNOWN');
            $extra = isset($parts[2]) ? implode(':', array_slice($parts, 2)) : null;

            $status = match ($rawStatus) {
                'OK' => 'ok',
                'QUOTA', '429' => 'quota',
                'FAIL' => 'fail',
                default => strtolower($rawStatus),
            };

            $entries[] = [
                'model' => $model,
                'status' => $status,
                'detail' => $extra,
            ];
        }

        return $entries;
    }

    private function inferProviderFromModel(string $model): string
    {
        $modelLower = strtolower($model);

        foreach (config('llm-monitor.provider_models', []) as $provider => $alias) {
            if (strtolower((string) $alias) === $modelLower) {
                return (string) $provider;
            }
        }

        if (str_contains($modelLower, 'claude')) {
            return 'anthropic';
        }
        if (str_contains($modelLower, 'gpt') || str_contains($modelLower, 'codex')) {
            return 'openai';
        }
        if (str_contains($modelLower, 'glm') || str_contains($modelLower, 'zai')) {
            return 'zai';
        }
        if (str_contains($modelLower, 'groq')) {
            return 'groq';
        }
        if (str_contains($modelLower, 'cursor')) {
            return 'cursor';
        }
        if (str_contains($modelLower, 'verdent')) {
            return 'verdent';
        }
        if (str_contains($modelLower, 'ollama') || str_contains($modelLower, 'agl-primary')) {
            return 'ollama';
        }

        return 'unknown';
    }

    private function deriveOverallStatus(
        string $action,
        bool $gatewayOk,
        int $openEvents,
        ?float $spend,
        float $spendWarn,
    ): string {
        if (! $gatewayOk || $action === 'critical') {
            return 'blocked';
        }

        if ($action === 'degraded' || $openEvents > 3) {
            return 'degraded';
        }

        if ($action === 'free-tier' || $action === 'warn-spend' || ($spend !== null && $spend >= $spendWarn)) {
            return 'warn';
        }

        return 'ok';
    }
}
