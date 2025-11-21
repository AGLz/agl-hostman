<?php

namespace App\Http\Controllers;

use App\Services\ArchonMcpService;
use Illuminate\Http\Request;

class ArchonTaskController extends Controller
{
    public function __construct(
        private ArchonMcpService $archonService
    ) {}

    /**
     * Store a newly created task
     */
    public function store(Request $request)
    {
        $validated = $request->validate([
            'project_id' => 'required|string',
            'title' => 'required|string|max:255',
            'description' => 'nullable|string|max:2000',
            'status' => 'required|in:todo,doing,review,done',
            'assignee' => 'nullable|string|max:100',
            'priority' => 'nullable|in:low,medium,high',
            'feature' => 'nullable|string|max:100',
            'task_order' => 'nullable|integer|min:0|max:100'
        ]);

        try {
            $task = $this->archonService->createTask(
                $validated['project_id'],
                $validated['title'],
                $validated['description'] ?? null,
                $validated['status'],
                $validated['assignee'] ?? 'User',
                $validated['task_order'] ?? 0,
                $validated['feature'] ?? null
            );

            // Broadcast event
            broadcast(new \App\Events\ArchonTaskCreated($task));

            return back()->with('success', 'Task created successfully');
        } catch (\Exception $e) {
            logger()->error('Task creation error', [
                'error' => $e->getMessage(),
                'data' => $validated
            ]);

            return back()
                ->withErrors(['error' => 'Failed to create task: ' . $e->getMessage()])
                ->withInput();
        }
    }

    /**
     * Update the specified task
     */
    public function update(Request $request, string $id)
    {
        $validated = $request->validate([
            'title' => 'sometimes|required|string|max:255',
            'description' => 'nullable|string|max:2000',
            'status' => 'sometimes|required|in:todo,doing,review,done',
            'assignee' => 'nullable|string|max:100',
            'priority' => 'nullable|in:low,medium,high',
            'feature' => 'nullable|string|max:100',
            'task_order' => 'nullable|integer|min:0|max:100'
        ]);

        try {
            $task = $this->archonService->updateTask($id, $validated);

            // Determine event type based on what changed
            if (isset($validated['status'])) {
                broadcast(new \App\Events\ArchonTaskMoved($task));
            } else {
                broadcast(new \App\Events\ArchonTaskUpdated($task));
            }

            if ($request->expectsJson()) {
                return response()->json([
                    'success' => true,
                    'task' => $task
                ]);
            }

            return back()->with('success', 'Task updated successfully');
        } catch (\Exception $e) {
            logger()->error('Task update error', [
                'error' => $e->getMessage(),
                'task_id' => $id,
                'data' => $validated
            ]);

            if ($request->expectsJson()) {
                return response()->json([
                    'success' => false,
                    'message' => 'Failed to update task: ' . $e->getMessage()
                ], 500);
            }

            return back()
                ->withErrors(['error' => 'Failed to update task: ' . $e->getMessage()])
                ->withInput();
        }
    }

    /**
     * Remove the specified task
     */
    public function destroy(string $id)
    {
        try {
            $this->archonService->deleteTask($id);

            // Broadcast event
            broadcast(new \App\Events\ArchonTaskDeleted($id));

            return back()->with('success', 'Task deleted successfully');
        } catch (\Exception $e) {
            logger()->error('Task delete error', [
                'error' => $e->getMessage(),
                'task_id' => $id
            ]);

            return back()
                ->withErrors(['error' => 'Failed to delete task: ' . $e->getMessage()]);
        }
    }

    /**
     * Bulk update task statuses (for Kanban drag-drop)
     */
    public function bulkUpdate(Request $request)
    {
        $validated = $request->validate([
            'tasks' => 'required|array',
            'tasks.*.id' => 'required|string',
            'tasks.*.status' => 'required|in:todo,doing,review,done',
            'tasks.*.task_order' => 'nullable|integer|min:0|max:100'
        ]);

        try {
            $updatedTasks = [];

            foreach ($validated['tasks'] as $taskData) {
                $task = $this->archonService->updateTask($taskData['id'], [
                    'status' => $taskData['status'],
                    'task_order' => $taskData['task_order'] ?? null
                ]);

                $updatedTasks[] = $task;

                // Broadcast event for each task
                broadcast(new \App\Events\ArchonTaskMoved($task));
            }

            return response()->json([
                'success' => true,
                'tasks' => $updatedTasks
            ]);
        } catch (\Exception $e) {
            logger()->error('Bulk task update error', [
                'error' => $e->getMessage(),
                'data' => $validated
            ]);

            return response()->json([
                'success' => false,
                'message' => 'Failed to update tasks: ' . $e->getMessage()
            ], 500);
        }
    }
}
