<?php

declare(strict_types=1);

namespace App\Http\Controllers\PcGamer;

use App\Http\Controllers\Controller;
use App\Http\Requests\PcGamer\StoreBuildRequest;
use App\Http\Requests\PcGamer\UpdateBuildItemRequest;
use App\Services\PcGamer\BuildComparisonService;
use App\Services\PcGamer\BuildService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

class BuildController extends Controller
{
    public function __construct(
        private readonly BuildService $buildService,
        private readonly BuildComparisonService $comparisonService,
    ) {}

    public function index(Request $request): Response
    {
        $status = $request->query('status');

        return Inertia::render('PcGamer/Builds/Index', [
            'builds' => $this->buildService->listBuilds(
                is_string($status) ? \App\Enums\PcGamer\BuildStatus::tryFrom($status) : null
            )->values(),
            'filters' => [
                'status' => is_string($status) ? $status : null,
            ],
        ]);
    }

    public function store(StoreBuildRequest $request): RedirectResponse
    {
        $build = $this->buildService->createBuild(
            $request->validated(),
            $request->boolean('use_template', true),
        );

        return redirect()
            ->route('pc-gamer.builds.show', $build['id'])
            ->with('success', "Montagem {$build['code']} criada.");
    }

    public function show(int $build): Response
    {
        $data = $this->buildService->getBuild($build);
        if ($data === null) {
            abort(404);
        }

        $comparison = null;
        try {
            $comparison = $this->comparisonService->compare($build);
        } catch (\InvalidArgumentException) {
            // ponytail: comparação opcional se build incompleto
        }

        return Inertia::render('PcGamer/Builds/Show', [
            'build' => $data,
            'comparison' => $comparison,
        ]);
    }

    public function updateItem(UpdateBuildItemRequest $request, int $build, int $item): RedirectResponse
    {
        $this->buildService->updateBuildItem($build, $item, $request->validated());

        return redirect()
            ->route('pc-gamer.builds.show', $build)
            ->with('success', 'Item actualizado.');
    }
}
