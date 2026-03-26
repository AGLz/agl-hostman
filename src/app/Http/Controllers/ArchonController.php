<?php

namespace App\Http\Controllers;

use App\Services\ArchonMcpService;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

class ArchonController extends Controller
{
    public function __construct(
        private ArchonMcpService $archonService
    ) {}

    /**
     * Display the Archon dashboard
     */
    public function index(): Response
    {
        try {
            // Fetch dashboard statistics
            $projects = $this->archonService->findProjects();
            $tasks = $this->archonService->findTasks();
            $sources = $this->archonService->getAvailableSources();

            $stats = [
                'total_projects' => count($projects),
                'active_tasks' => count(array_filter($tasks, fn ($t) => in_array($t['status'], ['todo', 'doing', 'review']))),
                'knowledge_sources' => count($sources),
                'total_documents' => 0, // TODO: Add document count from MCP
                'recent_tasks' => array_slice($tasks, 0, 5),
                'mcp_status' => $this->archonService->checkHealth() ? 'connected' : 'disconnected',
                'mcp_endpoint' => config('services.archon.endpoint'),
                'last_sync' => cache('archon_last_sync'),
            ];

            return Inertia::render('Archon/Index', [
                'stats' => $stats,
            ]);
        } catch (\Exception $e) {
            logger()->error('Archon dashboard error', [
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
            ]);

            return Inertia::render('Archon/Index', [
                'stats' => [
                    'total_projects' => 0,
                    'active_tasks' => 0,
                    'knowledge_sources' => 0,
                    'total_documents' => 0,
                    'recent_tasks' => [],
                    'mcp_status' => 'error',
                    'mcp_endpoint' => config('services.archon.endpoint'),
                    'last_sync' => null,
                ],
            ]);
        }
    }

    /**
     * Display the knowledge base search interface
     */
    public function knowledge(): Response
    {
        try {
            $sources = $this->archonService->getAvailableSources();

            return Inertia::render('Archon/KnowledgeBase', [
                'sources' => $sources,
                'initialResults' => [],
            ]);
        } catch (\Exception $e) {
            logger()->error('Knowledge base page error', [
                'error' => $e->getMessage(),
            ]);

            return Inertia::render('Archon/KnowledgeBase', [
                'sources' => [],
                'initialResults' => [],
            ]);
        }
    }

    /**
     * Execute knowledge base search
     */
    public function searchKnowledge(Request $request)
    {
        $validated = $request->validate([
            'query' => 'required|string|max:500',
            'source_id' => 'nullable|string',
            'match_count' => 'nullable|integer|min:1|max:50',
            'return_mode' => 'nullable|in:pages,chunks',
        ]);

        try {
            $results = $this->archonService->searchKnowledgeBase(
                $validated['query'],
                $validated['source_id'] ?? null,
                $validated['match_count'] ?? 10,
                $validated['return_mode'] ?? 'pages'
            );

            return response()->json([
                'success' => true,
                'results' => $results,
                'query' => $validated['query'],
            ]);
        } catch (\Exception $e) {
            logger()->error('Knowledge search error', [
                'error' => $e->getMessage(),
                'query' => $validated['query'],
            ]);

            return response()->json([
                'success' => false,
                'message' => 'Search failed: '.$e->getMessage(),
                'results' => [],
            ], 500);
        }
    }

    /**
     * Get autocomplete suggestions for knowledge search
     */
    public function searchSuggestions(Request $request)
    {
        $validated = $request->validate([
            'query' => 'required|string|max:100',
            'limit' => 'nullable|integer|min:1|max:10',
        ]);

        try {
            // Simple implementation: Get recent searches or popular queries
            // TODO: Implement proper autocomplete with MCP
            $suggestions = [
                'WireGuard mesh network',
                'Docker container setup',
                'Laravel deployment',
                'React components',
                'Authentication flow',
            ];

            // Filter based on query
            $filtered = array_filter($suggestions, function ($suggestion) use ($validated) {
                return stripos($suggestion, $validated['query']) !== false;
            });

            return response()->json([
                'success' => true,
                'suggestions' => array_values(array_slice($filtered, 0, $validated['limit'] ?? 5)),
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'suggestions' => [],
            ]);
        }
    }

    /**
     * Get full page content
     */
    public function getPage(Request $request)
    {
        $validated = $request->validate([
            'page_id' => 'nullable|string',
            'url' => 'nullable|string',
        ]);

        try {
            $page = $this->archonService->readFullPage(
                $validated['page_id'] ?? null,
                $validated['url'] ?? null
            );

            return response()->json([
                'success' => true,
                'page' => $page,
            ]);
        } catch (\Exception $e) {
            logger()->error('Get page error', [
                'error' => $e->getMessage(),
                'page_id' => $validated['page_id'] ?? null,
                'url' => $validated['url'] ?? null,
            ]);

            return response()->json([
                'success' => false,
                'message' => 'Failed to load page: '.$e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get available knowledge sources
     */
    public function getSources()
    {
        try {
            $sources = $this->archonService->getAvailableSources();

            return response()->json([
                'success' => true,
                'sources' => $sources,
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'sources' => [],
            ], 500);
        }
    }

    /**
     * Search code examples
     */
    public function searchCodeExamples(Request $request)
    {
        $validated = $request->validate([
            'query' => 'nullable|string|max:500',
            'language' => 'nullable|string|max:50',
            'source_id' => 'nullable|string',
            'match_count' => 'nullable|integer|min:1|max:50',
        ]);

        try {
            $results = $this->archonService->searchCodeExamples(
                $validated['query'] ?? '',
                $validated['source_id'] ?? null,
                $validated['match_count'] ?? 10
            );

            return response()->json([
                'success' => true,
                'results' => $results,
            ]);
        } catch (\Exception $e) {
            logger()->error('Code search error', [
                'error' => $e->getMessage(),
            ]);

            return response()->json([
                'success' => false,
                'message' => 'Code search failed: '.$e->getMessage(),
                'results' => [],
            ], 500);
        }
    }
}
