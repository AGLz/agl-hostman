<?php

declare(strict_types=1);

use App\DTOs\Dokploy\DeploymentDTO;
use App\Models\DokployApplication;
use App\Models\DokployDeployment;
use App\Services\Deployment\DeploymentWorkflowService;
use App\Services\DokployService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\Log;

uses(RefreshDatabase::class);

// ---------------------------------------------------------------------------
// Helpers — create test data without factories
// ---------------------------------------------------------------------------

function createProject(string $dokployId = 'proj-test'): \App\Models\DokployProject
{
    return \App\Models\DokployProject::create([
        'dokploy_id' => $dokployId,
        'name' => 'Test Project',
        'status' => 'active',
    ]);
}

function createApp(int $projectId, string $dokployId = 'app-test'): DokployApplication
{
    return DokployApplication::create([
        'project_id' => $projectId,
        'dokploy_id' => $dokployId,
        'name' => 'agl-hostman-qa',
        'app_name' => 'agl-hostman-qa',
        'status' => 'running',
    ]);
}

function createDeployment(int $appId, string $status = 'success', ?string $tag = null, ?string $commit = null): DokployDeployment
{
    return DokployDeployment::create([
        'application_id' => $appId,
        'status' => $status,
        'title' => "Deploy {$tag}",
        'tag' => $tag ?? 'qa-abc1234',
        'commit_hash' => $commit ?? 'abc1234def5678',
        'branch' => 'develop',
        'triggered_by' => 'ci',
        'started_at' => now()->subMinutes(10),
        'completed_at' => now()->subMinutes(5),
    ]);
}

// ---------------------------------------------------------------------------
// Suite
// ---------------------------------------------------------------------------

describe('DeploymentWorkflowService::rollback()', function () {

    beforeEach(function () {
        $this->mockDokploy = Mockery::mock(DokployService::class);
        $this->service = new DeploymentWorkflowService($this->mockDokploy);

        Config::set('deployment.rollback_enabled', true);
        Config::set('deployment.max_rollback_span', 5);
    });

    afterEach(function () {
        Mockery::close();
    });

    // -----------------------------------------------------------------------
    // C.4 test 1: rollback finds previous successful deployment
    // -----------------------------------------------------------------------
    it('finds the previous successful deployment and re-deploys it', function () {
        $project = createProject('proj-1');
        $app = createApp($project->id, 'dokapp-1');

        $goodDeployment = createDeployment($app->id, 'success', 'qa-aaa0001', 'aaa0001');
        $failedDeployment = createDeployment($app->id, 'failed', 'qa-bbb0002', 'bbb0002');

        $this->mockDokploy
            ->shouldReceive('deployApplication')
            ->once()
            ->with(
                $app->dokploy_id, // application's dokploy_application_id falls back to dokploy_id
                Mockery::on(fn ($title) => str_contains($title, 'Rollback')),
                Mockery::any()
            )
            ->andReturn(new DeploymentDTO(deploymentId: 'dep-test', status: 'pending'));

        $result = $this->service->rollback((string) $failedDeployment->id, 'test rollback');

        expect($result['success'])->toBeTrue();
        expect($result['rolled_back_to_deployment'])->toBe($goodDeployment->id);
        expect($result['rolled_back_to_tag'])->toBe('qa-aaa0001');
        expect($result['rolled_back_to_commit'])->toBe('aaa0001');
        expect($result)->toHaveKey('rollback_deployment_id');
    });

    // -----------------------------------------------------------------------
    // C.4 test 2: rollback throws when no previous deployment exists
    // -----------------------------------------------------------------------
    it('returns success=false when no previous successful deployment exists', function () {
        $project = createProject('proj-2');
        $app = createApp($project->id, 'dokapp-2');

        $onlyDeployment = createDeployment($app->id, 'failed', 'qa-ccc0003', 'ccc0003');

        $this->mockDokploy->shouldNotReceive('deployApplication');

        $result = $this->service->rollback((string) $onlyDeployment->id);

        expect($result['success'])->toBeFalse();
        expect($result['error'])->toContain('No previous successful deployment found');
    });

    // -----------------------------------------------------------------------
    // C.4 test 3: rollback creates a deployment record with status 'rollback'
    // -----------------------------------------------------------------------
    it('creates a rollback deployment record for audit trail', function () {
        $project = createProject('proj-3');
        $app = createApp($project->id, 'dokapp-3');

        $goodDeployment = createDeployment($app->id, 'success', 'qa-ddd0004', 'ddd0004');
        $failedDeployment = createDeployment($app->id, 'failed', 'qa-eee0005', 'eee0005');

        $this->mockDokploy
            ->shouldReceive('deployApplication')
            ->once()
            ->andReturn(new DeploymentDTO(deploymentId: 'dep-test', status: 'pending'));

        $this->service->rollback((string) $failedDeployment->id, 'audit trail test');

        $rollbackRecord = DokployDeployment::where('status', 'rollback')
            ->where('application_id', $app->id)
            ->first();

        expect($rollbackRecord)->not()->toBeNull();
        expect($rollbackRecord->triggered_by)->toBe('rollback');
        expect($rollbackRecord->tag)->toBe('qa-ddd0004');
        expect($rollbackRecord->commit_hash)->toBe('ddd0004');
        expect($rollbackRecord->metadata['rollback_from_deployment_id'])->toBe($failedDeployment->id);
        expect($rollbackRecord->metadata['rollback_to_deployment_id'])->toBe($goodDeployment->id);
    });

    // -----------------------------------------------------------------------
    // C.4 test 4: rollback picks the MOST RECENT successful deployment
    // -----------------------------------------------------------------------
    it('picks the most recent successful deployment when multiple exist', function () {
        $project = createProject('proj-4');
        $app = createApp($project->id, 'dokapp-4');

        $olderGood = createDeployment($app->id, 'success', 'qa-v1', 'v1hash');
        // Ensure completed_at ordering is distinct
        $olderGood->update(['completed_at' => now()->subMinutes(30)]);

        $newerGood = createDeployment($app->id, 'success', 'qa-v2', 'v2hash');
        $newerGood->update(['completed_at' => now()->subMinutes(10)]);

        $failedDeployment = createDeployment($app->id, 'failed', 'qa-v3', 'v3hash');

        $this->mockDokploy
            ->shouldReceive('deployApplication')
            ->once()
            ->andReturn(new DeploymentDTO(deploymentId: 'dep-test', status: 'pending'));

        $result = $this->service->rollback((string) $failedDeployment->id);

        expect($result['success'])->toBeTrue();
        expect($result['rolled_back_to_deployment'])->toBe($newerGood->id);
        expect($result['rolled_back_to_tag'])->toBe('qa-v2');
    });

    // -----------------------------------------------------------------------
    // C.4 test 5: rollback handles Dokploy service failure gracefully
    // -----------------------------------------------------------------------
    it('handles dokploy service failure gracefully and returns success=false', function () {
        $project = createProject('proj-5');
        $app = createApp($project->id, 'dokapp-5');

        $goodDeployment = createDeployment($app->id, 'success', 'qa-fff0006', 'fff0006');
        $failedDeployment = createDeployment($app->id, 'failed', 'qa-ggg0007', 'ggg0007');

        $this->mockDokploy
            ->shouldReceive('deployApplication')
            ->once()
            ->andThrow(new \Exception('Dokploy API unreachable'));

        $result = $this->service->rollback((string) $failedDeployment->id, 'dokploy failure test');

        expect($result['success'])->toBeFalse();
        expect($result['error'])->toContain('Dokploy API unreachable');
    });

    // -----------------------------------------------------------------------
    // C.4 test 6: rollbackUAT delegates to generic rollback
    // -----------------------------------------------------------------------
    it('rollbackUAT() delegates to the generic rollback() method', function () {
        $project = createProject('proj-6');
        $app = createApp($project->id, 'dokapp-6');

        $goodDeployment = createDeployment($app->id, 'success', 'uat-hhh0008', 'hhh0008');
        $failedDeployment = createDeployment($app->id, 'failed', 'uat-iii0009', 'iii0009');

        $this->mockDokploy
            ->shouldReceive('deployApplication')
            ->once()
            ->andReturn(new DeploymentDTO(deploymentId: 'dep-test', status: 'pending'));

        $result = $this->service->rollbackUAT((string) $failedDeployment->id);

        expect($result['success'])->toBeTrue();
        expect($result['rolled_back_to_deployment'])->toBe($goodDeployment->id);

        // Verify the audit record contains the UAT-specific reason
        $record = DokployDeployment::where('status', 'rollback')
            ->where('application_id', $app->id)
            ->first();
        expect($record->description)->toContain('UAT');
    });

    // -----------------------------------------------------------------------
    // C.4 test 7: span warning is logged but rollback still proceeds
    // -----------------------------------------------------------------------
    it('logs a warning when rollback spans more than max_rollback_span deployments', function () {
        Config::set('deployment.max_rollback_span', 2);

        $project = createProject('proj-7');
        $app = createApp($project->id, 'dokapp-7');

        // Create a successful deployment
        $goodDeployment = createDeployment($app->id, 'success', 'qa-base', 'base0000');
        $goodDeployment->update(['completed_at' => now()->subHours(2)]);

        // Create 3 failed deployments between them — span = 4 (exceeds max=2)
        for ($i = 1; $i <= 3; $i++) {
            createDeployment($app->id, 'failed', "qa-fail{$i}", "fail{$i}000");
        }

        $latestFailed = createDeployment($app->id, 'failed', 'qa-failLast', 'failLast0');

        Log::shouldReceive('warning')
            ->withArgs(fn ($msg) => str_contains($msg, 'Rollback spans more than'))
            ->atLeast()->once();

        $this->mockDokploy
            ->shouldReceive('deployApplication')
            ->once()
            ->andReturn(new DeploymentDTO(deploymentId: 'dep-test', status: 'pending'));

        // Also allow other Log calls
        Log::shouldReceive('warning')->withAnyArgs()->zeroOrMoreTimes();
        Log::shouldReceive('info')->withAnyArgs()->zeroOrMoreTimes();
        Log::shouldReceive('error')->withAnyArgs()->zeroOrMoreTimes();

        $result = $this->service->rollback((string) $latestFailed->id);

        // Rollback still succeeds despite the warning
        expect($result['success'])->toBeTrue();
        expect($result['rolled_back_to_deployment'])->toBe($goodDeployment->id);
    });
});

// ---------------------------------------------------------------------------
// scopeRollback on model
// ---------------------------------------------------------------------------
describe('DokployDeployment::scopeRollback()', function () {
    it('filters deployments with status rollback', function () {
        $project = createProject('proj-scope');
        $app = createApp($project->id, 'dokapp-scope');

        createDeployment($app->id, 'success', 'qa-s1');
        createDeployment($app->id, 'failed', 'qa-f1');
        createDeployment($app->id, 'rollback', 'qa-r1');
        createDeployment($app->id, 'rollback', 'qa-r2');

        $rollbacks = DokployDeployment::rollback()->get();

        expect($rollbacks)->toHaveCount(2);
        $rollbacks->each(fn ($d) => expect($d->status)->toBe('rollback'));
    });
});

// ---------------------------------------------------------------------------
// RollbackDeployment artisan command — --latest --env resolution
// ---------------------------------------------------------------------------
describe('deployment:rollback-deployment --latest --env', function () {
    it('resolves the most recent failed deployment for the qa environment via project bridge', function () {
        // Create a Dokploy project with a known dokploy_id
        $project = createProject('proj-env-qa');

        // Create an Environment of type=qa pointing at that project
        \App\Models\Environment::create([
            'name' => 'QA',
            'type' => 'qa',
            'dokploy_project_id' => 'proj-env-qa',
            'harbor_project' => 'agl-test',
            'git_branch' => 'develop',
            'auto_deploy' => false,
            'auto_test' => false,
            'status' => 'active',
            'domains' => [],
            'env_vars' => [],
            'resources' => [],
        ]);

        $app = createApp($project->id, 'dokapp-env-qa');

        $successDeployment = createDeployment($app->id, 'success', 'qa-v10', 'v10hash');
        $successDeployment->update(['completed_at' => now()->subMinutes(20)]);

        $failedDeployment = createDeployment($app->id, 'failed', 'qa-v11', 'v11hash');

        // Use --dry-run so no confirmation prompt and no service call needed
        $this->artisan('deployment:rollback-deployment', [
            '--latest' => true,
            '--env' => 'qa',
            '--dry-run' => true,
        ])
            ->expectsOutputToContain('Rolling back deployment #' . $failedDeployment->id)
            ->expectsOutputToContain('DRY-RUN')
            ->assertExitCode(0);
    });

    it('returns failure when environment type does not exist', function () {
        $this->artisan('deployment:rollback-deployment', [
            '--latest' => true,
            '--env' => 'staging',
            '--dry-run' => true,
        ])
            ->expectsOutputToContain('Environment not found for type: staging')
            ->assertExitCode(1);
    });
});
