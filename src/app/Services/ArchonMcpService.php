<?php

declare(strict_types=1);

namespace App\Services;

use App\DTOs\Archon\DocumentDTO;
use App\DTOs\Archon\KnowledgeSearchResultDTO;
use App\DTOs\Archon\ProjectDTO;
use App\DTOs\Archon\TaskDTO;
use App\Exceptions\ArchonMcpException;
use App\Services\Archon\ArchonMcpClient;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Log;

/**
 * Archon MCP Service - High-level API for Archon integration
 *
 * Provides developer-friendly methods for:
 * - Knowledge base search (RAG)
 * - Project management
 * - Task tracking
 * - Document management
 * - System monitoring
 */
class ArchonMcpService
{
    public function __construct(
        private readonly ArchonMcpClient $client
    ) {}

    // ========================================================================
    // KNOWLEDGE BASE METHODS
    // ========================================================================

    /**
     * Search knowledge base using semantic search
     *
     * @param  string  $query  Search query (2-5 keywords recommended)
     * @param  string|null  $sourceId  Optional source ID filter
     * @param  int  $matchCount  Maximum results (default: 5)
     * @param  string  $returnMode  'pages' or 'chunks' (default: 'pages')
     * @return Collection<KnowledgeSearchResultDTO>
     */
    public function searchKnowledgeBase(
        string $query,
        ?string $sourceId = null,
        int $matchCount = 5,
        string $returnMode = 'pages'
    ): Collection {
        try {
            $result = $this->client->call('rag_search_knowledge_base', [
                'query' => $query,
                'source_id' => $sourceId,
                'match_count' => $matchCount,
                'return_mode' => $returnMode,
            ], useCache: true);

            if (! $result['success']) {
                throw new ArchonMcpException($result['error'] ?? 'Search failed');
            }

            return collect($result['results'])->map(fn ($r) => KnowledgeSearchResultDTO::fromArray($r));

        } catch (ArchonMcpException $e) {
            Log::error('Knowledge base search failed', [
                'query' => $query,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Search for code examples in knowledge base
     *
     * @param  string  $query  Search query
     * @param  string|null  $sourceId  Optional source ID filter
     * @param  int  $matchCount  Maximum results (default: 3)
     * @return Collection<KnowledgeSearchResultDTO>
     */
    public function searchCodeExamples(
        string $query,
        ?string $sourceId = null,
        int $matchCount = 3
    ): Collection {
        try {
            $result = $this->client->call('rag_search_code_examples', [
                'query' => $query,
                'source_id' => $sourceId,
                'match_count' => $matchCount,
            ], useCache: true);

            if (! $result['success']) {
                throw new ArchonMcpException($result['error'] ?? 'Code search failed');
            }

            return collect($result['results'])->map(fn ($r) => KnowledgeSearchResultDTO::fromArray($r));

        } catch (ArchonMcpException $e) {
            Log::error('Code examples search failed', [
                'query' => $query,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Get available knowledge sources
     */
    public function getAvailableSources(): array
    {
        try {
            $result = $this->client->call('rag_get_available_sources', [], useCache: true);

            if (! $result['success']) {
                throw new ArchonMcpException($result['error'] ?? 'Failed to get sources');
            }

            return $result['sources'] ?? [];

        } catch (ArchonMcpException $e) {
            Log::error('Get available sources failed', ['error' => $e->getMessage()]);
            throw $e;
        }
    }

    /**
     * Read full page content from knowledge base
     *
     * @param  string  $pageId  Page UUID from search results
     */
    public function readFullPage(string $pageId): array
    {
        try {
            $result = $this->client->call('rag_read_full_page', [
                'page_id' => $pageId,
            ], useCache: true);

            if (! $result['success']) {
                throw new ArchonMcpException($result['error'] ?? 'Failed to read page');
            }

            return $result['page'] ?? [];

        } catch (ArchonMcpException $e) {
            Log::error('Read full page failed', [
                'page_id' => $pageId,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Add a new knowledge source (crawl website)
     *
     * @param  string  $url  URL to crawl
     * @param  array  $options  Optional parameters (name, description, tags, max_depth)
     * @return array Progress information
     */
    public function addKnowledgeSource(string $url, array $options = []): array
    {
        try {
            $result = $this->client->call('archon_add_knowledge_source', array_merge([
                'source_type' => 'website',
                'url' => $url,
                'knowledge_type' => 'technical',
                'max_depth' => 2,
            ], $options));

            Log::info('Knowledge source added', [
                'url' => $url,
                'progress_id' => $result['progressId'] ?? null,
            ]);

            return $result;

        } catch (ArchonMcpException $e) {
            Log::error('Add knowledge source failed', [
                'url' => $url,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    // ========================================================================
    // PROJECT MANAGEMENT METHODS
    // ========================================================================

    /**
     * Get projects with optional filtering
     *
     * @param  array  $filters  Optional filters (query, page, per_page)
     * @return Collection<ProjectDTO>
     */
    public function getProjects(array $filters = []): Collection
    {
        try {
            $result = $this->client->call('find_projects', $filters, useCache: true);

            // Handle both single project and array of projects
            $projects = isset($result['projects']) ? $result['projects'] : [$result];

            return collect($projects)->map(fn ($p) => ProjectDTO::fromArray($p));

        } catch (ArchonMcpException $e) {
            Log::error('Get projects failed', ['error' => $e->getMessage()]);
            throw $e;
        }
    }

    /**
     * Get a specific project by ID
     *
     * @param  string  $projectId  Project UUID
     */
    public function getProject(string $projectId): ProjectDTO
    {
        try {
            $result = $this->client->call('find_projects', [
                'project_id' => $projectId,
            ], useCache: true);

            return ProjectDTO::fromArray($result);

        } catch (ArchonMcpException $e) {
            Log::error('Get project failed', [
                'project_id' => $projectId,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Create a new project
     *
     * @param  string  $title  Project title
     * @param  string|null  $description  Project description
     * @param  string|null  $githubRepo  GitHub repository URL
     */
    public function createProject(
        string $title,
        ?string $description = null,
        ?string $githubRepo = null
    ): ProjectDTO {
        try {
            $result = $this->client->call('manage_project', [
                'action' => 'create',
                'title' => $title,
                'description' => $description,
                'github_repo' => $githubRepo,
            ]);

            if (! $result['success']) {
                throw new ArchonMcpException($result['message'] ?? 'Failed to create project');
            }

            Log::info('Project created', [
                'title' => $title,
                'project_id' => $result['project']['id'] ?? null,
            ]);

            return ProjectDTO::fromArray($result['project']);

        } catch (ArchonMcpException $e) {
            Log::error('Create project failed', [
                'title' => $title,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Update an existing project
     *
     * @param  string  $projectId  Project UUID
     * @param  array  $data  Fields to update (title, description, github_repo)
     */
    public function updateProject(string $projectId, array $data): ProjectDTO
    {
        try {
            $result = $this->client->call('manage_project', array_merge([
                'action' => 'update',
                'project_id' => $projectId,
            ], $data));

            if (! $result['success']) {
                throw new ArchonMcpException($result['message'] ?? 'Failed to update project');
            }

            Log::info('Project updated', ['project_id' => $projectId]);

            return ProjectDTO::fromArray($result['project']);

        } catch (ArchonMcpException $e) {
            Log::error('Update project failed', [
                'project_id' => $projectId,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Delete a project
     *
     * @param  string  $projectId  Project UUID
     */
    public function deleteProject(string $projectId): bool
    {
        try {
            $result = $this->client->call('manage_project', [
                'action' => 'delete',
                'project_id' => $projectId,
            ]);

            if (! $result['success']) {
                throw new ArchonMcpException($result['message'] ?? 'Failed to delete project');
            }

            Log::info('Project deleted', ['project_id' => $projectId]);

            return true;

        } catch (ArchonMcpException $e) {
            Log::error('Delete project failed', [
                'project_id' => $projectId,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Get project features
     *
     * @param  string  $projectId  Project UUID
     */
    public function getProjectFeatures(string $projectId): array
    {
        try {
            $result = $this->client->call('get_project_features', [
                'project_id' => $projectId,
            ], useCache: true);

            if (! $result['success']) {
                throw new ArchonMcpException($result['error'] ?? 'Failed to get features');
            }

            return $result['features'] ?? [];

        } catch (ArchonMcpException $e) {
            Log::error('Get project features failed', [
                'project_id' => $projectId,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    // ========================================================================
    // TASK MANAGEMENT METHODS
    // ========================================================================

    /**
     * Get tasks with optional filtering
     *
     * @param  array  $filters  Optional filters (query, filter_by, filter_value, project_id, etc.)
     * @return Collection<TaskDTO>
     */
    public function getTasks(array $filters = []): Collection
    {
        try {
            $result = $this->client->call('find_tasks', $filters, useCache: true);

            // Handle both single task and array of tasks
            $tasks = isset($result['tasks']) ? $result['tasks'] : [$result];

            return collect($tasks)->map(fn ($t) => TaskDTO::fromArray($t));

        } catch (ArchonMcpException $e) {
            Log::error('Get tasks failed', ['error' => $e->getMessage()]);
            throw $e;
        }
    }

    /**
     * Get a specific task by ID
     *
     * @param  string  $taskId  Task UUID
     */
    public function getTask(string $taskId): TaskDTO
    {
        try {
            $result = $this->client->call('find_tasks', [
                'task_id' => $taskId,
            ], useCache: true);

            return TaskDTO::fromArray($result);

        } catch (ArchonMcpException $e) {
            Log::error('Get task failed', [
                'task_id' => $taskId,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Create a new task
     *
     * @param  string  $projectId  Project UUID
     * @param  string  $title  Task title
     * @param  array  $data  Optional fields (description, status, assignee, task_order, feature)
     */
    public function createTask(string $projectId, string $title, array $data = []): TaskDTO
    {
        try {
            $result = $this->client->call('manage_task', array_merge([
                'action' => 'create',
                'project_id' => $projectId,
                'title' => $title,
                'status' => 'todo',
                'assignee' => 'User',
            ], $data));

            if (! $result['success']) {
                throw new ArchonMcpException($result['message'] ?? 'Failed to create task');
            }

            Log::info('Task created', [
                'title' => $title,
                'task_id' => $result['task']['id'] ?? null,
            ]);

            return TaskDTO::fromArray($result['task']);

        } catch (ArchonMcpException $e) {
            Log::error('Create task failed', [
                'title' => $title,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Update task status
     *
     * @param  string  $taskId  Task UUID
     * @param  string  $status  New status (todo, doing, review, done)
     */
    public function updateTaskStatus(string $taskId, string $status): TaskDTO
    {
        try {
            $result = $this->client->call('manage_task', [
                'action' => 'update',
                'task_id' => $taskId,
                'status' => $status,
            ]);

            if (! $result['success']) {
                throw new ArchonMcpException($result['message'] ?? 'Failed to update task status');
            }

            Log::info('Task status updated', [
                'task_id' => $taskId,
                'status' => $status,
            ]);

            return TaskDTO::fromArray($result['task']);

        } catch (ArchonMcpException $e) {
            Log::error('Update task status failed', [
                'task_id' => $taskId,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Delete a task
     *
     * @param  string  $taskId  Task UUID
     */
    public function deleteTask(string $taskId): bool
    {
        try {
            $result = $this->client->call('manage_task', [
                'action' => 'delete',
                'task_id' => $taskId,
            ]);

            if (! $result['success']) {
                throw new ArchonMcpException($result['message'] ?? 'Failed to delete task');
            }

            Log::info('Task deleted', ['task_id' => $taskId]);

            return true;

        } catch (ArchonMcpException $e) {
            Log::error('Delete task failed', [
                'task_id' => $taskId,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    // ========================================================================
    // DOCUMENT MANAGEMENT METHODS
    // ========================================================================

    /**
     * Get documents for a project
     *
     * @param  string  $projectId  Project UUID
     * @param  array  $filters  Optional filters (query, document_type, page, per_page)
     * @return Collection<DocumentDTO>
     */
    public function getDocuments(string $projectId, array $filters = []): Collection
    {
        try {
            $result = $this->client->call('find_documents', array_merge([
                'project_id' => $projectId,
            ], $filters), useCache: true);

            $documents = isset($result['documents']) ? $result['documents'] : [$result];

            return collect($documents)->map(fn ($d) => DocumentDTO::fromArray($d));

        } catch (ArchonMcpException $e) {
            Log::error('Get documents failed', [
                'project_id' => $projectId,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Create a new document
     *
     * @param  string  $projectId  Project UUID
     * @param  string  $title  Document title
     * @param  string  $type  Document type (spec, design, note, prp, api, guide)
     * @param  mixed  $content  Document content (array or string)
     * @param  array  $options  Optional (tags, author)
     */
    public function createDocument(
        string $projectId,
        string $title,
        string $type,
        mixed $content,
        array $options = []
    ): DocumentDTO {
        try {
            $result = $this->client->call('manage_document', array_merge([
                'action' => 'create',
                'project_id' => $projectId,
                'title' => $title,
                'document_type' => $type,
                'content' => $content,
            ], $options));

            if (! $result['success']) {
                throw new ArchonMcpException($result['message'] ?? 'Failed to create document');
            }

            Log::info('Document created', [
                'title' => $title,
                'document_id' => $result['document']['id'] ?? null,
            ]);

            return DocumentDTO::fromArray($result['document']);

        } catch (ArchonMcpException $e) {
            Log::error('Create document failed', [
                'title' => $title,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    // ========================================================================
    // SYSTEM METHODS
    // ========================================================================

    /**
     * Check MCP server health
     *
     * @return array Health status
     */
    public function healthCheck(): array
    {
        try {
            return $this->client->call('health_check');
        } catch (ArchonMcpException $e) {
            Log::error('Health check failed', ['error' => $e->getMessage()]);
            throw $e;
        }
    }

    /**
     * Get Archon system status
     *
     * @return array System status and configuration
     */
    public function getStatus(): array
    {
        try {
            return $this->client->call('archon_get_status', [], useCache: true);
        } catch (ArchonMcpException $e) {
            Log::error('Get status failed', ['error' => $e->getMessage()]);
            throw $e;
        }
    }

    /**
     * Test MCP connection
     */
    public function ping(): bool
    {
        return $this->client->ping();
    }
}
