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

describe('Task Creation', function () {
    it('creates a new task successfully', function () {
        $this->archonService->shouldReceive('createTask')
            ->once()
            ->with(
                'proj-1',
                'New Task',
                'Task description',
                'todo',
                'User',
                5,
                'feature-1'
            )
            ->andReturn([
                'id' => 'task-1',
                'title' => 'New Task',
                'status' => 'todo',
                'project_id' => 'proj-1'
            ]);

        Event::fake();

        $response = $this->post('/archon/tasks', [
            'project_id' => 'proj-1',
            'title' => 'New Task',
            'description' => 'Task description',
            'status' => 'todo',
            'assignee' => 'User',
            'priority' => 'medium',
            'feature' => 'feature-1',
            'task_order' => 5
        ]);

        $response->assertRedirect();
        $response->assertSessionHas('success');
    });

    it('validates required fields', function () {
        $response = $this->post('/archon/tasks', [
            'description' => 'Missing project_id and title'
        ]);

        $response->assertSessionHasErrors(['project_id', 'title', 'status']);
    });

    it('validates status enum', function () {
        $response = $this->post('/archon/tasks', [
            'project_id' => 'proj-1',
            'title' => 'Task',
            'status' => 'invalid-status'
        ]);

        $response->assertSessionHasErrors(['status']);
    });

    it('validates priority enum', function () {
        $response = $this->post('/archon/tasks', [
            'project_id' => 'proj-1',
            'title' => 'Task',
            'status' => 'todo',
            'priority' => 'invalid-priority'
        ]);

        $response->assertSessionHasErrors(['priority']);
    });

    it('validates task_order range', function () {
        $response = $this->post('/archon/tasks', [
            'project_id' => 'proj-1',
            'title' => 'Task',
            'status' => 'todo',
            'task_order' => 101 // Out of range
        ]);

        $response->assertSessionHasErrors(['task_order']);
    });
});

describe('Task Update', function () {
    it('updates task successfully', function () {
        $this->archonService->shouldReceive('updateTask')
            ->once()
            ->with('task-1', ['title' => 'Updated Title', 'status' => 'doing'])
            ->andReturn([
                'id' => 'task-1',
                'title' => 'Updated Title',
                'status' => 'doing',
                'project_id' => 'proj-1'
            ]);

        Event::fake();

        $response = $this->put('/archon/tasks/task-1', [
            'title' => 'Updated Title',
            'status' => 'doing'
        ]);

        $response->assertRedirect();
        $response->assertSessionHas('success');
    });

    it('broadcasts task moved event when status changes', function () {
        $this->archonService->shouldReceive('updateTask')
            ->once()
            ->andReturn([
                'id' => 'task-1',
                'status' => 'done',
                'project_id' => 'proj-1'
            ]);

        Event::fake();

        $this->put('/archon/tasks/task-1', [
            'status' => 'done'
        ]);

        Event::assertDispatched(\App\Events\ArchonTaskMoved::class);
    });

    it('returns JSON response when expecting JSON', function () {
        $this->archonService->shouldReceive('updateTask')
            ->once()
            ->andReturn([
                'id' => 'task-1',
                'title' => 'Updated'
            ]);

        $response = $this->putJson('/archon/tasks/task-1', [
            'title' => 'Updated'
        ]);

        $response->assertStatus(200);
        $response->assertJson([
            'success' => true
        ]);
    });

    it('handles update errors', function () {
        $this->archonService->shouldReceive('updateTask')
            ->once()
            ->andThrow(new Exception('Update failed'));

        $response = $this->putJson('/archon/tasks/task-1', [
            'title' => 'Updated'
        ]);

        $response->assertStatus(500);
        $response->assertJson([
            'success' => false
        ]);
    });
});

describe('Task Deletion', function () {
    it('deletes task successfully', function () {
        $this->archonService->shouldReceive('deleteTask')
            ->once()
            ->with('task-1');

        Event::fake();

        $response = $this->delete('/archon/tasks/task-1');

        $response->assertRedirect();
        $response->assertSessionHas('success');

        Event::assertDispatched(\App\Events\ArchonTaskDeleted::class);
    });

    it('handles deletion errors', function () {
        $this->archonService->shouldReceive('deleteTask')
            ->once()
            ->andThrow(new Exception('Cannot delete'));

        $response = $this->delete('/archon/tasks/task-1');

        $response->assertRedirect();
        $response->assertSessionHasErrors(['error']);
    });
});

describe('Bulk Task Update', function () {
    it('updates multiple tasks successfully', function () {
        $this->archonService->shouldReceive('updateTask')
            ->times(2)
            ->andReturn(
                ['id' => 'task-1', 'status' => 'doing', 'project_id' => 'proj-1'],
                ['id' => 'task-2', 'status' => 'review', 'project_id' => 'proj-1']
            );

        Event::fake();

        $response = $this->postJson('/archon/tasks/bulk-update', [
            'tasks' => [
                ['id' => 'task-1', 'status' => 'doing', 'task_order' => 1],
                ['id' => 'task-2', 'status' => 'review', 'task_order' => 2]
            ]
        ]);

        $response->assertStatus(200);
        $response->assertJson([
            'success' => true
        ]);
        $response->assertJsonStructure([
            'success',
            'tasks'
        ]);

        Event::assertDispatched(\App\Events\ArchonTaskMoved::class, 2);
    });

    it('validates bulk update payload', function () {
        $response = $this->postJson('/archon/tasks/bulk-update', [
            'tasks' => [
                ['id' => 'task-1'] // Missing status
            ]
        ]);

        $response->assertStatus(422);
        $response->assertJsonValidationErrors(['tasks.0.status']);
    });

    it('handles bulk update errors', function () {
        $this->archonService->shouldReceive('updateTask')
            ->once()
            ->andThrow(new Exception('Bulk update failed'));

        $response = $this->postJson('/archon/tasks/bulk-update', [
            'tasks' => [
                ['id' => 'task-1', 'status' => 'doing']
            ]
        ]);

        $response->assertStatus(500);
        $response->assertJson([
            'success' => false
        ]);
    });
});

describe('Task Status Transitions', function () {
    it('allows todo -> doing transition', function () {
        $this->archonService->shouldReceive('updateTask')
            ->once()
            ->with('task-1', ['status' => 'doing'])
            ->andReturn(['id' => 'task-1', 'status' => 'doing', 'project_id' => 'proj-1']);

        $response = $this->putJson('/archon/tasks/task-1', [
            'status' => 'doing'
        ]);

        $response->assertSuccessful();
    });

    it('allows doing -> review transition', function () {
        $this->archonService->shouldReceive('updateTask')
            ->once()
            ->with('task-1', ['status' => 'review'])
            ->andReturn(['id' => 'task-1', 'status' => 'review', 'project_id' => 'proj-1']);

        $response = $this->putJson('/archon/tasks/task-1', [
            'status' => 'review'
        ]);

        $response->assertSuccessful();
    });

    it('allows review -> done transition', function () {
        $this->archonService->shouldReceive('updateTask')
            ->once()
            ->with('task-1', ['status' => 'done'])
            ->andReturn(['id' => 'task-1', 'status' => 'done', 'project_id' => 'proj-1']);

        $response = $this->putJson('/archon/tasks/task-1', [
            'status' => 'done'
        ]);

        $response->assertSuccessful();
    });
});
