<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Jobs\IngestGovernorStateJob;
use App\Jobs\RunLlmProbeJob;
use App\Models\LlmConfigChangeProposal;
use App\Services\LlmMonitor\LlmMonitorService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class LlmMonitorController extends Controller
{
    public function __construct(
        private readonly LlmMonitorService $monitorService,
    ) {}

    public function status(): JsonResponse
    {
        return response()->json($this->monitorService->getStatus());
    }

    public function provider(Request $request, string $provider): JsonResponse
    {
        $canonical = $this->monitorService->resolveProviderModel($provider);
        if ($canonical === null && ! in_array(strtolower($provider), ['all', 'unknown'], true)) {
            $known = array_keys(config('llm-monitor.provider_models', []));

            return response()->json([
                'success' => false,
                'message' => 'Provider desconhecido',
                'known_providers' => $known,
            ], 404);
        }

        $withLiveProbe = $request->boolean('live');

        return response()->json($this->monitorService->getProvider($provider, $withLiveProbe));
    }

    public function ingest(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'timestamp' => ['sometimes', 'string', 'max:64'],
            'action' => ['sometimes', 'string', 'max:32'],
            'reason' => ['sometimes', 'string', 'max:512'],
            'tiers' => ['sometimes', 'array', 'max:20'],
            'tiers.*' => ['array'],
            'tiers.*.detail' => ['sometimes', 'string', 'max:4096'],
            'tiers.*.ok' => ['sometimes', 'integer', 'min:0'],
            'tiers.*.quota' => ['sometimes', 'integer', 'min:0'],
            'tiers.*.fail' => ['sometimes', 'integer', 'min:0'],
        ]);

        if ($validated === []) {
            $written = $this->monitorService->ingestGovernorState();
        } else {
            $written = $this->monitorService->ingestGovernorState($validated);
        }

        return response()->json([
            'success' => true,
            'records_written' => $written,
        ]);
    }

    public function dispatchProbe(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'probe_type' => ['sometimes', 'string', 'in:simple,complex'],
            'model' => ['sometimes', 'string', 'max:128'],
            'harness' => ['sometimes', 'string', 'max:64'],
        ]);

        RunLlmProbeJob::dispatch(
            $validated['probe_type'] ?? 'simple',
            $validated['model'] ?? null,
            $validated['harness'] ?? 'laravel',
        );

        return response()->json([
            'success' => true,
            'message' => 'Probe enfileirada',
        ], 202);
    }

    public function dispatchIngest(): JsonResponse
    {
        IngestGovernorStateJob::dispatch();

        return response()->json([
            'success' => true,
            'message' => 'Ingest enfileirado',
        ], 202);
    }

    public function storeProposal(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'diff' => ['required', 'array', 'max:50'],
            'reason' => ['required', 'string', 'max:1024'],
            'tier' => ['required', 'string', 'in:A,B,TierA,TierB,tier_a,tier_b'],
        ]);

        $tier = strtoupper($validated['tier']);
        if (str_contains($tier, 'A')) {
            $tier = 'A';
        } elseif (str_contains($tier, 'B')) {
            $tier = 'B';
        }

        return response()->json($this->monitorService->createProposal([
            'diff' => $validated['diff'],
            'reason' => $validated['reason'],
            'tier' => $tier,
        ]), 201);
    }

    public function approveProposal(Request $request, LlmConfigChangeProposal $proposal): JsonResponse
    {
        $user = $request->user();
        $approvedBy = $user?->email ?? $user?->name ?? 'sanctum-user';

        return response()->json(
            $this->monitorService->approveProposal($proposal->id, $approvedBy),
        );
    }

    public function rejectProposal(Request $request, LlmConfigChangeProposal $proposal): JsonResponse
    {
        $user = $request->user();
        $rejectedBy = $user?->email ?? $user?->name ?? 'sanctum-user';

        return response()->json(
            $this->monitorService->rejectProposal($proposal->id, $rejectedBy),
        );
    }
}
