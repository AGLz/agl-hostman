<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Auth\WorkOSController;
use App\Http\Controllers\N8NController;
use App\Http\Controllers\WebhookController;

Route::get('/user', function (Request $request) {
    return $request->user();
})->middleware('auth:sanctum');

// WorkOS Authentication routes
Route::prefix('auth')->group(function () {
    Route::get('/workos/redirect', [WorkOSController::class, 'redirect'])->name('workos.redirect');
    Route::get('/workos/callback', [WorkOSController::class, 'callback'])->name('workos.callback');
    Route::post('/workos/logout', [WorkOSController::class, 'logout'])->name('workos.logout');
});

// N8N Integration routes  
Route::prefix('n8n')->group(function () {
    // Public webhook endpoint (no auth required)
    Route::post('/webhook', [N8NController::class, 'webhook'])->name('n8n.webhook');
    
    // Authenticated endpoints
    Route::middleware('auth:sanctum')->group(function () {
        Route::post('/execute', [N8NController::class, 'executeWorkflow'])->name('n8n.execute');
        Route::post('/monitoring', [N8NController::class, 'triggerMonitoring'])->name('n8n.monitoring');
        Route::post('/ai', [N8NController::class, 'triggerAI'])->name('n8n.ai');
        Route::post('/deployment', [N8NController::class, 'triggerDeployment'])->name('n8n.deployment');
        Route::get('/status/{executionId}', [N8NController::class, 'getStatus'])->name('n8n.status');
        Route::get('/workflows', [N8NController::class, 'listWorkflows'])->name('n8n.workflows');
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

// Scrum Board routes
Route::middleware(['auth:sanctum'])->prefix('scrum')->group(function () {
    // Dashboard
    Route::get('/dashboard', [App\Http\Controllers\ScrumController::class, 'dashboard'])->name('scrum.dashboard');
    Route::get('/board', [App\Http\Controllers\ScrumController::class, 'board'])->name('scrum.board');
    
    // Sprints
    Route::get('/sprints', [App\Http\Controllers\ScrumController::class, 'listSprints'])->name('scrum.sprints.list');
    Route::post('/sprints', [App\Http\Controllers\ScrumController::class, 'createSprint'])->name('scrum.sprints.create');
    Route::put('/sprints/{sprint}', [App\Http\Controllers\ScrumController::class, 'updateSprint'])->name('scrum.sprints.update');
    Route::post('/sprints/{sprint}/start', [App\Http\Controllers\ScrumController::class, 'startSprint'])->name('scrum.sprints.start');
    
    // Tasks
    Route::get('/tasks', [App\Http\Controllers\ScrumController::class, 'listTasks'])->name('scrum.tasks.list');
    Route::post('/tasks', [App\Http\Controllers\ScrumController::class, 'createTask'])->name('scrum.tasks.create');
    Route::put('/tasks/{task}', [App\Http\Controllers\ScrumController::class, 'updateTask'])->name('scrum.tasks.update');
    Route::post('/tasks/{task}/move', [App\Http\Controllers\ScrumController::class, 'moveTask'])->name('scrum.tasks.move');
    
    // AI Features
    Route::post('/ai/suggest-tasks', [App\Http\Controllers\ScrumController::class, 'suggestTasks'])->name('scrum.ai.suggest');
    Route::post('/ai/estimate-points', [App\Http\Controllers\ScrumController::class, 'estimateStoryPoints'])->name('scrum.ai.estimate');
    
    // Metrics
    Route::get('/metrics/velocity', [App\Http\Controllers\ScrumController::class, 'velocity'])->name('scrum.metrics.velocity');
    Route::get('/metrics/team', [App\Http\Controllers\ScrumController::class, 'teamPerformance'])->name('scrum.metrics.team');
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

        // Project management
        Route::get('/projects', [App\Http\Controllers\Api\Dokploy\DokployApplicationController::class, 'projects']);

        // Testing & diagnostics
        Route::get('/test-connection', [App\Http\Controllers\Api\Dokploy\DokployApplicationController::class, 'testConnection']);
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

            if (!$deployment) {
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

            if (!$latestDeployment) {
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

            if (!$deployment) {
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