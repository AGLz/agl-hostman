<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\Harness\HarnessSnapshotService;
use Illuminate\Http\JsonResponse;

class HarnessController extends Controller
{
    public function __construct(
        private readonly HarnessSnapshotService $snapshotService,
    ) {}

    public function snapshot(): JsonResponse
    {
        return response()->json($this->snapshotService->getSnapshot());
    }
}
