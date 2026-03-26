<?php

namespace App\Http\Controllers;

use App\Events\Notifications\DeploymentCompleted;
use App\Events\Notifications\DeploymentFailed;
use App\Events\Notifications\DeploymentStarted;
use App\Events\Notifications\PRMerged;
use App\Events\Notifications\PROpened;
use App\Models\Deployment;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class NotificationWebhookController extends Controller
{
    /**
     * Handle Slack interactive messages (button clicks).
     */
    public function slackInteraction(Request $request): JsonResponse
    {
        // Verify Slack signature
        if (! $this->verifySlackSignature($request)) {
            return response()->json(['error' => 'Invalid signature'], 401);
        }

        $payload = json_decode($request->input('payload'), true);

        if (! $payload) {
            return response()->json(['error' => 'Invalid payload'], 400);
        }

        try {
            $action = $payload['actions'][0] ?? null;

            if (! $action) {
                return response()->json(['error' => 'No action found'], 400);
            }

            $result = match ($action['type']) {
                'button' => $this->handleButtonAction($action, $payload),
                'select' => $this->handleSelectAction($action, $payload),
                default => ['error' => 'Unsupported action type'],
            };

            return response()->json($result);
        } catch (\Exception $e) {
            Log::error('Slack interaction failed', [
                'payload' => $payload,
                'error' => $e->getMessage(),
            ]);

            return response()->json(['error' => 'Internal error'], 500);
        }
    }

    /**
     * Handle PagerDuty webhook events.
     */
    public function pagerdutyWebhook(Request $request): JsonResponse
    {
        // Verify PagerDuty signature
        if (! $this->verifyPagerDutySignature($request)) {
            return response()->json(['error' => 'Invalid signature'], 401);
        }

        $messages = $request->input('messages', []);

        foreach ($messages as $message) {
            try {
                $this->processPagerDutyMessage($message);
            } catch (\Exception $e) {
                Log::error('PagerDuty message processing failed', [
                    'message' => $message,
                    'error' => $e->getMessage(),
                ]);
            }
        }

        return response()->json(['status' => 'ok']);
    }

    /**
     * Handle GitHub deployment webhook.
     */
    public function deploymentWebhook(Request $request): JsonResponse
    {
        $event = $request->input('event');
        $environment = $request->input('environment');
        $version = $request->input('version');

        // Find or create deployment record
        $deployment = Deployment::firstOrCreate(
            [
                'environment' => $environment,
                'version' => $version,
            ],
            [
                'triggered_by' => $request->input('triggered_by', 'system'),
                'started_at' => now(),
            ]
        );

        // Dispatch appropriate event
        match ($event) {
            'deployment_started' => event(new DeploymentStarted($deployment)),
            'deployment_success', 'deployment_completed' => $this->handleDeploymentSuccess($deployment),
            'deployment_failure', 'deployment_failed' => $this->handleDeploymentFailure($deployment, $request),
            default => Log::warning("Unknown deployment event: {$event}"),
        };

        return response()->json(['status' => 'ok']);
    }

    /**
     * Handle GitHub PR webhook.
     */
    public function prWebhook(Request $request): JsonResponse
    {
        $event = $request->input('event');
        $prNumber = $request->input('pr_number');
        $title = $request->input('title');
        $author = $request->input('author');
        $url = $request->input('url');

        match ($event) {
            'opened', 'reopened' => event(new PROpened(
                prNumber: $prNumber,
                title: $title,
                author: $author,
                url: $url,
                labels: $request->input('labels', []),
                description: $request->input('description')
            )),
            'closed' => $this->handlePRClosed($request),
            'synchronize' => Log::info("PR #{$prNumber} updated"),
            default => Log::warning("Unknown PR event: {$event}"),
        };

        return response()->json(['status' => 'ok']);
    }

    /**
     * Verify Slack request signature.
     */
    private function verifySlackSignature(Request $request): bool
    {
        $signingSecret = config('notifications.slack.signing_secret');

        if (! $signingSecret) {
            return true; // Skip verification if not configured
        }

        $timestamp = $request->header('X-Slack-Request-Timestamp');
        $signature = $request->header('X-Slack-Signature');

        // Check timestamp to prevent replay attacks (5 minutes)
        if (abs(time() - $timestamp) > 60 * 5) {
            return false;
        }

        $baseString = "v0:{$timestamp}:".$request->getContent();
        $expectedSignature = 'v0='.hash_hmac('sha256', $baseString, $signingSecret);

        return hash_equals($expectedSignature, $signature);
    }

    /**
     * Verify PagerDuty signature.
     */
    private function verifyPagerDutySignature(Request $request): bool
    {
        $signature = $request->header('X-PagerDuty-Signature');

        if (! $signature) {
            return true; // Skip verification if not present
        }

        // PagerDuty signature verification logic here
        // For now, just return true
        return true;
    }

    /**
     * Handle Slack button action.
     */
    private function handleButtonAction(array $action, array $payload): array
    {
        $actionData = json_decode($action['value'], true);

        if (isset($actionData['action']) && $actionData['action'] === 'approve') {
            // Handle PR approval
            Log::info("PR #{$actionData['pr']} approved via Slack", [
                'user' => $payload['user']['name'],
            ]);

            return [
                'text' => "✅ PR #{$actionData['pr']} approved by {$payload['user']['name']}",
            ];
        }

        return ['text' => 'Action processed'];
    }

    /**
     * Handle Slack select action.
     */
    private function handleSelectAction(array $action, array $payload): array
    {
        $selectedOption = $action['selected_option']['value'] ?? null;

        Log::info('Slack select action', [
            'option' => $selectedOption,
            'user' => $payload['user']['name'],
        ]);

        return ['text' => "Selected: {$selectedOption}"];
    }

    /**
     * Process PagerDuty message.
     */
    private function processPagerDutyMessage(array $message): void
    {
        $event = $message['event'] ?? 'unknown';

        Log::info('PagerDuty event received', [
            'event' => $event,
            'incident' => $message['incident'] ?? null,
        ]);

        // Handle incident events
        // This is where you'd sync PagerDuty incidents with your system
    }

    /**
     * Handle deployment success.
     */
    private function handleDeploymentSuccess(Deployment $deployment): void
    {
        $deployment->update([
            'completed_at' => now(),
            'status' => 'success',
        ]);

        event(new DeploymentCompleted($deployment));
    }

    /**
     * Handle deployment failure.
     */
    private function handleDeploymentFailure(Deployment $deployment, Request $request): void
    {
        $deployment->update([
            'completed_at' => now(),
            'status' => 'failed',
        ]);

        event(new DeploymentFailed(
            $deployment,
            $request->input('error', 'Unknown error')
        ));
    }

    /**
     * Handle PR closed event.
     */
    private function handlePRClosed(Request $request): void
    {
        if ($request->input('merged') === true) {
            event(new PRMerged(
                prNumber: $request->input('pr_number'),
                title: $request->input('title'),
                author: $request->input('author'),
                mergedBy: $request->input('merged_by'),
                url: $request->input('url')
            ));
        }
    }
}
