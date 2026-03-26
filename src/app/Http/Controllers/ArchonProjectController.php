<?php

namespace App\Http\Controllers;

use App\Services\ArchonMcpService;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

class ArchonProjectController extends Controller
{
    public function __construct(
        private ArchonMcpService $archonService
    ) {}

    /**
     * Display a listing of projects
     */
    public function index(): Response
    {
        try {
            $projects = $this->archonService->findProjects();

            // Enrich projects with task counts
            foreach ($projects as &$project) {
                $tasks = $this->archonService->findTasks(
                    query: null,
                    project_id: $project['id']
                );

                $project['tasks_count'] = count($tasks);
                $project['tasks_todo_count'] = count(array_filter($tasks, fn ($t) => $t['status'] === 'todo'));
                $project['tasks_doing_count'] = count(array_filter($tasks, fn ($t) => $t['status'] === 'doing'));
                $project['tasks_review_count'] = count(array_filter($tasks, fn ($t) => $t['status'] === 'review'));
                $project['tasks_done_count'] = count(array_filter($tasks, fn ($t) => $t['status'] === 'done'));
            }

            return Inertia::render('Archon/Projects', [
                'projects' => $projects,
            ]);
        } catch (\Exception $e) {
            logger()->error('Projects list error', [
                'error' => $e->getMessage(),
            ]);

            return Inertia::render('Archon/Projects', [
                'projects' => [],
            ]);
        }
    }

    /**
     * Store a newly created project
     */
    public function store(Request $request)
    {
        $validated = $request->validate([
            'title' => 'required|string|max:255',
            'description' => 'nullable|string|max:1000',
            'github_repo' => 'nullable|url|max:500',
        ]);

        try {
            $project = $this->archonService->createProject(
                $validated['title'],
                $validated['description'] ?? null,
                $validated['github_repo'] ?? null
            );

            // Broadcast event
            broadcast(new \App\Events\ArchonProjectCreated($project));

            return redirect()->route('archon.projects.index')
                ->with('success', 'Project created successfully');
        } catch (\Exception $e) {
            logger()->error('Project creation error', [
                'error' => $e->getMessage(),
                'data' => $validated,
            ]);

            return back()
                ->withErrors(['error' => 'Failed to create project: '.$e->getMessage()])
                ->withInput();
        }
    }

    /**
     * Display the specified project
     */
    public function show(string $id): Response
    {
        try {
            $project = $this->archonService->getProject($id);

            if (! $project) {
                abort(404, 'Project not found');
            }

            $tasks = $this->archonService->findTasks(
                query: null,
                project_id: $id
            );

            return Inertia::render('Archon/ProjectShow', [
                'project' => $project,
                'tasks' => $tasks,
            ]);
        } catch (\Exception $e) {
            logger()->error('Project show error', [
                'error' => $e->getMessage(),
                'project_id' => $id,
            ]);

            abort(500, 'Failed to load project');
        }
    }

    /**
     * Update the specified project
     */
    public function update(Request $request, string $id)
    {
        $validated = $request->validate([
            'title' => 'sometimes|required|string|max:255',
            'description' => 'nullable|string|max:1000',
            'github_repo' => 'nullable|url|max:500',
        ]);

        try {
            $project = $this->archonService->updateProject($id, $validated);

            // Broadcast event
            broadcast(new \App\Events\ArchonProjectUpdated($project));

            return back()->with('success', 'Project updated successfully');
        } catch (\Exception $e) {
            logger()->error('Project update error', [
                'error' => $e->getMessage(),
                'project_id' => $id,
                'data' => $validated,
            ]);

            return back()
                ->withErrors(['error' => 'Failed to update project: '.$e->getMessage()])
                ->withInput();
        }
    }

    /**
     * Remove the specified project
     */
    public function destroy(string $id)
    {
        try {
            $this->archonService->deleteProject($id);

            // Broadcast event
            broadcast(new \App\Events\ArchonProjectDeleted($id));

            return redirect()->route('archon.projects.index')
                ->with('success', 'Project deleted successfully');
        } catch (\Exception $e) {
            logger()->error('Project delete error', [
                'error' => $e->getMessage(),
                'project_id' => $id,
            ]);

            return back()
                ->withErrors(['error' => 'Failed to delete project: '.$e->getMessage()]);
        }
    }

    /**
     * Display the task board for a project
     */
    public function taskBoard(string $id): Response
    {
        try {
            $project = $this->archonService->getProject($id);

            if (! $project) {
                abort(404, 'Project not found');
            }

            $tasks = $this->archonService->findTasks(
                query: null,
                project_id: $id
            );

            return Inertia::render('Archon/TaskBoard', [
                'project' => $project,
                'tasks' => $tasks,
            ]);
        } catch (\Exception $e) {
            logger()->error('Task board error', [
                'error' => $e->getMessage(),
                'project_id' => $id,
            ]);

            abort(500, 'Failed to load task board');
        }
    }
}
