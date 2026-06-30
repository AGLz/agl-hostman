<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\PcGamer;

use App\Enums\PcGamer\BuildStatus;
use App\Http\Controllers\Controller;
use App\Http\Requests\PcGamer\StoreBuildRequest;
use App\Http\Requests\PcGamer\TransitionBuildStatusRequest;
use App\Http\Requests\PcGamer\UpdateBuildItemRequest;
use App\Services\PcGamer\BuildComparisonService;
use App\Services\PcGamer\BuildService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class BuildController extends Controller
{
    public function __construct(
        private readonly BuildService $buildService,
        private readonly BuildComparisonService $comparisonService,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $status = $request->query('status');

        return response()->json([
            'data' => $this->buildService->listBuilds(
                is_string($status) ? \App\Enums\PcGamer\BuildStatus::tryFrom($status) : null
            )->values(),
        ]);
    }

    public function store(StoreBuildRequest $request): JsonResponse
    {
        $build = $this->buildService->createBuild(
            $request->validated(),
            $request->boolean('use_template', true),
        );

        return response()->json(['data' => $build], 201);
    }

    public function show(int $build): JsonResponse
    {
        $data = $this->buildService->getBuild($build);
        if ($data === null) {
            return response()->json(['message' => 'Montagem não encontrada'], 404);
        }

        return response()->json(['data' => $data]);
    }

    public function updateItem(UpdateBuildItemRequest $request, int $build, int $item): JsonResponse
    {
        $data = $this->buildService->updateBuildItem($build, $item, $request->validated());

        return response()->json(['data' => $data]);
    }

    public function transition(TransitionBuildStatusRequest $request, int $build): JsonResponse
    {
        $validated = $request->validated();
        $status = $validated['status'] instanceof BuildStatus
            ? $validated['status']
            : BuildStatus::from($validated['status']);

        $data = $this->buildService->transitionStatus(
            $build,
            $status,
            $validated['notes'] ?? null,
            $validated['payload'] ?? null,
        );

        return response()->json(['data' => $data]);
    }

    public function compare(int $build): JsonResponse
    {
        try {
            return response()->json([
                'data' => $this->comparisonService->compare($build),
            ]);
        } catch (\InvalidArgumentException $e) {
            return response()->json(['message' => $e->getMessage()], 404);
        }
    }
}
