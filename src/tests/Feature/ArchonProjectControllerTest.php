<?php

use App\Services\ArchonMcpService;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

beforeEach(function () {
    $this->user = \App\Models\User::factory()->create();
    $this->actingAs($this->user);

    $this->archonService = Mockery::mock(ArchonMcpService::class);
    $this->app->instance(ArchonMcpService::class, $this->archonService);
});

describe('Project List', function () {
    it('displays projects with task counts', function () {
        $this->archonService->shouldReceive('findProjects')
            ->once()
            ->andReturn([
                ['id' => 'proj-1', 'title' => 'Project 1'],
                ['id' => 'proj-2', 'title' => 'Project 2']
            ]);

        $this->archonService->shouldReceive('findTasks')
            ->times(2)
            ->andReturn([
                ['id' => '1', 'status' => 'todo'],
                ['id' => '2', 'status' => 'done']
            ]);

        $response = $this->get('/archon/projects');

        $response->assertStatus(200);
        $response->assertInertia(fn ($page) =>
            $page->component('Archon/Projects')
                ->has('projects', 2)
        );
    });

    it('handles empty project list', function () {
        $this->archonService->shouldReceive('findProjects')
            ->once()
            ->andReturn([]);

        $response = $this->get('/archon/projects');

        $response->assertStatus(200);
        $response->assertInertia(fn ($page) =>
            $page->component('Archon/Projects')
                ->has('projects', 0)
        );
    });
});

describe('Project Creation', function () {
    it('creates a new project successfully', function () {
        $this->archonService->shouldReceive('createProject')
            ->once()
            ->with('New Project', 'Description', 'https://github.com/user/repo')
            ->andReturn([
                'id' => 'proj-123',
                'title' => 'New Project',
                'description' => 'Description',
                'github_repo' => 'https://github.com/user/repo'
            ]);

        Event::fake();

        $response = $this->post('/archon/projects', [
            'title' => 'New Project',
            'description' => 'Description',
            'github_repo' => 'https://github.com/user/repo'
        ]);

        $response->assertRedirect('/archon/projects');
        $response->assertSessionHas('success');
    });

    it('validates required fields', function () {
        $response = $this->post('/archon/projects', [
            'description' => 'Description without title'
        ]);

        $response->assertStatus(302);
        $response->assertSessionHasErrors(['title']);
    });

    it('validates title length', function () {
        $response = $this->post('/archon/projects', [
            'title' => str_repeat('a', 256) // Too long
        ]);

        $response->assertSessionHasErrors(['title']);
    });

    it('validates github_repo URL format', function () {
        $response = $this->post('/archon/projects', [
            'title' => 'Project',
            'github_repo' => 'not-a-url'
        ]);

        $response->assertSessionHasErrors(['github_repo']);
    });

    it('handles creation errors', function () {
        $this->archonService->shouldReceive('createProject')
            ->once()
            ->andThrow(new Exception('MCP error'));

        $response = $this->post('/archon/projects', [
            'title' => 'Test Project'
        ]);

        $response->assertRedirect();
        $response->assertSessionHasErrors(['error']);
    });
});

describe('Project Show', function () {
    it('displays project with tasks', function () {
        $this->archonService->shouldReceive('getProject')
            ->once()
            ->with('proj-1')
            ->andReturn([
                'id' => 'proj-1',
                'title' => 'Project 1'
            ]);

        $this->archonService->shouldReceive('findTasks')
            ->once()
            ->with(null, null, null, null, null, 'proj-1', true, 1, 10)
            ->andReturn([
                ['id' => '1', 'title' => 'Task 1', 'status' => 'todo'],
                ['id' => '2', 'title' => 'Task 2', 'status' => 'doing']
            ]);

        $response = $this->get('/archon/projects/proj-1');

        $response->assertStatus(200);
        $response->assertInertia(fn ($page) =>
            $page->component('Archon/ProjectShow')
                ->has('project')
                ->has('tasks', 2)
        );
    });

    it('returns 404 for non-existent project', function () {
        $this->archonService->shouldReceive('getProject')
            ->once()
            ->with('non-existent')
            ->andReturn(null);

        $response = $this->get('/archon/projects/non-existent');

        $response->assertStatus(404);
    });
});

describe('Project Update', function () {
    it('updates project successfully', function () {
        $this->archonService->shouldReceive('updateProject')
            ->once()
            ->with('proj-1', ['title' => 'Updated Title'])
            ->andReturn([
                'id' => 'proj-1',
                'title' => 'Updated Title'
            ]);

        Event::fake();

        $response = $this->put('/archon/projects/proj-1', [
            'title' => 'Updated Title'
        ]);

        $response->assertRedirect();
        $response->assertSessionHas('success');
    });

    it('validates update fields', function () {
        $response = $this->put('/archon/projects/proj-1', [
            'title' => str_repeat('a', 256)
        ]);

        $response->assertSessionHasErrors(['title']);
    });
});

describe('Project Deletion', function () {
    it('deletes project successfully', function () {
        $this->archonService->shouldReceive('deleteProject')
            ->once()
            ->with('proj-1');

        Event::fake();

        $response = $this->delete('/archon/projects/proj-1');

        $response->assertRedirect('/archon/projects');
        $response->assertSessionHas('success');
    });

    it('handles deletion errors', function () {
        $this->archonService->shouldReceive('deleteProject')
            ->once()
            ->andThrow(new Exception('Cannot delete'));

        $response = $this->delete('/archon/projects/proj-1');

        $response->assertRedirect();
        $response->assertSessionHasErrors(['error']);
    });
});

describe('Task Board', function () {
    it('displays task board for project', function () {
        $this->archonService->shouldReceive('getProject')
            ->once()
            ->with('proj-1')
            ->andReturn([
                'id' => 'proj-1',
                'title' => 'Project 1'
            ]);

        $this->archonService->shouldReceive('findTasks')
            ->once()
            ->andReturn([
                ['id' => '1', 'status' => 'todo'],
                ['id' => '2', 'status' => 'doing'],
                ['id' => '3', 'status' => 'review'],
                ['id' => '4', 'status' => 'done']
            ]);

        $response = $this->get('/archon/projects/proj-1/tasks/board');

        $response->assertStatus(200);
        $response->assertInertia(fn ($page) =>
            $page->component('Archon/TaskBoard')
                ->has('project')
                ->has('tasks', 4)
        );
    });
});
