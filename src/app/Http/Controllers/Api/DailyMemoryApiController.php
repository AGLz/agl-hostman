<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\DailySessionLog;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DailyMemoryApiController extends Controller
{
    /**
     * List daily session logs with pagination.
     */
    public function index(Request $request): JsonResponse
    {
        $userId = $request->input('user_id');
        $from = $request->input('from');
        $to = $request->input('to');
        $perPage = min($request->input('per_page', 15), 100);

        $query = DailySessionLog::query()
            ->when($userId, fn ($q) => $q->where('user_id', $userId))
            ->when($from, fn ($q) => $q->whereDate('occurred_on', '>=', $from))
            ->when($to, fn ($q) => $q->whereDate('occurred_on', '<=', $to))
            ->orderByDesc('occurred_on')
            ->orderByDesc('id');

        return response()->json($query->paginate($perPage));
    }

    /**
     * Store a new daily session log from OpenClaw/Jarvis.
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'user_id' => 'sometimes|integer|exists:users,id',
            'occurred_on' => 'required|date',
            'title' => 'required|string|max:255',
            'summary' => 'required|string',
            'topics' => 'sometimes|array',
            'topics.*' => 'string|max:50',
            'project_tags' => 'sometimes|array',
            'project_tags.*' => 'string|max:50',
            'source' => 'sometimes|string|max:50',
        ]);

        // Default user_id to first user if not provided (for Jarvis auto-logging)
        if (! isset($validated['user_id'])) {
            $validated['user_id'] = 1; // Sr.Big
        }

        // Default source
        $validated['source'] = $validated['source'] ?? 'jarvis-auto';

        $log = DailySessionLog::create($validated);

        return response()->json([
            'success' => true,
            'data' => $log,
        ], 201);
    }

    /**
     * Search daily session logs by text.
     */
    public function search(Request $request): JsonResponse
    {
        $term = $request->input('q');
        $perPage = min($request->input('per_page', 15), 100);

        if (! $term) {
            return response()->json([
                'success' => false,
                'error' => 'Query parameter "q" is required',
            ], 400);
        }

        $logs = DailySessionLog::query()
            ->search($term)
            ->orderByDesc('occurred_on')
            ->orderByDesc('id')
            ->paginate($perPage);

        return response()->json($logs);
    }

    /**
     * Get statistics about daily session logs.
     */
    public function stats(Request $request): JsonResponse
    {
        $userId = $request->input('user_id');

        $base = DailySessionLog::query()
            ->when($userId, fn ($q) => $q->where('user_id', $userId));

        return response()->json([
            'total' => (clone $base)->count(),
            'last_occurred_on' => (clone $base)->max('occurred_on'),
            'sources' => (clone $base)->distinct()->pluck('source')->filter()->values(),
            'projects' => (clone $base)
                ->get('project_tags')
                ->pluck('project_tags')
                ->flatten()
                ->unique()
                ->values(),
        ]);
    }

    /**
     * Show a specific daily session log.
     */
    public function show(int $id): JsonResponse
    {
        $log = DailySessionLog::findOrFail($id);

        return response()->json([
            'success' => true,
            'data' => $log,
        ]);
    }

    /**
     * Update a daily session log.
     */
    public function update(Request $request, int $id): JsonResponse
    {
        $log = DailySessionLog::findOrFail($id);

        $validated = $request->validate([
            'occurred_on' => 'sometimes|date',
            'title' => 'sometimes|string|max:255',
            'summary' => 'sometimes|string',
            'topics' => 'sometimes|array',
            'topics.*' => 'string|max:50',
            'project_tags' => 'sometimes|array',
            'project_tags.*' => 'string|max:50',
            'source' => 'sometimes|string|max:50',
        ]);

        $log->update($validated);

        return response()->json([
            'success' => true,
            'data' => $log->fresh(),
        ]);
    }

    /**
     * Delete a daily session log.
     */
    public function destroy(int $id): JsonResponse
    {
        $log = DailySessionLog::findOrFail($id);
        $log->delete();

        return response()->json([
            'success' => true,
            'message' => 'Log deleted successfully',
        ]);
    }
}
