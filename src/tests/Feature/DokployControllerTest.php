<?php

declare(strict_types=1);

use App\Models\User;
use App\Models\DokployProject;
use App\Models\DokployApplication;
use App\Models\DokployDeployment;
use App\Services\DokployService;
use function Pest\Laravel\actingAs;
use function Pest\Laravel\get;
use function Pest\Laravel\post;

beforeEach(function () {
    $this->user = User::factory()->create();
    $this->mockDokployService();
});

test('dashboard renders successfully', function () {
    actingAs($this->user);

    $response = get(route('dokploy.index'));

    $response->assertOk();
    $response->assertInertia(fn($page) => $page
        ->component('Dokploy/Index')
        ->has('projects')
        ->has('stats')
    );
});

test('project show page renders successfully', function () {
    $project = DokployProject::factory()->create();

    actingAs($this->user);

    $response = get(route('dokploy.projects.show', $project->id));

    $response->assertOk();
    $response->assertInertia(fn($page) => $page
        ->component('Dokploy/ProjectShow')
        ->has('project')
        ->has('applications')
        ->has('deployments')
    );
});

test('application show page renders successfully', function () {
    $application = DokployApplication::factory()->create();

    actingAs($this->user);

    $response = get(route('dokploy.applications.show', $application->id));

    $response->assertOk();
    $response->assertInertia(fn($page) => $page
        ->component('Dokploy/ApplicationShow')
        ->has('application')
        ->has('deployments')
        ->has('domains')
        ->has('project')
    );
});

test('deployment history renders successfully', function () {
    DokployDeployment::factory()->count(10)->create();

    actingAs($this->user);

    $response = get(route('dokploy.deployments.history'));

    $response->assertOk();
    $response->assertInertia(fn($page) => $page
        ->component('Dokploy/DeploymentHistory')
        ->has('deployments')
        ->has('filters')
    );
});

test('deploy application returns success', function () {
    $application = DokployApplication::factory()->create();

    actingAs($this->user);

    $response = post(route('dokploy.api.applications.deploy', $application->id), [
        'title' => 'Test Deployment',
        'description' => 'Test deployment description',
    ]);

    $response->assertOk();
    $response->assertJson([
        'success' => true,
        'message' => 'Deployment started successfully',
    ]);

    $this->assertDatabaseHas('dokploy_deployments', [
        'application_id' => $application->id,
        'status' => 'running',
    ]);
});

test('stop application returns success', function () {
    $application = DokployApplication::factory()->create(['status' => 'running']);

    actingAs($this->user);

    $response = post(route('dokploy.api.applications.stop', $application->id));

    $response->assertOk();
    $response->assertJson([
        'success' => true,
        'message' => 'Application stopped successfully',
    ]);
});

test('restart application returns success', function () {
    $application = DokployApplication::factory()->create(['status' => 'stopped']);

    actingAs($this->user);

    $response = post(route('dokploy.api.applications.restart', $application->id));

    $response->assertOk();
    $response->assertJson([
        'success' => true,
        'message' => 'Application restarted successfully',
    ]);
});

test('rollback deployment returns success', function () {
    $deployment = DokployDeployment::factory()->create(['status' => 'done']);

    actingAs($this->user);

    $response = post(route('dokploy.api.deployments.rollback', $deployment->id));

    $response->assertOk();
    $response->assertJson([
        'success' => true,
        'message' => 'Rollback initiated successfully',
    ]);

    $this->assertDatabaseHas('dokploy_deployments', [
        'application_id' => $deployment->application_id,
        'is_rollback' => true,
        'rollback_from_id' => $deployment->id,
    ]);
});

test('cancel deployment returns success', function () {
    $deployment = DokployDeployment::factory()->create(['status' => 'running']);

    actingAs($this->user);

    $response = post(route('dokploy.api.deployments.cancel', $deployment->id));

    $response->assertOk();
    $response->assertJson([
        'success' => true,
        'message' => 'Deployment cancelled successfully',
    ]);

    $this->assertDatabaseHas('dokploy_deployments', [
        'id' => $deployment->id,
        'status' => 'cancelled',
    ]);
});

test('unauthenticated users cannot access dokploy dashboard', function () {
    $response = get(route('dokploy.index'));

    $response->assertRedirect('/login');
});

test('deployment history filters work correctly', function () {
    DokployDeployment::factory()->create(['status' => 'done']);
    DokployDeployment::factory()->create(['status' => 'error']);
    DokployDeployment::factory()->create(['status' => 'running']);

    actingAs($this->user);

    $response = get(route('dokploy.deployments.history', ['status' => 'done']));

    $response->assertOk();
    $response->assertInertia(fn($page) => $page
        ->component('Dokploy/DeploymentHistory')
        ->where('filters.status', 'done')
    );
});

// Helper to mock DokployService
function mockDokployService()
{
    $mock = Mockery::mock(DokployService::class);

    $mock->shouldReceive('getProjects')->andReturn(collect([]));
    $mock->shouldReceive('getProject')->andReturn((object) []);
    $mock->shouldReceive('getApplication')->andReturn((object) []);
    $mock->shouldReceive('deployApplication')->andReturn((object) ['deploymentId' => '123']);
    $mock->shouldReceive('stopApplication')->andReturn(true);
    $mock->shouldReceive('restartApplication')->andReturn(true);
    $mock->shouldReceive('redeployApplication')->andReturn((object) ['deploymentId' => '456']);
    $mock->shouldReceive('cancelDeployment')->andReturn(true);
    $mock->shouldReceive('getDeploymentLogs')->andReturn(collect([]));

    app()->instance(DokployService::class, $mock);
}
