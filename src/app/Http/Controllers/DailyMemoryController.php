<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreDailySessionLogRequest;
use App\Http\Requests\UpdateDailySessionLogRequest;
use App\Models\DailySessionLog;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

class DailyMemoryController extends Controller
{
    /**
     * Dashboard: lista, pesquisa e estatísticas dos registos diários.
     */
    public function index(Request $request): Response
    {
        $this->authorize('viewAny', DailySessionLog::class);

        $userId = $request->user()->id;
        $term = $request->string('q')->trim()->toString();
        $from = $request->input('from');
        $to = $request->input('to');

        $query = DailySessionLog::query()
            ->where('user_id', $userId)
            ->search($term !== '' ? $term : null);

        if ($from) {
            $query->whereDate('occurred_on', '>=', $from);
        }
        if ($to) {
            $query->whereDate('occurred_on', '<=', $to);
        }

        $logs = $query
            ->orderByDesc('occurred_on')
            ->orderByDesc('id')
            ->paginate(15)
            ->withQueryString();

        $base = DailySessionLog::query()->where('user_id', $userId);

        $stats = [
            'total' => (clone $base)->count(),
            'last_occurred_on' => (clone $base)->max('occurred_on'),
        ];

        return Inertia::render('Memory/Dashboard', [
            'logs' => $logs,
            'filters' => [
                'q' => $term,
                'from' => $from,
                'to' => $to,
            ],
            'stats' => $stats,
        ]);
    }

    public function create(): Response
    {
        $this->authorize('create', DailySessionLog::class);

        return Inertia::render('Memory/Create', [
            'defaultDate' => now()->toDateString(),
        ]);
    }

    public function store(StoreDailySessionLogRequest $request): RedirectResponse
    {
        $this->authorize('create', DailySessionLog::class);

        $tags = $request->parsedTags();

        DailySessionLog::query()->create([
            'user_id' => $request->user()->id,
            'occurred_on' => $request->validated('occurred_on'),
            'title' => $request->validated('title'),
            'summary' => $request->validated('summary'),
            'topics' => $tags['topics'],
            'project_tags' => $tags['project_tags'],
            'source' => $request->validated('source') ?? 'manual',
        ]);

        return redirect()
            ->route('daily-memory.index')
            ->with('success', 'Registo guardado.');
    }

    public function show(DailySessionLog $daily_memory): Response
    {
        $this->authorize('view', $daily_memory);

        return Inertia::render('Memory/Show', [
            'log' => $daily_memory,
        ]);
    }

    public function edit(DailySessionLog $daily_memory): Response
    {
        $this->authorize('update', $daily_memory);

        return Inertia::render('Memory/Edit', [
            'log' => $daily_memory,
        ]);
    }

    public function update(UpdateDailySessionLogRequest $request, DailySessionLog $daily_memory): RedirectResponse
    {
        $this->authorize('update', $daily_memory);

        $tags = $request->parsedTags();

        $daily_memory->update([
            'occurred_on' => $request->validated('occurred_on'),
            'title' => $request->validated('title'),
            'summary' => $request->validated('summary'),
            'topics' => $tags['topics'],
            'project_tags' => $tags['project_tags'],
            'source' => $request->validated('source') ?? $daily_memory->source,
        ]);

        return redirect()
            ->route('daily-memory.show', $daily_memory)
            ->with('success', 'Registo atualizado.');
    }

    public function destroy(DailySessionLog $daily_memory): RedirectResponse
    {
        $this->authorize('delete', $daily_memory);

        $daily_memory->delete();

        return redirect()
            ->route('daily-memory.index')
            ->with('success', 'Registo eliminado.');
    }
}
