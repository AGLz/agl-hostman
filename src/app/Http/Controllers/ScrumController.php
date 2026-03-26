<?php

namespace App\Http\Controllers;

use App\Models\Sprint;
use App\Models\Task;
use App\Services\AIModelService;
use App\Services\N8NService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class ScrumController extends Controller
{
    protected N8NService $n8nService;

    protected AIModelService $aiService;

    public function __construct(N8NService $n8nService, AIModelService $aiService)
    {
        $this->n8nService = $n8nService;
        $this->aiService = $aiService;
    }

    /**
     * Get dashboard overview
     */
    public function dashboard()
    {
        $activeSprint = Sprint::active();

        $stats = [
            'active_sprint' => $activeSprint ? [
                'id' => $activeSprint->id,
                'name' => $activeSprint->name,
                'progress' => $activeSprint->progress,
                'days_remaining' => now()->diffInDays($activeSprint->end_date),
            ] : null,
            'backlog_count' => Task::backlog()->count(),
            'in_progress_count' => Task::where('status', 'in_progress')->count(),
            'completed_today' => Task::whereDate('completed_at', today())->count(),
            'team_velocity' => $this->calculateTeamVelocity(),
        ];

        $recentTasks = Task::with(['assignee', 'sprint'])
            ->orderBy('updated_at', 'desc')
            ->limit(10)
            ->get();

        return response()->json([
            'stats' => $stats,
            'recent_tasks' => $recentTasks,
            'burndown' => $activeSprint?->getBurndownData(),
        ]);
    }

    /**
     * Sprint Management
     */
    public function listSprints()
    {
        $sprints = Sprint::with('creator')
            ->orderBy('start_date', 'desc')
            ->paginate(10);

        return response()->json($sprints);
    }

    public function createSprint(Request $request)
    {
        $request->validate([
            'name' => 'required|string|max:255',
            'goal' => 'nullable|string',
            'start_date' => 'required|date',
            'end_date' => 'required|date|after:start_date',
        ]);

        $sprint = Sprint::create([
            'name' => $request->name,
            'goal' => $request->goal,
            'start_date' => $request->start_date,
            'end_date' => $request->end_date,
            'created_by' => Auth::id(),
            'status' => 'planning',
        ]);

        return response()->json($sprint, 201);
    }

    public function updateSprint(Request $request, Sprint $sprint)
    {
        $request->validate([
            'name' => 'string|max:255',
            'goal' => 'nullable|string',
            'status' => 'in:planning,active,review,completed',
        ]);

        $sprint->update($request->only(['name', 'goal', 'status']));

        if ($request->status === 'completed') {
            $sprint->velocity = $sprint->calculateVelocity();
            $sprint->save();
        }

        return response()->json($sprint);
    }

    public function startSprint(Sprint $sprint)
    {
        // Only one sprint can be active at a time
        Sprint::where('status', 'active')->update(['status' => 'review']);

        $sprint->update(['status' => 'active']);

        // Trigger N8N workflow for sprint start
        $this->n8nService->executeWorkflow('sprint_started', [
            'sprint_id' => $sprint->id,
            'sprint_name' => $sprint->name,
        ]);

        return response()->json([
            'message' => 'Sprint started successfully',
            'sprint' => $sprint,
        ]);
    }

    /**
     * Task Management
     */
    public function listTasks(Request $request)
    {
        $query = Task::with(['assignee', 'creator', 'sprint', 'location']);

        if ($request->has('sprint_id')) {
            $query->where('sprint_id', $request->sprint_id);
        }

        if ($request->has('status')) {
            $query->where('status', $request->status);
        }

        if ($request->has('assigned_to')) {
            $query->where('assigned_to', $request->assigned_to);
        }

        if ($request->has('epic')) {
            $query->where('epic', $request->epic);
        }

        $tasks = $query->orderBy('priority', 'desc')
            ->orderBy('created_at', 'desc')
            ->paginate(20);

        return response()->json($tasks);
    }

    public function createTask(Request $request)
    {
        $request->validate([
            'title' => 'required|string|max:255',
            'description' => 'nullable|string',
            'priority' => 'in:low,medium,high,critical',
            'story_points' => 'nullable|integer|min:1|max:21',
            'sprint_id' => 'nullable|exists:sprints,id',
            'assigned_to' => 'nullable|exists:users,id',
            'location_id' => 'nullable|exists:physical_locations,id',
            'epic' => 'nullable|string',
            'tags' => 'nullable|array',
        ]);

        $task = Task::create([
            'title' => $request->title,
            'description' => $request->description,
            'priority' => $request->priority ?? 'medium',
            'story_points' => $request->story_points,
            'sprint_id' => $request->sprint_id,
            'assigned_to' => $request->assigned_to,
            'location_id' => $request->location_id,
            'epic' => $request->epic,
            'tags' => $request->tags,
            'created_by' => Auth::id(),
            'status' => $request->sprint_id ? 'todo' : 'backlog',
        ]);

        return response()->json($task, 201);
    }

    public function updateTask(Request $request, Task $task)
    {
        $request->validate([
            'title' => 'string|max:255',
            'description' => 'nullable|string',
            'status' => 'in:backlog,todo,in_progress,review,done',
            'priority' => 'in:low,medium,high,critical',
            'story_points' => 'nullable|integer|min:1|max:21',
            'assigned_to' => 'nullable|exists:users,id',
            'tags' => 'nullable|array',
        ]);

        $oldStatus = $task->status;
        $task->update($request->all());

        // Handle status transitions
        if ($request->has('status') && $oldStatus !== $request->status) {
            $task->moveToStatus($request->status);

            // Log status change
            Log::info('Task status changed', [
                'task_id' => $task->id,
                'from' => $oldStatus,
                'to' => $request->status,
                'user' => Auth::user()->name,
            ]);
        }

        return response()->json($task);
    }

    public function moveTask(Request $request, Task $task)
    {
        $request->validate([
            'status' => 'required|in:backlog,todo,in_progress,review,done',
            'sprint_id' => 'nullable|exists:sprints,id',
        ]);

        $task->moveToStatus($request->status);

        if ($request->has('sprint_id')) {
            $task->sprint_id = $request->sprint_id;
            $task->save();
        }

        return response()->json($task);
    }

    /**
     * Board View
     */
    public function board(Request $request)
    {
        $sprintId = $request->sprint_id ?? Sprint::active()?->id;

        $columns = [
            'backlog' => [],
            'todo' => [],
            'in_progress' => [],
            'review' => [],
            'done' => [],
        ];

        $tasks = Task::with(['assignee', 'location'])
            ->when($sprintId, function ($query) use ($sprintId) {
                $query->where('sprint_id', $sprintId);
            })
            ->get()
            ->groupBy('status');

        foreach ($columns as $status => $items) {
            $columns[$status] = $tasks->get($status, collect())->values();
        }

        return response()->json([
            'sprint_id' => $sprintId,
            'columns' => $columns,
        ]);
    }

    /**
     * AI-Powered Features
     */
    public function suggestTasks(Request $request)
    {
        $request->validate([
            'epic' => 'required|string',
            'context' => 'nullable|string',
        ]);

        $prompt = "Based on the epic '{$request->epic}' and context '{$request->context}', 
                   suggest 5-10 specific development tasks with story points (1-21 scale) 
                   and priorities (low/medium/high/critical). Format as JSON array.";

        $result = $this->aiService->query('claude', $prompt, ['max_tokens' => 2000]);

        if ($result['success']) {
            try {
                $tasks = json_decode($result['content'], true);

                return response()->json([
                    'success' => true,
                    'suggested_tasks' => $tasks,
                ]);
            } catch (\Exception $e) {
                return response()->json([
                    'success' => false,
                    'error' => 'Failed to parse AI response',
                ]);
            }
        }

        return response()->json($result);
    }

    public function estimateStoryPoints(Request $request)
    {
        $request->validate([
            'title' => 'required|string',
            'description' => 'required|string',
        ]);

        $prompt = "Estimate story points (1, 2, 3, 5, 8, 13, or 21) for this task:
                   Title: {$request->title}
                   Description: {$request->description}
                   Consider complexity, effort, and uncertainty. Return only the number.";

        $result = $this->aiService->query('claude', $prompt, ['max_tokens' => 50]);

        if ($result['success']) {
            $points = (int) trim($result['content']);

            return response()->json([
                'success' => true,
                'story_points' => $points,
                'reasoning' => 'Estimated based on complexity and effort',
            ]);
        }

        return response()->json($result);
    }

    /**
     * Metrics and Reports
     */
    public function velocity()
    {
        $sprints = Sprint::where('status', 'completed')
            ->orderBy('end_date', 'desc')
            ->limit(6)
            ->get();

        $velocityData = $sprints->map(function ($sprint) {
            return [
                'sprint' => $sprint->name,
                'velocity' => $sprint->velocity,
                'planned' => $sprint->tasks()->sum('story_points'),
            ];
        });

        return response()->json($velocityData);
    }

    public function teamPerformance()
    {
        $users = DB::table('tasks')
            ->select(
                'users.name',
                DB::raw('COUNT(tasks.id) as total_tasks'),
                DB::raw('SUM(CASE WHEN tasks.status = "done" THEN 1 ELSE 0 END) as completed_tasks'),
                DB::raw('AVG(tasks.story_points) as avg_story_points'),
                DB::raw('SUM(CASE WHEN tasks.status = "done" THEN tasks.story_points ELSE 0 END) as total_points')
            )
            ->join('users', 'tasks.assigned_to', '=', 'users.id')
            ->groupBy('users.id', 'users.name')
            ->get();

        return response()->json($users);
    }

    /**
     * Helper Methods
     */
    protected function calculateTeamVelocity(): float
    {
        $lastSprints = Sprint::where('status', 'completed')
            ->orderBy('end_date', 'desc')
            ->limit(3)
            ->pluck('velocity');

        return $lastSprints->avg() ?? 0;
    }
}
