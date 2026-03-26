<?php

use App\Services\ArchonMcpService;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

beforeEach(function () {
    // Mock authenticated user
    $this->user = \App\Models\User::factory()->create();
    $this->actingAs($this->user);

    // Mock ArchonMcpService
    $this->archonService = Mockery::mock(ArchonMcpService::class);
    $this->app->instance(ArchonMcpService::class, $this->archonService);
});

describe('Archon Dashboard', function () {
    it('displays dashboard with statistics', function () {
        $this->archonService->shouldReceive('findProjects')
            ->once()
            ->andReturn([
                ['id' => '1', 'title' => 'Project 1'],
                ['id' => '2', 'title' => 'Project 2'],
            ]);

        $this->archonService->shouldReceive('findTasks')
            ->once()
            ->andReturn([
                ['id' => '1', 'status' => 'todo'],
                ['id' => '2', 'status' => 'doing'],
            ]);

        $this->archonService->shouldReceive('getAvailableSources')
            ->once()
            ->andReturn([
                ['id' => 'src1', 'name' => 'Source 1'],
            ]);

        $this->archonService->shouldReceive('checkHealth')
            ->once()
            ->andReturn(true);

        $response = $this->get('/archon');

        $response->assertStatus(200);
        $response->assertInertia(fn ($page) => $page->component('Archon/Index')
            ->has('stats', fn ($stats) => $stats->where('total_projects', 2)
                ->where('active_tasks', 2)
                ->where('knowledge_sources', 1)
                ->where('mcp_status', 'connected')
            )
        );
    });

    it('handles dashboard errors gracefully', function () {
        $this->archonService->shouldReceive('findProjects')
            ->once()
            ->andThrow(new Exception('MCP connection failed'));

        $this->archonService->shouldReceive('findTasks')
            ->never();

        $response = $this->get('/archon');

        $response->assertStatus(200);
        $response->assertInertia(fn ($page) => $page->component('Archon/Index')
            ->has('stats', fn ($stats) => $stats->where('mcp_status', 'error')
            )
        );
    });
});

describe('Knowledge Base', function () {
    it('displays knowledge base page with sources', function () {
        $this->archonService->shouldReceive('getAvailableSources')
            ->once()
            ->andReturn([
                ['id' => 'src1', 'name' => 'Documentation'],
                ['id' => 'src2', 'name' => 'Code Examples'],
            ]);

        $response = $this->get('/archon/knowledge');

        $response->assertStatus(200);
        $response->assertInertia(fn ($page) => $page->component('Archon/KnowledgeBase')
            ->has('sources', 2)
        );
    });

    it('performs knowledge base search', function () {
        $this->archonService->shouldReceive('searchKnowledgeBase')
            ->once()
            ->with('WireGuard', null, 10, 'pages')
            ->andReturn([
                ['title' => 'WireGuard Setup', 'content' => 'Setup guide...'],
            ]);

        $response = $this->postJson('/archon/knowledge/search', [
            'query' => 'WireGuard',
            'match_count' => 10,
            'return_mode' => 'pages',
        ]);

        $response->assertStatus(200);
        $response->assertJson([
            'success' => true,
            'query' => 'WireGuard',
        ]);
        $response->assertJsonStructure([
            'success',
            'results',
            'query',
        ]);
    });

    it('validates search parameters', function () {
        $response = $this->postJson('/archon/knowledge/search', [
            'query' => str_repeat('a', 501), // Too long
        ]);

        $response->assertStatus(422);
        $response->assertJsonValidationErrors(['query']);
    });

    it('handles search errors', function () {
        $this->archonService->shouldReceive('searchKnowledgeBase')
            ->once()
            ->andThrow(new Exception('Search failed'));

        $response = $this->postJson('/archon/knowledge/search', [
            'query' => 'test',
        ]);

        $response->assertStatus(500);
        $response->assertJson([
            'success' => false,
        ]);
    });

    it('returns autocomplete suggestions', function () {
        $response = $this->postJson('/archon/knowledge/suggestions', [
            'query' => 'wire',
            'limit' => 5,
        ]);

        $response->assertStatus(200);
        $response->assertJsonStructure([
            'success',
            'suggestions',
        ]);
    });

    it('gets full page content', function () {
        $this->archonService->shouldReceive('readFullPage')
            ->once()
            ->with('page-123', null)
            ->andReturn([
                'id' => 'page-123',
                'title' => 'Full Page',
                'content' => 'Complete content...',
            ]);

        $response = $this->postJson('/archon/knowledge/page', [
            'page_id' => 'page-123',
        ]);

        $response->assertStatus(200);
        $response->assertJson([
            'success' => true,
        ]);
    });

    it('searches code examples', function () {
        $this->archonService->shouldReceive('searchCodeExamples')
            ->once()
            ->with('React hooks', null, 10)
            ->andReturn([
                ['language' => 'javascript', 'content' => 'const [state, setState] = useState();'],
            ]);

        $response = $this->postJson('/archon/knowledge/code', [
            'query' => 'React hooks',
            'match_count' => 10,
        ]);

        $response->assertStatus(200);
        $response->assertJson([
            'success' => true,
        ]);
    });
});

describe('Authentication', function () {
    it('requires authentication for all routes', function () {
        auth()->logout();

        $response = $this->get('/archon');
        $response->assertRedirect('/login');

        $response = $this->get('/archon/knowledge');
        $response->assertRedirect('/login');

        $response = $this->get('/archon/projects');
        $response->assertRedirect('/login');
    });
});
