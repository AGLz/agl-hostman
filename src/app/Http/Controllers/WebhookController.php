<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Models\Environment;
use App\Services\Deployment\DeploymentWorkflowService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Exception;

/**
 * Webhook Controller
 *
 * Handles incoming webhooks from external services (GitHub, Harbor, etc.)
 * Triggers automated deployments based on configured rules
 */
class WebhookController extends Controller
{
    public function __construct(
        private readonly DeploymentWorkflowService $deploymentService
    ) {}

    /**
     * Handle GitHub push webhook
     *
     * Triggered when code is pushed to GitHub
     * Deploys to appropriate environment based on branch
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function handleGitHubPush(Request $request): JsonResponse
    {
        try {
            // Validate webhook signature
            if (!$this->validateGitHubSignature($request)) {
                Log::warning('Invalid GitHub webhook signature', [
                    'ip' => $request->ip(),
                ]);

                return response()->json([
                    'success' => false,
                    'error' => 'Invalid signature',
                ], 403);
            }

            // Parse payload
            $payload = $request->json()->all();
            $event = $request->header('X-GitHub-Event');

            // Log webhook received
            Log::info('GitHub webhook received', [
                'event' => $event,
                'repository' => $payload['repository']['full_name'] ?? 'unknown',
                'ref' => $payload['ref'] ?? null,
            ]);

            // Only handle push events
            if ($event !== 'push') {
                return response()->json([
                    'success' => true,
                    'message' => "Event '{$event}' ignored (not a push)",
                ]);
            }

            // Extract branch name
            $ref = $payload['ref'] ?? null;
            if (!$ref || !str_starts_with($ref, 'refs/heads/')) {
                return response()->json([
                    'success' => true,
                    'message' => 'Not a branch push, ignoring',
                ]);
            }

            $branch = str_replace('refs/heads/', '', $ref);

            // Find matching environment
            $environment = Environment::where('git_branch', $branch)
                ->where('auto_deploy', true)
                ->where('status', 'active')
                ->first();

            if (!$environment) {
                Log::info('No auto-deploy environment for branch', [
                    'branch' => $branch,
                ]);

                return response()->json([
                    'success' => true,
                    'message' => "No auto-deploy configured for branch '{$branch}'",
                ]);
            }

            // Extract commit info
            $commit = $payload['head_commit'] ?? [];
            $commitSha = $commit['id'] ?? $payload['after'] ?? null;
            $commitMessage = $commit['message'] ?? null;
            $committer = $commit['committer']['username'] ?? 'unknown';

            Log::info('Triggering deployment', [
                'environment' => $environment->type,
                'branch' => $branch,
                'commit' => $commitSha,
                'committer' => $committer,
            ]);

            // Trigger deployment asynchronously
            dispatch(function () use ($environment, $commitSha, $commitMessage, $committer) {
                if ($environment->isQA()) {
                    $this->deploymentService->deployToQA([
                        'triggered_by' => 'github_webhook',
                        'git_commit' => $commitSha,
                        'commit_message' => $commitMessage,
                        'committer' => $committer,
                    ]);
                }
                // Add other environment types here as needed
            })->onQueue('deployments');

            return response()->json([
                'success' => true,
                'message' => "Deployment triggered for {$environment->type} environment",
                'environment' => $environment->type,
                'branch' => $branch,
                'commit' => $commitSha,
            ]);

        } catch (Exception $e) {
            Log::error('GitHub webhook handler error', [
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
            ]);

            return response()->json([
                'success' => false,
                'error' => 'Internal server error',
            ], 500);
        }
    }

    /**
     * Validate GitHub webhook signature
     *
     * Uses HMAC-SHA256 to validate webhook authenticity
     *
     * @param Request $request
     * @return bool True if signature is valid
     */
    private function validateGitHubSignature(Request $request): bool
    {
        // Skip validation if webhook secret is not configured
        $secret = config('services.github.webhook_secret');
        if (!$secret) {
            Log::warning('GitHub webhook secret not configured, skipping signature validation');
            return true;
        }

        // Get signature from header
        $signature = $request->header('X-Hub-Signature-256');
        if (!$signature) {
            return false;
        }

        // Compute expected signature
        $payload = $request->getContent();
        $expectedSignature = 'sha256=' . hash_hmac('sha256', $payload, $secret);

        // Compare signatures (timing-safe)
        return hash_equals($expectedSignature, $signature);
    }

    /**
     * Handle Harbor webhook
     *
     * Triggered when Docker image is pushed to Harbor
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function handleHarborPush(Request $request): JsonResponse
    {
        try {
            $payload = $request->json()->all();

            Log::info('Harbor webhook received', [
                'type' => $payload['type'] ?? 'unknown',
                'resource' => $payload['event_data']['resources'][0]['resource_url'] ?? 'unknown',
            ]);

            // TODO: Implement Harbor webhook logic
            // Extract image tag and trigger deployment

            return response()->json([
                'success' => true,
                'message' => 'Harbor webhook received',
            ]);

        } catch (Exception $e) {
            Log::error('Harbor webhook handler error', [
                'error' => $e->getMessage(),
            ]);

            return response()->json([
                'success' => false,
                'error' => 'Internal server error',
            ], 500);
        }
    }

    /**
     * Handle Dokploy webhook
     *
     * Status updates from Dokploy deployments
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function handleDokployStatus(Request $request): JsonResponse
    {
        try {
            $payload = $request->json()->all();

            Log::info('Dokploy webhook received', [
                'payload' => $payload,
            ]);

            // TODO: Implement Dokploy webhook logic
            // Update deployment status in database

            return response()->json([
                'success' => true,
                'message' => 'Dokploy webhook received',
            ]);

        } catch (Exception $e) {
            Log::error('Dokploy webhook handler error', [
                'error' => $e->getMessage(),
            ]);

            return response()->json([
                'success' => false,
                'error' => 'Internal server error',
            ], 500);
        }
    }
}
