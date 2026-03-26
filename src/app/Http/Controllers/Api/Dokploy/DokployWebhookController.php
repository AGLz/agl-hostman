<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\Dokploy;

use App\Http\Controllers\Controller;
use App\Services\DokployApiClient;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

/**
 * Dokploy Webhook Controller
 *
 * Handles Harbor registry webhooks for automated deployments
 * Triggered when Docker images are pushed to harbor.aglz.io:5000
 */
class DokployWebhookController extends Controller
{
    public function __construct(
        private DokployApiClient $dokploy
    ) {}

    /**
     * Handle Harbor push event webhook
     * POST /api/dokploy/webhooks/harbor
     *
     * Harbor sends webhooks when images are pushed/deleted
     * Payload format: https://goharbor.io/docs/2.0.0/working-with-projects/project-configuration/configure-webhooks/
     */
    public function harborPush(Request $request): JsonResponse
    {
        // Log incoming webhook for debugging
        Log::info('Harbor webhook received', [
            'headers' => $request->headers->all(),
            'payload' => $request->all(),
        ]);

        // Validate webhook payload
        $validated = $request->validate([
            'type' => 'required|string',
            'event_data' => 'required|array',
            'event_data.resources' => 'required|array',
            'event_data.repository' => 'required|array',
            'event_data.repository.name' => 'required|string',
            'event_data.repository.repo_full_name' => 'required|string',
        ]);

        $eventType = $validated['type'];
        $repository = $validated['event_data']['repository'];
        $resources = $validated['event_data']['resources'];

        // Only process PUSH_ARTIFACT events
        if ($eventType !== 'PUSH_ARTIFACT') {
            return response()->json([
                'success' => true,
                'message' => "Ignored event type: {$eventType}",
            ], 200);
        }

        // Extract image details
        $repoName = $repository['name'];
        $repoFullName = $repository['repo_full_name'];
        $imageTag = $resources[0]['tag'] ?? 'latest';

        Log::info('Processing Harbor push event', [
            'repository' => $repoFullName,
            'tag' => $imageTag,
        ]);

        try {
            // Find matching Dokploy application by image name
            $applications = $this->dokploy->getApplications();

            if (! $applications->isSuccess()) {
                throw new \Exception('Failed to fetch Dokploy applications');
            }

            $matchedApp = null;
            foreach ($applications->getData() as $app) {
                // Match by docker image field
                if (isset($app['dockerImage']) && str_contains($app['dockerImage'], $repoName)) {
                    $matchedApp = $app;
                    break;
                }
            }

            if (! $matchedApp) {
                return response()->json([
                    'success' => true,
                    'message' => "No Dokploy application found for image: {$repoName}",
                    'repository' => $repoFullName,
                    'tag' => $imageTag,
                ], 200);
            }

            // Trigger redeployment
            $deployResult = $this->dokploy->redeployApplication($matchedApp['applicationId']);

            if (! $deployResult->isSuccess()) {
                throw new \Exception('Failed to trigger redeployment: '.$deployResult->getError());
            }

            Log::info('Triggered Dokploy redeployment', [
                'application' => $matchedApp['name'],
                'applicationId' => $matchedApp['applicationId'],
                'image' => $repoFullName,
                'tag' => $imageTag,
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Redeployment triggered successfully',
                'application' => $matchedApp['name'],
                'applicationId' => $matchedApp['applicationId'],
                'repository' => $repoFullName,
                'tag' => $imageTag,
            ], 200);

        } catch (\Exception $e) {
            Log::error('Harbor webhook processing failed', [
                'error' => $e->getMessage(),
                'repository' => $repoFullName,
                'tag' => $imageTag,
            ]);

            return response()->json([
                'success' => false,
                'error' => $e->getMessage(),
                'repository' => $repoFullName,
                'tag' => $imageTag,
            ], 500);
        }
    }

    /**
     * Verify webhook authenticity (optional)
     * Harbor can send webhook secret for verification
     */
    protected function verifyWebhookSignature(Request $request): bool
    {
        $secret = config('dokploy.harbor_webhook_secret');

        if (! $secret) {
            return true; // No secret configured, skip verification
        }

        $signature = $request->header('X-Harbor-Signature');
        if (! $signature) {
            return false;
        }

        $payload = $request->getContent();
        $expectedSignature = hash_hmac('sha256', $payload, $secret);

        return hash_equals($expectedSignature, $signature);
    }

    /**
     * Manual webhook trigger for testing
     * POST /api/dokploy/webhooks/harbor/test
     */
    public function testHarborWebhook(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'repository' => 'required|string',
            'tag' => 'required|string',
        ]);

        // Simulate Harbor webhook payload
        $testPayload = [
            'type' => 'PUSH_ARTIFACT',
            'event_data' => [
                'repository' => [
                    'name' => $validated['repository'],
                    'repo_full_name' => 'agl/'.$validated['repository'],
                    'repo_type' => 'private',
                ],
                'resources' => [
                    [
                        'tag' => $validated['tag'],
                        'resource_url' => "harbor.aglz.io:5000/agl/{$validated['repository']}:{$validated['tag']}",
                    ],
                ],
            ],
        ];

        // Create test request
        $testRequest = Request::create(
            '/api/dokploy/webhooks/harbor',
            'POST',
            $testPayload
        );

        return $this->harborPush($testRequest);
    }
}
