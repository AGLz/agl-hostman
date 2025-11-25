<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Services\Deployment\PromotionWorkflowService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Log;

class GitHubWebhookController extends Controller
{
    public function __construct(
        private readonly PromotionWorkflowService $promotionService
    ) {}

    /**
     * Handle GitHub push events for automated dev→qa promotion
     */
    public function handlePush(Request $request): JsonResponse
    {
        // 1. Validate webhook signature
        $this->validateSignature($request);
        
        $payload = $request->json()->all();
        $branch = $payload['ref'] ?? '';
        
        Log::info('GitHub push webhook received', [
            'branch' => $branch,
            'repository' => $payload['repository']['full_name'] ?? 'unknown',
        ]);
        
        // Auto-promote on develop branch push
        if ($branch === 'refs/heads/develop') {
            $result = $this->promotionService->autoPromoteDevToQA($payload);
            
            return response()->json($result, $result['success'] ? 200 : 500);
        }
        
        return response()->json(['message' => 'Webhook received, no action taken']);
    }

    /**
     * Handle GitHub workflow_run events
     */
    public function handleWorkflowRun(Request $request): JsonResponse
    {
        $this->validateSignature($request);
        
        $payload = $request->json()->all();
        
        Log::info('GitHub workflow_run webhook received', [
            'workflow' => $payload['workflow']['name'] ?? 'unknown',
            'status' => $payload['workflow_run']['status'] ?? 'unknown',
        ]);
        
        // Track CI/CD workflow status
        // Can be used to trigger auto-promotion on test success
        
        return response()->json(['message' => 'Workflow run event received']);
    }

    /**
     * Validate GitHub webhook signature (HMAC-SHA256)
     */
    private function validateSignature(Request $request): void
    {
        $signature = $request->header('X-Hub-Signature-256');
        $payload = $request->getContent();
        $secret = config('deployment.github_webhook_secret');
        
        if (!$secret) {
            Log::warning('GitHub webhook secret not configured, skipping validation');
            return;
        }
        
        if (!$signature) {
            abort(401, 'Missing webhook signature');
        }
        
        $expectedSignature = 'sha256=' . hash_hmac('sha256', $payload, $secret);
        
        if (!hash_equals($expectedSignature, $signature)) {
            Log::error('Invalid GitHub webhook signature', [
                'expected' => $expectedSignature,
                'received' => $signature,
            ]);
            abort(401, 'Invalid webhook signature');
        }
    }
}
