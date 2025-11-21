<?php

use App\Models\User;
use App\Services\DokployApiClient;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;

uses(RefreshDatabase::class);

beforeEach(function () {
    $this->user = User::factory()->create();
});

describe('DokployApiClient', function () {
    beforeEach(function () {
        // Mock Dokploy API
        Http::fake([
            '*/api/project.all' => Http::response([
                ['projectId' => 'proj-1', 'name' => 'Test Project'],
            ], 200),
            '*/api/application.all' => Http::response([
                ['applicationId' => 'app-1', 'name' => 'Test App', 'dockerImage' => 'nginx:latest'],
            ], 200),
            '*/api/application.one*' => Http::response([
                'applicationId' => 'app-1',
                'name' => 'Test App',
                'status' => 'running',
            ], 200),
            '*/api/application.start' => Http::response(['success' => true], 200),
            '*/api/application.stop' => Http::response(['success' => true], 200),
            '*/api/application.redeploy' => Http::response(['success' => true], 200),
            '*/api/application.delete' => Http::response(['success' => true], 200),
        ]);

        $this->client = new DokployApiClient(
            baseUrl: 'https://dok.aglz.io',
            apiKey: 'test-api-key'
        );
    });

    it('can fetch all applications', function () {
        $response = $this->client->getApplications();

        expect($response->isSuccess())->toBeTrue();
        expect($response->getData())->toBeArray();
        expect($response->getData())->toHaveCount(1);
        expect($response->getData()[0]['name'])->toBe('Test App');
    });

    it('can fetch single application', function () {
        $response = $this->client->getApplication('app-1');

        expect($response->isSuccess())->toBeTrue();
        expect($response->getData())->toBeArray();
        expect($response->getData()['applicationId'] ?? $response->getData()[0]['applicationId'] ?? null)->toBe('app-1');
    });

    it('can start application', function () {
        $response = $this->client->startApplication('app-1');

        expect($response->isSuccess())->toBeTrue();
    });

    it('can stop application', function () {
        $response = $this->client->stopApplication('app-1');

        expect($response->isSuccess())->toBeTrue();
    });

    it('can redeploy application', function () {
        $response = $this->client->redeployApplication('app-1');

        expect($response->isSuccess())->toBeTrue();
    });

    it('can delete application', function () {
        $response = $this->client->deleteApplication('app-1');

        expect($response->isSuccess())->toBeTrue();
    });

    it('can fetch projects', function () {
        $response = $this->client->getProjects();

        expect($response->isSuccess())->toBeTrue();
        expect($response->getData())->toBeArray();
        expect($response->getData()[0]['name'])->toBe('Test Project');
    });

    it('can test connection', function () {
        $isConnected = $this->client->testConnection();

        expect($isConnected)->toBeTrue();
    });
});

describe('DokployApiClient Circuit Breaker', function () {
    it('handles API failures with circuit breaker', function () {
        // Set up Http::fake with 503 responses (no beforeEach interference)
        Http::fake([
            '*/api/project.all' => Http::response(['error' => 'Service unavailable'], 503),
        ]);

        // Create fresh client
        $client = new DokployApiClient(
            baseUrl: 'https://dok.aglz.io',
            apiKey: 'test-api-key'
        );

        // Trigger circuit breaker by calling API 5 times (threshold)
        for ($i = 0; $i < 5; $i++) {
            $response = $client->getProjects();
            // Each 503 response should register as failure
            expect($response->getStatusCode())->toBe(503);
        }

        // Verify circuit breaker is now open
        $breakerStatus = $client->getCircuitBreakerStatus();
        expect($breakerStatus['failures'])->toBeGreaterThanOrEqual(5);
        expect($breakerStatus['is_open'])->toBeTrue();

        // Next call should return circuit breaker response
        $response = $client->getProjects();
        expect($response->isSuccess())->toBeFalse();
        expect($response->getError())->toContain('Circuit breaker');
    });
});

describe('DokployApplicationController', function () {
    beforeEach(function () {
        // Mock Dokploy API for controller tests
        Http::fake([
            '*/api/project.all' => Http::response([
                ['projectId' => 'proj-1', 'name' => 'Test Project'],
            ], 200),
            '*/api/application.all' => Http::response([
                ['applicationId' => 'app-1', 'name' => 'Test App'],
            ], 200),
            '*/api/application.one*' => Http::response([
                'applicationId' => 'app-1',
                'name' => 'Test App',
            ], 200),
            '*/api/application.create' => Http::response([
                'applicationId' => 'app-2',
                'name' => 'New App',
            ], 201),
            '*/api/application.start' => Http::response(['success' => true], 200),
            '*/api/application.stop' => Http::response(['success' => true], 200),
            '*/api/application.redeploy' => Http::response(['success' => true], 200),
            '*/api/application.delete' => Http::response(['success' => true], 200),
        ]);
    });

    it('can list all applications', function () {
        $response = $this->actingAs($this->user, 'sanctum')
            ->getJson('/api/dokploy/applications');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
            ])
            ->assertJsonStructure([
                'success',
                'data',
            ]);
    });

    it('can get single application', function () {
        $response = $this->actingAs($this->user, 'sanctum')
            ->getJson('/api/dokploy/applications/app-1');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
            ]);
    });

    it('can create new application', function () {
        $data = [
            'name' => 'New App',
            'appName' => 'new-app',
            'projectId' => 'proj-1',
            'sourceType' => 'docker',
            'dockerImage' => 'nginx:latest',
        ];

        $response = $this->actingAs($this->user, 'sanctum')
            ->postJson('/api/dokploy/applications', $data);

        $response->assertStatus(201)
            ->assertJson([
                'success' => true,
                'message' => 'Application created successfully',
            ]);
    });

    it('validates required fields when creating application', function () {
        $response = $this->actingAs($this->user, 'sanctum')
            ->postJson('/api/dokploy/applications', []);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['name', 'appName', 'projectId']);
    });

    it('can start application', function () {
        $response = $this->actingAs($this->user, 'sanctum')
            ->postJson('/api/dokploy/applications/app-1/start');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'message' => 'Application started successfully',
            ]);
    });

    it('can stop application', function () {
        $response = $this->actingAs($this->user, 'sanctum')
            ->postJson('/api/dokploy/applications/app-1/stop');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'message' => 'Application stopped successfully',
            ]);
    });

    it('can redeploy application', function () {
        $response = $this->actingAs($this->user, 'sanctum')
            ->postJson('/api/dokploy/applications/app-1/redeploy');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'message' => 'Application redeployment triggered',
            ]);
    });

    it('can delete application', function () {
        $response = $this->actingAs($this->user, 'sanctum')
            ->deleteJson('/api/dokploy/applications/app-1');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'message' => 'Application deleted successfully',
            ]);
    });

    it('can fetch projects', function () {
        $response = $this->actingAs($this->user, 'sanctum')
            ->getJson('/api/dokploy/projects');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
            ]);
    });

    it('can test Dokploy connection', function () {
        $response = $this->actingAs($this->user, 'sanctum')
            ->getJson('/api/dokploy/test-connection');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'connected' => true,
                'message' => 'Dokploy API is accessible',
            ]);
    });

    it('requires authentication', function () {
        $response = $this->getJson('/api/dokploy/applications');

        $response->assertStatus(401);
    });
});

describe('DokployWebhookController', function () {
    it('handles Harbor push webhook', function () {
        // Mock Dokploy API for this specific test
        Http::fake([
            '*/api/application.all' => Http::response([
                [
                    'applicationId' => 'app-1',
                    'name' => 'Test App',
                    'dockerImage' => 'harbor.aglz.io:5000/agl/test-app:latest',
                ],
            ], 200),
            '*/api/application.redeploy' => Http::response(['success' => true], 200),
        ]);
        $payload = [
            'type' => 'PUSH_ARTIFACT',
            'event_data' => [
                'repository' => [
                    'name' => 'test-app',
                    'repo_full_name' => 'agl/test-app',
                    'repo_type' => 'private',
                ],
                'resources' => [
                    [
                        'tag' => 'latest',
                        'resource_url' => 'harbor.aglz.io:5000/agl/test-app:latest',
                    ],
                ],
            ],
        ];

        $response = $this->postJson('/api/dokploy/webhooks/harbor', $payload);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'message' => 'Redeployment triggered successfully',
            ]);
    });

    it('ignores non-push events', function () {
        $payload = [
            'type' => 'DELETE_ARTIFACT',
            'event_data' => [
                'repository' => [
                    'name' => 'test-app',
                    'repo_full_name' => 'agl/test-app',
                ],
                'resources' => [
                    ['tag' => 'latest'],
                ],
            ],
        ];

        $response = $this->postJson('/api/dokploy/webhooks/harbor', $payload);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'message' => 'Ignored event type: DELETE_ARTIFACT',
            ]);
    });

    it('handles no matching application gracefully', function () {
        Http::fake([
            '*/api/application.all' => Http::response([
                [
                    'applicationId' => 'app-1',
                    'name' => 'Different App',
                    'dockerImage' => 'nginx:latest',
                ],
            ], 200),
        ]);

        $payload = [
            'type' => 'PUSH_ARTIFACT',
            'event_data' => [
                'repository' => [
                    'name' => 'test-app',
                    'repo_full_name' => 'agl/test-app',
                ],
                'resources' => [['tag' => 'latest']],
            ],
        ];

        $response = $this->postJson('/api/dokploy/webhooks/harbor', $payload);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'message' => 'No Dokploy application found for image: test-app',
            ]);
    });

    it('validates webhook payload', function () {
        $response = $this->postJson('/api/dokploy/webhooks/harbor', [
            'type' => 'PUSH_ARTIFACT',
            // Missing required event_data
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['event_data']);
    });

    it('can test webhook with manual trigger', function () {
        // Mock Dokploy API for test webhook
        Http::fake([
            '*/api/application.all' => Http::response([
                [
                    'applicationId' => 'app-1',
                    'name' => 'Test App',
                    'dockerImage' => 'harbor.aglz.io:5000/agl/test-app:latest',
                ],
            ], 200),
            '*/api/application.redeploy' => Http::response(['success' => true], 200),
        ]);

        $response = $this->actingAs($this->user, 'sanctum')
            ->postJson('/api/dokploy/webhooks/harbor/test', [
                'repository' => 'test-app',
                'tag' => 'latest',
            ]);

        $response->assertStatus(200);
    });
});
