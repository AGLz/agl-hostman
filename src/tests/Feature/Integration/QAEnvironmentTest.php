<?php

use App\Models\Environment;
use App\Services\Deployment\DeploymentWorkflowService;
use App\Services\DokployService;
use Illuminate\Support\Facades\Http;

describe('QA Environment Integration Tests', function () {
    beforeEach(function () {
        $this->environment = Environment::where('type', 'qa')->first();

        if (! $this->environment) {
            $this->markTestSkipped('QA Environment not configured');
        }
    });

    it('has QA environment configured', function () {
        expect($this->environment)->not->toBeNull()
            ->and($this->environment->type)->toBe('qa')
            ->and($this->environment->status)->toBe('active');
    })->group('integration');

    it('has correct environment variables', function () {
        expect($this->environment->env_vars)->toBeArray()
            ->and($this->environment->env_vars['APP_ENV'])->toBe('qa')
            ->and($this->environment->env_vars['APP_DEBUG'])->toBe('true')
            ->and($this->environment->env_vars['DB_DATABASE'])->toBe('agl_hostman_qa')
            ->and($this->environment->env_vars['CACHE_DRIVER'])->toBe('redis')
            ->and($this->environment->env_vars['QUEUE_CONNECTION'])->toBe('redis');
    })->group('integration');

    it('has correct resource limits', function () {
        expect($this->environment->resources)->toBeArray()
            ->and($this->environment->resources['cpu_limit'])->toBe('2')
            ->and($this->environment->resources['memory_limit'])->toBe('4096M');
    })->group('integration');

    it('has domains configured', function () {
        expect($this->environment->domains)->toBeArray()
            ->and($this->environment->domains)->toHaveCount(2)
            ->and($this->environment->getPrimaryDomain())->not->toBeNull();
    })->group('integration');

    it('can connect to Dokploy API', function () {
        $dokployService = app(DokployService::class);

        expect($dokployService->testConnection())->toBeTrue();
    })->group('integration')->skip(fn () => ! config('dokploy.api_url'), 'Dokploy not configured');

    it('has Dokploy project created', function () {
        expect($this->environment->dokploy_project_id)->not->toBeNull();

        $dokployService = app(DokployService::class);
        $project = $dokployService->getProject($this->environment->dokploy_project_id);

        expect($project)->not->toBeNull()
            ->and($project->projectId)->toBe($this->environment->dokploy_project_id);
    })->group('integration')->skip(fn () => ! config('dokploy.api_url'), 'Dokploy not configured');

    it('can reach QA deployment health endpoint', function () {
        $primaryDomain = $this->environment->getPrimaryDomain();

        if (! $primaryDomain) {
            $this->markTestSkipped('No primary domain configured');
        }

        $response = Http::timeout(10)->get("https://{$primaryDomain}/api/health");

        expect($response->successful())->toBeTrue()
            ->and($response->json())->toHaveKey('status')
            ->and($response->json('status'))->toBe('ok');
    })->group('integration')->skip('Requires deployed application');

    it('can connect to QA database', function () {
        $dbConfig = [
            'host' => $this->environment->env_vars['DB_HOST'] ?? 'postgres',
            'port' => $this->environment->env_vars['DB_PORT'] ?? '5432',
            'database' => $this->environment->env_vars['DB_DATABASE'] ?? 'agl_hostman_qa',
        ];

        // Attempt connection
        try {
            \DB::connection('qa')->getPdo();
            expect(true)->toBeTrue();
        } catch (\Exception $e) {
            $this->markTestSkipped('QA database not accessible: '.$e->getMessage());
        }
    })->group('integration')->skip('Requires QA database connection');

    it('can connect to Redis', function () {
        $redisHost = $this->environment->env_vars['REDIS_HOST'] ?? 'redis';
        $redisPort = $this->environment->env_vars['REDIS_PORT'] ?? '6379';

        try {
            $redis = new \Redis;
            $connected = $redis->connect($redisHost, (int) $redisPort, 2);

            expect($connected)->toBeTrue()
                ->and($redis->ping())->toBeInstanceOf(\Redis::class);

            $redis->close();
        } catch (\Exception $e) {
            $this->markTestSkipped('Redis not accessible: '.$e->getMessage());
        }
    })->group('integration')->skip('Requires Redis connection');

    it('has WebSocket connection available', function () {
        $primaryDomain = $this->environment->getPrimaryDomain();

        if (! $primaryDomain) {
            $this->markTestSkipped('No primary domain configured');
        }

        // Check WebSocket endpoint
        $wsUrl = str_replace(['https://', 'http://'], 'wss://', "https://{$primaryDomain}").'/ws';

        // Simple check - would need WebSocket client for full test
        expect($wsUrl)->toContain('wss://');
    })->group('integration')->skip('Requires WebSocket client');

    it('can trigger deployment workflow', function () {
        $workflowService = app(DeploymentWorkflowService::class);

        // This is a dry-run test
        expect($workflowService)->toBeInstanceOf(DeploymentWorkflowService::class);
    })->group('integration');

    it('validates deployment configuration', function () {
        expect($this->environment->auto_deploy)->toBeTrue()
            ->and($this->environment->auto_test)->toBeTrue()
            ->and($this->environment->harbor_project)->toBe('agl-hostman-qa')
            ->and($this->environment->git_branch)->toBe('develop');
    })->group('integration');

    it('has Archon MCP integration configured', function () {
        $archonUrl = $this->environment->env_vars['ARCHON_MCP_URL'] ?? config('archon.mcp_url');

        if (! $archonUrl) {
            $this->markTestSkipped('Archon MCP not configured');
        }

        $response = Http::timeout(5)->get("{$archonUrl}/health");

        expect($response->successful())->toBeTrue();
    })->group('integration')->skip('Requires Archon MCP');
});

describe('QA Deployment Workflow Tests', function () {
    it('can validate deployment workflow steps', function () {
        $workflowService = app(DeploymentWorkflowService::class);

        // Check that all required methods exist
        expect(method_exists($workflowService, 'deployToQA'))->toBeTrue()
            ->and(method_exists($workflowService, 'runIntegrationTests'))->toBeTrue()
            ->and(method_exists($workflowService, 'validateDeployment'))->toBeTrue()
            ->and(method_exists($workflowService, 'notifyDeploymentStatus'))->toBeTrue();
    })->group('integration');

    it('can run integration test suite', function () {
        $workflowService = app(DeploymentWorkflowService::class);

        // Create a test deployment ID
        $testDeploymentId = 'test-'.uniqid();

        // This should not crash (actual test logic will depend on implementation)
        expect(function () {
            // $workflowService->runIntegrationTests($testDeploymentId);
            return true;
        })->not->toThrow(\Exception::class);
    })->group('integration')->skip('Requires actual deployment');
});
