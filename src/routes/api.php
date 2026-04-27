<?php

use App\Http\Controllers\Api\DailyMemoryApiController;
use App\Http\Controllers\Auth\WorkOSController;
use App\Http\Controllers\N8NController;
use App\Http\Controllers\WebhookController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::get('/user', function (Request $request) {
    return $request->user();
})->middleware('auth:sanctum');

// Daily Memory API (for OpenClaw integration)
Route::prefix('daily-memory')->group(function () {
    // Public endpoints with API key auth
    Route::middleware('api.key')->group(function () {
        Route::get('/', [DailyMemoryApiController::class, 'index'])->name('api.daily-memory.index');
        Route::post('/', [DailyMemoryApiController::class, 'store'])->name('api.daily-memory.store');
        Route::get('/search', [DailyMemoryApiController::class, 'search'])->name('api.daily-memory.search');
        Route::get('/stats', [DailyMemoryApiController::class, 'stats'])->name('api.daily-memory.stats');
        Route::get('/{id}', [DailyMemoryApiController::class, 'show'])->name('api.daily-memory.show');
        Route::put('/{id}', [DailyMemoryApiController::class, 'update'])->name('api.daily-memory.update');
        Route::delete('/{id}', [DailyMemoryApiController::class, 'destroy'])->name('api.daily-memory.destroy');
    });
});

require __DIR__.'/api/openclaw.php';

// N8N Integration routes
Route::prefix('n8n')->group(function () {
    // Public webhook endpoint (no auth required - secured by webhook secret)
    Route::post('/webhook/{workflow}', [App\Http\Controllers\Api\N8NController::class, 'webhook'])->name('n8n.webhook');

    // Authenticated endpoints
    Route::middleware('auth:sanctum')->group(function () {
        // Legacy endpoints (backward compatibility)
        Route::post('/execute', [N8NController::class, 'executeWorkflow'])->name('n8n.execute');
        Route::post('/monitoring', [N8NController::class, 'triggerMonitoring'])->name('n8n.monitoring');
        Route::post('/ai', [N8NController::class, 'triggerAI'])->name('n8n.ai');
        Route::post('/deployment', [N8NController::class, 'triggerDeployment'])->name('n8n.deployment');

        // New comprehensive API endpoints
        Route::prefix('workflows')->group(function () {
            Route::get('/', [App\Http\Controllers\Api\N8NController::class, 'listWorkflows'])->name('n8n.workflows.list');
            Route::post('/', [App\Http\Controllers\Api\N8NController::class, 'createWorkflow'])->name('n8n.workflows.create');
            Route::get('/statistics', [App\Http\Controllers\Api\N8NController::class, 'statistics'])->name('n8n.workflows.statistics');

            Route::prefix('{workflow}')->group(function () {
                Route::get('/', [App\Http\Controllers\Api\N8NController::class, 'showWorkflow'])->name('n8n.workflows.show');
                Route::put('/', [App\Http\Controllers\Api\N8NController::class, 'updateWorkflow'])->name('n8n.workflows.update');
                Route::delete('/', [App\Http\Controllers\Api\N8NController::class, 'deleteWorkflow'])->name('n8n.workflows.delete');
                Route::post('/activate', [App\Http\Controllers\Api\N8NController::class, 'activateWorkflow'])->name('n8n.workflows.activate');
                Route::post('/deactivate', [App\Http\Controllers\Api\N8NController::class, 'deactivateWorkflow'])->name('n8n.workflows.deactivate');
                Route::get('/executions', [App\Http\Controllers\Api\N8NController::class, 'executions'])->name('n8n.workflows.executions');
            });
        });

        // Trigger workflows
        Route::post('/trigger/{workflow}', [App\Http\Controllers\Api\N8NController::class, 'trigger'])->name('n8n.trigger');

        // Sync and diagnostics
        Route::post('/sync', [App\Http\Controllers\Api\N8NController::class, 'sync'])->name('n8n.sync');
        Route::get('/test-connection', [App\Http\Controllers\Api\N8NController::class, 'testConnection'])->name('n8n.test');
        Route::get('/status/{executionId}', [App\Http\Controllers\Api\N8NController::class, 'getStatus'])->name('n8n.status');
    });
});

// Infrastructure Management routes
Route::middleware(['auth:sanctum'])->prefix('infrastructure')->group(function () {
    Route::get('/locations', function () {
        return \App\Models\PhysicalLocation::all();
    });

    Route::get('/servers/{code}', function ($code) {
        return \App\Models\PhysicalLocation::where('code', $code)->firstOrFail();
    });
});

// AI Model routes
Route::middleware(['auth:sanctum'])->prefix('ai')->group(function () {
    Route::post('/query', [App\Http\Controllers\AIController::class, 'query'])->name('ai.query');
    Route::post('/multi-agent', [App\Http\Controllers\AIController::class, 'multiAgent'])->name('ai.multi-agent');
    Route::get('/models', [App\Http\Controllers\AIController::class, 'models'])->name('ai.models');
    Route::post('/select-model', [App\Http\Controllers\AIController::class, 'selectModel'])->name('ai.select-model');
    Route::post('/analyze-infrastructure', [App\Http\Controllers\AIController::class, 'analyzeInfrastructure'])->name('ai.analyze-infrastructure');
    Route::post('/review-code', [App\Http\Controllers\AIController::class, 'reviewCode'])->name('ai.review-code');
});

// AI Service Integration routes (New AIService - OpenAI, Claude, Ollama)
Route::middleware(['auth:sanctum'])->prefix('ai-service')->group(function () {
    Route::post('/predict', [App\Http\Controllers\Api\AIController::class, 'predict'])->name('ai-service.predict');
    Route::post('/analyze', [App\Http\Controllers\Api\AIController::class, 'analyze'])->name('ai-service.analyze');
    Route::post('/chat', [App\Http\Controllers\Api\AIController::class, 'chat'])->name('ai-service.chat');
    Route::get('/models', [App\Http\Controllers\Api\AIController::class, 'models'])->name('ai-service.models');
    Route::get('/usage', [App\Http\Controllers\Api\AIController::class, 'usage'])->name('ai-service.usage');
});

// Scrum Board routes
Route::middleware(['auth:sanctum'])->prefix('scrum')->group(function () {
    // Sprints
    Route::get('/sprints', [App\Http\Controllers\Api\ScrumController::class, 'listSprints'])->name('scrum.sprints.list');
    Route::post('/sprints', [App\Http\Controllers\Api\ScrumController::class, 'createSprint'])->name('scrum.sprints.create');
    Route::get('/sprints/{id}/backlog', [App\Http\Controllers\Api\ScrumController::class, 'getSprintBacklog'])->name('scrum.sprints.backlog');
    Route::post('/sprints/{id}/start', [App\Http\Controllers\Api\ScrumController::class, 'startSprint'])->name('scrum.sprints.start');
    Route::post('/sprints/{id}/complete', [App\Http\Controllers\Api\ScrumController::class, 'completeSprint'])->name('scrum.sprints.complete');

    // Tasks
    Route::get('/tasks', [App\Http\Controllers\Api\ScrumController::class, 'listTasks'])->name('scrum.tasks.list');
    Route::post('/tasks', [App\Http\Controllers\Api\ScrumController::class, 'createTask'])->name('scrum.tasks.create');
    Route::put('/tasks/{id}', [App\Http\Controllers\Api\ScrumController::class, 'updateTask'])->name('scrum.tasks.update');
    Route::delete('/tasks/{id}', [App\Http\Controllers\Api\ScrumController::class, 'deleteTask'])->name('scrum.tasks.delete');
    Route::post('/tasks/{id}/move', [App\Http\Controllers\Api\ScrumController::class, 'moveTask'])->name('scrum.tasks.move');

    // Stories
    Route::get('/stories', [App\Http\Controllers\Api\ScrumController::class, 'listStories'])->name('scrum.stories.list');
    Route::post('/stories', [App\Http\Controllers\Api\ScrumController::class, 'createStory'])->name('scrum.stories.create');
    Route::put('/stories/{id}', [App\Http\Controllers\Api\ScrumController::class, 'updateStory'])->name('scrum.stories.update');
    Route::delete('/stories/{id}', [App\Http\Controllers\Api\ScrumController::class, 'deleteStory'])->name('scrum.stories.delete');

    // Bugs
    Route::get('/bugs', [App\Http\Controllers\Api\ScrumController::class, 'listBugs'])->name('scrum.bugs.list');
    Route::post('/bugs', [App\Http\Controllers\Api\ScrumController::class, 'createBug'])->name('scrum.bugs.create');
    Route::put('/bugs/{id}', [App\Http\Controllers\Api\ScrumController::class, 'updateBug'])->name('scrum.bugs.update');

    // Sprint Members
    Route::get('/sprints/{sprintId}/members', [App\Http\Controllers\Api\ScrumController::class, 'getSprintMembers'])->name('scrum.sprints.members');
    Route::post('/sprints/{sprintId}/members', [App\Http\Controllers\Api\ScrumController::class, 'addSprintMember'])->name('scrum.sprints.members.add');
    Route::delete('/sprints/{sprintId}/members/{userId}', [App\Http\Controllers\Api\ScrumController::class, 'removeSprintMember'])->name('scrum.sprints.members.remove');

    // Metrics & Reports
    Route::get('/burndown', [App\Http\Controllers\Api\ScrumController::class, 'getBurndown'])->name('scrum.burndown');
    Route::get('/velocity', [App\Http\Controllers\Api\ScrumController::class, 'getVelocity'])->name('scrum.velocity');
    Route::get('/epics', [App\Http\Controllers\Api\ScrumController::class, 'listEpics'])->name('scrum.epics');

    // Kanban Board
    Route::get('/kanban', [App\Http\Controllers\Api\ScrumController::class, 'getKanban'])->name('scrum.kanban');
});

// Infrastructure Analytics Routes
Route::prefix('infrastructure')->middleware('auth:sanctum')->group(function () {
    Route::get('/status', [App\Http\Controllers\Api\InfrastructureAnalyticsController::class, 'status']);
    Route::get('/analytics', [App\Http\Controllers\Api\InfrastructureAnalyticsController::class, 'analytics']);
    Route::get('/server/{serverCode}', [App\Http\Controllers\Api\InfrastructureAnalyticsController::class, 'serverMetrics']);
    Route::post('/monitor', [App\Http\Controllers\Api\InfrastructureAnalyticsController::class, 'triggerMonitoring']);
    Route::get('/history', [App\Http\Controllers\Api\InfrastructureAnalyticsController::class, 'history']);
    Route::get('/predictions', [App\Http\Controllers\Api\InfrastructureAnalyticsController::class, 'predictions']);
    Route::get('/optimizations', [App\Http\Controllers\Api\InfrastructureAnalyticsController::class, 'optimizations']);
});

// Container Lifecycle Management Routes
Route::prefix('containers')->middleware('auth:sanctum')->group(function () {
    // Create and restore operations
    Route::post('/create', [App\Http\Controllers\Api\Container\ContainerLifecycleController::class, 'create']);
    Route::post('/restore', [App\Http\Controllers\Api\Container\ContainerLifecycleController::class, 'restore']);

    // Container-specific operations
    Route::post('/{vmid}/clone', [App\Http\Controllers\Api\Container\ContainerLifecycleController::class, 'clone']);
    Route::post('/{vmid}/migrate', [App\Http\Controllers\Api\Container\ContainerLifecycleController::class, 'migrate']);
    Route::post('/{vmid}/backup', [App\Http\Controllers\Api\Container\ContainerLifecycleController::class, 'backup']);
    Route::post('/{vmid}/snapshot', [App\Http\Controllers\Api\Container\ContainerLifecycleController::class, 'snapshot']);
    Route::post('/{vmid}/rollback', [App\Http\Controllers\Api\Container\ContainerLifecycleController::class, 'rollback']);

    // List operations
    Route::get('/{vmid}/snapshots', [App\Http\Controllers\Api\Container\ContainerLifecycleController::class, 'listSnapshots']);
    Route::get('/backups', [App\Http\Controllers\Api\Container\ContainerLifecycleController::class, 'listBackups']);
});

// Backup Routes
Route::prefix('backup')->middleware('auth:sanctum')->group(function () {
    Route::get('/list', [App\Http\Controllers\Api\BackupController::class, 'list']);
    Route::post('/create', [App\Http\Controllers\Api\BackupController::class, 'create']);
    Route::post('/restore/{id}', [App\Http\Controllers\Api\BackupController::class, 'restore']);
    Route::delete('/{id}', [App\Http\Controllers\Api\BackupController::class, 'delete']);
    Route::get('/download/{id}', [App\Http\Controllers\Api\BackupController::class, 'download']);
});

// Harbor Integration Routes
Route::prefix('harbor')->middleware('auth:sanctum')->group(function () {
    // Projects
    Route::get('/projects', [App\Http\Controllers\Api\HarborController::class, 'projects']);
    Route::post('/projects', [App\Http\Controllers\Api\HarborController::class, 'createProject']);
    Route::get('/projects/{project}', [App\Http\Controllers\Api\HarborController::class, 'getProject']);
    Route::put('/projects/{project}', [App\Http\Controllers\Api\HarborController::class, 'updateProject']);
    Route::delete('/projects/{project}', [App\Http\Controllers\Api\HarborController::class, 'deleteProject']);

    // Repositories
    Route::get('/repositories', [App\Http\Controllers\Api\HarborController::class, 'repositories']);
    Route::get('/repositories/{project}/{repository}', [App\Http\Controllers\Api\HarborController::class, 'getRepository']);
    Route::delete('/repositories/{project}/{repository}', [App\Http\Controllers\Api\HarborController::class, 'deleteRepository']);

    // Artifacts
    Route::get('/artifacts', [App\Http\Controllers\Api\HarborController::class, 'artifacts']);
    Route::get('/artifacts/{project}/{repository}/{reference}', [App\Http\Controllers\Api\HarborController::class, 'getArtifact']);
    Route::delete('/artifacts/{project}/{repository}/{reference}', [App\Http\Controllers\Api\HarborController::class, 'deleteArtifact']);
    Route::post('/artifacts/copy', [App\Http\Controllers\Api\HarborController::class, 'copyArtifact']);

    // Vulnerability Scanning
    Route::get('/vulnerabilities/{project}/{repository}/{reference}', [App\Http\Controllers\Api\HarborController::class, 'vulnerabilities']);
    Route::post('/scan', [App\Http\Controllers\Api\HarborController::class, 'triggerScan']);

    // Retention Policies
    Route::get('/retention/{projectId}', [App\Http\Controllers\Api\HarborController::class, 'retentionPolicies']);
    Route::post('/retention/{projectId}', [App\Http\Controllers\Api\HarborController::class, 'createRetentionPolicy']);

    // Webhooks
    Route::get('/webhooks/{projectId}', [App\Http\Controllers\Api\HarborController::class, 'webhooks']);
    Route::post('/webhooks/{projectId}', [App\Http\Controllers\Api\HarborController::class, 'createWebhook']);
    Route::delete('/webhooks/{projectId}/{webhookId}', [App\Http\Controllers\Api\HarborController::class, 'deleteWebhook']);

    // System & Health
    Route::get('/system/info', [App\Http\Controllers\Api\HarborController::class, 'systemInfo']);
    Route::get('/system/health', [App\Http\Controllers\Api\HarborController::class, 'health']);
    Route::get('/credentials', [App\Http\Controllers\Api\HarborController::class, 'credentials']);
    Route::get('/test', [App\Http\Controllers\Api\HarborController::class, 'testConnection']);
});

// Dokploy Integration Routes
Route::prefix('dokploy')->group(function () {
    // Public webhook endpoint (no auth - Harbor webhooks)
    Route::post('/webhooks/harbor', [App\Http\Controllers\Api\Dokploy\DokployWebhookController::class, 'harborPush']);

    // Authenticated endpoints
    Route::middleware('auth:sanctum')->group(function () {
        // Application management
        Route::get('/applications', [App\Http\Controllers\Api\Dokploy\DokployApplicationController::class, 'index']);
        Route::get('/applications/{applicationId}', [App\Http\Controllers\Api\Dokploy\DokployApplicationController::class, 'show']);
        Route::post('/applications', [App\Http\Controllers\Api\Dokploy\DokployApplicationController::class, 'store']);
        Route::post('/applications/{applicationId}/start', [App\Http\Controllers\Api\Dokploy\DokployApplicationController::class, 'start']);
        Route::post('/applications/{applicationId}/stop', [App\Http\Controllers\Api\Dokploy\DokployApplicationController::class, 'stop']);
        Route::post('/applications/{applicationId}/redeploy', [App\Http\Controllers\Api\Dokploy\DokployApplicationController::class, 'redeploy']);
        Route::delete('/applications/{applicationId}', [App\Http\Controllers\Api\Dokploy\DokployApplicationController::class, 'destroy']);

        // Service management (new unified controller)
        Route::get('/services', [App\Http\Controllers\Api\DokployController::class, 'services']);
        Route::post('/services/{id}/start', [App\Http\Controllers\Api\DokployController::class, 'startService']);
        Route::post('/services/{id}/stop', [App\Http\Controllers\Api\DokployController::class, 'stopService']);
        Route::post('/services/{id}/restart', [App\Http\Controllers\Api\DokployController::class, 'restartService']);

        // Deployment management
        Route::post('/deploy', [App\Http\Controllers\Api\DokployController::class, 'deploy']);
        Route::post('/redeploy', [App\Http\Controllers\Api\DokployController::class, 'redeploy']);
        Route::get('/deployments', [App\Http\Controllers\Api\DokployController::class, 'deployments']);
        Route::get('/deployments/{applicationId}/status', [App\Http\Controllers\Api\DokployController::class, 'deploymentStatus']);
        Route::post('/deployments/{applicationId}/cancel', [App\Http\Controllers\Api\DokployController::class, 'cancelDeployment']);

        // Domain management
        Route::get('/domains', [App\Http\Controllers\Api\DokployController::class, 'domains']);
        Route::post('/domains', [App\Http\Controllers\Api\DokployController::class, 'addDomain']);
        Route::delete('/domains/{domainId}', [App\Http\Controllers\Api\DokployController::class, 'removeDomain']);

        // Environment management
        Route::get('/environment', [App\Http\Controllers\Api\DokployController::class, 'environment']);
        Route::post('/environment', [App\Http\Controllers\Api\DokployController::class, 'setEnvironment']);

        // Logs
        Route::get('/logs', [App\Http\Controllers\Api\DokployController::class, 'logs']);

        // Project management
        Route::get('/projects', [App\Http\Controllers\Api\Dokploy\DokployApplicationController::class, 'projects']);
        Route::post('/projects', [App\Http\Controllers\Api\DokployController::class, 'createProject']);

        // Testing & diagnostics
        Route::get('/test-connection', [App\Http\Controllers\Api\Dokploy\DokployApplicationController::class, 'testConnection']);
        Route::get('/health', [App\Http\Controllers\Api\DokployController::class, 'health']);
        Route::post('/webhooks/harbor/test', [App\Http\Controllers\Api\Dokploy\DokployWebhookController::class, 'testHarborWebhook']);
    });
});

// Alert Center Routes (Phase 3)
Route::prefix('alerts')->middleware('auth:sanctum')->group(function () {
    // Alert management
    Route::get('/active', [App\Http\Controllers\AlertController::class, 'getActive']);
    Route::get('/history', [App\Http\Controllers\AlertController::class, 'getHistory']);
    Route::get('/stats', [App\Http\Controllers\AlertController::class, 'stats']);
    Route::post('/{id}/acknowledge', [App\Http\Controllers\AlertController::class, 'acknowledge']);
    Route::post('/{id}/resolve', [App\Http\Controllers\AlertController::class, 'resolve']);
    Route::post('/{id}/mute', [App\Http\Controllers\AlertController::class, 'mute']);
    Route::post('/bulk/acknowledge', [App\Http\Controllers\AlertController::class, 'bulkAcknowledge']);
    Route::post('/bulk/resolve', [App\Http\Controllers\AlertController::class, 'bulkResolve']);
});

// Alert Rules Routes (Phase 3)
Route::prefix('alert-rules')->middleware('auth:sanctum')->group(function () {
    Route::get('/', [App\Http\Controllers\AlertRuleController::class, 'index']);
    Route::post('/', [App\Http\Controllers\AlertRuleController::class, 'store']);
    Route::get('/{id}', [App\Http\Controllers\AlertRuleController::class, 'show']);
    Route::put('/{id}', [App\Http\Controllers\AlertRuleController::class, 'update']);
    Route::delete('/{id}', [App\Http\Controllers\AlertRuleController::class, 'destroy']);
    Route::post('/{id}/toggle', [App\Http\Controllers\AlertRuleController::class, 'toggle']);
    Route::post('/{id}/test', [App\Http\Controllers\AlertRuleController::class, 'test']);
});

// Network Topology Routes (Phase 3)
Route::prefix('network')->middleware('auth:sanctum')->group(function () {
    Route::get('/graph', [App\Http\Controllers\NetworkTopologyController::class, 'getGraph']);
    Route::get('/nodes/{nodeId}', [App\Http\Controllers\NetworkTopologyController::class, 'getNodeDetails']);
    Route::get('/connections/{sourceId}/{targetId}', [App\Http\Controllers\NetworkTopologyController::class, 'getConnectionDetails']);
    Route::get('/health', [App\Http\Controllers\NetworkTopologyController::class, 'getNetworkHealth']);
    Route::get('/issues', [App\Http\Controllers\NetworkTopologyController::class, 'detectIssues']);
    Route::post('/path', [App\Http\Controllers\NetworkTopologyController::class, 'calculatePath']);
    Route::get('/wireguard/peers', [App\Http\Controllers\NetworkTopologyController::class, 'getWireGuardPeers']);
});

// ========== Webhook Routes (Phase 3.1) ==========
Route::prefix('webhooks')->group(function () {
    // GitHub webhook
    Route::post('/github', [WebhookController::class, 'handleGitHubPush'])
        ->name('webhooks.github')
        ->middleware('throttle:10,1'); // Max 10 requests per minute

    // Harbor webhook
    Route::post('/harbor', [WebhookController::class, 'handleHarborPush'])
        ->name('webhooks.harbor')
        ->middleware('throttle:10,1');

    // Dokploy webhook
    Route::post('/dokploy', [WebhookController::class, 'handleDokployStatus'])
        ->name('webhooks.dokploy')
        ->middleware('throttle:10,1');
});

// ========== Deployment API Routes (Phase 3.1 & 3.2) ==========
Route::prefix('deployment')->middleware(['auth:sanctum'])->group(function () {
    // QA Environment
    Route::prefix('qa')->group(function () {
        Route::post('/deploy', function () {
            $workflowService = app(\App\Services\Deployment\DeploymentWorkflowService::class);
            $deployment = $workflowService->deployToQA([
                'triggered_by' => 'manual_api',
            ]);

            return response()->json([
                'success' => true,
                'deployment_id' => $deployment->id,
                'status' => $deployment->status,
            ]);
        })->name('deployment.qa.deploy');

        Route::post('/rollback', function () {
            $environment = \App\Models\Environment::where('type', 'qa')->firstOrFail();
            $success = $environment->rollback();

            return response()->json([
                'success' => $success,
                'message' => $success ? 'Rollback initiated' : 'Rollback failed',
            ]);
        })->name('deployment.qa.rollback');

        Route::get('/status', function () {
            $environment = \App\Models\Environment::where('type', 'qa')->firstOrFail();

            return response()->json([
                'success' => true,
                'environment' => [
                    'id' => $environment->id,
                    'name' => $environment->name,
                    'type' => $environment->type,
                    'status' => $environment->status,
                    'last_deployed_at' => $environment->last_deployed_at?->toIso8601String(),
                    'deployment_status' => $environment->getStatus(),
                    'domains' => $environment->domains,
                ],
            ]);
        })->name('deployment.qa.status');

        Route::get('/logs', function () {
            $environment = \App\Models\Environment::where('type', 'qa')->firstOrFail();
            $deployment = $environment->deployments()->latest()->first();

            if (! $deployment) {
                return response()->json([
                    'success' => false,
                    'message' => 'No deployments found',
                ], 404);
            }

            $dokployService = app(\App\Services\DokployService::class);
            $logs = $dokployService->getDeploymentLogs($deployment->dokploy_application_id, 100);

            return response()->json([
                'success' => true,
                'deployment_id' => $deployment->id,
                'logs' => $logs->toArray(),
            ]);
        })->name('deployment.qa.logs');
    });

    // UAT Environment (Phase 3.2)
    Route::prefix('uat')->group(function () {
        Route::post('/deploy', [App\Http\Controllers\DeploymentController::class, 'deployToUAT'])
            ->name('deployment.uat.deploy');

        Route::post('/rollback', function () {
            $workflowService = app(\App\Services\Deployment\DeploymentWorkflowService::class);

            $environment = \App\Models\Environment::where('type', 'uat')->firstOrFail();
            $latestDeployment = $environment->deployments()->latest()->first();

            if (! $latestDeployment) {
                return response()->json([
                    'success' => false,
                    'message' => 'No deployments found to rollback',
                ], 404);
            }

            $result = $workflowService->rollbackUAT($latestDeployment->id);

            return response()->json($result);
        })->name('deployment.uat.rollback');

        Route::get('/status', [App\Http\Controllers\DeploymentController::class, 'getUATStatus'])
            ->name('deployment.uat.status');

        Route::get('/logs', function () {
            $environment = \App\Models\Environment::where('type', 'uat')->firstOrFail();
            $deployment = $environment->deployments()->latest()->first();

            if (! $deployment) {
                return response()->json([
                    'success' => false,
                    'message' => 'No deployments found',
                ], 404);
            }

            $dokployService = app(\App\Services\DokployService::class);
            $logs = $dokployService->getDeploymentLogs($deployment->dokploy_application_id, 100);

            return response()->json([
                'success' => true,
                'deployment_id' => $deployment->id,
                'logs' => $logs->toArray(),
            ]);
        })->name('deployment.uat.logs');
    });
});

// ========== Promotion API Routes (Phase 3.2) ==========
Route::prefix('promotion')->middleware('auth:sanctum')->group(function () {
    // Promotion workflow
    Route::post('/qa-to-uat', [App\Http\Controllers\PromotionController::class, 'promoteQAtoUAT'])
        ->name('promotion.qa-to-uat');

    Route::post('/{promotionId}/approve', [App\Http\Controllers\PromotionController::class, 'approveUATPromotion'])
        ->name('promotion.approve');

    Route::get('/{promotionId}/status', [App\Http\Controllers\PromotionController::class, 'getPromotionStatus'])
        ->name('promotion.status');

    Route::post('/{promotionId}/rollback', [App\Http\Controllers\PromotionController::class, 'rollbackPromotion'])
        ->name('promotion.rollback');

    // List promotions
    Route::get('/pending', function () {
        $promotions = \App\Models\Promotion::pending()
            ->with(['sourceEnvironment', 'targetEnvironment', 'requester'])
            ->latest('requested_at')
            ->get();

        return response()->json([
            'success' => true,
            'data' => $promotions,
        ]);
    })->name('promotion.pending');

    Route::get('/history', function () {
        $promotions = \App\Models\Promotion::with(['sourceEnvironment', 'targetEnvironment', 'requester', 'approver'])
            ->latest('requested_at')
            ->paginate(20);

        return response()->json([
            'success' => true,
            'data' => $promotions,
        ]);
    })->name('promotion.history');
});

// Promotion workflow routes
Route::prefix('promotion')->middleware('auth:sanctum')->group(function () {
    // Pipeline overview
    Route::get('/pipeline', [App\Http\Controllers\PromotionDashboardController::class, 'getPromotionPipeline']);
    Route::get('/metrics', [App\Http\Controllers\PromotionDashboardController::class, 'getPromotionMetrics']);
    Route::get('/active', [App\Http\Controllers\PromotionDashboardController::class, 'getActivePromotions']);
    Route::get('/history', [App\Http\Controllers\PromotionDashboardController::class, 'getPromotionHistory']);

    // Promotion actions
    Route::post('/qa-to-uat', [App\Http\Controllers\PromotionController::class, 'promoteQAtoUAT']);
    Route::post('/uat-to-production', [App\Http\Controllers\PromotionController::class, 'promoteUATtoProduction']);

    // Approval workflow
    Route::post('/{id}/approve', [App\Http\Controllers\PromotionController::class, 'approvePromotion'])
        ->middleware('role:admin,lead-developer|any');
    Route::post('/{id}/reject', [App\Http\Controllers\PromotionController::class, 'rejectPromotion'])
        ->middleware('role:admin,lead-developer|any');
    Route::get('/{id}/approvals', [App\Http\Controllers\PromotionController::class, 'getApprovalStatus']);
    Route::get('/pending-approvals', [App\Http\Controllers\PromotionController::class, 'getPendingApprovals']);

    // Rollback
    Route::post('/{id}/rollback', [App\Http\Controllers\PromotionController::class, 'rollbackPromotion']);
});

// GitHub webhook routes
Route::prefix('webhooks/github')->group(function () {
    Route::post('/push', [App\Http\Controllers\GitHubWebhookController::class, 'handlePush']);
    Route::post('/workflow-run', [App\Http\Controllers\GitHubWebhookController::class, 'handleWorkflowRun']);
});

// ========== Build Metrics API Routes (Phase 4.1) ==========
Route::prefix('build')->group(function () {
    // Public webhook endpoint for CI/CD to record metrics (no auth - secured by URL pattern)
    Route::post('/metrics/record', [App\Http\Controllers\BuildMetricsController::class, 'recordMetrics'])
        ->name('build.metrics.record')
        ->middleware('throttle:60,1'); // Max 60 requests per minute

    // Authenticated endpoints for viewing metrics
    Route::middleware('auth:sanctum')->group(function () {
        Route::get('/metrics/latest', [App\Http\Controllers\BuildMetricsController::class, 'getLatestMetrics'])
            ->name('build.metrics.latest');

        Route::get('/metrics/history', [App\Http\Controllers\BuildMetricsController::class, 'getBuildHistory'])
            ->name('build.metrics.history');

        Route::get('/metrics/trends', [App\Http\Controllers\BuildMetricsController::class, 'getBuildTrends'])
            ->name('build.metrics.trends');

        Route::get('/metrics/environment/{environment}', [App\Http\Controllers\BuildMetricsController::class, 'getEnvironmentMetrics'])
            ->name('build.metrics.environment');

        Route::get('/metrics/comparison', [App\Http\Controllers\BuildMetricsController::class, 'getComparison'])
            ->name('build.metrics.comparison');
    });
});

// ========== Smart Notifications API Routes (Phase 4.3) ==========
Route::prefix('notifications')->middleware('auth:sanctum')->group(function () {
    // Notification channels
    Route::apiResource('channels', App\Http\Controllers\NotificationChannelController::class);
    Route::post('channels/{channel}/test', [App\Http\Controllers\NotificationChannelController::class, 'test'])
        ->name('notifications.channels.test');
    Route::get('channels/{channel}/statistics', [App\Http\Controllers\NotificationChannelController::class, 'statistics'])
        ->name('notifications.channels.statistics');

    // Notification rules
    Route::apiResource('rules', App\Http\Controllers\NotificationRuleController::class);
    Route::post('rules/reorder', [App\Http\Controllers\NotificationRuleController::class, 'reorder'])
        ->name('notifications.rules.reorder');
    Route::post('rules/{rule}/test', [App\Http\Controllers\NotificationRuleController::class, 'test'])
        ->name('notifications.rules.test');

    // On-call schedules
    Route::get('on-call/current', [App\Http\Controllers\OnCallScheduleController::class, 'current'])
        ->name('notifications.on-call.current');
    Route::post('on-call/rotate', [App\Http\Controllers\OnCallScheduleController::class, 'rotate'])
        ->name('notifications.on-call.rotate');
    Route::get('on-call/history', [App\Http\Controllers\OnCallScheduleController::class, 'history'])
        ->name('notifications.on-call.history');
    Route::apiResource('on-call', App\Http\Controllers\OnCallScheduleController::class);
});

// Public webhook endpoints (no auth required)
Route::post('webhooks/slack', [App\Http\Controllers\NotificationWebhookController::class, 'slackInteraction'])
    ->name('webhooks.slack')
    ->middleware('throttle:60,1');

Route::post('webhooks/pagerduty', [App\Http\Controllers\NotificationWebhookController::class, 'pagerdutyWebhook'])
    ->name('webhooks.pagerduty')
    ->middleware('throttle:60,1');

Route::post('webhooks/deployment', [App\Http\Controllers\NotificationWebhookController::class, 'deploymentWebhook'])
    ->name('webhooks.deployment')
    ->middleware('throttle:60,1');

Route::post('webhooks/pr', [App\Http\Controllers\NotificationWebhookController::class, 'prWebhook'])
    ->name('webhooks.pr')
    ->middleware('throttle:60,1');

// ========== Monitoring API Routes ==========
Route::prefix('monitoring')->middleware('auth:sanctum')->group(function () {
    // Metrics endpoints
    Route::get('/metrics', [App\Http\Controllers\Api\MonitoringController::class, 'metrics'])
        ->name('monitoring.metrics');
    Route::get('/health', [App\Http\Controllers\Api\MonitoringController::class, 'health'])
        ->name('monitoring.health');
    Route::get('/trends', [App\Http\Controllers\Api\MonitoringController::class, 'trends'])
        ->name('monitoring.trends');
    Route::get('/stats', [App\Http\Controllers\Api\MonitoringController::class, 'stats'])
        ->name('monitoring.stats');
    Route::get('/server/{serverCode}', [App\Http\Controllers\Api\MonitoringController::class, 'serverMetrics'])
        ->name('monitoring.server');

    // Alert management
    Route::get('/alerts', [App\Http\Controllers\Api\MonitoringController::class, 'alerts'])
        ->name('monitoring.alerts');
    Route::post('/alerts/read', [App\Http\Controllers\Api\MonitoringController::class, 'markAlertsRead'])
        ->name('monitoring.alerts.read');
    Route::post('/alerts/{alertId}/resolve', [App\Http\Controllers\Api\MonitoringController::class, 'resolveAlert'])
        ->name('monitoring.alerts.resolve');

    // Collection management
    Route::post('/collect', [App\Http\Controllers\Api\MonitoringController::class, 'collect'])
        ->name('monitoring.collect');
    Route::post('/refresh', [App\Http\Controllers\Api\MonitoringController::class, 'refresh'])
        ->name('monitoring.refresh');
});

// ========== Agent OS v3 API Routes ==========
require __DIR__.'/agent-os.php';

// ========== RBAC API Routes ==========
Route::prefix('rbac')->middleware('auth:sanctum')->group(function () {
    // RBAC overview
    Route::get('/overview', [App\Http\Controllers\Api\Rbac\RbacController::class, 'overview'])
        ->middleware('permission:view-roles')
        ->name('rbac.overview');

    // Current user RBAC
    Route::get('/me', [App\Http\Controllers\Api\Rbac\RbacController::class, 'me'])
        ->name('rbac.me');

    // User RBAC summary (admin only)
    Route::get('/users/{user}', [App\Http\Controllers\Api\Rbac\RbacController::class, 'userSummary'])
        ->middleware('permission:view-users')
        ->name('rbac.user.summary');

    // Grant/revoke roles and permissions
    Route::post('/grant-role', [App\Http\Controllers\Api\Rbac\RbacController::class, 'grantRole'])
        ->middleware('permission:assign-roles')
        ->name('rbac.grant-role');

    Route::post('/revoke-role', [App\Http\Controllers\Api\Rbac\RbacController::class, 'revokeRole'])
        ->middleware('permission:assign-roles')
        ->name('rbac.revoke-role');

    Route::post('/grant-permission', [App\Http\Controllers\Api\Rbac\RbacController::class, 'grantPermission'])
        ->middleware('permission:assign-permissions')
        ->name('rbac.grant-permission');

    Route::post('/revoke-permission', [App\Http\Controllers\Api\Rbac\RbacController::class, 'revokePermission'])
        ->middleware('permission:assign-permissions')
        ->name('rbac.revoke-permission');

    // Get users by role/permission
    Route::get('/users/role/{role}', [App\Http\Controllers\Api\Rbac\RbacController::class, 'usersWithRole'])
        ->middleware('permission:view-users')
        ->name('rbac.users.role');

    Route::get('/users/permission/{permission}', [App\Http\Controllers\Api\Rbac\RbacController::class, 'usersWithPermission'])
        ->middleware('permission:view-users')
        ->name('rbac.users.permission');
});

// Roles API
Route::prefix('roles')->middleware('auth:sanctum')->group(function () {
    Route::get('/', [App\Http\Controllers\Api\Rbac\RoleController::class, 'index'])
        ->middleware('permission:view-roles')
        ->name('roles.index');

    Route::post('/', [App\Http\Controllers\Api\Rbac\RoleController::class, 'store'])
        ->middleware('permission:create-roles')
        ->name('roles.store');

    Route::get('/statistics', [App\Http\Controllers\Api\Rbac\RoleController::class, 'statistics'])
        ->middleware('permission:view-roles')
        ->name('roles.statistics');

    Route::prefix('{role}')->group(function () {
        Route::get('/', [App\Http\Controllers\Api\Rbac\RoleController::class, 'show'])
            ->middleware('permission:view-roles')
            ->name('roles.show');

        Route::put('/', [App\Http\Controllers\Api\Rbac\RoleController::class, 'update'])
            ->middleware('permission:edit-roles')
            ->name('roles.update');

        Route::delete('/', [App\Http\Controllers\Api\Rbac\RoleController::class, 'destroy'])
            ->middleware('permission:delete-roles')
            ->name('roles.destroy');

        Route::post('/assign', [App\Http\Controllers\Api\Rbac\RoleController::class, 'assignToUser'])
            ->middleware('permission:assign-roles')
            ->name('roles.assign');

        Route::delete('/revoke', [App\Http\Controllers\Api\Rbac\RoleController::class, 'revokeFromUser'])
            ->middleware('permission:assign-roles')
            ->name('roles.revoke');

        Route::post('/clone', [App\Http\Controllers\Api\Rbac\RoleController::class, 'clone'])
            ->middleware('permission:create-roles')
            ->name('roles.clone');
    });
});

// Permissions API
Route::prefix('permissions')->middleware('auth:sanctum')->group(function () {
    Route::get('/', [App\Http\Controllers\Api\Rbac\PermissionController::class, 'index'])
        ->middleware('permission:permissions.view')
        ->name('permissions.index');

    Route::get('/grouped', [App\Http\Controllers\Api\Rbac\PermissionController::class, 'grouped'])
        ->middleware('permission:permissions.view')
        ->name('permissions.grouped');

    Route::get('/modules', [App\Http\Controllers\Api\Rbac\PermissionController::class, 'modules'])
        ->middleware('permission:permissions.view')
        ->name('permissions.modules');

    Route::get('/statistics', [App\Http\Controllers\Api\Rbac\PermissionController::class, 'statistics'])
        ->middleware('permission:permissions.view')
        ->name('permissions.statistics');

    Route::post('/', [App\Http\Controllers\Api\Rbac\PermissionController::class, 'store'])
        ->middleware('permission:permissions.manage')
        ->name('permissions.store');

    Route::prefix('{permission}')->group(function () {
        Route::get('/', [App\Http\Controllers\Api\Rbac\PermissionController::class, 'show'])
            ->middleware('permission:permissions.view')
            ->name('permissions.show');

        Route::put('/', [App\Http\Controllers\Api\Rbac\PermissionController::class, 'update'])
            ->middleware('permission:permissions.manage')
            ->name('permissions.update');

        Route::delete('/', [App\Http\Controllers\Api\Rbac\PermissionController::class, 'destroy'])
            ->middleware('permission:permissions.manage')
            ->name('permissions.destroy');

        Route::post('/assign-role', [App\Http\Controllers\Api\Rbac\PermissionController::class, 'assignToRole'])
            ->middleware('permission:edit-roles')
            ->name('permissions.assign-role');

        Route::delete('/revoke-role', [App\Http\Controllers\Api\Rbac\PermissionController::class, 'revokeFromRole'])
            ->middleware('permission:edit-roles')
            ->name('permissions.revoke-role');

        Route::post('/assign-user', [App\Http\Controllers\Api\Rbac\PermissionController::class, 'assignToUser'])
            ->middleware('permission:assign-permissions')
            ->name('permissions.assign-user');
    });
});

