<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Services\DokployService;
use App\Models\DokployProject;
use App\Models\DokployApplication;
use App\Models\DokployDeployment;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;
use Exception;

/**
 * Dokploy Dashboard Controller
 *
 * Handles Inertia.js page rendering for Dokploy integration frontend
 */
class DokployController extends Controller
{
    public function __construct(
        private readonly DokployService $dokployService
    ) {}

    /**
     * Dashboard - Show all projects
     */
    public function index(): Response
    {
        try {
            // Fetch projects from Dokploy API
            $projects = $this->dokployService->getProjects();

            // Get local database records for additional metadata
            $localProjects = DokployProject::with(['applications', 'applications.deployments'])
                ->get()
                ->keyBy('dokploy_id');

            // Merge API data with local data
            $enrichedProjects = $projects->map(function ($project) use ($localProjects) {
                $projectArray = $project->toArray();
                $local = $localProjects->get($project->projectId);

                if ($local) {
                    $projectArray['id'] = $local->id;
                    $projectArray['applications'] = $local->applications->map(fn($app) => [
                        'id' => $app->id,
                        'name' => $app->name,
                        'status' => $app->status,
                        'environment' => $app->environment,
                    ]);
                }

                return $projectArray;
            });

            // Calculate stats
            $stats = [
                'total_projects' => $enrichedProjects->count(),
                'total_applications' => DokployApplication::count(),
                'active_deployments' => DokployDeployment::where('status', 'running')->count(),
                'success_rate' => $this->calculateSuccessRate(),
            ];

            return Inertia::render('Dokploy/Index', [
                'projects' => $enrichedProjects,
                'stats' => $stats,
            ]);
        } catch (Exception $e) {
            \Log::error('Failed to load Dokploy dashboard', [
                'error' => $e->getMessage(),
            ]);

            return Inertia::render('Dokploy/Index', [
                'projects' => [],
                'stats' => null,
                'error' => 'Failed to load projects. Please try again.',
            ]);
        }
    }

    /**
     * Show single project with applications
     */
    public function show(string $id): Response
    {
        try {
            $project = DokployProject::with([
                'applications.deployments' => function ($query) {
                    $query->latest()->limit(10);
                },
            ])->findOrFail($id);

            // Fetch fresh data from Dokploy API
            $apiProject = $this->dokployService->getProject($project->dokploy_id);

            // Get all deployments for pipeline visualization
            $deployments = DokployDeployment::whereIn('application_id', $project->applications->pluck('id'))
                ->with('application')
                ->latest()
                ->limit(50)
                ->get();

            return Inertia::render('Dokploy/ProjectShow', [
                'project' => array_merge($project->toArray(), $apiProject->toArray()),
                'applications' => $project->applications,
                'deployments' => $deployments,
            ]);
        } catch (Exception $e) {
            \Log::error('Failed to load project', [
                'id' => $id,
                'error' => $e->getMessage(),
            ]);

            abort(404, 'Project not found');
        }
    }

    /**
     * Deployment history page
     */
    public function deploymentHistory(Request $request): Response
    {
        $query = DokployDeployment::with(['application.project']);

        // Apply filters
        if ($request->has('environment')) {
            $query->whereHas('application', function ($q) use ($request) {
                $q->where('environment', $request->environment);
            });
        }

        if ($request->has('status')) {
            $query->where('status', $request->status);
        }

        if ($request->has('dateRange')) {
            $dateRange = $request->dateRange;
            $ranges = [
                '24h' => now()->subHours(24),
                '7d' => now()->subDays(7),
                '30d' => now()->subDays(30),
            ];

            if (isset($ranges[$dateRange])) {
                $query->where('created_at', '>=', $ranges[$dateRange]);
            }
        }

        $deployments = $query->latest()->paginate(50);

        return Inertia::render('Dokploy/DeploymentHistory', [
            'deployments' => $deployments,
            'filters' => $request->only(['environment', 'status', 'dateRange']),
        ]);
    }

    /**
     * Calculate overall success rate
     */
    private function calculateSuccessRate(): int
    {
        $total = DokployDeployment::count();

        if ($total === 0) {
            return 0;
        }

        $successful = DokployDeployment::where('status', 'done')->count();

        return (int) round(($successful / $total) * 100);
    }
}
