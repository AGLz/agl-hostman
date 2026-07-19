<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\MissionControl\MissionControlSnapshotService;
use Illuminate\Http\JsonResponse;

class MissionControlHostController extends Controller
{
    public function __construct(
        private readonly MissionControlSnapshotService $snapshotService,
    ) {}

    public function snapshot(string $code): JsonResponse
    {
        $snapshot = $this->snapshotService->getHostSnapshot($code);
        if ($snapshot === null) {
            return response()->json(['error' => 'Host não encontrado no registry'], 404);
        }

        return response()->json($snapshot);
    }

    public function guests(string $code): JsonResponse
    {
        $guests = $this->snapshotService->getHostGuests($code);
        if ($guests === null) {
            return response()->json(['error' => 'Host não encontrado no registry'], 404);
        }

        return response()->json([
            'host' => $code,
            'guests' => $guests,
            'count' => count($guests),
        ]);
    }

    public function refresh(string $code): JsonResponse
    {
        // Reason: um único ciclo de probes no request; job CollectServiceHealth fica para cron
        $snapshot = $this->snapshotService->getHostSnapshot($code, forceRefresh: true);
        if ($snapshot === null) {
            return response()->json(['error' => 'Host não encontrado no registry'], 404);
        }

        return response()->json($snapshot);
    }
}
