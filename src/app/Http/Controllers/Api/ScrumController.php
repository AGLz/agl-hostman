<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Bug;
use App\Models\Sprint;
use App\Models\SprintMember;
use App\Models\Story;
use App\Models\Task;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\ValidationException;

class ScrumController extends Controller
{
    /**
     * List all sprints
     */
    public function listSprints(Request $request): JsonResponse
    {
        $query = Sprint::with(['creator', 'tasks', 'members.user']);

        if ($request->has('status')) {
            $query->where('status', $request->input('status'));
        }

        if ($request->has('search')) {
            $query->where('name', 'like', '%'.$request->input('search').'%')
                ->orWhere('goal', 'like', '%'.$request->input('search').'%');
        }

        $sprints = $query->orderBy('start_date', 'desc')
            ->paginate($request->input('per_page', 15));

        return response()->json([
            'sprints' => $sprints->items(),
            'pagination' => [
                'total' => $sprints->total(),
                'per_page' => $sprints->perPage(),
                'current_page' => $sprints->currentPage(),
                'last_page' => $sprints->lastPage(),
            ],
        ]);
    }

    /**
     * Create a new sprint
     */
    public function createSprint(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:255',
            'goal' => 'nullable|string',
            'start_date' => 'required|date',
            'end_date' => 'required|date|after:start_date',
            'members' => 'array',
            'members.*.user_id' => 'required|exists:users,id',
            'members.*.role' => 'required|in:scrum_master,product_owner,developer,tester,designer,observer',
            'members.*.capacity' => 'nullable|integer|min:0|max:100',
        ]);

        if ($validator->fails()) {
            throw new ValidationException($validator);
        }

        $sprint = DB::transaction(function () use ($request) {
            $sprint = Sprint::create([
                'name' => $request->input('name'),
                'goal' => $request->input('goal'),
                'start_date' => $request->input('start_date'),
                'end_date' => $request->input('end_date'),
                'status' => 'planning',
                'created_by' => $request->user()->id,
            ]);

            // Add members if provided
            if ($request->has('members')) {
                foreach ($request->input('members') as $member) {
                    SprintMember::create([
                        'sprint_id' => $sprint->id,
                        'user_id' => $member['user_id'],
                        'role' => $member['role'],
                        'capacity' => $member['capacity'] ?? 100,
                        'availability' => 100,
                    ]);
                }
            }

            return $sprint;
        });

        $sprint->load('members.user', 'creator');

        return response()->json([
            'sprint' => $sprint,
            'message' => 'Sprint created successfully',
        ], 201);
    }

    /**
     * Get sprint backlog (tasks and stories)
     */
    public function getSprintBacklog(Request $request, int $id): JsonResponse
    {
        $sprint = Sprint::with(['creator', 'members.user'])
            ->findOrFail($id);

        $tasks = Task::with(['assignee', 'creator', 'story'])
            ->where('sprint_id', $id)
            ->get();

        $stories = Story::with(['creator', 'tasks'])
            ->where('sprint_id', $id)
            ->get();

        $bugs = Bug::with(['reporter', 'assignee'])
            ->where('sprint_id', $id)
            ->get();

        $backlog = [
            'stories' => $stories->map(function ($story) {
                return [
                    'id' => $story->id,
                    'title' => $story->title,
                    'description' => $story->description,
                    'story_points' => $story->story_points,
                    'priority' => $story->priority,
                    'status' => $story->status,
                    'business_value' => $story->business_value,
                    'complexity' => $story->complexity,
                    'tasks_count' => $story->tasks->count(),
                    'completed_tasks' => $story->completed_tasks_count,
                    'epic' => $story->epic,
                ];
            }),
            'tasks' => $tasks->map(function ($task) {
                return [
                    'id' => $task->id,
                    'title' => $task->title,
                    'description' => $task->description,
                    'story_points' => $task->story_points,
                    'priority' => $task->priority,
                    'status' => $task->status,
                    'assignee' => $task->assignee?->only('id', 'name'),
                    'story_id' => $task->story_id,
                    'story_title' => $task->story?->title,
                ];
            }),
            'bugs' => $bugs->map(function ($bug) {
                return [
                    'id' => $bug->id,
                    'title' => $bug->title,
                    'severity' => $bug->severity,
                    'priority' => $bug->priority,
                    'status' => $bug->status,
                    'assignee' => $bug->assignee?->only('id', 'name'),
                    'age_days' => $bug->age_in_days,
                ];
            }),
            'summary' => [
                'total_story_points' => $tasks->sum('story_points') + $stories->sum('story_points'),
                'completed_points' => $tasks->where('status', 'done')->sum('story_points'),
                'total_tasks' => $tasks->count(),
                'completed_tasks' => $tasks->where('status', 'done')->count(),
                'total_stories' => $stories->count(),
                'completed_stories' => $stories->filter(fn ($s) => $s->isCompleted())->count(),
                'open_bugs' => $bugs->whereIn('status', ['open', 'assigned', 'in_progress'])->count(),
            ],
        ];

        return response()->json([
            'sprint' => $sprint,
            'backlog' => $backlog,
        ]);
    }

    /**
     * Start a sprint
     */
    public function startSprint(Request $request, int $id): JsonResponse
    {
        $sprint = Sprint::findOrFail($id);

        if ($sprint->status !== 'planning') {
            return response()->json([
                'message' => 'Only planning sprints can be started',
            ], 400);
        }

        $sprint->update(['status' => 'active']);

        return response()->json([
            'sprint' => $sprint,
            'message' => 'Sprint started successfully',
        ]);
    }

    /**
     * Complete a sprint
     */
    public function completeSprint(Request $request, int $id): JsonResponse
    {
        $sprint = Sprint::findOrFail($id);

        if ($sprint->status !== 'active') {
            return response()->json([
                'message' => 'Only active sprints can be completed',
            ], 400);
        }

        $sprint->update([
            'status' => 'completed',
            'velocity' => $sprint->calculateVelocity(),
        ]);

        return response()->json([
            'sprint' => $sprint,
            'message' => 'Sprint completed successfully',
            'velocity' => $sprint->velocity,
        ]);
    }

    /**
     * List all tasks
     */
    public function listTasks(Request $request): JsonResponse
    {
        $query = Task::with(['sprint', 'assignee', 'creator', 'story']);

        if ($request->has('status')) {
            $query->where('status', $request->input('status'));
        }

        if ($request->has('sprint_id')) {
            $query->where('sprint_id', $request->input('sprint_id'));
        }

        if ($request->has('assigned_to')) {
            $query->where('assigned_to', $request->input('assigned_to'));
        }

        if ($request->has('story_id')) {
            $query->where('story_id', $request->input('story_id'));
        }

        if ($request->has('backlog')) {
            $query->backlog();
        }

        $tasks = $query->orderBy('created_at', 'desc')
            ->paginate($request->input('per_page', 20));

        return response()->json([
            'tasks' => $tasks->items(),
            'pagination' => [
                'total' => $tasks->total(),
                'per_page' => $tasks->perPage(),
                'current_page' => $tasks->currentPage(),
                'last_page' => $tasks->lastPage(),
            ],
        ]);
    }

    /**
     * Create a new task
     */
    public function createTask(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'title' => 'required|string|max:255',
            'description' => 'nullable|string',
            'story_points' => 'nullable|integer|min:0|max:21',
            'priority' => 'required|in:low,medium,high,critical',
            'sprint_id' => 'nullable|exists:sprints,id',
            'story_id' => 'nullable|exists:stories,id',
            'assigned_to' => 'nullable|exists:users,id',
            'epic' => 'nullable|string|max:255',
            'tags' => 'array',
            'tags.*' => 'string',
        ]);

        if ($validator->fails()) {
            throw new ValidationException($validator);
        }

        $task = Task::create([
            'title' => $request->input('title'),
            'description' => $request->input('description'),
            'story_points' => $request->input('story_points'),
            'priority' => $request->input('priority'),
            'status' => $request->input('sprint_id') ? 'todo' : 'backlog',
            'sprint_id' => $request->input('sprint_id'),
            'story_id' => $request->input('story_id'),
            'assigned_to' => $request->input('assigned_to'),
            'created_by' => $request->user()->id,
            'epic' => $request->input('epic'),
            'tags' => $request->input('tags', []),
        ]);

        $task->load('sprint', 'assignee', 'creator', 'story');

        return response()->json([
            'task' => $task,
            'message' => 'Task created successfully',
        ], 201);
    }

    /**
     * Update a task
     */
    public function updateTask(Request $request, int $id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'title' => 'sometimes|string|max:255',
            'description' => 'nullable|string',
            'story_points' => 'nullable|integer|min:0|max:21',
            'priority' => 'sometimes|in:low,medium,high,critical',
            'status' => 'sometimes|in:backlog,todo,in_progress,review,done',
            'assigned_to' => 'nullable|exists:users,id',
            'tags' => 'array',
            'tags.*' => 'string',
        ]);

        if ($validator->fails()) {
            throw new ValidationException($validator);
        }

        $task = Task::findOrFail($id);

        $task->update($request->only([
            'title',
            'description',
            'story_points',
            'priority',
            'status',
            'assigned_to',
            'tags',
        ]));

        // Handle status changes with timestamps
        if ($request->has('status')) {
            $task->moveToStatus($request->input('status'));
        }

        $task->load('sprint', 'assignee', 'creator', 'story');

        return response()->json([
            'task' => $task,
            'message' => 'Task updated successfully',
        ]);
    }

    /**
     * Delete a task
     */
    public function deleteTask(int $id): JsonResponse
    {
        $task = Task::findOrFail($id);
        $task->delete();

        return response()->json([
            'message' => 'Task deleted successfully',
        ]);
    }

    /**
     * Move task to sprint
     */
    public function moveTask(Request $request, int $id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'sprint_id' => 'required|exists:sprints,id',
        ]);

        if ($validator->fails()) {
            throw new ValidationException($validator);
        }

        $task = Task::findOrFail($id);
        $sprint = Sprint::findOrFail($request->input('sprint_id'));

        $task->update([
            'sprint_id' => $sprint->id,
            'status' => $sprint->status === 'active' ? 'in_progress' : 'todo',
        ]);

        $task->load('sprint');

        return response()->json([
            'task' => $task,
            'message' => 'Task moved to sprint successfully',
        ]);
    }

    /**
     * Get burndown chart data
     */
    public function getBurndown(Request $request): JsonResponse
    {
        $request->validate([
            'sprint_id' => 'required|exists:sprints,id',
        ]);

        $sprint = Sprint::findOrFail($request->input('sprint_id'));

        $burndownData = $sprint->getBurndownData();

        return response()->json([
            'sprint' => [
                'id' => $sprint->id,
                'name' => $sprint->name,
                'start_date' => $sprint->start_date,
                'end_date' => $sprint->end_date,
            ],
            'burndown_data' => $burndownData,
        ]);
    }

    /**
     * Get velocity report
     */
    public function getVelocity(Request $request): JsonResponse
    {
        $sprintCount = $request->input('sprints', 5);

        $sprints = Sprint::where('status', 'completed')
            ->orderBy('end_date', 'desc')
            ->take($sprintCount)
            ->get();

        $velocityData = $sprints->map(function ($sprint) {
            return [
                'id' => $sprint->id,
                'name' => $sprint->name,
                'end_date' => $sprint->end_date,
                'velocity' => $sprint->velocity,
                'committed_points' => $sprint->tasks->sum('story_points'),
                'completed_points' => $sprint->tasks()->where('status', 'done')->sum('story_points'),
                'total_tasks' => $sprint->tasks->count(),
                'completed_tasks' => $sprint->tasks()->where('status', 'done')->count(),
            ];
        });

        $averageVelocity = $sprints->avg('velocity') ?? 0;
        $minVelocity = $sprints->min('velocity') ?? 0;
        $maxVelocity = $sprints->max('velocity') ?? 0;

        return response()->json([
            'sprints' => $velocityData,
            'statistics' => [
                'average_velocity' => round($averageVelocity, 2),
                'min_velocity' => $minVelocity,
                'max_velocity' => $maxVelocity,
                'sprint_count' => $sprints->count(),
            ],
        ]);
    }

    /**
     * Get all stories
     */
    public function listStories(Request $request): JsonResponse
    {
        $query = Story::with(['sprint', 'creator', 'tasks']);

        if ($request->has('status')) {
            $query->where('status', $request->input('status'));
        }

        if ($request->has('epic')) {
            $query->where('epic', $request->input('epic'));
        }

        if ($request->has('backlog')) {
            $query->backlog();
        }

        $stories = $query->orderBy('business_value', 'desc')
            ->paginate($request->input('per_page', 15));

        return response()->json([
            'stories' => $stories->items(),
            'pagination' => [
                'total' => $stories->total(),
                'per_page' => $stories->perPage(),
                'current_page' => $stories->currentPage(),
                'last_page' => $stories->lastPage(),
            ],
        ]);
    }

    /**
     * Create a new story
     */
    public function createStory(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'title' => 'required|string|max:255',
            'description' => 'nullable|string',
            'acceptance_criteria' => 'array',
            'acceptance_criteria.*' => 'string',
            'user_role' => 'nullable|string|max:255',
            'story_points' => 'nullable|integer|min:0|max:21',
            'priority' => 'required|in:low,medium,high,critical',
            'business_value' => 'nullable|integer|min:0|max:100',
            'complexity' => 'nullable|integer|min:0|max:10',
            'epic' => 'nullable|string|max:255',
            'tags' => 'array',
            'tags.*' => 'string',
            'sprint_id' => 'nullable|exists:sprints,id',
        ]);

        if ($validator->fails()) {
            throw new ValidationException($validator);
        }

        $story = Story::create([
            'title' => $request->input('title'),
            'description' => $request->input('description'),
            'acceptance_criteria' => $request->input('acceptance_criteria'),
            'user_role' => $request->input('user_role'),
            'story_points' => $request->input('story_points'),
            'priority' => $request->input('priority'),
            'business_value' => $request->input('business_value', 0),
            'complexity' => $request->input('complexity', 0),
            'epic' => $request->input('epic'),
            'tags' => $request->input('tags', []),
            'sprint_id' => $request->input('sprint_id'),
            'status' => $request->input('sprint_id') ? 'planned' : 'backlog',
            'created_by' => $request->user()->id,
        ]);

        $story->load('sprint', 'creator');

        return response()->json([
            'story' => $story,
            'message' => 'Story created successfully',
        ], 201);
    }

    /**
     * Update a story
     */
    public function updateStory(Request $request, int $id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'title' => 'sometimes|string|max:255',
            'description' => 'nullable|string',
            'acceptance_criteria' => 'array',
            'story_points' => 'nullable|integer|min:0|max:21',
            'priority' => 'sometimes|in:low,medium,high,critical',
            'status' => 'sometimes|in:backlog,refined,planned,in_progress,testing,done',
            'business_value' => 'nullable|integer|min:0|max:100',
            'complexity' => 'nullable|integer|min:0|max:10',
            'tags' => 'array',
        ]);

        if ($validator->fails()) {
            throw new ValidationException($validator);
        }

        $story = Story::findOrFail($id);

        $story->update($request->only([
            'title',
            'description',
            'acceptance_criteria',
            'story_points',
            'priority',
            'business_value',
            'complexity',
            'tags',
        ]));

        if ($request->has('status')) {
            $story->moveToStatus($request->input('status'));
        }

        $story->load('sprint', 'creator', 'tasks');

        return response()->json([
            'story' => $story,
            'message' => 'Story updated successfully',
        ]);
    }

    /**
     * Delete a story
     */
    public function deleteStory(int $id): JsonResponse
    {
        $story = Story::findOrFail($id);
        $story->delete();

        return response()->json([
            'message' => 'Story deleted successfully',
        ]);
    }

    /**
     * List all bugs
     */
    public function listBugs(Request $request): JsonResponse
    {
        $query = Bug::with(['sprint', 'story', 'task', 'reporter', 'assignee']);

        if ($request->has('status')) {
            $query->where('status', $request->input('status'));
        }

        if ($request->has('severity')) {
            $query->where('severity', $request->input('severity'));
        }

        if ($request->has('sprint_id')) {
            $query->where('sprint_id', $request->input('sprint_id'));
        }

        if ($request->has('assigned_to')) {
            $query->where('assigned_to', $request->input('assigned_to'));
        }

        if ($request->has('critical')) {
            $query->critical();
        }

        $bugs = $query->orderBy('severity', 'desc')
            ->orderBy('created_at', 'desc')
            ->paginate($request->input('per_page', 20));

        return response()->json([
            'bugs' => $bugs->items(),
            'pagination' => [
                'total' => $bugs->total(),
                'per_page' => $bugs->perPage(),
                'current_page' => $bugs->currentPage(),
                'last_page' => $bugs->lastPage(),
            ],
        ]);
    }

    /**
     * Create a new bug
     */
    public function createBug(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'title' => 'required|string|max:255',
            'description' => 'nullable|string',
            'severity' => 'required|in:trivial,low,medium,high,critical,blocker',
            'priority' => 'required|in:low,medium,high,critical',
            'reproduction_steps' => 'array',
            'reproduction_steps.*' => 'string',
            'expected_behavior' => 'nullable|string',
            'actual_behavior' => 'nullable|string',
            'environment' => 'nullable|string',
            'found_in_version' => 'nullable|string',
            'sprint_id' => 'nullable|exists:sprints,id',
            'story_id' => 'nullable|exists:stories,id',
            'task_id' => 'nullable|exists:tasks,id',
            'assigned_to' => 'nullable|exists:users,id',
            'labels' => 'array',
            'labels.*' => 'string',
        ]);

        if ($validator->fails()) {
            throw new ValidationException($validator);
        }

        $bug = Bug::create([
            'title' => $request->input('title'),
            'description' => $request->input('description'),
            'severity' => $request->input('severity'),
            'priority' => $request->input('priority'),
            'reproduction_steps' => $request->input('reproduction_steps'),
            'expected_behavior' => $request->input('expected_behavior'),
            'actual_behavior' => $request->input('actual_behavior'),
            'environment' => $request->input('environment'),
            'found_in_version' => $request->input('found_in_version'),
            'sprint_id' => $request->input('sprint_id'),
            'story_id' => $request->input('story_id'),
            'task_id' => $request->input('task_id'),
            'assigned_to' => $request->input('assigned_to'),
            'reported_by' => $request->user()->id,
            'labels' => $request->input('labels', []),
            'status' => $request->input('assigned_to') ? 'assigned' : 'open',
        ]);

        $bug->load('sprint', 'story', 'task', 'reporter', 'assignee');

        return response()->json([
            'bug' => $bug,
            'message' => 'Bug created successfully',
        ], 201);
    }

    /**
     * Update a bug
     */
    public function updateBug(Request $request, int $id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'title' => 'sometimes|string|max:255',
            'description' => 'nullable|string',
            'severity' => 'sometimes|in:trivial,low,medium,high,critical,blocker',
            'priority' => 'sometimes|in:low,medium,high,critical',
            'status' => 'sometimes|in:open,assigned,in_progress,resolved,verified,closed',
            'assigned_to' => 'nullable|exists:users,id',
            'resolved_in_version' => 'nullable|string',
            'labels' => 'array',
        ]);

        if ($validator->fails()) {
            throw new ValidationException($validator);
        }

        $bug = Bug::findOrFail($id);

        $bug->update($request->only([
            'title',
            'description',
            'severity',
            'priority',
            'assigned_to',
            'resolved_in_version',
            'labels',
        ]));

        if ($request->has('status')) {
            $bug->moveToStatus($request->input('status'), $request->user());
        }

        $bug->load('sprint', 'story', 'task', 'reporter', 'assignee');

        return response()->json([
            'bug' => $bug,
            'message' => 'Bug updated successfully',
        ]);
    }

    /**
     * Get sprint members
     */
    public function getSprintMembers(Request $request, int $sprintId): JsonResponse
    {
        $sprint = Sprint::findOrFail($sprintId);
        $members = SprintMember::with('user')
            ->where('sprint_id', $sprintId)
            ->active()
            ->get();

        return response()->json([
            'sprint' => $sprint,
            'members' => $members,
        ]);
    }

    /**
     * Add member to sprint
     */
    public function addSprintMember(Request $request, int $sprintId): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'user_id' => 'required|exists:users,id',
            'role' => 'required|in:scrum_master,product_owner,developer,tester,designer,observer',
            'capacity' => 'nullable|integer|min:0|max:100',
        ]);

        if ($validator->fails()) {
            throw new ValidationException($validator);
        }

        $sprint = Sprint::findOrFail($sprintId);

        $member = SprintMember::updateOrCreate(
            [
                'sprint_id' => $sprintId,
                'user_id' => $request->input('user_id'),
            ],
            [
                'role' => $request->input('role'),
                'capacity' => $request->input('capacity', 100),
                'availability' => 100,
                'left_at' => null,
            ]
        );

        $member->load('user');

        return response()->json([
            'member' => $member,
            'message' => 'Member added to sprint successfully',
        ], 201);
    }

    /**
     * Remove member from sprint
     */
    public function removeSprintMember(int $sprintId, int $userId): JsonResponse
    {
        $member = SprintMember::where('sprint_id', $sprintId)
            ->where('user_id', $userId)
            ->active()
            ->firstOrFail();

        $member->leaveSprint();

        return response()->json([
            'message' => 'Member removed from sprint successfully',
        ]);
    }

    /**
     * Get epics list
     */
    public function listEpics(Request $request): JsonResponse
    {
        $epics = Story::whereNotNull('epic')
            ->selectRaw('epic, COUNT(*) as story_count, SUM(story_points) as total_points')
            ->groupBy('epic')
            ->orderBy('epic')
            ->get();

        return response()->json([
            'epics' => $epics,
        ]);
    }

    /**
     * Get Kanban board data
     */
    public function getKanban(Request $request): JsonResponse
    {
        $request->validate([
            'sprint_id' => 'nullable|exists:sprints,id',
        ]);

        $taskQuery = Task::with(['assignee', 'story']);
        $storyQuery = Story::with(['creator']);

        if ($request->has('sprint_id')) {
            $taskQuery->where('sprint_id', $request->input('sprint_id'));
            $storyQuery->where('sprint_id', $request->input('sprint_id'));
        }

        $tasks = $taskQuery->get();
        $stories = $storyQuery->get();

        $columns = [
            'backlog' => [],
            'todo' => [],
            'in_progress' => [],
            'review' => [],
            'done' => [],
        ];

        foreach ($tasks as $task) {
            $columns[$task->status][] = [
                'type' => 'task',
                'id' => $task->id,
                'title' => $task->title,
                'story_points' => $task->story_points,
                'priority' => $task->priority,
                'assignee' => $task->assignee?->only('id', 'name'),
                'story_id' => $task->story_id,
            ];
        }

        foreach ($stories as $story) {
            $columns[$story->status][] = [
                'type' => 'story',
                'id' => $story->id,
                'title' => $story->title,
                'story_points' => $story->story_points,
                'priority' => $story->priority,
                'business_value' => $story->business_value,
            ];
        }

        return response()->json([
            'columns' => $columns,
        ]);
    }
}
